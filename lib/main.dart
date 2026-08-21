// FILE: lib/main.dart

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'firebase_options.dart';

// ── DATA MODELS ───────────────────────────────────────────────
import 'features/charges/data/charge_model.dart';
import 'features/maintenance/data/maintenance_model.dart';
import 'features/planned_maintenance/data/job_template_model.dart';
import 'features/planned_maintenance/data/job_diary_model.dart';
import 'features/planned_maintenance/data/job_module_model.dart';
import 'features/planned_maintenance/data/template_governance_model.dart';
import 'features/planned_maintenance/data/baf_knowledge_model.dart';
import 'features/directives/data/operational_directive_model.dart';
import 'features/audit/models/audit_event_model.dart';
import 'features/abnormalities/data/abnormality_model.dart';
import 'features/maintenance_workflow/data/compliance_attempt_record.dart';
import 'features/maintenance_workflow/data/compliance_request_record.dart';
import 'features/maintenance_workflow/data/equipment_prompt_record.dart';
import 'features/maintenance_workflow/data/equipment_status_record.dart';
import 'features/maintenance_workflow/data/job_lane_record.dart';
import 'features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'features/maintenance_workflow/data/workflow_command_record.dart';
import 'features/maintenance_workflow/data/workflow_event_record.dart';

// ── AUTH ─────────────────────────────────────────────────────
import 'features/auth/data/user_model.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/pending_approval_screen.dart';
import 'features/auth/providers/auth_provider.dart';

// ── SERVICES / PROVIDERS ─────────────────────────────────────
import 'core/providers/sync_providers.dart';
import 'core/persistence/app_database.dart';
import 'core/serialization/persisted_data_reader.dart';
import 'core/services/auto_sync_service.dart';
import 'core/services/app_logger.dart';
import 'core/security/app_check_bootstrap.dart';
import 'core/services/crash_reporting_bootstrap.dart';
import 'core/services/governed_asset_identity_local_repair.dart';
import 'core/services/isar_installed_store_provenance.dart';
import 'core/services/isar_production_recovery.dart';
import 'core/services/isar_schema_guard.dart';
import 'core/services/isar_schema_migration.dart';
import 'core/services/live_remote_sync_service.dart';
import 'core/services/operational_assurance_local_repair.dart';
import 'core/services/planned_job_local_link_repair.dart';
import 'core/services/sync_coordinator.dart';
import 'core/theme/baf_design_system.dart';
import 'core/widgets/brand/brand_widgets.dart';

// ── UI ───────────────────────────────────────────────────────
import 'home_screen.dart';

// ─────────────────────────────────────────────────────────────

const bool _ciPackageProof = bool.fromEnvironment('CRM3_CI_PACKAGE_PROOF');

class _CiPackageProofApp extends StatelessWidget {
  const _CiPackageProofApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'CRM-III BAF Ops\nCI package proof',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

final _isarSchemas = [
  ChargeSchema,
  MaintenanceRecordSchema,
  JobTemplateSchema,
  JobExecutionSchema,
  JobDiaryEntrySchema,
  JobModuleInstanceSchema,
  TemplatePackageSchema,
  TemplateVersionSchema,
  TemplatePublishAuditSchema,
  BafKnowledgeRowSchema,
  BafKnowledgeMatrixMetaStoreSchema,
  OperationalDirectiveSchema,
  AuditEventSchema,
  SyncRejectionSchema,

  // Abnormalities module schemas.
  AbnormalityTypeSchema,
  ChargeAbnormalitySchema,

  // Maintenance workflow control-plane schemas.
  WorkflowAggregateRecordSchema,
  JobLaneRecordSchema,
  ComplianceRequestRecordSchema,
  ComplianceAttemptRecordSchema,
  EquipmentStatusRecordSchema,
  EquipmentPromptRecordSchema,
  WorkflowEventRecordSchema,
  WorkflowCommandRecordSchema,
  WorkflowCommandReceiptRecordSchema,
];

Future<Isar> _openLocalIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  final preOpenProvenance = await readPrivacySafeIsarProvenanceInventory(
    databaseDirectoryPath: dir.path,
  );
  preserveStartupPreOpenIsarProvenanceInventory(preOpenProvenance);
  final schemaPreparation = await ensureIsarSchemaBeforeOpen(
    databaseDirectoryPath: dir.path,
  );
  final localIsar = await Isar.open(_isarSchemas, directory: dir.path);
  try {
    final repair = await repairPlannedJobLocalLinks(localIsar);
    if (repair.changed) {
      debugPrint(
        '🧭 Repaired transported planned-job local links: '
        'modules=${repair.repairedModules}, '
        'diaryExecutionLinks=${repair.repairedDiaryExecutionLinks}, '
        'diaryModuleLinks=${repair.repairedDiaryModuleLinks}',
      );
    }
    final assuranceRepair = await repairLegacyOperationalAssuranceRequests(
      localIsar,
    );
    if (assuranceRepair.changed) {
      debugPrint(
        'Normalized legacy assurance requests: '
        '${assuranceRepair.normalizedLegacyRequests}',
      );
    }
    final identityRepair = await repairGovernedAssetIdentityForSchemaUpgrade(
      localIsar,
      fromVersion: schemaPreparation.result.fromVersion,
      toVersion: schemaPreparation.result.toVersion,
    );
    if (identityRepair?.changed ?? false) {
      debugPrint(
        'Quarantined legacy governed-asset projections: '
        'workflows=${identityRepair!.removedWorkflowProjections}, '
        'equipment=${identityRepair.removedEquipmentProjections}',
      );
    }
    final committedMarker = await schemaPreparation.commitAfterSuccessfulOpen();
    debugPrint(
      'Isar provenance committed: '
      'schema=${committedMarker.schemaVersion}, '
      'origin=${committedMarker.origin.wireName}',
    );
    return localIsar;
  } catch (_) {
    await localIsar.close();
    rethrow;
  }
}

