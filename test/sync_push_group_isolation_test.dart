import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/core/providers/sync_status_provider.dart';
import 'package:crm3_baf_ops/core/services/global_pull_service.dart';
import 'package:crm3_baf_ops/core/services/local_recovery_session_guard.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/core/services/sync_push_snapshot.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_pull_service.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_uncertain_retry_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/planned_job_server_completion_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets(
    'reconciled execution conflict keeps dependent work visibly pending until the next run',
    (tester) async {
      final rig = _Rig()
        ..localExecution = _execution(deleted: true)
        ..remoteExecution = _execution(deleted: false)
        ..pendingModule = (JobModuleInstance()
          ..id = 12
          ..firestoreId = 'pending-module'
          ..jobExecutionFirestoreId = 'reconciled-job'
          ..moduleTitle = 'Inspection'
          ..draftNote = 'Unsent inspection evidence'
          ..createdAt = DateTime.utc(2026, 9, 20)
          ..updatedAt = DateTime.utc(2026, 9, 21))
        ..pushType = true;
      final pendingBefore = rig.pendingModule!.toMap();
      final pull = _Pull();
      final owner = Provider<SyncCoordinator>((ref) {
        final coordinator = SyncCoordinator(
          ref,
          rig.service,
          pull,
          LocalRecoverySessionGuard(),
          connectivity: _Connectivity(),
          runGuardFactory: () => SyncRunGuard(() {}),
        );
        ref.onDispose(coordinator.dispose);
        return coordinator;
      });
      final container = ProviderContainer(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
          workflowUncertainRetryServiceProvider.overrideWithValue(_Retry()),
          workflowRepositoryProvider.overrideWithValue(_WorkflowRepository()),
          workflowPullServiceProvider.overrideWithValue(_WorkflowPull()),
        ],
      );
      addTearDown(container.dispose);
      final coordinator = container.read(owner);
      final outcome = await coordinator.runFullSyncWithResult(force: true);

      expect(rig.localExecution!.isDeleted, isFalse);
      expect(rig.localExecution!.isSynced, isTrue);
      expect(rig.audits.single.before!['isDeleted'], isTrue);
      expect(rig.audits.single.after!['isDeleted'], isFalse);
      expect(rig.service.lastConflictCount, 1);
      expect(rig.service.lastFailureCount, 0);
      expect(rig.service.lastDeferredPushStages, {
        'job_diary',
        'job_module',
        'job_execution_closure',
      });
      expect(
        rig.visits,
        _allStages.where(
          (stage) => !['diary', 'modules', 'closures'].contains(stage),
        ),
      );
      expect(rig.moduleWrites, isEmpty);
      expect(rig.pendingModule!.isSynced, isFalse);
      expect(rig.pendingModule!.toMap(), pendingBefore);
      expect(
        rig.typeWriteCalls,
        1,
        reason: 'independent work still progresses',
      );
      expect(pull.calls, 1, reason: 'the canonical refresh still completes');
      expect(outcome, SyncRequestOutcome.partial);
      final health = container.read(syncRunHealthProvider);
      expect(health.lastSucceeded, isFalse);
      expect(health.lastPartiallySucceeded, isTrue);
      expect(health.deferredStageCount, 3);
      expect(
        health.failureCount,
        0,
        reason: 'reconciliation is not a failed write',
      );
      expect(health.lastError, contains('deferred'));
      await tester.pump(const Duration(seconds: 6));
      expect(container.read(syncStatusProvider), SyncStatus.partial);

      rig.visits.clear();
      expect(
        await coordinator.runFullSyncWithResult(force: true),
        SyncRequestOutcome.succeeded,
      );
      expect(rig.visits, _allStages);
      expect(rig.moduleWrites.single, pendingBefore);
      expect(rig.pendingModule!.isSynced, isTrue);
      expect(rig.service.lastConflictCount, 0);
      expect(rig.service.lastDeferredPushStages, isEmpty);
      expect(pull.calls, 2);
      expect(container.read(syncRunHealthProvider).lastError, isNull);
      expect(container.read(syncRunHealthProvider).deferredStageCount, 0);
      expect(
        container.read(syncRunHealthProvider).lastPartiallySucceeded,
        isFalse,
      );
      coordinator.dispose();
    },
  );

  test(
    'an early batch failure preserves order and attempts independent pushes',
    () async {
      final rig = _Rig()
        ..failures['tickets'] = StateError('unreadable ticket batch');
      await rig.service.syncAll();
      expect(rig.visits, _allStages);
      expect(rig.service.lastFailureCount, 1);
      expect(rig.service.lastFailureDetails.single.entityType, 'maintenance');
      expect(
        rig.service.lastFailureDetails.single.message,
        contains('unreadable ticket batch'),
      );
      expect(
        rig.service.lastSuccessCount,
        1,
        reason: 'audit is still attempted',
      );
    },
  );

  for (final failed in ['templates', 'versions', 'packages']) {
    test('$failed failure holds dependent publication work only', () async {
      final rig = _Rig()..failures[failed] = StateError('batch unavailable');
      await rig.service.syncAll();
      final failedIndex = _allStages.indexOf(failed);
      expect(rig.visits, [
        ..._allStages.take(failedIndex + 1),
        ..._allStages.skip(_allStages.indexOf('knowledge')),
      ]);
      expect(rig.service.lastFailureCount, 1);
    });
  }

  for (final failed in ['executions', 'diary', 'modules']) {
    test('$failed batch failure never submits dependent job closure', () async {
      final rig = _Rig()..failures[failed] = StateError('batch unavailable');
      await rig.service.syncAll();
      final failedIndex = _allStages.indexOf(failed);
      expect(rig.visits, [
        ..._allStages.take(failedIndex + 1),
        ..._allStages.skip(_allStages.indexOf('directives')),
      ]);
      expect(rig.service.lastFailureCount, 1);
    });
  }

  test('a caught per-record module failure also prevents closure', () async {
    final rig = _Rig()..badModule = true;
    await rig.service.syncAll();
    expect(rig.visits, _allStages.where((stage) => stage != 'closures'));
    expect(rig.service.lastFailureCount, 1);
    expect(rig.service.lastFailureDetails.single.entityType, 'job_module');
  });

  test(
    'a caught per-record type failure holds dependent events but runs audit',
    () async {
      final rig = _Rig()..badType = true;
      await rig.service.syncAll();
      expect(rig.visits, _allStages.where((stage) => stage != 'abnormalities'));
      expect(rig.service.lastFailureCount, 1);
      expect(rig.service.lastSuccessCount, 1);
    },
  );

  test(
    'unrelated failures aggregate without hiding successful independent work',
    () async {
      final rig = _Rig()
        ..failures['tickets'] = StateError('tickets failed')
        ..failures['directives'] = StateError('directives failed')
        ..failures['types'] = StateError('types failed');
      await rig.service.syncAll();
      expect(rig.visits, _allStages.where((stage) => stage != 'abnormalities'));
      expect(rig.service.lastFailureCount, 3);
      expect(rig.service.lastFailureDetails, hasLength(3));
      expect(rig.service.lastSuccessCount, 1);
    },
  );

  test(
    'an isolated audit failure leaves prior successful pushes counted',
    () async {
      final rig = _Rig()..failures['audit'] = StateError('audit failed');
      await rig.service.syncAll();
      expect(rig.visits, _allStages);
      expect(rig.service.lastFailureCount, 1);
      expect(rig.service.lastFailureDetails.single.entityType, 'audit_event');
    },
  );

  for (final error in <Object>[
    const SyncRunAborted('account changed'),
    IsarError('local database is closed'),
    FirebaseAuthException(code: 'unauthenticated'),
  ]) {
    test(
      'fatal ${error.runtimeType} inside a caught domain stops the run',
      () async {
        final rig = _Rig()..failures['knowledge'] = error;
        await expectLater(
          rig.service.syncAll(),
          throwsA(anyOf(isA<SyncRunAborted>(), isA<IsarError>())),
        );
        expect(
          rig.visits,
          _allStages.take(_allStages.indexOf('knowledge') + 1),
        );
        expect(rig.service.lastFailureDetails, isEmpty);
        rig.failures.clear();
        rig.visits.clear();
        await rig.service.syncAll();
        expect(
          rig.visits,
          _allStages,
          reason: 'fatal cleanup must release the run lock',
        );
      },
    );
  }

  test(
    'account switch after an awaited read stops before the next domain',
    () async {
      final rig = _Rig();
      rig.onVisit = (stage) {
        if (stage == 'tickets') rig.auth.actor = null;
      };
      await expectLater(rig.service.syncAll(), throwsA(isA<SyncRunAborted>()));
      expect(rig.visits, ['tickets']);
      expect(rig.service.lastFailureDetails, isEmpty);
    },
  );

  test(
    'session guard invalidation in row read prevents remote write and audit',
    () async {
      final rig = _Rig()..badType = true;
      var current = true;
      final guard = SyncRunGuard(() {
        if (!current) throw const SyncRunAborted('authority changed');
      });
      rig.onVisit = (stage) {
        if (stage == 'types') current = false;
      };
      await expectLater(
        rig.service.syncAll(runGuard: guard),
        throwsA(isA<SyncRunAborted>()),
      );
      expect(rig.visits, _allStages.take(_allStages.indexOf('types') + 1));
      expect(rig.service.lastFailureDetails, isEmpty);
    },
  );

  test(
    'later independent type rows are actually written and acknowledged',
    () async {
      final rig = _Rig()
        ..failures['tickets'] = StateError('ticket batch unreadable')
        ..pushType = true;
      await rig.service.syncAll();
      expect(rig.typeWriteCalls, 1);
      expect(rig.typesMarked, 1);
      expect(rig.service.lastFailureCount, 1);
      expect(rig.service.lastSuccessCount, 2);
    },
  );

  test('a remote lookup failure holds events and continues audit', () async {
    final rig = _Rig()
      ..pushType = true
      ..typeReadError = StateError('remote type batch unavailable');
    await rig.service.syncAll();
    expect(rig.typeWriteCalls, 0);
    expect(rig.typesMarked, 0);
    expect(rig.visits, _allStages.where((stage) => stage != 'abnormalities'));
    expect(rig.service.lastFailureCount, 1);
  });

  test(
    'unauthenticated row write stops retries, acknowledgement and later domains',
    () async {
      final rig = _Rig()
        ..pushType = true
        ..typeWriteError = FirebaseAuthException(code: 'unauthenticated');
      await expectLater(rig.service.syncAll(), throwsA(isA<SyncRunAborted>()));
      expect(rig.typeWriteCalls, 1);
      expect(rig.typesMarked, 0);
      expect(rig.visits, _allStages.take(_allStages.indexOf('types') + 1));
      expect(rig.service.lastFailureDetails, isEmpty);
    },
  );

  testWidgets('an account change during retry delay prevents a second write', (
    tester,
  ) async {
    final rig = _Rig()
      ..pushType = true
      ..typeWriteError = StateError('temporary write failure');
    final completion = expectLater(
      rig.service.syncAll(),
      throwsA(isA<SyncRunAborted>()),
    );
    await tester.pump();
    expect(rig.typeWriteCalls, 1);
    rig.auth.actor = null;
    await tester.pump(const Duration(seconds: 3));
    await completion;
    expect(rig.typeWriteCalls, 1);
    expect(rig.typesMarked, 0);
    expect(rig.visits, isNot(contains('audit')));
  });

  test(
    'a row failure in version publication prevents package pointer and audit',
    () async {
      final rig = _Rig()..badVersion = true;
      await rig.service.syncAll();
      expect(
        rig.visits,
        _allStages.where(
          (stage) => !['packages', 'publishAudits'].contains(stage),
        ),
      );
      expect(rig.service.lastFailureCount, 1);
      expect(
        rig.service.lastFailureDetails.single.entityType,
        'template_version',
      );
    },
  );

  test(
    'a preserved prerequisite conflict also holds dependent event pushes',
    () async {
      final rig = _Rig()
        ..pushType = true
        ..newerRemoteType = true;
      await rig.service.syncAll();
      expect(rig.visits, _allStages.where((stage) => stage != 'abnormalities'));
      expect(rig.typeWriteCalls, 0);
      expect(rig.typesMarked, 0);
      expect(rig.service.lastConflictCount, 1);
    },
  );
}

