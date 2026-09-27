import '../../assets/data/asset_hierarchy_model.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../data/maintenance_model.dart';
import '../domain/maintenance_component_identification.dart';

WorkflowCommand buildMaintenanceComponentIdentificationCommand({
  required MaintenanceRecord ticket,
  required AssetHierarchyReference target,
  required String basis,
}) {
  final original = ticket.assetHierarchyReference;
  final cleanBasis = basis.trim();
  if (!ticket.isSynced ||
      !ticket.awaitsComponentIdentification ||
      ticket.firestoreId == null ||
      original == null ||
      original.scope != AssetHierarchyReferenceScope.physicalAsset ||
      target.assetClassId != original.assetClassId ||
      target.assetInstanceId != original.assetInstanceId ||
      target.assetNumber != ticket.assetNumber ||
      !{
        AssetHierarchyReferenceScope.componentDefinitionOnAsset,
        AssetHierarchyReferenceScope.installedComponent,
      }.contains(target.scope) ||
      cleanBasis.isEmpty ||
      cleanBasis.length > 2000) {
    throw StateError(
      'Identify a registered component on the original asset and explain the evidence.',
    );
  }
  return WorkflowCommandFactory.create(
    type: WorkflowCommandType.identifyMaintenanceTicketComponent,
    aggregateId: ticket.firestoreId!,
    expectedVersion: ticket.version,
    payload: {'targetReferenceJson': target.encode(), 'basis': cleanBasis},
  );
}

MaintenanceComponentIdentification
validateMaintenanceComponentIdentificationReceipt({
  required WorkflowCommand command,
  required WorkflowCommandReceipt receipt,
  required String actorUid,
}) {
  if (command.type != WorkflowCommandType.identifyMaintenanceTicketComponent ||
      receipt.commandId != command.commandId ||
      receipt.resultKey != 'maintenance-ticket-component-identified' ||
      receipt.aggregateVersion != command.expectedVersion + 1 ||
      receipt.result['ticketId'] != command.aggregateId ||
      receipt.result['auditId'] !=
          'server_maintenance_ticket_${command.commandId}' ||
      receipt.result['componentIdentification'] is! Map) {
    throw StateError(
      'The component identification receipt does not match the request.',
    );
  }
  final identified = MaintenanceComponentIdentification.fromMap(
    Map<String, dynamic>.from(receipt.result['componentIdentification'] as Map),
  );
  final requested = AssetHierarchyReference.decode(
    command.payload['targetReferenceJson'] as String,
    source: 'component identification request',
  );
  final accepted = identified.target;
  if (identified.originalTicketVersion != command.expectedVersion ||
      identified.basis != command.payload['basis'] ||
      identified.identifiedByUid != actorUid ||
      identified.identifiedAt.toUtc() != receipt.appliedAt.toUtc() ||
      accepted.assetClassId != requested.assetClassId ||
      accepted.assetInstanceId != requested.assetInstanceId ||
      accepted.scope != requested.scope ||
      accepted.nodeId != requested.nodeId ||
      accepted.nodeVersion != requested.nodeVersion ||
      accepted.assetInstanceVersion != requested.assetInstanceVersion ||
      accepted.componentInstanceId != requested.componentInstanceId ||
      accepted.componentInstanceVersion != requested.componentInstanceVersion) {
    throw StateError(
      'The component identification receipt has inconsistent evidence.',
    );
  }
  return identified;
}
