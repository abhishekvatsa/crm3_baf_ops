'use strict';
// Finite transport/lifecycle regressions. The public wire never opens a socket.
const test=require('node:test'),assert=require('node:assert/strict');
const {EventEmitter}=require('node:events'),{AsyncResource}=require('node:async_hooks');
const path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const t=require('./runtimeDeploymentTransportGuard31.cjs');
const MOTD='https://firebase-public.firebaseio.com/cli.json',PROJECT='crm3-baf-ops-b8638';
const allNames=Array.from({length:19},(_,i)=>'fn'+i);
function guard(){return new t.RuntimeDeploymentTransportGuard31({names:['fn0'],allNames,baselineFunctions:{},phase:'callables'});}
function client(){return {opts:{urlPrefix:'https://firebase-public.firebaseio.com',auth:false}};}
function identityGuard(){
  const number='123456789012',origin='https://cloudresourcemanager.googleapis.com/v1/projects/'+PROJECT;
  return new t.RuntimeDeploymentTransportGuard31({names:['fn0'],allNames,baselineFunctions:{},phase:'callables',projectNumber:number,
    serviceIdentityBaseline:{project:{method:'GET',url:origin,httpStatus:200,bodyText:JSON.stringify({projectId:PROJECT,projectNumber:number})},
      projectIam:{method:'POST',url:origin+':getIamPolicy',httpStatus:200,bodyText:JSON.stringify({bindings:['pubsub','eventarc'].map(name=>({role:'roles/'+name+'.serviceAgent',members:['serviceAccount:service-'+number+'@gcp-sa-'+name+'.iam.gserviceaccount.com']}))})}}});
}

test('MOTD is one exact unauthenticated read, never a preparation write',()=>{
  const g=guard();assert.deepEqual(g.before(client(),{method:'GET',path:'/cli.json'}),{kind:'cli-motd',url:MOTD,method:'GET'});
  assert.equal(g.prepared,false);assert.equal(g.mutations.size,0);
  assert.throws(()=>g.before(client(),{method:'GET',path:'/cli.json'}),/retry/);
  assert.deepEqual(g.read(new URL(MOTD),'GET'),{kind:'cli-motd'});
});
for(const [label,edit]of [
  ['authenticated Client',(c,r)=>{c.opts.auth=true;}],['implicit authentication',(c,r)=>{delete c.opts.auth;}],
  ['POST',(c,r)=>{r.method='POST';}],['HEAD',(c,r)=>{r.method='HEAD';}],['lowercase method',(c,r)=>{r.method='get';}],
  ['body',(c,r)=>{r.body={};}],['empty body value',(c,r)=>{r.body='';}],['query',(c,r)=>{r.queryParams={key:'fake'};}],
  ['empty query selector',(c,r)=>{r.queryParams={};}],['authorization',(c,r)=>{r.headers={Authorization:'FAKE_CANARY'};}],
  ['cookie',(c,r)=>{r.headers={Cookie:'FAKE_CANARY'};}],['content length',(c,r)=>{r.headers={'Content-Length':'1'};}],
  ['trailers',(c,r)=>{r.headers={Trailer:'x-secret'};}],['Host',(c,r)=>{r.headers={Host:'evil.invalid'};}],
])test('MOTD API refuses '+label,()=>{const c=client(),r={method:'GET',path:'/cli.json'};edit(c,r);assert.throws(()=>guard().before(c,r));});
for(const name of ['x-goog-api-key','x-api-key','x-firebase-appcheck','x-auth-token'])test('MOTD API refuses alternate credential header '+name,()=>{
  assert.throws(()=>guard().before(client(),{method:'GET',path:'/cli.json',headers:{[name]:'CREDENTIAL_CANARY'}}));
});
for(const suffix of ['/other.json','/cli.json/','/cli.json?','/cli.json?q=1','/cli.json#fragment','/nested/../cli.json','/%63li.json','//cli.json'])test('MOTD refuses path '+suffix,()=>{
  assert.throws(()=>guard().before(client(),{method:'GET',path:suffix}));
  assert.throws(()=>{const x=t.effectiveRequest31('https://firebase-public.firebaseio.com'+suffix,{method:'GET'},'https:');guard().read(x.url,x.method);});
});
for(const origin of ['http://firebase-public.firebaseio.com','https://firebase-public.firebaseio.com:443','https://firebase-public.firebaseio.com:444','https://user@firebase-public.firebaseio.com','https://FIREBASE-PUBLIC.firebaseio.com','https://firebase-public.firebaseio.com.','https://other.firebaseio.com','https://firebase-public.firebaseio.com.evil.invalid'])test('MOTD refuses origin '+origin,()=>{
  const c=client();c.opts.urlPrefix=origin;assert.throws(()=>guard().before(c,{method:'GET',path:'/cli.json'}));
  assert.throws(()=>{const x=t.effectiveRequest31(origin+'/cli.json',{method:'GET'},'https:');guard().read(x.url,x.method);});
});
for(const options of [{hostname:'evil.invalid'},{host:'evil.invalid'},{path:'/other.json'},{port:443},{method:'HEAD'},{hash:'#x'},{search:'?x=1'},{headers:{Authorization:'fake'}}])test('MOTD effective options cannot redirect or authenticate '+JSON.stringify(options),()=>assert.throws(()=>t.effectiveRequest31(MOTD,{method:'GET',...options},'https:')));

