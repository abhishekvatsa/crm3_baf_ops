import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_create_command.dart';
import 'package:crm3_baf_ops/features/maintenance/data/frequent_issue_definition.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/frequent_issue_selection.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
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
      expect(ticket, containsPair('plantConditionEffect', 'unfit'));
      expect(ticket, containsPair('assetHierarchyRefJson', isNotEmpty));
      expect(ticket, isNot(contains('loggedByUid')));
      expect(ticket, isNot(contains('loggedByName')));
      expect(ticket, isNot(contains('createdAt')));
      expect(ticket, isNot(contains('updatedAt')));
      expect(ticket, isNot(contains('status')));
      expect(ticket, isNot(contains('isResolved')));
      expect(ticket, isNot(contains(issueLaneCompletionEvidenceFieldName)));
      expect(ticket.keys.toSet(), <String>{
        'schemaVersion',
        'version',
        'assetType',
        'assetNumber',
        'component',
        'subsystem',
        'tag',
        'hierarchyPath',
        'assetHierarchyRefJson',
        'maintenanceType',
        'classification',
        'description',
        'plantConditionEffect',
        'routedTo',
        'otherDepartment',
        'issueLaneSchemaVersion',
        'issueLaneRevision',
        'issueAssignedLanes',
        'issueAcknowledgedLanes',
        'issueCompletedLanes',
        'isCritical',
        'startDate',
        'chargeNoAtEvent',
        'qualityIntentSchemaVersion',
        'qualityImpactAssessment',
        'qualityWarningReason',
        'qualityAbnormalityTypeId',
      });
    },
  );

  test('client lane fields match the shared server command contract', () {
    final contract = Map<String, Object?>.from(
      jsonDecode(
            File(
              'test/fixtures/maintenance_ticket_lane_command_contract_v1.json',
            ).readAsStringSync(),
          )
          as Map,
    );
    final clientFields = List<String>.from(
      contract['clientWriteFields']! as List,
    );
    final serverOwnedFields = List<String>.from(
      contract['serverOwnedFields']! as List,
    );
    final plan = IssueLanePlan.initial(const <String>[
      'mechanical',
      'instrumentation',
    ]);

    expect(plan.toClientWriteFields().keys, orderedEquals(clientFields));
    expect(serverOwnedFields, <String>[issueLaneCompletionEvidenceFieldName]);
    expect(
      plan.toClientWriteFields().keys.toSet().intersection(
        serverOwnedFields.toSet(),
      ),
      isEmpty,
    );
  });

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

  test(
    'Base Inner Cover availability uses verified dependency evidence without a component tag',
    () {
      final eventAt = DateTime.utc(2026, 9, 1, 4, 30);
      final record =
          MaintenanceRecord()
            ..firestoreId = 'base-inner-cover-unavailable-201'
            ..version = 1
            ..assetType = AssetType.base
            ..assetNumber = 201
            ..component = baseInnerCoverAvailabilityComponent
            ..subsystem = baseInnerCoverAvailabilitySubsystem
            ..maintenanceType = MaintenanceType.breakdown
            ..classification = baseInnerCoverUnavailableClassification
            ..description = 'Base 201 has no Inner Cover available.'
            ..plantConditionEffect =
                MaintenanceIssuePlantConditionEffect.unavailable
            ..routedTo = RoutedTo.operations
            ..startDate = eventAt
            ..assetHierarchyRefJson =
                AssetHierarchyReference(
                  scope: AssetHierarchyReferenceScope.physicalAsset,
                  assetClassId: 'class-base',
                  assetClassCode: 'BASE',
                  assetClassName: 'Base',
                  nodeId: 'asset-base-201',
                  nodeVersion: 3,
                  nodeName: 'Base 201',
                  assetInstanceId: 'asset-base-201',
                  assetInstanceVersion: 3,
                  assetNumber: 201,
                  assetInstanceName: 'Base 201',
                  hierarchyPath: const <String>['Base', 'Base 201'],
                  ownershipStatus: AssetOwnershipStatus.confirmed,
                  ownerDiscipline: 'Operations',
                  accountableRoleKeys: const <String>['operations'],
                  innerCoverAssociation: InnerCoverEventReference(
                    baseAssetInstanceId: 'asset-base-201',
                    baseAssetNumber: 201,
                    positionState: InnerCoverPositionState.noneLinked,
                    eventAt: eventAt,
                    confirmedAt: eventAt.add(const Duration(minutes: 1)),
                    confirmedByUid: 'operations-1',
                    confirmedByName: 'Operations User',
                  ),
                ).encode()
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

      expect(ticket['classification'], baseInnerCoverUnavailableClassification);
      expect(ticket['component'], baseInnerCoverAvailabilityComponent);
      expect(ticket['subsystem'], baseInnerCoverAvailabilitySubsystem);
      expect(ticket['plantConditionEffect'], 'unavailable');
      expect(ticket['tag'], isNull);
      expect(ticket, isNot(contains('frequentIssueSelection')));
    },
  );

  test('Base Inner Cover availability rejects missing vacancy evidence', () {
    final record =
        MaintenanceRecord()
          ..firestoreId = 'base-inner-cover-unverified-201'
          ..version = 1
          ..assetType = AssetType.base
          ..assetNumber = 201
          ..component = baseInnerCoverAvailabilityComponent
          ..subsystem = baseInnerCoverAvailabilitySubsystem
          ..maintenanceType = MaintenanceType.breakdown
          ..classification = baseInnerCoverUnavailableClassification
          ..description = 'Base 201 has no Inner Cover available.'
          ..plantConditionEffect =
              MaintenanceIssuePlantConditionEffect.unavailable
          ..routedTo = RoutedTo.operations
          ..startDate = DateTime.utc(2026, 9, 1)
          ..assetHierarchyRefJson =
              const AssetHierarchyReference(
                scope: AssetHierarchyReferenceScope.physicalAsset,
                assetClassId: 'class-base',
                assetClassCode: 'BASE',
                assetClassName: 'Base',
                nodeId: 'asset-base-201',
                nodeVersion: 3,
                nodeName: 'Base 201',
                assetInstanceId: 'asset-base-201',
                assetInstanceVersion: 3,
                assetNumber: 201,
                assetInstanceName: 'Base 201',
                hierarchyPath: <String>['Base', 'Base 201'],
                ownershipStatus: AssetOwnershipStatus.confirmed,
                ownerDiscipline: 'Operations',
                accountableRoleKeys: <String>['operations'],
              ).encode()
          ..qualityIntent = const IssueQualityIntent(
            assessment: IssueQualityAssessment.notSuspected,
          );

    expect(
      () => buildMaintenanceIssueCreateCommand(record, createVersion: 1),
      throwsStateError,
    );
  });

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
          ..status = TicketStatus.resolved
          ..isResolved = true
          ..acknowledgedByUid = 'instrumentation-supervisor-1'
          ..acknowledgedByName = 'Instrumentation Supervisor'
          ..acknowledgedAt = DateTime.utc(2026, 8, 17, 8)
          ..issueLanePlan =
              IssueLanePlan.initial(const <String>[
                'instrumentation',
                'electrical',
              ]).completeAll()
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
    expect(ticket['issueAssignedLanes'], const <String>[
      'instrumentation',
      'electrical',
    ]);
    expect(ticket['issueAcknowledgedLanes'], isEmpty);
    expect(ticket['issueCompletedLanes'], isEmpty);
  });

  test('governed creation rejects a local revision as the server baseline', () {
    final record =
        MaintenanceRecord()
          ..firestoreId = 'ticket-local-revision'
          ..assetHierarchyRefJson =
              '{"schemaVersion":3,"scope":"physicalAsset",'
              '"assetClassId":"class-furnace",'
              '"assetInstanceId":"asset-furnace-7",'
              '"assetInstanceVersion":1}'
          ..qualityIntent = const IssueQualityIntent(
            assessment: IssueQualityAssessment.notSuspected,
          );

    expect(
      () => buildMaintenanceIssueCreateCommand(record, createVersion: 2),
      throwsStateError,
    );
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
            abnormalityTypeId: 'ATMOSPHERE_DEVIATION',
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
        'abnormalityId': 'issue_quality_${command.aggregateId}',
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

  test('legacy suspected receipt remains recoverable without abnormality', () {
    const ticketId = 'legacy-quality-ticket';
    final command = WorkflowCommand(
      commandId: 'createMaintenanceTicket_$ticketId',
      type: WorkflowCommandType.createMaintenanceTicket,
      aggregateId: ticketId,
      expectedVersion: 0,
      payload: const <String, Object?>{
        'ticket': <String, Object?>{
          'version': 1,
          'qualityIntentSchemaVersion': 1,
          'qualityImpactAssessment': 'suspected',
        },
      },
    );
    final receipt = WorkflowCommandReceipt(
      commandId: command.commandId,
      resultKey: 'maintenance-ticket-created',
      aggregateVersion: 1,
      result: <String, Object?>{
        'ticketId': ticketId,
        'auditId': 'server_maintenance_ticket_${command.commandId}',
        'warningId': 'issue_$ticketId',
      },
      appliedAt: DateTime.utc(2026, 8, 17),
    );

    expect(
      () => validateMaintenanceIssueCreateReceipt(
        command: command,
        receipt: receipt,
        createVersion: 1,
      ),
      returnsNormally,
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
