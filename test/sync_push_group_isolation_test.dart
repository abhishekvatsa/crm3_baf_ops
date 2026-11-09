// Firestore transport doubles exercise the real repository and wire writers.
// ignore_for_file: subtype_of_sealed_class
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/providers/sync_status_provider.dart';
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/core/services/global_pull_service.dart';
import 'package:crm3_baf_ops/core/services/local_recovery_session_guard.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/core/services/sync_push_snapshot.dart';
import 'package:crm3_baf_ops/core/services/retained_row_mutations.dart';
import 'package:isar_community/isar.dart' hide Query;
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/abnormalities/services/charge_abnormality_queue_guard.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
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

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  _registerTemplatePackageDependencyTests();
  testWidgets(
    'an individual audit dependency hold stays partial until exact reconciliation',
    (tester) async {
      final rig = _Rig()
        ..pendingPublishAudit = _publicationAudit()
        ..remoteTemplateVersion = (TemplateVersion()
          ..firestoreId = 'published-version'
          ..packageFirestoreId = 'published-package'
          ..versionNumber = 1
          ..status = TemplateVersionStatus.published);
      final before = rig.pendingPublishAudit!.toMap();
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
      // Only this row is waiting; successful pull and independent pushes must
      // not hide it or invent a failed write. Repeated runs must not accumulate.
      for (var run = 0; run < 2; run++) {
        rig.visits.clear();
        expect(
          await coordinator.runFullSyncWithResult(force: true),
          SyncRequestOutcome.partial,
        );
        expect(rig.visits, _allStages);
        expect(pull.calls, run + 1);
        expect(rig.publishAuditWrites, isEmpty);
        expect(rig.publishAuditsMarked, 0);
        expect(rig.pendingPublishAudit!.isSynced, isFalse);
        expect(rig.pendingPublishAudit!.toMap(), before);
        expect(rig.service.lastFailureCount, 0);
        expect(rig.service.lastConflictCount, 0);
        expect(rig.service.lastDeferredPushStages, isEmpty);
        expect(rig.service.lastDeferredPushRecordKeys, {
          'template_publish_audit/pending-publication-audit',
        });
        final health = container.read(syncRunHealthProvider);
        expect(health.lastSucceeded, isFalse);
        expect(health.lastPartiallySucceeded, isTrue);
        expect(health.failureCount, 0);
        expect(health.failureDetails, isEmpty);
        expect(health.deferredStageCount, 0);
        expect(health.deferredRecordCount, 1);
        expect(
          health.lastError,
          contains('waiting for related server records'),
        );
        await tester.pump(const Duration(seconds: 6));
        expect(container.read(syncStatusProvider), SyncStatus.partial);
      }
      rig.remoteTemplatePackage = TemplatePackage()
        ..firestoreId = 'published-package'
        ..latestVersionNumber = 1
        ..lifecycleStatus = TemplatePackageLifecycleStatus.active;
      expect(
        await coordinator.runFullSyncWithResult(force: true),
        SyncRequestOutcome.succeeded,
      );
      expect(rig.publishAuditWrites, [before]);
      expect(rig.publishAuditsMarked, 1);
      expect(rig.pendingPublishAudit!.isSynced, isTrue);
      expect(rig.pendingPublishAudit!.toMap(), before);
      expect(rig.service.lastDeferredPushRecordKeys, isEmpty);
      expect(container.read(syncRunHealthProvider).deferredRecordCount, 0);
      expect(container.read(syncRunHealthProvider).lastError, isNull);
      expect(pull.calls, 3);
      coordinator.dispose();
    },
  );
  test(
    'exact remote audit reconciles without waiting for old dependencies',
    () async {
      final rig = _Rig()
        ..pendingPublishAudit = _publicationAudit()
        ..remotePublishAudit = _publicationAudit();
      final before = rig.pendingPublishAudit!.toMap();
      await rig.service.syncAll();
      expect(rig.publishAuditWrites, isEmpty);
      expect(rig.publishAuditsMarked, 1);
      expect(rig.pendingPublishAudit!.isSynced, isTrue);
      expect(rig.pendingPublishAudit!.toMap(), before);
      expect(rig.service.lastDeferredPushRecordKeys, isEmpty);
      expect(rig.service.lastFailureCount, 0);
    },
  );
  testWidgets(
    'B-held A abnormality does not stop independent audit and canonical pull',
    (tester) async {
      final rig = _Rig()
        ..pendingAbnormality = (ChargeAbnormality()
          ..id = 19
          ..firestoreId = 'original-a-abnormality'
          ..sourceChargeNo = 12001
          ..abnormalityTypeId = 'condition'
          ..abnormalityTypeCode = 'CONDITION'
          ..abnormalityTypeTitle = 'Condition'
          ..observedReason = 'Original account A evidence'
          ..loggedAt = DateTime.utc(2026, 9, 20)
          ..updatedAt = DateTime.utc(2026, 9, 20)
          ..loggedByUid = 'origin-a'
          ..updatedByUid = 'origin-a'
          ..version = 1);
      final before = rig.pendingAbnormality!.toMap();
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
      expect(
        await container.read(owner).runFullSyncWithResult(force: true),
        SyncRequestOutcome.partial,
      );
      expect(rig.visits, _allStages);
      expect(rig.abnormalityRemoteReads, 0);
      expect(rig.abnormalityWrites, 0);
      expect(rig.abnormalitiesMarked, 0);
      expect(rig.pendingAbnormality!.isSynced, isFalse);
      expect(rig.pendingAbnormality!.toMap(), before);
      expect(pull.calls, 1);
      expect(
        rig.service.lastSuccessCount,
        1,
        reason: 'Independent audit completed.',
      );
      expect(rig.service.lastFailureCount, 1);
      expect(
        container.read(syncRunHealthProvider).lastPartiallySucceeded,
        isTrue,
      );
      expect(container.read(syncRunHealthProvider).lastSucceeded, isFalse);
      await tester.pump(const Duration(seconds: 6));
    },
  );
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
        ..pushKnowledge = true;
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
        rig.knowledgePushCalls,
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
    'later independent module rows are actually written and acknowledged',
    () async {
      final rig = _Rig()
        ..failures['tickets'] = StateError('ticket batch unreadable')
        ..pendingModule = _pendingModule();
      await rig.service.syncAll();
      expect(rig.moduleWriteCalls, 1);
      expect(rig.modulesMarked, 1);
      expect(rig.pendingModule!.isSynced, isTrue);
      expect(rig.service.lastFailureCount, 1);
      expect(rig.service.lastSuccessCount, 2);
    },
  );

  test(
    'a remote module lookup failure holds closure and continues audit',
    () async {
      final rig = _Rig()
        ..pendingModule = _pendingModule()
        ..moduleReadError = StateError('remote module batch unavailable');
      await rig.service.syncAll();
      expect(rig.moduleWriteCalls, 0);
      expect(rig.modulesMarked, 0);
      expect(rig.pendingModule!.isSynced, isFalse);
      expect(rig.visits, _allStages.where((stage) => stage != 'closures'));
      expect(rig.service.lastFailureCount, 1);
    },
  );

  test(
    'unauthenticated row write stops retries, acknowledgement and later domains',
    () async {
      final rig = _Rig()
        ..pendingModule = _pendingModule()
        ..moduleWriteError = FirebaseAuthException(code: 'unauthenticated');
      await expectLater(rig.service.syncAll(), throwsA(isA<SyncRunAborted>()));
      expect(rig.moduleWriteCalls, 1);
      expect(rig.modulesMarked, 0);
      expect(rig.visits, _allStages.take(_allStages.indexOf('modules') + 1));
      expect(rig.service.lastFailureDetails, isEmpty);
    },
  );

  testWidgets('an account change during retry delay prevents a second write', (
    tester,
  ) async {
    final rig = _Rig()
      ..pendingModule = _pendingModule()
      ..moduleWriteError = StateError('temporary write failure');
    final completion = expectLater(
      rig.service.syncAll(),
      throwsA(isA<SyncRunAborted>()),
    );
    await tester.pump();
    expect(rig.moduleWriteCalls, 1);
    rig.auth.actor = null;
    await tester.pump(const Duration(seconds: 3));
    await completion;
    expect(rig.moduleWriteCalls, 1);
    expect(rig.modulesMarked, 0);
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
    'unknown type origin is retained for review and holds dependent event pushes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cf01_isolation_',
      );
      final database = await Isar.open(
        [DurableSubmissionRecordSchema],
        name: 'cf01_isolation',
        directory: directory.path,
        inspector: false,
      );
      try {
        final store = DurableSubmissionRepository(database);
        final rig = _Rig(retainedStore: store)..pushType = true;
        final before = RetainedRowMutations.wire(
          (await _Abnormalities(rig).getUnsyncedTypes()).single,
        );
        rig.visits.clear();
        await rig.service.syncAll();
        expect(
          rig.visits,
          _allStages.where((stage) => stage != 'abnormalities'),
        );
        expect(rig.typeWriteCalls, 0);
        expect(rig.typesMarked, 0);
        expect(rig.service.lastFailureCount, 1);
        expect(rig.service.lastConflictCount, 0);
        expect(
          rig.service.lastFailureDetails.single.message,
          contains('original account'),
        );
        final retained = await store.findUnresolvedForResource(
          'retainedRow:demo-test:abnormality_types:type-7',
        );
        expect(retained!.isLegacy, isTrue);
        expect(retained.actorUid, isNull);
        expect(
          jsonDecode(utf8.decode(base64Decode(retained.legacySourceBase64!))),
          before,
        );
      } finally {
        await database.close(deleteFromDisk: true);
        await directory.delete(recursive: true);
      }
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

TemplatePublishAudit _publicationAudit() => TemplatePublishAudit()
  ..id = 51
  ..firestoreId = 'pending-publication-audit'
  ..packageFirestoreId = 'published-package'
  ..versionFirestoreId = 'published-version'
  ..action = TemplatePublishAuditAction.published
  ..performedByUid = 'actor'
  ..performedByName = 'Actor'
  ..performedAt = DateTime.utc(2026, 9, 27)
  ..updatedAt = DateTime.utc(2026, 9, 27)
  ..afterHash = 'retained-content-hash'
  ..payloadSnapshotJson = '{"original":"publication evidence"}';

class _Rig {
  _Rig({this.retainedStore, this.localGovernance, this.remoteGovernance});
  final DurableSubmissionRepository? retainedStore;
  final TemplateGovernanceRepository? localGovernance;
  final TemplateGovernanceRepository? remoteGovernance;
  final visits = <String>[];
  final failures = <String, Object>{};
  void Function(String)? onVisit;
  bool badModule = false;
  bool badType = false;
  bool badVersion = false;
  bool pushType = false;
  bool pushKnowledge = false;
  int knowledgePushCalls = 0;
  Object? moduleReadError;
  Object? moduleWriteError;
  int moduleWriteCalls = 0;
  int modulesMarked = 0;
  int typeWriteCalls = 0;
  int typesMarked = 0;
  JobExecution? localExecution;
  JobExecution? remoteExecution;
  JobModuleInstance? pendingModule;
  ChargeAbnormality? pendingAbnormality;
  int abnormalityRemoteReads = 0;
  int abnormalityWrites = 0;
  int abnormalitiesMarked = 0;
  final moduleWrites = <Map<String, dynamic>>[];
  final audits = <AuditEvent>[];
  TemplatePublishAudit? pendingPublishAudit;
  TemplatePublishAudit? remotePublishAudit;
  TemplateVersion? remoteTemplateVersion;
  TemplatePackage? remoteTemplatePackage;
  final publishAuditWrites = <Map<String, dynamic>>[];
  int publishAuditsMarked = 0;
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
    templateGovernanceRepo: localGovernance ?? _Governance(this),
    firestoreTemplateGovernance: remoteGovernance ?? _Governance(this),
    directiveRepo: _Directives(this),
    firestoreDirective: _Directives(this),
    abnormalityRepo: _Abnormalities(this),
    firestoreAbnormality: _Abnormalities(this),
    knowledgeRepo: _Knowledge(this),
    auditRepository: _Audit(this),
    auth: auth,
    rejectionOwnerUidLookup: () => auth.currentUser?.uid,
    retainedRowMutations: RetainedRowMutations(
      store: retainedStore,
      projectId: () => 'demo-test',
      currentActorUid: () => auth.currentUser?.uid,
    ),
    abnormalityQueueGuard: ChargeAbnormalityQueueGuard(
      store: retainedStore,
      projectId: () => 'demo-test',
      currentActorUid: () => auth.currentUser?.uid,
    ),
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
  ) async =>
      rig.remoteTemplateVersion == null ? [] : [rig.remoteTemplateVersion!];

  @override
  Future<List<TemplatePackage>> getPackagesByFirestoreIds(
    List<String> ids,
  ) async =>
      rig.remoteTemplatePackage == null ? [] : [rig.remoteTemplatePackage!];

  @override
  Future<List<TemplatePublishAudit>> getAuditsByFirestoreIds(
    List<String> ids,
  ) async => rig.remotePublishAudit == null ? [] : [rig.remotePublishAudit!];

  @override
  Future<List<TemplatePackage>> getUnsyncedPackages() async {
    rig.visit('packages');
    return [];
  }

  @override
  Future<List<TemplatePublishAudit>> getUnsyncedAudits() async {
    rig.visit('publishAudits');
    final record = rig.pendingPublishAudit;
    return record != null && !record.isSynced ? [record] : [];
  }

  @override
  Future<void> batchUpsertAudits(List<TemplatePublishAudit> records) async {
    rig.publishAuditWrites.addAll(records.map((record) => record.toMap()));
    rig.remotePublishAudit = records.single;
  }

  @override
  Future<void> markAuditsSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    final record = rig.pendingPublishAudit!;
    expect(snapshots.single.id, record.id);
    expect(snapshots.single.version, record.version);
    expect(snapshots.single.updatedAt, record.updatedAt);
    rig.publishAuditsMarked += snapshots.length;
    record.isSynced = true;
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
  ) async {
    if (rig.moduleReadError != null) throw rig.moduleReadError!;
    return [];
  }

  @override
  Future<void> batchUpsertModules(List<JobModuleInstance> records) async {
    rig.moduleWriteCalls++;
    if (rig.moduleWriteError != null) throw rig.moduleWriteError!;
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
    rig.modulesMarked += snapshots.length;
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
    return [];
  }

  @override
  Future<void> batchUpsertTypes(List<AbnormalityType> records) async {
    rig.typeWriteCalls++;
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
    return rig.pendingAbnormality == null ? [] : [rig.pendingAbnormality!];
  }

  @override
  Future<List<ChargeAbnormality>> getAbnormalitiesByFirestoreIds(
    List<String> ids,
  ) async {
    rig.abnormalityRemoteReads++;
    return [];
  }

  @override
  Future<void> batchUpsertAbnormalities(List<ChargeAbnormality> records) async {
    rig.abnormalityWrites++;
  }

  @override
  Future<void> markAbnormalitiesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  ) async {
    rig.abnormalitiesMarked += snapshots.length;
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
    if (rig.pushKnowledge) rig.knowledgePushCalls++;
    return rig.pushKnowledge ? 1 : 0;
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

JobModuleInstance _pendingModule() => JobModuleInstance()
  ..id = 12
  ..firestoreId = 'pending-module'
  ..jobExecutionFirestoreId = 'reconciled-job'
  ..moduleTitle = 'Inspection'
  ..draftNote = 'Unsent inspection evidence'
  ..createdAt = DateTime.utc(2026, 9, 20)
  ..updatedAt = DateTime.utc(2026, 9, 21);

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

const _dependencyPackageId = 'ci-required-red-successor-package';
const _dependencySeedVersionId = 'ci-required-red-successor-version-1';
const _dependencyCopyId = 'diagnostic-successor-publication-copy-2';

void _registerTemplatePackageDependencyTests() {
  for (final explicitSave in [false, true]) {
    test(
      'publication between snapshots defers only its package '
      '(explicit package save: $explicitSave)',
      () => _withDependencyFixture(explicitSave, (f) async {
        f.local.afterNextVersionSnapshot = (snapshot) async {
          expect(snapshot, isEmpty);
          f.local.events.add({'event': 'versions-snapshot'});
          final draft = (await f.local.getVersionByFirestoreId(
            _dependencyCopyId,
          ))!;
          await f.local.publishVersion(
            draft,
            actor: f.actor,
            reason: 'Publication between real sync snapshots',
          );
          f.local.events.add({'event': 'actual-publication-committed'});
        };
        await f.addPendingPackage(
          'ready-peer',
          pointer: 'ready-peer-version',
          number: 1,
        );
        f.memory.documents['template_versions/ready-peer-version'] = f
            .publishedWire('ready-peer-version', 'ready-peer', 1);

        await f.rig.service.syncAll();

        expect(f.local.events.map((event) => event['event']), [
          'versions-snapshot',
          'actual-publication-committed',
          'packages-snapshot',
        ]);
        expect(f.packageWrites.map((write) => write['path']), [
          'template_packages/ready-peer',
        ]);
        expect(
          (await f.local.getPackageByFirestoreId('ready-peer'))!.isSynced,
          isTrue,
        );
        final held = (await f.local.getPackageByFirestoreId(
          _dependencyPackageId,
        ))!;
        final published = (await f.local.getVersionByFirestoreId(
          _dependencyCopyId,
        ))!;
        expect(held.isSynced, isFalse);
        expect(held.activeVersionFirestoreId, _dependencyCopyId);
        expect(held.latestVersionNumber, 2);
        expect(held.version, explicitSave ? 3 : 2);
        expect(published.isPublished, isTrue);
        expect(published.isSynced, isFalse);
        expect(
          f.memory.documents['template_versions/$_dependencyCopyId']!['status'],
          'draft',
        );
        expect(f.rig.service.lastDeferredPushRecordKeys, {
          'template_package/$_dependencyPackageId',
        });
        expect(
          f.rig.service.lastDeferredPushStages,
          contains('template_publish_audit'),
        );
        expect(f.rig.service.lastFailureCount, 0);
        expect(f.rig.service.lastConflictCount, 0);
        expect(await f.database.syncRejections.count(), 0);
        expect(await f.local.getUnsyncedAudits(), hasLength(1));
        expect(f.rig.visits, contains('audit'));
        expect(f.memory.queryReads.single['source'], Source.server);

        // A later server read confirms the exact real publication. This is
        // transport evidence only: no claim that the original CI or Rules
        // accepted a synthetic write, and no FirebaseAuth lifecycle replay.
        f.memory.documents['template_versions/$_dependencyCopyId'] = published
            .toMap();
        f.memory.batches.clear();
        await f.rig.service.syncAll();
        expect(
          (await f.local.getVersionByFirestoreId(_dependencyCopyId))!.isSynced,
          isTrue,
        );
        expect(
          (await f.local.getPackageByFirestoreId(
            _dependencyPackageId,
          ))!.isSynced,
          isTrue,
        );
        expect(await f.local.getUnsyncedAudits(), isEmpty);
        expect(f.rig.service.lastDeferredPushRecordKeys, isEmpty);
        expect(f.rig.service.lastFailureCount, 0);
        expect(f.rig.service.lastConflictCount, 0);
        expect(await f.database.syncRejections.count(), 0);
        final sent = f.packageWrites.single['data'] as Map;
        expect(sent['activeVersionFirestoreId'], _dependencyCopyId);
        expect(sent['latestVersionNumber'], 2);
        expect(sent['version'], explicitSave ? 3 : 2);
        expect(sent['createdAt'], '2026-11-09T00:00:00.123456+00:00');
        expect(sent['createdByUid'], f.actor.uid);
      }),
    );
  }

  for (final condition in [
    'missing',
    'draft',
    'retired',
    'archived',
    'deleted',
    'wrong document identity',
    'wrong package',
    'wrong number',
  ]) {
    test(
      'package dependency $condition stays pending without rejection',
      () => _withDependencyFixture(false, (f) async {
        final package = await f.addPendingPackage(
          'pending-package',
          pointer: 'target',
          number: 2,
        );
        final before = package.toMap();
        final target = f.publishedWire('target', 'pending-package', 2);
        switch (condition) {
          case 'draft':
          case 'archived':
            target['status'] = condition;
            target['publishedAt'] = null;
            target['publishedByUid'] = null;
            target['publishedByName'] = null;
          case 'retired':
            target['status'] = condition;
            target['retiredAt'] = '2026-11-09T00:00:00.123456+00:00';
            target['retiredByUid'] = f.actor.uid;
            target['retiredByName'] = f.actor.name;
            target['retireReason'] = 'Superseded fixture target';
          case 'deleted':
            target['isDeleted'] = true;
            target['deletedAt'] = '2026-11-09T00:00:00.123456+00:00';
            target['deletedByUid'] = f.actor.uid;
            target['deletedByName'] = f.actor.name;
          case 'wrong document identity':
            target['firestoreId'] = 'another-target';
            f.memory.queryIdOverrides['target'] = 'another-target';
          case 'wrong package':
            target['packageFirestoreId'] = 'another-package';
          case 'wrong number':
            target['versionNumber'] = 1;
        }
        if (condition != 'missing') {
          f.memory.documents['template_versions/target'] = target;
        }
        for (var pass = 0; pass < 2; pass++) {
          await f.rig.service.syncAll();
          expect(f.packageWrites, isEmpty);
          final retained = (await f.local.getPackageByFirestoreId(
            'pending-package',
          ))!;
          expect(retained.toMap(), before);
          expect(retained.isSynced, isFalse);
          expect(f.rig.service.lastDeferredPushRecordKeys, {
            'template_package/pending-package',
          });
          expect(f.rig.service.lastFailureCount, 0);
          expect(f.rig.service.lastConflictCount, 0);
          expect(await f.database.syncRejections.count(), 0);
        }
      }),
    );
  }

  for (final condition in [
    'null pointer',
    'blank pointer',
    'deleted',
    'exact remote match',
  ]) {
    test(
      'package dependency preserves $condition path',
      () => _withDependencyFixture(false, (f) async {
        final package = await f.addPendingPackage(
          'existing-path',
          pointer: condition == 'null pointer' || condition == 'blank pointer'
              ? null
              : 'missing-target',
          number: 0,
        );
        if (condition == 'blank pointer') {
          // A valid remote row was decoded first. The local model can retain
          // whitespace, which the existing outgoing wire serializer clears.
          package.activeVersionFirestoreId = ' ';
          await f.database.writeTxn(
            () => f.database.templatePackages.put(package),
          );
        }
        if (condition == 'deleted') {
          package
            ..isDeleted = true
            ..deletedAt = DateTime.parse('2026-11-09T00:00:00.123456+00:00')
            ..deletedByUid = f.actor.uid
            ..deletedByName = f.actor.name;
          await f.database.writeTxn(
            () => f.database.templatePackages.put(package),
          );
        }
        if (condition == 'exact remote match') {
          f.memory.documents['template_packages/existing-path'] = package
              .toMap();
          final remote = (await _DependencyRemote(
            f.memory,
          ).getPackagesByFirestoreIds(['existing-path'])).single;
          expect(
            syncPersistedSnapshotsEquivalent(package.toMap(), remote.toMap()),
            isTrue,
          );
        }
        await f.rig.service.syncAll();
        expect(f.memory.queryReads, isEmpty);
        expect(
          (await f.local.getPackageByFirestoreId('existing-path'))!.isSynced,
          isTrue,
        );
        expect(
          f.packageWrites,
          condition == 'exact remote match' ? isEmpty : hasLength(1),
        );
        expect(f.rig.service.lastFailureCount, 0);
        expect(f.rig.service.lastDeferredPushRecordKeys, isEmpty);
      }),
    );
  }

  test(
    'package pointer lookup matches the existing outgoing wire normalization',
    () => _withDependencyFixture(false, (f) async {
      final package = await f.addPendingPackage(
        'normalized-pointer',
        pointer: 'target',
        number: 2,
      );
      package.activeVersionFirestoreId = ' target ';
      await f.database.writeTxn(() => f.database.templatePackages.put(package));
      f.memory.documents['template_versions/target'] = f.publishedWire(
        'target',
        'normalized-pointer',
        2,
      );
      await f.rig.service.syncAll();
      expect(f.memory.queryReads.single['ids'], ['target']);
      expect(
        (f.packageWrites.single['data'] as Map)['activeVersionFirestoreId'],
        'target',
      );
      expect(f.rig.service.lastFailureCount, 0);
      expect(f.rig.service.lastDeferredPushRecordKeys, isEmpty);
    }),
  );

  test(
    'package acknowledgment does not consume a newer edit during its send',
    () => _withDependencyFixture(false, (f) async {
      final package = await f.addPendingPackage(
        'edited-during-send',
        pointer: 'target',
        number: 2,
      );
      final oldTitle = package.title;
      final oldRevision = package.version;
      f.memory.documents['template_versions/target'] = f.publishedWire(
        'target',
        'edited-during-send',
        2,
      );
      f.memory.beforeNextCommit = (writes) async {
        expect(writes.single['path'], 'template_packages/edited-during-send');
        final newer = (await f.local.getPackageByFirestoreId(
          'edited-during-send',
        ))!;
        newer.title = 'Edited while the previous snapshot was sending';
        await f.local.savePackage(newer, actor: f.actor);
      };
      await f.rig.service.syncAll();
      final retained = (await f.local.getPackageByFirestoreId(
        'edited-during-send',
      ))!;
      expect(retained.isSynced, isFalse);
      expect(retained.version, greaterThan(oldRevision));
      expect(retained.title, 'Edited while the previous snapshot was sending');
      expect((f.packageWrites.single['data'] as Map)['title'], oldTitle);
      expect(f.rig.service.lastFailureCount, 0);
      expect(await f.database.syncRejections.count(), 0);
    }),
  );

  for (final refusal in ['permission-denied', 'cached', 'pending']) {
    test(
      'package authoritative read $refusal is a stage error, not a rejection',
      () => _withDependencyFixture(false, (f) async {
        await f.addPendingPackage('read-refused', pointer: 'target', number: 2);
        f.memory.documents['template_versions/target'] = f.publishedWire(
          'target',
          'read-refused',
          2,
        );
        if (refusal == 'permission-denied') {
          f.memory.queryError = FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        } else if (refusal == 'cached') {
          f.memory.queryCached = true;
        } else {
          f.memory.queryPending = true;
        }
        await f.rig.service.syncAll();
        expect(f.packageWrites, isEmpty);
        expect(f.rig.service.lastFailureCount, 1);
        expect(f.rig.service.lastDeferredPushRecordKeys, isEmpty);
        expect(
          f.rig.service.lastDeferredPushStages,
          contains('template_publish_audit'),
        );
        expect(
          (await f.local.getPackageByFirestoreId('read-refused'))!.isSynced,
          isFalse,
        );
        expect(await f.database.syncRejections.count(), 0);
        expect(f.rig.visits, contains('audit'));
      }),
    );
  }

  test(
    'authoritative version reads use server chunks and preserve old getter',
    () async {
      final memory = _DependencyFirestore(_dependencySeed(_dependencyActor()));
      final repository = FirestoreTemplateGovernanceRepository(
        firestore: memory,
      );
      final seed =
          memory.documents['template_versions/$_dependencySeedVersionId']!;
      final ids = [for (var i = 0; i < 61; i++) 'version-$i'];
      for (final id in ids) {
        memory.documents['template_versions/$id'] = {
          ...seed,
          'firestoreId': id,
        };
      }
      final versions = await repository.getAuthoritativeVersionsForPackagePush(
        ids,
      );
      expect(versions.map((v) => v.firestoreId), ids);
      expect(memory.queryReads.map((r) => (r['ids'] as List).length), [
        30,
        30,
        1,
      ]);
      expect(
        memory.queryReads.map((r) => r['source']),
        everyElement(Source.server),
      );
      memory.queryReads.clear();
      expect(
        await repository.getAuthoritativeVersionsForPackagePush([]),
        isEmpty,
      );
      expect(memory.queryReads, isEmpty);
      await repository.getVersionsByFirestoreIds([ids.first]);
      expect(memory.queryReads.single['source'], isNull);
    },
  );

  for (final provenance in [
    'query cache',
    'query pending',
    'document cache',
    'document pending',
  ]) {
    test('authoritative version reads refuse $provenance', () async {
      final memory = _DependencyFirestore(_dependencySeed(_dependencyActor()));
      switch (provenance) {
        case 'query cache':
          memory.queryCached = true;
        case 'query pending':
          memory.queryPending = true;
        case 'document cache':
          memory.cachedDocumentIds.add(_dependencySeedVersionId);
        case 'document pending':
          memory.pendingDocumentIds.add(_dependencySeedVersionId);
      }
      final repository = FirestoreTemplateGovernanceRepository(
        firestore: memory,
      );
      await expectLater(
        repository.getAuthoritativeVersionsForPackagePush([
          _dependencySeedVersionId,
        ]),
        throwsStateError,
      );
      expect(memory.queryReads.single['source'], Source.server);
      expect(memory.batches, isEmpty);
    });
  }

  for (final field in ['firestoreId', 'packageFirestoreId', 'status']) {
    test('authoritative version reads refuse normalized $field', () async {
      final memory = _DependencyFirestore(_dependencySeed(_dependencyActor()));
      final data =
          memory.documents['template_versions/$_dependencySeedVersionId']!;
      final raw = data[field] as String;
      data[field] = ' $raw ';
      final repository = FirestoreTemplateGovernanceRepository(
        firestore: memory,
      );
      await expectLater(
        repository.getAuthoritativeVersionsForPackagePush([
          _dependencySeedVersionId,
        ]),
        field == 'status'
            ? throwsA(
                isA<PersistedDataFormatException>().having(
                  (error) => error.fieldName,
                  'fieldName',
                  'status',
                ),
              )
            : throwsStateError,
      );
      expect(memory.queryReads.single['source'], Source.server);
      expect(memory.batches, isEmpty);
    });
  }

  test('authoritative version read denial has no cached fallback', () async {
    final memory = _DependencyFirestore(_dependencySeed(_dependencyActor()));
    final denied = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    memory.queryError = denied;
    final repository = FirestoreTemplateGovernanceRepository(firestore: memory);
    await expectLater(
      repository.getAuthoritativeVersionsForPackagePush([
        _dependencySeedVersionId,
      ]),
      throwsA(same(denied)),
    );
    expect(memory.queryReads, hasLength(1));
    expect(memory.queryReads.single['source'], Source.server);
    expect(memory.batches, isEmpty);
  });

  test('local versions cannot satisfy authoritative package reads', () {
    final repository = IsarTemplateGovernanceRepository();
    expect(
      () => repository.getAuthoritativeVersionsForPackagePush(['target']),
      throwsUnsupportedError,
    );
  });
}

AppUser _dependencyActor() => AppUser(
  uid: 'actor',
  name: 'Actor',
  email: 'dev.usability-si@example.invalid',
  roles: [AppRole.si],
  isApproved: true,
  createdAt: DateTime.utc(2026, 11, 9),
);

class _DependencyFixture {
  _DependencyFixture(
    this.database,
    this.actor,
    this.local,
    this.memory,
    this.rig,
  );
  final Isar database;
  final AppUser actor;
  final _DependencyLocal local;
  final _DependencyFirestore memory;
  final _Rig rig;

  List<Map<String, dynamic>> get packageWrites => [
    for (final batch in memory.batches)
      for (final write in batch['writes'] as List)
        if ((write['path'] as String).startsWith('template_packages/'))
          Map<String, dynamic>.from(write as Map),
  ];

  Future<TemplatePackage> addPendingPackage(
    String id, {
    required String? pointer,
    required int number,
  }) async {
    final wire =
        Map<String, dynamic>.from(
            _dependencySeed(actor)['template_packages/$_dependencyPackageId']!,
          )
          ..['firestoreId'] = id
          ..['activeVersionFirestoreId'] = pointer
          ..['latestVersionNumber'] = number;
    final package = TemplatePackage.fromMap(wire, id)..isSynced = false;
    await database.writeTxn(() => database.templatePackages.put(package));
    // Baselines must reflect the actual Isar round trip, including its local
    // DateTime representation, without changing runtime wire normalization.
    return (await local.getPackageByFirestoreId(id))!;
  }

  Map<String, dynamic> publishedWire(String id, String packageId, int number) =>
      Map<String, dynamic>.from(
          _dependencySeed(
            actor,
          )['template_versions/$_dependencySeedVersionId']!,
        )
        ..['firestoreId'] = id
        ..['packageFirestoreId'] = packageId
        ..['versionNumber'] = number
        ..['status'] = 'published'
        ..['publishedAt'] = '2026-11-09T00:00:00.123456+00:00'
        ..['publishedByUid'] = actor.uid
        ..['publishedByName'] = actor.name;
}

Future<void> _withDependencyFixture(
  bool explicitSave,
  Future<void> Function(_DependencyFixture) body,
) async {
  final directory = await Directory.systemTemp.createTemp(
    'package_dependency_',
  );
  final database = await Isar.open(
    [
      TemplatePackageSchema,
      TemplateVersionSchema,
      TemplatePublishAuditSchema,
      SyncRejectionSchema,
    ],
    directory: directory.path,
    inspector: false,
  );
  app.isar = database;
  final originalHttpOverrides = HttpOverrides.current;
  HttpOverrides.global = _DependencyNoNetwork();
  try {
    final actor = _dependencyActor();
    final seed = _dependencySeed(actor);
    final memory = _DependencyFirestore(seed);
    final local = _DependencyLocal();
    final remote = _DependencyRemote(memory);
    final rig = _Rig(localGovernance: local, remoteGovernance: remote);
    final package = TemplatePackage.fromMap(
      seed['template_packages/$_dependencyPackageId']!,
      _dependencyPackageId,
    )..isSynced = true;
    final version = TemplateVersion.fromMap(
      seed['template_versions/$_dependencySeedVersionId']!,
      _dependencySeedVersionId,
    )..isSynced = true;
    await database.writeTxn(() async {
      await database.templatePackages.put(package);
      await database.templateVersions.put(version);
    });
    if (explicitSave) {
      final title = package.title;
      package.title = '$title (explicit edit)';
      await local.savePackage(package, actor: actor);
    }
    final copy = TemplateVersion.fromMap(
      Map<String, dynamic>.from(version.toMap())
        ..['firestoreId'] = _dependencyCopyId
        ..['versionNumber'] = 2
        ..['versionLabel'] = 'v2'
        ..['sourceVersionFirestoreId'] = _dependencySeedVersionId,
      _dependencyCopyId,
    );
    copy.refreshContentHash();
    await local.saveVersion(copy, actor: actor);
    await rig.service.syncAll();
    expect(rig.service.lastFailureCount, 0);
    expect(
      (await local.getVersionByFirestoreId(_dependencyCopyId))!.isSynced,
      isTrue,
    );
    expect(
      memory.documents['template_versions/$_dependencyCopyId']!['status'],
      'draft',
    );
    memory.batches.clear();
    memory.queryReads.clear();
    await body(_DependencyFixture(database, actor, local, memory, rig));
  } finally {
    HttpOverrides.global = originalHttpOverrides;
    await database.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  }
}

Map<String, Map<String, dynamic>> _dependencySeed(AppUser actor) {
  const at = '2026-11-09T00:00:00.123456+00:00';
  const title = 'DEV required RED refractory inspection';
  final metadata = <String, dynamic>{
    'schemaVersion': 1,
    'version': 1,
    'isDeleted': false,
    'createdByUid': actor.uid,
    'createdByName': actor.name,
    'updatedByUid': actor.uid,
    'updatedByName': actor.name,
    'createdAt': at,
    'updatedAt': at,
  };
  final review = <String, dynamic>{
    'closureReviewConfirmed': true,
    'closureReviewConfirmedByUid': actor.uid,
    'closureReviewConfirmedByName': actor.name,
    'closureReviewConfirmedAt': at,
  };
  final package = <String, dynamic>{
    ...metadata,
    'firestoreId': _dependencyPackageId,
    'packageCode': 'CI-REQUIRED-RED-FURNACE',
    'title': title,
    'description': 'Synthetic required RED Android journey draft.',
    'assetType': 'furnace',
    'disciplineScope': 'refractory',
    'lifecycleStatus': 'active',
    'latestVersionNumber': 0,
    'activeVersionFirestoreId': null,
  };
  final version = <String, dynamic>{
    ...metadata,
    'firestoreId': _dependencySeedVersionId,
    'packageFirestoreId': _dependencyPackageId,
    'versionNumber': 1,
    'versionLabel': 'v1',
    'status': 'draft',
    'jobTemplateSnapshotJson': jsonEncode({
      'jobName': title,
      'assetType': 'furnace',
      'composer': review,
      'closureCriticalCount': 1,
    }),
    'moduleSnapshotsJson': jsonEncode([
      {
        'moduleCode': 'CI-RED-01',
        'moduleTitle': 'Refractory inspection',
        'discipline': 'refractory',
        'requiredForClosure': true,
        'isRequired': true,
      },
    ]),
    'fieldDefinitionsJson': jsonEncode([
      {
        'key': 'redInspection',
        'label': 'Refractory findings',
        'moduleCode': 'CI-RED-01',
        'type': 'text',
        'isRequired': true,
      },
    ]),
    'checklistJson': '[]',
    ...review,
    'closureCriticalModuleCount': 1,
    'targetRefs': [],
    'deviceTagRefs': [],
    'safetyClass': null,
    'safetyGatePolicyJson': null,
    'procedureRefs': [],
    'operationalStatePreconditions': [],
    'publishedAt': null,
    'publishedByUid': null,
    'publishedByName': null,
    'retiredAt': null,
    'metadataJson': null,
  };
  final parsed = TemplateVersion.fromMap(version, _dependencySeedVersionId);
  parsed.refreshContentHash();
  version['contentHash'] = parsed.contentHash;
  return {
    'template_packages/$_dependencyPackageId': package,
    'template_versions/$_dependencySeedVersionId': version,
  };
}

dynamic _copyDependencyWire(Object? value) => jsonDecode(jsonEncode(value));

class _DependencyLocal extends IsarTemplateGovernanceRepository {
  _DependencyLocal()
    : super(auditFirestoreIdFactory: () => 'diagnostic-publication-audit');
  Future<void> Function(List<TemplateVersion>)? afterNextVersionSnapshot;
  final events = <Map<String, dynamic>>[];
  @override
  Future<List<TemplateVersion>> getUnsyncedVersions() async {
    final snapshot = await super.getUnsyncedVersions();
    final hook = afterNextVersionSnapshot;
    afterNextVersionSnapshot = null;
    if (hook != null) await hook(snapshot);
    return snapshot;
  }

  @override
  Future<List<TemplatePackage>> getUnsyncedPackages() async {
    final snapshot = await super.getUnsyncedPackages();
    if (events.isNotEmpty) {
      events.add({
        'event': 'packages-snapshot',
        'ids': snapshot.map((r) => r.firestoreId).toList(),
      });
    }
    return snapshot;
  }
}

class _DependencyRemote extends FirestoreTemplateGovernanceRepository {
  _DependencyRemote(this.memory) : super(firestore: memory);
  final _DependencyFirestore memory;
  // Query transport only. The real batch writers/wire serializers are inherited.
  @override
  Future<List<TemplatePackage>> getPackagesByFirestoreIds(
    List<String> ids,
  ) async => [
    for (final id in ids)
      if (memory.documents['template_packages/$id'] case final value?)
        TemplatePackage.fromMap(Map.from(value), id),
  ];
  @override
  Future<List<TemplateVersion>> getVersionsByFirestoreIds(
    List<String> ids,
  ) async => [
    for (final id in ids)
      if (memory.documents['template_versions/$id'] case final value?)
        TemplateVersion.fromMap(Map.from(value), id),
  ];
  @override
  Future<List<TemplatePublishAudit>> getAuditsByFirestoreIds(
    List<String> ids,
  ) async => [];
}

class _DependencyFirestore implements FirebaseFirestore {
  _DependencyFirestore(Map<String, Map<String, dynamic>> seed)
    : documents = {
        for (final entry in seed.entries)
          entry.key: Map<String, dynamic>.from(
            _copyDependencyWire(entry.value),
          ),
      };
  final Map<String, Map<String, dynamic>> documents;
  final batches = <Map<String, dynamic>>[];
  final queryReads = <Map<String, dynamic>>[];
  final cachedDocumentIds = <String>{};
  final pendingDocumentIds = <String>{};
  final queryIdOverrides = <String, String>{};
  bool queryCached = false;
  bool queryPending = false;
  Object? queryError;
  Future<void> Function(List<Map<String, dynamic>>)? beforeNextCommit;
  String phase = 'seed';
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _DependencyCollection(this, path);
  @override
  WriteBatch batch() => _DependencyBatch(this);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unimplemented test Firestore call: ${invocation.memberName}',
  );
}

