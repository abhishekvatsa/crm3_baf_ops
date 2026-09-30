import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_workflow_evidence.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'plant_asset_overview_test.dart' as fixture;

final _at = DateTime.utc(2026, 9, 1);
final _baseClass = fixture.assetClass(
  id: 'bases',
  code: 'BASE',
  name: 'Base',
  legacyKey: 'base',
);
final _base = fixture.asset(
  id: 'base-101',
  assetClass: _baseClass,
  number: 101,
);

InnerCoverProfile _cover({
  String id = 'cover-g66',
  String serial = 'G66',
  int? base = 101,
}) => InnerCoverProfile(
  id: id,
  assetClassId: 'covers',
  assetClassCode: 'IC',
  assetClassName: 'Inner Cover',
  serialNumber: serial,
  normalizedSerialNumber: serial,
  sourceType: InnerCoverSourceType.legacyExisting,
  lifecycleState: base == null
      ? InnerCoverLifecycleState.underRepair
      : InnerCoverLifecycleState.installed,
  traceabilityGrade: InnerCoverTraceabilityGrade.t0,
  currentBaseAssetInstanceId: base == null ? null : 'base-$base',
  currentBaseAssetNumber: base,
  currentBaseAssetName: base == null ? null : 'Base $base',
  currentLinkageId: base == null ? null : 'link-$base',
  version: 2,
  createdAt: _at,
  updatedAt: _at,
  lastMutationId: 'fixture',
);

Map<String, dynamic> _position({String serial = 'G66'}) => {
  'baseAssetInstanceId': 'base-101',
  'baseAssetClassId': 'bases',
  'baseAssetNumber': 101,
  'innerCoverId': 'cover-g66',
  'innerCoverSerialNumber': serial,
  'linkageId': 'link-101',
  'assignmentVersion': 1,
};

Map<String, dynamic> _workflowData({
  String executionId = 'execution-1',
  String status = 'inProgress',
  String? kind,
  bool red = false,
  bool preparation = false,
}) => {
  'jobExecutionId': executionId,
  'assetTypeKey': 'innerCover',
  'assetNumber': 101,
  'assetClassId': 'bases',
  'assetInstanceId': 'base-101',
  'innerCoverId': 'cover-g66',
  'innerCoverSerialNumber': 'G66',
  'innerCoverLinkageId': 'link-101',
  'innerCoverAssignmentVersion': 1,
  'status': status,
  'version': 2,
  'workflowSchemaVersion': 1,
  'laneSetVersion': 1,
  if (kind != null) 'workflowKind': kind,
  'cancelled': status == 'cancelled',
  'activeRedWork': red,
  'awaitingPreparation': preparation,
  'createdAt': _at.toIso8601String(),
  'updatedAt': _at.toIso8601String(),
};

InnerCoverWorkflowEvidence _workflow({
  String id = 'workflow-1',
  String executionId = 'execution-1',
  String status = 'inProgress',
  String? kind,
  bool red = false,
  bool preparation = false,
}) => InnerCoverWorkflowEvidence.fromMap(
  _workflowData(
    executionId: executionId,
    status: status,
    kind: kind,
    red: red,
    preparation: preparation,
  ),
  id,
);

JobExecution _execution({
  String id = 'execution-1',
  bool completed = false,
  bool cancelled = false,
  bool synced = true,
  String serial = 'G66',
}) => JobExecution()
  ..firestoreId = id
  ..assetType = AssetType.innerCover
  ..assetNumber = 101
  ..workflowSchemaVersion = 1
  ..isSynced = synced
  ..isCompleted = completed
  ..isCancelled = cancelled
  ..metadataJson = jsonEncode({
    'assignmentAssetIdentity': {
      'assetClassId': 'bases',
      'assetInstanceId': 'base-101',
      'assetNumber': 101,
    },
    'assignmentInnerCoverPosition': _position(serial: serial),
  });

MaintenanceRecord _ticket({
  String id = 'issue-1',
  MaintenanceIssuePlantConditionEffect effect =
      MaintenanceIssuePlantConditionEffect.unfit,
  bool resolved = false,
  bool synced = true,
}) {
  final ticket = fixture.issueCondition(
    id: id,
    asset: _base,
    effect: effect,
    resolved: resolved,
    synced: synced,
  )..assetType = AssetType.innerCover;
  final reference = _base.toReference().toMap();
  reference['innerCoverAssociation'] = InnerCoverEventReference(
    baseAssetInstanceId: 'base-101',
    baseAssetNumber: 101,
    positionState: InnerCoverPositionState.linked,
    innerCoverId: 'cover-g66',
    innerCoverSerialNumber: 'G66',
    linkageId: 'link-101',
    assignmentVersion: 1,
    linkedAt: DateTime.utc(2026, 8, 1),
    eventAt: DateTime.utc(2026, 8, 14),
    confirmedAt: DateTime.utc(2026, 8, 14),
    confirmedByUid: 'operator',
    confirmedByName: 'Operator',
  ).toMap();
  ticket.assetHierarchyRefJson = jsonEncode(reference);
  return ticket;
}

