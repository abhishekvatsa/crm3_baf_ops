import 'dart:io';

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
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/remote_maintenance_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
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
  _Knowledge knowledge,
) {
  final planned = _Planned();
  final diary = _Diary();
  final modules = _Modules();
  final templates = _Templates();
  final directives = _Directives();
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
  Future<void> syncAll({bool recheckPermanentRejections = false}) async {}
  @override
  int get lastSuccessCount => 0;
  @override
  int get lastFailureCount => 0;
  @override
  int get lastConflictCount => 0;
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
  @override
  Future<void> log(AuditEvent event, {bool syncToRemote = true}) async {
    events.add(event);
  }
}

class _Knowledge extends Fake implements BafKnowledgeRepository {
  int calls = 0;
  @override
  Future<BafKnowledgePullResult> pullCloudToLocal([
    DateTime? since,
    DateTime? through,
  ]) async {
    calls++;
    return const BafKnowledgePullResult();
  }
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

class _Planned extends _EmptyPages implements FirestorePlannedRepository {}

class _Diary extends _EmptyPages implements FirestoreJobDiaryRepository {}

class _Modules extends _EmptyPages implements FirestoreJobModuleRepository {}

class _Templates extends _EmptyPages
    implements FirestoreTemplateGovernanceRepository {}

class _Directives extends _EmptyPages implements FirestoreDirectiveRepository {}

class _Abnormalities extends _EmptyPages
    implements FirestoreAbnormalityRepository {}