class StartupFailure {
  final String stage;
  final Object error;
  final StackTrace stackTrace;
  final DateTime occurredAt;
  final String? diagnosticsFilePath;
  final String? schemaProvenanceSnapshotJson;
  final IsarInstalledStoreProvenanceInventory?
  installedStoreProvenanceInventory;

  StartupFailure({
    required this.stage,
    required this.error,
    required this.stackTrace,
    DateTime? occurredAt,
    this.diagnosticsFilePath,
    this.schemaProvenanceSnapshotJson,
    this.installedStoreProvenanceInventory,
  }) : occurredAt = occurredAt ?? DateTime.now();

  String get diagnosticsText {
    return [
      'CRM-III BAF Ops startup failure',
      'stage: $stage',
      'occurredAt: ${occurredAt.toIso8601String()}',
      'errorType: ${error.runtimeType}',
      'error: $error',
      if (diagnosticsFilePath != null)
        'diagnosticsFilePath: $diagnosticsFilePath',
      if (schemaProvenanceSnapshotJson != null)
        'schemaProvenanceSnapshot: $schemaProvenanceSnapshotJson',
      if (installedStoreProvenanceInventory != null)
        'installedStoreProvenance: '
            '${jsonEncode(installedStoreProvenanceInventory!.toMap())}',
      'stackTrace:',
      stackTrace.toString(),
    ].join('\n');
  }

  StartupFailure copyWith({
    String? diagnosticsFilePath,
    String? schemaProvenanceSnapshotJson,
    IsarInstalledStoreProvenanceInventory? installedStoreProvenanceInventory,
  }) {
    return StartupFailure(
      stage: stage,
      error: error,
      stackTrace: stackTrace,
      occurredAt: occurredAt,
      diagnosticsFilePath: diagnosticsFilePath ?? this.diagnosticsFilePath,
      schemaProvenanceSnapshotJson:
          schemaProvenanceSnapshotJson ?? this.schemaProvenanceSnapshotJson,
      installedStoreProvenanceInventory:
          installedStoreProvenanceInventory ??
          this.installedStoreProvenanceInventory,
    );
  }

  bool get isLocalDatabaseStage =>
      stage.startsWith('local_database') ||
      stage.startsWith('isar_') ||
      stage.contains('database');

  IsarSchemaMigrationException? get schemaProvenanceFailure =>
      error is IsarSchemaMigrationException
          ? error as IsarSchemaMigrationException
          : null;

  String? get schemaProvenanceReasonCode {
    final currentError = error;
    if (currentError is IsarSchemaMigrationException) {
      return currentError.reasonCode;
    }
    if (currentError is IsarSchemaMarkerFormatException) {
      return currentError.reasonCode;
    }
    return null;
  }

  bool get isSchemaProvenanceFailure => schemaProvenanceReasonCode != null;