async function withWire(run){
  const https=require('node:https'),http=require('node:http'),net=require('node:net'),tls=require('node:tls'),Module=require('node:module');
  const saved=[https.request,https.get,http.request,http.get,net.Socket.prototype.connect,tls.connect,Module._load,globalThis.fetch];
  const calls=[];
  try{
    const physical=protocol=>function(input,options,callback){
      if(typeof options==='function')callback=options;
      const e=t.effectiveRequest31(input,options,protocol),async=new AsyncResource('MOTD_FAKE_WIRE');
      const row={method:e.method,url:e.url.href,forwarded:false,bodyBytes:0};calls.push(row);
      const req=new EventEmitter(),headers={host:e.url.host,...(options?.headers??{})};req.useChunkedEncodingByDefault=false;
      req.getHeaders=()=>({...headers});req.setHeader=(k,v)=>{headers[k.toLowerCase()]=v;return req;};
      req.appendHeader=(k,v)=>{headers[k.toLowerCase()]=v;return req;};req.flushHeaders=()=>req;
      req.write=chunk=>{row.bodyBytes+=Buffer.byteLength(chunk);return true;};req.destroy=()=>{row.destroyed=true;return req;};
      req.end=chunk=>{if(chunk)req.write(chunk);row.forwarded=true;queueMicrotask(()=>async.runInAsyncScope(()=>{const res=new EventEmitter();res.statusCode=200;req.emit('response',res);res.emit('end');async.emitDestroy();}));return req;};
      if(callback)req.on('response',callback);return req;
    };
    https.request=physical('https:');http.request=physical('http:');
    const g=guard();t.installNetworkBoundary31(g);await run({https,g,calls});
  }finally{
    [https.request,https.get,http.request,http.get,net.Socket.prototype.connect,tls.connect,Module._load,globalThis.fetch]=saved;
  }
}
function wiredClient(https,hook,body={minVersion:'3.0.5'}){
  return class Client{
    constructor(){this.opts=client().opts;}
    request(r){return new Promise((resolve,reject)=>{const req=https.request(MOTD,{method:r.method,headers:r.headers},res=>resolve({status:res.statusCode,body}));req.on('error',reject);if(hook)hook(req);req.end();});}
  };
}
test('real API and physical boundaries send no MOTD body and retain metadata only',async()=>withWire(async({https,g,calls})=>{
  const Client=wiredClient(https);let writes=0;t.installApiBoundary31(Client,g,()=>{writes++;});await new Client().request({method:'GET',path:'/cli.json'});
  assert.equal(writes,0);assert.equal(calls.length,1);assert.equal(calls[0].forwarded,true);assert.equal(calls[0].bodyBytes,0);
  assert.deepEqual(g.events,[{kind:'cli-motd',method:'GET',host:'firebase-public.firebaseio.com',path:'/cli.json',status:200}]);
}));
for(const [name,hook]of [['late auth',r=>r.setHeader('Authorization','SECRET_CANARY')],['late cookie',r=>r.setHeader('Cookie','SECRET_CANARY')],['body',r=>r.write('SECRET_CANARY')],['end body',r=>r.end('SECRET_CANARY')],['trailers',r=>r.addTrailers({'x-secret':'SECRET_CANARY'})],['framing',r=>r.setHeader('Transfer-Encoding','chunked')]])test('physical MOTD refuses '+name+' before body/header transmission',async()=>withWire(async({https,g,calls})=>{
  const Client=wiredClient(https,hook);t.installApiBoundary31(Client,g,()=>assert.fail('No write callback expected'));
  await assert.rejects(()=>new Client().request({method:'GET',path:'/cli.json'}));assert.equal(calls[0].forwarded,false);assert.equal(calls[0].bodyBytes,0);
  assert.equal(JSON.stringify(g.events).includes('SECRET_CANARY'),false);
}));
for(const name of ['x-goog-api-key','x-api-key','x-firebase-appcheck','x-auth-token'])test('physical MOTD refuses late alternate credential header '+name,async()=>withWire(async({https,g,calls})=>{
  const Client=wiredClient(https,r=>r.setHeader(name,'CREDENTIAL_CANARY'));t.installApiBoundary31(Client,g,()=>assert.fail());
  await assert.rejects(()=>new Client().request({method:'GET',path:'/cli.json'}));assert.equal(calls[0].forwarded,false);
  assert.equal(JSON.stringify(g.events).includes('CREDENTIAL_CANARY'),false);
}));
test('physical MOTD refuses a retry or redirect even to the same exact URL',async()=>withWire(async({https,g,calls})=>{
  class Client{
    constructor(){this.opts=client().opts;}
    request(){return new Promise((resolve,reject)=>{https.request(MOTD,{method:'GET'},()=>{try{https.request(MOTD,{method:'GET'}).end();resolve({status:200});}catch(e){reject(e);}}).end();});}
  }
  t.installApiBoundary31(Client,g,()=>assert.fail());await assert.rejects(()=>new Client().request({method:'GET',path:'/cli.json'}));assert.equal(calls.length,1);
}));
test('a too-high fetched minimum version is refused before it can seed a later phase',async()=>withWire(async({https,g})=>{
  const Client=wiredClient(https,null,{minVersion:'15.22.5'});t.installApiBoundary31(Client,g,()=>assert.fail());
  await assert.rejects(()=>new Client().request({method:'GET',path:'/cli.json'}),/minimum version exceeds/);assert.deepEqual(g.events,[]);
}));
test('safe refusal metadata excludes bodies, query values, headers and raw errors',()=>{
  const c={opts:{urlPrefix:'https://www.googleapis.com'}},r={method:'POST',path:'/oauth2/v3/token?token=QUERY_CANARY',body:{refresh_token:'BODY_CANARY'},headers:{Authorization:'HEADER_CANARY'}};
  assert.deepEqual(t.safeRequestMetadata31(c,r),{method:'POST',host:'www.googleapis.com',path:'/oauth2/v3/token',status:null});
  for(const secret of ['QUERY_CANARY','BODY_CANARY','HEADER_CANARY'])assert.equal(JSON.stringify(t.safeRequestMetadata31(c,r)).includes(secret),false);
});

