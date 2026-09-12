import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/services/isar_production_recovery.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/admin/services/local_recovery_package_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/test_isar_core.dart';

/// The recovery package is what support falls back on when a handset is in
/// trouble. During the 2026-09-09 incident it reported "Recovery package
/// created. 2 DB file(s) copied", which was read as a verified backup. It was
/// raw file copies taken while the store was open, and it contained none of
/// the preference-backed state.
///
/// These tests hold the service to saying what it actually did.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);

  late Directory storeDirectory;
  late Isar openStore;

  setUp(() async {
    storeDirectory = await Directory.systemTemp.createTemp('recovery_pkg');
    openStore = await Isar.open([
      MaintenanceRecordSchema,
    ], directory: storeDirectory.path, name: 'recovery_pkg_test');
  });

  tearDown(() async {
    await openStore.close();
    if (storeDirectory.existsSync()) {
      storeDirectory.deleteSync(recursive: true);
    }
  });

  IsarRecoveryPackageResult packageAt(
    String directory, {
    int copiedFileCount = 2,
    List<String> warnings = const <String>[],
  }) {
    return IsarRecoveryPackageResult(
      directoryPath: directory,
      reportPath: '$directory/recovery_report.txt',
      copiedFileCount: copiedFileCount,
      warnings: warnings,
      files: const <IsarRecoveryFileEntry>[],
    );
  }

  late Map<String, String> written;

  Future<String?> captureWrite({
    required String directoryPath,
    required String fileName,
    required String contents,
  }) async {
    written['$directoryPath/$fileName'] = contents;
    return '$directoryPath/$fileName';
  }

  setUp(() {
    written = <String, String>{};
    SharedPreferences.setMockInitialValues(<String, Object>{
      'globalPullCursor': '2026-09-09T17:00:00Z',
      'composerDraft.RECOVERY::abc': '{"title":"unsent draft"}',
      'morningReviewCommandIdempotency': 'cmd-1',
    });
  });

  LocalRecoveryPackageService serviceWith({
    Object? database = 'open',
    bool consistentThrows = false,
  }) {
    return LocalRecoveryPackageService(
      // The service only passes this through to the snapshot creator, which is
      // stubbed here, so the sentinel stands in for an open store.
      databaseLookup: () => database == null ? null : openStore,
      preferencesLoader: SharedPreferences.getInstance,
      ancillaryWriter: captureWrite,
      consistentCreator: ({
        required database,
        required diagnosticsText,
        required reason,
        manifestJsonText,
      }) async {
        if (consistentThrows) {
          throw StateError('snapshot unavailable');
        }
        return packageAt('/recovery/consistent', copiedFileCount: 1);
      },
      rawCreator: ({
        required diagnosticsText,
        required reason,
        manifestJsonText,
      }) async => packageAt('/recovery/raw'),
    );
  }

  Future<LocalRecoveryPackageOutcome> run(
    LocalRecoveryPackageService service,
  ) => service.create(
    diagnosticsText: 'diagnostics',
    manifestJsonText: '{}',
    reason: 'test',
  );

  group('local recovery package', () {
    test('prefers the consistent snapshot when the store is open', () async {
      final outcome = await run(serviceWith());

      expect(outcome.snapshotMode, LocalRecoverySnapshotMode.consistent);
      expect(outcome.isConsistent, isTrue);
      expect(outcome.operatorSummary, contains('Consistent database snapshot'));
    });

    test('captures preference-backed state the database copy omits', () async {
      final outcome = await run(serviceWith());

      expect(outcome.coversAncillaryState, isTrue);
      expect(outcome.ancillaryKeyCount, 3);

      final payload =
          jsonDecode(written[outcome.ancillaryStatePath]!)
              as Map<String, dynamic>;
      final entries = payload['entries'] as Map<String, dynamic>;

      // The unsent draft and the idempotency key are exactly what a retry
      // needs so it does not become a duplicate submission.
      expect(entries.keys, contains('composerDraft.RECOVERY::abc'));
      expect(entries.keys, contains('morningReviewCommandIdempotency'));
      expect(entries.keys, contains('globalPullCursor'));
    });

    test('falls back to raw copies and says so when there is no store', () async {
      final outcome = await run(serviceWith(database: null));

      expect(outcome.snapshotMode, LocalRecoverySnapshotMode.rawFileCopy);
      expect(outcome.isConsistent, isFalse);
      expect(
        outcome.operatorSummary,
        contains('consistency not guaranteed'),
      );
      expect(
        outcome.warnings.any((w) => w.contains('was not open')),
        isTrue,
      );
    });

    test('degrades to raw copies when the snapshot fails, and reports it', () async {
      final outcome = await run(serviceWith(consistentThrows: true));

      // Preserving something beats preserving nothing, but the caller must
      // not be told it holds a snapshot.
      expect(outcome.snapshotMode, LocalRecoverySnapshotMode.rawFileCopy);
      expect(outcome.databaseFileCount, 2);
      expect(
        outcome.warnings.any((w) => w.contains('consistent snapshot failed')),
        isTrue,
      );
    });

    test('a package with no database files does not read as success', () async {
      final service = LocalRecoveryPackageService(
        databaseLookup: () => null,
        preferencesLoader: SharedPreferences.getInstance,
        ancillaryWriter: captureWrite,
        consistentCreator: ({
          required database,
          required diagnosticsText,
          required reason,
          manifestJsonText,
        }) async => packageAt('/unused'),
        rawCreator: ({
          required diagnosticsText,
          required reason,
          manifestJsonText,
        }) async => packageAt(
          '/recovery/empty',
          copiedFileCount: 0,
          warnings: const <String>['No likely Isar store files were found.'],
        ),
      );

      final outcome = await run(service);

      expect(outcome.coversDatabase, isFalse);
      expect(outcome.operatorSummary, contains('No database files'));
      expect(outcome.operatorSummary, contains('contact support'));
    });

    test('a failure to capture settings is stated, not swallowed', () async {
      final service = LocalRecoveryPackageService(
        databaseLookup: () => openStore,
        preferencesLoader: () async => throw StateError('prefs unavailable'),
        ancillaryWriter: captureWrite,
        consistentCreator: ({
          required database,
          required diagnosticsText,
          required reason,
          manifestJsonText,
        }) async => packageAt('/recovery/consistent', copiedFileCount: 1),
        rawCreator: ({
          required diagnosticsText,
          required reason,
          manifestJsonText,
        }) async => packageAt('/recovery/raw'),
      );

      final outcome = await run(service);

      expect(outcome.coversAncillaryState, isFalse);
      expect(outcome.operatorSummary, contains('NOT included'));
      expect(
        outcome.warnings.any((w) => w.contains('could not be captured')),
        isTrue,
      );
    });

    test('the summary never claims an off-device backup', () async {
      final outcome = await run(serviceWith());

      expect(outcome.operatorSummary, contains('Stored on this device only'));
      expect(outcome.operatorSummary.toLowerCase(), isNot(contains('backed up')));
    });
  });
}
