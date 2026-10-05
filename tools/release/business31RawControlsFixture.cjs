"use strict";
// Synthetic raw readback fixture only. These records describe no real cloud reads
// or authenticated process, and cannot confer preparation or execution authority.
const assert = require('node:assert/strict');
const PROJECT='crm3-baf-ops-b8638', REGION='asia-south1';
const root=`projects/${PROJECT}/locations/${REGION}`;
function makeRawControls({policy,sourceCommit,approvalSha256,startedAtUtc,completedAtUtc,endpointLabels,outputTag='before'}) {
  const names=Object.keys(policy.functionBindings).sort();
  const ids=[...new Set(names.map(n=>policy.functionBindings[n].runtimeServiceAccountId))].sort();
  assert.equal(names.length,19); assert.equal(ids.length,15);
  assert.match(sourceCommit,/^[a-f0-9]{40}$/i); assert.match(approvalSha256,/^[a-f0-9]{64}$/i);
  assert.equal(typeof startedAtUtc,'string');assert.equal(typeof completedAtUtc,'string');
  assert.ok(Number.isFinite(Date.parse(startedAtUtc))&&Date.parse(startedAtUtc)<=Date.parse(completedAtUtc));
  assert.match(outputTag,/^[a-z][a-z0-9-]{0,24}$/);
  assert.deepEqual(Object.keys(endpointLabels).sort(),names);
  for (const label of Object.values(endpointLabels)) assert.match(label,/^[a-f0-9]{40}$/i);
  const response=(url,value,method='GET')=>({url,method,httpStatus:200,bodyText:JSON.stringify(value)});
  const page=(url,key,items)=>[response(url+'?pageSize=100',{[key]:items})];
  const iam={version:3,etag:'synthetic-stable-etag',bindings:[]};
  const email=id=>`${id}@${PROJECT}.iam.gserviceaccount.com`;
  const functions=[],runs=[],runIam=[];
  for (const name of names) {
    const service=`${root}/services/${name.toLowerCase()}`;
    const revision=`${name.toLowerCase()}-${outputTag}`;
    const sa=email(policy.functionBindings[name].runtimeServiceAccountId);
    const env={CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK:'false'};
    const build=`${root}/builds/synthetic-${name.toLowerCase()}-${outputTag}`;
    const storage={bucket:'synthetic-build31-fixture',object:`${outputTag}/${name}.zip`,generation:'1'};
    const image=`${REGION}-docker.pkg.dev/${PROJECT}/gcf-artifacts/${name.toLowerCase()}:${outputTag}`;
    const labels={'firebase-functions-hash':endpointLabels[name],fixture:'synthetic'};
    functions.push({name:`${root}/functions/${name}`,state:'ACTIVE',environment:'GEN_2',labels,
      buildConfig:{runtime:'nodejs22',entryPoint:name,build,source:{storageSource:storage},dockerRepository:`${root}/repositories/gcf-artifacts`},
      serviceConfig:{service,revision,serviceAccountEmail:sa,environmentVariables:env,maxInstanceCount:20,allTrafficOnLatestRevision:true}});
    const traffic=[{type:'TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST',percent:100}];
    runs.push({name:service,uid:`synthetic-uid-${name.toLowerCase()}`,generation:'1',observedGeneration:'1',reconciling:false,
      terminalCondition:{type:'Ready',state:'CONDITION_SUCCEEDED'},latestCreatedRevision:`${service}/revisions/${revision}`,latestReadyRevision:`${service}/revisions/${revision}`,
      labels,scaling:{maxInstanceCount:20},traffic,trafficStatuses:[{...traffic[0],revision}],
      template:{revision,serviceAccount:sa,labels,scaling:{maxInstanceCount:20},containers:[{image,env:Object.entries(env).map(([name,value])=>({name,value}))}]},
      buildConfig:{name:build,sourceLocation:`gs://${storage.bucket}/${storage.object}#${storage.generation}`,imageUri:image,functionTarget:name,
        baseImage:'synthetic-nodejs22-base',enableAutomaticUpdates:false,environmentVariables:{},serviceAccount:`projects/${PROJECT}/serviceAccounts/synthetic-builder@${PROJECT}.iam.gserviceaccount.com`}});
    runIam.push({resource:service,response:response(`https://run.googleapis.com/v2/${service}:getIamPolicy?options.requestedPolicyVersion=3`,iam)});
  }
  const accounts=ids.map((id,i)=>({projectId:PROJECT,email:email(id),uniqueId:String(100000000000000000000n+BigInt(i)),disabled:false}));
  const bindings=new Map();
  for (const name of names) for (const role of policy.functionBindings[name].requiredProjectRoles??[]) {
    if (!bindings.has(role)) bindings.set(role,new Set());
    bindings.get(role).add('serviceAccount:'+email(policy.functionBindings[name].runtimeServiceAccountId));
  }
  const projectIam={version:3,bindings:[...bindings].sort(([a],[b])=>a.localeCompare(b)).map(([role,members])=>({role,members:[...members].sort()}))};
  const raw={schemaVersion:1,projectId:PROJECT,region:REGION,sourceCommit,approvalSha256,startedAtUtc,completedAtUtc,
    project:response(`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}`,{projectId:PROJECT,projectNumber:'123456789012'}),
    functions:page(`https://cloudfunctions.googleapis.com/v2/projects/${PROJECT}/locations/-/functions`,'functions',functions),
    runLocations:page(`https://run.googleapis.com/v1/projects/${PROJECT}/locations`,'locations',[{locationId:REGION}]),
    runInventories:[{location:REGION,pages:page(`https://run.googleapis.com/v2/projects/${PROJECT}/locations/${REGION}/services`,'services',runs)}],runIam,
    accounts:page(`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts`,'accounts',accounts),
    accountIam:accounts.map(account=>({email:account.email,response:response(`https://iam.googleapis.com/v1/projects/${PROJECT}/serviceAccounts/${account.email}:getIamPolicy?options.requestedPolicyVersion=3`,iam,'POST')})),
    projectIam:response(`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy`,projectIam,'POST'),absence:[]};
  const schedulerName=`${root}/jobs/firebase-schedule-maintenanceWorkflowEscalationSweep-${REGION}`;
  const scheduler=response(`https://cloudscheduler.googleapis.com/v1/${schedulerName}`,{name:schedulerName,state:'ENABLED',schedule:'every 5 minutes',timeZone:'UTC',
    httpTarget:{uri:`https://${REGION}-${PROJECT}.cloudfunctions.net/maintenanceWorkflowEscalationSweep`,httpMethod:'POST',oidcToken:{serviceAccountEmail:email(policy.functionBindings.maintenanceWorkflowEscalationSweep.runtimeServiceAccountId)}}});
  return {raw,scheduler};
}
module.exports={makeRawControls};
