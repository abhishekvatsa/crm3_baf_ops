import 'dart:convert';

import '../../../core/persistence/durable_submission.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';

class InspectionCampaignSubmissionException implements Exception {
  const InspectionCampaignSubmissionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One frozen creation request. Payload getters decode fresh objects so callers
/// cannot change nested lists retained by the saved intent.
class InspectionCampaignSubmission {
  InspectionCampaignSubmission._(this.envelopeJson);
  final String envelopeJson;

  factory InspectionCampaignSubmission.prepare({
    required String actorUid,
    required String commandId,
    required String campaignId,
    required Map<String, Object?> payload,
  }) => InspectionCampaignSubmission.parse(
    jsonEncode({
      'protocolVersion': 2,
      'originActorUid': actorUid,
      'command': WorkflowCommand(
        commandId: commandId,
        type: WorkflowCommandType.createInspectionCampaign,
        aggregateId: campaignId,
        expectedVersion: 0,
        payload: payload,
      ).toMap(),
    }),
  );

  factory InspectionCampaignSubmission.parse(String raw) {
    final outer = durableSubmissionJsonObject(raw);
    final actor = outer['originActorUid'];
    final inner = outer['command'];
    if (outer.length != 3 ||
        outer['protocolVersion'] != 2 ||
        actor is! String ||
        actor.trim().isEmpty ||
        actor != actor.trim() ||
        inner is! Map<String, dynamic> ||
        inner.length != 5 ||
        inner['commandType'] != 'createInspectionCampaign' ||
        inner['expectedVersion'] is! int ||
        inner['expectedVersion'] != 0 ||
        inner['commandId'] is! String ||
        inner['aggregateId'] is! String ||
        inner['payload'] is! Map<String, dynamic>) {
      _invalid();
    }
    final payload = inner['payload'] as Map<String, dynamic>;
    const keys = {
      'definitionId',
      'definitionVersion',
      'purpose',
      'assetTypeKey',
      'assetClassId',
      'populationMode',
      'hostAssetClassId',
      'targetAssetNumbers',
      'expectedPopulation',
      'physicalPositionLabels',
      'baselineCampaignId',
      'observerRoleKeys',
      'reason',
    };
    if (payload.length != keys.length ||
        !payload.keys.toSet().containsAll(keys)) {
      _invalid();
    }
    for (final key in [
      'definitionId',
      'purpose',
      'assetTypeKey',
      'assetClassId',
      'reason',
    ]) {
      final value = payload[key];
      if (value is! String || value.trim().isEmpty || value != value.trim()) {
        _invalid();
      }
    }
    for (final key in ['hostAssetClassId', 'baselineCampaignId']) {
      final value = payload[key];
      if (value != null &&
          (value is! String || value.trim().isEmpty || value != value.trim())) {
        _invalid();
      }
    }
    final mode = payload['populationMode'];
    if (!const {
          'assetInstances',
          'installedInnerCoversByBase',
        }.contains(mode) ||
        (mode == 'assetInstances' && payload['hostAssetClassId'] != null) ||
        (mode == 'installedInnerCoversByBase' &&
            (payload['hostAssetClassId'] == null ||
                payload['assetTypeKey'] != 'innerCover'))) {
      _invalid();
    }
    for (final key in ['definitionVersion', 'expectedPopulation']) {
      final value = payload[key];
      if (value is! int || value < 1 || value > 9007199254740991) _invalid();
    }
    if ((payload['expectedPopulation'] as int) > 500) _invalid();
    final numbers = payload['targetAssetNumbers'];
    if (numbers is! List ||
        numbers.isEmpty ||
        numbers.length > 500 ||
        numbers.any((value) => value is! int || value < 1) ||
        numbers.toSet().length != numbers.length) {
      _invalid();
    }
    for (final key in ['physicalPositionLabels', 'observerRoleKeys']) {
      final values = payload[key];
      if (values is! List ||
          (key == 'observerRoleKeys' && values.isEmpty) ||
          values.any(
            (value) =>
                value is! String ||
                value.trim().isEmpty ||
                value != value.trim(),
          ) ||
          values.toSet().length != values.length) {
        _invalid();
      }
    }
    final submission = InspectionCampaignSubmission._(raw);
    // Apply the shared document-identity contract too.
    submission.command;
    return submission;
  }

  Map<String, dynamic> get _outer => durableSubmissionJsonObject(envelopeJson);
  String get actorUid => _outer['originActorUid'] as String;
  String get resourceKey => 'inspectionCampaignCreation:$actorUid';
  WorkflowCommand get command {
    final inner = _outer['command'] as Map<String, dynamic>;
    return WorkflowCommand(
      commandId: inner['commandId'] as String,
      type: WorkflowCommandType.createInspectionCampaign,
      aggregateId: inner['aggregateId'] as String,
      expectedVersion: 0,
      payload: Map<String, Object?>.from(inner['payload'] as Map),
    );
  }

  static Never _invalid() => throw const InspectionCampaignSubmissionException(
    'Saved programme entries are incomplete or inconsistent. They are retained for review; nothing was sent.',
  );
}
