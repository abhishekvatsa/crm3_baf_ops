import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_command_reconciler.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  setUpAll(initializeTestIsarCore);

  test(
    'clean command boundary atomically adopts exact multi-lane server state',
    () async {
      await _withMaintenanceIsar((isar) async {
        final localTime = DateTime.utc(2026, 8, 23, 4);
        final remoteTime = localTime.add(const Duration(minutes: 1));
        final local = _record(
          version: 3,
          updatedAt: localTime,
          isSynced: true,
          lanePlan: IssueLanePlan.initial(const <String>[
            'mechanical',
            'electrical',
          ]),
        )..operationalEventIssueLinkIds = <String>['event-link-old'];
        final remote =
            _record(
                version: 4,
                updatedAt: remoteTime,
                isSynced: false,
                status: TicketStatus.inProgress,
                lanePlan: IssueLanePlan.initial(const <String>[
                  'mechanical',
                  'electrical',
                ]).acknowledge('mechanical'),
              )
              ..acknowledgedByUid = 'mechanical-1'
              ..acknowledgedByName = 'Mechanical One'
              ..acknowledgedAt = remoteTime
              ..operationalEventIssueLinkIds = <String>[
                'event-link-current',
                'event-link-second',
              ];
        await isar.writeTxn(() => isar.maintenanceRecords.put(local));

        final applied = await IsarMaintenanceRepository()
            .applyMaintenanceIssueCommandReadback(
              remote: remote,
              expectedLocalVersion: 3,
              expectedLocalUpdatedAt: localTime,
            );
        final stored = await isar.maintenanceRecords.get(local.id);

        expect(applied, isTrue);
        expect(stored!.version, 4);
        expect(stored.updatedAt.isAtSameMomentAs(remoteTime), isTrue);
        expect(stored.isSynced, isTrue);
        expect(stored.status, TicketStatus.inProgress);
        expect(stored.issueLanePlan.acknowledgedLanes, <String>['mechanical']);
        expect(stored.operationalEventIssueLinkIds, <String>[
          'event-link-current',
          'event-link-second',
        ]);
      });
    },
  );

  test('command readback preserves a concurrent dirty local edit', () async {
    await _withMaintenanceIsar((isar) async {
      final localTime = DateTime.utc(2026, 8, 23, 4);
      final local = _record(version: 3, updatedAt: localTime, isSynced: true);
      await isar.writeTxn(() => isar.maintenanceRecords.put(local));
      await isar.writeTxn(() async {
        final changed = await isar.maintenanceRecords.get(local.id);
        changed!
          ..version = 4
          ..updatedAt = localTime.add(const Duration(seconds: 30))
          ..description = 'Locally revised evidence awaiting synchronization'
          ..isSynced = false;
        await isar.maintenanceRecords.put(changed);
      });

      final applied = await IsarMaintenanceRepository()
          .applyMaintenanceIssueCommandReadback(
            remote:
                _record(
                    version: 4,
                    updatedAt: localTime.add(const Duration(minutes: 1)),
                    isSynced: false,
                    status: TicketStatus.acknowledged,
                    lanePlan: IssueLanePlan.initial(const <String>[
                      'mechanical',
                    ]).acknowledge('mechanical'),
                  )
                  ..acknowledgedByUid = 'mechanical-1'
                  ..acknowledgedByName = 'Mechanical One'
                  ..acknowledgedAt = localTime.add(const Duration(minutes: 1)),
            expectedLocalVersion: 3,
            expectedLocalUpdatedAt: localTime,
          );
      final stored = await isar.maintenanceRecords.get(local.id);

      expect(applied, isFalse);
      expect(
        stored!.description,
        'Locally revised evidence awaiting synchronization',
      );
      expect(stored.isSynced, isFalse);
    });
  });

  test('exact server refresh applies a clean remote tombstone', () async {
    await _withMaintenanceIsar((isar) async {
      final localTime = DateTime.utc(2026, 8, 23, 4);
      final remoteTime = localTime.add(const Duration(minutes: 1));
      final local = _record(version: 3, updatedAt: localTime, isSynced: true);
      final remote =
          _record(version: 4, updatedAt: remoteTime, isSynced: false)
            ..isDeleted = true
            ..deletedAt = remoteTime
            ..deletedByUid = 'admin-1'
            ..deletedByName = 'Admin One'
            ..deleteReason = 'Duplicate issue';
      await isar.writeTxn(() => isar.maintenanceRecords.put(local));

      final applied = await IsarMaintenanceRepository()
          .applyMaintenanceIssueServerRefresh(
            remote: remote,
            expectedLocalVersion: 3,
            expectedLocalUpdatedAt: localTime,
          );
      final stored = await isar.maintenanceRecords.get(local.id);

      expect(applied, isTrue);
      expect(stored!.isDeleted, isTrue);
      expect(stored.version, 4);
      expect(stored.isSynced, isTrue);
      expect(stored.deleteReason, 'Duplicate issue');
    });
  });

  test('exact server refresh preserves a dirty local row', () async {
    await _withMaintenanceIsar((isar) async {
      final localTime = DateTime.utc(2026, 8, 23, 4);
      final local = _record(version: 3, updatedAt: localTime, isSynced: false);
      await isar.writeTxn(() => isar.maintenanceRecords.put(local));

      final applied = await IsarMaintenanceRepository()
          .applyMaintenanceIssueServerRefresh(
            remote: _record(
              version: 4,
              updatedAt: localTime.add(const Duration(minutes: 1)),
              isSynced: false,
            ),
            expectedLocalVersion: 3,
            expectedLocalUpdatedAt: localTime,
          );
      final stored = await isar.maintenanceRecords.get(local.id);

      expect(applied, isFalse);
      expect(stored!.version, 3);
      expect(stored.isDeleted, isFalse);
      expect(stored.isSynced, isFalse);
    });
  });

  test('reconciler rejects a stale point read before local adoption', () async {
    final local = _FakeMaintenanceRepository(
      _record(
        version: 3,
        updatedAt: DateTime.utc(2026, 8, 23, 4),
        isSynced: true,
      ),
    );
    final remote = _FakeMaintenanceRepository(
      _record(
        version: 3,
        updatedAt: DateTime.utc(2026, 8, 23, 4),
        isSynced: false,
      ),
    );

    await expectLater(
      MaintenanceIssueCommandReconciler(
        localRepository: local,
        remoteRepository: remote,
      ).adoptServerMutation(
        firestoreId: 'ticket-command-1',
        expectedLocalVersion: 3,
        expectedLocalUpdatedAt: DateTime.utc(2026, 8, 23, 4),
        minimumServerVersion: 4,
      ),
      throwsA(isA<MaintenanceIssueCommandConvergenceException>()),
    );
    expect(local.applyCalls, 0);
  });

  test(
    'reconciler accepts state already adopted by an intervening full sync',
    () async {
      final remoteTime = DateTime.utc(2026, 8, 23, 4, 1);
      final authoritative =
          _record(
              version: 4,
              updatedAt: remoteTime,
              isSynced: true,
              status: TicketStatus.inProgress,
              lanePlan: IssueLanePlan.initial(const <String>[
                'mechanical',
                'electrical',
              ]).acknowledge('mechanical'),
            )
            ..acknowledgedByUid = 'mechanical-1'
            ..acknowledgedByName = 'Mechanical One'
            ..acknowledgedAt = remoteTime;
      final local = _FakeMaintenanceRepository(
        authoritative,
        applyReadbackResult: false,
      );
      final remote = _FakeMaintenanceRepository(authoritative);

      final adopted = await MaintenanceIssueCommandReconciler(
        localRepository: local,
        remoteRepository: remote,
      ).adoptServerMutation(
        firestoreId: 'ticket-command-1',
        expectedLocalVersion: 3,
        expectedLocalUpdatedAt: DateTime.utc(2026, 8, 23, 4),
        minimumServerVersion: 4,
      );

      expect(adopted.version, 4);
      expect(adopted.isSynced, isTrue);
      expect(local.applyCalls, 1);
    },
  );

  test(
    'reconciler does not mistake newer dirty work for convergence',
    () async {
      final localTime = DateTime.utc(2026, 8, 23, 4);
      final local = _FakeMaintenanceRepository(
        _record(version: 5, updatedAt: localTime, isSynced: false)
          ..description = 'Newer local field evidence',
        applyReadbackResult: false,
      );
      final remote = _FakeMaintenanceRepository(
        _record(
          version: 4,
          updatedAt: localTime.add(const Duration(minutes: 1)),
          isSynced: false,
        ),
      );

      await expectLater(
        MaintenanceIssueCommandReconciler(
          localRepository: local,
          remoteRepository: remote,
        ).adoptServerMutation(
          firestoreId: 'ticket-command-1',
          expectedLocalVersion: 3,
          expectedLocalUpdatedAt: localTime,
          minimumServerVersion: 4,
        ),
        throwsA(isA<MaintenanceIssueCommandConvergenceException>()),
      );
      expect(local.record!.description, 'Newer local field evidence');
      expect(local.record!.isSynced, isFalse);
    },
  );

  test('lane mutation receipts must match exact request evidence', () {
    final command = WorkflowCommand(
      commandId: 'lane-command-1',
      type: WorkflowCommandType.reconfigureMaintenanceTicketLanes,
      aggregateId: 'ticket-command-1',
      expectedVersion: 3,
      payload: const <String, Object?>{
        'lanes': <String>['mechanical', 'electrical'],
        'otherDepartment': null,
        'reason': 'Electrical support is required for the repair.',
      },
    );
    final valid = WorkflowCommandReceipt(
      commandId: command.commandId,
      resultKey: 'maintenance-ticket-lanes-reconfigured',
      aggregateVersion: 4,
      result: <String, Object?>{
        'ticketId': command.aggregateId,
        'auditId': 'server_maintenance_ticket_${command.commandId}',
        'lanes': const <String>['mechanical', 'electrical'],
      },
      appliedAt: DateTime.utc(2026, 8, 23, 4),
    );

    expect(
      () => validateMaintenanceIssueLaneCommandReceipt(
        command: command,
        receipt: valid,
      ),
      returnsNormally,
    );
    expect(
      () => validateMaintenanceIssueLaneCommandReceipt(
        command: command,
        receipt: WorkflowCommandReceipt(
          commandId: command.commandId,
          resultKey: valid.resultKey,
          aggregateVersion: valid.aggregateVersion,
          result: <String, Object?>{
            ...valid.result,
            'lanes': const <String>['mechanical'],
          },
          appliedAt: valid.appliedAt,
        ),
      ),
      throwsStateError,
    );
  });

  test(
    'coordination receipt binds workflow, compliance and ticket version',
    () {
      final command = WorkflowCommand(
        commandId: 'coordination-command-1',
        type: WorkflowCommandType.startIssueCoordination,
        aggregateId: 'workflow-1',
        expectedVersion: 0,
        payload: const <String, Object?>{
          'ticketId': 'ticket-command-1',
          'expectedTicketVersion': 3,
          'complianceId': 'compliance-1',
          'requestPurposeKey': 'deferment',
        },
      );
      WorkflowCommandReceipt receipt({int ticketVersion = 4}) =>
          WorkflowCommandReceipt(
            commandId: command.commandId,
            resultKey: 'issue-coordination-started',
            aggregateVersion: 1,
            result: <String, Object?>{
              'workflowId': command.aggregateId,
              'ticketId': 'ticket-command-1',
              'ticketVersion': ticketVersion,
              'complianceId': 'compliance-1',
              'requestPurposeKey': 'deferment',
            },
            appliedAt: DateTime.utc(2026, 8, 23, 4),
          );

      expect(
        validateMaintenanceIssueCoordinationReceipt(
          command: command,
          receipt: receipt(),
        ),
        4,
      );
      expect(
        () => validateMaintenanceIssueCoordinationReceipt(
          command: command,
          receipt: receipt(ticketVersion: 3),
        ),
        throwsStateError,
      );
    },
  );
}

