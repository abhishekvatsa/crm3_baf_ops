import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
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

  test(
    'administrative closure readback becomes synchronized terminal server state',
    () async {
      await _withMaintenanceIsar((isar) async {
        final localTime = DateTime.utc(2026, 8, 28, 4);
        final remoteTime = localTime.add(const Duration(minutes: 1));
        final lanePlan = IssueLanePlan.initial(const <String>['mechanical']);
        final local = _record(
          version: 4,
          updatedAt: localTime,
          isSynced: true,
          lanePlan: lanePlan,
        );
        final remote =
            _record(
                version: 5,
                updatedAt: remoteTime,
                isSynced: false,
                status: TicketStatus.closedWithoutResolution,
                lanePlan: lanePlan,
              )
              ..isResolved = true
              ..endDate = remoteTime
              ..closedByUid = 'admin-1'
              ..closedByName = 'Admin One'
              ..administrativeClosure = const IssueAdministrativeClosure(
                disposition:
                    IssueAdministrativeClosureDisposition.stillRelevant,
                reason:
                    'The operating cycle ended while the concern remains relevant.',
              );
        await isar.writeTxn(() => isar.maintenanceRecords.put(local));

        final applied = await IsarMaintenanceRepository()
            .applyMaintenanceIssueCommandReadback(
              remote: remote,
              expectedLocalVersion: 4,
              expectedLocalUpdatedAt: localTime,
            );
        final repository = IsarMaintenanceRepository();
        final stored = await isar.maintenanceRecords.get(local.id);
        final unsynced = await repository.getUnsyncedTickets();

        expect(applied, isTrue);
        expect(stored!.status, TicketStatus.closedWithoutResolution);
        expect(stored.isResolved, isTrue);
        expect(stored.wasTechnicallyResolved, isFalse);
        expect(stored.wasClosedWithoutResolution, isTrue);
        expect(stored.version, 5);
        expect(stored.isSynced, isTrue);
        expect(
          stored.administrativeClosure?.disposition,
          IssueAdministrativeClosureDisposition.stillRelevant,
        );
        expect(stored.issueLanePlan.completedLanes, isEmpty);
        expect(unsynced, isEmpty);
      });
    },
  );

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

  test(
    'reconciler requires exact reopening evidence before reporting convergence',
    () async {
      final reopenedAt = DateTime.utc(2026, 8, 23, 4, 1);
      final local = _FakeMaintenanceRepository(
        _record(version: 4, updatedAt: reopenedAt, isSynced: true),
        applyReadbackResult: false,
      );
      final remote = _FakeMaintenanceRepository(
        _record(version: 4, updatedAt: reopenedAt, isSynced: false)
          ..reopenedByUid = 'operations-1'
          ..reopenedByName = 'Operations One'
          ..reopenedAt = reopenedAt
          ..reopenReason = 'The issue recurred during operation.',
      );

      await expectLater(
        MaintenanceIssueCommandReconciler(
          localRepository: local,
          remoteRepository: remote,
        ).adoptServerMutation(
          firestoreId: 'ticket-command-1',
          expectedLocalVersion: 3,
          expectedLocalUpdatedAt: reopenedAt.subtract(
            const Duration(minutes: 1),
          ),
          minimumServerVersion: 4,
        ),
        throwsA(isA<MaintenanceIssueCommandConvergenceException>()),
      );
      expect(local.applyCalls, 1);
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

  test('correction receipt binds exact fields, version and audit identity', () {
    final command = WorkflowCommand(
      commandId: 'correction-command-1',
      type: WorkflowCommandType.correctMaintenanceTicket,
      aggregateId: 'ticket-command-1',
      expectedVersion: 3,
      payload: const <String, Object?>{
        'reason': 'Corrected after checking the shift record.',
        'corrections': <String, Object?>{
          'routedTo': 'mechanical',
          'description': 'Corrected issue description',
        },
      },
    );
    final valid = WorkflowCommandReceipt(
      commandId: command.commandId,
      resultKey: 'maintenance-ticket-corrected',
      aggregateVersion: 4,
      result: <String, Object?>{
        'ticketId': command.aggregateId,
        'auditId': 'server_maintenance_ticket_${command.commandId}',
        'correctedFields': const <String>['description', 'routedTo'],
      },
      appliedAt: DateTime.utc(2026, 8, 25, 6),
    );

    expect(
      () => validateMaintenanceTicketCorrectionReceipt(
        command: command,
        receipt: valid,
      ),
      returnsNormally,
    );
    expect(
      () => validateMaintenanceTicketCorrectionReceipt(
        command: command,
        receipt: WorkflowCommandReceipt(
          commandId: command.commandId,
          resultKey: valid.resultKey,
          aggregateVersion: valid.aggregateVersion,
          result: <String, Object?>{
            ...valid.result,
            'correctedFields': const <String>['description'],
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

  test(
    'mobile soft delete reaches the server before local tombstone adoption',
    () async {
      final localTime = DateTime.utc(2026, 8, 30, 4);
      final remoteTime = localTime.add(const Duration(minutes: 1));
      final operations = <String>[];
      final local = _FakeMaintenanceRepository(
        _record(version: 3, updatedAt: localTime, isSynced: true),
        label: 'local',
        operationLog: operations,
      );
      final remote = _FakeMaintenanceRepository(
        _record(version: 3, updatedAt: localTime, isSynced: false),
        label: 'remote',
        operationLog: operations,
        deleteAt: remoteTime,
      );

      final deleted = await MaintenanceIssueCommandReconciler(
        localRepository: local,
        remoteRepository: remote,
      ).softDeleteServerFirst(
        localRecord: local.record!,
        actor: _adminActor(),
        auditContext: const AuditContext(
          performedByUid: 'admin-1',
          performedByName: 'Admin One',
          reason: AuditReason.other,
          reasonNotes: 'Build 19 labelled trial cleanup',
        ),
      );

      expect(operations, <String>[
        'remote.delete',
        'remote.read',
        'local.apply-refresh',
        'local.verify',
      ]);
      expect(deleted.isDeleted, isTrue);
      expect(deleted.version, 4);
      expect(deleted.updatedAt, remoteTime);
      expect(deleted.isSynced, isTrue);
      expect(deleted.deleteReason, AuditReason.other.name);
    },
  );

  test(
    'rejected server delete leaves the synchronized local issue untouched',
    () async {
      final localTime = DateTime.utc(2026, 8, 30, 4);
      final operations = <String>[];
      final local = _FakeMaintenanceRepository(
        _record(version: 3, updatedAt: localTime, isSynced: true),
        label: 'local',
        operationLog: operations,
      );
      final remote = _FakeMaintenanceRepository(
        _record(version: 3, updatedAt: localTime, isSynced: false),
        label: 'remote',
        operationLog: operations,
        deleteError: StateError('permission denied'),
      );

      await expectLater(
        MaintenanceIssueCommandReconciler(
          localRepository: local,
          remoteRepository: remote,
        ).softDeleteServerFirst(
          localRecord: local.record!,
          actor: _adminActor(),
        ),
        throwsA(isA<MaintenanceIssueCommandConvergenceException>()),
      );

      expect(operations, <String>['remote.delete']);
      expect(local.record!.isDeleted, isFalse);
      expect(local.record!.version, 3);
      expect(local.record!.isSynced, isTrue);
      expect(local.applyCalls, 0);
    },
  );
}

AppUser _adminActor() => AppUser(
  uid: 'admin-1',
  name: 'Admin One',
  email: 'admin@example.com',
  roles: const <AppRole>[AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 30),
);

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
  _FakeMaintenanceRepository(
    this.record, {
    this.applyReadbackResult = true,
    this.label = 'repository',
    this.operationLog,
    this.deleteAt,
    this.deleteError,
  });

  MaintenanceRecord? record;
  final bool applyReadbackResult;
  final String label;
  final List<String>? operationLog;
  final DateTime? deleteAt;
  final Object? deleteError;
  int applyCalls = 0;

  @override
  Future<MaintenanceRecord?> getByFirestoreId(String firestoreId) async {
    operationLog?.add('$label.verify');
    return record?.firestoreId == firestoreId ? record : null;
  }

  @override
  Future<MaintenanceRecord?> readMaintenanceIssueCommandServerState(
    String firestoreId,
  ) async {
    operationLog?.add('$label.read');
    return record?.firestoreId == firestoreId ? record : null;
  }

  @override
  Future<void> deleteTicket(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    operationLog?.add('$label.delete');
    final error = deleteError;
    if (error != null) throw error;
    final current = record;
    if (current == null || current.isDeleted) return;
    final deletedAt =
        deleteAt ?? current.updatedAt.add(const Duration(minutes: 1));
    current
      ..isDeleted = true
      ..deletedAt = deletedAt
      ..deletedByUid = auditContext?.performedByUid
      ..deletedByName = auditContext?.performedByName
      ..deleteReason = auditContext?.reason?.name ?? auditContext?.reasonNotes
      ..updatedAt = deletedAt
      ..version += 1;
  }

  @override
  Future<bool> applyMaintenanceIssueCommandReadback({
    required MaintenanceRecord remote,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
  }) async {
    operationLog?.add('$label.apply-command');
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
    operationLog?.add('$label.apply-refresh');
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
