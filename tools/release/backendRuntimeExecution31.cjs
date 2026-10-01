"use strict";
// Private preparation proposal. This file performs local validation only.
// An actual automatic approval refusal blocks adding an executable branch.
const fs=require("node:fs"),path=require("node:path");
const {isDeepStrictEqual}=require("node:util");
const {verifyBackendRuntimeAdmission31,helpers}=require("./backendRuntimeAdmission31.cjs");
const {need}=helpers;
const PHASES=Object.freeze(["callables","events","fleet"]);
const EXPECTED_COHORTS=Object.freeze({"callables":["assignPublishedTemplateVersion","assignPublishedTemplateVersionV2","beginGlobalPullRun","completePlannedJobExecution","executeMaintenanceWorkflowCommand","executeMaintenanceWorkflowCommandV2","getBackendReleaseIdentity","mutateAssetHierarchy","mutateAssetHierarchyV2","mutateChargeAbnormality","mutateChargeAbnormalityV2","mutateRuntimeJobModulePopulation","mutateUserAuthority"],"events":["onJobAssigned","onMaintenanceWorkflowEventCreated","onTicketCreated","onTicketResolved","stampGlobalPullServerClock"],"schedulers":["maintenanceWorkflowEscalationSweep"],"fleet":["assignPublishedTemplateVersion","assignPublishedTemplateVersionV2","beginGlobalPullRun","completePlannedJobExecution","executeMaintenanceWorkflowCommand","executeMaintenanceWorkflowCommandV2","getBackendReleaseIdentity","maintenanceWorkflowEscalationSweep","mutateAssetHierarchy","mutateAssetHierarchyV2","mutateChargeAbnormality","mutateChargeAbnormalityV2","mutateRuntimeJobModulePopulation","mutateUserAuthority","onJobAssigned","onMaintenanceWorkflowEventCreated","onTicketCreated","onTicketResolved","stampGlobalPullServerClock"]});
const CLI_PATH="tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js";
function validateConfig(value,closure=false){
 need(value&&typeof value==="object"&&!Array.isArray(value),"Configuration object required");
 const keys=["repoRoot","authorityRoot","evidenceDirectory","approvalPointer",closure?"closurePointer":"phase"].sort();
 need(isDeepStrictEqual(Object.keys(value).sort(),keys),"Unexpected/missing configuration field; execution overrides are not accepted");
 for(const key of ["repoRoot","authorityRoot","evidenceDirectory"])need(typeof value[key]==="string"&&path.isAbsolute(value[key]),"Explicit absolute "+key+" required");
 need(fs.realpathSync(value.repoRoot)!==fs.realpathSync(value.authorityRoot),"Execution source and approval custody require distinct roots");
 if(!closure)need(PHASES.includes(value.phase),"Only callables, events or fleet planning is allowed");
 return value;
}
function fixedCohortPlan(admission,phase){
 need(admission?.ok===true&&admission.proposalOnly===true&&admission.deploymentAuthorized===false,"Read-only admitted proposal required");
 need(PHASES.includes(phase),"No Rules, indexes or manual scheduler phase exists");
 const c=admission.cohorts;
 need(c&&c.callables?.length===13&&c.events?.length===5&&c.schedulers?.length===1&&c.fleet?.length===19,"Finite 13/5/1 population required");
 need(isDeepStrictEqual(c,EXPECTED_COHORTS),"Only the reviewed existing19 Function names are admitted");
 const all=[...c.callables,...c.events,...c.schedulers];
 need(new Set(all).size===19&&all.every(n=>typeof n==="string"&&/^[A-Za-z][A-Za-z0-9_]*$/.test(n)),"Duplicate or unsafe Function name");
 need(isDeepStrictEqual([...all].sort(),[...c.fleet].sort()),"Full fleet differs from fixed cohort union");
 need(admission.projectId==="crm3-baf-ops-b8638"&&admission.region==="asia-south1","Project/region substitution refused");
 const functionNames=[...(phase==="fleet"?c.schedulers:c[phase])].sort();
 return {phase,functionNames,executable:admission.runtime.nodeExecutable,
  arguments:["--no-global-search-paths",admission.runtime.cliEntrypoint,"deploy","--only",functionNames.map(n=>"functions:"+n).join(","),"--project",admission.projectId,"--non-interactive"],
  priorCohortsRequired:PHASES.slice(0,PHASES.indexOf(phase)),
  implemented:false,executionAuthorized:false,automaticRetryAllowed:false,
  scheduledFunctionDeploymentOnly:phase==="fleet",manualSchedulerInvocation:false,
  boundary:"Plan only. No subprocess or deployment was performed. A separately approved executable path and exact deployment decision remain required."};
}
function planBackendRuntime31(config){
 validateConfig(config);
 const {phase,...inputs}=config;
 const result=verifyBackendRuntimeAdmission31({...inputs,nowUtc:new Date().toISOString()});
 const expected=fs.realpathSync(path.join(config.repoRoot,CLI_PATH));
 need(fs.realpathSync(result.runtime.cliEntrypoint)===expected,"CLI entry point must be the fixed source checkout path");
 need(!process.env.NODE_OPTIONS&&!process.env.NODE_PATH,"Node runtime injection environment is not admitted");
 const plan=fixedCohortPlan(result,phase);
 return {ok:true,mode:"VALIDATION_ONLY",source:result.source,approvalPointer:result.approvalPointer,
  executionWindow:result.executionWindow,plan,actualDeploymentPerformed:false};
}
function parseCli(args){
 need(args.length===2&&args[0]==="--config"&&typeof args[1]==="string", "Use --config FILE only; no execution flag is implemented");
 return JSON.parse(fs.readFileSync(args[1],"utf8"));
}
module.exports={planBackendRuntime31,validateConfig,fixedCohortPlan,parseCli,PHASES,CLI_PATH,EXPECTED_COHORTS};
if(require.main===module){try{process.stdout.write(JSON.stringify(planBackendRuntime31(parseCli(process.argv.slice(2))),null,2)+"\n");}catch(e){process.stderr.write("Build31 plan refused: "+e.message+"\n");process.exitCode=1;}}
