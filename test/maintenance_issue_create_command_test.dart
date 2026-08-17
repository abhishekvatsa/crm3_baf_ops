import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_create_command.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'governed issue command carries business input, not actor authority',
    () {
      final record =
          MaintenanceRecord()
            ..firestoreId = 'ticket-42'
            ..version = 3
            ..assetType = AssetType.furnace
            ..assetNumber = 7
            ..component = 'Furnace body'
            ..subsystem = 'Shell assembly'
            ..tag = 'FR-07'
            ..hierarchyPath = const <String>['Furnace', 'Furnace 7']
            ..assetHierarchyRefJson =
                '{"schemaVersion":3,"scope":"physicalAsset",'
                '"assetClassId":"class-furnace",'
                '"assetInstanceId":"asset-furnace-7",'
                '"assetInstanceVersion":4}'
            ..maintenanceType = MaintenanceType.breakdown
            ..description = 'Shell temperature is above the expected range.'
            ..routedTo = RoutedTo.mechanical
            ..isCritical = true
            ..startDate = DateTime.utc(2026, 8, 17, 4, 30)
            ..createdAt = DateTime.utc(2026, 8, 17, 4, 31)
            ..updatedAt = DateTime.utc(2026, 8, 17, 4, 32)
            ..loggedByUid = 'client-supplied-uid'
            ..loggedByName = 'Client Supplied Name'
            ..qualityIntent = const IssueQualityIntent(
              assessment: IssueQualityAssessment.notSuspected,
            );

      final command = buildMaintenanceIssueCreateCommand(
        record,
        createVersion: 1,
      );
      final ticket = Map<String, Object?>.from(
        command.payload['ticket']! as Map,
      );

      expect(command.commandId, 'createMaintenanceTicket_ticket-42');
      expect(command.type, WorkflowCommandType.createMaintenanceTicket);
      expect(command.aggregateId, 'ticket-42');
      expect(command.expectedVersion, 0);
      expect(ticket, containsPair('version', 1));
      expect(ticket, containsPair('assetType', 'furnace'));
      expect(ticket, containsPair('qualityImpactAssessment', 'notSuspected'));
      expect(ticket, containsPair('assetHierarchyRefJson', isNotEmpty));
      expect(ticket, isNot(contains('loggedByUid')));
      expect(ticket, isNot(contains('loggedByName')));
      expect(ticket, isNot(contains('createdAt')));
      expect(ticket, isNot(contains('updatedAt')));
      expect(ticket, isNot(contains('status')));
      expect(ticket, isNot(contains('isResolved')));
    },
  );

  test(
    'governed issue command requires identity, asset, and quality intent',
    () {
      final missing =
          MaintenanceRecord()
            ..assetType = AssetType.furnace
            ..assetNumber = 7
            ..component = 'Furnace body'
            ..maintenanceType = MaintenanceType.breakdown
            ..description = 'Shell temperature is above the expected range.'
            ..routedTo = RoutedTo.mechanical
            ..startDate = DateTime.utc(2026, 8, 17)
            ..createdAt = DateTime.utc(2026, 8, 17)
            ..updatedAt = DateTime.utc(2026, 8, 17);

      expect(
        () => buildMaintenanceIssueCreateCommand(missing, createVersion: 1),
        throwsStateError,
      );
    },
  );

  test('creation receipt must match command and derived evidence', () {
    final record =
        MaintenanceRecord()
          ..firestoreId = 'ticket-quality-1'
          ..version = 1
          ..assetType = AssetType.furnace
          ..assetNumber = 7
          ..component = 'Furnace body'
          ..maintenanceType = MaintenanceType.breakdown
          ..description = 'Shell temperature may have affected the charge.'
          ..routedTo = RoutedTo.mechanical
          ..isCritical = true
          ..startDate = DateTime.utc(2026, 8, 17)
          ..chargeNoAtEvent = 123456
          ..assetHierarchyRefJson =
              '{"schemaVersion":3,"scope":"physicalAsset",'
              '"assetClassId":"class-furnace",'
              '"assetInstanceId":"asset-furnace-7",'
              '"assetInstanceVersion":4}'
          ..qualityIntent = const IssueQualityIntent(
            assessment: IssueQualityAssessment.suspected,
            warningReason: 'The reported deviation requires quality review.',
          );
    final command = buildMaintenanceIssueCreateCommand(
      record,
      createVersion: 1,
    );
    final valid = WorkflowCommandReceipt(
      commandId: command.commandId,
      resultKey: 'maintenance-ticket-created',
      aggregateVersion: 1,
      result: <String, Object?>{
        'ticketId': command.aggregateId,
        'auditId': 'server_maintenance_ticket_${command.commandId}',
        'warningId': 'issue_${command.aggregateId}',
        'directiveId': null,
      },
      appliedAt: DateTime.utc(2026, 8, 17, 1),
    );

    expect(
      () => validateMaintenanceIssueCreateReceipt(
        command: command,
        receipt: valid,
        createVersion: 1,
      ),
      returnsNormally,
    );
    expect(
      () => validateMaintenanceIssueCreateReceipt(
        command: command,
        receipt: WorkflowCommandReceipt(
          commandId: command.commandId,
          resultKey: valid.resultKey,
          aggregateVersion: valid.aggregateVersion,
          result: <String, Object?>{...valid.result, 'warningId': null},
          appliedAt: valid.appliedAt,
        ),
        createVersion: 1,
      ),
      throwsStateError,
    );
  });
}
