import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_event_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../tool/test_support/test_isar_core.dart';

void main() {
  late Isar isar;
  late IsarWorkflowRepository repository;
  late Directory directory;

  setUpAll(initializeTestIsarCore);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('workflow_query_test_');
    isar = await Isar.open(
      [
        WorkflowAggregateRecordSchema,
        JobLaneRecordSchema,
        ComplianceRequestRecordSchema,
        EquipmentStatusRecordSchema,
        WorkflowEventRecordSchema,
        WorkflowCommandRecordSchema,
      ],
      directory: directory.path,
      name: 'workflow_query_test',
      inspector: false,
    );
    repository = IsarWorkflowRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  test(
    'workflow lookup and watcher follow only the requested identity',
    () async {
      final watched = _observe(repository.watchWorkflow('selected'));
      expect(await watched.at(0), isNull);
      expect(await repository.getWorkflow('selected'), isNull);

      await repository.upsertWorkflowFromRemote(_workflow('other'));
      await watched.expectCount(1);

      final selected = _workflow('selected');
      await repository.upsertWorkflowFromRemote(selected);
      expect((await watched.at(1))?.firestoreId, 'selected');
      expect(
        (await repository.getWorkflow('selected'))?.firestoreId,
        'selected',
      );

      selected.version = 7;
      await repository.upsertWorkflowFromRemote(selected);
      expect((await watched.at(2))?.version, 7);

      await isar.writeTxn(
        () => isar.workflowAggregateRecords.delete(selected.id),
      );
      expect(await watched.at(3), isNull);
    },
  );

  test('workflow lanes are scoped and ordered, retaining tombstones', () async {
    final later = _lane('later', order: 9);
    final first = _lane('first', order: 2, deleted: true);
    await isar.writeTxn(
      () => isar.jobLaneRecords.putAll([
        later,
        _lane('unrelated', workflow: 'other', order: 0),
        first,
      ]),
    );

    expect(_laneIds(await repository.getLanes('selected')), ['first', 'later']);
    expect(await repository.getLanes('missing'), isEmpty);
    final watched = _observe(repository.watchLanes('selected'));
    expect(_laneIds(await watched.at(0)), ['first', 'later']);

    await repository.upsertLaneFromRemote(
      _lane('unrelated-new', workflow: 'other'),
    );
    await watched.expectCount(1);

    later.displayOrder = 1;
    await repository.upsertLaneFromRemote(later);
    expect(_laneIds(await watched.at(1)), ['later', 'first']);

    later.workflowFirestoreId = 'other';
    await repository.upsertLaneFromRemote(later);
    expect(_laneIds(await watched.at(2)), ['first']);
  });

  test('lane-key watcher spans workflows and retains tombstones', () async {
    await isar.writeTxn(
      () => isar.jobLaneRecords.putAll([
        _lane('older', updated: 1),
        _lane('newer-deleted', workflow: 'other', updated: 3, deleted: true),
        _lane('different-lane', lane: 'electrical', updated: 4),
      ]),
    );
    final watched = _observe(repository.watchLanesByLane('mechanical'));
    expect(_laneIds(await watched.at(0)), ['newer-deleted', 'older']);

    await repository.upsertLaneFromRemote(
      _lane('unrelated', lane: 'electrical'),
    );
    await watched.expectCount(1);
    await repository.upsertLaneFromRemote(_lane('newest', updated: 5));
    expect(_laneIds(await watched.at(1)), ['newest', 'newer-deleted', 'older']);
  });

  test(
    'all lanes excludes tombstones and tracks deletion transitions',
    () async {
      final active = _lane('active', updated: 2);
      final deleted = _lane('deleted', updated: 3, deleted: true);
      await isar.writeTxn(
        () => isar.jobLaneRecords.putAll([
          _lane('older', updated: 1),
          active,
          deleted,
        ]),
      );
      final watched = _observe(repository.watchAllLanes());
      expect(_laneIds(await watched.at(0)), ['active', 'older']);

      deleted.updatedAt = _time(4);
      await repository.upsertLaneFromRemote(deleted);
      await watched.expectCount(1);

      active.isDeleted = true;
      await repository.upsertLaneFromRemote(active);
      expect(_laneIds(await watched.at(1)), ['older']);

      deleted.isDeleted = false;
      await repository.upsertLaneFromRemote(deleted);
      expect(_laneIds(await watched.at(2)), ['deleted', 'older']);
    },
  );

  test(
    'workflow compliance retains tombstones, but ID lookup excludes them',
    () async {
      final older = _compliance('older', updated: 1);
      await isar.writeTxn(
        () => isar.complianceRequestRecords.putAll([
          older,
          _compliance('deleted', updated: 3, deleted: true),
          _compliance('unrelated', workflow: 'other', updated: 4),
          _compliance('unlinked', workflow: null, updated: 5),
        ]),
      );
      expect(_complianceIds(await repository.getCompliance('selected')), [
        'deleted',
        'older',
      ]);
      expect(await repository.getCompliance('missing'), isEmpty);
      expect(await repository.getComplianceById('deleted'), isNull);
      expect(await repository.getComplianceById('missing'), isNull);
      expect(
        (await repository.getComplianceById('older'))?.firestoreId,
        'older',
      );

      final watched = _observe(repository.watchCompliance('selected'));
      expect(_complianceIds(await watched.at(0)), ['deleted', 'older']);
      await repository.upsertComplianceFromRemote(
        _compliance('other-new', workflow: 'other'),
      );
      await watched.expectCount(1);

      older.updatedAt = _time(6);
      await repository.upsertComplianceFromRemote(older);
      expect(_complianceIds(await watched.at(1)), ['older', 'deleted']);
    },
  );

  test(
    'compliance inbox scopes by lane and excludes deleted records',
    () async {
      final selected = _compliance('selected-request', updated: 1);
      await isar.writeTxn(
        () => isar.complianceRequestRecords.putAll([
          selected,
          _compliance('another-workflow', workflow: 'other', updated: 3),
          _compliance('deleted', updated: 5, deleted: true),
          _compliance('other-lane', lane: 'electrical', updated: 7),
        ]),
      );
      final watched = _observe(repository.watchComplianceInbox('mechanical'));
      expect(_complianceIds(await watched.at(0)), [
        'another-workflow',
        'selected-request',
      ]);

      await repository.upsertComplianceFromRemote(
        _compliance('unrelated', lane: 'electrical'),
      );
      await watched.expectCount(1);
      await repository.upsertComplianceFromRemote(
        _compliance('another-deleted', deleted: true),
      );
      await watched.expectCount(1);

      selected.isDeleted = true;
      await repository.upsertComplianceFromRemote(selected);
      expect(_complianceIds(await watched.at(1)), ['another-workflow']);
    },
  );

  test(
    'all compliance is ordered and reacts when a tombstone is restored',
    () async {
      final deleted = _compliance('deleted', updated: 5, deleted: true);
      await isar.writeTxn(
        () => isar.complianceRequestRecords.putAll([
          _compliance('older', updated: 1),
          _compliance(
            'newer',
            workflow: 'other',
            lane: 'electrical',
            updated: 3,
          ),
          deleted,
        ]),
      );
      final watched = _observe(repository.watchAllCompliance());
      expect(_complianceIds(await watched.at(0)), ['newer', 'older']);

      deleted.description = 'Updated while deleted';
      await repository.upsertComplianceFromRemote(deleted);
      await watched.expectCount(1);

      deleted.isDeleted = false;
      await repository.upsertComplianceFromRemote(deleted);
      expect(_complianceIds(await watched.at(1)), [
        'deleted',
        'newer',
        'older',
      ]);
    },
  );

  test('event watcher scopes by aggregate and orders newest first', () async {
    await isar.writeTxn(
      () => isar.workflowEventRecords.putAll([
        _event('older', occurred: 1),
        _event('newer', occurred: 3),
        _event('unrelated', workflow: 'other', occurred: 4),
      ]),
    );
    final watched = _observe(repository.watchEvents('selected'));
    expect((await watched.at(0)).map((row) => row.firestoreId), [
      'newer',
      'older',
    ]);

    await repository.upsertEventFromRemote(
      _event('other-new', workflow: 'other'),
    );
    await watched.expectCount(1);
    await repository.upsertEventFromRemote(_event('newest', occurred: 5));
    expect((await watched.at(1)).map((row) => row.firestoreId), [
      'newest',
      'newer',
      'older',
    ]);
  });

  test(
    'equipment state watcher sorts by type then number and tracks entry and exit',
    () async {
      final outside = _equipment(
        'outside',
        type: 'base',
        number: 2,
        state: 'outOfService',
      );
      await isar.writeTxn(
        () => isar.equipmentStatusRecords.putAll([
          _equipment('cover', type: 'cover', number: 1),
          _equipment('base-ten', type: 'base', number: 10),
          _equipment('base-one', type: 'base', number: 1),
          outside,
        ]),
      );
      final scoped = _observe(repository.watchEquipmentByState('inService'));
      expect(_equipmentIds(await scoped.at(0)), [
        'base-one',
        'base-ten',
        'cover',
      ]);
      expect(
        _equipmentIds(await repository.watchEquipmentByState(null).first),
        ['base-one', 'outside', 'base-ten', 'cover'],
      );

      outside.version = 2;
      await repository.upsertEquipmentFromRemote(outside);
      await scoped.expectCount(1);

      outside.stateKey = 'inService';
      await repository.upsertEquipmentFromRemote(outside);
      expect(_equipmentIds(await scoped.at(1)), [
        'base-one',
        'outside',
        'base-ten',
        'cover',
      ]);

      outside.stateKey = 'outOfService';
      await repository.upsertEquipmentFromRemote(outside);
      expect(_equipmentIds(await scoped.at(2)), [
        'base-one',
        'base-ten',
        'cover',
      ]);
    },
  );

  test(
    'equipment lookup preserves ordinary and governed custom identities',
    () async {
      await isar.writeTxn(
        () => isar.equipmentStatusRecords.putAll([
          _equipment('base', type: 'base', number: 1),
          _equipment('duplicate-base', type: 'base', number: 1),
          _equipment(
            'wrong-number',
            type: 'governedCustom',
            number: 2,
            assetClass: 'class-a',
            instance: 'instance-a',
          ),
          _equipment(
            'wrong-class',
            type: 'governedCustom',
            number: 1,
            assetClass: 'class-b',
            instance: 'instance-a',
          ),
          _equipment(
            'wrong-instance',
            type: 'governedCustom',
            number: 1,
            assetClass: 'class-a',
            instance: 'instance-b',
          ),
          _equipment(
            'custom',
            type: 'governedCustom',
            number: 1,
            assetClass: 'class-a',
            instance: 'instance-a',
          ),
          _equipment(
            'duplicate-custom',
            type: 'governedCustom',
            number: 1,
            assetClass: 'class-a',
            instance: 'instance-a',
          ),
          _equipment('custom-null', type: 'governedCustom', number: 1),
        ]),
      );
      expect(
        (await repository.getEquipment(
          'base',
          1,
          assetClassId: 'ignored',
          assetInstanceId: 'ignored',
        ))?.firestoreId,
        'base',
      );
      expect(
        (await repository.getEquipment(
          'governedCustom',
          1,
          assetClassId: 'class-a',
          assetInstanceId: 'instance-a',
        ))?.firestoreId,
        'custom',
      );
      expect(
        (await repository.getEquipment('governedCustom', 1))?.firestoreId,
        'custom-null',
      );
      expect(
        await repository.getEquipment(
          'governedCustom',
          1,
          assetClassId: 'missing',
          assetInstanceId: 'instance-a',
        ),
        isNull,
      );
      expect(await repository.getEquipment('base', 99), isNull);
    },
  );

  test(
    'retry queries preserve the due boundary, nulls, and manual-review policy',
    () async {
      final now = _time(20);
      await isar.writeTxn(
        () => isar.workflowCommandRecords.putAll([
          _command('due-now', created: 5, retry: now),
          _command('past-due', created: 2, retry: _time(19)),
          _command('future', created: 1, retry: _time(21)),
          _command('no-retry-time', created: 3),
          _command(
            'manual',
            state: 'manualReview',
            created: 4,
            retry: _time(19),
          ),
          _command('ready', state: 'ready', created: 6, retry: _time(19)),
          _command('sending', state: 'sending', created: 7),
          _command('unknown', state: 'futureState', created: 8),
          _command('applied', state: 'applied', created: 0, retry: _time(19)),
          _command('rejected', state: 'rejected', created: 9, retry: _time(19)),
        ]),
      );

      expect(
        (await repository.getRetryableCommands(
          now,
        )).map((row) => row.commandId),
        ['past-due', 'due-now'],
      );
      expect(
        (await repository.getPendingCommands()).map((row) => row.commandId),
        [
          'future',
          'past-due',
          'no-retry-time',
          'manual',
          'due-now',
          'ready',
          'sending',
          'unknown',
        ],
      );
      expect(
        (await repository.getRetryCommand('manual'))?.stateKey,
        'manualReview',
      );
      expect(await repository.getRetryCommand('missing'), isNull);

      await repository.deleteRetryCommand('past-due');
      await repository.deleteRetryCommand('missing');
      expect(await repository.getRetryCommand('past-due'), isNull);
      expect(
        (await repository.getRetryableCommands(
          now,
        )).map((row) => row.commandId),
        ['due-now'],
      );
    },
  );
}

