enum WorkflowLaneStatus { pending, acknowledged, closed, removed, terminated }

enum WorkflowStatus {
  pendingLaneClassification,
  assigned,
  partiallyAcknowledged,
  fullyAcknowledged,
  inProgress,
  awaitingCompliance,
  readyForClosure,
  completed,
  cancelled,
}

enum ComplianceStatus {
  raised,
  acknowledged,
  complied,
  confirmedClosed,
  superseded,
  cancelled,
}

enum ComplianceConditionType { manual, chargeComplete, activityRef }

enum ComplianceRequestPurpose { assurance, deferment, operationsSupport }

enum ComplianceDefermentBasis {
  ongoingCycle,
  equipmentRequired,
  operationalCompliance,
  safetyConstraint,
  qualityConstraint,
  other,
}

enum OperationsSupportType {
  craneMovement,
  assetRelocation,
  isolation,
  processPreparation,
  utilitySupport,
  accessOrPermit,
  other,
}

enum OperationsResource { crane, transferCar, operationsCrew, utilities, other }

enum EquipmentWorkflowState {
  inService,
  underMaintenance,
  awaitingPreparation,
  underRED,
  available,
}

enum WorkflowCommandType {
  createLegacyWorkflowJob,
  createMaintenanceTicket,
  startIssueCoordination,
  upsertFrequentIssueDefinition,
  setFrequentIssueDefinitionStatus,
  upsertMaintenanceClassDefinition,
  setMaintenanceClassDefinitionStatus,
  classifyMaintenanceExecution,
  upsertMaintenancePlan,
  setMaintenancePlanStatus,
  upsertInspectionDefinition,
  setInspectionDefinitionStatus,
  createInspectionCampaign,
  setInspectionCampaignStatus,
  recordInspectionObservation,
  linkInspectionObservationIssue,
  finalizeLaneSet,
  acknowledgeLane,
  addLane,
  removeLane,
  terminateLane,
  closeLane,
  cancelWorkflow,
  raiseCompliance,
  acknowledgeCompliance,
  confirmConditionAndReactivate,
  markComplianceComplied,
  returnComplianceForCorrection,
  confirmComplianceClosed,
  proposeCounterCondition,
  decideCounterCondition,
  prepareRedLane,
  reopenWorkflowModule,
  finalizeJob,
  deployEquipment,
  reconcileEquipment,
  acknowledgeMaintenanceTicket,
  correctMaintenanceTicket,
  releaseFurnaceStuckup,
  adjudicateFurnaceStuckup,
}

enum WorkflowCommandDeliveryState {
  ready,
  sending,
  applied,
  rejected,
  uncertainOutcome,
}