for(const minimum of ['3.0.5','15.22.5'])test('identity waits for the fire-and-forget MOTD '+minimum+' response before admission',async()=>{
  const g=identityGuard();let release,identityCalls=0,writes=0;
  class Client{
    constructor(opts){this.opts=opts;}
    request(){
      if(this.opts.urlPrefix==='https://firebase-public.firebaseio.com')return new Promise(resolve=>{release=resolve;});
      identityCalls++;return Promise.resolve({status:200,body:{done:true,response:{'@type':'type.googleapis.com/google.api.serviceusage.v1beta1.ServiceIdentity',email:'service-123456789012@gcp-sa-pubsub.iam.gserviceaccount.com'}}});
    }
  }
  t.installApiBoundary31(Client,g,()=>{writes++;});
  const motd=new Client(client().opts).request({method:'GET',path:'/cli.json'});
  const identity=new Client({urlPrefix:'https://serviceusage.googleapis.com',apiVersion:'v1beta1'}).request({method:'POST',path:'projects/123456789012/services/pubsub.googleapis.com:generateServiceIdentity',body:{},headers:{'x-goog-user-project':'123456789012'}});
  await Promise.resolve();assert.equal(identityCalls,0);assert.equal(writes,0);assert.equal(g.identityRequests.size,0);
  release({status:200,body:{minVersion:minimum}});
  const outcomes=await Promise.allSettled([motd,identity]);
  if(minimum==='3.0.5'){assert(outcomes.every(row=>row.status==='fulfilled'));assert.equal(identityCalls,1);assert.equal(writes,1);}
  else{assert(outcomes.every(row=>row.status==='rejected'));assert.equal(identityCalls,0);assert.equal(writes,0);assert.equal(g.identityRequests.size,0);}
});
test('a lost MOTD is bounded and cannot leave identity admission waiting indefinitely',{timeout:22000},async()=>{
  const g=identityGuard();g.before(client(),{method:'GET',path:'/cli.json'});
  await assert.rejects(g.awaitInitialization31(),/MOTD must settle/);
  assert.equal(g.motdFailed,true);assert.equal(g.motdAccepted,false);assert.equal(g.identityRequests.size,0);
});