class _DependencyCollection
    implements CollectionReference<Map<String, dynamic>> {
  _DependencyCollection(this.owner, this.path);
  final _DependencyFirestore owner;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    if (path == null) {
      throw StateError('No diagnostic random document ID allocation');
    }
    return _DependencyReference(owner, '${this.path}/$path');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      expect(invocation.positionalArguments.single, FieldPath.documentId);
      return _DependencyQuery(
        owner,
        path,
        List<String>.from(invocation.namedArguments[#whereIn] as List),
      );
    }
    throw StateError('Unexpected test collection call');
  }
}

class _DependencyQuery extends Fake implements Query<Map<String, dynamic>> {
  _DependencyQuery(this.owner, this.collectionPath, this.ids);
  final _DependencyFirestore owner;
  final String collectionPath;
  final List<String> ids;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    owner.queryReads.add({
      'collection': collectionPath,
      'ids': List<String>.from(ids),
      'source': options?.source,
    });
    final error = owner.queryError;
    if (error != null) throw error;
    return _DependencyQuerySnapshot([
      for (final id in ids)
        if (owner.documents['$collectionPath/$id'] case final value?)
          _DependencyQueryDocument(
            owner.queryIdOverrides[id] ?? id,
            Map<String, dynamic>.from(_copyDependencyWire(value)),
            _DependencyMetadata(
              owner.cachedDocumentIds.contains(id),
              owner.pendingDocumentIds.contains(id),
            ),
          ),
    ], _DependencyMetadata(owner.queryCached, owner.queryPending));
  }
}

