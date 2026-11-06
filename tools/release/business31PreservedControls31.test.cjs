"use strict";
const test=require("node:test"), assert=require("node:assert/strict");
const {preserveFunctionRequest31}=require("./business31PreservedControls31.cjs");
const resource="projects/crm3-baf-ops-b8638/locations/asia-south1/functions/", name="approvedCallable";
function fixture(event=false) {
  const baseline={name:resource+name,buildConfig:{sourceToken:undefined,source:{storageSource:{bucket:"old"}}},
    serviceConfig:{ingressSettings:"ALLOW_ALL",environmentVariables:{APP_SETTING:"same",FUNCTION_SIGNATURE_TYPE:"http"}}};
  if(event){delete baseline.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE; baseline.eventTrigger={eventType:"type",eventFilters:[
    {attribute:"type",value:"event"},{attribute:"subject",value:"path/*",operator:"match-path-pattern"}]};}
  const request={method:"PATCH",path:resource+name,queryParams:{updateMask:"serviceConfig.environmentVariables"},body:structuredClone(baseline),retries:0};
  return {client:{opts:{urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v2"}},request,names:[name],baselineFunctions:{[name]:baseline}};
}
test("restore only omitted same-Function HTTP signature, retaining original and all other request fields",()=>{
  const f=fixture(); delete f.request.body.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE;
  const original=structuredClone(f.request), result=preserveFunctionRequest31(f);
  assert.deepEqual(f.request,original); assert.notEqual(result.request,f.request); assert.notEqual(result.request.body,f.request.body);
  assert.equal(result.request.queryParams,f.request.queryParams); assert.equal(Object.hasOwn(result.request.body.buildConfig,"sourceToken"),true);
  assert.deepEqual(result.request.body.serviceConfig.environmentVariables,f.baselineFunctions[name].serviceConfig.environmentVariables);
  assert.deepEqual(result.edits,[{kind:"restore-http-signature",path:"serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE",before:{present:false},after:{present:true,value:"http"}}]);
});
test("already identical controls require an explicit empty edit record",()=>assert.deepEqual(preserveFunctionRequest31(fixture()).edits,[]));
test("only an equal unique filter set can be put in baseline order",()=>{
  const f=fixture(true); f.request.body.eventTrigger.eventFilters.reverse(); const original=structuredClone(f.request);
  const result=preserveFunctionRequest31(f); assert.deepEqual(f.request,original);
  assert.deepEqual(result.request.body.eventTrigger.eventFilters,f.baselineFunctions[name].eventTrigger.eventFilters);
  assert.deepEqual(result.edits,[{kind:"restore-event-filter-order",path:"eventTrigger.eventFilters",before:original.body.eventTrigger.eventFilters,after:f.baselineFunctions[name].eventTrigger.eventFilters}]);
});
for(const [label,edit] of [
  ["wrong signature",f=>f.request.body.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE="cloudevent"],
  ["explicit null",f=>f.request.body.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE=null],
  ["explicit undefined",f=>f.request.body.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE=undefined],
  ["other environment addition",f=>f.request.body.serviceConfig.environmentVariables.EXTRA="x"],
  ["other environment removal",f=>delete f.request.body.serviceConfig.environmentVariables.APP_SETTING],
  ["other environment value",f=>f.request.body.serviceConfig.environmentVariables.APP_SETTING="changed"],
  ["missing map",f=>delete f.request.body.serviceConfig.environmentVariables],
  ["baseline signature is not http",f=>{delete f.request.body.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE; f.baselineFunctions[name].serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE="cloudevent";}],
  ["baseline is not HTTP",f=>{delete f.request.body.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE; f.baselineFunctions[name].eventTrigger={eventType:"event"};}],
  ["proposed is not HTTP",f=>{delete f.request.body.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE; f.request.body.eventTrigger={eventType:"event"};}],
  ["wrong body identity",f=>f.request.body.name=resource+"other"],
  ["wrong baseline identity",f=>f.baselineFunctions[name].name=resource+"other"],
  ["wrong path identity",f=>f.request.path=resource+"other"],
  ["encoded path identity",f=>f.request.path=resource+"%61pprovedCallable"],
  ["wrong cohort",f=>f.names=["other"]],
  ["empty cohort",f=>f.names=[]]
]) test(label+" is refused",()=>{const f=fixture();edit(f);assert.throws(()=>preserveFunctionRequest31(f),/request preservation/);});
for(const [label,edit] of [
  ["changed attribute",f=>f.request.body.eventTrigger.eventFilters[0].attribute="other"],
  ["changed value",f=>f.request.body.eventTrigger.eventFilters[0].value="other"],
  ["changed operator",f=>f.request.body.eventTrigger.eventFilters[1].operator="other"],
  ["missing operator",f=>delete f.request.body.eventTrigger.eventFilters[1].operator],
  ["extra operator",f=>f.request.body.eventTrigger.eventFilters[0].operator=""],
  ["explicit undefined operator",f=>f.request.body.eventTrigger.eventFilters[0].operator=undefined],
  ["extra field",f=>f.request.body.eventTrigger.eventFilters[0].extra=true],
  ["missing filter",f=>f.request.body.eventTrigger.eventFilters.pop()],
  ["missing filters",f=>delete f.request.body.eventTrigger.eventFilters],
  ["duplicate proposed filter",f=>f.request.body.eventTrigger.eventFilters.push({...f.request.body.eventTrigger.eventFilters[0]})],
  ["duplicate baseline filter",f=>f.baselineFunctions[name].eventTrigger.eventFilters.push({...f.baselineFunctions[name].eventTrigger.eventFilters[0]})],
  ["identical duplicate filters",f=>{f.request.body.eventTrigger.eventFilters.push({...f.request.body.eventTrigger.eventFilters[0]});f.baselineFunctions[name].eventTrigger.eventFilters=structuredClone(f.request.body.eventTrigger.eventFilters);}]
]) test(label+" is refused",()=>{const f=fixture(true);edit(f);assert.throws(()=>preserveFunctionRequest31(f),/request preservation/);});
test("all other body/mask/source changes pass through unmodified for the strict guard to reject",()=>{
  const f=fixture();f.request.body.serviceConfig.ingressSettings=null; f.request.body.buildConfig.source.storageSource.bucket="wrong";
  f.request.queryParams.updateMask+=",bogus";
  const original=structuredClone(f.request),result=preserveFunctionRequest31(f); assert.deepEqual(result.request,original);assert.deepEqual(result.edits,[]);
});
test("unrelated and credential requests are not inspected or cloned",()=>{
  const body={get refresh_token(){throw Error("credential was inspected");}};
  assert.equal(preserveFunctionRequest31({client:{opts:{urlPrefix:"https://www.googleapis.com",apiVersion:""}},request:{method:"POST",path:"oauth2/v3/token",body}}),null);
  for(const opts of [{urlPrefix:"https://cloudfunctions.googleapis.com",apiVersion:"v1"},{urlPrefix:"https://foreign.invalid",apiVersion:"v2"}]) {
    assert.equal(preserveFunctionRequest31({client:{opts},request:{method:"PATCH",body}}),null);
  }
});
