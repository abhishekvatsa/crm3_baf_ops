import {Actor, JsonMap, WorkflowCommand} from "../src/maintenanceWorkflow/types";
import {MaintenanceWorkflowCommandService} from "../src/maintenanceWorkflow/dispatcher";
import {MemoryWorkflowStore} from "../src/maintenanceWorkflow/memoryStore";
import {deriveEquipmentState} from "../src/maintenanceWorkflow/equipmentProjection";
import {evaluateRedExit} from "../src/maintenanceWorkflow/redPolicy";
import {hasProtectedProgress} from "../src/maintenanceWorkflow/laneProgress";
import {WorkflowError} from "../src/maintenanceWorkflow/errors";

let passed = 0;
let failed = 0;
const assert = (condition: unknown, message: string): void => { if (!condition) throw new Error(message); };
const equal = (actual: unknown, expected: unknown, message: string): void => {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error(`${message}; expected=${JSON.stringify(expected)} actual=${JSON.stringify(actual)}`);
};
const test = async (name: string, body: () => void | Promise<void>): Promise<void> => {
  try { await body(); passed += 1; console.log(`PASS ${name}`); }
  catch (error) { failed += 1; console.error(`FAIL ${name}:`, error); }
};

const actor = (uid: string, roles: Actor["roles"]): Actor => ({uid, name: uid, roles});
const admin = actor("admin-1", new Set(["admin"]));
const ops = actor("ops-1", new Set(["operations"]));
const electrical = actor("elec-1", new Set(["seniorElectrical"]));
const refractory = actor("red-1", new Set(["refractory"]));

const serviceFor = (
  store: MemoryWorkflowStore,
): MaintenanceWorkflowCommandService => {
  for (const current of [admin, ops, electrical, refractory]) {
    store.seed(`users/${current.uid}`, {
      isApproved: true,
      roles: [...current.roles],
      name: current.name,
    });
  }
  return new MaintenanceWorkflowCommandService(store);
};

const command = (type: WorkflowCommand["commandType"], id: string, version: number, payload: JsonMap): WorkflowCommand => ({
  commandId: `${type}-${Math.random().toString(16).slice(2)}`,
  commandType: type,
  aggregateId: id,
  expectedVersion: version,
  payload,
});

const seedWorkflow = (store: MemoryWorkflowStore, id = "wf1", status = "pendingLaneClassification", version = 0): void => {
  store.seed(`maintenance_workflows/${id}`, {
    jobExecutionId: `${id}-exec`, status, version, assetTypeKey: "furnace", assetNumber: 7,
    laneSetFinalizedAt: null, cancelled: false, createdAt: "2026-07-20T00:00:00.000Z", updatedAt: "2026-07-20T00:00:00.000Z",
  });
  store.seed(`job_executions/${id}-exec`, {version: 1, isCompleted: false});
};

