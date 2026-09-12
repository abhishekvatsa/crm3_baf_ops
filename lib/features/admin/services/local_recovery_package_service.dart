import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/isar_production_recovery.dart';

/// How the database bytes in a recovery package were obtained.
enum LocalRecoverySnapshotMode {
  /// Written through the store's own snapshot API, so the copy is a
  /// transactionally consistent view of the database.
  consistent,

  /// Ordinary file copies taken while the store may have been changing. Useful
  /// evidence, but not a guaranteed-restorable snapshot.
  rawFileCopy,
}

/// What a recovery package actually contains.
///
/// The previous button reported "Recovery package created" and a file count.
/// That wording could not distinguish a consistent snapshot from raw copies
/// taken during writes, said nothing about the preference-backed state it never
/// collected, and read as success even when zero database files were found.
/// Support then treated it as a verified backup. This result carries the
/// qualifications with it so the operator message cannot overstate them.
class LocalRecoveryPackageOutcome {
  const LocalRecoveryPackageOutcome({
    required this.directoryPath,
    required this.snapshotMode,
    required this.databaseFileCount,
    required this.ancillaryKeyCount,
    required this.ancillaryStatePath,
    required this.warnings,
  });

  final String directoryPath;
  final LocalRecoverySnapshotMode snapshotMode;
  final int databaseFileCount;
  final int ancillaryKeyCount;
  final String? ancillaryStatePath;
  final List<String> warnings;

  bool get isConsistent =>
      snapshotMode == LocalRecoverySnapshotMode.consistent;

  bool get coversDatabase => databaseFileCount > 0;

  bool get coversAncillaryState => ancillaryStatePath != null;

  /// A short, honest operator summary.
  ///
  /// It never says "backed up": the package stays inside the application
  /// sandbox, and retrieving it is a separate act.
  String get operatorSummary {
    if (!coversDatabase) {
      return 'No database files were captured. Keep this folder and contact '
          'support before further use.';
    }
    final basis =
        isConsistent
            ? 'Consistent database snapshot'
            : 'Raw database copy (consistency not guaranteed)';
    final ancillary =
        coversAncillaryState
            ? '$ancillaryKeyCount saved settings and drafts included'
            : 'saved settings and drafts NOT included';
    return '$basis; $ancillary. Stored on this device only.';
  }
}

typedef ConsistentRecoveryPackageCreator =
    Future<IsarRecoveryPackageResult> Function({
      required Isar database,
      required String diagnosticsText,
      required String reason,
      String? manifestJsonText,
    });

typedef RecoveryAncillaryStateWriter =
    Future<String?> Function({
      required String directoryPath,
      required String fileName,
      required String contents,
    });

typedef RawRecoveryPackageCreator =
    Future<IsarRecoveryPackageResult> Function({
      required String diagnosticsText,
      required String reason,
      String? manifestJsonText,
    });

/// Builds the support recovery package for the local diagnostics screen.
///
/// Presentation owns no direct persistence, so the screen asks this service
/// rather than reaching for the store itself.
///
/// Two gaps in the previous behaviour are closed here. The diagnostics button
/// called the raw-copy helper even though the store exposes a consistent
/// snapshot, and preference-backed state was never collected at all — which
/// silently excluded pull cursors, schema provenance, the command idempotency
/// stores that stop a retry becoming a duplicate submission, and unsent
/// composer drafts.
class LocalRecoveryPackageService {
  LocalRecoveryPackageService({
    Isar? Function()? databaseLookup,
    Future<SharedPreferences> Function()? preferencesLoader,
    ConsistentRecoveryPackageCreator? consistentCreator,
    RawRecoveryPackageCreator? rawCreator,
    RecoveryAncillaryStateWriter? ancillaryWriter,
  }) : _databaseLookup = databaseLookup ?? Isar.getInstance,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _consistentCreator =
           consistentCreator ?? createConsistentIsarRecoveryPackage,
       _rawCreator = rawCreator ?? createIsarRecoveryPackage,
       _ancillaryWriter = ancillaryWriter ?? writeRecoveryAncillaryStateFile;