const _allStages = [
  'tickets',
  'templates',
  'versions',
  'packages',
  'publishAudits',
  'knowledge',
  'executions',
  'diary',
  'modules',
  'closures',
  'directives',
  'types',
  'abnormalities',
  'audit',
];

class _Rig {
  final visits = <String>[];
  final failures = <String, Object>{};
  void Function(String)? onVisit;
  bool badModule = false;
  bool badType = false;
  bool badVersion = false;
  bool newerRemoteType = false;
  bool pushType = false;
  Object? typeReadError;
  Object? typeWriteError;
  int typeWriteCalls = 0;
  int typesMarked = 0;
  JobExecution? localExecution;
  JobExecution? remoteExecution;
  JobModuleInstance? pendingModule;
  final moduleWrites = <Map<String, dynamic>>[];
  final audits = <AuditEvent>[];
  late final auth = _Auth();
  late final service = SyncService(
    maintenanceRepo: _Maintenance(this),
    firestoreMaintenance: _Maintenance(this),
    plannedRepo: _Planned(this),
    firestorePlanned: _Planned(this),
    serverCompletion: _Completion(),
    jobDiaryRepo: _Diary(this),
    firestoreJobDiary: _Diary(this),
    jobModuleRepo: _Modules(this),
    firestoreJobModule: _Modules(this),
    templateGovernanceRepo: _Governance(this),
    firestoreTemplateGovernance: _Governance(this),
    directiveRepo: _Directives(this),
    firestoreDirective: _Directives(this),
    abnormalityRepo: _Abnormalities(this),
    firestoreAbnormality: _Abnormalities(this),
    knowledgeRepo: _Knowledge(this),
    auditRepository: _Audit(this),
    auth: auth,
    rejectionOwnerUidLookup: () => auth.currentUser?.uid,
  );

