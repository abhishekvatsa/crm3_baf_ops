/**
 * The persisted shape of one accountable job lane, named in a single place.
 *
 * A lane's state is stored as `status`. The client keeps its own local
 * property, `statusKey`, for the same idea, and a server consumer that reaches
 * for that name reads undefined from every real lane — refusing work the agency
 * has actually acknowledged, while a test that seeds the invented name passes.
 * Every server reader of a lane's state goes through here so the two names
 * cannot drift apart again.
 */

type LaneRecordLike = {readonly [key: string]: unknown} | null | undefined;

export const LANE_PENDING = "pending";
export const LANE_ACKNOWLEDGED = "acknowledged";
export const LANE_CLOSED = "closed";
export const LANE_REMOVED = "removed";
export const LANE_TERMINATED = "terminated";

/** A lane's persisted state, or null when the record does not carry one. */
export function persistedLaneStatus(lane: LaneRecordLike): string | null {
  const status = lane?.status;
  return typeof status === "string" && status.length > 0 ? status : null;
}

/** Whether the accountable agency has taken the lane on. */
export function laneIsAcknowledged(lane: LaneRecordLike): boolean {
  return persistedLaneStatus(lane) === LANE_ACKNOWLEDGED;
}

/**
 * Whether the lane is part of the current accountable set, rather than history
 * that a supported removal or a generation replacement has superseded.
 */
export function laneIsActive(lane: LaneRecordLike): boolean {
  const status = persistedLaneStatus(lane);
  return status !== LANE_REMOVED && status !== LANE_TERMINATED;
}