  String _jsonEscape(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  String toRecoveryManifestJsonText() {
    final provenanceFailure = schemaProvenanceFailure;
    final provenanceReasonCode = schemaProvenanceReasonCode;
    final escapedError = _jsonEscape(error.toString());
    final escapedPath =
        diagnosticsFilePath == null
            ? 'null'
            : '"${_jsonEscape(diagnosticsFilePath!)}"';
    final provenanceSnapshot = schemaProvenanceSnapshotJson ?? 'null';
    final installedStoreProvenance =
        installedStoreProvenanceInventory == null
            ? 'null'
            : jsonEncode(installedStoreProvenanceInventory!.toMap());
    final mode =
        isLocalDatabaseStage
            ? 'startup_isar_open_failed'
            : 'startup_core_initialization_failed';
    final isarOpenStatus = isLocalDatabaseStage ? 'failed' : 'not_attempted';
    final schemaProvenanceStatus =
        provenanceReasonCode == null ? 'not_evaluated' : 'rejected_before_open';
    final schemaProvenanceReason =
        provenanceReasonCode == null
            ? 'null'
            : '"${_jsonEscape(provenanceReasonCode)}"';
    final markerDisposition =
        provenanceFailure?.markerDisposition == null
            ? 'null'
            : '"${_jsonEscape(provenanceFailure!.markerDisposition!)}"';
    final storedSchemaVersion =
        provenanceFailure?.storedVersion?.toString() ?? 'null';
    final targetSchemaVersion =
        provenanceFailure?.targetVersion.toString() ?? 'null';
    final hadExistingLocalStore =
        provenanceFailure?.hasExistingLocalStore?.toString() ?? 'null';
    final policy =
        provenanceFailure != null
            ? 'provenance rejected before Isar open; preserve raw files and marker evidence before governed recovery'
            : isLocalDatabaseStage
            ? 'backup raw DB files before rebuild; Firestore restores synced records only'
            : 'capture diagnostics and review Firebase/startup configuration; local DB recovery not attempted';
    return '''{
  "app": "CRM-III BAF Ops",
  "mode": "$mode",
  "stage": "$stage",
  "occurredAt": "${occurredAt.toIso8601String()}",
  "errorType": "${error.runtimeType}",
  "error": "$escapedError",
  "diagnosticsFilePath": $escapedPath,
  "isarOpenStatus": "$isarOpenStatus",
  "schemaProvenanceStatus": "$schemaProvenanceStatus",
  "schemaProvenanceReason": $schemaProvenanceReason,
  "markerDisposition": $markerDisposition,
  "storedSchemaVersion": $storedSchemaVersion,
  "targetSchemaVersion": $targetSchemaVersion,
  "hadExistingLocalStore": $hadExistingLocalStore,
  "schemaProvenanceSnapshot": $provenanceSnapshot,
  "installedStoreProvenance": $installedStoreProvenance,
  "rowLevelInventoryAvailable": false,
  "policy": "$policy"
}''';
  }
}

Future<StartupFailure> _captureStartupFailure({
  required String stage,
  required Object error,
  required StackTrace stackTrace,
}) async {
  var failure = StartupFailure(
    stage: stage,
    error: error,
    stackTrace: stackTrace,
    installedStoreProvenanceInventory:
        readStartupPreOpenIsarProvenanceInventory(),
  );
  if (!kIsWeb && failure.isLocalDatabaseStage) {
    try {
      final snapshot = await readIsarSchemaProvenanceSnapshotJson();
      failure = failure.copyWith(schemaProvenanceSnapshotJson: snapshot);
    } catch (snapshotError, snapshotStack) {
      debugPrint(
        'Could not capture Isar schema provenance marker evidence: '
        '$snapshotError',
      );
      debugPrint('$snapshotStack');
    }
  }
  if (!kIsWeb) {
    try {
      final diagnostic = await writeIsarStartupFailureDiagnostics(
        diagnosticsText: failure.diagnosticsText,
      );
      failure = failure.copyWith(diagnosticsFilePath: diagnostic.filePath);
    } catch (diagError, diagStack) {
      debugPrint('⚠️ Could not write Isar startup diagnostics: $diagError');
      debugPrint('$diagStack');
      unawaited(
        AppLogger.recordNonFatalError(
          diagError,
          diagStack,
          reason: 'startup_diagnostics_write_failed',
          context: const {
            'app_area': 'startup',
            'startup_stage': 'diagnostics_write',
          },
        ),
      );
    }
  }

  await AppLogger.recordNonFatalError(
    error,
    stackTrace,
    reason: 'startup_failure_$stage',
    context: {
      'app_area': 'startup',
      'startup_stage': stage,
      'startup_failure': true,
      'isar_open_status':
          failure.isLocalDatabaseStage ? 'failed' : 'not_attempted',
      'diagnostics_written': failure.diagnosticsFilePath != null,
      'schema_provenance_failure': failure.isSchemaProvenanceFailure,
      if (failure.schemaProvenanceReasonCode case final reason?)
        'schema_provenance_reason': reason,
    },
  );

  return failure;
}

Future<StartupFailure?> _initializeFirebaseAndCrashReporting() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('❌ Firebase initialization failed before app startup: $e');
    debugPrint('$st');
    return _captureStartupFailure(
      stage: 'firebase_initialize',
      error: e,
      stackTrace: st,
    );
  }

  late final Crm3AppCheckPlan appCheckPlan;
  try {
    appCheckPlan = await activateCrm3AppCheck();
  } catch (e, st) {
    debugPrint('❌ Firebase App Check activation failed before app startup: $e');
    debugPrint('$st');
    return _captureStartupFailure(
      stage: 'app_check_activate',
      error: e,
      stackTrace: st,
    );
  }

  try {
    await AppLogger.init(throwOnFailure: true);
    await AppLogger.setCustomKeys({
      'startup_stage': 'firebase_initialized',
      'app_check_enabled': appCheckPlan.enabled,
      'app_check_provider': appCheckPlan.provider.name,
    });
    installGlobalCrashReportingHandlers();
  } catch (e, st) {
    debugPrint(
      '❌ Crash reporting initialization failed before app startup: $e',
    );
    debugPrint('$st');
    return _captureStartupFailure(
      stage: 'app_logger_init',
      error: e,
      stackTrace: st,
    );
  }

  return null;
}

