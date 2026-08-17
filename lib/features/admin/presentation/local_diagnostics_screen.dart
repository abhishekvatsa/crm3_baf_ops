// FILE: lib/features/admin/presentation/local_diagnostics_screen.dart

import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/sync_status_provider.dart';
import '../../../core/release/app_build_identity.dart';
import '../../../core/release/backend_release_identity_service.dart';
import '../../../core/services/isar_installed_store_provenance.dart';
import '../../../core/services/isar_production_recovery.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../services/local_diagnostics_read_adapter.dart';
import 'local_diagnostics_exporter.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/planned_maintenance/services/planned_job_server_completion_service.dart';
import '../../../features/planned_maintenance/services/published_template_assignment_server_service.dart';
import '../../../firebase_options.dart';

final localDiagnosticsReportProvider =
    FutureProvider.autoDispose<LocalDiagnosticsReport>((ref) async {
      final actor = await ref.watch(currentAppUserProvider.future);
      if (actor == null || !actor.canManageTemplateGovernance) {
        throw StateError('Admin/SI access is required for local diagnostics.');
      }

      final syncStatus = ref.watch(syncStatusProvider);
      final syncHealth = ref.watch(syncRunHealthProvider);
      final supportSnapshot = LocalDiagnosticsSupportSnapshot.capture(
        syncStatus: syncStatus,
        syncHealth: syncHealth,
      );
      final releaseSnapshot = await LocalReleaseDiagnosticsSnapshot.capture(
        ref,
        loadBackend: !kIsWeb,
      );

      if (kIsWeb) {
        return LocalDiagnosticsReport.webUnavailable(
          supportSnapshot: supportSnapshot,
          releaseSnapshot: releaseSnapshot,
          provenanceInventory:
              IsarInstalledStoreProvenanceInventory.unsupported(),
        );
      }

      final persistence = await LocalDiagnosticsReadAdapter().read();
      final rows = persistence.rows
          .map(
            (row) => LocalDiagnosticsRow(
              label: row.label,
              totalCount: row.totalCount,
              unsyncedCount: row.unsyncedCount,
              note: row.note,
            ),
          )
          .toList(growable: false);
      final governance = persistence.governance;
      final governanceSummary = LocalGovernanceDiagnosticsSummary(
        activePackages: governance.activePackages,
        retiredPackages: governance.retiredPackages,
        archivedPackages: governance.archivedPackages,
        publishedVersions: governance.publishedVersions,
        draftVersions: governance.draftVersions,
        retiredVersions: governance.retiredVersions,
        archivedVersions: governance.archivedVersions,
        publishAuditRows: governance.publishAuditRows,
      );

      return LocalDiagnosticsReport(
        generatedAt: DateTime.now(),
        rows: rows,
        unresolvedRejections: persistence.unresolvedRejections,
        likelyPermanentRejections: persistence.likelyPermanentRejections,
        totalRejections: persistence.totalRejections,
        knowledgeMetaRows: persistence.knowledgeMetaRows,
        collectionCount: rows.length + 2,
        governanceSummary: governanceSummary,
        supportSnapshot: supportSnapshot,
        releaseSnapshot: releaseSnapshot,
        provenanceInventory: persistence.provenanceInventory,
      );
    });

class LocalDiagnosticsReport {
  final DateTime generatedAt;
  final List<LocalDiagnosticsRow> rows;
  final int unresolvedRejections;
  final int likelyPermanentRejections;
  final int totalRejections;
  final int knowledgeMetaRows;
  final int collectionCount;
  final LocalGovernanceDiagnosticsSummary? governanceSummary;
  final LocalDiagnosticsSupportSnapshot supportSnapshot;
  final LocalReleaseDiagnosticsSnapshot releaseSnapshot;
  final IsarInstalledStoreProvenanceInventory provenanceInventory;
  final bool isWebUnavailable;

  const LocalDiagnosticsReport({
    required this.generatedAt,
    required this.rows,
    required this.unresolvedRejections,
    required this.likelyPermanentRejections,
    required this.totalRejections,
    required this.knowledgeMetaRows,
    required this.collectionCount,
    required this.supportSnapshot,
    required this.releaseSnapshot,
    required this.provenanceInventory,
    this.governanceSummary,
    this.isWebUnavailable = false,
  });

  factory LocalDiagnosticsReport.webUnavailable({
    required LocalDiagnosticsSupportSnapshot supportSnapshot,
    required LocalReleaseDiagnosticsSnapshot releaseSnapshot,
    required IsarInstalledStoreProvenanceInventory provenanceInventory,
  }) {
    return LocalDiagnosticsReport(
      generatedAt: DateTime.now(),
      rows: const <LocalDiagnosticsRow>[],
      unresolvedRejections: 0,
      likelyPermanentRejections: 0,
      totalRejections: 0,
      knowledgeMetaRows: 0,
      collectionCount: 0,
      supportSnapshot: supportSnapshot,
      releaseSnapshot: releaseSnapshot,
      provenanceInventory: provenanceInventory,
      isWebUnavailable: true,
    );
  }

