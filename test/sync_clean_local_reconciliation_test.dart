import 'dart:io';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/providers/sync_conflict_provider.dart';
import 'package:crm3_baf_ops/core/providers/sync_status_provider.dart';
import 'package:crm3_baf_ops/core/services/global_pull_cursor_store.dart';
import 'package:crm3_baf_ops/core/services/global_pull_protocol.dart';
import 'package:crm3_baf_ops/core/services/global_pull_service.dart';
import 'package:crm3_baf_ops/core/services/isar_schema_migration.dart';
import 'package:crm3_baf_ops/core/services/live_remote_sync_service.dart';
import 'package:crm3_baf_ops/core/services/local_recovery_session_guard.dart';
import 'package:crm3_baf_ops/core/services/remote_tombstone_apply_result.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/remote_maintenance_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_pull_service.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_uncertain_retry_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/planned_job_server_completion_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart' hide Query;
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/test_isar_core.dart';

const _actor = 'reconciliation-operator';
const _generation = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _runId = '11111111-1111-4111-8111-111111111111';
const _digest =
    'auth1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final _oldAnchor = DateTime.utc(2026, 9, 8, 8);
final _remoteTime = DateTime.utc(2026, 9, 8, 8, 5);
final _localTime = DateTime.utc(2026, 9, 8, 9);
final _anchor = DateTime.utc(2026, 9, 8, 10);