MaintenanceRecord _record({
  required int version,
  required DateTime updatedAt,
  required bool isSynced,
  TicketStatus status = TicketStatus.open,
  IssueLanePlan? lanePlan,
}) {
  final record =
      MaintenanceRecord()
        ..firestoreId = 'ticket-command-1'
        ..version = version
        ..isSynced = isSynced
        ..assetType = AssetType.furnace
        ..assetNumber = 7
        ..component = 'Furnace body'
        ..maintenanceType = MaintenanceType.breakdown
        ..description = 'Furnace shell temperature is above the expected range.'
        ..routedTo = RoutedTo.mechanical
        ..status = status
        ..isResolved = false
        ..loggedByUid = 'operations-1'
        ..loggedByName = 'Operations One'
        ..startDate = DateTime.utc(2026, 8, 23, 3)
        ..createdAt = DateTime.utc(2026, 8, 23, 3)
        ..updatedAt = updatedAt;
  record.issueLanePlan =
      lanePlan ?? IssueLanePlan.initial(const <String>['mechanical']);
  return record;
}

class _FakeMaintenanceRepository implements MaintenanceRepository {
  _FakeMaintenanceRepository(this.record, {this.applyReadbackResult = true});

  MaintenanceRecord? record;
  final bool applyReadbackResult;
  int applyCalls = 0;

  @override
  Future<MaintenanceRecord?> getByFirestoreId(String firestoreId) async =>
      record?.firestoreId == firestoreId ? record : null;

  @override
  Future<MaintenanceRecord?> readMaintenanceIssueCommandServerState(
    String firestoreId,
  ) async => record?.firestoreId == firestoreId ? record : null;

  @override
  Future<bool> applyMaintenanceIssueCommandReadback({
    required MaintenanceRecord remote,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
  }) async {
    applyCalls += 1;
    if (!applyReadbackResult) return false;
    record = remote..isSynced = true;
    return true;
  }

  @override
  Future<bool> applyMaintenanceIssueServerRefresh({
    required MaintenanceRecord remote,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
  }) async {
    applyCalls += 1;
    if (!applyReadbackResult) return false;
    record = remote..isSynced = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _withMaintenanceIsar(Future<void> Function(Isar isar) body) async {
  final directory = await Directory.systemTemp.createTemp(
    'maintenance_issue_command_readback_',
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
