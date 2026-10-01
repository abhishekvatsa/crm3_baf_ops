'use strict';
// Offline qualification of the actual pinned CLI/node-fetch path. Native HTTPS
// is replaced below before the production refusal boundary is installed. No
// network listener, credential refresh, real API or deployment is performed.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync}=require('node:child_process');
if(!process.env.CRM31_WIRE_CHILD){
  test('actual pinned CLI JSON, ZIP, concurrent requests and bypass refusals on an offline wire',()=>{
    const r=spawnSync(process.execPath,[__filename],{env:{...process.env,CRM31_WIRE_CHILD:'1'},encoding:'utf8',windowsHide:true,timeout:30000});
    assert.equal(r.status,0,r.stdout+'\n'+r.stderr);const result=JSON.parse(r.stdout.trim());assert.equal(result.ok,true);assert.equal(result.networkCalls,0);assert.equal(result.cliVersion,'15.22.4');assert.equal(result.assertions,31);
  });
}else{
  (async()=>{
    for(const key of Object.keys(process.env))if(/proxy/i.test(key))delete process.env[key];
    const cli=path.resolve(__dirname,'../../tooling/firebase-cli/node_modules/firebase-tools');
    const {Client}=require(path.join(cli,'lib/apiv2.js'));const originalClientRequest=Client.prototype.request,originalDoRequest=Client.prototype.doRequest,requestOptions=[];Client.prototype.doRequest=function(options){requestOptions.push({...options});return originalDoRequest.call(this,options);};const scheduler=require(path.join(cli,'lib/gcp/cloudscheduler.js'));Client.prototype.addAuthHeader=async options=>options; // Isolated auth-free fake wire only.
    const https=require('node:https'),http=require('node:http'),{Writable,Readable}=require('node:stream');
    const t=require('./runtimeDeploymentTransportGuard31.cjs'),hash=require('./backendRuntimeAdmission31.cjs').helpers.hash;
    const names=Array.from({length:19},(_,i)=>'fn'+i),resource='projects/crm3-baf-ops-b8638/locations/asia-south1/functions/';
    const zip=Buffer.from('offline ZIP fixture bytes'),dir=fs.mkdtempSync(path.join(os.tmpdir(),'crm31-wire-')),zipFile=path.join(dir,'source.zip');fs.writeFileSync(zipFile,zip);
    const baseline=n=>({name:resource+n,buildConfig:{runtime:'nodejs22',entryPoint:n,source:{storageSource:{bucket:'old',object:'old',generation:'1'}}},labels:{'firebase-functions-hash':'a'.repeat(40),preserved:'yes'},serviceConfig:{environmentVariables:{CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK:'false'}}});
    const location={bucket:'offline',object:'source.zip',generation:'2'},signed='https://storage.googleapis.com/offline/source.zip?Signature=offline';
    const schedulerJob={name:'projects/crm3-baf-ops-b8638/locations/asia-south1/jobs/synthetic-scheduler',schedule:'every 5 minutes',timeZone:'UTC',attemptDeadline:'180s',retryConfig:{retryCount:0},httpTarget:{uri:'https://synthetic.invalid',httpMethod:'POST',oidcToken:{serviceAccountEmail:'synthetic@example.invalid'}}};const wire=[];let failNextStatus=0;
    https.request=function(input,options,callback){
      if(typeof options==='function')callback=options;
      const effective=t.effectiveRequest31(input,options,'https:');const chunks=[];
      const req=new Writable({write(chunk,encoding,done){chunks.push(Buffer.from(chunk));done();},final(done){
        const raw=Buffer.concat(chunks);wire.push({url:effective.url.href,method:effective.method,raw});
        const body=effective.url.hostname==='cloudscheduler.googleapis.com'?schedulerJob:effective.url.pathname.endsWith(':generateUploadUrl')?{uploadUrl:signed,storageSource:location}:{name:'offline-operation',done:true};
        const response=Readable.from([Buffer.from(JSON.stringify(body))]);response.statusCode=failNextStatus||200;failNextStatus=0;response.statusMessage='OK';response.headers={'content-type':'application/json'};response.rawHeaders=['content-type','application/json'];response.httpVersion='1.1';
        queueMicrotask(()=>{req.emit('response',response);done();});
      }});req.abort=()=>req.destroy();req.setTimeout=()=>req;req.setHeader=()=>{};req.getHeader=()=>undefined;if(callback)req.on('response',callback);return req;
    };
    http.request=()=>{throw Error('Offline harness admits no HTTP wire');};
    const guard=new t.RuntimeDeploymentTransportGuard31({names:['fn0','fn1'],allNames:names,baselineFunctions:{fn0:baseline('fn0'),fn1:baseline('fn1')},sourceArchiveHash:'b'.repeat(40),endpointRuntimeHashes:Object.fromEntries(names.map(n=>[n,'c'.repeat(40)])),phase:'callables'});
    guard.preparedMatches({sourceArchiveHash:'b'.repeat(40),endpointRuntimeHashes:Object.fromEntries(names.map(n=>[n,'c'.repeat(40)])),archiveSha256:hash(zip),archiveBytes:zip.length});
    t.installNetworkBoundary31(guard);const ordinals=[];t.installApiBoundary31(Client,guard,async operation=>{ordinals.push(operation.sequence);await new Promise(resolve=>setImmediate(resolve));});
    const cf=new Client({urlPrefix:'https://cloudfunctions.googleapis.com',apiVersion:'v2',auth:false});
    await cf.get(resource+'fn0');assert.equal(wire[0].method,'GET');
    await cf.post(resource.slice(0,-1)+':generateUploadUrl');assert.equal(wire[1].raw.length,0);
    const upload=new Client({urlPrefix:'https://storage.googleapis.com',auth:false});await upload.put('/offline/source.zip',fs.createReadStream(zipFile),{queryParams:new URLSearchParams('Signature=offline')});assert.deepEqual(wire[2].raw,zip);
    const proposed=names.slice(0,2).map(n=>{const p=baseline(n);p.buildConfig.source.storageSource=location;p.labels['firebase-functions-hash']='c'.repeat(40);return p;});
    await Promise.all(proposed.map(p=>cf.patch(p.name,p,{queryParams:{updateMask:'name,buildConfig.source,buildConfig.runtime,buildConfig.entryPoint,labels,serviceConfig.environmentVariables'}})));
    assert.deepEqual(wire[3].raw,Buffer.from(JSON.stringify(proposed[0])));assert.deepEqual(wire[4].raw,Buffer.from(JSON.stringify(proposed[1])));assert.deepEqual(ordinals,[1,2,3,4]);guard.assertComplete();
    let assertions=6;
    function rejects(fn){assert.throws(fn);assertions++;}
    rejects(()=>https.get('https://serviceusage.googleapis.com/v1/projects/crm3-baf-ops-b8638/services/x:enable',{method:'POST'}));
    rejects(()=>https.get('https://cloudfunctions.googleapis.com/v2/'+resource+'fn0',{hostname:'evil.invalid'}));
    rejects(()=>https.request('https://cloudfunctions.googleapis.com/v2/'+resource+'fn0',{method:'DELETE'}));
    rejects(()=>https.request('https://cloudfunctions.googleapis.com/v2/'+resource+'fn0',{path:'/v2/projects/another-project/locations/x/functions/y'}));
    await assert.rejects(()=>globalThis.fetch(new Request('https://cloudfunctions.googleapis.com/v2/'+resource+'fn0',{method:'PATCH',body:'{}'})));assertions++;
    await assert.rejects(()=>globalThis.fetch(new Request('https://cloudfunctions.googleapis.com/v2/'+resource+'fn0'),{method:'POST',body:'{}'}));assertions++;
    rejects(()=>require('undici'));rejects(()=>require('node:net').connect({host:'127.0.0.1',port:9}));rejects(()=>require('node:tls').connect({host:'example.invalid',port:443}));
    await assert.rejects(()=>cf.patch(proposed[0].name,proposed[0],{queryParams:{updateMask:'labels'}}),/retry/);assertions++;
    assert.equal(wire.length,5);assertions++;
    assert.deepEqual(guard.events.filter(e=>e.kind==='function-update').map(e=>e.sequence),[3,4]);assertions++;
    const prior=wire.length;await scheduler.createOrReplaceJob(structuredClone(schedulerJob));assert.equal(wire.length,prior+1);assertions++;assert.equal(wire.at(-1).method,'GET');assertions++;await assert.rejects(()=>scheduler.createOrReplaceJob({...schedulerJob,schedule:'every 1 minutes'}),/Unapproved cloud mutation/);assertions++;assert.equal(wire.filter(x=>x.url.includes('cloudscheduler')).every(x=>x.method==='GET'),true);assertions++;
    const reader=require('./captureBackendRuntimePreparedInputs31.cjs').readCurrentControlResponse31;
    const raw=await reader(Client,'https://cloudscheduler.googleapis.com/v1/'+schedulerJob.name);assert.equal(raw.bodyText,JSON.stringify(schedulerJob));assertions++;assert.equal(raw.httpStatus,200);assertions++;
    for(const change of ['body','query']){Client.prototype.request=originalClientRequest;const isolated=new t.RuntimeDeploymentTransportGuard31({names:['fn2'],allNames:names,baselineFunctions:{fn2:baseline('fn2')},sourceArchiveHash:'b'.repeat(40),endpointRuntimeHashes:Object.fromEntries(names.map(n=>[n,'c'.repeat(40)])),phase:'events'});isolated.preparedMatches({sourceArchiveHash:'b'.repeat(40),endpointRuntimeHashes:Object.fromEntries(names.map(n=>[n,'c'.repeat(40)])),archiveSha256:hash(zip),archiveBytes:zip.length});isolated.after({kind:'generate-upload'},{body:{uploadUrl:signed,storageSource:location}});const proposed=baseline('fn2');proposed.buildConfig.source.storageSource=location;proposed.labels['firebase-functions-hash']='c'.repeat(40);const request={method:'PATCH',path:proposed.name,body:proposed,queryParams:{updateMask:'buildConfig.source,labels'}};t.installApiBoundary31(Client,isolated,async()=>{if(change==='body')proposed.serviceConfig.environmentVariables.CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK='true';else request.queryParams.updateMask='*';});const before=wire.length;await assert.rejects(()=>cf.request(request));assertions++;assert.equal(wire.length,before);assertions++;}
    Client.prototype.request=originalClientRequest;const failed=new t.RuntimeDeploymentTransportGuard31({names:['fn3'],allNames:names,baselineFunctions:{fn3:baseline('fn3')},sourceArchiveHash:'b'.repeat(40),endpointRuntimeHashes:Object.fromEntries(names.map(n=>[n,'c'.repeat(40)])),phase:'events'});failed.preparedMatches({sourceArchiveHash:'b'.repeat(40),endpointRuntimeHashes:Object.fromEntries(names.map(n=>[n,'c'.repeat(40)])),archiveSha256:hash(zip),archiveBytes:zip.length});t.installApiBoundary31(Client,failed,async()=>{});const previous=wire.length;failNextStatus=503;await assert.rejects(()=>cf.post(resource.slice(0,-1)+':generateUploadUrl'));assertions++;assert.equal(requestOptions.at(-1).retries,0);assertions++;assert.equal(wire.length,previous+1);assertions++;
    fs.unlinkSync(zipFile);fs.rmdirSync(dir);process.stdout.write(JSON.stringify({ok:true,networkCalls:0,assertions,wireRequests:wire.length,cliVersion:require(path.join(cli,'package.json')).version}));
  })().catch(error=>{process.stderr.write(error.stack+'\n');process.exitCode=1;});
}