void main() {
  setUpAll(initializeTestIsarCore);

  for (final batchFails in [false, true]) {
    test(
      'audit session ending after remote ${batchFails ? 'fallback' : 'batch'} response leaves native acknowledgements pending',
      () async {
        await _withIsar((isar) async {
          var ended = false;
          final first = AuditEvent(
            entityType: 'maintenance',
            entityId: 'first',
            action: AuditAction.update,
            performedByUid: _actor,
            after: {'description': 'Original unsent findings'},
          )..timestamp = _oldAnchor;
          final second = AuditEvent(
            entityType: 'maintenance',
            entityId: 'second',
            action: AuditAction.update,
            performedByUid: _actor,
            after: {'description': 'Later unsent findings'},
          )..timestamp = _localTime;
          await isar.writeTxn(() => isar.auditEvents.putAll([first, second]));
          final audit = _GuardedNativeAudit(
            batchFails: batchFails,
            endSession: () {
              ended = true;
            },
          );
          await expectLater(
            audit.syncPendingAuditEvents(
              batchSize: 1,
              runGuard: SyncRunGuard(() {
                if (ended) throw const SyncRunAborted('approved session ended');
              }),
            ),
            throwsA(isA<SyncRunAborted>()),
          );
          expect(audit.batchIds, [
            ['first'],
          ]);
          expect(audit.individualIds, batchFails ? ['first'] : isEmpty);
          expect(await audit.countPendingAuditEvents(), 2);
          for (final original in [first, second]) {
            final persisted = (await isar.auditEvents.get(original.id))!;
            expect(persisted.isSynced, isFalse);
            expect(persisted.afterJson, original.afterJson);
            expect(persisted.performedByUid, _actor);
          }
        });
      },
    );
  }

  test('an already invalid session cannot start global pull', () async {
    await _withIsar((isar) async {
      final preferences = await _preparePreferences();
      final remote = _MaintenanceRemote([
        _record('unread', 1, _anchor, 'Must not be adopted'),
      ]);
      final knowledge = _Knowledge();
      final pull = _pull(remote, _Audit(), knowledge);
      await expectLater(
        pull.pullAndReconcile(
          runGuard: SyncRunGuard(() {
            throw const SyncRunAborted('approved session ended');
          }),
        ),
        throwsA(isA<SyncRunAborted>()),
      );
      expect(knowledge.calls, 0);
      expect(remote.requestedSince, isEmpty);
      expect(await isar.maintenanceRecords.count(), 0);
      expect(
        SharedPreferencesGlobalPullCursorStore(
          preferences,
        ).read(actorUid: _actor, databaseGenerationId: _generation),
        isNull,
      );
    });
  });

  test(
    'same-UID authority revocation stops the next pull domain and cursor completion',
    () async {
      await _withIsar((isar) async {
        final preferences = await _preparePreferences();
        var revoked = false;
        final remote = _MaintenanceRemote([
          _record('unread', 1, _anchor, 'Adopt only on a new run'),
        ]);
        final knowledge = _Knowledge()
          ..onPull = () {
            revoked = true;
          };
        final pull = _pull(remote, _Audit(), knowledge);
        await expectLater(
          pull.pullAndReconcile(
            runGuard: SyncRunGuard(() {
              if (revoked) throw const SyncRunAborted('authority revoked');
            }),
          ),
          throwsA(isA<SyncRunAborted>()),
        );
        expect(knowledge.calls, 1);
        expect(remote.requestedSince, isEmpty);
        expect(await isar.maintenanceRecords.count(), 0);
        final cursorStore = SharedPreferencesGlobalPullCursorStore(preferences);
        final interrupted = cursorStore.read(
          actorUid: _actor,
          databaseGenerationId: _generation,
        )!;
        expect(interrupted.state, GlobalPullRunState.prepared);
        expect(
          interrupted.cursorFor(GlobalPullDomain.knowledgeBase).completedInRun,
          isFalse,
        );
        // A failed run must release its active guard. Existing direct callers
        // remain UID-gated and can retry under their own current authority.
        await pull.pullAndReconcile();
        expect(remote.requestedSince, hasLength(1));
        expect(
          (await isar.maintenanceRecords.where().findFirst())!.description,
          'Adopt only on a new run',
        );
        expect(
          cursorStore
              .read(actorUid: _actor, databaseGenerationId: _generation)!
              .state,
          GlobalPullRunState.committed,
        );
      });
    },
  );

  for (final deleteTime in [_localTime, _anchor]) {
    test(
      'actual pull retains tombstone policy for dirty rows at or before $deleteTime',
      () async {
        await _withIsar((isar) async {
          await _preparePreferences();
          final dirty = _record(
            'deleted',
            3,
            _localTime,
            'Unsent local evidence',
          )..isSynced = false;
          await isar.writeTxn(() => isar.maintenanceRecords.put(dirty));
          final tombstone = _record('deleted', 4, deleteTime, 'Server deletion')
            ..isDeleted = true
            ..deletedAt = deleteTime
            ..deletedByUid = _actor;
          final pull = _pull(
            _MaintenanceRemote([tombstone]),
            _Audit(),
            _Knowledge(),
          );
          await pull.pullAndReconcile();
          final retained = (await isar.maintenanceRecords.get(dirty.id))!;
          expect(retained.isDeleted, isTrue);
          expect(retained.isSynced, isTrue);
          expect(retained.deletedAt?.toUtc(), deleteTime);
          expect(retained.version, 4);
          expect(pull.lastDeleted, 1);
        });
      },
    );
  }

  test(
    'early push fetch failure still pulls clean updates and preserves the exact dirty native row',
    () async {
      await _withIsar((isar) async {
        final preferences = await _preparePreferences();
        final dirty =
            _record('unsent', 3, _localTime, 'Unsent operator findings')
              ..isSynced = false
              ..remarks = 'Do not discard this local evidence';
        final clean = _record('clean', 1, _oldAnchor, 'Old clean state');
        await isar.writeTxn(
          () => isar.maintenanceRecords.putAll([dirty, clean]),
        );
        final before = (await isar.maintenanceRecords.get(
          dirty.id,
        ))!.toAuditMap();
        final remote = _FailedMaintenancePush([
          _record('unsent', 8, _anchor, 'Different authoritative evidence'),
          _record('clean', 2, _anchor, 'Clean server update adopted'),
        ]);
        final audit = _Audit();
        final knowledge = _Knowledge();
        final empty = _EmptyPushRepositories();
        final push = SyncService(
          maintenanceRepo: IsarMaintenanceRepository(),
          firestoreMaintenance: remote,
          plannedRepo: empty,
          firestorePlanned: empty,
          serverCompletion: _NoServerCompletion(),
          jobDiaryRepo: empty,
          firestoreJobDiary: empty,
          jobModuleRepo: empty,
          firestoreJobModule: empty,
          templateGovernanceRepo: empty,
          firestoreTemplateGovernance: empty,
          directiveRepo: empty,
          firestoreDirective: empty,
          abnormalityRepo: empty,
          firestoreAbnormality: empty,
          knowledgeRepo: knowledge,
          auditRepository: audit,
          auth: _Auth(),
          rejectionOwnerUidLookup: () => _actor,
        );
        final pull = _pull(remote, audit, knowledge);
        final coordinatorProvider = Provider<SyncCoordinator>((ref) {
          final coordinator = SyncCoordinator(
            ref,
            push,
            pull,
            LocalRecoverySessionGuard(),
            runGuardFactory: () => SyncRunGuard(() {}),
            connectivity: _NoConnectivity(),
          );
          ref.onDispose(coordinator.dispose);
          return coordinator;
        });
        final container = ProviderContainer(
          overrides: [
            // Purge reconciliation is outside this scenario. Actual pull still
            // obtains its independent approved authority from _Authority.
            currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
            workflowUncertainRetryServiceProvider.overrideWithValue(
              _EmptyWorkflowRetry(),
            ),
            workflowRepositoryProvider.overrideWithValue(
              _EmptyWorkflowRepository(),
            ),
            workflowPullServiceProvider.overrideWithValue(_EmptyWorkflowPull()),
          ],
        );
        try {
          final outcome = await container
              .read(coordinatorProvider)
              .runFullSyncWithResult(
                reason: 'CF-02 native preservation',
                force: true,
              );
          expect(remote.pushReads, [
            ['unsent'],
          ]);
          expect(
            remote.requestedSince,
            hasLength(1),
            reason:
                'A recoverable early push fetch failure must not skip real pull.',
          );
          expect(knowledge.pushCalls, 1);
          expect(audit.pushCalls, 1);
          expect(empty.calls, contains(#getUnsyncedAbnormalities));
          final retained = (await isar.maintenanceRecords.get(dirty.id))!;
          expect(retained.id, dirty.id);
          expect(retained.toAuditMap(), before);
          expect(retained.isSynced, isFalse);
          expect(retained.isDeleted, isFalse);
          expect(
            (await isar.maintenanceRecords.get(clean.id))!.description,
            'Clean server update adopted',
          );
          expect(
            (await isar.maintenanceRecords.get(clean.id))!.isSynced,
            isTrue,
          );
          expect(pull.lastConflicted, 1);
          expect(pull.lastConflictKeys, {'maintenance ticket:unsent'});
          expect(
            audit.events.single.before!['description'],
            'Unsent operator findings',
          );
          expect(
            audit.events.single.after!['description'],
            'Different authoritative evidence',
          );
          final cursor = SharedPreferencesGlobalPullCursorStore(
            preferences,
          ).read(actorUid: _actor, databaseGenerationId: _generation)!;
          expect(cursor.state, GlobalPullRunState.committed);
          expect(push.lastFailureCount, greaterThan(0));
          expect(
            push.lastFailureDetails.any(
              (detail) => detail.errorCode == 'unavailable',
            ),
            isTrue,
          );
          expect(outcome, SyncRequestOutcome.partial);
          expect(container.read(syncStatusProvider), SyncStatus.partial);
          expect(container.read(syncRunHealthProvider).lastSucceeded, isFalse);
          expect(
            container.read(syncRunHealthProvider).lastPartiallySucceeded,
            isTrue,
          );
          expect(container.read(syncConflictProvider), 1);
        } finally {
          container.dispose();
        }
      });
    },
  );

  test(
    'live mirror disposal does not read its disposed provider owner',
    () async {
      await _withIsar((isar) async {
        final container = ProviderContainer();
        final live = LiveRemoteSyncService(isar, container.read);
        live.pauseForLifecycle();
        live.stop();
        expect(
          container.read(liveRemoteSyncHealthProvider).maintenanceState,
          LiveRemoteSyncConnectionState.disconnected,
        );
        container.dispose();
        expect(live.dispose, returnsNormally);
        expect(live.dispose, returnsNormally);
        expect(live.stop, returnsNormally);
        expect(live.pauseForLifecycle, returnsNormally);
        expect(live.resumeAfterLifecyclePause, returnsNormally);
      });
    },
  );

  test(
    'malformed directive page retains cursor while valid rows on later pages are adopted',
    () async {
      await _withIsar((isar) async {
        final prefs = await _preparePreferences();
        final pages = _PartialDirectives();
        final pull = _pull(
          _MaintenanceRemote([
            _record('maintenance-control', 1, _remoteTime, 'Control'),
          ]),
          _Audit(),
          _Knowledge(),
          directivePages: pages,
        );
        await expectLater(
          pull.pullAndReconcile(),
          throwsA(
            isA<GlobalPullCursorException>().having(
              (e) => e.reasonCode,
              'reason',
              'domain-record-processing-failed',
            ),
          ),
        );
        expect(pages.adopted, ['directive-first', 'directive-second']);
        expect(pages.calls, 2);
        final envelope = SharedPreferencesGlobalPullCursorStore(
          prefs,
        ).read(actorUid: _actor, databaseGenerationId: _generation)!;
        expect(
          envelope.cursorFor(GlobalPullDomain.directives).completedInRun,
          isFalse,
        );
        expect(await DirectiveReadHealth.incomplete(_actor), isTrue);
      });
    },
  );

  test(
    'pull retains the failed cursor across restart and audits preserved evidence',
    () async {
      await _withIsar((isar) async {
        final preferences = await _preparePreferences();
        final cursorStore = SharedPreferencesGlobalPullCursorStore(preferences);
        var baseline = await cursorStore.begin(
          actorUid: _actor,
          databaseGenerationId: _generation,
          authority: _authority(_oldAnchor),
          runId: _runId,
        );
        for (final domain in GlobalPullDomain.values) {
          baseline = await cursorStore.completeDomain(baseline, domain);
        }
        await cursorStore.commit(baseline);

        final local = _record(
          'skewed',
          3,
          _localTime,
          'Retained local evidence',
        );
        final dirty = _record('unsent', 2, _localTime, 'Unsent unrelated work')
          ..isSynced = false;
        await isar.writeTxn(
          () => isar.maintenanceRecords.putAll([local, dirty]),
        );
        final remote = _MaintenanceRemote([
          _record('skewed', 7, _remoteTime, 'Authoritative higher version'),
        ]);
        final audit = _Audit();
        final knowledge = _Knowledge();
        final pull = _pull(remote, audit, knowledge);

        final pending = throwsA(
          isA<GlobalPullCursorException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'domain-clean-local-reconciliation-required',
          ),
        );
        final coordinatorProvider = Provider<SyncCoordinator>((ref) {
          final coordinator = SyncCoordinator(
            ref,
            _Push(),
            pull,
            LocalRecoverySessionGuard(),
            runGuardFactory: () => SyncRunGuard(() {}),
            connectivity: _NoConnectivity(),
          );
          ref.onDispose(coordinator.dispose);
          return coordinator;
        });
        final container = ProviderContainer();
        try {
          final outcome = await container
              .read(coordinatorProvider)
              .runFullSyncWithResult(
                reason: 'reconciliation regression',
                force: true,
              );
          expect(outcome, SyncRequestOutcome.failed);
          expect(container.read(syncConflictProvider), 1);
          expect(container.read(syncStatusProvider), SyncStatus.failed);
          expect(container.read(syncRunHealthProvider).lastSucceeded, isFalse);
          expect(container.read(syncRunHealthProvider).conflictCount, 1);
          expect(
            container.read(syncRunHealthProvider).lastError,
            contains('reconciliation'),
          );
        } finally {
          container.dispose();
        }
        expect(pull.lastFailedDomain, GlobalPullDomain.maintenanceRecords);
        expect(pull.lastConflicted, 1);
        expect(pull.lastConflictKeys, {'maintenance ticket:skewed'});
        expect(audit.events, hasLength(1));
        expect(
          audit.events.single.before!['description'],
          'Retained local evidence',
        );
        expect(
          audit.events.single.after!['description'],
          'Authoritative higher version',
        );
        expect(
          audit.events.single.reasonNotes,
          contains('cursor completion was blocked'),
        );
        final retained = cursorStore.read(
          actorUid: _actor,
          databaseGenerationId: _generation,
        )!;
        expect(retained.state, GlobalPullRunState.prepared);
        expect(
          retained.cursorFor(GlobalPullDomain.knowledgeBase).completedInRun,
          isTrue,
        );
        expect(
          retained.cursorFor(GlobalPullDomain.maintenanceRecords).cursor,
          _oldAnchor,
        );
        expect(
          retained
              .cursorFor(GlobalPullDomain.maintenanceRecords)
              .completedInRun,
          isFalse,
        );
        expect((await isar.maintenanceRecords.get(local.id))!.version, 3);
        expect(
          (await isar.maintenanceRecords.get(dirty.id))!.isSynced,
          isFalse,
        );

        // A new coordinator uses the persisted pending domain rather than
        // forgetting the rejected server version on restart.
        final restarted = _pull(remote, audit, knowledge);
        await expectLater(restarted.pullAndReconcile(), pending);
        expect(remote.requestedSince, [_oldAnchor, _oldAnchor]);
        expect(knowledge.calls, 1);

        // A later unambiguous server change can satisfy the obligation normally.
        remote.records = [
          _record('skewed', 8, _anchor, 'Reconciled server state'),
        ];
        await restarted.pullAndReconcile();
        final complete = cursorStore.read(
          actorUid: _actor,
          databaseGenerationId: _generation,
        )!;
        expect(complete.state, GlobalPullRunState.committed);
        expect(
          complete.cursorFor(GlobalPullDomain.maintenanceRecords).cursor,
          _anchor,
        );
        expect(restarted.lastFailedDomain, isNull);
        expect(restarted.lastConflicted, 0);
        expect(
          (await isar.maintenanceRecords.get(local.id))!.description,
          'Reconciled server state',
        );
        expect(
          (await isar.maintenanceRecords.get(dirty.id))!.description,
          'Unsent unrelated work',
        );
        expect(
          (await isar.maintenanceRecords.get(dirty.id))!.isSynced,
          isFalse,
        );
      });
    },
  );

  test(
    'live reconciliation remains visible across unrelated and older snapshots',
    () async {
      await _withIsar((isar) async {
        final local = _record(
          'skewed',
          3,
          _localTime,
          'Retained local evidence',
        );
        await isar.writeTxn(() => isar.maintenanceRecords.put(local));
        final container = ProviderContainer();
        final live = LiveRemoteSyncService(isar, container.read);
        try {
          await live.applyMaintenanceSnapshotForTesting(
            _snapshot(
              _record('skewed', 7, _remoteTime, 'Higher server version'),
            ),
          );
          expect(container.read(liveRemoteSyncHealthProvider).hasError, isTrue);
          expect(
            container.read(liveRemoteSyncHealthProvider).lastError,
            contains('reconciliation'),
          );
          expect(container.read(liveRemoteSyncHealthProvider).appliedCount, 0);
          expect(
            (await isar.maintenanceRecords.get(local.id))!.description,
            'Retained local evidence',
          );

          await live.applyMaintenanceSnapshotForTesting(
            _snapshot(
              _record(
                'another',
                1,
                _remoteTime,
                'Unrelated successful refresh',
              ),
            ),
          );
          expect(container.read(liveRemoteSyncHealthProvider).hasError, isTrue);
          expect(container.read(liveRemoteSyncHealthProvider).appliedCount, 1);
          // Even an exact match of the old local boundary must not clear the
          // already-observed higher server version's reconciliation obligation.
          await live.applyMaintenanceSnapshotForTesting(_snapshot(local));
          expect(container.read(liveRemoteSyncHealthProvider).hasError, isTrue);

          await expectLater(
            live.applyMaintenanceSnapshotForTesting(
              _snapshot(
                _record('skewed', 7, _remoteTime, 'Higher server version'),
              ),
              propagateFailure: true,
            ),
            throwsA(isA<RemoteRecordReconciliationRequiredException>()),
          );
          await live.applyMaintenanceSnapshotForTesting(
            _snapshot(_record('skewed', 8, _anchor, 'Reconciled server state')),
          );
          expect(
            container.read(liveRemoteSyncHealthProvider).hasError,
            isFalse,
          );
          expect(
            container.read(liveRemoteSyncHealthProvider).lastError,
            isNull,
          );
          expect((await isar.maintenanceRecords.get(local.id))!.version, 8);
        } finally {
          live.dispose();
          container.dispose();
        }
      });
    },
  );

  test(
    'genuinely older server version remains an ordinary non-destructive skip',
    () async {
      await _withIsar((isar) async {
        final local = _record('skewed', 7, _remoteTime, 'Current local state');
        await isar.writeTxn(() => isar.maintenanceRecords.put(local));
        final result = await IsarMaintenanceRepository()
            .applyMaintenanceRecordFromRemote(
              _record('skewed', 3, _localTime, 'Old version with newer clock'),
            );
        expect(result.outcome, RemoteRecordApplyOutcome.staleRemoteSkipped);
        expect(result.remoteIsNewer, isFalse);
        expect((await isar.maintenanceRecords.get(local.id))!.version, 7);
      });
    },
  );
}

GlobalPullService _pull(
  _MaintenanceRemote remote,
  _Audit audit,
  _Knowledge knowledge, {
  _Directives? directivePages,
}) {
  final planned = _Planned();
  final diary = _Diary();
  final modules = _Modules();
  final templates = _Templates();
  final directives = directivePages ?? _Directives();
  final abnormalities = _Abnormalities();
  return GlobalPullService(
    IsarMaintenanceRepository(),
    remote,
    planned,
    planned,
    diary,
    diary,
    modules,
    modules,
    templates,
    templates,
    directives,
    directives,
    abnormalities,
    abnormalities,
    knowledge,
    audit,
    auth: _Auth(),
    authorityReader: _Authority(),
    runIdFactory: () => _runId,
  );
}

GlobalPullRunAuthority _authority(DateTime anchor) => GlobalPullRunAuthority(
  actorUid: _actor,
  authorityDigest: _digest,
  activatedAt: _oldAnchor.subtract(const Duration(days: 1)),
  serverAnchor: anchor,
);

Future<SharedPreferences> _preparePreferences() async {
  const marker = IsarSchemaProvenanceMarker(
    state: IsarSchemaMarkerState.committed,
    schemaVersion: IsarSchemaMigrator.currentSchemaVersion,
    schemaFingerprint: IsarSchemaMigrator.currentSchemaFingerprint,
    databaseGenerationId: _generation,
    origin: IsarSchemaMarkerOrigin.freshInstall,
    sourceSchemaVersion: null,
    sourceSchemaFingerprint: null,
  );
  SharedPreferences.setMockInitialValues({
    SharedPreferencesIsarSchemaProvenanceStore.canonicalMarkerKey: marker
        .encode(),
  });
  return SharedPreferences.getInstance();
}

MaintenanceRecord _record(
  String id,
  int version,
  DateTime time,
  String description,
) => MaintenanceRecord()
  ..firestoreId = id
  ..version = version
  ..updatedAt = time
  ..isSynced = true
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..component = 'Furnace body'
  ..maintenanceType = MaintenanceType.breakdown
  ..description = description
  ..routedTo = RoutedTo.mechanical
  ..loggedByUid = _actor
  ..loggedByName = 'Reconciliation operator'
  ..startDate = _oldAnchor
  ..createdAt = _oldAnchor;

_Snapshot _snapshot(MaintenanceRecord record) => _validatedSnapshot(
  record.firestoreId!,
  {
    // Complete legacy independent-ticket wire shape, not its audit projection.
    'firestoreId': record.firestoreId,
    'version': record.version,
    'assetType': record.assetType.name,
    'assetNumber': record.assetNumber,
    'component': record.component,
    'description': record.description,
    'status': record.status.name,
    'isResolved': record.isResolved,
    'isCritical': record.isCritical,
    'isDeleted': record.isDeleted,
    if (record.isDeleted) 'deletedAt': record.deletedAt,
    if (record.isDeleted) 'deletedByUid': record.deletedByUid,
    'updatedAt': record.updatedAt,
    'createdAt': record.createdAt,
    'startDate': record.startDate,
    'maintenanceType': record.maintenanceType.name,
    'routedTo': record.routedTo.name,
    'loggedByUid': record.loggedByUid,
    'loggedByName': record.loggedByName,
    'actionsJson': '[]',
    'resolutionHistoryJson': '[]',
    globalPullServerUpdatedAtField: Timestamp.fromDate(_anchor),
  },
);

_Snapshot _validatedSnapshot(String id, Map<String, dynamic> data) {
  // A swallowed decode error must never masquerade as tested sync health.
  readRemoteMaintenanceRecord(data, documentId: id);
  return _Snapshot(id, data);
}

Future<void> _withIsar(Future<void> Function(Isar) body) async {
  final directory = await Directory.systemTemp.createTemp(
    'sync_reconciliation_',
  );
  final isar = await Isar.open([
    MaintenanceRecordSchema,
    SyncRejectionSchema,
    AuditEventSchema,
  ], directory: directory.path);
  app.isar = isar;
  try {
    await body(isar);
  } finally {
    await isar.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

// Test-only Firestore boundary; all decoding and native persistence stay real.
// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
  @override
  SnapshotMetadata get metadata => _Metadata();
}

class _Metadata extends Fake implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
  @override
  bool get isFromCache => false;
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => _actor;
  @override
  String? get displayName => 'Reconciliation operator';
  @override
  String? get email => null;
}

class _Authority implements GlobalPullAuthorityReader {
  @override
  Future<GlobalPullRunAuthority> beginRun({
    required String expectedUid,
  }) async => _authority(_anchor);
}

class _NoConnectivity extends Fake implements Connectivity {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _Push extends Fake implements SyncService {
  @override
  Future<void> syncAll({
    bool recheckPermanentRejections = false,
    SyncRunGuard? runGuard,
  }) async {}
  @override
  int get lastSuccessCount => 0;
  @override
  int get lastFailureCount => 0;
  @override
  int get lastConflictCount => 0;
  @override
  Set<String> get lastDeferredPushStages => {};
  @override
  Set<String> get lastDeferredPushRecordKeys => {};
  @override
  int get lastFailureDetailOverflowCount => 0;
  @override
  List<SyncFailureDetail> get lastFailureDetails => const [];
}

class _MaintenanceRemote extends Fake
    implements FirestoreMaintenanceRepository {
  _MaintenanceRemote(this.records);
  List<MaintenanceRecord> records;
  final requestedSince = <DateTime?>[];
  @override
  Future<PaginatedMaintenanceResult> getUpdatedTickets({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    requestedSince.add(since);
    return PaginatedMaintenanceResult(
      records: records,
      lastDoc: _snapshot(records.last),
    );
  }
}

class _Audit extends Fake implements AuditRepository {
  final events = <AuditEvent>[];
  int pushCalls = 0;
  @override
  Future<AuditSyncResult> syncPendingAuditEvents({
    int batchSize = 450,
    SyncRunGuard? runGuard,
  }) async {
    pushCalls++;
    return AuditSyncResult.empty;
  }

  @override
  Future<void> log(
    AuditEvent event, {
    bool syncToRemote = true,
    SyncRunGuard? runGuard,
  }) async {
    events.add(event);
  }
}

class _Knowledge extends Fake implements BafKnowledgeRepository {
  int calls = 0;
  int pushCalls = 0;
  void Function()? onPull;
  @override
  Future<int> syncUnsyncedToCloud({SyncRunGuard? runGuard}) async {
    pushCalls++;
    return 0;
  }

  @override
  Future<BafKnowledgePullResult> pullCloudToLocal([
    DateTime? since,
    DateTime? through,
  ]) async {
    calls++;
    onPull?.call();
    return const BafKnowledgePullResult();
  }
}

class _EmptyWorkflowRetry extends Fake
    implements WorkflowUncertainRetryService {
  @override
  Future<WorkflowRetryRunSummary> retryDueCommands({
    SyncRunGuard? runGuard,
  }) async => const WorkflowRetryRunSummary();
}

class _EmptyWorkflowRepository extends Fake implements WorkflowRepository {
  @override
  Future<WorkflowOutcomeInventory> readOutcomeInventory() async =>
      const WorkflowOutcomeInventory();
}

class _EmptyWorkflowPull extends Fake implements WorkflowPullService {
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

// Empty remote pages keep the runtime coordinator's normal sequence intact.
// Any unexpected read or write fails via Fake rather than accessing Firebase.
class _EmptyPages extends Fake {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return switch (invocation.memberName) {
      #getUpdatedPackages => Future.value(
        PaginatedTemplatePackageResult(records: []),
      ),
      #getUpdatedVersions => Future.value(
        PaginatedTemplateVersionResult(records: []),
      ),
      #getUpdatedAudits => Future.value(
        PaginatedTemplateAuditResult(records: []),
      ),
      #getUpdatedTemplates => Future.value(
        PaginatedTemplateResult(records: []),
      ),
      #getUpdatedExecutions => Future.value(
        PaginatedExecutionResult(records: []),
      ),
      #getUpdatedEntries => Future.value(PaginatedDiaryResult(records: [])),
      #getUpdatedModules => Future.value(PaginatedJobModuleResult(records: [])),
      #getUpdatedDirectives => Future.value(
        PaginatedDirectivesResult(records: []),
      ),
      #getUpdatedTypes => Future.value(
        PaginatedAbnormalityTypesResult(records: []),
      ),
      #getUpdatedAbnormalities => Future.value(
        PaginatedChargeAbnormalitiesResult(records: []),
      ),
      _ => super.noSuchMethod(invocation),
    };
  }
}

