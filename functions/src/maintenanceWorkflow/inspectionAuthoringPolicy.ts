import {WorkflowError} from "./errors";

export const INSPECTION_V2_AUTHORING_CAPABILITY = "inspectionReadingsV2.authoring.v1";

/** Deployment-owned opt-in, never a request/role/app-version claim. Closing it
 * stops new v2 authoring while retaining readers and existing campaign work. */
export function inspectionV2AuthoringEnabled(): boolean {
  return process.env.CRM_INSPECTION_V2_AUTHORING_ENABLED === "true";
}

export function requireInspectionV2Authoring(): void {
  if (!inspectionV2AuthoringEnabled()) {
    throw new WorkflowError(
      "failed-precondition",
      "New labelled-reading definitions and programmes are not enabled yet. Existing inspection records remain available.",
      {reasonCode: "inspection-v2-authoring-unavailable"},
    );
  }
}