DateTime _time(int minutes) => DateTime.utc(2026, 9, 6, 0, minutes);

WorkflowAggregateRecord _workflow(String id) => WorkflowAggregateRecord()
  ..firestoreId = id
  ..jobExecutionFirestoreId = 'execution-$id'
  ..assetTypeKey = 'base'
  ..assetNumber = 1;

JobLaneRecord _lane(
  String id, {
  String workflow = 'selected',
  String lane = 'mechanical',
  int order = 0,
  int updated = 0,
  bool deleted = false,
}) => JobLaneRecord()
  ..firestoreId = id
  ..workflowFirestoreId = workflow
  ..jobExecutionFirestoreId = 'execution-$workflow'
  ..laneKey = lane
  ..displayOrder = order
  ..updatedAt = _time(updated)
  ..isDeleted = deleted;

ComplianceRequestRecord _compliance(
  String id, {
  String? workflow = 'selected',
  String lane = 'mechanical',
  int updated = 0,
  bool deleted = false,
}) => ComplianceRequestRecord()
  ..firestoreId = id
  ..title = id
  ..description = 'Request $id'
  ..linkedWorkflowId = workflow
  ..targetLaneKey = lane
  ..updatedAt = _time(updated)
  ..isDeleted = deleted;

WorkflowEventRecord _event(
  String id, {
  String workflow = 'selected',
  int occurred = 0,
}) => WorkflowEventRecord()
  ..firestoreId = id
  ..aggregateId = workflow
  ..eventTypeKey = 'laneUpdated'
  ..occurredAt = _time(occurred);

