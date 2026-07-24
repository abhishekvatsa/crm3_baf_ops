export const workflowPath = (id: string): string => `maintenance_workflows/${id}`;
export const lanePath = (workflowId: string, laneKey: string, generation = 1): string =>
  `job_lanes/${workflowId}_${laneKey}_${generation}`;
export const compliancePath = (id: string): string => `compliance_requests/${id}`;
export const complianceAttemptPath = (complianceId: string, attemptNumber: number): string =>
  `compliance_attempts/${complianceId}_${attemptNumber}`;
export const equipmentPath = (assetTypeKey: string, assetNumber: number): string =>
  `equipment_status/${assetTypeKey}_${assetNumber}`;
export const maintenancePath = (id: string): string => `maintenance_records/${id}`;
export const executionPath = (id: string): string => `job_executions/${id}`;
