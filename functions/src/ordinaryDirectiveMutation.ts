import {createHash} from "crypto";
import {AssetHierarchyMutationError, AssetHierarchyMutationFirestoreLike} from "./assetHierarchyMutation";
import {canonicalApprovedUserAuthority} from "./userAuthority";
import {persistedInstantMillis} from "./persistedInstant";
import {stableJson} from "./stableJson";
import {
  PILOT_PURGE_MANIFEST_COLLECTION,
  pilotPurgeReceiptId,
} from "./pilotRecordPurge";

type MapValue = {[key: string]: unknown};
export const ORDINARY_DIRECTIVE_OPERATION = "APPLY_ORDINARY_DIRECTIVE";
export const userCanMutateOrdinaryDirective = (data: unknown): boolean => canonicalApprovedUserAuthority(data) !== null;
export const isOrdinaryDirectiveOperation = (value: unknown): boolean => value === ORDINARY_DIRECTIVE_OPERATION;
const fields = ("firestoreId title description assetType assetNumber component subsystem tag hierarchyPath directedTo status priority createdByUid createdByName issuedByUid issuedByName issuedAt isActive acknowledgedByUid acknowledgedByName acknowledgedAt closedByUid closedByName closedAt closedWithoutAcknowledgement remarks linkedMaintenanceFirestoreId linkedExecutionFirestoreId metadataJson isDeleted deletedAt deletedByUid deletedByName deleteReason createdAt updatedAt version").split(" ");
const optional = new Set(("assetType assetNumber component subsystem tag hierarchyPath createdByName issuedByName issuedAt acknowledgedByUid acknowledgedByName acknowledgedAt closedByUid closedByName closedAt remarks linkedMaintenanceFirestoreId linkedExecutionFirestoreId metadataJson deletedAt deletedByUid deletedByName deleteReason").split(" "));
const dates = new Set(["createdAt", "updatedAt", "issuedAt", "acknowledgedAt", "closedAt", "deletedAt"]);
const roles = ["admin", "si", "contractSupervisor", "shiftSupervisor", "operations", "seniorElectrical", "seniorMechanical", "seniorInstrumentation", "seniorRefractory", "refractory"];
const content = ("title description directedTo priority assetType assetNumber component subsystem tag hierarchyPath remarks linkedMaintenanceFirestoreId linkedExecutionFirestoreId metadataJson").split(" ");
const plain = (v: unknown): v is MapValue => v != null && typeof v === "object" && !Array.isArray(v);
const text = (v: unknown): v is string => typeof v === "string" && v.trim().length > 0 && v.length <= 20000;
const fail = (reason: string, message: string, code: "invalid-argument"|"permission-denied"|"aborted"|"data-loss"|"failed-precondition" = "invalid-argument"): never => {
  throw new AssetHierarchyMutationError(code, message, {reasonCode: reason});
};
const hash = (v: unknown): string => createHash("sha256").update(stableJson(v)).digest("hex");
function canonicalTime(value: unknown): string {
 const millis=persistedInstantMillis(value);
 if(!Number.isFinite(millis))return fail("directive-date-invalid", "Invalid directive date.");
 let micros=0;
 if(typeof value==="string"){
   const match=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.(\d{1,6}))?(?:Z|[+-]\d{2}:\d{2})?$/.exec(value);
   if(!match)return fail("directive-date-invalid", "Unsupported directive date representation.");
   const parts=value.slice(0,19).split(/[-T:]/).map(Number);
   const [year,month,day,hour,minute,second]=parts;
   const check=new Date(Date.UTC(year,month-1,day,hour,minute,second));
   if(year<100 || check.getUTCFullYear()!==year || check.getUTCMonth()!==month-1 || check.getUTCDate()!==day || hour>23 || minute>59 || second>59) return fail("directive-date-invalid", "Invalid calendar date.");
   micros=Number((match[1]??"").padEnd(6,"0").slice(3));
 } else if(plain(value)) {
   const nanos=value.nanoseconds??value._nanoseconds;
   if(typeof nanos==="number"){
     if(nanos%1000!==0)return fail("directive-date-invalid", "Submicrosecond evidence requires review.");
     micros=Math.floor(nanos/1000)%1000;
   }
 }
 return new Date(Math.floor(millis)).toISOString().replace(/(\.\d{3})Z$/,`$1${String(micros).padStart(3,"0")}Z`);
}
export function ordinaryDirectiveRecord(raw: unknown, id: string): MapValue {
  if (!plain(raw)) return fail("directive-record-invalid", "Directive evidence must be an object.");
  const d: MapValue = {};
  for (const field of fields) {
    const value = raw[field];
    if (value == null && !optional.has(field)) return fail("directive-record-invalid", `Missing directive ${field}.`);
    d[field] = value ?? null;
  }
  if (d.firestoreId !== id || !text(d.title) || !text(d.description) || !roles.includes(String(d.directedTo)) ||
      !["low", "medium", "high", "critical"].includes(String(d.priority)) ||
      !["open", "acknowledged", "closed"].includes(String(d.status)) ||
      !text(d.createdByUid) || d.createdByUid !== d.issuedByUid || !Number.isSafeInteger(d.version) || (d.version as number) < 1 ||
      typeof d.isDeleted !== "boolean" || typeof d.closedWithoutAcknowledgement !== "boolean" || d.isActive !== (d.status !== "closed")) {
    return fail("directive-record-invalid", "Directive identity or lifecycle is inconsistent.");
  }
  for (const field of optional) {
    if (dates.has(field) || ["assetNumber", "hierarchyPath"].includes(field)) continue;
    if (d[field] != null && !text(d[field])) return fail("directive-record-invalid", `Invalid directive ${field}.`);
  }
  for (const field of dates) {
    if (d[field] == null) continue;
    const instant = persistedInstantMillis(d[field]);
    if (!Number.isFinite(instant)) return fail("directive-date-invalid", `Invalid directive ${field}.`);
    // Preserve supported microsecond precision in the canonical UTC wire format.
    d[field] = canonicalTime(d[field]);
  }
  const created = d.createdAt as string, updated = d.updatedAt as string;
  if (updated < created || [...dates].some((f) => d[f] != null && ((d[f] as string) < created || (d[f] as string) > updated))) return fail("directive-chronology-invalid", "Directive event times disagree.");
  if (d.assetType == null ? d.assetNumber != null : !Number.isSafeInteger(d.assetNumber)) return fail("directive-asset-invalid", "Asset type and number must be supplied together.");
  const n = d.assetNumber as number;
  if (d.assetType != null && !(d.assetType === "base" ? (n >= 101 && n <= 124 || n >= 201 && n <= 223) :
    d.assetType === "furnace" ? n >= 1 && n <= 26 : d.assetType === "forceCooler" ? n >= 1 && n <= 25 :
      d.assetType === "innerCover" ? n > 0 : d.assetType === "governedCustom" && n >= 1 && n <= 9999)) return fail("directive-asset-invalid", "Asset context is outside the supported range.");
  if (d.hierarchyPath != null && (!Array.isArray(d.hierarchyPath) || d.hierarchyPath.some((v) => !text(v)))) return fail("directive-record-invalid", "Directive path is malformed.");
  if (d.metadataJson != null) {
    try { const metadata=JSON.parse(d.metadataJson as string); if (!plain(metadata) || metadata.trigger === "burnerConditionRoundRedHot" || metadata.kind === "burnerRedHot" || metadata.burnerRoundId != null || metadata.protocol === "burnerRedHot.v1") throw Error(); } catch (_) { return fail("directive-record-invalid", "Directive metadata is malformed."); }
  }
  const ack = d.acknowledgedAt != null, closed = d.closedAt != null;
  if (ack !== (d.acknowledgedByUid != null) || !ack && d.acknowledgedByName != null ||
      closed !== (d.closedByUid != null) || !closed && d.closedByName != null ||
      d.status === "open" && ack || d.status === "acknowledged" && !ack || closed !== (d.status === "closed") ||
      d.closedWithoutAcknowledgement !== (closed && !ack) ||
      d.isDeleted !== (d.deletedAt != null) || d.isDeleted && !text(d.deletedByUid) ||
      !d.isDeleted && ["deletedByUid", "deletedByName", "deleteReason"].some((f) => d[f] != null)) return fail("directive-lifecycle-invalid", "Directive lifecycle evidence contradicts its status.");
  return d;
}
function mayTarget(actorRoles: ReadonlySet<string>, target: string): boolean {
  if (!roles.includes(target) || target === "admin") return false;
  if (actorRoles.has("admin")) return true;
  const specialist = ["seniorElectrical", "seniorMechanical", "seniorInstrumentation", "seniorRefractory"];
  return actorRoles.has("si") && ["contractSupervisor", "shiftSupervisor", "operations", ...specialist].includes(target) ||
    actorRoles.has("contractSupervisor") && ["shiftSupervisor", "operations", ...specialist].includes(target) ||
    actorRoles.has("shiftSupervisor") && ["operations", ...specialist].includes(target) ||
    actorRoles.has("operations") && ["contractSupervisor", "shiftSupervisor", ...specialist].includes(target);
}
export type OrdinaryDirectiveResult = {ok: true; requestId: string; operation: string; entityId: string; version: number; committedAt: string; idempotentReplay: boolean; entity: MapValue};
export async function mutateOrdinaryDirectiveWithDb(args: {db: AssetHierarchyMutationFirestoreLike; authUid: string|null; data: unknown; now?:()=>Date}): Promise<OrdinaryDirectiveResult> {
  const q=args.data;
  if (!plain(q) || Object.keys(q).sort().join() !== ["requestId","operation","directiveId","expectedVersion","action","reason","before","after"].sort().join() ||
      q.operation !== ORDINARY_DIRECTIVE_OPERATION || typeof q.requestId !== "string" || !/^[a-zA-Z0-9_-]{8,128}$/.test(q.requestId) ||
      typeof q.directiveId !== "string" || !/^[a-zA-Z0-9_-]{1,160}$/.test(q.directiveId) || q.directiveId.startsWith("burner_round_") ||
      !["create","acknowledge","close","amend","delete"].includes(String(q.action)) || !text(q.reason) || (q.reason as string).length > 2000 ||
      !Number.isSafeInteger(q.expectedVersion) || (q.expectedVersion as number) < 0) return fail("directive-command-invalid", "The saved directive command is invalid.");
  const uid=args.authUid;
  if (!uid) return fail("directive-actor-required", "Sign in using the original account.", "permission-denied");
  const id=q.directiveId, requestId=q.requestId, fingerprint=hash({uid,request:q});
  const after=ordinaryDirectiveRecord(q.after,id);
  if (!plain(q.after) || Object.keys(q.after).some((f)=>!fields.includes(f))) return fail("directive-command-invalid", "Unsupported directive field.");
  const before=q.before===null?null:ordinaryDirectiveRecord(q.before,id);
  if (q.action === "create" ? before!==null || q.expectedVersion!==0 || after.version!==1 : before===null || before.version!==q.expectedVersion || after.version!==(q.expectedVersion as number)+1) return fail("directive-basis-invalid", "The directive revision does not match the saved command.");
  const receiptRef=args.db.collection("ordinary_directive_receipts").doc(requestId);
  const auditRef=args.db.collection("audit_logs").doc(`server_ordinary_directive_${requestId}`);
  const ref=args.db.collection("directives").doc(id);
  return args.db.runTransaction(async(tx)=>{
    const actorSnap=await tx.get(args.db.collection("users").doc(uid)) as {data:()=>MapValue|undefined};
    const authority=canonicalApprovedUserAuthority(actorSnap.data());
    if (!authority) return fail("directive-authority-unavailable", "Current approved authority is required.", "permission-denied");
    const receipt=await tx.get(receiptRef) as {exists:boolean;data:()=>MapValue|undefined};
    const audit=await tx.get(auditRef) as {exists:boolean;data:()=>MapValue|undefined};
    const snapshot=await tx.get(ref) as {exists:boolean;data:()=>MapValue|undefined};
    if (q.action === "create") {
      const purgeManifest = await tx.get(
        args.db.collection(PILOT_PURGE_MANIFEST_COLLECTION).doc(
          pilotPurgeReceiptId("directives", id),
        ),
      ) as {exists:boolean;data:()=>MapValue|undefined};
      if (purgeManifest.exists) {
        return fail(
          "directive-identity-permanently-removed",
          "This directive identity was permanently removed and cannot be recreated. Use a new directive identity.",
          "failed-precondition",
        );
      }
    }
    if(receipt.exists){
      const r=receipt.data()!; const a=audit.data();
      if(r.fingerprint!==fingerprint || r.actorUid!==uid) return fail("directive-request-conflict", "This request belongs to different saved evidence.", "aborted");
      if(!a || hash(a)!==r.auditSha256 || !plain(r.result) || hash(r.result)!==r.resultSha256 || r.result.requestId!==requestId || r.result.entityId!==id || !plain(r.result.entity) || stableJson(ordinaryDirectiveRecord(r.result.entity,id))!==stableJson(after)) return fail("directive-receipt-invalid", "The original acceptance evidence needs review.", "data-loss");
      return {...r.result,idempotentReplay:true} as OrdinaryDirectiveResult;
    }
    if(audit.exists) return fail("directive-audit-collision", "An audit already occupies this request identity.", "data-loss");
    const current=snapshot.exists?ordinaryDirectiveRecord(snapshot.data(),id):null;
    if(stableJson(current)!==stableJson(before)) return fail("directive-reviewed-basis-changed", "The directive changed. Keep your draft and review its current instruction before trying again.", "aborted");
    const actorRoles=authority.roles;
    const name=authority.data.name;
    if(!text(name)) return fail("directive-actor-name-required", "The approved account needs a display name.", "permission-denied");
    const changed=before===null?fields:fields.filter((f)=>stableJson(before[f])!==stableJson(after[f]));
    let allowed:string[]=[];
    if(q.action==="create"){
      if(!mayTarget(actorRoles,String(after.directedTo)) || after.createdByUid!==uid || after.createdByName!==name || after.issuedByName!==name || after.status!=="open" || after.isDeleted) return fail("directive-create-not-authorized", "This account cannot issue that instruction.", "permission-denied");
    } else {
      if(before!.isDeleted || before!.status==="closed") return fail("directive-terminal-history", "Completed/deleted instructions remain historical records.", "failed-precondition");
      allowed=["updatedAt","version"];
      if(q.action==="acknowledge"){
        if(before!.status!=="open" || !actorRoles.has(String(before!.directedTo)) || after.status!=="acknowledged" || after.acknowledgedByUid!==uid || after.acknowledgedByName!==name || after.acknowledgedAt!==after.updatedAt) return fail("directive-ack-not-authorized", "Acknowledge only the current instruction addressed to your role.", "permission-denied");
        allowed.push("status","acknowledgedByUid","acknowledgedByName","acknowledgedAt");
      }else if(q.action==="close"){
        const supervisor=["admin","si","contractSupervisor","shiftSupervisor"].some(r=>actorRoles.has(r));
        if(!(supervisor || before!.createdByUid===uid || before!.acknowledgedByUid===uid && actorRoles.has(String(before!.directedTo))) || after.status!=="closed" || after.closedByUid!==uid || after.closedByName!==name || after.closedAt!==after.updatedAt) return fail("directive-close-not-authorized", "This account cannot end the current instruction.", "permission-denied");
        allowed.push("status","isActive","closedByUid","closedByName","closedAt","closedWithoutAcknowledgement","remarks");
      }else if(q.action==="amend"){
        if(!actorRoles.has("admin") || !mayTarget(actorRoles,String(after.directedTo)) || after.status!=="open" || after.acknowledgedAt!==null) return fail("directive-amend-not-authorized", "An Admin amendment must require fresh acknowledgement.", "permission-denied");
        allowed.push(...content,"status","isActive","acknowledgedByUid","acknowledgedByName","acknowledgedAt");
      }else if(q.action==="delete"){
        if(!actorRoles.has("admin") || after.isDeleted!==true || after.deletedByUid!==uid || after.deletedByName!==name || after.deleteReason!==q.reason || after.deletedAt!==after.updatedAt) return fail("directive-delete-not-authorized", "An Admin must record the deletion reason.", "permission-denied");
        allowed.push("isDeleted","deletedAt","deletedByUid","deletedByName","deleteReason");
      }
      if(changed.some(f=>!allowed.includes(f))) return fail("directive-field-change-forbidden", "This action attempts to alter unrelated directive evidence.", "permission-denied");
    }
    const now=(args.now??(()=>new Date()))();
    if(Date.parse(after.updatedAt as string)>now.valueOf()+300000 || before && Date.parse(after.updatedAt as string)<Date.parse(before.updatedAt as string)) return fail("directive-clock-invalid", "The saved action time needs review.");
    const committedAt=now.toISOString();
    const result:OrdinaryDirectiveResult={ok:true,requestId,operation:ORDINARY_DIRECTIVE_OPERATION,entityId:id,version:after.version as number,committedAt,idempotentReplay:false,entity:after};
    const event={schemaVersion:1,entityType:"directive",entityId:id,action:q.action==="acknowledge"||q.action==="amend"?"update":q.action==="close"?"resolve":q.action,
      severity:"high",performedByUid:uid,performedByName:name,timestamp:committedAt,reason:"other",reasonNotes:q.reason,
      requestId,expectedVersion:q.expectedVersion,resultVersion:after.version,beforeJson:before===null?null:JSON.stringify(before),afterJson:JSON.stringify(after),summary:`Directive ${q.action}`};
    tx.set(ref,{...after,commandProtocol:"ordinaryDirective.v1",lastCommandId:requestId});
    tx.set(auditRef,event);
    tx.set(receiptRef,{schemaVersion:1,requestId,actorUid:uid,fingerprint,result,resultSha256:hash(result),auditSha256:hash(event)});
    return result;
  });
}
