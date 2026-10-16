"use strict";
// Synthetic public-source projection, not production readback, SDK execution, or IAM authority.
const assert = require("node:assert/strict");
const PROJECT = "crm3-baf-ops-b8638", REGION = "asia-south1";
const EVENT_DEFINITIONS = Object.freeze({
  onJobAssigned: ["created", "job_executions/{executionId}"],
  onMaintenanceWorkflowEventCreated: ["created", "maintenance_workflow_events/{eventId}"],
  onTicketCreated: ["created", "maintenance_records/{ticketId}"],
  onTicketResolved: ["updated", "maintenance_records/{ticketId}"],
  stampGlobalPullServerClock: ["written", "{collectionId}/{documentId}"]
});
const VARIANTS = Object.freeze(["existing-fleet", "missing-runtime-sa", "no-existing-event-service"]);
function createFleetFixture(cohorts, policy, variant = "existing-fleet") {
  assert(VARIANTS.includes(variant));
  assert.equal(policy.productionProjectId, PROJECT);
  assert.equal(cohorts.callables.length, 13); assert.equal(cohorts.events.length, 5);
  assert.equal(cohorts.schedulers.length, 1); assert.equal(cohorts.fleet.length, 19);
  assert.deepEqual([...Object.keys(policy.functionBindings)].sort(), [...cohorts.fleet].sort());
  assert.deepEqual(Object.keys(EVENT_DEFINITIONS).sort(), [...cohorts.events].sort());
  assert.deepEqual(cohorts.schedulers, ["maintenanceWorkflowEscalationSweep"]);
  const endpoints = {}, functions = [];
  for (const name of cohorts.fleet) {
    const id = policy.functionBindings[name].runtimeServiceAccountId;
    assert.equal(typeof id, "string"); assert(/^[a-z][a-z0-9-]+$/.test(id));
    const serviceAccount = id + "@" + PROJECT + ".iam.gserviceaccount.com";
    let trigger;
    if (cohorts.callables.includes(name)) trigger = { callableTrigger: {} };
    else if (cohorts.events.includes(name)) {
      const [operation, document] = EVENT_DEFINITIONS[name];
      trigger = { eventTrigger: { eventType: "google.cloud.firestore.document.v1." + operation,
        eventFilters: { database: "(default)", namespace: "(default)" },
        eventFilterPathPatterns: { document }, retry: true, region: REGION } };
    } else trigger = { scheduleTrigger: { schedule: "every 15 minutes", timeZone: "Asia/Kolkata" } };
    endpoints[name] = { platform: "gcfv2", region: [REGION], entryPoint: name, serviceAccount,
      secretEnvironmentVariables: [], ...trigger };
    // Minimal API-shaped synthetic record. No live revisions, hashes, URLs, policies, etags or source archives are copied.
    const existing = { name: "projects/" + PROJECT + "/locations/" + REGION + "/functions/" + name,
      environment: "GEN_2", state: "ACTIVE", buildConfig: { runtime: "nodejs22", entryPoint: name },
      serviceConfig: { serviceAccountEmail: serviceAccount, secretEnvironmentVariables: [] }, labels: {} };
    if (trigger.callableTrigger) existing.labels["deployment-callable"] = "true";
    else if (trigger.scheduleTrigger) existing.labels["deployment-scheduled"] = "true";
    else {
      const event = trigger.eventTrigger;
      existing.eventTrigger = { eventType: event.eventType, triggerRegion: REGION,
        serviceAccountEmail: serviceAccount, retryPolicy: "RETRY_POLICY_RETRY",
        eventFilters: [...Object.entries(event.eventFilters).map(([attribute, value]) => ({ attribute, value })),
          { attribute: "document", value: event.eventFilterPathPatterns.document, operator: "match-path-pattern" }] };
    }
    functions.push(existing);
  }
  if (variant === "missing-runtime-sa") delete endpoints.getBackendReleaseIdentity.serviceAccount;
  if (variant === "no-existing-event-service") {
    // Deliberately new service, with retry disabled only in this adversary so the real CLI reaches its IAM branch
    // instead of stopping earlier at the separate --force/failure-policy prompt.
    for (const name of cohorts.events) endpoints[name].eventTrigger.retry = false;
  }
  const existingFunctions = variant === "no-existing-event-service"
    ? functions.filter(fn => !fn.eventTrigger) : functions;
  return { synthetic: true, variant, actualSdkDiscoveryExecuted: false, currentProductionStateClaimed: false,
    manifest: { specVersion: "v1alpha1", endpoints, params: [], requiredAPIs: [] },
    existingFunctions };
}
module.exports = { createFleetFixture, EVENT_DEFINITIONS, VARIANTS };
