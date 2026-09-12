import {JsonMap} from "./types";

/** New verification requires technical completion, not merely a terminal ticket.
 * Historical command replay is deliberately handled before this predicate.
 */
export const isCompletedCorrectiveMaintenance = (
  ticket: JsonMap | null,
  ticketId: string,
): boolean => ticket != null &&
  ticket.firestoreId === ticketId &&
  ticket.isDeleted === false &&
  ticket.isResolved === true &&
  ticket.status === "resolved";
