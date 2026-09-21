import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/maintenance_creation_successor_review.dart';
import 'package:crm3_baf_ops/features/maintenance/repositories/maintenance_creation_successor_repository.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_creation_successor_service.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';

import '../tool/test_support/test_isar_core.dart';

final _at = DateTime.utc(2026, 9, 21);
MaintenanceRecord _record({bool synced = true}) => MaintenanceRecord()
  ..firestoreId = 'complete-review'
  ..loggedByUid = 'reporter'
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..maintenanceType = MaintenanceType.breakdown
  ..routedTo = RoutedTo.mechanical
  ..description = 'Original issue'
  ..startDate = _at
  ..createdAt = _at
  ..updatedAt = _at
  ..plantConditionEffect = MaintenanceIssuePlantConditionEffect.unfit
  ..isSynced = synced;

MaintenanceCreationSuccessorReview _review(
  MaintenanceRecord local,
  MaintenanceRecord server, {
  String snapshot = '[]',
}) {
  final command = WorkflowCommand(
    commandId: 'createMaintenanceTicket_complete-review',
    type: WorkflowCommandType.createMaintenanceTicket,
    aggregateId: 'complete-review',
    expectedVersion: 0,
    payload: {
      'ticket': {
        'assetType': 'furnace',
        'assetNumber': 7,
        'startDate': _at.toIso8601String(),
        ...maintenanceCorrectionValues(_record()),
      },
    },
  );
  return MaintenanceCreationSuccessorReview(
    acceptance: MaintenanceCreationAcceptance(
      envelopeJson: '{}',
      actorUid: 'reporter',
      command: command,
      receipt: WorkflowCommandReceipt(
        commandId: command.commandId,
        resultKey: 'maintenance-ticket-created',
        aggregateVersion: 1,
        result: const {},
        appliedAt: _at,
      ),
    ),
    local: local,
    server: server,
    localSnapshotJson: snapshot,
  );
}