test('a configured live guard cannot begin identities without a completed discovery',()=>{
  const g=guard();g.requireDiscovery31(()=>{});assert.throws(()=>g.assertDiscoveryStopped31(),/shutdown must complete/);
  assert.throws(()=>g.claimDiscoveryShutdown31(new URL('http://localhost:8250/__/quitquitquit'),'GET'));
  assert.equal(g.discoveryRefused,true);
});
function fakeLifecycle(g=guard()){
  const child=new EventEmitter();Object.assign(child,{pid:12345,exitCode:null,signalCode:null});
  class Delegate{
    constructor(){this.projectId=PROJECT;this.sourceDir=path.join(os.tmpdir(),'b31-source');}
    spawnFunctionsProcess(){return child;}
    serveAdmin(config,env,port){this.spawnFunctionsProcess(config,{...env,PORT:port});return Promise.resolve(async()=>{});}
  }
  const lease=t.installDiscoveryLifecycle31({Delegate,guard:g,projectId:PROJECT,sourceDirectory:path.join(os.tmpdir(),'b31-source')});
  return {g,child,Delegate,lease};
}
test('discovery shutdown is one exact owned port and must settle before identity',async()=>{
  const f=fakeLifecycle();try{
    const stop=await new f.Delegate().serveAdmin({}, {}, '8250');assert.throws(()=>f.g.assertDiscoveryStopped31());
    const row=f.g.claimDiscoveryShutdown31(new URL('http://localhost:8250/__/quitquitquit'),'GET');
    assert.throws(()=>f.g.claimDiscoveryShutdown31(new URL('http://localhost:8250/__/quitquitquit'),'GET'));
    assert.throws(()=>f.g.assertDiscoveryStopped31());row.shutdownStatus=200;row.shutdownEnded=true;f.child.exitCode=0;f.child.emit('exit',0);
    await stop();assert.throws(()=>f.g.assertDiscoveryStopped31(),/shutdown must complete/); // the earlier refusal is sticky
  }finally{f.lease.restore();}
});
test('an unrefused owned discovery stops and releases the pre-identity gate',async()=>{
  const f=fakeLifecycle();try{
    const stop=await new f.Delegate().serveAdmin({}, {}, '8251');const row=f.g.claimDiscoveryShutdown31(new URL('http://localhost:8251/__/quitquitquit'),'GET');
    row.shutdownStatus=200;row.shutdownEnded=true;f.child.exitCode=0;f.child.emit('exit',0);await stop();assert.doesNotThrow(()=>f.g.assertDiscoveryStopped31());
  }finally{f.lease.restore();}
});
for(const url of ['http://localhost:8252/__/quitquitquit','http://127.0.0.1:8251/__/quitquitquit','http://localhost:8251/__/quitquitquit?x=1','http://localhost:8251/other','https://localhost:8251/__/quitquitquit'])test('discovery ownership refuses '+url,async()=>{
  const f=fakeLifecycle();try{await new f.Delegate().serveAdmin({}, {}, '8251');assert.throws(()=>f.g.claimDiscoveryShutdown31(new URL(url),'GET'));assert.equal(f.g.discoveryRefused,true);}finally{f.lease.restore();}
});
test('foreign discovery method replacement is preserved and blocks identity',()=>{
  const f=fakeLifecycle(),foreign=()=>{};f.Delegate.prototype.serveAdmin=foreign;
  assert.throws(()=>f.g.assertDiscoveryStopped31(),/ownership/);assert.throws(()=>f.lease.restore(),/ownership/);assert.equal(f.Delegate.prototype.serveAdmin,foreign);
});
test('an invalid discovery port is refused before spawning any child',()=>{
  const g=guard();let spawns=0;
  class Delegate{
    constructor(){this.projectId=PROJECT;this.sourceDir=os.tmpdir();}
    spawnFunctionsProcess(){spawns++;throw Error('must not spawn');}
    serveAdmin(){}
  }
  const lease=t.installDiscoveryLifecycle31({Delegate,guard:g,sourceDirectory:os.tmpdir(),projectId:PROJECT});
  try{for(const PORT of ['0','80','65536','8250/other','08250'])assert.throws(()=>new Delegate().spawnFunctionsProcess({}, {PORT}));assert.equal(spawns,0);}finally{lease.restore();}
});

