import {RED_APPLICABLE_ASSET_TYPES, STAND_PREPARATION_ASSET_TYPES} from "./policy.generated";
import {JsonMap} from "./types";

export type RedExitAction =
  | "notApplicable" | "promptRedRequirement" | "promptPreparationRequirement"
  | "closeWithoutRED" | "createREDSuccessor" | "createREDSuccessorAwaitingPreparation";

export interface RedExitInput {
  readonly assetTypeKey: string;
  readonly wouldCompleteParent: boolean;
  readonly redAlreadyInWorkflow: boolean;
  readonly redRequired: boolean | null;
  readonly preparationRequired: boolean | null;
}

export interface RedExitDecision {readonly action: RedExitAction; readonly details: JsonMap;}

export const evaluateRedExit = (input: RedExitInput): RedExitDecision => {
  if (!input.wouldCompleteParent) return {action: "notApplicable", details: {reason: "parent-not-ready"}};
  if (!RED_APPLICABLE_ASSET_TYPES.has(input.assetTypeKey)) {
    return {action: "notApplicable", details: {reason: "asset-not-red-applicable"}};
  }
  if (input.redAlreadyInWorkflow) return {action: "notApplicable", details: {reason: "red-preselected"}};
  if (input.redRequired == null) return {action: "promptRedRequirement", details: {}};
  if (input.redRequired === false) return {action: "closeWithoutRED", details: {}};
  const asksPreparation = STAND_PREPARATION_ASSET_TYPES.has(input.assetTypeKey);
  if (asksPreparation && input.preparationRequired == null) {
    return {action: "promptPreparationRequirement", details: {}};
  }
  if (asksPreparation && input.preparationRequired === true) {
    return {action: "createREDSuccessorAwaitingPreparation", details: {}};
  }
  return {action: "createREDSuccessor", details: {}};
};
