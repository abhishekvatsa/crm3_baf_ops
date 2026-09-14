const OPERATION = /^[A-Z][A-Z_]{0,63}$/;
const DOCUMENT_ID = /^[A-Za-z0-9_.:-]{1,200}$/;
const REASON_CODE = /^[a-z0-9]+(?:-[a-z0-9]+){0,15}$/;
const FIELD_PATH = /^[A-Za-z0-9_.[\]-]{1,200}$/;

function jsonMap(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value) ?
    value as Record<string, unknown> : {};
}

/**
 * Structured fields for a refused quality-case command. The operator only sees
 * the refusal message, so the backend log keeps its reason and field.
 * Identifiers only: observations, decision reasons and names are never logged.
 */
export function governedCaseRefusalLogFields(
  requestData: unknown,
  error: {readonly code: string; readonly details?: unknown},
): Record<string, string> {
  const data = jsonMap(requestData);
  const details = jsonMap(error.details);
  const fields: Record<string, string> = {code: error.code};
  const keep = (name: string, value: unknown, pattern: RegExp): void => {
    if (typeof value === "string" && pattern.test(value)) fields[name] = value;
  };
  keep("operation", data.operation, OPERATION);
  keep("requestId", data.requestId, DOCUMENT_ID);
  keep("abnormalityId", data.abnormalityId, DOCUMENT_ID);
  keep("warningId", data.warningId, DOCUMENT_ID);
  keep("monitoringRequestId", data.monitoringRequestId, DOCUMENT_ID);
  keep("reasonCode", details.reasonCode, REASON_CODE);
  keep("causeReasonCode", details.causeReasonCode, REASON_CODE);
  keep("field", details.field, FIELD_PATH);
  return fields;
}