DecodedSnapshotBatch<T> _batch<T>(
  List<T> rows, {
  bool cache = false,
  bool pending = false,
  bool rejected = false,
}) => DecodedSnapshotBatch(
  records: rows,
  rejectedDocumentIds: rejected ? ['bad-record'] : [],
  isFromCache: cache,
  hasPendingWrites: pending,
);

InnerCoverDependencies _derive({
  List<InnerCoverProfile>? covers,
  List<MaintenanceRecord> tickets = const [],
  List<InnerCoverWorkflowEvidence> workflows = const [],
  List<JobExecution> executions = const [],
  String? unavailableSource,
  String mode = 'cache',
}) {
  DecodedSnapshotBatch<T> batch<T>(String source, List<T> rows) => _batch(
    rows,
    cache: unavailableSource == source && mode == 'cache',
    pending: unavailableSource == source && mode == 'pending',
    rejected: unavailableSource == source && mode == 'rejected',
  );
  return deriveInnerCoverDependencies(
    profiles: batch('profiles', covers ?? [_cover()]),
    tickets: batch('tickets', tickets),
    workflows: batch('workflows', workflows),
    executions: batch('executions', executions),
  );
}

EquipmentStatusRecord _projection({
  int maintenance = 0,
  int red = 0,
  int preparation = 0,
  String? instanceId = 'base-101',
  String? classId = 'bases',
}) => equipmentStatusRecordFromFirestoreData(
  documentId: 'innerCover_101',
  data: {
    'assetTypeKey': 'innerCover',
    'assetNumber': 101,
    if (instanceId != null) 'assetInstanceId': instanceId,
    if (classId != null) 'assetClassId': classId,
    'version': 1,
    'state': red > 0
        ? 'underRED'
        : preparation > 0
        ? 'awaitingPreparation'
        : maintenance > 0
        ? 'underMaintenance'
        : 'inService',
    'previousState': 'inService',
    'activeNonRedMaintenanceCount': maintenance,
    'activeRedWorkCount': red,
    'awaitingPreparationCount': preparation,
    'updatedAt': _at.toIso8601String(),
  },
);

// Shared integration fixtures. Importing this file does not execute main().
InnerCoverWorkflowEvidence dependencyWorkflowFixture({
  String id = 'workflow-1',
  Map<String, dynamic> overrides = const {},
}) =>
    InnerCoverWorkflowEvidence.fromMap({..._workflowData(), ...overrides}, id);

JobExecution dependencyExecutionFixture({
  String id = 'execution-1',
  Map<String, dynamic>? position,
  bool completed = false,
  bool cancelled = false,
}) {
  final assigned = position ?? _position();
  return _execution(id: id, completed: completed, cancelled: cancelled)
    ..assetNumber = assigned['baseAssetNumber'] as int
    ..metadataJson = jsonEncode({
      'assignmentAssetIdentity': {
        'assetClassId': assigned['baseAssetClassId'],
        'assetInstanceId': assigned['baseAssetInstanceId'],
        'assetNumber': assigned['baseAssetNumber'],
      },
      'assignmentInnerCoverPosition': assigned,
    });
}

