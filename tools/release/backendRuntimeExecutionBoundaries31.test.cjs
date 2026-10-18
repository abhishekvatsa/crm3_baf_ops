'use strict';
// Synthetic/local tests only. No actual preparation, HTTP call or deployment.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const a=require('./backendRuntimeAdmission31.cjs'),gate=require('./backendRuntimeExecutionAdmission31.cjs'),t=require('./runtimeDeploymentTransportGuard31.cjs');
const h=a.helpers.hash,source={commit:'1'.repeat(40),tree:'2'.repeat(40),functionsTree:'3'.repeat(40)};
function consent(){const approval={source,decidedAtUtc:'2026-10-01T20:00:00Z'},originalMessage={evidenceType:gate.TRUSTED_MESSAGE_TYPE,actorKind:'human-owner',conversationId:'synthetic-conversation',messageId:'synthetic-message',source,exactQuestion:gate.ownerInstruction(source),exactText:'Yes—deploy this exact reviewed source',actualProductionDeploymentAuthorized:true,codePreparationOnly:false,receiptTimeBasis:'first-receipt-observation',receivedAtUtc:'2026-10-01T19:59:00Z',provenanceBasis:'operator-retained-direct-human-message',machineAuthenticatedHuman:false,recordedBy:'synthetic-test-operator'},owner={schemaVersion:2,authorizationType:'direct-human-production-deployment',deploymentAction:gate.OWNER_ACTION,source,scope:a.SCOPE,actualProductionDeploymentAuthorized:true,codePreparationOnly:false,ownerInstruction:originalMessage.exactText,authorizedAtUtc:originalMessage.receivedAtUtc,recordedAtUtc:'2026-10-01T19:59:30Z'};return {approval,owner,originalMessage,source};}
test('explicit source/action contract accepts a structurally complete local fixture without claiming human authentication',()=>assert.equal(gate.verifyExplicitDeploymentOwner31(consent()),true));
for(const [name,mutate]of [
 ['today preparation reply',x=>{x.originalMessage.exactText='Approve publication of 128aec81 and backend release-code preparation.';x.owner.ownerInstruction=x.originalMessage.exactText;}],
 ['preparation-only flag',x=>x.originalMessage.codePreparationOnly=true],
 ['no deployment approval',x=>x.owner.actualProductionDeploymentAuthorized=false],
 ['wrong source',x=>x.owner.source={...source,commit:'4'.repeat(40)}],
 ['wrong action',x=>x.owner.deploymentAction='prepare-code'],
 ['claimed machine human authentication',x=>x.originalMessage.machineAuthenticatedHuman=true],
 ['synthetic authority marker',x=>x.approval.testFixtureOnly=true],
 ['Rules scope widening',x=>x.owner.scope={...a.SCOPE,firestoreRulesDeployment:true}],
 ['earlier original receipt relabelled as later consent',x=>x.owner.authorizedAtUtc='2026-10-01T19:59:20Z'],
 ['missing receipt time basis',x=>delete x.originalMessage.receiptTimeBasis],
 ['later owner receipt',x=>x.originalMessage.receivedAtUtc='2026-10-01T20:01:00Z'],
 ['generic yes without bound question',x=>x.originalMessage.exactQuestion='Can I prepare release code?'],
])test('execution consent rejects '+name,()=>{const x=consent();mutate(x);assert.throws(()=>gate.verifyExplicitDeploymentOwner31(x));});
for(const key of ['NODE_OPTIONS','NODE_PATH','NODE_EXTRA_CA_CERTS','NODE_TLS_REJECT_UNAUTHORIZED','SSL_CERT_FILE','SSL_CERT_DIR','FIREBASE_CONFIG','FIREBASE_TOKEN','FIREBASE_AUTH_EMULATOR_HOST','GOOGLE_APPLICATION_CREDENTIALS','npm_config_script_shell','HTTPS_PROXY'])test('process environment refuses '+key,()=>assert.throws(()=>gate.cleanEnvironment31({[key]:'unreviewed'})));
test('process environment preserves account-storage location without arbitrary environment',()=>{const result=gate.cleanEnvironment31({USERPROFILE:'C:/synthetic',APPDATA:'C:/synthetic/app',ARBITRARY:'x'});assert.equal(result.USERPROFILE,'C:/synthetic');assert.equal(result.ARBITRARY,undefined);});
test('deep synthetic contamination is rejected',()=>assert.throws(()=>gate.rejectSynthetic({commands:{one:{notActualExecution:true}}})));