  void visit(String stage) {
    visits.add(stage);
    onVisit?.call(stage);
    final error = failures[stage];
    if (error != null) throw error;
  }
}

class _Maintenance extends MaintenanceRepository {
  _Maintenance(this.rig);
  final _Rig rig;
  @override
  Future<List<MaintenanceRecord>> getUnsyncedTickets() async {
    rig.visit('tickets');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Planned extends PlannedMaintenanceRepository {
  _Planned(this.rig);
  final _Rig rig;
  @override
  Future<List<JobTemplate>> getUnsyncedTemplates() async {
    rig.visit('templates');
    return [];
  }

  @override
  Future<List<JobExecution>> getUnsyncedExecutions() async {
    rig.visit(rig.visits.contains('executions') ? 'closures' : 'executions');
    final record = rig.localExecution;
    return record != null && !record.isSynced ? [record] : [];
  }

  @override
  Future<List<JobExecution>> getExecutionsByFirestoreIds(
    List<String> ids,
  ) async => rig.remoteExecution == null ? [] : [rig.remoteExecution!];

  @override
  Future<bool> applyExecutionServerReadbackIfUnchanged(
    JobExecution remote, {
    required SyncPushSnapshot expectedLocal,
    required bool expectedLocalSynced,
    String? reason,
  }) async {
    expect(expectedLocal.id, rig.localExecution!.id);
    expect(expectedLocal.version, rig.localExecution!.version);
    expect(expectedLocal.updatedAt, rig.localExecution!.updatedAt);
    expect(expectedLocalSynced, rig.localExecution!.isSynced);
    rig.localExecution = remote..isSynced = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Governance extends TemplateGovernanceRepository {
  _Governance(this.rig);
  final _Rig rig;
  @override
  Future<List<TemplateVersion>> getUnsyncedVersions() async {
    rig.visit('versions');
    return rig.badVersion
        ? [
            TemplateVersion()
              ..id = 5
              ..updatedAt = DateTime.utc(2026, 9, 27),
          ]
        : [];
  }

  @override
  Future<List<TemplateVersion>> getVersionsByFirestoreIds(
    List<String> ids,
  ) async => [];

  @override
  Future<List<TemplatePackage>> getUnsyncedPackages() async {
    rig.visit('packages');
    return [];
  }

  @override
  Future<List<TemplatePublishAudit>> getUnsyncedAudits() async {
    rig.visit('publishAudits');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Diary extends JobDiaryRepository {
  _Diary(this.rig);
  final _Rig rig;
  @override
  Future<List<JobDiaryEntry>> getUnsyncedEntries() async {
    rig.visit('diary');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Modules extends JobModuleRepository {
  _Modules(this.rig);
  final _Rig rig;
  @override
  Future<List<JobModuleInstance>> getUnsyncedModules() async {
    rig.visit('modules');
    if (rig.pendingModule != null) {
      return rig.pendingModule!.isSynced ? [] : [rig.pendingModule!];
    }
    return rig.badModule
        ? [
            JobModuleInstance()
              ..id = 9
              ..updatedAt = DateTime.utc(2026, 9, 27),
          ]
        : [];
  }

  @override
  Future<List<JobModuleInstance>> getModulesByFirestoreIds(
    List<String> ids,
  ) async => [];
  @override
  Future<void> batchUpsertModules(List<JobModuleInstance> records) async {
    rig.moduleWrites.addAll(records.map((record) => record.toMap()));
  }

  @override
  Future<void> markModulesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    final record = rig.pendingModule!;
    expect(snapshots.single.id, record.id);
    expect(snapshots.single.version, record.version);
    expect(snapshots.single.updatedAt, record.updatedAt);
    record.isSynced = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Directives extends DirectiveRepository {
  _Directives(this.rig);
  final _Rig rig;
  @override
  Future<List<OperationalDirective>> getUnsyncedDirectives() async {
    rig.visit('directives');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Abnormalities extends AbnormalityRepository {
  _Abnormalities(this.rig);
  final _Rig rig;
  @override
  Future<List<AbnormalityType>> getUnsyncedTypes() async {
    rig.visit('types');
    return rig.badType || rig.pushType
        ? [
            AbnormalityType()
              ..id = 7
              ..firestoreId = rig.pushType ? 'type-7' : null
              ..code = 'TYPE7'
              ..title = 'Test type'
              ..createdAt = DateTime.utc(2026, 9, 27)
              ..updatedAt = DateTime.utc(2026, 9, 27),
          ]
        : [];
  }

  @override
  Future<List<AbnormalityType>> getTypesByFirestoreIds(List<String> ids) async {
    if (rig.typeReadError != null) throw rig.typeReadError!;
    if (rig.newerRemoteType) {
      return [
        AbnormalityType()
          ..firestoreId = 'type-7'
          ..version = 2
          ..code = 'TYPE7'
          ..title = 'Test type'
          ..createdAt = DateTime.utc(2026, 9, 27)
          ..updatedAt = DateTime.utc(2026, 9, 27),
      ];
    }
    return [];
  }

  @override
  Future<void> batchUpsertTypes(List<AbnormalityType> records) async {
    rig.typeWriteCalls++;
    if (rig.typeWriteError != null) throw rig.typeWriteError!;
  }

  @override
  Future<void> markTypesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    rig.typesMarked += snapshots.length;
  }

  @override
  Future<List<ChargeAbnormality>> getUnsyncedAbnormalities() async {
    rig.visit('abnormalities');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Knowledge implements BafKnowledgeRepository {
  _Knowledge(this.rig);
  final _Rig rig;
  @override
  Future<int> syncUnsyncedToCloud({SyncRunGuard? runGuard}) async {
    rig.visit('knowledge');
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Audit extends AuditRepository {
  _Audit(this.rig);
  final _Rig rig;
  @override
  Future<void> log(
    AuditEvent event, {
    bool syncToRemote = true,
    SyncRunGuard? runGuard,
  }) async {
    runGuard?.checkCurrent();
    rig.audits.add(event);
  }

  @override
  Future<AuditSyncResult> syncPendingAuditEvents({
    int batchSize = 450,
    SyncRunGuard? runGuard,
  }) async {
    rig.visit('audit');
    return const AuditSyncResult(
      attempted: 1,
      synced: 1,
      failed: 0,
      batchFailureCount: 0,
    );
  }
}

class _Completion implements PlannedJobServerCompletionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends Fake implements FirebaseAuth {
  User? actor = _User();
  @override
  User? get currentUser => actor;
}

class _User extends Fake implements User {
  @override
  String get uid => 'actor';
  @override
  String? get displayName => 'Actor';
  @override
  String? get email => null;
}

JobExecution _execution({required bool deleted}) => JobExecution()
  ..id = 11
  ..firestoreId = 'reconciled-job'
  ..templateFirestoreId = 'inspection-template'
  ..assetType = AssetType.furnace
  ..assetNumber = 1
  ..createdAt = DateTime.utc(2026, 9, 19)
  ..updatedAt = DateTime.utc(2026, 9, deleted ? 20 : 21)
  ..version = deleted ? 2 : 3
  ..isDeleted = deleted;

class _Connectivity extends Fake implements Connectivity {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _Pull extends Fake implements GlobalPullService {
  int calls = 0;
  @override
  Future<void> pullAndReconcile({SyncRunGuard? runGuard}) async {
    calls++;
  }

  @override
  Set<String> get lastConflictKeys => {};
  @override
  int get lastConflicted => 0;
  @override
  Null get lastFailedDomain => null;
}

class _Retry extends Fake implements WorkflowUncertainRetryService {
  @override
  Future<WorkflowRetryRunSummary> retryDueCommands({
    SyncRunGuard? runGuard,
  }) async => const WorkflowRetryRunSummary();
}

class _WorkflowRepository extends Fake implements WorkflowRepository {
  @override
  Future<WorkflowOutcomeInventory> readOutcomeInventory() async =>
      const WorkflowOutcomeInventory();
}

class _WorkflowPull extends Fake implements WorkflowPullService {
  @override
  Future<WorkflowPullSummary> pull({SyncRunGuard? runGuard}) async =>
      const WorkflowPullSummary(
        workflows: 0,
        lanes: 0,
        compliance: 0,
        attempts: 0,
        equipment: 0,
        prompts: 0,
        events: 0,
      );
}