final _omittedMutations = <String, void Function(MaintenanceRecord)>{
  'hierarchyPath': (row) =>
      row.hierarchyPath = ['A different physical context'],
  'chargeNoAtEvent': (row) => row.chargeNoAtEvent = 145,
  'downtimeHours': (row) => row.downtimeHours = 2.75,
  'isResolved': (row) => row.isResolved = true,
  'acknowledgedAt': (row) =>
      row.acknowledgedAt = _at.add(const Duration(hours: 1)),
  'acknowledgedByName': (row) =>
      row.acknowledgedByName = 'Acknowledging engineer',
  'acknowledgedByUid': (row) => row.acknowledgedByUid = 'engineer',
  'closedByName': (row) => row.closedByName = 'Closing engineer',
  'closedByUid': (row) => row.closedByUid = 'closing-engineer',
  'reopenedAt': (row) => row.reopenedAt = _at.add(const Duration(hours: 2)),
  'workflowComplianceId': (row) => row.workflowComplianceId = 'compliance-2',
  'workflowDeferred': (row) => row.workflowDeferred = true,
  'workflowConditionRef': (row) => row.workflowConditionRef = 'condition-ref',
  'workflowConditionTypeKey': (row) =>
      row.workflowConditionTypeKey = 'condition-type',
  'workflowCorrectionReason': (row) =>
      row.workflowCorrectionReason = 'Reviewed reason',
  'workflowDeferredAt': (row) =>
      row.workflowDeferredAt = _at.add(const Duration(hours: 3)),
  'workflowDeferredByName': (row) =>
      row.workflowDeferredByName = 'Deferring supervisor',
  'workflowDeferredByUid': (row) =>
      row.workflowDeferredByUid = 'deferring-supervisor',
  'workflowOriginLaneKey': (row) => row.workflowOriginLaneKey = 'mechanical',
  'workflowReactivatedAt': (row) =>
      row.workflowReactivatedAt = _at.add(const Duration(hours: 4)),
  'workflowReactivatedByName': (row) =>
      row.workflowReactivatedByName = 'Resuming supervisor',
  'workflowReactivatedByUid': (row) =>
      row.workflowReactivatedByUid = 'resuming-supervisor',
  'workflowReleasedAt': (row) =>
      row.workflowReleasedAt = _at.add(const Duration(hours: 5)),
  'workflowReleasedByName': (row) =>
      row.workflowReleasedByName = 'Releasing supervisor',
  'workflowReleasedByUid': (row) =>
      row.workflowReleasedByUid = 'releasing-supervisor',
  'workflowTargetLaneKey': (row) => row.workflowTargetLaneKey = 'electrical',
  'workflowUpdatedAt': (row) =>
      row.workflowUpdatedAt = _at.add(const Duration(hours: 6)),
  'reportedBy': (row) => row.reportedBy = 'Reporter display evidence',
  'loggedByName': (row) => row.loggedByName = 'Reporter name',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  test(
    'same-version boundary covers every generated persisted field except local sync flag',
    () {
      final boundary =
          jsonDecode(maintenanceReviewServerBoundary(_record())) as Map;
      final expected = MaintenanceRecordSchema.properties.keys.toSet()
        ..remove('isSynced');
      expect(boundary.keys.toSet(), expected);
    },
  );
  for (final entry in _omittedMutations.entries) {
    test(
      '${entry.key} fences same-version C and is an explicit unsupported B/C difference',
      () {
        final server = _record();
        final before = maintenanceReviewServerBoundary(server);
        entry.value(server);
        expect(maintenanceReviewServerBoundary(server), isNot(before));
        final local = _record(synced: false);
        entry.value(local);
        expect(
          _review(local, _record()).unsupportedChanges,
          contains(entry.key),
        );
      },
    );
  }

  test(
    'server-only advances disclose B/C values without inventing device-edit intent',
    () {
      final server = _record()
        ..downtimeHours = 4.5
        ..workflowComplianceId = 'new-on-server';
      final review = _review(_record(synced: false), server);
      expect(
        review.unsupportedDifferences['downtimeHours']!.deviceValue,
        isNull,
      );
      expect(review.unsupportedDifferences['downtimeHours']!.serverValue, 4.5);
      final evidence = review.evidence(
        reason: 'Keep confirmed current values',
        corrections: {},
        disposition: 'keepServer',
      );
      final differences = evidence['retainedUnsupportedDifferences'] as Map;
      expect(differences['workflowComplianceId'], {
        'deviceValue': null,
        'serverValue': 'new-on-server',
        'disposition': 'retainDeviceEvidenceKeepServer',
      });
    },
  );

  test('complete comparison freezes lists and provenance at review time', () {
    final local = _record(synced: false)
      ..hierarchyPath = ['Retained device context'];
    final server = _record()..hierarchyPath = ['Reviewed server context'];
    final review = _review(local, server);
    final boundary = review.serverBoundaryJson;
    local.hierarchyPath!.add('Later edit');
    server.hierarchyPath!.add('Later server context');
    expect(review.serverBoundaryJson, boundary);
    expect(review.unsupportedDifferences['hierarchyPath']!.deviceValue, [
      'Retained device context',
    ]);
    expect(review.unsupportedDifferences['hierarchyPath']!.serverValue, [
      'Reviewed server context',
    ]);
  });

  test('only documented local primary key and sync flag are excluded', () {
    final first = _record()..id = 1;
    final second = _record(synced: false)..id = 99;
    expect(maintenanceReviewLocalFieldExclusions.keys.toSet(), {
      'id',
      'isSynced',
    });
    expect(
      maintenanceReviewServerBoundary(first),
      maintenanceReviewServerBoundary(second),
    );
    final allKeys = maintenancePersistedReviewValues(first).keys.toSet();
    expect(
      allKeys.union({'isSynced'}),
      MaintenanceRecordSchema.properties.keys.toSet(),
    );
  });

  group('native schema proof and adoption refusal', () {
    late Directory directory;
    late Isar db;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'complete_maintenance_review_',
      );
      db = await Isar.open(
        [
          MaintenanceRecordSchema,
          AuditEventSchema,
          DurableSubmissionRecordSchema,
          WorkflowCommandRecordSchema,
          WorkflowCommandReceiptRecordSchema,
        ],
        directory: directory.path,
        name: 'complete-boundary',
        inspector: false,
      );
    });
    tearDown(() async {
      await db.close(deleteFromDisk: true);
      directory.deleteSync(recursive: true);
    });
    test(
      'generated review codec equals every stored native schema property',
      () async {
        final row = _record();
        for (final mutate in _omittedMutations.values) {
          mutate(row);
        }
        row
          ..updatedAt = _at.add(const Duration(microseconds: 123456))
          ..metadataJson = '{"retained":" exact raw bytes "}'
          ..actionsJson = '[{"raw":1}]';
        await db.writeTxn(() => db.maintenanceRecords.put(row));
        final exported = await db.maintenanceRecords.where().exportJsonRaw(
          (bytes) => utf8.decode(bytes),
        );
        final native = (jsonDecode(exported) as List).single as Map;
        final projected = maintenancePersistedReviewValues(row);
        for (final property in MaintenanceRecordSchema.properties.values) {
          if (maintenanceReviewLocalFieldExclusions.containsKey(
            property.name,
          )) {
            continue;
          }
          Object? value = native[property.name];
          if (property.type == IsarType.dateTime && value != null) {
            value = DateTime.fromMicrosecondsSinceEpoch(
              value as int,
              isUtc: true,
            ).toIso8601String();
          }
          expect(projected[property.name], value, reason: property.name);
        }
        expect(
          projected.keys.toSet(),
          native.keys.toSet().difference({'id', 'isSynced'}),
        );
      },
    );

    test(
      'same-version omitted-field changes refuse real native keep-server adoption',
      () async {
        final local = _record(synced: false);
        await db.writeTxn(() => db.maintenanceRecords.put(local));
        final snapshot = await db.maintenanceRecords.where().exportJsonRaw(
          (bytes) => utf8.decode(bytes),
        );
        for (final entry in _omittedMutations.entries) {
          final server = _record();
          final review = _review(local, server, snapshot: snapshot);
          final repository = MaintenanceCreationSuccessorRepository(
            isar: db,
            workflow: IsarWorkflowRepository(db),
            readServer: (_) async => server,
            readCorrectionAudit: (_) async =>
                throw StateError('No remote mutation permitted'),
          );
          final service = MaintenanceCreationSuccessorService(
            repository: repository,
            store: DurableSubmissionRepository(db),
            gateway: _NoDispatch(),
            currentActor: () => AppUser(
              uid: 'si',
              name: 'SI',
              email: 'si@example.test',
              roles: [AppRole.si],
              isApproved: true,
              createdAt: _at,
            ),
            now: () => _at,
          );
          entry.value(server);
          await expectLater(
            service.keepServer(
              review: review,
              reason: 'Reviewed current issue',
              acknowledgeRetainedDifferences: true,
            ),
            throwsStateError,
            reason: entry.key,
          );
          expect(
            (await db.maintenanceRecords.get(local.id))!.isSynced,
            isFalse,
            reason: entry.key,
          );
          expect(await db.auditEvents.count(), 0, reason: entry.key);
        }
        expect(
          await db.maintenanceRecords.where().exportJsonRaw(
            (bytes) => utf8.decode(bytes),
          ),
          snapshot,
        );
      },
    );
  });
}

class _NoDispatch implements OriginBoundWorkflowCommandGateway {
  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) => throw StateError('Keep-server must not dispatch');
}