function live(){const head='4'.repeat(40),issue_url='https://api.github.com/repos/abhishekvatsa/crm3_baf_ops/issues/391',request={id:1001,issue_url,body:'Review exact head '+head,created_at:'2026-10-01T19:16:00Z'},review={id:1002,issue_url,body:'No major issues. **Reviewed commit:** `'+head.slice(0,10)+'`',created_at:'2026-10-01T19:21:00Z',user:{login:'chatgpt-codex-connector[bot]'},performed_via_github_app:{slug:'chatgpt-codex-connector'}},pr={number:391,merged:true,merge_commit_sha:source.commit,head:{sha:head},base:{sha:source.commit,ref:'main',repo:{full_name:'abhishekvatsa/crm3_baf_ops'}},merged_at:'2026-10-01T19:22:00Z'};
 const ci=(kind,id)=>({schemaVersion:1,evidenceType:kind==='release'?'github-exact-main-release-gate':'github-exact-main-codeql',repository:'abhishekvatsa/crm3_baf_ops',sourceCommit:source.commit,sourceTree:source.tree,capturedAtUtc:'2026-10-01T19:55:00Z',pullRequest:pr,run:{id,run_attempt:1,repository:{full_name:'abhishekvatsa/crm3_baf_ops'},head_sha:source.commit,head_branch:'main',event:'push',path:kind==='release'?'.github/workflows/release-gate.yml':'.github/workflows/codeql.yml',status:'completed',conclusion:'success',created_at:'2026-10-01T19:23:00Z',updated_at:'2026-10-01T19:50:00Z'},jobs:{total_count:(kind==='release'?a.RELEASE_JOBS:a.SECURITY_JOBS).length,jobs:(kind==='release'?a.RELEASE_JOBS:a.SECURITY_JOBS).map((name,i)=>({id:id*10+i,run_id:id,run_attempt:1,head_sha:source.commit,name,status:'completed',conclusion:'success',completed_at:'2026-10-01T19:49:00Z'}))}});
 return {source,approval:{decidedAtUtc:'2026-10-01T20:00:00Z',normalMergeParents:['0'.repeat(40),head],mainCiRun:{id:1,runAttempt:1},securityCiRun:{id:2,runAttempt:1},settledSourceReview:{kind:'bot-issue-comment-no-findings',reviewer:'chatgpt-codex-connector[bot]',headCommit:head,response:{id:review.id,bodySha256:h(Buffer.from(review.body))},request:{id:request.id,bodySha256:h(Buffer.from(request.body))}}},release:ci('release',1),security:ci('security',2),mainRef:{ref:'refs/heads/main',object:{sha:source.commit}},pr,review,reviewRequest:request,reviewedHeadCommit:head,reviews:{nodes:[],pageInfo:{hasNextPage:false}},threads:{nodes:[],pageInfo:{hasNextPage:false}},nowUtc:'2026-10-01T20:01:00Z'};
}
test('synthetic full request/abbreviated positive bot response validates with exact resolved commit and postmerge base SHA',()=>assert.equal(gate.verifyLiveGitHubRecords31(live()),true));
for(const [name,mutate]of [['changed live main',x=>x.mainRef.object.sha='0'.repeat(40)],['wrong resolved prefix',x=>x.reviewedHeadCommit='0'.repeat(40)],['old run attempt',x=>x.release.jobs.jobs[0].run_attempt=2],['outstanding changes requested',x=>x.reviews.nodes.push({author:{login:'reviewer'},submittedAt:'2026-10-01T19:30:00Z',state:'CHANGES_REQUESTED'})],['unresolved thread',x=>x.threads.nodes.push({isResolved:false})],['truncated review population',x=>x.reviews.pageInfo.hasNextPage=true],['quota instead of review',x=>{x.review.body='Review usage allowance exhausted';x.approval.settledSourceReview.response.bodySha256=h(Buffer.from(x.review.body));}],['arbitrary comment',x=>{x.review.body='COMMENTED on the PR';x.approval.settledSourceReview.response.bodySha256=h(Buffer.from(x.review.body));}]])test('live gate rejects '+name,()=>{const x=live();mutate(x);assert.throws(()=>gate.verifyLiveGitHubRecords31(x));});