  int get totalUnsyncedRows =>
      rows.fold<int>(0, (sum, row) => sum + row.unsyncedCount);

  String toClipboardText() {
    final buffer =
        StringBuffer()
          ..writeln('CRM-III BAF Ops local diagnostics inventory')
          ..writeln('generatedAt: ${generatedAt.toIso8601String()}')
          ..writeln('totalUnsyncedRows: $totalUnsyncedRows')
          ..writeln('unresolvedSyncRejections: $unresolvedRejections')
          ..writeln('likelyPermanentSyncRejections: $likelyPermanentRejections')
          ..writeln('totalSyncRejectionRows: $totalRejections')
          ..writeln('knowledgeMetaRows: $knowledgeMetaRows')
          ..writeln('collectionsReported: $collectionCount')
          ..writeln('syncStatus: ${supportSnapshot.syncStatusLabel}')
          ..writeln('syncRunning: ${supportSnapshot.syncIsRunning}')
          ..writeln(
            'syncLastReason: ${supportSnapshot.syncLastReason ?? 'none'}',
          )
          ..writeln(
            'syncLastCompletedAt: ${supportSnapshot.syncLastCompletedAtIso ?? 'never'}',
          )
          ..writeln(
            'syncLastSkippedAt: ${supportSnapshot.syncLastSkippedAtIso ?? 'never'}',
          )
          ..writeln(
            'syncLastSucceeded: ${supportSnapshot.syncLastSucceeded ?? 'unknown'}',
          )
          ..writeln('syncRunCount: ${supportSnapshot.syncRunCount}')
          ..writeln('syncSuccessCount: ${supportSnapshot.syncSuccessCount}')
          ..writeln('syncFailureCount: ${supportSnapshot.syncFailureCount}')
          ..writeln('syncConflictCount: ${supportSnapshot.syncConflictCount}')
          ..writeln(
            'syncFailureDetailCount: ${supportSnapshot.syncFailureDetailCount}',
          )
          ..writeln(
            'syncFailureDetailOverflowCount: ${supportSnapshot.syncFailureDetailOverflowCount}',
          )
          ..writeln(
            'closureCallable: ${supportSnapshot.callableName} (${supportSnapshot.callableRegion})',
          )
          ..writeln(
            'assignmentCallable: ${supportSnapshot.assignmentCallableName} (${supportSnapshot.assignmentCallableRegion})',
          )
          ..writeln(
            'backendIdentityCallable: ${supportSnapshot.backendIdentityCallableName} (${supportSnapshot.backendIdentityCallableRegion})',
          )
          ..writeln(
            'firebaseProjectId: ${supportSnapshot.firebaseProjectId ?? 'unavailable'}',
          )
          ..writeln(
            'firebaseStorageBucket: ${supportSnapshot.firebaseStorageBucket ?? 'unavailable'}',
          )
          ..writeln('platform: ${supportSnapshot.platformLabel}')
          ..writeln('')
          ..writeln('Local database provenance:')
          ..writeln(provenanceInventory.toDiagnosticsText())
          ..writeln('')
          ..writeln('Release identity:')
          ..writeln(releaseSnapshot.toDiagnosticsText())
          ..writeln('')
          ..writeln('Governance:')
          ..writeln(
            'activeTemplatePackages: ${governanceSummary?.activePackages ?? 0}',
          )
          ..writeln(
            'publishedTemplateVersions: ${governanceSummary?.publishedVersions ?? 0}',
          )
          ..writeln(
            'draftTemplateVersions: ${governanceSummary?.draftVersions ?? 0}',
          )
          ..writeln(
            'registryMode: Firestore-only in this release; local diagnostics do not count remote registry families/revisions.',
          )
          ..writeln('')
          ..writeln('Rows:');

    for (final row in rows) {
      buffer.writeln(
        '- ${row.label}: total=${row.totalCount}, unsynced=${row.unsyncedCount}',
      );
      if (row.note != null) buffer.writeln('  note=${row.note}');
    }
    return buffer.toString();
  }