class _FailedMaintenancePush extends _MaintenanceRemote {
  _FailedMaintenancePush(super.records);
  final pushReads = <List<String>>[];

  @override
  Future<List<MaintenanceRecord>> getTicketsByFirestoreIds(
    List<String> ids,
  ) async {
    pushReads.add(List.of(ids));
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'Synthetic early maintenance batch fetch failure',
    );
  }
}

class _GuardedNativeAudit extends AuditRepository {
  _GuardedNativeAudit({required this.batchFails, required this.endSession});
  final bool batchFails;
  final void Function() endSession;
  final batchIds = <List<String>>[];
  final individualIds = <String>[];

  @override
  Future<void> logBatchRemote(List<AuditEvent> events) async {
    batchIds.add(events.map((event) => event.entityId).toList());
    if (batchFails) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    endSession();
  }

  @override
  Future<void> logRemote(AuditEvent event) async {
    individualIds.add(event.entityId);
    endSession();
  }
}

class _NoServerCompletion extends Fake
    implements PlannedJobServerCompletionService {}

/// Empty independent domains leave the production push orchestration intact.
/// Only its repository boundaries are substituted; all local maintenance reads,
/// remote application, conflict accounting, and cursor writes remain real.
class _EmptyPushRepositories extends Fake
    implements
        PlannedMaintenanceRepository,
        JobDiaryRepository,
        JobModuleRepository,
        TemplateGovernanceRepository,
        DirectiveRepository,
        AbnormalityRepository {
  final calls = <Symbol>[];

  @override
  Future<RemoteTombstoneApplyResult> applyTombstoneFromRemote(Object remote) =>
      throw StateError('Empty push fixtures cannot apply a tombstone.');

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (const {
      #getUnsyncedTemplates,
      #getUnsyncedExecutions,
      #getUnsyncedEntries,
      #getUnsyncedModules,
      #getUnsyncedPackages,
      #getUnsyncedVersions,
      #getUnsyncedAudits,
      #getUnsyncedDirectives,
      #getUnsyncedTypes,
      #getUnsyncedAbnormalities,
    }.contains(invocation.memberName)) {
      calls.add(invocation.memberName);
      return Future.value(<Never>[]);
    }
    return super.noSuchMethod(invocation);
  }
}

