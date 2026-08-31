import '../data/maintenance_model.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../domain/furnace_stuckup_case.dart';
import '../domain/issue_lane_plan.dart';

WorkflowCommand buildMaintenanceIssueCreateCommand(
  MaintenanceRecord record, {
  required int createVersion,
}) {
  final ticketId = record.firestoreId?.trim();
  final assetReference = record.assetHierarchyRefJson?.trim();
  final qualityIntent = record.qualityIntent;
  if (ticketId == null || ticketId.isEmpty) {
    throw StateError('A governed issue requires a stable remote identity.');
  }
  if (assetReference == null || assetReference.isEmpty) {
    throw StateError('A governed issue requires an exact asset reference.');
  }
  if (qualityIntent == null) {
    throw StateError('A governed issue requires a quality assessment.');
  }
  if (createVersion != 1) {
    throw StateError('A governed issue must begin at version 1.');
  }
  final burnerLockout = record.burnerLockoutCase;
  final furnaceStuckup = record.furnaceStuckupCase;
  final frequentIssueSelection = record.frequentIssueSelection;
  final plantConditionEffect =
      record.plantConditionEffect != MaintenanceIssuePlantConditionEffect.none
          ? record.plantConditionEffect
          : record.classification == furnaceStuckupClassification
          ? MaintenanceIssuePlantConditionEffect.stuckUp
          : MaintenanceIssuePlantConditionEffect.unfit;
  final createLanePlan = IssueLanePlan.initial(
    record.issueLanePlan.assignedLanes,
  );
  final ticket = <String, Object?>{
    'schemaVersion': 1,
    'version': createVersion,
    'assetType': record.assetType.name,
    'assetNumber': record.assetNumber,
    'component': record.component,
    'subsystem': record.subsystem,
    'tag': record.tag,
    'hierarchyPath': record.hierarchyPath,
    'assetHierarchyRefJson': assetReference,
    'maintenanceType': record.maintenanceType.name,
    'classification': record.classification,
    'description': record.description,
    'plantConditionEffect': plantConditionEffect.name,
    'routedTo': record.routedTo.name,
    'otherDepartment': record.otherDepartment,
    ...createLanePlan.toClientWriteFields(),
    'isCritical': record.isCritical,
    'startDate': record.startDate.toUtc().toIso8601String(),
    'chargeNoAtEvent': record.chargeNoAtEvent,
    ...qualityIntent.toSynchronizedFields(),
    if (burnerLockout != null)
      ...burnerLockout.clearResolution().toSynchronizedFields(),
    if (furnaceStuckup != null) ...furnaceStuckup.toSynchronizedFields(),
    if (frequentIssueSelection != null)
      'frequentIssueSelection': frequentIssueSelection.toCommandMap(),
  };
  return WorkflowCommand(
    commandId: 'createMaintenanceTicket_$ticketId',
    type: WorkflowCommandType.createMaintenanceTicket,
    aggregateId: ticketId,
    expectedVersion: 0,
    payload: <String, Object?>{'ticket': ticket},
  );
}

void validateMaintenanceIssueCreateReceipt({
  required WorkflowCommand command,
  required WorkflowCommandReceipt receipt,
  required int createVersion,
}) {
  final ticket = command.payload['ticket'];
  if (command.type != WorkflowCommandType.createMaintenanceTicket ||
      ticket is! Map ||
      createVersion != 1 ||
      ticket['version'] != 1 ||
      receipt.commandId != command.commandId ||
      receipt.resultKey != 'maintenance-ticket-created' ||
      receipt.aggregateVersion != createVersion ||
      receipt.result['ticketId'] != command.aggregateId ||
      receipt.result['auditId'] !=
          'server_maintenance_ticket_${command.commandId}') {
    throw StateError(
      'The governed issue-creation receipt is inconsistent with the issue.',
    );
  }

  final expectedWarningId =
      ticket['qualityImpactAssessment'] == 'suspected'
          ? 'issue_${command.aggregateId}'
          : null;
  final expectedAbnormalityId =
      ticket['qualityIntentSchemaVersion'] == 2 &&
              ticket['qualityImpactAssessment'] == 'suspected'
          ? 'issue_quality_${command.aggregateId}'
          : null;
  final redHotPositions = ticket['burnerRedHotPositions'];
  final expectedDirectiveId =
      redHotPositions is List && redHotPositions.isNotEmpty
          ? 'burner_red_hot_${command.aggregateId}'
          : null;
  final expectedStuckupCaseId =
      ticket['classification'] == furnaceStuckupClassification
          ? command.aggregateId
          : null;
  final selection = ticket['frequentIssueSelection'];
  final expectedReviewQueueId =
      selection is Map && selection['selectionType'] == 'unlisted'
          ? command.aggregateId
          : null;
  if (receipt.result['warningId'] != expectedWarningId ||
      receipt.result['abnormalityId'] != expectedAbnormalityId ||
      receipt.result['directiveId'] != expectedDirectiveId ||
      receipt.result['stuckupCaseId'] != expectedStuckupCaseId ||
      receipt.result['reviewQueueId'] != expectedReviewQueueId) {
    throw StateError(
      'The governed issue-creation receipt has inconsistent derived evidence.',
    );
  }
}