class _DependencyQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _DependencyQuerySnapshot(this.docs, this.metadata);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
}

class _DependencyQueryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _DependencyQueryDocument(this.id, this.value, this.metadata);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  final SnapshotMetadata metadata;
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
}

class _DependencyMetadata extends Fake implements SnapshotMetadata {
  _DependencyMetadata(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

class _DependencyReference implements DocumentReference<Map<String, dynamic>> {
  _DependencyReference(this.owner, this.path);
  final _DependencyFirestore owner;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _DependencySnapshot(
    id,
    owner.documents[path] == null
        ? null
        : Map<String, dynamic>.from(_copyDependencyWire(owner.documents[path])),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unimplemented test reference call: ${invocation.memberName}',
  );
}

class _DependencySnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _DependencySnapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unimplemented test snapshot call: ${invocation.memberName}',
  );
}

class _DependencyBatch implements WriteBatch {
  _DependencyBatch(this.owner);
  final _DependencyFirestore owner;
  final writes = <Map<String, dynamic>>[];
  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    if (options?.merge != true) {
      throw StateError('Expected unchanged real writer merge:true');
    }
    writes.add({
      'path': document.path,
      'data': _copyDependencyWire(data),
      'merge': options!.merge,
    });
  }

  @override
  Future<void> commit() async {
    final hook = owner.beforeNextCommit;
    owner.beforeNextCommit = null;
    if (hook != null) await hook(writes);
    final before = _copyDependencyWire(owner.documents);
    for (final write in writes) {
      final path = write['path'] as String;
      owner.documents[path] = {
        ...?owner.documents[path],
        ...Map<String, dynamic>.from(write['data'] as Map),
      };
    }
    owner.batches.add({
      'phase': owner.phase,
      'writes': _copyDependencyWire(writes),
      'beforeDocuments': before,
      'afterDocuments': _copyDependencyWire(owner.documents),
      'acceptance': 'PRIVATE_TRANSPORT_ONLY_NOT_RULES',
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unimplemented test batch call: ${invocation.memberName}',
  );
}

class _DependencyNoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Network is forbidden in the dependency regression');
}