void (async () => {
  await test("RED applicability excludes force cooler", () => {
    equal(evaluateRedExit({assetTypeKey: "forceCooler", wouldCompleteParent: true, redAlreadyInWorkflow: false, redRequired: null, preparationRequired: null}).action, "notApplicable", "force cooler must not prompt RED");
  });
  await test("Furnace RED may require preparation", () => {
    equal(evaluateRedExit({assetTypeKey: "furnace", wouldCompleteParent: true, redAlreadyInWorkflow: false, redRequired: true, preparationRequired: true}).action, "createREDSuccessorAwaitingPreparation", "furnace should await preparation");
  });
  await test("Equipment projection prefers preparation before RED", () => {
    equal(deriveEquipmentState({activeNonRedMaintenanceCount: 0, activeRedWorkCount: 0, awaitingPreparationCount: 1, operationsDeployed: false}).state, "awaitingPreparation", "state mismatch");
  });
  await test("Acknowledgement alone is not protected progress", () => {
    assert(!hasProtectedProgress({acknowledged: true, moduleWork: false, diary: false, attachment: false, evidence: false, substantiveNote: false, complianceLink: false, carryForward: false, closureHistory: false}), "acknowledgement should not protect lane");
  });
  await test("Lane-less workflow can be finalised by Admin", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store);
    const service = serviceFor(store);
    const receipt = await service.execute(command("finalizeLaneSet", "wf1", 0, {laneKeys: ["elec", "mech"]}), {actor: admin, serverNow: new Date("2026-07-20T01:00:00Z")});
    equal(receipt.resultKey, "lane-set-finalized", "receipt mismatch");
    equal(store.read("maintenance_workflows/wf1")?.status, "assigned", "workflow should be assigned");
  });
  await test("Lane set finalisation is idempotent", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store);
    const service = serviceFor(store);
    const cmd: WorkflowCommand = {commandId: "same", commandType: "finalizeLaneSet", aggregateId: "wf1", expectedVersion: 0, payload: {laneKeys: ["elec"]}};
    const first = await service.execute(cmd, {actor: admin, serverNow: new Date("2026-07-20T01:00:00Z")});
    const second = await service.execute(cmd, {actor: admin, serverNow: new Date("2026-07-20T01:01:00Z")});
    equal(second, first, "replay should return original receipt");
  });
  await test("EMD can be acknowledged by Admin on behalf of EMD", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store);
    const service = serviceFor(store);
    await service.execute({commandId: "f", commandType: "finalizeLaneSet", aggregateId: "wf1", expectedVersion: 0, payload: {laneKeys: ["emd"]}}, {actor: admin, serverNow: new Date("2026-07-20T01:00:00Z")});
    await service.execute({commandId: "a", commandType: "acknowledgeLane", aggregateId: "wf1", expectedVersion: 1, payload: {laneKey: "emd"}}, {actor: admin, serverNow: new Date("2026-07-20T01:02:00Z")});
    const event = store.read("maintenance_workflow_events/a");
    equal(event?.representedLaneKey, "emd", "represented lane should be recorded");
  });
  await test("Ordinary Operations user cannot close OPRN lane", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store);
    const service = serviceFor(store);
    await service.execute({commandId: "f", commandType: "finalizeLaneSet", aggregateId: "wf1", expectedVersion: 0, payload: {laneKeys: ["oprn"]}}, {actor: admin, serverNow: new Date("2026-07-20T01:00:00Z")});
    await service.execute({commandId: "a", commandType: "acknowledgeLane", aggregateId: "wf1", expectedVersion: 1, payload: {laneKey: "oprn"}}, {actor: ops, serverNow: new Date("2026-07-20T01:01:00Z")});
    let denied = false;
    try { await service.execute({commandId: "c", commandType: "closeLane", aggregateId: "wf1", expectedVersion: 2, payload: {laneKey: "oprn"}}, {actor: ops, serverNow: new Date("2026-07-20T01:02:00Z")}); }
    catch (error) { denied = error instanceof WorkflowError && error.code === "permission-denied"; }
    assert(denied, "Operations close should be denied");
  });
  await test("Acknowledged untouched lane can be removed and workflow reclassified", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store);
    const service = serviceFor(store);
    await service.execute({commandId: "f", commandType: "finalizeLaneSet", aggregateId: "wf1", expectedVersion: 0, payload: {laneKeys: ["elec"]}}, {actor: admin, serverNow: new Date("2026-07-20T01:00:00Z")});
    await service.execute({commandId: "a", commandType: "acknowledgeLane", aggregateId: "wf1", expectedVersion: 1, payload: {laneKey: "elec"}}, {actor: electrical, serverNow: new Date("2026-07-20T01:01:00Z")});
    const r = await service.execute({commandId: "r", commandType: "removeLane", aggregateId: "wf1", expectedVersion: 2, payload: {laneKey: "elec", reason: "Incorrect classification"}}, {actor: admin, serverNow: new Date("2026-07-20T01:02:00Z")});
    equal(r.resultKey, "workflow-requires-reclassification", "should require reclassification");
    equal(store.read("maintenance_workflows/wf1")?.status, "pendingLaneClassification", "status mismatch");
  });
  await test("Condition confirmation complies request and reactivates linked item", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, "wf1", "awaitingCompliance", 3);
    store.seed("maintenance_records/m1", {version: 1, workflowQueueState: "deferred", workflowDeferred: true});
    store.seed("compliance_requests/c1", {linkedWorkflowId: "wf1", linkedMaintenanceFirestoreId: "m1", targetLaneKey: "elec", status: "acknowledged", conditionTypeKey: "chargeComplete", version: 1});
    const service = serviceFor(store);
    const r = await service.execute({commandId: "due", commandType: "confirmConditionAndReactivate", aggregateId: "wf1", expectedVersion: 3, payload: {complianceId: "c1"}}, {actor: ops, serverNow: new Date("2026-07-20T02:00:00Z")});
    equal(r.resultKey, "condition-confirmed-work-reactivated", "result mismatch");
    equal(store.read("compliance_requests/c1")?.status, "complied", "compliance should be complied");
    equal(store.read("maintenance_records/m1")?.workflowQueueState, "actionable", "maintenance item should be actionable");
  });
  await test("Accepted counter supersedes original and creates acknowledged successor", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, "wf1", "awaitingCompliance", 4);
    store.seed("compliance_requests/c1", {linkedWorkflowId: "wf1", originLaneKey: "elec", targetLaneKey: "oprn", status: "acknowledged", counterDepth: 0, counterProposal: {revisedDescription: "After crane release", proposedByUid: "ops-1", proposedByName: "ops-1"}, version: 2});
    const service = serviceFor(store);
    const r = await service.execute({commandId: "dec", commandType: "decideCounterCondition", aggregateId: "wf1", expectedVersion: 4, payload: {complianceId: "c1", accepted: true, successorComplianceId: "c2"}}, {actor: electrical, serverNow: new Date("2026-07-20T03:00:00Z")});
    equal(r.resultKey, "counter-condition-accepted", "result mismatch");
    equal(store.read("compliance_requests/c1")?.status, "superseded", "original should be superseded");
    equal(store.read("compliance_requests/c2")?.status, "acknowledged", "successor should be acknowledged");
  });


  await test("Senior authority can close an acknowledged OPRN lane", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store);
    const service = serviceFor(store);
    await service.execute({commandId: "fc", commandType: "finalizeLaneSet", aggregateId: "wf1", expectedVersion: 0, payload: {laneKeys: ["oprn"]}}, {actor: admin, serverNow: new Date("2026-07-20T04:00:00Z")});
    await service.execute({commandId: "ac", commandType: "acknowledgeLane", aggregateId: "wf1", expectedVersion: 1, payload: {laneKey: "oprn"}}, {actor: ops, serverNow: new Date("2026-07-20T04:01:00Z")});
    const receipt = await service.execute({commandId: "cc", commandType: "closeLane", aggregateId: "wf1", expectedVersion: 2, payload: {laneKey: "oprn", note: "Operations preparation completed"}}, {actor: admin, serverNow: new Date("2026-07-20T04:02:00Z")});
    equal(receipt.resultKey, "lane-closed", "close result mismatch");
  });

  await test("Returned compliance preserves the attempt and re-defers linked work", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, "wf1", "inProgress", 5);
    store.seed("maintenance_records/m2", {version: 2, workflowQueueState: "actionable", workflowDeferred: false});
    store.seed("compliance_requests/c3", {linkedWorkflowId: "wf1", linkedMaintenanceFirestoreId: "m2", originLaneKey: "elec", targetLaneKey: "oprn", status: "complied", version: 3, correctionCount: 0});
    const service = serviceFor(store);
    const receipt = await service.execute({commandId: "corr", commandType: "returnComplianceForCorrection", aggregateId: "wf1", expectedVersion: 5, payload: {complianceId: "c3", reason: "Furnace is not correctly positioned"}}, {actor: electrical, serverNow: new Date("2026-07-20T05:00:00Z")});
    equal(receipt.resultKey, "compliance-returned-for-correction", "correction result mismatch");
    equal(store.read("compliance_requests/c3")?.status, "acknowledged", "request should return to acknowledged");
    equal(store.read("maintenance_records/m2")?.workflowQueueState, "deferred", "linked work should be deferred again");
  });

  await test("Force cooler finalisation closes without a RED question", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, "wf1", "readyForClosure", 7);
    store.seed("maintenance_workflows/wf1", {jobExecutionId: "wf1-exec", status: "readyForClosure", version: 7, assetTypeKey: "forceCooler", assetNumber: 2, laneSetFinalizedAt: "2026-07-20T00:00:00Z", cancelled: false});
    store.seed("job_lanes/wf1_mech_1", {workflowId: "wf1", jobExecutionId: "wf1-exec", laneKey: "mech", status: "closed", activationGeneration: 1, version: 2});
    store.seed("equipment_status/forceCooler_2", {state: "underMaintenance", activeNonRedMaintenanceCount: 1, activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 1});
    const service = serviceFor(store);
    const receipt = await service.execute({commandId: "final-fc", commandType: "finalizeJob", aggregateId: "wf1", expectedVersion: 7, payload: {}}, {actor: admin, serverNow: new Date("2026-07-20T06:00:00Z")});
    equal(receipt.resultKey, "workflow-finalized", "finalise result mismatch");
    equal(store.read("equipment_status/forceCooler_2")?.state, "available", "force cooler should become available");
  });

  await test("Furnace RED successor is created with an Operations preparation gate", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, "wf1", "readyForClosure", 8);
    store.seed("maintenance_workflows/wf1", {jobExecutionId: "wf1-exec", status: "readyForClosure", version: 8, assetTypeKey: "furnace", assetNumber: 7, laneSetFinalizedAt: "2026-07-20T00:00:00Z", cancelled: false});
    store.seed("job_lanes/wf1_mech_1", {workflowId: "wf1", jobExecutionId: "wf1-exec", laneKey: "mech", status: "closed", activationGeneration: 1, version: 2});
    store.seed("equipment_status/furnace_7", {state: "underMaintenance", activeNonRedMaintenanceCount: 1, activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 2});
    const service = serviceFor(store);
    const receipt = await service.execute({commandId: "final-red", commandType: "finalizeJob", aggregateId: "wf1", expectedVersion: 8, payload: {redRequired: true, preparationRequired: true, redSuccessorWorkflowId: "wf-red", redSuccessorExecutionId: "exec-red", redTemplatePackageId: "pkg-red", redTemplateVersionId: "ver-red", redTemplateContentHash: "hash-red"}}, {actor: admin, serverNow: new Date("2026-07-20T07:00:00Z")});
    equal(receipt.resultKey, "workflow-finalized", "RED finalise result mismatch");
    equal(store.read("equipment_status/furnace_7")?.state, "awaitingPreparation", "furnace should await preparation");
    equal(store.read("maintenance_workflows/wf-red")?.status, "awaitingCompliance", "RED successor should be gated");
    equal(store.read("compliance_requests/wf-red_preparation")?.targetLaneKey, "oprn", "Operations should own preparation");
  });

  await test("Workflow cancellation provides an exit for a void job", async () => {
    const store = new MemoryWorkflowStore(); seedWorkflow(store, "wf1", "assigned", 2);
    const service = serviceFor(store);
    const receipt = await service.execute({commandId: "cancel", commandType: "cancelWorkflow", aggregateId: "wf1", expectedVersion: 2, payload: {reason: "Raised against the wrong equipment"}}, {actor: admin, serverNow: new Date("2026-07-20T08:00:00Z")});
    equal(receipt.resultKey, "workflow-cancelled", "cancel result mismatch");
    equal(store.read("maintenance_workflows/wf1")?.status, "cancelled", "workflow should be cancelled");
  });


  await test("Preselected base RED becomes active in situ and can then be acknowledged", async () => {
    const store = new MemoryWorkflowStore();
    store.seed("maintenance_workflows/wf-base", {jobExecutionId: "exec-base", status: "inProgress", version: 3, assetTypeKey: "base", assetNumber: 4, laneSetFinalizedAt: "2026-07-20T00:00:00Z", activeRedWork: false, awaitingPreparation: false});
    store.seed("job_lanes/wf-base_mech_1", {workflowId: "wf-base", jobExecutionId: "exec-base", laneKey: "mech", status: "closed", activationGeneration: 1, version: 2});
    store.seed("job_lanes/wf-base_red_1", {workflowId: "wf-base", jobExecutionId: "exec-base", laneKey: "red", status: "pending", activationGeneration: 1, version: 1});
    store.seed("equipment_status/base_4", {state: "underMaintenance", activeNonRedMaintenanceCount: 1, activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 1});
    const service = serviceFor(store);
    const prepared = await service.execute({commandId: "prepare-base", commandType: "prepareRedLane", aggregateId: "wf-base", expectedVersion: 3, payload: {}}, {actor: admin, serverNow: new Date("2026-07-20T09:00:00Z")});
    equal(prepared.resultKey, "red-ready-for-work", "base RED should be released in situ");
    equal(store.read("equipment_status/base_4")?.state, "underRED", "base should be under RED");
    const acknowledged = await service.execute({commandId: "ack-base-red", commandType: "acknowledgeLane", aggregateId: "wf-base", expectedVersion: 4, payload: {laneKey: "red"}}, {actor: refractory, serverNow: new Date("2026-07-20T09:01:00Z")});
    equal(acknowledged.resultKey, "lane-acknowledged", "RED acknowledgement should succeed after release");
  });

  await test("Preselected furnace RED is gated until Operations preparation is confirmed", async () => {
    const store = new MemoryWorkflowStore();
    store.seed("maintenance_workflows/wf-pre-red", {jobExecutionId: "exec-pre-red", status: "inProgress", version: 3, assetTypeKey: "furnace", assetNumber: 8, laneSetFinalizedAt: "2026-07-20T00:00:00Z", activeRedWork: false, awaitingPreparation: false});
    store.seed("job_lanes/wf-pre-red_mech_1", {workflowId: "wf-pre-red", jobExecutionId: "exec-pre-red", laneKey: "mech", status: "closed", activationGeneration: 1, version: 2});
    store.seed("job_lanes/wf-pre-red_red_1", {workflowId: "wf-pre-red", jobExecutionId: "exec-pre-red", laneKey: "red", status: "pending", activationGeneration: 1, version: 1});
    store.seed("equipment_status/furnace_8", {state: "underMaintenance", activeNonRedMaintenanceCount: 1, activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 1});
    const service = serviceFor(store);
    await service.execute({commandId: "prepare-furnace", commandType: "prepareRedLane", aggregateId: "wf-pre-red", expectedVersion: 3, payload: {preparationRequired: true}}, {actor: admin, serverNow: new Date("2026-07-20T10:00:00Z")});
    equal(store.read("equipment_status/furnace_8")?.state, "awaitingPreparation", "furnace should await preparation");
    let denied = false;
    try {
      await service.execute({commandId: "early-ack-red", commandType: "acknowledgeLane", aggregateId: "wf-pre-red", expectedVersion: 4, payload: {laneKey: "red"}}, {actor: refractory, serverNow: new Date("2026-07-20T10:01:00Z")});
    } catch (error) {
      denied = error instanceof WorkflowError && (error.code === "red-preparation-incomplete" || error.code === "blocking-compliance-open");
    }
    assert(denied, "RED acknowledgement must be denied before preparation confirmation");
    await service.execute({commandId: "ack-prep", commandType: "acknowledgeCompliance", aggregateId: "wf-pre-red", expectedVersion: 4, payload: {complianceId: "wf-pre-red_red_preparation"}}, {actor: ops, serverNow: new Date("2026-07-20T10:02:00Z")});
    await service.execute({commandId: "comply-prep", commandType: "markComplianceComplied", aggregateId: "wf-pre-red", expectedVersion: 5, payload: {complianceId: "wf-pre-red_red_preparation", note: "Furnace placed on stand"}}, {actor: ops, serverNow: new Date("2026-07-20T10:03:00Z")});
    const released = await service.execute({commandId: "confirm-prep", commandType: "confirmComplianceClosed", aggregateId: "wf-pre-red", expectedVersion: 6, payload: {complianceId: "wf-pre-red_red_preparation", note: "Stand placement verified"}}, {actor: refractory, serverNow: new Date("2026-07-20T10:04:00Z")});
    equal(released.resultKey, "red-preparation-confirmed", "preparation should release RED");
    equal(store.read("equipment_status/furnace_8")?.state, "underRED", "furnace should become under RED");
    equal(store.read("job_lanes/wf-pre-red_red_1")?.gatingComplianceRequestId, null, "RED gate should be cleared");
    const ack = await service.execute({commandId: "ack-red-after-prep", commandType: "acknowledgeLane", aggregateId: "wf-pre-red", expectedVersion: 7, payload: {laneKey: "red"}}, {actor: refractory, serverNow: new Date("2026-07-20T10:05:00Z")});
    equal(ack.resultKey, "lane-acknowledged", "RED acknowledgement should succeed after preparation");
  });

  await test("Finalising one job preserves other open maintenance on the equipment", async () => {
    const store = new MemoryWorkflowStore();
    store.seed("maintenance_workflows/wf-final", {jobExecutionId: "exec-final", status: "readyForClosure", version: 4, assetTypeKey: "furnace", assetNumber: 11, laneSetFinalizedAt: "2026-07-20T00:00:00Z"});
    store.seed("job_lanes/wf-final_mech_1", {workflowId: "wf-final", jobExecutionId: "exec-final", laneKey: "mech", status: "closed", activationGeneration: 1, version: 2});
    store.seed("job_executions/exec-final", {version: 1, isCompleted: false});
    store.seed("maintenance_workflows/wf-other", {jobExecutionId: "exec-other", status: "inProgress", version: 2, assetTypeKey: "furnace", assetNumber: 11, activeRedWork: false, awaitingPreparation: false});
    store.seed("equipment_status/furnace_11", {state: "underMaintenance", activeNonRedMaintenanceCount: 2, activeRedWorkCount: 0, awaitingPreparationCount: 0, version: 3});
    const service = serviceFor(store);
    const receipt = await service.execute({commandId: "final-multi", commandType: "finalizeJob", aggregateId: "wf-final", expectedVersion: 4, payload: {redRequired: false}}, {actor: admin, serverNow: new Date("2026-07-20T11:00:00Z")});
    equal(receipt.resultKey, "workflow-finalized", "finalization result mismatch");
    equal(store.read("equipment_status/furnace_11")?.state, "underMaintenance", "other open job must keep equipment under maintenance");
    equal(store.read("equipment_status/furnace_11")?.activeNonRedMaintenanceCount, 1, "other job count must be preserved");
  });

  await test("Equipment projection reports active RED when another workflow awaits preparation", () => {
    const projection = deriveEquipmentState({activeNonRedMaintenanceCount: 0, activeRedWorkCount: 1, awaitingPreparationCount: 1, operationsDeployed: false});
    equal(projection.state, "underRED", "physical active RED state should take precedence across workflows");
    equal(projection.conflicts, [], "parallel pending preparation should not create a false projection conflict");
  });

  console.log(`SUMMARY passed=${passed} failed=${failed}`);
  if (failed > 0) throw new Error(`${failed} test(s) failed.`);
})();
