import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_create_command.dart';
import 'package:crm3_baf_ops/features/maintenance/data/frequent_issue_definition.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/frequent_issue_selection.dart';
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

  test('governed create-open burner payload clears local closure evidence', () {
    final record =
        MaintenanceRecord()
          ..firestoreId = 'burner-ticket-1'
          ..version = 2
          ..assetType = AssetType.furnace
          ..assetNumber = 7
          ..component = 'Burner system'
          ..classification = burnerLockoutClassification
          ..maintenanceType = MaintenanceType.breakdown
          ..description = 'Burner 2 locked out during firing.'
          ..routedTo = RoutedTo.instrumentation
          ..startDate = DateTime.utc(2026, 8, 17)
          ..assetHierarchyRefJson =
              '{"schemaVersion":3,"scope":"physicalAsset",'
              '"assetClassId":"class-furnace",'
              '"assetInstanceId":"asset-furnace-7",'
              '"assetInstanceVersion":4}'
          ..qualityIntent = const IssueQualityIntent(
            assessment: IssueQualityAssessment.notSuspected,
          )
          ..burnerLockoutCase = BurnerLockoutCase(
            positions: const <int>[2],
            commonMode: false,
            cycleStage: BurnerCycleStage.firing,
            flameObservation: BurnerObservation.notSeen,
            sparkObservation: BurnerObservation.seen,
            relightAttempts: 1,
            remainsLockedOut: false,
            attendedPositions: const <int>[2],
            resolutionOutcomes: const <int, BurnerResolutionOutcome>{
              2: BurnerResolutionOutcome.returnedToService,
            },
            resolutionActionCodes: const <int, List<BurnerActionCode>>{
              2: <BurnerActionCode>[BurnerActionCode.uvDetectorCleaning],
            },
            resolutionMicroampReadings: const <int, double>{2: 3.7},
          );

    final command = buildMaintenanceIssueCreateCommand(
      record,
      createVersion: 1,
    );
    final ticket = Map<String, Object?>.from(command.payload['ticket']! as Map);

    expect(ticket['burnerAttendedPositions'], isEmpty);
    expect(ticket['burnerResolutionEvidence'], isEmpty);
    expect(ticket['burnerPositions'], <int>[2]);
  });

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
          ..chargeNoAtEvent = 12345
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

  test(
    'frequent issue selection is carried without mutable catalogue text',
    () {
      final record =
          MaintenanceRecord()
            ..firestoreId = 'ticket-frequent-1'
            ..version = 1
            ..assetType = AssetType.furnace
            ..assetNumber = 7
            ..component = 'Burner system'
            ..maintenanceType = MaintenanceType.breakdown
            ..description = 'Burner flame is unstable.'
            ..routedTo = RoutedTo.instrumentation
            ..startDate = DateTime.utc(2026, 8, 20)
            ..assetHierarchyRefJson =
                '{"schemaVersion":4,"scope":"componentDefinitionOnAsset",'
                '"assetClassId":"class-furnace","nodeId":"node-burner",'
                '"nodeVersion":2,"assetInstanceId":"furnace-7",'
                '"assetInstanceVersion":4}'
            ..qualityIntent = const IssueQualityIntent(
              assessment: IssueQualityAssessment.notSuspected,
            )
            ..frequentIssueSelection = FrequentIssueSelection.definition(
              _definition(),
            );

      final command = buildMaintenanceIssueCreateCommand(
        record,
        createVersion: 1,
      );
      final ticket = Map<String, Object?>.from(
        command.payload['ticket']! as Map,
      );
      final selection = Map<String, Object?>.from(
        ticket['frequentIssueSelection']! as Map,
      );

      expect(selection, <String, Object?>{
        'schemaVersion': 1,
        'selectionType': 'definition',
        'definitionId': 'issue-1',
        'definitionVersion': 3,
        'unlistedReason': null,
      });
      expect(selection, isNot(contains('definitionTitle')));
      expect(selection, isNot(contains('definitionCode')));
    },
  );
}

FrequentIssueDefinition _definition() => FrequentIssueDefinition(
  id: 'issue-1',
  version: 3,
  status: FrequentIssueDefinitionStatus.active,
  code: 'FLAME_UNSTABLE',
  title: 'Unstable flame',
  description: 'Burner flame is unstable.',
  applicableAssetTypeKeys: const <String>['furnace'],
  applicableAssetClassIds: const <String>[],
  applicableComponentNodeIds: const <String>['node-burner'],
  suggestedSeverityKey: 'normal',
  suggestedMaintenanceTypeKey: 'breakdown',
  defaultRouteKey: 'instrumentation',
  requiredEvidenceFields: const <String>['observation'],
  aliases: const <String>[],
  createdAt: DateTime.utc(2026, 8, 20),
  createdByUid: 'admin-1',
  createdByName: 'Admin',
  updatedAt: DateTime.utc(2026, 8, 20),
  updatedByUid: 'admin-1',
  updatedByName: 'Admin',
);