for(const [label,headers]of [['auth',{Authorization:'AUTH_CANARY'}],['cookie',{Cookie:'COOKIE_CANARY'}],['body length',{'Content-Length':'1'}],['framing',{'Transfer-Encoding':'chunked'}],['Host',{Host:'evil.invalid'}]])test('owned shutdown refuses '+label+' before physical forwarding',async()=>withWire(async({g,calls})=>{
  const f=fakeLifecycle(g);try{
    await new f.Delegate().serveAdmin({}, {}, '8251');
    assert.throws(()=>require('node:http').request('http://localhost:8251/__/quitquitquit',{method:'GET',headers}));
    assert.equal(calls.length,0);assert.throws(()=>g.assertDiscoveryStopped31());
  }finally{f.lease.restore();}
}));
for(const name of ['x-goog-api-key','x-api-key','x-firebase-appcheck','x-auth-token'])test('owned shutdown refuses alternate credential header '+name,async()=>withWire(async({g,calls})=>{
  const f=fakeLifecycle(g);try{
    await new f.Delegate().serveAdmin({}, {}, '8251');
    assert.throws(()=>require('node:http').request('http://localhost:8251/__/quitquitquit',{method:'GET',headers:{[name]:'CREDENTIAL_CANARY'}}));
    assert.equal(calls.length,0);assert.throws(()=>g.assertDiscoveryStopped31());assert.equal(JSON.stringify(g.events).includes('CREDENTIAL_CANARY'),false);
  }finally{f.lease.restore();}
}));
for(const [label,change]of [['body',r=>r.write('BODY_CANARY')],['end body',r=>r.end('BODY_CANARY')],['late auth',r=>r.setHeader('Authorization','AUTH_CANARY')],['trailers',r=>r.addTrailers({canary:'SECRET'})]])test('owned shutdown refuses '+label+' without sending bytes',async()=>withWire(async({g,calls})=>{
  const f=fakeLifecycle(g);try{
    await new f.Delegate().serveAdmin({}, {}, '8251');
    const req=require('node:http').request('http://localhost:8251/__/quitquitquit',{method:'GET'});
    assert.throws(()=>change(req));assert.equal(calls[0].forwarded,false);assert.equal(calls[0].bodyBytes,0);
    assert.equal(g.discoveryRows[0].failed,true);assert.throws(()=>g.assertDiscoveryStopped31());
  }finally{f.lease.restore();}
}));

