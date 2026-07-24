import {Actor, JsonMap, LaneKey} from "./types";
import {eventRepresentation} from "./authority";
import {iso} from "./utils";

export interface WorkflowEventPlan {
  readonly path: string;
  readonly data: JsonMap;
}

export const eventPlan = (args: {
  aggregateId: string;
  eventId: string;
  eventType: string;
  actor: Actor;
  at: Date;
  commandId: string;
  laneKey?: LaneKey;
  payload?: JsonMap;
}): WorkflowEventPlan => {
  const representation = args.laneKey == null
    ? {representedLaneKey: null, delegationBasis: null}
    : eventRepresentation(args.actor, args.laneKey);
  return {
    path: `maintenance_workflow_events/${args.eventId}`,
    data: {
      aggregateId: args.aggregateId,
      eventType: args.eventType,
      actorUid: args.actor.uid,
      actorName: args.actor.name,
      actorRoles: [...args.actor.roles].sort(),
      laneKey: args.laneKey ?? null,
      representedLaneKey: representation.representedLaneKey,
      delegationBasis: representation.delegationBasis,
      commandId: args.commandId,
      occurredAt: iso(args.at),
      payload: args.payload ?? {},
    },
  };
};
