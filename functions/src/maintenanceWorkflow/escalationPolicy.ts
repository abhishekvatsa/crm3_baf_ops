export const MAX_ESCALATION_TIER = 3;

// The sweep runs every 15 minutes. A 20-minute guard absorbs ordinary
// scheduler jitter and prevents the same tier from being emitted twice by
// overlapping or delayed invocations.
export const ESCALATION_SUPPRESSION_MINUTES = 20;

export const nextEscalationTier = (args: {
  currentTier: number;
  lastEscalatedAtMillis: number | null;
  nowMillis: number;
}): number | null => {
  const currentTier = Math.max(0, Math.trunc(args.currentTier));
  if (currentTier >= MAX_ESCALATION_TIER) return null;
  if (
    args.lastEscalatedAtMillis != null &&
    args.nowMillis - args.lastEscalatedAtMillis <
      ESCALATION_SUPPRESSION_MINUTES * 60 * 1000
  ) {
    return null;
  }
  return Math.min(MAX_ESCALATION_TIER, currentTier + 1);
};

/**
 * Returns the next time a non-terminal source row should be eligible for the
 * scheduler. Tier 3 is terminal and is deliberately removed from future sweep
 * queries by storing null.
 */
export const nextEscalationAtMillis = (args: {
  nextTier: number;
  nowMillis: number;
}): number | null =>
  args.nextTier >= MAX_ESCALATION_TIER
    ? null
    : args.nowMillis + ESCALATION_SUPPRESSION_MINUTES * 60 * 1000;

export const escalationEventType = (
  collectionId: string,
  status: string,
): string => {
  if (collectionId === "job_lanes") return "lane.escalated";
  if (status === "raised") return "compliance.acknowledgementEscalated";
  return "compliance.completionEscalated";
};

export const escalationEventId = (args: {
  collectionId: string;
  documentId: string;
  tier: number;
}): string =>
  `escalation_${args.collectionId}_${args.documentId}_tier_${args.tier}`;