const names=Array.from({length:19},(_,i)=>'fn'+i),project='projects/crm3-baf-ops-b8638/locations/asia-south1/functions/',zip=Buffer.from('local synthetic archive');
function transport(){const baseline={name:project+'fn0',buildConfig:{runtime:'nodejs22',entryPoint:'fn0',source:{storageSource:{bucket:'old',object:'old',generation:'1'}}},labels:{'firebase-functions-hash':'a'.repeat(40),preserved:'yes'},serviceConfig:{environmentVariables:{CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK:'false'},maxInstanceCount:20}},guard=new t.RuntimeDeploymentTransportGuard31({names:['fn0'],allNames:names,baselineFunctions:{fn0:baseline},sourceArchiveHash:'b'.repeat(40),endpointRuntimeHashes:Object.fromEntries(names.map(n=>[n,'c'.repeat(40)])),phase:'callables'});return {guard,baseline};}
const cf={opts:{urlPrefix:'https://cloudfunctions.googleapis.com',apiVersion:'v2'}};
function prepared(guard){guard.preparedMatches({sourceArchiveHash:'b'.repeat(40),endpointRuntimeHashes:Object.fromEntries(names.map(n=>[n,'c'.repeat(40)])),archiveSha256:h(zip),archiveBytes:zip.length});}
test('no cloud write before actual prepared-input comparison',()=>assert.throws(()=>transport().guard.before(cf,{method:'POST',path:project.slice(0,-1)+':generateUploadUrl'})));
test('actual verified ZIP binding is adopted only with actual capture',()=>{const{guard}=transport();prepared(guard);assert.equal(guard.archiveSha256,h(zip));assert.equal(guard.archiveBytes,zip.length);});
function patchCase(){const{guard,baseline}=transport();prepared(guard);const location={bucket:'verified',object:'new',generation:'2'};guard.after({kind:'generate-upload'},{body:{uploadUrl:'https://storage.googleapis.com/synthetic?GoogleAccessId=x',storageSource:location}});const proposed=structuredClone(baseline);proposed.buildConfig.source.storageSource=location;proposed.labels['firebase-functions-hash']='c'.repeat(40);return {guard,request:{method:'PATCH',path:project+'fn0',body:proposed,queryParams:{updateMask:'name,buildConfig.source,buildConfig.runtime,buildConfig.entryPoint,labels,serviceConfig.environmentVariables,serviceConfig.maxInstanceCount'}}};}
test('exact source/label update preserving all other controls is admitted structurally',()=>{const x=patchCase();assert.equal(x.guard.before(cf,x.request).kind,'function-update');});
for(const[name,mutate]of [['removed preserved label',x=>delete x.request.body.labels.preserved],['changed enforcement',x=>x.request.body.serviceConfig.environmentVariables.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK='true'],['changed capacity',x=>x.request.body.serviceConfig.maxInstanceCount=21],['unknown source',x=>x.request.body.buildConfig.source.storageSource.object='other'],['wrong endpoint label',x=>x.request.body.labels['firebase-functions-hash']='d'.repeat(40)],['wildcard mask',x=>x.request.queryParams.updateMask='*'],['wrong cohort',x=>x.request.path=project+'fn1']])test('transport refuses '+name,()=>{const x=patchCase();mutate(x);assert.throws(()=>x.guard.before(cf,x.request));});
test('a second Function update cannot silently retry',()=>{const x=patchCase();x.guard.before(cf,x.request);assert.throws(()=>x.guard.before(cf,x.request),/retry/);});
for(const [host,method,url]of [['serviceusage.googleapis.com','POST','/v1/projects/crm3-baf-ops-b8638/services/x:enable'],['cloudresourcemanager.googleapis.com','POST','/v1/projects/crm3-baf-ops-b8638:setIamPolicy'],['cloudscheduler.googleapis.com','POST','/v1/projects/crm3-baf-ops-b8638/locations/asia-south1/jobs/x:run'],['secretmanager.googleapis.com','GET','/v1/projects/crm3-baf-ops-b8638/secrets/x/versions/1:access'],['cloudfunctions.googleapis.com','DELETE','/v2/'+project+'fn0']])test('forbidden operation '+host+url,()=>{const{guard}=transport();prepared(guard);assert.throws(()=>guard.before({opts:{urlPrefix:'https://'+host}},{method,path:url}));});
test('URL effective hostname/path/method overrides are inspected',()=>{const r=t.effectiveRequest31(new URL('https://cloudfunctions.googleapis.com/safe'),{hostname:'evil.invalid',path:'/changed?q=1',method:'DELETE'},'https:');assert.equal(r.url.href,'https://evil.invalid/changed?q=1');assert.equal(r.method,'DELETE');});