Future<void> _requestStartupNotificationPermission() async {
  if (kIsWeb) {
    return;
  }

  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e, st) {
    debugPrint('⚠️ Notification permission request failed: $e');
    debugPrint('$st');
    unawaited(
      AppLogger.recordNonFatalError(
        e,
        st,
        reason: 'notification_permission_request_failed',
        context: const {
          'app_area': 'startup',
          'startup_stage': 'notification_permission',
        },
      ),
    );
  }
}

Future<StartupFailure?> _initializeLocalDatabase() async {
  if (kIsWeb) {
    return null;
  }

  try {
    isar = await _openLocalIsar();
    unawaited(
      AppLogger.setCustomKeys(const {
        'startup_stage': 'local_database_opened',
        'isar_open_status': 'opened',
      }),
    );
    return null;
  } catch (e, st) {
    final failure = await _captureStartupFailure(
      stage: 'local_database_open',
      error: e,
      stackTrace: st,
    );
    debugPrint('❌ Failed to open local Isar database: $e');
    debugPrint('$st');
    return failure;
  }
}

void main() {
  if (_ciPackageProof) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const _CiPackageProofApp());
    return;
  }

  runCrashReportingZoned(() async {
    WidgetsFlutterBinding.ensureInitialized();
    var startupFailure = await _initializeFirebaseAndCrashReporting();

    if (startupFailure == null) {
      await _requestStartupNotificationPermission();
      startupFailure = await _initializeLocalDatabase();
    }

    runApp(ProviderScope(child: CrmBafApp(startupFailure: startupFailure)));
  });
}

void _showStartupSnack(
  BuildContext context,
  String message, {
  Color? backgroundColor,
}) {
  if (!context.mounted) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: backgroundColor),
  );
}

// ─────────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────────

class CrmBafApp extends ConsumerStatefulWidget {
  final StartupFailure? startupFailure;

  const CrmBafApp({super.key, this.startupFailure});

  @override
  ConsumerState<CrmBafApp> createState() => _CrmBafAppState();
}

class _CrmBafAppState extends ConsumerState<CrmBafApp> {
  StartupFailure? _startupFailure;
  bool _isRetryingLocalDatabaseOpen = false;
  bool _isBackingUpLocalDatabase = false;
  bool _isRebuildingLocalDatabase = false;
  String? _startupRecoveryMessage;

  @override
  void initState() {
    super.initState();
    _startupFailure = widget.startupFailure;
  }

