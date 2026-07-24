import {LANE_POLICY} from "./policy.generated";

const escalationRoles = (
  laneKey: string | null,
  tier: number,
): string[] => {
  if (tier >= 3) return ["admin"];
  if (tier >= 2) return ["shiftSupervisor", "si"];

  if (laneKey == null) return ["si"];
  const lane = LANE_POLICY[laneKey];
  if (lane == null) return ["si"];

  // Tier 1 is the lane's senior tier. Admin/SI are deliberately excluded
  // here because the ratified ladder reaches SI at Tier 2 and Admin at Tier 3.
  const senior = lane.closeRoles.filter(
    (role) => role !== "admin" && role !== "si",
  );
  return senior.length > 0 ? [...new Set(senior)] : ["si"];
};

/**
 * Resolves workflow notification recipients from the same generated lane
 * authority policy used by command handling. Ordinary workflow events go to
 * the relevant action roles. Escalation events follow the ratified tier
 * ladder instead of notifying every supervisory role at the first overdue
 * sweep.
 */
export const workflowRecipientRoles = (
  eventType: string,
  laneKey: string | null,
  escalationTier?: number | null,
): string[] => {
  const isEscalation = eventType.endsWith("Escalated") ||
    eventType === "lane.escalated";
  if (isEscalation) {
    return escalationRoles(laneKey, Math.max(1, Number(escalationTier ?? 1)));
  }

  const roles = new Set<string>(["admin", "si"]);

  if (eventType.startsWith("equipment.")) {
    roles.add("shiftSupervisor");
    roles.add("operations");
    return [...roles];
  }

  if (laneKey != null) {
    const lane = LANE_POLICY[laneKey];
    if (lane != null) {
      for (const role of lane.ackRoles) roles.add(role);
      for (const role of lane.workRoles) roles.add(role);
      for (const role of lane.closeRoles) roles.add(role);
    }
  }
  return [...roles];
};
