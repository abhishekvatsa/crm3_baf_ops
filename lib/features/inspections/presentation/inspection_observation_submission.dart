part of 'inspection_programmes_screen.dart';

class _InspectionObservationDraft {
  const _InspectionObservationDraft({
    required this.observationId,
    required this.campaign,
    required this.target,
    required this.component,
    required this.physicalPosition,
    required this.observedAt,
    required this.numericValue,
    required this.booleanValue,
    required this.textValue,
    required this.choiceValue,
    required this.conditions,
    required this.chargeNo,
    required this.note,
    required this.evidenceUrls,
    required this.supersedesObservationId,
    required this.correction,
  });

  final String observationId;
  final InspectionCampaign campaign;
  final InspectionCampaignTarget target;
  final AssetHierarchyNode? component;
  final String? physicalPosition;
  final DateTime observedAt;
  final double? numericValue;
  final bool? booleanValue;
  final String? textValue;
  final String? choiceValue;
  final Map<String, String> conditions;
  final int? chargeNo;
  final String? note;
  final List<String> evidenceUrls;
  final String? supersedesObservationId;
  final InspectionObservation? correction;

  Map<String, Object?> toPayload() => {
    'observationId': observationId,
    'targetKey': target.targetKey,
    if (target.contextRevision > 0)
      'targetContextRevision': target.contextRevision,
    'definitionVersion': campaign.definition.version,
    'assetTypeKey': campaign.assetTypeKey,
    'assetNumber': target.assetNumber,
    'assetClassId': target.assetClassId,
    'assetInstanceId': target.assetInstanceId,
    'componentNodeId': correction == null
        ? component?.id
        : correction!.componentNodeId,
    'componentNodeVersion': correction == null
        ? component?.version
        : correction!.componentNodeVersion,
    'componentName': correction == null
        ? component?.name
        : correction!.componentName,
    'hierarchyPath': correction == null
        ? component?.hierarchyPath ?? const <String>[]
        : correction!.hierarchyPath,
    'physicalPosition': correction == null
        ? physicalPosition
        : correction!.physicalPosition,
    'observedAt': observedAt.toUtc().toIso8601String(),
    'value': {
      'valueType': campaign.definition.valueType.name,
      'numericValue': numericValue,
      'booleanValue': booleanValue,
      'textValue': textValue,
      'choiceValue': choiceValue,
    },
    'unit': campaign.definition.unit,
    'operatingConditions': conditions,
    'chargeNo': chargeNo,
    'note': note,
    'evidenceUrls': evidenceUrls,
    'supersedesObservationId': supersedesObservationId,
  };
}

Future<void> _recordObservation(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  List<AssetHierarchyNode> nodes, {
  InspectionObservation? correction,
  String? initialTargetKey,
}) async {
  final draft = await showDialog<_InspectionObservationDraft>(
    context: context,
    builder: (_) => _InspectionObservationEditor(
      campaign: campaign,
      nodes: nodes,
      correction: correction,
      initialTargetKey: initialTargetKey,
    ),
  );
  if (draft == null || !context.mounted) return;
  final receipt = await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'recordInspectionObservation_${const Uuid().v4()}',
      type: WorkflowCommandType.recordInspectionObservation,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: draft.toPayload(),
    ),
    correction == null
        ? 'Inspection reading recorded.'
        : 'Correction recorded.',
  );
  if (receipt?.result['issueRecommended'] == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This result is outside the governed range. Raise a maintenance issue, then link its ID from this reading.',
        ),
        backgroundColor: BafColors.warning,
        duration: Duration(seconds: 6),
      ),
    );
  }
}