  @override
  void didUpdateWidget(CrmBafApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startupFailure != widget.startupFailure) {
      _startupFailure = widget.startupFailure;
      _startupRecoveryMessage = null;
    }
  }

  Future<void> _retryLocalDatabaseOpen() async {
    if (kIsWeb ||
        _isRetryingLocalDatabaseOpen ||
        _isBackingUpLocalDatabase ||
        _isRebuildingLocalDatabase) {
      return;
    }

    setState(() => _isRetryingLocalDatabaseOpen = true);

    try {
      isar = await _openLocalIsar();
      if (!mounted) {
        return;
      }
      setState(() {
        _startupFailure = null;
      });
      unawaited(
        AppLogger.setCustomKeys(const {
          'startup_stage': 'local_database_retry_opened',
          'isar_open_status': 'opened_after_retry',
        }),
      );
    } catch (e, st) {
      if (!mounted) {
        return;
      }
      final failure = await _captureStartupFailure(
        stage: 'local_database_retry',
        error: e,
        stackTrace: st,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _startupFailure = failure;
      });
      debugPrint('❌ Failed to reopen local Isar database: $e');
      debugPrint('$st');
    } finally {
      if (mounted) {
        setState(() => _isRetryingLocalDatabaseOpen = false);
      }
    }
  }

  Future<void> _backupLocalDatabaseForRecovery() async {
    final failure = _startupFailure;
    if (failure == null ||
        kIsWeb ||
        _isBackingUpLocalDatabase ||
        _isRetryingLocalDatabaseOpen ||
        _isRebuildingLocalDatabase) {
      return;
    }

    setState(() {
      _isBackingUpLocalDatabase = true;
      _startupRecoveryMessage = null;
    });

    try {
      final result = await createIsarRecoveryPackage(
        diagnosticsText: failure.diagnosticsText,
        manifestJsonText: failure.toRecoveryManifestJsonText(),
        reason: 'startup_open_failure_backup',
      );
      if (!mounted) {
        return;
      }
      await Clipboard.setData(ClipboardData(text: result.directoryPath));
      if (!mounted) {
        return;
      }
      setState(() {
        _startupRecoveryMessage =
            'Recovery package created at ${result.directoryPath}. ${result.copiedFileCount} likely Isar file(s) copied. Folder path copied to clipboard.';
      });
    } catch (e, st) {
      debugPrint('❌ Failed to create Isar recovery package: $e');
      debugPrint('$st');
      unawaited(
        AppLogger.recordNonFatalError(
          e,
          st,
          reason: 'isar_recovery_package_failed',
          context: const {
            'app_area': 'startup_recovery',
            'startup_stage': 'recovery_backup',
          },
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _startupRecoveryMessage = 'Could not create recovery package: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isBackingUpLocalDatabase = false);
      }
    }
  }

  Future<void> _confirmAndRebuildLocalDatabase() async {
    final failure = _startupFailure;
    if (failure == null ||
        kIsWeb ||
        _isRebuildingLocalDatabase ||
        _isBackingUpLocalDatabase ||
        _isRetryingLocalDatabaseOpen) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RebuildLocalDatabaseConfirmDialog(),
    );

    if (!mounted || confirmed != true) {
      return;
    }
    await _rebuildLocalDatabaseAfterRecoveryBackup(failure);
  }

  Future<void> _rebuildLocalDatabaseAfterRecoveryBackup(
    StartupFailure failure,
  ) async {
    if (kIsWeb ||
        _isRebuildingLocalDatabase ||
        _isBackingUpLocalDatabase ||
        _isRetryingLocalDatabaseOpen) {
      return;
    }

    setState(() {
      _isRebuildingLocalDatabase = true;
      _startupRecoveryMessage = null;
    });

    try {
      final result = await rebuildLocalDatabaseAfterBackup(
        diagnosticsText: failure.diagnosticsText,
        manifestJsonText: failure.toRecoveryManifestJsonText(),
        reason: 'startup_open_failure_rebuild',
      );

      if (!result.success) {
        if (!mounted) {
          return;
        }
        setState(() {
          _startupRecoveryMessage =
              'Local rebuild was not completed. Existing DB files were left in place. Recovery report: ${result.reportPath}';
        });
        return;
      }

      isar = await _openLocalIsar();
      if (!mounted) {
        return;
      }
      setState(() {
        _startupFailure = null;
        _startupRecoveryMessage =
            'Local database rebuilt after backup. Recovery package: ${result.recoveryDirectoryPath}. Run/verify cloud sync before plant use.';
      });
    } catch (e, st) {
      debugPrint('❌ Failed controlled Isar rebuild: $e');
      debugPrint('$st');
      unawaited(
        AppLogger.recordNonFatalError(
          e,
          st,
          reason: 'isar_controlled_rebuild_failed',
          context: const {
            'app_area': 'startup_recovery',
            'startup_stage': 'controlled_rebuild',
          },
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _startupRecoveryMessage = 'Could not rebuild local database: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isRebuildingLocalDatabase = false);
      }
    }
  }

  Widget _buildStartupHome() {
    final failure = _startupFailure;
    if (failure == null) {
      return const AuthGate();
    }

    if (!failure.isLocalDatabaseStage) {
      return _CoreStartupErrorScreen(failure: failure);
    }

    return _LocalDatabaseStartupErrorScreen(
      failure: failure,
      isRetrying: _isRetryingLocalDatabaseOpen,
      isBackingUp: _isBackingUpLocalDatabase,
      isRebuilding: _isRebuildingLocalDatabase,
      recoveryMessage: _startupRecoveryMessage,
      onRetry: _retryLocalDatabaseOpen,
      onBackup: _backupLocalDatabaseForRecovery,
      onRebuild: _confirmAndRebuildLocalDatabase,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_startupFailure == null) {
      ref.watch(crashlyticsIdentitySyncProvider);
      ref.watch(notificationInstallationSyncProvider);
    }

    return MaterialApp(
      title: BafBrand.productName,
      debugShowCheckedModeBanner: false,
      theme: BafAppTheme.light,
      home: _buildStartupHome(),
    );
  }
}

class _RebuildLocalDatabaseConfirmDialog extends StatefulWidget {
  const _RebuildLocalDatabaseConfirmDialog();

  @override
  State<_RebuildLocalDatabaseConfirmDialog> createState() =>
      _RebuildLocalDatabaseConfirmDialogState();
}

class _RebuildLocalDatabaseConfirmDialogState
    extends State<_RebuildLocalDatabaseConfirmDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleChanged);
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmation = _controller.text.trim().toUpperCase();
    final canSubmit = confirmation == 'REBUILD';

    return AlertDialog(
      title: const Text('Rebuild local database after backup?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will first create a recovery package with diagnostics and raw Isar file backup, then move the current local Isar store aside and try to open a clean local database.',
              ),
              const SizedBox(height: BafSpacing.md),
              const Text(
                'Cloud-synced records can be pulled again. Local-only unsynced evidence may not return automatically and may exist only in the backup package.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: BafSpacing.md),
              const Text('Type REBUILD to continue.'),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Confirmation',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: BafColors.danger),
          onPressed: canSubmit ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Create backup & rebuild'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AUTH GATE
// ─────────────────────────────────────────────────────────────

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading:
          () => const _FullScreenStatus(
            icon: Icons.lock_open_rounded,
            title: 'Checking sign-in',
            message: 'Verifying your Google session…',
            showProgress: true,
          ),
      error: (e, _) => _AuthErrorScreen(title: 'Auth error', message: '$e'),
      data: (firebaseUser) {
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        final appUser = ref.watch(currentAppUserProvider);

        return appUser.when(
          loading:
              () => const _FullScreenStatus(
                icon: Icons.verified_user_rounded,
                title: 'Checking access',
                message: 'Loading your BAF profile and approval status…',
                showProgress: true,
              ),
          error: (e, _) {
            if (e is PersistedDataFormatException) {
              return const _AuthErrorScreen(
                title: 'Profile needs repair',
                message:
                    'Your access profile has incomplete or malformed identity history. No app access was granted. Ask an administrator to repair the profile, then reopen the app.',
              );
            }
            return _AuthErrorScreen(title: 'User profile error', message: '$e');
          },
          data: (user) {
            if (user == null) {
              return _ProfileBootstrapScreen(firebaseUser: firebaseUser);
            }

            if (!user.isApproved) {
              return const PendingApprovalScreen();
            }

            return _StartupSyncGate(appUser: user);
          },
        );
      },
    );
  }
}

