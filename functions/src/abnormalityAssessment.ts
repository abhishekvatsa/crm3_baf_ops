import {isValidPersistedInstant, persistedInstantMillis} from "./persistedInstant";
type MapValue = Record<string, unknown>;
const map = (v: unknown): v is MapValue => v != null && typeof v === "object" && !Array.isArray(v);
function text(v: unknown, max: number, required = false): string | null {
  if (v == null && !required) return null;
  if (typeof v !== "string" || !v.trim() || v.length > max) throw new Error("Bounded evidence text is required.");
  return v.trim();
}
function keys(v: MapValue, allowed: string[]): void {
  if (Object.keys(v).some((key) => !allowed.includes(key))) throw new Error("Unsupported assessment field.");
}
export function normalizedAbnormalityAssessment(raw: unknown, status: unknown): MapValue | null {
  if (raw == null) return null;
  if (!map(raw) || raw.schemaVersion !== 1) throw new Error("Unsupported assessment schema.");
  keys(raw, ["schemaVersion", "observationKind", "candidateCauses", "raPerformedAt", "postRaResult", "postRaObservation"]);
  if (typeof raw.observationKind !== "string" || !["resultFinding", "processEquipment", "legacyUnknown"].includes(raw.observationKind)) throw new Error("Choose a result or process observation.");
  if (!Array.isArray(raw.candidateCauses) || raw.candidateCauses.length > 20) throw new Error("At most 20 candidate causes are supported.");
  const ids = new Set<string>();
  const causes = raw.candidateCauses.map((value) => {
    if (!map(value)) throw new Error("Malformed candidate cause.");
    keys(value, ["id", "description", "assessment", "evidence", "maintenanceTicketId", "processAbnormalityId"]);
    const id = text(value.id, 128, true)!;
    if (ids.has(id)) throw new Error("Duplicate cause identity.");
    ids.add(id);
    if (typeof value.assessment !== "string" || !["suspected", "confirmed", "ruledOut"].includes(value.assessment)) throw new Error("Choose a cause assessment.");
    const evidence = text(value.evidence, 2000, value.assessment !== "suspected");
    const maintenanceTicketId = text(value.maintenanceTicketId, 512);
    const processAbnormalityId = text(value.processAbnormalityId, 512);
    if ([maintenanceTicketId, processAbnormalityId].some((v) => v?.includes("/"))) throw new Error("Invalid linked identity.");
    return {id, description: text(value.description, 1000, true), assessment: value.assessment,
      evidence, maintenanceTicketId, processAbnormalityId};
  });
  let performedAt: string | null = null;
  if (raw.raPerformedAt != null) {
    if (!isValidPersistedInstant(raw.raPerformedAt) || status !== "completed") throw new Error("RA performed time requires completed RA.");
    performedAt = new Date(persistedInstantMillis(raw.raPerformedAt)).toISOString();
  }
  if (typeof raw.postRaResult !== "string" || !["notAssessed", "acceptable", "abnormal"].includes(raw.postRaResult)) throw new Error("Invalid post-RA result.");
  const postRaObservation = text(raw.postRaObservation, 2000, raw.postRaResult !== "notAssessed");
  if (raw.postRaResult !== "notAssessed" && status !== "completed") throw new Error("Post-RA assessment requires completed RA.");
  return {schemaVersion: 1, observationKind: raw.observationKind, candidateCauses: causes,
    raPerformedAt: performedAt, postRaResult: raw.postRaResult, postRaObservation};
}

/** New classifications cannot turn a product finding into a process cause. */
export function validateAssessmentClassification(assessment: unknown, category: unknown): void {
  if (!map(assessment) || assessment.observationKind === "legacyUnknown") return;
  const compatible = typeof category === "string" && (assessment.observationKind === "resultFinding" ?
    ["resultQuality", "reannealing"].includes(category) :
    ["process", "equipment", "other"].includes(category));
  if (!compatible) throw new Error("Choose a catalogue classification matching the observation kind.");
}

/** Read only explicitly linked records; shared charge alone never confirms cause. */
export async function validateAssessmentLinks(args: {
  assessment: unknown; sourceChargeNo: unknown; abnormalityId: string; nowMillis: number;
  read: (collection: string, id: string) => Promise<MapValue | null>;
}): Promise<void> {
  if (!map(args.assessment)) return;
  if (args.assessment.raPerformedAt != null && persistedInstantMillis(args.assessment.raPerformedAt) > args.nowMillis) {
    throw new Error("RA performed time cannot be in the future.");
  }
  for (const cause of args.assessment.candidateCauses as MapValue[]) {
    if (cause.maintenanceTicketId != null) {
      const ticket = await args.read("maintenance_records", String(cause.maintenanceTicketId));
      if (ticket == null || ticket.isDeleted === true || ticket.chargeNoAtEvent !== args.sourceChargeNo) {
        throw new Error("Linked maintenance issue must exist on this source charge.");
      }
    }
    if (cause.processAbnormalityId != null) {
      const id = String(cause.processAbnormalityId);
      const record = await args.read("charge_abnormalities", id);
      const recordAssessment = record?.assessment;
      const observation = map(recordAssessment) ? recordAssessment.observationKind : null;
      if (id === args.abnormalityId || record == null || record.isDeleted === true ||
          record.sourceChargeNo !== args.sourceChargeNo ||
          typeof record.category !== "string" ||
          !((observation === "processEquipment" && ["process", "equipment", "other"].includes(record.category)) ||
            (observation == null && ["process", "equipment"].includes(record.category)))) {
        throw new Error("Link an existing process observation on this source charge.");
      }
    }
  }
}