const firestoreLocation='https://firestore.googleapis.com/v1/projects/crm3-baf-ops-b8638/databases/(default)';
const firestore={opts:{urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1'}};
const defaultDatabase='projects/crm3-baf-ops-b8638/databases/(default)';
test('only the exact default Firestore database location GET is an unprepared read',()=>{
  const{guard}=transport();
  assert.deepEqual(guard.before(firestore,{method:'GET',path:defaultDatabase}),{kind:'read',url:firestoreLocation,method:'GET'});
  assert.deepEqual(guard.read(new URL(firestoreLocation),'GET'),{kind:'read'});
  const effective=t.effectiveRequest31(firestoreLocation,undefined,'https:');
  assert.deepEqual(guard.read(effective.url,effective.method),{kind:'read'});
  assert.equal(guard.prepared,false);assert.equal(guard.mutations.size,0);
});
test('Firestore location read never invokes the mutation callback',async()=>{
  class Client{constructor(){this.opts=firestore.opts;}async request(request){assert.equal(request.retries,0);assert.deepEqual(request.retryCodes,[]);return {body:{locationId:'asia-south1'}};}}
  const{guard}=transport();let writes=0;
  t.installApiBoundary31(Client,guard,()=>{writes++;throw Error('unexpected mutation callback');});
  assert.deepEqual(await new Client().request({method:'GET',path:defaultDatabase}),{body:{locationId:'asia-south1'}});
  assert.equal(writes,0);assert.equal(guard.prepared,false);assert.deepEqual(guard.events,[{kind:'read'}]);
});
for(const method of ['HEAD','POST','PUT','PATCH','DELETE','OPTIONS'])test('Firestore location refuses '+method+' before and after preparation',()=>{
  for(const isPrepared of [false,true]){const{guard}=transport();if(isPrepared)prepared(guard);
    assert.throws(()=>guard.before(firestore,{method,path:defaultDatabase}));
    assert.throws(()=>guard.read(new URL(firestoreLocation),method));
    assert.throws(()=>t.effectiveRequest31(firestoreLocation,{method},'https:'));
    assert.equal(guard.mutations.size,0);
  }
});
for(const [label,request]of [
  ['other project',{path:'projects/other-project/databases/(default)'}],
  ['named database',{path:'projects/crm3-baf-ops-b8638/databases/other'}],
  ['database listing',{path:'projects/crm3-baf-ops-b8638/databases'}],
  ['document path',{path:defaultDatabase+'/documents/x/y'}],
  ['trailing slash',{path:defaultDatabase+'/'}],
  ['dot segment',{path:'projects/crm3-baf-ops-b8638/databases/other/../(default)'}],
  ['encoded dot segment',{path:'projects/crm3-baf-ops-b8638/databases/other/%2e%2e/(default)'}],
  ['encoded database',{path:'projects/crm3-baf-ops-b8638/databases/%28default%29'}],
  ['backslash path',{path:defaultDatabase.replace('/databases/','\\databases\\')}],
  ['query',{path:defaultDatabase+'?x=1'}],
  ['empty query',{path:defaultDatabase+'?'}],
  ['fragment',{path:defaultDatabase+'#location'}],
  ['empty fragment',{path:defaultDatabase+'#'}],
  ['query object',{path:defaultDatabase,queryParams:{fields:'locationId'}}],
  ['query parameters',{path:defaultDatabase,queryParams:new URLSearchParams('fields=locationId')}],
  ['body',{path:defaultDatabase,body:{fields:'locationId'}}],
])test('Firestore location refuses '+label+' without widening the host policy',()=>{
  for(const isPrepared of [false,true]){const{guard}=transport();if(isPrepared)prepared(guard);assert.throws(()=>guard.before(firestore,{method:'GET',...request}));}
});
for(const [label,url]of [
  ['HTTP',firestoreLocation.replace('https:','http:')],
  ['credentials',firestoreLocation.replace('https://','https://user:password@')],
  ['explicit default port',firestoreLocation.replace('.com/','.com:443/')],
  ['other port',firestoreLocation.replace('.com/','.com:444/')],
  ['uppercase host',firestoreLocation.replace('firestore.googleapis.com','FIRESTORE.GOOGLEAPIS.COM')],
  ['host suffix',firestoreLocation.replace('.com/','.com.evil.invalid/')],
  ['API version',firestoreLocation.replace('/v1/','/v1beta1/')],
  ['dot segment',firestoreLocation.replace('/databases/','/other/../databases/')],
  ['encoded dot segment',firestoreLocation.replace('/databases/','/other/%2e%2e/databases/')],
  ['backslash',firestoreLocation.replace('/databases/','\\databases\\')],
  ['query',firestoreLocation+'?fields=locationId'],
  ['empty query',firestoreLocation+'?'],
  ['fragment',firestoreLocation+'#location'],
  ['empty fragment',firestoreLocation+'#'],
])test('effective Firestore request refuses '+label+' spelling',()=>{
  const{guard}=transport();
  assert.throws(()=>{const effective=t.effectiveRequest31(url,undefined,'https:');guard.read(effective.url,effective.method);});
});
test('effective Firestore option overrides cannot broaden the resource or method',()=>{
  const{guard}=transport();
  for(const options of [{path:'/v1/'+defaultDatabase+'/documents/x/y'},{path:'/v1/'+defaultDatabase+'?'},{path:'/v1/projects/crm3-baf-ops-b8638/other/../databases/(default)'},{method:'POST'},{port:443},{hostname:'firestore.googleapis.com.evil.invalid'}]){
    assert.throws(()=>{const effective=t.effectiveRequest31(new URL(firestoreLocation),options,'https:');guard.read(effective.url,effective.method);});
  }
});

// Every request here is a fake native transport. No socket or credential path runs.
async function withFirestoreWire31(isPrepared,run){
  const https=require('node:https'),http=require('node:http'),net=require('node:net'),tls=require('node:tls'),Module=require('node:module');
  const slots=[[https,'request'],[https,'get'],[http,'request'],[http,'get'],[net.Socket.prototype,'connect'],[tls,'connect'],[Module,'_load'],[globalThis,'fetch']];
  const saved=slots.map(([object,key])=>[object,key,Object.getOwnPropertyDescriptor(object,key)]);
  const calls={created:0,writes:0,ends:0,flushes:0,trailers:0,destroyed:0,bytes:0,callbacks:0,mutationCallbacks:0};
  const byteLength=chunk=>chunk===undefined||chunk===null||typeof chunk==='function'?0:typeof chunk==='string'?Buffer.byteLength(chunk):chunk.byteLength;
  const callbackOf=args=>[...args].findLast(value=>typeof value==='function');
  let last;
  try{
    https.request=function(input,options){
      calls.created++;
      const selected={...(typeof input==='object'&&!(input instanceof URL)?input:{}),...(options&&typeof options==='object'?options:{})},headers={};
      const initial=selected.headers??{};
      if(Array.isArray(initial)){for(let i=0;i<initial.length;i+=2)headers[initial[i].toLowerCase()]=initial[i+1];}
      else for(const[key,value]of Object.entries(initial))headers[key.toLowerCase()]=value;
      const callback=args=>{const cb=callbackOf(args);if(cb)queueMicrotask(()=>{calls.callbacks++;cb();});};
      last={useChunkedEncodingByDefault:false,chunkedEncoding:false,
        getHeaders(){return {...headers};},
        setHeader(key,value){headers[key.toLowerCase()]=value;return this;},
        appendHeader(key,value){const name=key.toLowerCase();headers[name]=headers[name]===undefined?value:[headers[name],value];return this;},
        write(chunk){calls.writes++;calls.bytes+=byteLength(chunk);callback(arguments);return true;},
        end(chunk){calls.ends++;calls.bytes+=byteLength(chunk);callback(arguments);return this;},
        flushHeaders(){calls.flushes++;},
        addTrailers(){calls.trailers++;},
        destroy(){calls.destroyed++;return this;}
      };
      return last;
    };
    http.request=()=>{throw Error('Unexpected fake HTTP transport');};
    const{guard}=transport();if(isPrepared)prepared(guard);
    t.installNetworkBoundary31(guard);
    const invoke=async(mode,action,headers)=>{
      const forward=()=>action(https.request(firestoreLocation,{method:'GET',...(headers===undefined?{}:{headers})}));
      if(mode==='direct')return forward();
      class Client{constructor(){this.opts=firestore.opts;}async request(request){assert.equal(request.retries,0);assert.deepEqual(request.retryCodes,[]);forward();return {body:{locationId:'asia-south1'}};}}
      t.installApiBoundary31(Client,guard,()=>{calls.mutationCallbacks++;throw Error('Unexpected mutation callback');});
      return new Client().request({method:'GET',path:defaultDatabase});
    };
    await run({invoke,calls,guard,last:()=>last,https});
    await Promise.resolve();
    assert.equal(calls.mutationCallbacks,0);
  }finally{for(const[object,key,descriptor]of saved.reverse()){if(descriptor)Object.defineProperty(object,key,descriptor);else delete object[key];}}
}

for(const mode of ['direct','Client'])for(const isPrepared of [false,true]){
  test('bodyless Firestore '+mode+' keeps empty native overloads, prepared='+isPrepared,async()=>{
    for(const [label,headers,action,expected]of [
      ['end',undefined,request=>assert.equal(request.end(),request),{writes:0,ends:1,callbacks:0}],
      ['end callback',undefined,request=>assert.equal(request.end(()=>{}),request),{writes:0,ends:1,callbacks:1}],
      ['empty text and null end',undefined,request=>{assert.equal(request.write('',()=>{}),true);assert.equal(request.end(null,()=>{}),request);},{writes:1,ends:1,callbacks:2}],
      ['empty binary',{'Content-Length':'0'},request=>{assert.equal(request.write(Buffer.alloc(0)),true);assert.equal(request.end(new Uint8Array(0)),request);},{writes:1,ends:1,callbacks:0}],
      ['raw zero length',['Content-Length','0'],request=>assert.equal(request.end('','utf8',()=>{}),request),{writes:0,ends:1,callbacks:1}],
      ['late zero length',undefined,request=>{request.setHeader('Content-Length',0);request.flushHeaders();request.end();},{writes:0,ends:1,callbacks:0,flushes:1}],
      ['append zero length',undefined,request=>{request.appendHeader('Content-Length','0');request.end();},{writes:0,ends:1,callbacks:0}],
    ])await withFirestoreWire31(isPrepared,async({invoke,calls,guard})=>{
      await invoke(mode,action,headers);await Promise.resolve();
      assert.equal(calls.created,1,label);assert.equal(calls.bytes,0,label);assert.equal(calls.destroyed,0,label);assert.equal(calls.trailers,0,label);
      for(const[key,value]of Object.entries(expected))assert.equal(calls[key],value,label);
      assert.equal(guard.mutations.size,0);assert.equal(guard.prepared,isPrepared);
    });
  });
  test('bodyless Firestore '+mode+' refuses bytes and latches the request, prepared='+isPrepared,async()=>{
    for(const[label,action]of [
      ['write text',request=>request.write('x')],['write Buffer',request=>request.write(Buffer.from('x'))],['write Uint8Array',request=>request.write(new Uint8Array([1]))],
      ['write encoded text',request=>request.write('eA==','base64')],['end text',request=>request.end('x')],['end Buffer',request=>request.end(Buffer.from('x'))],
      ['end Uint8Array',request=>request.end(new Uint8Array([1]))],['end encoded text',request=>request.end('78','hex')],['invalid end chunk',request=>request.end(0)],
      ['set transfer encoding',request=>request.setHeader('Transfer-Encoding','chunked')],['append transfer encoding',request=>request.appendHeader('transfer-encoding','chunked')],
      ['set positive length',request=>request.setHeader('Content-Length',1)],['append positive length',request=>request.appendHeader('Content-Length','1')],
      ['set trailers',request=>request.setHeader('Trailer','x-check')],['add trailers',request=>request.addTrailers({'x-check':'x'})],
      ['implicit chunked framing',request=>{request.useChunkedEncodingByDefault=true;request.end();}],
    ])await withFirestoreWire31(isPrepared,async({invoke,calls})=>{
      await assert.rejects(()=>invoke(mode,request=>{
        let refusal;try{action(request);}catch(error){refusal=error;}
        assert.ok(refusal,label);assert.match(refusal.message,/Firestore location/);
        for(const later of [()=>request.write(''),()=>request.end(),()=>request.flushHeaders()])assert.throws(later,/already refused/,label);
        throw refusal;
      }),/Firestore location/,label);
      assert.equal(calls.created,1,label);assert.equal(calls.bytes,0,label);assert.equal(calls.writes,0,label);assert.equal(calls.ends,0,label);assert.equal(calls.flushes,0,label);assert.equal(calls.trailers,0,label);assert.ok(calls.destroyed>=1,label);
    });
  });
  test('bodyless Firestore '+mode+' rejects initial framing before native construction, prepared='+isPrepared,async()=>{
    for(const headers of [{'Content-Length':'1'},{'Content-Length':['0','0']},{'Transfer-Encoding':'chunked'},{Trailer:'x-check'},['cOnTeNt-LeNgTh','2'],['Transfer-Encoding','chunked']]){
      await withFirestoreWire31(isPrepared,async({invoke,calls})=>{
        await assert.rejects(()=>invoke(mode,request=>request.end(),headers),/Firestore location/);
        assert.equal(calls.created,0);assert.equal(calls.bytes,0);assert.equal(calls.ends,0);
      });
    }
  });
}
test('Firestore bodyless enforcement leaves another admitted read route unchanged',async()=>{
  await withFirestoreWire31(false,async({https,calls})=>{
    const request=https.request('https://cloudfunctions.googleapis.com/v2/'+project,{method:'GET'});
    request.write('existing read behavior');request.end();
    assert.equal(calls.writes,1);assert.equal(calls.ends,1);assert.equal(calls.bytes,Buffer.byteLength('existing read behavior'));assert.equal(calls.destroyed,0);
  });
});

test('signed upload query is retained exactly in effective URI',()=>{const u=t.urlOf({opts:{urlPrefix:'https://storage.googleapis.com'}},{path:'/bucket/object',queryParams:new URLSearchParams('GoogleAccessId=x&Signature=y')});assert.equal(u.search,'?GoogleAccessId=x&Signature=y');});
test('wire JSON body binding changes with controls',()=>assert.notEqual(t.bodyBinding31({body:{max:20}}),t.bodyBinding31({body:{max:21}})));

test('observer binary binding is checked without executing the measured file',()=>{const file=process.execPath,digest=h(fs.readFileSync(file)),runtime={githubExecutable:file,githubExecutableSha256:digest};assert.deepEqual(a.verifyGithubObserverRuntime31(runtime),{executable:file,sha256:digest});assert.throws(()=>a.verifyGithubObserverRuntime31({}),/GitHub observer/);assert.throws(()=>a.verifyGithubObserverRuntime31({...runtime,githubExecutableSha256:'0'.repeat(64)}),/GitHub observer/);});
test('historical observation cannot omit or substitute the declared observer identity',()=>{const runtime={githubExecutable:process.execPath,githubExecutableSha256:h(fs.readFileSync(process.execPath))};for(const observer of [undefined,{executable:'unreviewed',sha256:runtime.githubExecutableSha256},{executable:runtime.githubExecutable,sha256:'0'.repeat(64)}])assert.throws(()=>gate.verifyPreservedLiveGitHub31({observer},{runtime},{}),/observer/);});

// The body fixture is the exact retained official comment6251814428 UTF-8 body.
// It proves format support only; synthetic chains below confer no authority.
const codexBody31=fs.readFileSync(path.join(__dirname,'testdata/codex-review-summary-6251814428.body.txt'));
const actualCodexHead31='ea9a28c8266d80b63fbbb3daf260ad0f4d576e06';
function structuredLive31(){
 const f=live(),head=f.pr.head.sha;
 f.approval.reviewPreparedAtUtc='2026-10-01T19:59:00Z';
 f.review.body=codexBody31.toString('utf8').replaceAll(actualCodexHead31,head);
 f.review.user={login:'chatgpt-codex-connector[bot]',id:199175422,type:'Bot'};
 f.review.performed_via_github_app={id:1144995,slug:'chatgpt-codex-connector',owner:{login:'openai',id:14957082}};
 f.review.created_at='2026-10-01T19:00:00Z';f.review.updated_at='2026-10-01T19:21:00Z';
 f.reviewRequest.updated_at=f.reviewRequest.created_at;f.reviewRequest.body='@codex review\n\nReview exact head '+head;
 f.reviewRequest.user={login:'abhishekvatsa',id:213690022,type:'User'};f.reviewRequest.author_association='OWNER';
 return rebindStructured31(f);
}
function rebindStructured31(f){f.approval.settledSourceReview.response.bodySha256=h(Buffer.from(f.review.body));f.approval.settledSourceReview.request.bodySha256=h(Buffer.from(f.reviewRequest.body));if(f.reviewSummary)f.approval.settledSourceReview.summary={id:f.reviewSummary.id,bodySha256:h(Buffer.from(f.reviewSummary.body))};return f;}
function changeCodeState31(f,change){const match=/<!-- codex-review-state:v1 ([^\r\n]+) -->/.exec(f.review.body),state=JSON.parse(match[1]);change(state);f.review.body=f.review.body.replace(match[1],JSON.stringify(state));}
test('exact official Codex body supports completed full-head state without a legacy marker',()=>{
 assert.equal(codexBody31.length,1165);assert.equal(h(codexBody31),'41EFDA44B131E3E5CFA26A8899F004ED37A085ADFECCE3353C43DFDBB69EBC98');
 assert.doesNotMatch(codexBody31.toString('utf8'),/\*\*Reviewed commit:/);
 const f=structuredLive31();assert.equal(gate.verifyLiveGitHubRecords31(f),true);
 const review={...f.review,body:codexBody31.toString('utf8')},request={...f.reviewRequest,body:'@codex review\n\n'+actualCodexHead31};
 assert.equal(gate.codexStructuredReview31({review,request,headCommit:actualCodexHead31,pullRequestNumber:f.pr.number,latestUtc:f.approval.reviewPreparedAtUtc}),actualCodexHead31);
});
test('structured Codex state is independent of security-review state and visible abbreviated table',()=>{const f=structuredLive31();changeCodeState31(f,s=>s.security_review={commit_sha:'0'.repeat(40),status:'in_progress',has_any_findings:true,has_unresolved_findings:true});rebindStructured31(f);assert.equal(gate.verifyLiveGitHubRecords31(f),true);});
test('structured optional summary can only repeat the identical selected native response',()=>{const f=structuredLive31();f.reviewSummary=structuredClone(f.review);rebindStructured31(f);assert.equal(gate.verifyLiveGitHubRecords31(f),true);f.reviewSummary.updated_at='2026-10-01T19:22:00Z';assert.throws(()=>gate.verifyLiveGitHubRecords31(f),/selected native response/);});
const structuredNegatives31=[
 ['same request and response',f=>{f.reviewRequest=structuredClone(f.review);f.approval.settledSourceReview.request.id=f.review.id;}],
 ['noninteger PR number',f=>f.pr.number=String(f.pr.number)],
 ['unrelated owner comment',f=>f.reviewRequest.body='Please inspect '+f.pr.head.sha],
 ['security review trigger',f=>f.reviewRequest.body='@codex security review\n'+f.pr.head.sha],
 ['quoted trigger',f=>f.reviewRequest.body='> @codex review\n'+f.pr.head.sha],
 ['non-owner actor',f=>f.reviewRequest.user.id++],
 ['bot request actor',f=>f.reviewRequest.user.type='Bot'],
 ['non-owner association',f=>f.reviewRequest.author_association='COLLABORATOR'],
 ['security boolean',f=>changeCodeState31(f,s=>s.security_review=true)],
 ['security array',f=>changeCodeState31(f,s=>s.security_review=[])],
 ['security missing field',f=>changeCodeState31(f,s=>delete s.security_review.status)],
 ['security extra field',f=>changeCodeState31(f,s=>s.security_review.approved=true)],
 ['pending',f=>changeCodeState31(f,s=>s.code_review.status='in_progress')],
 ['missing status',f=>changeCodeState31(f,s=>delete s.code_review.status)],
 ['findings',f=>changeCodeState31(f,s=>s.code_review.has_any_findings=true)],
 ['unresolved findings',f=>changeCodeState31(f,s=>s.code_review.has_unresolved_findings=true)],
 ['string false',f=>changeCodeState31(f,s=>s.code_review.has_any_findings='false')],
 ['missing flag',f=>changeCodeState31(f,s=>delete s.code_review.has_any_findings)],
 ['wrong full head',f=>changeCodeState31(f,s=>s.code_review.commit_sha='0'.repeat(40))],
 ['abbreviated head',f=>changeCodeState31(f,s=>s.code_review.commit_sha=s.code_review.commit_sha.slice(0,7))],
 ['security only',f=>changeCodeState31(f,s=>{s.security_review=s.code_review;delete s.code_review;})],
 ['null code review',f=>changeCodeState31(f,s=>s.code_review=null)],
 ['extra code field',f=>changeCodeState31(f,s=>s.code_review.approved=true)],
 ['duplicate state',f=>f.review.body+=f.review.body],
 ['duplicate JSON key',f=>f.review.body=f.review.body.replace('"status":"completed"','"status":"in_progress","status":"completed"')],
 ['malformed JSON',f=>f.review.body=f.review.body.replace('"code_review":','"code_review":,')],
 ['unknown state version',f=>f.review.body=f.review.body.replace('codex-review-state:v1','codex-review-state:v2')],
 ['quoted metadata',f=>f.review.body='> '+f.review.body],
 ['downgrade to footer and legacy marker',f=>{f.review.body=f.review.body.replace('codex-review-state:v1','codex-review-state:v2')+'\nNo findings. **Reviewed commit:** `'+f.pr.head.sha+'`';}],
 ['wrong actor ID',f=>f.review.user.id++],['human actor',f=>f.review.user.type='User'],
 ['wrong app ID',f=>f.review.performed_via_github_app.id++],['wrong app slug',f=>f.review.performed_via_github_app.slug='lookalike'],
 ['wrong app owner',f=>f.review.performed_via_github_app.owner.id++],['null supplied owner',f=>f.review.performed_via_github_app.owner=null],
 ['missing update',f=>delete f.review.updated_at],['update before creation',f=>f.review.updated_at='2026-10-01T18:00:00Z'],
 ['update after contract',f=>f.review.updated_at='2026-10-01T19:59:01Z'],
 ['request edited after result',f=>f.reviewRequest.updated_at='2026-10-01T19:22:00Z'],
 ['head only inside longer hex',f=>f.reviewRequest.body='a'+f.pr.head.sha+'b'],
 ['missing contract cutoff',f=>delete f.approval.reviewPreparedAtUtc],
 ['contract after decision',f=>f.approval.reviewPreparedAtUtc='2026-10-01T20:00:01Z'],
 ['decision after observation',f=>f.nowUtc='2026-10-01T19:59:59Z'],
 ['wrong native PR',f=>f.review.issue_url+='0'],
];
for(const [name,change]of structuredNegatives31)test('structured Codex refuses '+name,()=>{const f=structuredLive31();change(f);rebindStructured31(f);assert.throws(()=>gate.verifyLiveGitHubRecords31(f));});
test('structured native body digest remains mandatory',()=>{const f=structuredLive31();f.review.body+='\n';assert.throws(()=>gate.verifyLiveGitHubRecords31(f),/chain differs/);});
test('generic Codex footer is not a structured result',()=>{const f=structuredLive31();f.review.body=f.review.body.slice(f.review.body.indexOf('<details>'));assert.equal(gate.codexStructuredReview31({review:f.review}),null);assert.throws(()=>gate.verifyPreservedLiveGitHub31({observer:{executable:process.execPath,sha256:h(fs.readFileSync(process.execPath))},observedAtUtc:f.nowUtc,completedAtUtc:f.nowUtc,pr:JSON.stringify(f.pr),review:JSON.stringify(f.review),reviewRequest:JSON.stringify(f.reviewRequest),reviewSummary:null,threads:'{}'},{runtime:{githubExecutable:process.execPath,githubExecutableSha256:h(fs.readFileSync(process.execPath))}},f.approval),/marker absent/);});
