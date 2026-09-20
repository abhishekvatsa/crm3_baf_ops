import {AssetHierarchyMutationError} from "./assetHierarchyMutation";
import type {MorningReviewFirestoreLike} from "./morningReviewMutation";
type JsonMap = {[key: string]: unknown};
type Tx = Parameters<Parameters<MorningReviewFirestoreLike["runTransaction"]>[0]>[0];
type Ref = ReturnType<ReturnType<MorningReviewFirestoreLike["collection"]>["doc"]>;
type Write = {ref: Ref; data?: JsonMap; options?: JsonMap};
const MEMBERS = ["morning_review_entries", "morning_review_participants", "morning_review_concern_checks", "morning_review_actions"];

/** New-reader meetings retain unfinished minutes. The server-only membership
 * manifest is independent of the children, so missing content cannot certify
 * a complete frozen document. Legacy populations are never guessed/backfilled. */
export async function protectMorningReviewPopulation(args: {
  db: MorningReviewFirestoreLike; tx: Tx; writes: Write[];
  creatingSession: string | null;
}): Promise<void> {
  const sessions = args.writes.filter((write) => write.ref.path === `morning_review_sessions/${write.ref.id}`);
  for (const sessionWrite of sessions) {
    const id = sessionWrite.ref.id;
    const manifestRef = args.db.collection("morning_review_population_manifests").doc(id);
    const existing = await args.tx.get(manifestRef);
    const hasManifest = "exists" in existing && existing.exists;
    if (!hasManifest && args.creatingSession !== id) continue;
    const old = hasManifest && "exists" in existing ? existing.data() ?? {} : {};
    if (hasManifest && (old.schemaVersion !== 1 || old.sessionId !== id)) {
      throw new AssetHierarchyMutationError("data-loss", "The meeting membership manifest is malformed.");
    }
    const members: JsonMap = {};
    for (const collection of MEMBERS) {
      const ids = hasManifest ? (old.members as JsonMap | undefined)?.[collection] : [];
      if (!Array.isArray(ids) || ids.some((value) => typeof value !== "string") || new Set(ids).size !== ids.length) {
        throw new AssetHierarchyMutationError("data-loss", "The meeting membership manifest is incomplete.");
      }
      const added = args.writes.filter((write) => write.ref.path === `${collection}/${write.ref.id}` && write.data?.sessionId === id).map((write) => write.ref.id);
      members[collection] = [...new Set([...ids, ...added])].sort();
    }
    const current = await args.tx.get(sessionWrite.ref);
    const status = sessionWrite.data?.status ?? ("exists" in current ? current.data()?.status : null);
    if (status === "open") {
      sessionWrite.data = {...sessionWrite.data, expiresAt: null};
      for (const write of args.writes) {
        if (write.data?.sessionId === id && MEMBERS.filter((collection) => collection !== "morning_review_actions").some((collection) => write.ref.path === `${collection}/${write.ref.id}`)) {
          write.data = {...write.data, expiresAt: null};
        }
      }
    }
    args.writes.push({ref: manifestRef, data: {schemaVersion: 1, sessionId: id, members}});
  }
}

export async function requireMorningReviewPopulation(args: {
  db: MorningReviewFirestoreLike; tx: Tx; sessionId: string;
  entries: readonly {id: string}[]; participants: readonly {id: string}[]; checks: readonly {id: string}[];
  actions: readonly {id: string}[];
}): Promise<boolean> {
  const snapshot = await args.tx.get(args.db.collection("morning_review_population_manifests").doc(args.sessionId));
  if (!("exists" in snapshot) || !snapshot.exists) return false;
  const manifest = snapshot.data() ?? {};
  const populations = [args.entries, args.participants, args.checks, args.actions];
  if (manifest.schemaVersion !== 1 || manifest.sessionId !== args.sessionId || MEMBERS.some((collection, index) => {
    const expected = (manifest.members as JsonMap | undefined)?.[collection];
    const actual = populations[index].map((row) => row.id);
    return !Array.isArray(expected) || expected.length !== actual.length || new Set(expected).size !== expected.length || expected.some((id) => !actual.includes(String(id)));
  })) {
    throw new AssetHierarchyMutationError("data-loss", "The original meeting population is incomplete. Restore the missing evidence before finalization.",
      {reasonCode: "morning-review-population-incomplete"});
  }
  return true;
}