class _ProfileBootstrapScreen extends ConsumerStatefulWidget {
  final User firebaseUser;

  const _ProfileBootstrapScreen({required this.firebaseUser});

  @override
  ConsumerState<_ProfileBootstrapScreen> createState() =>
      _ProfileBootstrapScreenState();
}

class _ProfileBootstrapScreenState
    extends ConsumerState<_ProfileBootstrapScreen> {
  bool _started = false;
  bool _isRepairing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ensureProfileOnce();
  }

  @override
  void didUpdateWidget(_ProfileBootstrapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseUser.uid != widget.firebaseUser.uid) {
      _started = false;
      _errorMessage = null;
      _ensureProfileOnce();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _ProfileBootstrapErrorScreen(
        message: _errorMessage!,
        isRetrying: _isRepairing,
        onRetry: _repairProfile,
        onSignOut: () => ref.read(authServiceProvider).signOut(),
      );
    }

    return const _FullScreenStatus(
      icon: Icons.manage_accounts_rounded,
      title: 'Setting up your profile',
      message: 'Creating or repairing your pending approval profile…',
      showProgress: true,
    );
  }

  void _ensureProfileOnce() {
    if (_started) {
      return;
    }
    _started = true;
    _repairProfile();
  }

  Future<void> _repairProfile() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isRepairing = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authServiceProvider)
          .ensureUserDocument(firebaseUser: widget.firebaseUser);
      ref.invalidate(currentAppUserProvider);
    } catch (e, st) {
      unawaited(
        AppLogger.recordNonFatalError(
          e,
          st,
          reason: 'profile_bootstrap_repair_failed',
          context: const {
            'app_area': 'auth',
            'auth_stage': 'profile_bootstrap',
          },
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _isRepairing = false);
      }
    }
  }
}

class _StartupSyncGate extends ConsumerStatefulWidget {
  final AppUser appUser;

  const _StartupSyncGate({required this.appUser});

  @override
  ConsumerState<_StartupSyncGate> createState() => _StartupSyncGateState();
}

class _StartupSyncGateState extends ConsumerState<_StartupSyncGate>
    with WidgetsBindingObserver {
  bool _syncStarted = false;
  bool _backgroundServicesStarted = false;
  LiveRemoteSyncService? _liveRemoteSyncService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startBackgroundSyncServices();
      _startInitialSyncOnce();
    });
  }

  @override
  void didUpdateWidget(_StartupSyncGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldScope = LiveMaintenanceMirrorScope.forUser(oldWidget.appUser);
    final newScope = LiveMaintenanceMirrorScope.forUser(widget.appUser);
    if (oldScope.scopeKey != newScope.scopeKey) {
      _startOrUpdateLiveMaintenanceMirror();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final liveService = _liveRemoteSyncService;
    if (liveService == null) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      liveService.resumeAfterLifecyclePause();
      return;
    }

    liveService.pauseForLifecycle(reason: 'app_${state.name}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(autoSyncServiceProvider).stop();
    _liveRemoteSyncService?.dispose();
    _liveRemoteSyncService = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }

  void _startInitialSyncOnce() {
    if (_syncStarted || ref.read(syncOnceProvider)) {
      return;
    }
    _syncStarted = true;

    Future.microtask(() async {
      try {
        final syncOutcome = await ref
            .read(syncCoordinatorProvider)
            .runFullSyncWithResult(reason: 'auth_gate', force: true);

        if (!mounted) {
          return;
        }

        if (syncOutcome.isSuccessful) {
          ref.read(syncOnceProvider.notifier).state = true;
        } else {
          _syncStarted = false;
        }
      } catch (e, st) {
        unawaited(
          AppLogger.recordNonFatalError(
            e,
            st,
            reason: 'startup_sync_gate_failed',
            context: const {
              'app_area': 'sync',
              'sync_phase': 'initial_full_sync',
            },
          ),
        );
        if (!mounted) {
          return;
        }
        _syncStarted = false;
      }
    });
  }

  void _startBackgroundSyncServices() {
    if (_backgroundServicesStarted) {
      return;
    }
    _backgroundServicesStarted = true;

    Future.microtask(() {
      try {
        if (!mounted) {
          return;
        }
        ref.read(autoSyncServiceProvider).start();

        _startOrUpdateLiveMaintenanceMirror();
      } catch (e, st) {
        unawaited(
          AppLogger.recordNonFatalError(
            e,
            st,
            reason: 'background_sync_services_start_failed',
            context: const {
              'app_area': 'sync',
              'sync_phase': 'background_services_start',
            },
          ),
        );
        _backgroundServicesStarted = false;
      }
    });
  }

  void _startOrUpdateLiveMaintenanceMirror() {
    if (kIsWeb || !mounted) {
      return;
    }

    _liveRemoteSyncService ??= LiveRemoteSyncService(isar, ref.read);
    _liveRemoteSyncService!.startMaintenanceOpenTicketMirror(
      actor: widget.appUser,
    );
  }
}