void main() {
  test(
    'orphan IC projection cannot certify a serial clear or guess its current binding',
    () {
      final clear = _derive(covers: [_cover(base: 102)]);
      expect(clear.complete, isTrue);
      for (final projection in [
        _projection(maintenance: 1),
        _projection(red: 1),
        _projection(preparation: 1),
        _projection(maintenance: 1, classId: null, instanceId: null),
      ]) {
        final qualified = qualifyInnerCoverDependencyProjections(
          clear,
          _batch([projection]),
        );
        expect(qualified.complete, isFalse);
        expect(
          qualified.byCoverId['cover-g66']!.confirmsNoRestriction,
          isFalse,
        );
        expect(qualified.byCoverId['cover-g66']!.reasons, isEmpty);
      }
    },
  );
  test(
    'projection counters reconcile exact recorded hosts and separate non-RED from RED and preparation',
    () {
      final dependencies = _derive(
        covers: [_cover(base: 102)],
        workflows: [
          _workflow(),
          _workflow(id: 'red', executionId: 'red-exec', red: true),
          _workflow(id: 'prep', executionId: 'prep-exec', preparation: true),
        ],
        executions: [
          _execution(),
          _execution(id: 'red-exec'),
          _execution(id: 'prep-exec'),
        ],
      );
      final projection = _projection(maintenance: 1, red: 1, preparation: 1);
      expect(projection.openMaintenanceCount, 1);
      expect(
        qualifyInnerCoverDependencyProjections(
          dependencies,
          _batch([projection]),
        ).complete,
        isTrue,
      );
      for (final mismatched in [
        _projection(maintenance: 2, red: 1, preparation: 1),
        _projection(
          maintenance: 1,
          red: 1,
          preparation: 1,
          instanceId: 'base-102',
        ),
        _projection(
          maintenance: 1,
          red: 1,
          preparation: 1,
          classId: 'other-class',
        ),
        _projection(maintenance: 1, red: 1, preparation: 1)..assetNumber = 102,
      ]) {
        final result = qualifyInnerCoverDependencyProjections(
          dependencies,
          _batch([mismatched]),
        );
        final state = result.byCoverId['cover-g66']!;
        expect(result.complete, isFalse);
        expect(state.reasons, hasLength(3));
        expect(
          state.hasRedWork &&
              state.isAwaitingPreparation &&
              state.isUnderMaintenance,
          isTrue,
        );
        expect(
          state.reasons.every((r) => r.eventHostAssetId == 'base-101'),
          isTrue,
        );
      }
    },
  );
  test(
    'missing cached pending rejected duplicate and contradictory projection evidence preserves restrictions',
    () {
      final dependencies = _derive(
        workflows: [_workflow()],
        executions: [_execution()],
        tickets: [_ticket()],
      );
      for (final batch in [
        _batch<EquipmentStatusRecord>([]),
        _batch([_projection(maintenance: 1)], cache: true),
        _batch([_projection(maintenance: 1)], pending: true),
        _batch([_projection(maintenance: 1)], rejected: true),
        _batch([_projection(maintenance: 1), _projection(maintenance: 1)]),
        _batch([_projection(maintenance: 1)..isSynced = false]),
        _batch([_projection(maintenance: 1)..stateKey = 'available']),
        _batch([_projection()..stateKey = 'underRED']),
      ]) {
        final result = qualifyInnerCoverDependencyProjections(
          dependencies,
          batch,
        );
        expect(result.complete, isFalse);
        expect(result.byCoverId['cover-g66']!.isUnderMaintenance, isTrue);
        expect(result.byCoverId['cover-g66']!.isUnfit, isTrue);
      }
      for (final batch in [
        _batch<EquipmentStatusRecord>([], cache: true),
        _batch<EquipmentStatusRecord>([], pending: true),
        _batch<EquipmentStatusRecord>([], rejected: true),
      ]) {
        expect(
          qualifyInnerCoverDependencyProjections(_derive(), batch).complete,
          isFalse,
        );
      }
    },
  );
  test(
    'projection qualification never upgrades other incomplete evidence and does not treat Base work as IC work',
    () {
      final incomplete = _derive(unavailableSource: 'tickets');
      expect(
        qualifyInnerCoverDependencyProjections(incomplete, _batch([])),
        same(incomplete),
      );
      final clear = _derive();
      expect(
        qualifyInnerCoverDependencyProjections(
          clear,
          _batch([
            _projection(),
            _projection(maintenance: 9)..assetTypeKey = 'base',
          ]),
        ).complete,
        isTrue,
      );
      expect(
        qualifyInnerCoverDependencyProjections(
          clear,
          _batch([_projection(classId: null, instanceId: null)]),
        ).complete,
        isTrue,
      );
    },
  );
  test(
    'conflicting workflow contributions preserve both adverse families instead of last row winning',
    () {
      final dependencies = _derive(
        workflows: [_workflow(), _workflow(red: true)],
        executions: [_execution()],
      );
      final state = dependencies.byCoverId['cover-g66']!;
      expect(state.complete, isFalse);
      expect(
        state.reasons.map((r) => r.kind),
        containsAll([
          InnerCoverDependencyKind.maintenance,
          InnerCoverDependencyKind.red,
        ]),
      );
    },
  );
  test(
    'exact issue restricts its serial and preserves the recorded host after transfer or delink',
    () {
      final ticket = _ticket();
      final snapshot = ticket.assetHierarchyRefJson;
      for (final base in <int?>[101, 102, null]) {
        final result = _derive(
          covers: [_cover(base: base)],
          tickets: [ticket],
        );
        final state = result.byCoverId['cover-g66']!;
        expect(state.complete, isTrue);
        expect(state.isUnfit, isTrue);
        expect(state.reasons.single.eventHostAssetId, 'base-101');
        expect(state.reasons.single.eventLinkageId, 'link-101');
        expect(ticket.assetHierarchyRefJson, snapshot);
      }
    },
  );
  test(
    'Base and Furnace faults with incidental serial snapshots never propagate to the cover',
    () {
      for (final type in [AssetType.base, AssetType.furnace]) {
        final issue = _ticket()..assetType = type;
        expect(
          _derive(
            tickets: [issue],
          ).byCoverId['cover-g66']!.confirmsNoRestriction,
          isTrue,
        );
      }
    },
  );
  test(
    'replacement cover never inherits predecessor restrictions by its host number',
    () {
      final result = _derive(
        covers: [
          _cover(base: null),
          _cover(id: 'replacement', serial: 'G67'),
        ],
        tickets: [_ticket()],
      );
      expect(result.byCoverId['cover-g66']!.isUnfit, isTrue);
      expect(result.byCoverId['replacement']!.confirmsNoRestriction, isTrue);
    },
  );
  test(
    'multiple issues keep remaining restriction after one server-confirmed closure',
    () {
      final result = _derive(
        tickets: [
          _ticket(resolved: true),
          _ticket(
            id: 'issue-2',
            effect: MaintenanceIssuePlantConditionEffect.unavailable,
          ),
        ],
      );
      final state = result.byCoverId['cover-g66']!;
      expect(state.isUnfit, isFalse);
      expect(state.isUnavailable, isTrue);
      expect(state.reasons.single.sourceId, 'issue-2');
    },
  );
  test(
    'pending closure and still-relevant administrative closure retain their own reason',
    () {
      final pending = _ticket(resolved: true, synced: false);
      expect(
        _derive(tickets: [pending]).byCoverId['cover-g66']!.isUnfit,
        isTrue,
      );
      expect(_derive(tickets: [pending]).complete, isFalse);
      for (final disposition in IssueAdministrativeClosureDisposition.values) {
        final closed = _ticket(resolved: true)
          ..status = TicketStatus.closedWithoutResolution
          ..administrativeClosure = IssueAdministrativeClosure(
            disposition: disposition,
            reason: 'Reviewed',
          );
        expect(
          _derive(tickets: [closed]).byCoverId['cover-g66']!.hasRestrictions,
          disposition == IssueAdministrativeClosureDisposition.stillRelevant,
        );
      }
    },
  );
  test(
    'cached pending and rejected feeds retain adverse evidence without clean certification',
    () {
      for (final source in ['profiles', 'tickets', 'workflows', 'executions']) {
        for (final mode in ['cache', 'pending', 'rejected']) {
          final state = _derive(
            tickets: [_ticket()],
            unavailableSource: source,
            mode: mode,
          ).byCoverId['cover-g66']!;
          expect(state.complete, isFalse, reason: '$source $mode');
          expect(state.isUnfit, isTrue);
          expect(state.confirmsNoRestriction, isFalse);
          expect(
            _derive(
              unavailableSource: source,
              mode: mode,
            ).byCoverId['cover-g66']!.confirmsNoRestriction,
            isFalse,
          );
        }
      }
    },
  );
  test(
    'legacy missing or contradictory issue serial identity remains unverified, never guessed from current host',
    () {
      final noId = _ticket()..firestoreId = null;
      expect(_derive(tickets: [noId]).complete, isFalse);
      final legacy = _ticket()
        ..assetHierarchyRefJson = _base.toReference().encode();
      expect(_derive(tickets: [legacy]).complete, isFalse);
      expect(
        _derive(tickets: [legacy]).byCoverId['cover-g66']!.hasRestrictions,
        isFalse,
      );
      final different = _derive(
        covers: [_cover(serial: 'OTHER')],
        tickets: [_ticket()],
      );
      expect(different.complete, isFalse);
      expect(different.byCoverId['cover-g66']!.confirmsNoRestriction, isFalse);
    },
  );
  test(
    'DTO requires exact active serial and explicit valid state; no demand for historical terminal identity',
    () {
      for (final field in [
        'innerCoverId',
        'innerCoverSerialNumber',
        'innerCoverLinkageId',
        'innerCoverAssignmentVersion',
        'assetClassId',
        'assetInstanceId',
        'activeRedWork',
        'awaitingPreparation',
        'cancelled',
      ]) {
        final data = _workflowData()..remove(field);
        expect(
          () => InnerCoverWorkflowEvidence.fromMap(data, 'workflow-1'),
          throwsFormatException,
          reason: field,
        );
      }
      final completed = _workflowData(status: 'completed')
        ..remove('innerCoverId');
      expect(
        InnerCoverWorkflowEvidence.fromMap(completed, 'workflow-1').isTerminal,
        isTrue,
      );
      expect(
        () => InnerCoverWorkflowEvidence.fromMap(
          _workflowData(red: true, preparation: true),
          'workflow-1',
        ),
        throwsFormatException,
      );
      expect(
        () => InnerCoverWorkflowEvidence.fromMap(
          _workflowData(status: 'completed', red: true),
          'workflow-1',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'exact authoritative execution snapshot qualifies maintenance RED and preparation independently',
    () {
      final states = [
        _derive(
          workflows: [_workflow()],
          executions: [_execution()],
        ).byCoverId['cover-g66']!,
        _derive(
          workflows: [_workflow(red: true)],
          executions: [_execution()],
        ).byCoverId['cover-g66']!,
        _derive(
          workflows: [_workflow(preparation: true)],
          executions: [_execution()],
        ).byCoverId['cover-g66']!,
      ];
      expect(states.every((s) => s.complete && s.isUnderMaintenance), isTrue);
      expect(states[0].hasRedWork, isFalse);
      expect(states[1].hasRedWork, isTrue);
      expect(states[2].isAwaitingPreparation, isTrue);
    },
  );
  test(
    'missing malformed contradictory or local execution cannot certify serial clear',
    () {
      for (final jobs in <List<JobExecution>>[
        [],
        [_execution(serial: 'OTHER')],
        [_execution()..metadataJson = '{broken'],
        [_execution(synced: false)],
        [_execution()..metadataJson = null],
        [_execution(completed: true)],
        [_execution(), _execution()],
      ]) {
        final state = _derive(
          workflows: [_workflow()],
          executions: jobs,
        ).byCoverId['cover-g66']!;
        expect(state.complete, isFalse);
        expect(state.isUnderMaintenance, isTrue);
        expect(state.reasons.single.awaitingServerConfirmation, isTrue);
      }
    },
  );
  test(
    'terminal evidence reconciles with parent and removes only that workflow reason',
    () {
      for (final status in ['completed', 'cancelled']) {
        final terminal = _workflow(status: status);
        final execution = _execution(
          completed: status == 'completed',
          cancelled: status == 'cancelled',
        );
        expect(
          _derive(
            workflows: [terminal],
            executions: [execution],
          ).byCoverId['cover-g66']!.confirmsNoRestriction,
          isTrue,
        );
        expect(
          _derive(workflows: [terminal], executions: [_execution()]).complete,
          isFalse,
        );
        final other = _derive(
          workflows: [
            terminal,
            _workflow(id: 'workflow-2', executionId: 'execution-2'),
          ],
          executions: [
            execution,
            _execution(id: 'execution-2'),
          ],
          tickets: [_ticket()],
        ).byCoverId['cover-g66']!;
        expect(other.isUnderMaintenance, isTrue);
        expect(other.isUnfit, isTrue);
        expect(other.reasons, hasLength(2));
      }
    },
  );
  test(
    'issue coordination is excluded without manufacturing orphan maintenance',
    () {
      final data = _workflowData(kind: 'issueCoordination')
        ..remove('innerCoverId');
      final result = _derive(
        workflows: [InnerCoverWorkflowEvidence.fromMap(data, 'coordination')],
        executions: [_execution()],
      );
      expect(result.byCoverId['cover-g66']!.confirmsNoRestriction, isTrue);
    },
  );
  test(
    'orphan active executions and duplicate workflow identity cannot prove absence',
    () {
      expect(_derive(executions: [_execution()]).complete, isFalse);
      expect(
        _derive(
          workflows: [_workflow(), _workflow()],
          executions: [_execution()],
        ).complete,
        isFalse,
      );
      expect(_derive(covers: [_cover(), _cover()]).complete, isFalse);
    },
  );
  test(
    'read model and reasons collections are immutable and never rewrite host identity',
    () {
      final result = _derive(
        covers: [_cover(base: 102)],
        workflows: [_workflow()],
        executions: [_execution()],
      );
      final state = result.byCoverId['cover-g66']!;
      expect(state.reasons.single.eventHostAssetId, 'base-101');
      expect(() => result.byCoverId.clear(), throwsUnsupportedError);
      expect(() => state.reasons.clear(), throwsUnsupportedError);
      expect(() => state.warnings.clear(), throwsUnsupportedError);
    },
  );
}