class _Planned extends _EmptyPages implements FirestorePlannedRepository {}

class _Diary extends _EmptyPages implements FirestoreJobDiaryRepository {}

class _Modules extends _EmptyPages implements FirestoreJobModuleRepository {}

class _Templates extends _EmptyPages
    implements FirestoreTemplateGovernanceRepository {}

class _Directives extends _EmptyPages implements FirestoreDirectiveRepository {}

class _Abnormalities extends _EmptyPages
    implements FirestoreAbnormalityRepository {}

class _PartialDirectives extends _Directives {
  int calls = 0;
  final adopted = <String>[];
  @override
  Future<PaginatedDirectivesResult> getUpdatedDirectives({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    calls++;
    return PaginatedDirectivesResult(
      records: [
        OperationalDirective()
          ..firestoreId = (calls == 1 ? 'directive-first' : 'directive-second'),
      ],
      rawCount: calls == 1 ? 500 : 1,
      rejectedIds: calls == 1 ? ['malformed-row'] : [],
      lastDoc: _Snapshot('page-$calls', {
        globalPullServerUpdatedAtField: Timestamp.fromDate(_anchor),
      }),
    );
  }

  @override
  Future<RemoteRecordApplyResult<OperationalDirective>>
  applyDirectiveFromRemote(OperationalDirective remote) async {
    adopted.add(remote.firestoreId!);
    return RemoteRecordApplyResult<OperationalDirective>(
      RemoteRecordApplyOutcome.inserted,
      localRecord: remote,
    );
  }
}