class _CoreStartupErrorScreen extends StatelessWidget {
  final StartupFailure failure;

  const _CoreStartupErrorScreen({required this.failure});

  @override
  Widget build(BuildContext context) {
    final errorText = failure.error.toString();
    final compactError =
        errorText.length <= 360 ? errorText : '${errorText.substring(0, 360)}…';

    return _FullScreenStatus(
      icon: Icons.warning_amber_rounded,
      title: 'App startup failed',
      message:
          'The app could not complete core startup before opening the normal workflow. '
          'Do not clear app data or uninstall the app before Admin/SI review, because local evidence may still exist on this device.\n\n'
          'Stage: ${failure.stage}\n'
          'Recorded: ${failure.occurredAt.toLocal().toIso8601String()}\n'
          'Error type: ${failure.error.runtimeType}\n'
          'Error: $compactError'
          '${failure.diagnosticsFilePath == null ? '' : '\nDiagnostics file: ${failure.diagnosticsFilePath}'}',
      color: BafColors.danger,
      primaryActionLabel: 'Copy Diagnostics',
      primaryAction: () async {
        await Clipboard.setData(ClipboardData(text: failure.diagnosticsText));
        if (!context.mounted) {
          return;
        }
        _showStartupSnack(
          context,
          'Startup diagnostics copied.',
          backgroundColor: BafColors.sync,
        );
      },
    );
  }
}

class _LocalDatabaseStartupErrorScreen extends StatelessWidget {
  final StartupFailure failure;
  final bool isRetrying;
  final bool isBackingUp;
  final bool isRebuilding;
  final String? recoveryMessage;
  final VoidCallback onRetry;
  final VoidCallback onBackup;
  final VoidCallback onRebuild;

  const _LocalDatabaseStartupErrorScreen({
    required this.failure,
    required this.isRetrying,
    required this.isBackingUp,
    required this.isRebuilding,
    required this.recoveryMessage,
    required this.onRetry,
    required this.onBackup,
    required this.onRebuild,
  });

  @override
  Widget build(BuildContext context) {
    final errorText = failure.error.toString();
    final compactError =
        errorText.length <= 360 ? errorText : '${errorText.substring(0, 360)}…';
    final isLocalDatabaseFailure = failure.isLocalDatabaseStage;
    final isSchemaProvenanceFailure = failure.isSchemaProvenanceFailure;

    final title =
        isSchemaProvenanceFailure
            ? 'Local database provenance could not be verified'
            : isLocalDatabaseFailure
            ? 'Local database could not be opened'
            : 'App startup could not complete';
    final messagePrefix =
        isSchemaProvenanceFailure
            ? 'The app rejected the offline database before opening it because its schema provenance was absent, incomplete, malformed, or unsupported. The existing store was not automatically stamped.\n\n'
                'Do not uninstall the app or clear app data. Create a recovery package so authorized Admin/SI review can preserve the raw database and marker evidence before any governed rebuild or migration.\n\n'
            : isLocalDatabaseFailure
            ? 'The app could not open the offline Isar database. This can happen after a schema-stage app update or if the local store is damaged.\n\n'
                'Do not uninstall the app or clear app data before authorized Admin/SI recovery review, because unsynced plant-floor evidence may still exist only in local Isar files.\n\n'
                'First create a recovery package. Rebuild should happen only after backup; Firestore can restore synced cloud records, not local-only unsynced evidence.\n\n'
            : 'The app could not complete core startup before showing the sign-in flow. This can happen if Firebase configuration, crash reporting bootstrap, or another required startup service fails.\n\n'
                'Do not use the app for plant-floor evidence capture until Admin/SI support reviews the diagnostics. Local data has not been modified by this screen.\n\n';

    return _FullScreenStatus(
      icon: isLocalDatabaseFailure ? Icons.storage_rounded : Icons.cloud_off,
      title: title,
      message:
          '$messagePrefix'
          'Stage: ${failure.stage}\n'
          'Recorded: ${failure.occurredAt.toLocal().toIso8601String()}\n'
          'Error type: ${failure.error.runtimeType}\n'
          'Error: $compactError'
          '${failure.diagnosticsFilePath == null ? '' : '\nDiagnostics file: ${failure.diagnosticsFilePath}'}'
          '${recoveryMessage == null ? '' : '\n\nRecovery status: $recoveryMessage'}',
      color: BafColors.danger,
      secondaryActionLabel:
          isLocalDatabaseFailure
              ? isBackingUp
                  ? 'Backing up…'
                  : 'Create Recovery Package'
              : null,
      secondaryAction:
          isLocalDatabaseFailure && !isBackingUp && !isRebuilding && !isRetrying
              ? onBackup
              : null,
      tertiaryActionLabel: 'Copy Diagnostics',
      tertiaryAction: () async {
        await Clipboard.setData(ClipboardData(text: failure.diagnosticsText));
        if (!context.mounted) {
          return;
        }
        _showStartupSnack(
          context,
          'Startup diagnostics copied.',
          backgroundColor: BafColors.sync,
        );
      },
      primaryActionLabel:
          isLocalDatabaseFailure
              ? isRetrying
                  ? 'Retrying…'
                  : 'Retry Opening Database'
              : null,
      primaryAction:
          isLocalDatabaseFailure && !isRetrying && !isRebuilding && !isBackingUp
              ? onRetry
              : null,
      dangerActionLabel:
          isLocalDatabaseFailure
              ? isRebuilding
                  ? 'Rebuilding…'
                  : 'Backup & Rebuild Local DB'
              : null,
      dangerAction:
          isLocalDatabaseFailure && !isRetrying && !isBackingUp && !isRebuilding
              ? onRebuild
              : null,
    );
  }
}

