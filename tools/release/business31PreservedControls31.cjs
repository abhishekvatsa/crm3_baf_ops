"use strict";
// Two exact request edits only. This is not a replacement for the transport guard.
const {isDeepStrictEqual: same} = require("node:util");
const RESOURCE = "projects/crm3-baf-ops-b8638/locations/asia-south1/functions/";
const SIGNATURE = "FUNCTION_SIGNATURE_TYPE";
const own = (value, key) => value != null && Object.hasOwn(value, key);
const need = (value, message) => { if (!value) throw Error("Business31 request preservation: " + message); };
const plain = value => value !== null && typeof value === "object" &&
  [Object.prototype, null].includes(Object.getPrototypeOf(value));
function environment(value) {
  need(plain(value) && Reflect.ownKeys(value).every(key => typeof key === "string" && typeof value[key] === "string"),
    "exact environment map required");
}
function filterKeys(filters) {
  need(Array.isArray(filters), "exact event filter array required");
  const result = filters.map(filter => {
    need(plain(filter) && same(Reflect.ownKeys(filter).sort(),
      own(filter, "operator") ? ["attribute", "operator", "value"] : ["attribute", "value"]) &&
      typeof filter.attribute === "string" && typeof filter.value === "string" &&
      (!own(filter, "operator") || typeof filter.operator === "string"), "exact event filter triple required");
    return JSON.stringify([filter.attribute, filter.value, own(filter, "operator"), filter.operator ?? null]);
  });
  need(new Set(result).size === result.length, "duplicate event filter triple");
  return result.sort();
}
function preserveFunctionRequest31({client, request, names, baselineFunctions}) {
  // Do not inspect or retain unrelated requests, especially credential exchanges.
  if (request?.method !== "PATCH" || client?.opts?.urlPrefix !== "https://cloudfunctions.googleapis.com" ||
      client.opts.apiVersion !== "v2") return null;
  need(Array.isArray(names) && names.length > 0 && new Set(names).size === names.length &&
    names.every(name => typeof name === "string" && /^[A-Za-z0-9_-]+$/.test(name)), "exact approved cohort required");
  const name = typeof request.path === "string" && request.path.startsWith(RESOURCE) ? request.path.slice(RESOURCE.length) : "";
  need(names.includes(name) && request.path === RESOURCE + name && plain(request.body), "approved Function identity required");
  const baseline = own(baselineFunctions, name) ? baselineFunctions[name] : null;
  need(plain(baseline) && baseline.name === RESOURCE + name && request.body.name === baseline.name,
    "request and live baseline Function identities differ");
  const body = structuredClone(request.body), edits = [];
  const previousEnv = baseline.serviceConfig?.environmentVariables, proposedEnv = body.serviceConfig?.environmentVariables;
  const previousHasEnv = own(baseline.serviceConfig, "environmentVariables"), proposedHasEnv = own(body.serviceConfig, "environmentVariables");
  if (previousHasEnv || proposedHasEnv) {
    need(previousHasEnv && proposedHasEnv, "environment map addition or removal refused");
    environment(previousEnv); environment(proposedEnv);
    if (!own(proposedEnv, SIGNATURE) && own(previousEnv, SIGNATURE) && previousEnv[SIGNATURE] === "http") {
      need(baseline.eventTrigger === undefined && body.eventTrigger === undefined, "HTTP signature preservation requires the same HTTP Function");
      const withoutSignature = {...previousEnv}; delete withoutSignature[SIGNATURE];
      need(same(proposedEnv, withoutSignature), "other environment change refused");
      proposedEnv[SIGNATURE] = "http";
      edits.push({kind:"restore-http-signature", path:"serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE",
        before:{present:false}, after:{present:true,value:"http"}});
    }
    need(same(proposedEnv, previousEnv), "environment change refused");
  }
  const previousHasFilters = own(baseline.eventTrigger, "eventFilters"), proposedHasFilters = own(body.eventTrigger, "eventFilters");
  if (previousHasFilters || proposedHasFilters) {
    need(previousHasFilters && proposedHasFilters, "event filter addition or removal refused");
    const previous = baseline.eventTrigger.eventFilters, proposed = body.eventTrigger.eventFilters;
    need(same(filterKeys(previous), filterKeys(proposed)), "event filter set changed");
    if (!same(proposed, previous)) {
      body.eventTrigger.eventFilters = structuredClone(previous);
      edits.push({kind:"restore-event-filter-order", path:"eventTrigger.eventFilters",
        before:structuredClone(proposed), after:structuredClone(previous)});
    }
  }
  // Preserve every other request option and body field. The unchanged guard must
  // still check the full effective body, updateMask, source and endpoint controls.
  return {request:{...request,body}, edits};
}
module.exports = {preserveFunctionRequest31};
