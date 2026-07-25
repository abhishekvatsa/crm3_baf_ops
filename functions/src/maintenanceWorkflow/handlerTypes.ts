import {WorkflowTransaction} from "./store";
import {CommandContext, JsonMap, WorkflowCommand} from "./types";

export interface HandlerResult {
  readonly resultKey: string;
  readonly aggregateVersion: number;
  readonly result: JsonMap;
}

export interface HandlerArgs {
  readonly tx: WorkflowTransaction;
  readonly command: WorkflowCommand;
  readonly context: CommandContext;
}

export type CommandHandler = (args: HandlerArgs) => Promise<HandlerResult>;