  String toRecoveryManifestJsonText({String mode = 'open_database_inventory'}) {
    final map = <String, Object?>{
      'app': 'CRM-III BAF Ops',
      'mode': mode,
      'generatedAt': generatedAt.toIso8601String(),
      'isWebUnavailable': isWebUnavailable,
      'totalUnsyncedRows': totalUnsyncedRows,
      'unresolvedSyncRejections': unresolvedRejections,
      'likelyPermanentSyncRejections': likelyPermanentRejections,
      'totalSyncRejectionRows': totalRejections,
      'knowledgeMetaRows': knowledgeMetaRows,
      'collectionsReported': collectionCount,
      'support': supportSnapshot.toMap(),
      'releaseIdentity': releaseSnapshot.toMap(),
      'localDatabaseProvenance': provenanceInventory.toMap(),
      if (governanceSummary != null)
        'governanceSummary': governanceSummary!.toMap(),
      'rows': rows
          .map(
            (row) => <String, Object?>{
              'label': row.label,
              'totalCount': row.totalCount,
              'unsyncedCount': row.unsyncedCount,
              if (row.note != null) 'note': row.note,
            },
          )
          .toList(growable: false),
      'policy': <String, Object?>{
        'firestoreCanRestore': 'synced cloud records only',
        'localOnlyEvidenceRisk': totalUnsyncedRows > 0,
        'resetRule': 'backup/export before rebuild; never auto-wipe',
      },
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}

class LocalReleaseDiagnosticsSnapshot {
  final AppBuildIdentity build;
  final BackendReleaseIdentity? backend;
  final String? backendError;

  const LocalReleaseDiagnosticsSnapshot({
    required this.build,
    this.backend,
    this.backendError,
  });

  static Future<LocalReleaseDiagnosticsSnapshot> capture(
    Ref ref, {
    required bool loadBackend,
  }) async {
    if (!loadBackend) {
      return const LocalReleaseDiagnosticsSnapshot(
        build: AppBuildIdentity.current,
        backendError: 'Backend identity is not loaded for web diagnostics.',
      );
    }
    try {
      final backend =
          await ref.read(backendReleaseIdentityServiceProvider).fetch();
      return LocalReleaseDiagnosticsSnapshot(
        build: AppBuildIdentity.current,
        backend: backend,
      );
    } catch (error) {
      return LocalReleaseDiagnosticsSnapshot(
        build: AppBuildIdentity.current,
        backendError: error.toString(),
      );
    }
  }

  bool get backendParityConfirmed =>
      backend != null &&
      build.expectsBackendParity &&
      backend!.releaseId == build.expectedBackendReleaseId;

  String get parityLabel {
    if (!build.expectsBackendParity) return 'not declared by build';
    if (backend == null) return 'unavailable';
    return backendParityConfirmed ? 'match' : 'mismatch';
  }

  String toDiagnosticsText() {
    final lines = <String>[
      build.toDiagnosticsText(),
      'backendParity: $parityLabel',
    ];
    if (backend != null) {
      lines.add('observedBackendReleaseId: ${backend!.releaseId}');
      lines.add('backendEnvironment: ${backend!.environment}');
      lines.add('backendGitCommit: ${backend!.gitCommit ?? 'unavailable'}');
      lines.add(
        'functionsRevision: ${backend!.functionsRevision ?? 'unavailable'}',
      );
      lines.add(
        'firestoreRulesReleaseId: ${backend!.firestoreRulesReleaseId ?? 'unavailable'}',
      );
      lines.add(
        'backendDeployedAt: ${backend!.deployedAt?.toIso8601String() ?? 'unavailable'}',
      );
    } else {
      lines.add('observedBackendReleaseId: unavailable');
      lines.add('backendIdentityError: ${backendError ?? 'unknown'}');
    }
    return lines.join('\n');
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'build': build.toMap(),
    'backend': backend?.toMap(),
    'backendError': backendError,
    'backendParity': parityLabel,
    'backendParityConfirmed': backendParityConfirmed,
  };
}

class LocalGovernanceDiagnosticsSummary {
  final int activePackages;
  final int retiredPackages;
  final int archivedPackages;
  final int publishedVersions;
  final int draftVersions;
  final int retiredVersions;
  final int archivedVersions;
  final int publishAuditRows;

  const LocalGovernanceDiagnosticsSummary({
    required this.activePackages,
    required this.retiredPackages,
    required this.archivedPackages,
    required this.publishedVersions,
    required this.draftVersions,
    required this.retiredVersions,
    required this.archivedVersions,
    required this.publishAuditRows,
  });

  Map<String, Object?> toMap() => <String, Object?>{
    'activePackages': activePackages,
    'retiredPackages': retiredPackages,
    'archivedPackages': archivedPackages,
    'publishedVersions': publishedVersions,
    'draftVersions': draftVersions,
    'retiredVersions': retiredVersions,
    'archivedVersions': archivedVersions,
    'publishAuditRows': publishAuditRows,
    'registryMode':
        'Firestore-only in this release; local diagnostics do not count remote registry families/revisions.',
  };
}

class LocalDiagnosticsSupportSnapshot {
  final String syncStatusLabel;
  final bool syncIsRunning;
  final DateTime? syncLastStartedAt;
  final DateTime? syncLastCompletedAt;
  final DateTime? syncLastSkippedAt;
  final String? syncLastReason;
  final String? syncLastSkippedReason;
  final bool? syncLastSucceeded;
  final int syncRunCount;
  final int syncSuccessCount;
  final int syncFailureCount;
  final int syncConflictCount;
  final String? syncLastError;
  final int syncFailureDetailCount;
  final int syncFailureDetailOverflowCount;
  final bool syncHasPendingFollowUp;
  final String? syncPendingFollowUpReason;
  final bool syncPendingFollowUpForce;
  final String callableName;
  final String callableRegion;
  final String assignmentCallableName;
  final String assignmentCallableRegion;
  final String backendIdentityCallableName;
  final String backendIdentityCallableRegion;
  final String? firebaseProjectId;
  final String? firebaseStorageBucket;
  final String platformLabel;

  const LocalDiagnosticsSupportSnapshot({
    required this.syncStatusLabel,
    required this.syncIsRunning,
    required this.syncRunCount,
    required this.syncSuccessCount,
    required this.syncFailureCount,
    required this.syncConflictCount,
    required this.syncFailureDetailCount,
    required this.syncFailureDetailOverflowCount,
    required this.syncHasPendingFollowUp,
    required this.syncPendingFollowUpForce,
    required this.callableName,
    required this.callableRegion,
    required this.assignmentCallableName,
    required this.assignmentCallableRegion,
    required this.backendIdentityCallableName,
    required this.backendIdentityCallableRegion,
    required this.platformLabel,
    this.syncLastStartedAt,
    this.syncLastCompletedAt,
    this.syncLastSkippedAt,
    this.syncLastReason,
    this.syncLastSkippedReason,
    this.syncLastSucceeded,
    this.syncLastError,
    this.syncPendingFollowUpReason,
    this.firebaseProjectId,
    this.firebaseStorageBucket,
  });

  factory LocalDiagnosticsSupportSnapshot.capture({
    required SyncStatus syncStatus,
    required SyncRunHealth syncHealth,
  }) {
    return LocalDiagnosticsSupportSnapshot(
      syncStatusLabel: syncStatus.name,
      syncIsRunning: syncHealth.isRunning,
      syncLastStartedAt: syncHealth.lastStartedAt,
      syncLastCompletedAt: syncHealth.lastCompletedAt,
      syncLastSkippedAt: syncHealth.lastSkippedAt,
      syncLastReason: syncHealth.lastReason,
      syncLastSkippedReason: syncHealth.lastSkippedReason,
      syncLastSucceeded: syncHealth.lastSucceeded,
      syncRunCount: syncHealth.runCount,
      syncSuccessCount: syncHealth.successCount,
      syncFailureCount: syncHealth.failureCount,
      syncConflictCount: syncHealth.conflictCount,
      syncLastError: syncHealth.lastError,
      syncFailureDetailCount: syncHealth.failureDetails.length,
      syncFailureDetailOverflowCount: syncHealth.failureDetailOverflowCount,
      syncHasPendingFollowUp: syncHealth.hasPendingFollowUp,
      syncPendingFollowUpReason: syncHealth.pendingFollowUpReason,
      syncPendingFollowUpForce: syncHealth.pendingFollowUpForce,
      callableName: plannedJobCompletionCallableName,
      callableRegion: plannedJobCompletionCallableRegion,
      assignmentCallableName: publishedTemplateAssignmentCallableName,
      assignmentCallableRegion: publishedTemplateAssignmentCallableRegion,
      backendIdentityCallableName: backendReleaseIdentityCallableName,
      backendIdentityCallableRegion: backendReleaseIdentityCallableRegion,
      firebaseProjectId: _firebaseProjectId(),
      firebaseStorageBucket: _firebaseStorageBucket(),
      platformLabel: kIsWeb ? 'web' : defaultTargetPlatform.name,
    );
  }

  String? get syncLastStartedAtIso => syncLastStartedAt?.toIso8601String();
  String? get syncLastCompletedAtIso => syncLastCompletedAt?.toIso8601String();
  String? get syncLastSkippedAtIso => syncLastSkippedAt?.toIso8601String();

  String get syncSkippedSummary {
    if (syncLastSkippedAt == null && syncLastSkippedReason == null) {
      return 'none';
    }
    final parts = <String>[
      if (syncLastSkippedReason != null) syncLastSkippedReason!,
      if (syncLastSkippedAt != null) _formatDiagnosticTime(syncLastSkippedAt!),
    ];
    return parts.join(' · ');
  }

  String get syncPendingFollowUpSummary {
    if (!syncHasPendingFollowUp) {
      return 'none';
    }

    final parts = <String>[
      if (syncPendingFollowUpReason != null) syncPendingFollowUpReason!,
      syncPendingFollowUpForce ? 'forced' : 'normal',
    ];
    return parts.join(' · ');
  }

  String get syncRunCounterSummary =>
      '$syncRunCount runs · $syncSuccessCount success · $syncFailureCount failures · $syncConflictCount conflicts';

  String get syncFailureDetailSummary =>
      '$syncFailureDetailCount captured${syncFailureDetailOverflowCount > 0 ? ', +$syncFailureDetailOverflowCount overflow' : ''}';

  Map<String, Object?> toMap() => <String, Object?>{
    'syncStatus': syncStatusLabel,
    'syncIsRunning': syncIsRunning,
    'syncLastStartedAt': syncLastStartedAtIso,
    'syncLastCompletedAt': syncLastCompletedAtIso,
    'syncLastSkippedAt': syncLastSkippedAtIso,
    'syncLastReason': syncLastReason,
    'syncLastSkippedReason': syncLastSkippedReason,
    'syncLastSucceeded': syncLastSucceeded,
    'syncRunCount': syncRunCount,
    'syncSuccessCount': syncSuccessCount,
    'syncFailureCount': syncFailureCount,
    'syncConflictCount': syncConflictCount,
    'syncLastError': syncLastError,
    'syncFailureDetailCount': syncFailureDetailCount,
    'syncFailureDetailOverflowCount': syncFailureDetailOverflowCount,
    'syncHasPendingFollowUp': syncHasPendingFollowUp,
    'syncPendingFollowUpReason': syncPendingFollowUpReason,
    'syncPendingFollowUpForce': syncPendingFollowUpForce,
    'callableName': callableName,
    'callableRegion': callableRegion,
    'assignmentCallableName': assignmentCallableName,
    'assignmentCallableRegion': assignmentCallableRegion,
    'backendIdentityCallableName': backendIdentityCallableName,
    'backendIdentityCallableRegion': backendIdentityCallableRegion,
    'firebaseProjectId': firebaseProjectId,
    'firebaseStorageBucket': firebaseStorageBucket,
    'platform': platformLabel,
  };
}

String? _firebaseProjectId() {
  try {
    return DefaultFirebaseOptions.currentPlatform.projectId;
  } catch (_) {
    return null;
  }
}

String? _firebaseStorageBucket() {
  try {
    return DefaultFirebaseOptions.currentPlatform.storageBucket;
  } catch (_) {
    return null;
  }
}

class LocalDiagnosticsRow {
  final String label;
  final int totalCount;
  final int unsyncedCount;
  final String? note;

  const LocalDiagnosticsRow({
    required this.label,
    required this.totalCount,
    required this.unsyncedCount,
    this.note,
  });
}

class LocalDiagnosticsScreen extends ConsumerWidget {
  const LocalDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);

    return actorAsync.when(
      loading:
          () => const Scaffold(
            backgroundColor: BafColors.background,
            body: Center(child: CircularProgressIndicator()),
          ),
      error: (error, _) => _DiagnosticsError(message: '$error'),
      data: (actor) {
        if (actor == null || !actor.canManageTemplateGovernance) {
          return const _DiagnosticsError(
            title: 'Admin/SI access required',
            message:
                'Only approved Admin/SI users can open local diagnostics inventory.',
          );
        }

        final reportAsync = ref.watch(localDiagnosticsReportProvider);

        return Scaffold(
          backgroundColor: BafColors.background,
          appBar: AppBar(
            title: const Text('Local Diagnostics'),
            backgroundColor: BafColors.navy,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Refresh diagnostics',
                onPressed: () => ref.invalidate(localDiagnosticsReportProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
              reportAsync.maybeWhen(
                data:
                    (report) => IconButton(
                      tooltip: 'Create recovery package',
                      onPressed:
                          report.isWebUnavailable
                              ? null
                              : () => _createRecoveryPackage(context, report),
                      icon: const Icon(Icons.inventory_2_rounded),
                    ),
                orElse: () => const SizedBox.shrink(),
              ),
              reportAsync.maybeWhen(
                data:
                    (report) => IconButton(
                      tooltip: 'Save diagnostics file',
                      onPressed:
                          report.isWebUnavailable
                              ? null
                              : () => _saveReportFile(context, report),
                      icon: const Icon(Icons.file_download_rounded),
                    ),
                orElse: () => const SizedBox.shrink(),
              ),
              reportAsync.maybeWhen(
                data:
                    (report) => IconButton(
                      tooltip: 'Copy diagnostics',
                      onPressed:
                          report.isWebUnavailable
                              ? null
                              : () => _copyReport(context, report),
                      icon: const Icon(Icons.copy_rounded),
                    ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          body: SafeArea(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _DiagnosticsErrorBody(message: '$error'),
              data: (report) => _DiagnosticsReportView(report: report),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createRecoveryPackage(
    BuildContext context,
    LocalDiagnosticsReport report,
  ) async {
    try {
      final result = await createIsarRecoveryPackage(
        diagnosticsText: report.toClipboardText(),
        manifestJsonText: report.toRecoveryManifestJsonText(),
        reason: 'admin_local_diagnostics_open_db',
      );
      await Clipboard.setData(ClipboardData(text: result.directoryPath));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recovery package created. ${result.copiedFileCount} DB file(s) copied. Folder path copied.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create recovery package: $e')),
      );
    }
  }

  Future<void> _saveReportFile(
    BuildContext context,
    LocalDiagnosticsReport report,
  ) async {
    try {
      final result = await saveLocalDiagnosticsText(report.toClipboardText());
      await Clipboard.setData(ClipboardData(text: result.path));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${result.fileName}. File path copied to clipboard.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save diagnostics file: $e')),
      );
    }
  }

  Future<void> _copyReport(
    BuildContext context,
    LocalDiagnosticsReport report,
  ) async {
    await Clipboard.setData(ClipboardData(text: report.toClipboardText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Local diagnostics copied.')));
  }
}

class _DiagnosticsReportView extends StatelessWidget {
  final LocalDiagnosticsReport report;

  const _DiagnosticsReportView({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.isWebUnavailable) {
      return const _DiagnosticsErrorBody(
        title: 'Local diagnostics unavailable on web',
        message:
            'This inventory reads the local Isar store and is intended for Android tablet diagnostics.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(BafSpacing.lg),
      children: [
        _DiagnosticsSummary(report: report),
        const SizedBox(height: BafSpacing.lg),
        _DiagnosticsSupportPanel(snapshot: report.supportSnapshot),
        const SizedBox(height: BafSpacing.lg),
        _DatabaseProvenanceDiagnosticsPanel(
          inventory: report.provenanceInventory,
        ),
        const SizedBox(height: BafSpacing.lg),
        _ReleaseIdentityDiagnosticsPanel(snapshot: report.releaseSnapshot),
        if (report.governanceSummary != null) ...[
          const SizedBox(height: BafSpacing.lg),
          _GovernanceDiagnosticsPanel(summary: report.governanceSummary!),
        ],
        const SizedBox(height: BafSpacing.lg),
        _DiagnosticsPanel(
          title: 'Local evidence inventory',
          subtitle:
              'Counts are read locally only. File export saves this inventory text; recovery package export also copies likely raw Isar files. This screen does not sync, reset, delete, or mark anything clean.',
          icon: Icons.storage_rounded,
          child: Column(
            children: report.rows
                .map((row) => _DiagnosticsRowTile(row: row))
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: BafSpacing.lg),
        const _DiagnosticsPanel(
          title: 'Recovery policy',
          icon: Icons.health_and_safety_rounded,
          child: Text(
            'Do not uninstall the app, clear app data, rename the database, or reset local storage before authorized Admin/SI recovery review. Use Create recovery package before any rebuild/reset decision. Firestore can restore synced cloud records only; local-only unsynced evidence may exist only in the backed-up Isar files.',
            style: TextStyle(
              color: BafColors.textSecondary,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticsSummary extends StatelessWidget {
  final LocalDiagnosticsReport report;

  const _DiagnosticsSummary({required this.report});

  @override
  Widget build(BuildContext context) {
    return _DiagnosticsPanel(
      title: 'Local diagnostics inventory',
      subtitle: 'Generated ${report.generatedAt.toLocal()}',
      icon: Icons.fact_check_rounded,
      child: Wrap(
        spacing: BafSpacing.sm,
        runSpacing: BafSpacing.sm,
        children: [
          _SummaryChip(
            label: '${report.totalUnsyncedRows} unsynced rows',
            icon: Icons.cloud_off_rounded,
            color:
                report.totalUnsyncedRows > 0
                    ? BafColors.warning
                    : BafColors.success,
          ),
          _SummaryChip(
            label: '${report.unresolvedRejections} unresolved rejections',
            icon: Icons.report_problem_rounded,
            color:
                report.unresolvedRejections > 0
                    ? BafColors.danger
                    : BafColors.success,
          ),
          _SummaryChip(
            label: '${report.likelyPermanentRejections} likely permanent',
            icon: Icons.block_rounded,
            color:
                report.likelyPermanentRejections > 0
                    ? BafColors.danger
                    : BafColors.textSecondary,
          ),
          _SummaryChip(
            label: '${report.knowledgeMetaRows} knowledge meta rows',
            icon: Icons.psychology_rounded,
            color: BafColors.planned,
          ),
          _SummaryChip(
            label: 'Sync ${report.supportSnapshot.syncStatusLabel}',
            icon:
                report.supportSnapshot.syncIsRunning
                    ? Icons.sync_rounded
                    : Icons.cloud_done_rounded,
            color:
                report.supportSnapshot.syncIsRunning
                    ? BafColors.warning
                    : BafColors.sync,
          ),
        ],
      ),
    );
  }
}

class _DatabaseProvenanceDiagnosticsPanel extends StatelessWidget {
  final IsarInstalledStoreProvenanceInventory inventory;

  const _DatabaseProvenanceDiagnosticsPanel({required this.inventory});

  @override
  Widget build(BuildContext context) {
    final generation = inventory.databaseGenerationSha256;
    final generationLabel =
        generation == null ? 'none' : '${generation.substring(0, 16)}...';

    return _DiagnosticsPanel(
      title: 'Local database provenance',
      subtitle: inventory.overallDisposition,
      icon: Icons.verified_user_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              _SummaryChip(
                label: 'Canonical ${inventory.canonicalDisposition.wireName}',
                icon: Icons.fingerprint_rounded,
                color:
                    inventory.canonicalFingerprintRecognized
                        ? BafColors.success
                        : BafColors.warning,
              ),
              _SummaryChip(
                label:
                    'Schema ${inventory.canonicalSchemaVersion ?? 'unknown'}',
                icon: Icons.schema_rounded,
                color: BafColors.planned,
              ),
              _SummaryChip(
                label:
                    inventory.requiresGovernedRecovery
                        ? 'Recovery review required'
                        : 'Provenance current',
                icon:
                    inventory.requiresGovernedRecovery
                        ? Icons.report_problem_rounded
                        : Icons.check_circle_rounded,
                color:
                    inventory.requiresGovernedRecovery
                        ? BafColors.danger
                        : BafColors.success,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Text(
            'Durable store: ${inventory.hasDurableStore ? 'present' : 'absent'}\n'
            'Legacy marker: ${inventory.legacyDisposition.wireName}\n'
            'Generation digest: $generationLabel\n'
            'Reason: ${inventory.reasonCode ?? 'none'}',
            style: const TextStyle(
              color: BafColors.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSupportPanel extends StatelessWidget {
  final LocalDiagnosticsSupportSnapshot snapshot;

  const _DiagnosticsSupportPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return _DiagnosticsPanel(
      title: 'Runtime support context',
      subtitle:
          'Read-only deployment and sync health signals for Admin/SI support review.',
      icon: Icons.support_agent_rounded,
      child: Column(
        children: [
          _DiagnosticsInfoRow(
            label: 'Firebase project',
            value: snapshot.firebaseProjectId ?? 'Unavailable',
          ),
          _DiagnosticsInfoRow(
            label: 'Storage bucket',
            value: snapshot.firebaseStorageBucket ?? 'Unavailable',
          ),
          _DiagnosticsInfoRow(label: 'Platform', value: snapshot.platformLabel),
          _DiagnosticsInfoRow(
            label: 'Closure callable',
            value: '${snapshot.callableName} (${snapshot.callableRegion})',
          ),
          _DiagnosticsInfoRow(
            label: 'Assignment callable',
            value:
                '${snapshot.assignmentCallableName} (${snapshot.assignmentCallableRegion})',
          ),
          _DiagnosticsInfoRow(
            label: 'Backend identity callable',
            value:
                '${snapshot.backendIdentityCallableName} (${snapshot.backendIdentityCallableRegion})',
          ),
          _DiagnosticsInfoRow(
            label: 'Sync status',
            value: snapshot.syncStatusLabel,
          ),
          _DiagnosticsInfoRow(
            label: 'Sync running',
            value: snapshot.syncIsRunning ? 'yes' : 'no',
          ),
          _DiagnosticsInfoRow(
            label: 'Pending follow-up sync',
            value: snapshot.syncPendingFollowUpSummary,
            isWarning: snapshot.syncHasPendingFollowUp,
          ),
          _DiagnosticsInfoRow(
            label: 'Last sync reason',
            value: snapshot.syncLastReason ?? 'none',
          ),
          _DiagnosticsInfoRow(
            label: 'Last sync completed',
            value:
                snapshot.syncLastCompletedAt == null
                    ? 'never'
                    : _formatDiagnosticTime(snapshot.syncLastCompletedAt!),
          ),
          _DiagnosticsInfoRow(
            label: 'Last sync result',
            value:
                snapshot.syncLastSucceeded == null
                    ? 'unknown'
                    : (snapshot.syncLastSucceeded! ? 'success' : 'failed'),
          ),
          _DiagnosticsInfoRow(
            label: 'Last skipped sync',
            value: snapshot.syncSkippedSummary,
          ),
          _DiagnosticsInfoRow(
            label: 'Run / success / fail / conflict counts',
            value: snapshot.syncRunCounterSummary,
          ),
          _DiagnosticsInfoRow(
            label: 'Failure details',
            value: snapshot.syncFailureDetailSummary,
          ),
          if (snapshot.syncLastError != null)
            _DiagnosticsInfoRow(
              label: 'Last sync error',
              value: snapshot.syncLastError!,
              isWarning: true,
            ),
        ],
      ),
    );
  }
}

class _ReleaseIdentityDiagnosticsPanel extends StatelessWidget {
  final LocalReleaseDiagnosticsSnapshot snapshot;

  const _ReleaseIdentityDiagnosticsPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final parityWarning =
        snapshot.build.expectsBackendParity && !snapshot.backendParityConfirmed;
    return _DiagnosticsPanel(
      title: 'Release and backend identity',
      subtitle:
          'Build-time source identity and the currently observed Firebase backend release. The final APK/AAB hash belongs in the external release manifest.',
      icon: Icons.verified_user_rounded,
      child: Column(
        children: [
          _DiagnosticsInfoRow(
            label: 'App version / build',
            value: snapshot.build.versionLabel,
            isWarning: !snapshot.build.isVersioned,
          ),
          _DiagnosticsInfoRow(
            label: 'Git commit',
            value: snapshot.build.gitCommit,
            isWarning: !snapshot.build.isSourceIdentified,
          ),
          _DiagnosticsInfoRow(
            label: 'Release ID',
            value: snapshot.build.releaseId,
            isWarning: !snapshot.build.isSourceIdentified,
          ),
          _DiagnosticsInfoRow(
            label: 'Tag / channel',
            value:
                '${snapshot.build.releaseTag} · ${snapshot.build.releaseChannel}',
          ),
          _DiagnosticsInfoRow(
            label: 'CI run / build timestamp',
            value:
                '${snapshot.build.ciRunId} · ${snapshot.build.buildTimestampUtc}',
          ),
          _DiagnosticsInfoRow(
            label: 'Source archive SHA-256',
            value: snapshot.build.sourceArchiveSha256,
          ),
          _DiagnosticsInfoRow(
            label: 'Expected backend release',
            value: snapshot.build.expectedBackendReleaseId,
          ),
          _DiagnosticsInfoRow(
            label: 'Observed backend release',
            value: snapshot.backend?.releaseId ?? 'Unavailable',
            isWarning: snapshot.backend == null,
          ),
          _DiagnosticsInfoRow(
            label: 'Backend parity',
            value: snapshot.parityLabel,
            isWarning: parityWarning,
          ),
          if (snapshot.backend != null) ...[
            _DiagnosticsInfoRow(
              label: 'Functions revision',
              value: snapshot.backend!.functionsRevision ?? 'Unavailable',
            ),
            _DiagnosticsInfoRow(
              label: 'Firestore rules release',
              value: snapshot.backend!.firestoreRulesReleaseId ?? 'Unavailable',
            ),
            _DiagnosticsInfoRow(
              label: 'Backend deployed at',
              value:
                  snapshot.backend!.deployedAt == null
                      ? 'Unavailable'
                      : _formatDiagnosticTime(snapshot.backend!.deployedAt!),
            ),
          ] else if (snapshot.backendError != null)
            _DiagnosticsInfoRow(
              label: 'Backend identity status',
              value: snapshot.backendError!,
              isWarning: true,
            ),
        ],
      ),
    );
  }
}

class _GovernanceDiagnosticsPanel extends StatelessWidget {
  final LocalGovernanceDiagnosticsSummary summary;

  const _GovernanceDiagnosticsPanel({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _DiagnosticsPanel(
      title: 'Template governance inventory',
      subtitle:
          'Local TemplatePackage / TemplateVersion support counts. Module Registry is Firestore-only in this release and is not counted from Isar.',
      icon: Icons.verified_rounded,
      child: Column(
        children: [
          _DiagnosticsInfoRow(
            label: 'Template packages',
            value:
                '${summary.activePackages} active · ${summary.retiredPackages} retired · ${summary.archivedPackages} archived',
          ),
          _DiagnosticsInfoRow(
            label: 'Template versions',
            value:
                '${summary.publishedVersions} published · ${summary.draftVersions} draft · ${summary.retiredVersions} retired · ${summary.archivedVersions} archived',
          ),
          _DiagnosticsInfoRow(
            label: 'Template publish audits',
            value: '${summary.publishAuditRows}',
          ),
          const _DiagnosticsInfoRow(
            label: 'Module Registry',
            value:
                'Firestore-only governance source; inspect through Registry authoring / Firestore, not local Isar diagnostics.',
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;

  const _DiagnosticsInfoRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? BafColors.warning : BafColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDiagnosticTime(DateTime value) {
  return value.toLocal().toIso8601String();
}

class _DiagnosticsRowTile extends StatelessWidget {
  final LocalDiagnosticsRow row;

  const _DiagnosticsRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final hasDirty = row.unsyncedCount > 0;
    final color = hasDirty ? BafColors.warning : BafColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasDirty
                    ? Icons.sync_problem_rounded
                    : Icons.check_circle_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  row.label,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${row.unsyncedCount}/${row.totalCount}',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (row.note != null) ...[
            const SizedBox(height: BafSpacing.xs),
            Text(
              row.note!,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  const _DiagnosticsPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: BafColors.navy, size: 26),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: BafSpacing.xs),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: BafSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsError extends StatelessWidget {
  final String title;
  final String message;

  const _DiagnosticsError({
    required this.message,
    this.title = 'Local diagnostics unavailable',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Local Diagnostics'),
        backgroundColor: BafColors.navy,
        foregroundColor: Colors.white,
      ),
      body: _DiagnosticsErrorBody(title: title, message: message),
    );
  }
}

class _DiagnosticsErrorBody extends StatelessWidget {
  final String title;
  final String message;

  const _DiagnosticsErrorBody({
    required this.message,
    this.title = 'Could not load local diagnostics',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: _DiagnosticsPanel(
          title: title,
          icon: Icons.error_outline_rounded,
          child: Text(message, style: const TextStyle(color: BafColors.danger)),
        ),
      ),
    );
  }
}