  final Isar? Function() _databaseLookup;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final ConsistentRecoveryPackageCreator _consistentCreator;
  final RawRecoveryPackageCreator _rawCreator;
  final RecoveryAncillaryStateWriter _ancillaryWriter;

  static const String ancillaryStateFileName = 'ancillary_state.json';

  Future<LocalRecoveryPackageOutcome> create({
    required String diagnosticsText,
    required String manifestJsonText,
    required String reason,
  }) async {
    final warnings = <String>[];
    final database = _databaseLookup();

    IsarRecoveryPackageResult result;
    LocalRecoverySnapshotMode mode;

    if (database == null) {
      // Falling back is better than refusing to preserve anything, but the
      // caller must not be told this is a snapshot.
      warnings.add(
        'The local store was not open, so raw file copies were taken instead '
        'of a consistent snapshot.',
      );
      result = await _rawCreator(
        diagnosticsText: diagnosticsText,
        reason: reason,
        manifestJsonText: manifestJsonText,
      );
      mode = LocalRecoverySnapshotMode.rawFileCopy;
    } else {
      try {
        result = await _consistentCreator(
          database: database,
          diagnosticsText: diagnosticsText,
          reason: reason,
          manifestJsonText: manifestJsonText,
        );
        mode = LocalRecoverySnapshotMode.consistent;
      } catch (error) {
        // A failed snapshot must not lose the evidence entirely; degrade to
        // raw copies and say which one happened.
        warnings.add('The consistent snapshot failed ($error).');
        result = await _rawCreator(
          diagnosticsText: diagnosticsText,
          reason: reason,
          manifestJsonText: manifestJsonText,
        );
        mode = LocalRecoverySnapshotMode.rawFileCopy;
      }
    }

    warnings.addAll(result.warnings);

    final ancillary = await _writeAncillaryState(result.directoryPath);

    return LocalRecoveryPackageOutcome(
      directoryPath: result.directoryPath,
      snapshotMode: mode,
      databaseFileCount: result.copiedFileCount,
      ancillaryKeyCount: ancillary.keyCount,
      ancillaryStatePath: ancillary.path,
      warnings: <String>[...warnings, ...ancillary.warnings],
    );
  }

  Future<_AncillaryStateResult> _writeAncillaryState(
    String directoryPath,
  ) async {
    try {
      final preferences = await _preferencesLoader();
      await preferences.reload();
      final keys = preferences.getKeys().toList()..sort();
      final values = <String, Object?>{
        for (final key in keys) key: preferences.get(key),
      };
      final path = await _ancillaryWriter(
        directoryPath: directoryPath,
        fileName: ancillaryStateFileName,
        contents: const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
          'keyCount': keys.length,
          'note':
              'Preference-backed state: synchronization cursors, schema '
              'provenance, command idempotency keys and unsent drafts. This '
              'is device-local operational state, not a credential store.',
          'entries': values,
        }),
      );
      if (path == null) {
        return const _AncillaryStateResult(
          path: null,
          keyCount: 0,
          warnings: <String>[
            'This platform has no filesystem, so saved settings and drafts '
            'were not captured.',
          ],
        );
      }
      return _AncillaryStateResult(
        path: path,
        keyCount: keys.length,
        warnings:
            keys.isEmpty
                ? const <String>[
                  'No preference-backed state was found to capture.',
                ]
                : const <String>[],
      );
    } catch (error) {
      return _AncillaryStateResult(
        path: null,
        keyCount: 0,
        warnings: <String>[
          'Saved settings and drafts could not be captured ($error). The '
          'database copy does not contain them.',
        ],
      );
    }
  }
}

class _AncillaryStateResult {
  const _AncillaryStateResult({
    required this.path,
    required this.keyCount,
    required this.warnings,
  });

  final String? path;
  final int keyCount;
  final List<String> warnings;
}
