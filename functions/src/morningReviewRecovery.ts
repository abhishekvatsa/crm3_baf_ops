import {AssetHierarchyMutationError} from "./assetHierarchyMutation";
import {canonicalApprovedUserAuthority} from "./userAuthority";
import {stableJson} from "./stableJson";
import type {MorningReviewFirestoreLike, MorningReviewMutationResult} from "./morningReviewMutation";

type JsonMap = {[key: string]: unknown};
type Transaction = Parameters<Parameters<MorningReviewFirestoreLike["runTransaction"]>[0]>[0];
const REFUSALS = "morning_review_refusals";

function refusalError(proof: JsonMap, request: JsonMap, actorUid: string): AssetHierarchyMutationError {
  if (proof.schemaVersion !== 1 || proof.actorUid !== actorUid ||
      stableJson(proof.request) !== stableJson(request) ||
      typeof proof.message !== "string" || typeof proof.refusedAt !== "string" ||
      !["aborted", "failed-precondition", "already-exists", "not-found"].includes(String(proof.code))) {
    return new AssetHierarchyMutationError("data-loss", "The saved refusal does not match this exact request.");
  }
  return new AssetHierarchyMutationError(proof.code as AssetHierarchyMutationError["code"], proof.message,
    {reasonCode: proof.reasonCode, morningReviewRefusal: proof});
}

/** Every business attempt reads this fence in its acceptance transaction. */
export async function assertMorningReviewNotRefused(
  db: MorningReviewFirestoreLike, tx: Transaction, request: JsonMap, actorUid: string,
): Promise<void> {
  const row = await tx.get(db.collection(REFUSALS).doc(String(request.requestId)));
  if ("exists" in row && row.exists) throw refusalError(row.data() ?? {}, request, actorUid);
}

/** Serialize an ordinary refusal against in-flight acceptance. Receipt wins;
 * otherwise a permanent fence prevents every late/retried original execution.
 * Transport errors and malformed data never become proof of non-execution. */
export async function executeMorningReviewWithRefusalFence(args: {
  db: MorningReviewFirestoreLike; actorUid: string; request: JsonMap;
  execute: () => Promise<MorningReviewMutationResult>;
  accepted: (receipt: JsonMap) => MorningReviewMutationResult;
  now: () => Date;
}): Promise<MorningReviewMutationResult> {
  try { return await args.execute(); } catch (error) {
    if (!(error instanceof AssetHierarchyMutationError) ||
        !["aborted", "failed-precondition", "already-exists", "not-found"].includes(error.code)) throw error;
    const decision = await args.db.runTransaction(async (tx) => {
      const actor = await tx.get(args.db.collection("users").doc(args.actorUid));
      if (!("exists" in actor) || !canonicalApprovedUserAuthority(actor.data())) throw error;
      const receipt = await tx.get(args.db.collection("morning_review_mutation_receipts").doc(String(args.request.requestId)));
      const ref = args.db.collection(REFUSALS).doc(String(args.request.requestId));
      const prior = await tx.get(ref);
      if ("exists" in receipt && receipt.exists) return {accepted: args.accepted(receipt.data() ?? {})};
      if ("exists" in prior && prior.exists) return {refused: prior.data() ?? {}};
      const proof = {schemaVersion: 1, actorUid: args.actorUid, request: args.request,
        code: error.code, reasonCode: (error.details as JsonMap | undefined)?.reasonCode ?? "morning-review-business-refused",
        message: error.message, refusedAt: args.now().toISOString()};
      tx.set(ref, proof); // No TTL: this identity must never execute later.
      return {refused: proof};
    });
    if (decision.accepted != null) return decision.accepted;
    throw refusalError(decision.refused!, args.request, args.actorUid);
  }
}