class _AuthErrorScreen extends ConsumerWidget {
  final String title;
  final String message;

  const _AuthErrorScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _FullScreenStatus(
      icon: Icons.error_outline_rounded,
      title: title,
      message: message,
      color: BafColors.danger,
      primaryActionLabel: 'Sign Out',
      primaryAction: () => ref.read(authServiceProvider).signOut(),
    );
  }
}

class _ProfileBootstrapErrorScreen extends StatelessWidget {
  final String message;
  final bool isRetrying;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _ProfileBootstrapErrorScreen({
    required this.message,
    required this.isRetrying,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return _FullScreenStatus(
      icon: Icons.manage_accounts_rounded,
      title: 'Could not set up profile',
      message:
          'Your Google sign-in succeeded, but your app profile could not be created or repaired.\n\n$message',
      color: BafColors.danger,
      primaryActionLabel: isRetrying ? 'Retrying…' : 'Retry',
      primaryAction: isRetrying ? null : onRetry,
      secondaryActionLabel: 'Sign Out',
      secondaryAction: onSignOut,
    );
  }
}

class _FullScreenStatus extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final bool showProgress;
  final String? primaryActionLabel;
  final VoidCallback? primaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? secondaryAction;
  final String? tertiaryActionLabel;
  final VoidCallback? tertiaryAction;
  final String? dangerActionLabel;
  final VoidCallback? dangerAction;

  const _FullScreenStatus({
    required this.icon,
    required this.title,
    required this.message,
    this.color = BafColors.navySoft,
    this.showProgress = false,
    this.primaryActionLabel,
    this.primaryAction,
    this.secondaryActionLabel,
    this.secondaryAction,
    this.tertiaryActionLabel,
    this.tertiaryAction,
    this.dangerActionLabel,
    this.dangerAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BafSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(BafSpacing.xl),
                decoration: BoxDecoration(
                  color: BafColors.card,
                  borderRadius: BorderRadius.circular(BafRadius.xLarge),
                  border: Border.all(color: BafColors.border),
                  boxShadow: BafShadows.subtle,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BafBrandLockup(compact: true),
                    const SizedBox(height: BafSpacing.xl),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(BafRadius.xLarge),
                      ),
                      child: Icon(icon, size: 42, color: color),
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    if (showProgress) ...[
                      const SizedBox(height: BafSpacing.xl),
                      const CircularProgressIndicator(),
                    ],
                    if (primaryActionLabel != null ||
                        secondaryActionLabel != null ||
                        tertiaryActionLabel != null ||
                        dangerActionLabel != null) ...[
                      const SizedBox(height: BafSpacing.xl),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: BafSpacing.md,
                        runSpacing: BafSpacing.sm,
                        children: [
                          if (secondaryActionLabel != null)
                            OutlinedButton(
                              onPressed: secondaryAction,
                              child: Text(secondaryActionLabel!),
                            ),
                          if (tertiaryActionLabel != null)
                            OutlinedButton(
                              onPressed: tertiaryAction,
                              child: Text(tertiaryActionLabel!),
                            ),
                          if (primaryActionLabel != null)
                            FilledButton(
                              onPressed: primaryAction,
                              style: FilledButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(primaryActionLabel!),
                            ),
                          if (dangerActionLabel != null)
                            FilledButton(
                              onPressed: dangerAction,
                              style: FilledButton.styleFrom(
                                backgroundColor: BafColors.danger,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(dangerActionLabel!),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