test('the real owned loopback server exits before the identity gate opens', {timeout:15000},async()=>{
  const http=require('node:http'),https=require('node:https'),net=require('node:net'),tls=require('node:tls'),Module=require('node:module');
  const saved=[https.request,https.get,http.request,http.get,net.Socket.prototype.connect,tls.connect,Module._load,globalThis.fetch];
  const port=await new Promise((resolve,reject)=>{const s=net.createServer();s.once('error',reject);s.listen(0,'localhost',()=>{const p=s.address().port;s.close(()=>resolve(String(p)));});});
  let child,exited,lease;
  const source=path.join(os.tmpdir(),'b31-loopback-lifecycle');
  class Delegate{
    constructor(){this.projectId=PROJECT;this.sourceDir=source;}
    spawnFunctionsProcess(_config,env){
      child=cp.spawn(process.execPath,['-e',"const http=require('node:http');const s=http.createServer((q,r)=>{if(q.url!=='/__/quitquitquit'){r.statusCode=404;r.end();return;}r.end('ok');s.close();});s.listen(Number(process.env.PORT),()=>console.log('READY'));"],
        {env:{SystemRoot:process.env.SystemRoot??process.env.SYSTEMROOT,WINDIR:process.env.WINDIR,PORT:env.PORT},stdio:['ignore','pipe','pipe'],windowsHide:true});
      exited=new Promise((resolve,reject)=>{child.once('exit',(code,signal)=>resolve({code,signal}));child.once('error',reject);});return child;
    }
    async serveAdmin(config,env,selectedPort){
      const p=this.spawnFunctionsProcess(config,{...env,PORT:selectedPort});
      await new Promise((resolve,reject)=>{p.stdout.once('data',resolve);p.once('error',reject);});
      return async()=>{
        await new Promise((resolve,reject)=>{const q=http.get('http://localhost:'+selectedPort+'/__/quitquitquit',r=>{r.once('error',reject);r.once('end',resolve);r.resume();});q.once('error',reject);});
        assert.deepEqual(await exited,{code:0,signal:null});
      };
    }
  }
  try{
    const g=guard();lease=t.installDiscoveryLifecycle31({Delegate,guard:g,sourceDirectory:source,projectId:PROJECT});t.installNetworkBoundary31(g);
    const stop=await new Delegate().serveAdmin({}, {}, port);const pid=child.pid;
    assert.throws(()=>g.assertDiscoveryStopped31(),/shutdown must complete/);
    await stop();assert.doesNotThrow(()=>g.assertDiscoveryStopped31());assert.throws(()=>process.kill(pid,0),{code:'ESRCH'});
    assert.deepEqual(g.events.map(row=>row.kind),['discovery-started','discovery-shutdown-admitted','discovery-stopped']);
  }finally{
    if(child&&child.exitCode===null&&child.signalCode===null){child.kill('SIGKILL');await exited;}
    if(lease)lease.restore();[https.request,https.get,http.request,http.get,net.Socket.prototype.connect,tls.connect,Module._load,globalThis.fetch]=saved;
  }
});