EquipmentStatusRecord _equipment(
  String id, {
  required String type,
  required int number,
  String state = 'inService',
  String? assetClass,
  String? instance,
}) => EquipmentStatusRecord()
  ..firestoreId = id
  ..assetTypeKey = type
  ..assetNumber = number
  ..stateKey = state
  ..assetClassId = assetClass
  ..assetInstanceId = instance;

WorkflowCommandRecord _command(
  String id, {
  String state = 'uncertainOutcome',
  int created = 0,
  DateTime? retry,
}) => WorkflowCommandRecord()
  ..commandId = id
  ..aggregateId = 'selected'
  ..commandTypeKey = 'acknowledgeLane'
  ..stateKey = state
  ..createdLocallyAt = _time(created)
  ..nextRetryAt = retry;

Iterable<String?> _laneIds(List<JobLaneRecord> rows) =>
    rows.map((row) => row.firestoreId);
Iterable<String?> _complianceIds(List<ComplianceRequestRecord> rows) =>
    rows.map((row) => row.firestoreId);
Iterable<String?> _equipmentIds(List<EquipmentStatusRecord> rows) =>
    rows.map((row) => row.firestoreId);

_ObservedStream<T> _observe<T>(Stream<T> stream) {
  final observed = _ObservedStream(stream);
  addTearDown(observed.close);
  return observed;
}

/// Keep listening between assertions so unwanted emissions are not discarded.
class _ObservedStream<T> {
  final List<T> _values = [];
  late final StreamSubscription<T> _subscription;
  Completer<void>? _changed;

  _ObservedStream(Stream<T> stream) {
    _subscription = stream.listen((value) {
      _values.add(value);
      _changed?.complete();
      _changed = null;
    });
  }

  Future<T> at(int index) async {
    while (_values.length <= index) {
      final changed = _changed ??= Completer<void>();
      await changed.future.timeout(const Duration(seconds: 5));
    }
    return _values[index];
  }

  Future<void> expectCount(int count) async {
    // The write has committed; let queued native watcher notifications drain.
    await pumpEventQueue();
    expect(_values, hasLength(count));
  }

  Future<void> close() => _subscription.cancel();
}
