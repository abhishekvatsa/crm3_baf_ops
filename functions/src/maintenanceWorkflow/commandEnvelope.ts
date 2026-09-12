import {WorkflowError} from "./errors";
import {WorkflowCommand} from "./types";

/** A command identity is one document segment, never a caller-supplied path. */
export const assertWorkflowDocumentId = (value: unknown, field: string): void => {
  if (typeof value !== "string" || value.length === 0 ||
      value !== value.trim() || value === "." || value === ".." ||
      value.includes("/") || /[\u0000-\u001f\u007f]/.test(value) ||
      Buffer.byteLength(value, "utf8") > 1500) {
    throw new WorkflowError(
      "invalid-argument", `${field} must be a non-empty document identifier.`,
      {reasonCode: "workflow-command-identity-invalid", field},
    );
  }
};

/** Validate before constructing receipt, audit or aggregate document paths. */
export const assertWorkflowCommandEnvelope = (command: WorkflowCommand): void => {
  if (command == null || typeof command !== "object" || Array.isArray(command)) {
    throw new WorkflowError("invalid-argument", "Workflow command must be an object.");
  }
  assertWorkflowDocumentId(command.commandId, "commandId");
  assertWorkflowDocumentId(command.aggregateId, "aggregateId");
  if (!Number.isSafeInteger(command.expectedVersion) || command.expectedVersion < 0 ||
      command.payload == null || typeof command.payload !== "object" ||
      Array.isArray(command.payload) || typeof command.commandType !== "string") {
    throw new WorkflowError("invalid-argument", "Workflow command envelope is invalid.");
  }
};
