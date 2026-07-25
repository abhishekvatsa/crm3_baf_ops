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

enum EquipmentWorkflowState {
  inService,
  underMaintenance,
  awaitingPreparation,
  underRED,
  available,
}

enum WorkflowCommandType {
  createLegacyWorkflowJob,
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
}

enum WorkflowCommandDeliveryState {
  ready,
  sending,
  applied,
  rejected,
  uncertainOutcome,
}
