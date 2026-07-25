import {
  MODULE_DISCIPLINE_LANE_MAP,
  MODULE_DISCIPLINE_SUBMIT_ROLES,
  MODULE_DISCIPLINE_WORK_ROLES,
} from "./policy.generated";
import {Actor, LaneKey, RoleKey} from "./types";
import {WorkflowTransaction} from "./store";
import {WorkflowError} from "./errors";

export type CanonicalModuleDiscipline =
  | "mechanical" | "electrical" | "instrumentation" | "operations"
  | "shiftInCharge" | "emd" | "refractory" | "safety" | "admin"
  | "shared" | "others";

const normalize = (value: unknown): string => String(value ?? "")
  .trim()
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, "");

export const canonicalModuleDiscipline = (value: unknown): CanonicalModuleDiscipline => {
  switch (normalize(value)) {
  case "mechanical": return "mechanical";
  case "electrical": return "electrical";
  case "instrumentation":
  case "instrument":
  case "ia":
  case "ianda":
  case "instrumentationautomation":
  case "instrumentationandautomation": return "instrumentation";
  case "operations":
  case "operation": return "operations";
  case "shiftincharge":
  case "shift":
  case "shiftcharge":
  case "shiftlead": return "shiftInCharge";
  case "emd": return "emd";
  case "refractory": return "refractory";
  case "safety": return "safety";
  case "admin":
  case "administration": return "admin";
  case "others":
  case "other": return "others";
  case "shared":
  case "multi":
  case "multidiscipline":
  default: return "shared";
  }
};

export const laneForModuleDiscipline = (value: unknown): LaneKey => {
  const discipline = canonicalModuleDiscipline(value);
  const lane = MODULE_DISCIPLINE_LANE_MAP[discipline];
  if (lane == null) {
    throw new WorkflowError("failed-precondition", "Module discipline has no governed workflow lane.", {
      discipline,
    });
  }
  return lane as LaneKey;
};

const hasAny = (actor: Actor, roles: readonly string[]): boolean =>
  roles.some((role) => actor.roles.has(role as RoleKey));

export const actorMayWorkModuleDiscipline = (actor: Actor, value: unknown): boolean => {
  const discipline = canonicalModuleDiscipline(value);
  return hasAny(actor, MODULE_DISCIPLINE_WORK_ROLES[discipline] ?? []);
};

export const actorMaySubmitModuleDiscipline = (actor: Actor, value: unknown): boolean => {
  const discipline = canonicalModuleDiscipline(value);
  return hasAny(actor, MODULE_DISCIPLINE_SUBMIT_ROLES[discipline] ?? []);
};


export const legacyAgencyForLane = (lane: LaneKey): string => {
  switch (lane) {
  case "elec": return "electrical";
  case "mech": return "mechanical";
  case "inst": return "instrumentation";
  case "oprn": return "operations";
  case "emd": return "emd";
  case "red": return "refractory";
  case "shared": return "shared";
  }
};

export const requiredLaneKeysForExecution = async (
  tx: WorkflowTransaction,
  executionId: string,
): Promise<readonly LaneKey[]> => {
  const rows = await tx.query("job_modules", [
    {field: "jobExecutionFirestoreId", op: "==", value: executionId},
    {field: "isDeleted", op: "==", value: false},
  ]);
  const lanes = new Set<LaneKey>();
  for (const row of rows) {
    if (row.data == null) continue;
    const lane = laneForModuleDiscipline(row.data.discipline);
    const suppliedLane = typeof row.data.laneKey === "string" ? row.data.laneKey : null;
    if (suppliedLane != null && suppliedLane !== lane) {
      throw new WorkflowError(
        "failed-precondition",
        "A module lane identity conflicts with its canonical discipline.",
        {modulePath: row.path, discipline: row.data.discipline, suppliedLane, canonicalLane: lane},
      );
    }
    lanes.add(lane);
  }
  return [...lanes].sort();
};
