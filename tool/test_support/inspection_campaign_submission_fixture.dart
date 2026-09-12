import 'dart:async';
import 'dart:convert';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/inspections/domain/inspection_campaign_submission.dart';
import 'package:crm3_baf_ops/features/inspections/repositories/inspection_campaign_creation_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';

AppUser campaignManager([String uid = 'manager-a']) => AppUser(
  uid: uid,
  name: 'Programme manager',
  email: '$uid@example.test',
  roles: const [AppRole.shiftSupervisor],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

Map<String, Object?> campaignCreationPayload() => {
  'definitionId': 'definition-1',
  'definitionVersion': 2,
  'purpose': 'Verify furnace pressure settings.',
  'assetTypeKey': 'furnace',
  'assetClassId': 'class-furnace',
  'populationMode': 'assetInstances',
  'hostAssetClassId': null,
  'targetAssetNumbers': [7],
  'expectedPopulation': 1,
  'physicalPositionLabels': ['Gas train'],
  'baselineCampaignId': null,
  'observerRoleKeys': ['seniorInstrumentation'],
  'reason': 'Open the pressure inspection.',
};

/// Capable idempotent server double: a fresh ID really creates another record.
/// Assertions about zero duplicate creations therefore do not rely on failure.
class CampaignCreationServer extends InspectionCampaignCreationReader
    implements OriginBoundWorkflowCommandGateway {
  final List<String> envelopes = [];
  final Map<String, Map<String, dynamic>> campaigns = {};
  final Map<String, WorkflowCommandReceipt> receipts = {};
  bool loseNextResponse = false;
  bool wrongReceipt = false;
  bool failRead = false;
  int reads = 0;
  Completer<void>? dispatchGate;
  void Function()? onRead;
  final appliedAt = DateTime.utc(2026, 9, 12, 10);

  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    envelopes.add(envelopeJson);
    await dispatchGate?.future;
    final frozen = InspectionCampaignSubmission.parse(envelopeJson);
    final command = frozen.command;
    final receipt = receipts.putIfAbsent(command.commandId, () {
      campaigns[command.aggregateId] = campaignDocument(frozen, appliedAt);
      return WorkflowCommandReceipt(
        commandId: command.commandId,
        resultKey: 'inspection-campaign-created',
        aggregateVersion: 1,
        appliedAt: appliedAt,
        result: {
          'campaignId': command.aggregateId,
          'status': 'open',
          'definitionCode': 'FURNACE_PT',
        },
      );
    });
    if (loseNextResponse) {
      loseNextResponse = false;
      throw StateError('The server accepted, but the response was lost.');
    }
    if (wrongReceipt) {
      return WorkflowCommandReceipt(
        commandId: receipt.commandId,
        resultKey: receipt.resultKey,
        aggregateVersion: 1,
        appliedAt: appliedAt,
        result: {...receipt.result, 'campaignId': 'another-campaign'},
      );
    }
    return receipt;
  }

  @override
  Future<Map<String, dynamic>> read(String campaignId) async {
    reads++;
    onRead?.call();
    if (failRead) throw StateError('Server read unavailable');
    final raw = campaigns[campaignId];
    if (raw == null) throw StateError('Missing server campaign');
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map);
  }
}

Map<String, dynamic> campaignDocument(
  InspectionCampaignSubmission frozen,
  DateTime at,
) {
  final command = frozen.command;
  final payload = command.payload;
  final numbers = (payload['targetAssetNumbers'] as List).cast<int>();
  return {
    'schemaVersion': 2,
    'campaignId': command.aggregateId,
    'version': 1,
    'status': 'open',
    ...payload,
    'definition': {
      'schemaVersion': 1,
      'definitionId': payload['definitionId'],
      'definitionVersion': payload['definitionVersion'],
      'code': 'FURNACE_PT',
      'title': 'Pressure setting',
      'description': 'Verify pressure.',
      'assetTypeKeys': ['furnace'],
      'assetClassIds': ['class-furnace'],
      'componentNodeIds': ['pressure-transmitter'],
      'valueType': 'number',
      'unit': 'bar',
      'choiceValues': <String>[],
      'minimumValue': 2,
      'maximumValue': 4,
      'preconditions': <String>[],
      'requiresChargeNo': false,
    },
    'definitionCode': 'FURNACE_PT',
    'definitionTitle': 'Pressure setting',
    'targetPopulation': [
      for (final number in numbers)
        campaignCreationTarget(number, at, frozen.actorUid),
    ],
    'targetDispositionCounts': {
      'pending': numbers.length,
      'observed': 0,
      'deferred': 0,
      'unavailable': 0,
      'excludedWithReason': 0,
      'requiresReaudit': 0,
    },
    'observationCount': 0,
    'distinctTargetKeys': <String>[],
    'latestObservationAt': null,
    'createdAt': at.toIso8601String(),
    'createdByUid': frozen.actorUid,
  };
}

Map<String, dynamic> campaignCreationTarget(
  int number,
  DateTime at,
  String actor,
) => {
  'schemaVersion': 1,
  'targetKey': 'class-furnace:furnace-$number|pressure-transmitter|Gas train',
  'assetTypeKey': 'furnace',
  'assetClassId': 'class-furnace',
  'assetNumber': number,
  'assetInstanceId': 'furnace-$number',
  'assetInstanceVersion': 1,
  'assetInstanceName': 'Furnace $number',
  'componentNodeId': 'pressure-transmitter',
  'physicalPosition': 'Gas train',
  'disposition': 'pending',
  'dispositionReason': null,
  'dispositionAt': at.toIso8601String(),
  'dispositionByUid': actor,
  'dispositionByName': 'Programme manager',
  'addedLater': false,
  'lastObservationId': null,
  'lastObservedAt': null,
};
