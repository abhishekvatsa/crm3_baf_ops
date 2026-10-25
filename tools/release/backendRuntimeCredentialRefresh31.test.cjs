'use strict';
// Synthetic boundary tests. The physical transport below never opens a socket.
const test=require('node:test'),assert=require('node:assert/strict');
const {EventEmitter}=require('node:events');
const {AsyncResource}=require('node:async_hooks');
const t=require('./runtimeDeploymentTransportGuard31.cjs');
const TOKEN='https://www.googleapis.com/oauth2/v3/token';
const names=Array.from({length:19},(_,i)=>'fn'+i);
function guard(){return new t.RuntimeDeploymentTransportGuard31({names:['fn0'],allNames:names,baselineFunctions:{},sourceArchiveHash:'a'.repeat(40),endpointRuntimeHashes:{},phase:'callables'});}
const client={opts:{urlPrefix:'https://www.googleapis.com'}};

test('the pinned CLI token endpoint is an unprepared credential refresh, not a mutation',()=>{
  const g=guard();
  assert.deepEqual(g.before(client,{method:'POST',path:'/oauth2/v3/token',body:{fakeSecret:'not retained'}}),{kind:'credential-refresh',url:TOKEN,method:'POST'});
  assert.deepEqual(g.read(new URL(TOKEN),'POST'),{kind:'credential-refresh'});
  assert.equal(g.prepared,false);assert.equal(g.mutations.size,0);
});

for(const method of ['GET','HEAD','PUT','PATCH','DELETE','OPTIONS','post'])test('www token refuses method '+method,()=>{
  assert.throws(()=>guard().before(client,{method,path:'/oauth2/v3/token'}));
  assert.throws(()=>t.effectiveRequest31(TOKEN,{method},'https:'));
});

for(const path of ['/token','/oauth2/v4/token','/other','/oauth2/v3/token/','//oauth2/v3/token','/oauth2/v3/token?','/oauth2/v3/token?q=1','/oauth2/v3/token#','/oauth2/v3/token#fragment','/oauth2/v3/other/../token','/oauth2/v3/other/%2e%2e/token','/oauth2/v3/%74oken','/oauth2%2fv3/token','/oauth2\\v3/token'])test('www token refuses path '+path,()=>{
  assert.throws(()=>guard().before(client,{method:'POST',path}));
  assert.throws(()=>t.effectiveRequest31('https://www.googleapis.com'+path,{method:'POST'},'https:'));
});

for(const origin of ['http://www.googleapis.com','https://www.googleapis.com:443','https://www.googleapis.com:444','https://user@www.googleapis.com','https://user:password@www.googleapis.com','https://WWW.googleapis.com','https://www.googleapis.com.','https://www.googleapis.com.evil.invalid','https://evil.www.googleapis.com','https://www%2egoogleapis.com'])test('www token refuses noncanonical or foreign origin '+origin,()=>{
  const candidate={opts:{urlPrefix:origin}};
  assert.throws(()=>guard().before(candidate,{method:'POST',path:'/oauth2/v3/token'}));
  assert.throws(()=>{const e=t.effectiveRequest31(origin+'/oauth2/v3/token',{method:'POST'},'https:');guard().read(e.url,e.method);});
});

test('API token requests cannot add query parameters or change the Host header',()=>{
  for(const queryParams of [{token:'fake'},new URLSearchParams('token=fake')])assert.throws(()=>guard().before(client,{method:'POST',path:'/oauth2/v3/token',queryParams}));
  for(const headers of [{Host:'evil.invalid'},{host:'www.googleapis.com:443'},{Host:['www.googleapis.com']},['Host','www.googleapis.com','host','evil.invalid']])assert.throws(()=>guard().before(client,{method:'POST',path:'/oauth2/v3/token',headers}));
});

test('the effective Node overloads preserve the canonical token request',()=>{
  for(const [input,options]of [[TOKEN,{method:'POST'}],[new URL(TOKEN),{method:'POST'}],[{hostname:'www.googleapis.com',path:'/oauth2/v3/token',method:'POST'},undefined],[{host:'www.googleapis.com',protocol:'https:',path:'/oauth2/v3/token',method:'POST'},{headers:{Host:'www.googleapis.com'}}]]){
    const e=t.effectiveRequest31(input,options,'https:');assert.equal(e.url.href,TOKEN);assert.equal(e.method,'POST');
  }
  // A URL object has already discarded its original spelling; only its effective
  // canonical identity remains available. Raw string inputs are stricter above.
  assert.equal(t.effectiveRequest31(new URL('https://www.googleapis.com:443/oauth2/v3/other/../token'),{method:'POST'},'https:').url.href,TOKEN);
});

for(const [label,options]of [
  ['hostname',{hostname:'evil.invalid'}],['host',{host:'evil.invalid'}],['protocol',{protocol:'http:'}],['port',{port:443}],['other port',{port:444}],['zero port',{port:0}],['false port',{port:false}],
  ['path',{path:'/other'}],['query',{path:'/oauth2/v3/token?fake=1'}],['fragment',{hash:'#fake'}],['separate query',{search:'?fake=1'}],
  ['method',{method:'GET'}],['userinfo',{auth:'fake:secret'}],['Host header',{headers:{Host:'evil.invalid'}}],
])test('effective token request refuses '+label+' override',()=>assert.throws(()=>t.effectiveRequest31(TOKEN,{method:'POST',...options},'https:')));

test('conflicting original options cannot be made canonical by later overrides',()=>{
  for(const [input,options]of [[TOKEN.replace('/token','/other'),{path:'/oauth2/v3/token'}],[{hostname:'evil.invalid',path:'/oauth2/v3/token'},{hostname:'www.googleapis.com'}],[{hostname:'www.googleapis.com',path:'/other'},{path:'/oauth2/v3/token'}],[{hostname:'www.googleapis.com',path:'/oauth2/v3/token',method:'GET'},{method:'POST'}]])assert.throws(()=>t.effectiveRequest31(input,{method:'POST',...options},'https:'));
});

for(const path of ['/token','/oauth2/v4/token'])test('separate oauth2.googleapis.com route remains compatible: '+path,()=>{
  const g=guard(),url='https://oauth2.googleapis.com'+path;
  assert.deepEqual(g.before({opts:{urlPrefix:'https://oauth2.googleapis.com'}},{method:'POST',path}),{kind:'credential-refresh',url,method:'POST'});
  const e=t.effectiveRequest31(url,{method:'POST'},'https:');assert.deepEqual(g.read(e.url,e.method),{kind:'credential-refresh'});
});

async function withWire(run){
  const https=require('node:https'),http=require('node:http'),net=require('node:net'),tls=require('node:tls'),Module=require('node:module');
  const original={httpsRequest:https.request,httpsGet:https.get,httpRequest:http.request,httpGet:http.get,connect:net.Socket.prototype.connect,tlsConnect:tls.connect,load:Module._load,fetch:globalThis.fetch};
  const calls=[];let responseStatus=200;
  try{
    https.request=function(input,options,callback){
      if(typeof options==='function')callback=options;
      const e=t.effectiveRequest31(input,options,'https:');calls.push({method:e.method,url:e.url.href});
      const physical=new AsyncResource('OFFLINE_PHYSICAL_REQUEST'),req=new EventEmitter();
      req.write=()=>true;req.destroy=()=>req;req.setHeader=()=>req;req.appendHeader=()=>req;
      req.end=()=>{queueMicrotask(()=>physical.runInAsyncScope(()=>{req.emit('response',{statusCode:responseStatus});physical.emitDestroy();}));return req;};
      if(callback)req.on('response',callback);return req;
    };
    http.request=()=>{throw Error('No physical HTTP transport in this fixture');};
    const g=guard();t.installNetworkBoundary31(g);
    await run({https,g,calls,setStatus:value=>{responseStatus=value;}});
  }finally{
    https.request=original.httpsRequest;https.get=original.httpsGet;http.request=original.httpRequest;http.get=original.httpGet;
    net.Socket.prototype.connect=original.connect;tls.connect=original.tlsConnect;Module._load=original.load;globalThis.fetch=original.fetch;
  }
}

test('both boundaries forward a token body without retaining any secret fields',async()=>withWire(async({https,g,calls})=>{
  const secrets=['FAKE_REFRESH_TOKEN','FAKE_CLIENT_SECRET','FAKE_ACCESS_TOKEN'];let writes=0;
  class Client{
    constructor(){this.opts=client.opts;}
    request(request){assert.equal(request.retries,0);assert.deepEqual(request.retryCodes,[]);return new Promise((resolve,reject)=>{const req=https.request(TOKEN,{method:request.method},res=>resolve({status:res.statusCode,body:{access_token:secrets[2]},headers:{Authorization:secrets[2]}}));req.on('error',reject);req.end(request.body);});}
  }
  t.installApiBoundary31(Client,g,()=>{writes++;});
  await new Client().request({method:'POST',path:'/oauth2/v3/token',body:secrets.slice(0,2).join('&'),headers:{'content-type':'application/x-www-form-urlencoded'}});
  assert.equal(writes,0);assert.equal(calls.length,1);
  assert.deepEqual(g.events,[{kind:'credential-refresh',method:'POST',host:'www.googleapis.com',path:'/oauth2/v3/token',status:200}]);
  for(const secret of secrets)assert.equal(JSON.stringify(g.events).includes(secret),false);
}));

for(const status of [301,302,303,307,308])test('token redirect '+status+' cannot reach a second physical transport',async()=>{
  for(const target of [TOKEN,'https://www.googleapis.com/other','https://oauth2.googleapis.com/token','https://evil.invalid/token'])await withWire(async({https,g,calls,setStatus})=>{
    setStatus(status);
    class Client{
      constructor(){this.opts=client.opts;}
      request(){return new Promise((resolve,reject)=>{const req=https.request(TOKEN,{method:'POST'},()=>{try{https.request(target,{method:status===303?'GET':'POST'}).end();resolve({status});}catch(error){reject(error);}});req.on('error',reject);req.end('fake-body');});}
    }
    t.installApiBoundary31(Client,g,()=>{throw Error('No write expected');});
    await assert.rejects(()=>new Client().request({method:'POST',path:'/oauth2/v3/token'}));
    assert.equal(calls.length,1);assert.deepEqual(g.events,[]);
  });
});

test('a direct token transport also binds its redirect context',async()=>withWire(async({https,calls})=>{
  await assert.rejects(()=>new Promise((resolve,reject)=>{https.request(TOKEN,{method:'POST'},()=>{try{https.request('https://oauth2.googleapis.com/token',{method:'POST'}).end();resolve();}catch(error){reject(error);}}).end('fake-body');}));
  assert.equal(calls.length,1);
}));

test('late token Host header changes cannot alter the checked destination',async()=>withWire(async({https})=>{
  const req=https.request(TOKEN,{method:'POST'});
  assert.equal(req.setHeader('Host','www.googleapis.com'),req);
  assert.throws(()=>req.setHeader('Host','evil.invalid'));
  assert.throws(()=>req.end('fake-body'),/already refused/);
  const appended=https.request(TOKEN,{method:'POST'});
  assert.throws(()=>appended.appendHeader('Host','www.googleapis.com'));
  assert.throws(()=>appended.write('fake-body'),/already refused/);
  req.destroy();
}));

test('nested refresh is distinct from the parent ordinary API request',async()=>withWire(async({https,g,calls})=>{
  const resource='https://cloudfunctions.googleapis.com/v2/projects/crm3-baf-ops-b8638/locations/asia-south1/functions';
  const physical=(url,method)=>new Promise(resolve=>https.request(url,{method},res=>resolve({status:res.statusCode})).end());
  class Client{
    constructor(urlPrefix){this.opts={urlPrefix};}
    async request(request){if(this.opts.urlPrefix==='https://cloudfunctions.googleapis.com')await new Client('https://www.googleapis.com').request({method:'POST',path:'/oauth2/v3/token'});return physical(t.urlOf(this,request).href,request.method);}
  }
  t.installApiBoundary31(Client,g,()=>{throw Error('No write expected');});
  await new Client('https://cloudfunctions.googleapis.com').request({method:'GET',path:new URL(resource).pathname});
  assert.deepEqual(calls,[{method:'POST',url:TOKEN},{method:'GET',url:resource}]);assert.deepEqual(g.events.map(e=>e.kind),['credential-refresh','read']);
}));

test('credential debug suppression excludes complete third-party calls and preserves concurrent ordinary logging',async()=>{
  const calls=[],logger={debug(...args){calls.push({receiver:this,args});return 'original-result';}},original=Object.getOwnPropertyDescriptor(logger,'debug');
  let settle;
  const pending=new Promise(resolve=>{settle=resolve;}),lease=t.installCredentialRefreshDebugBoundary31(logger),g=guard();
  class Client{
    constructor(){this.opts=client.opts;}
    async request(){
      logger.debug('fake-token-buffer',Buffer.from('FAKE_REFRESH_TOKEN'),{client_secret:'FAKE_CLIENT_SECRET'});
      await pending;
      logger.debug('fake-token-response',{access_token:'FAKE_ACCESS_TOKEN'});
      return {status:200};
    }
  }
  t.installApiBoundary31(Client,g,()=>{throw Error('No mutation expected');});
  const request=new Client().request({method:'POST',path:'/oauth2/v3/token'});
  try{
    assert.throws(()=>lease.restore(),/pending request/);
    assert.throws(()=>t.installCredentialRefreshDebugBoundary31(logger),/installed once/);
    const marker={ordinary:true};assert.equal(logger.debug('ordinary',marker),'original-result');
    assert.deepEqual(calls,[{receiver:logger,args:['ordinary',marker]}]);
    settle();await request;lease.assertOwned();
    assert.equal(calls.length,1);lease.restore();lease.restore();
    assert.deepEqual(Object.getOwnPropertyDescriptor(logger,'debug'),original);
  }finally{settle();await request.catch(()=>{});lease.restore();}
});

test('failed refresh keeps its logger filter through settlement after an early restore refusal',async()=>{
  const calls=[],logger={debug(...args){calls.push(args);}},lease=t.installCredentialRefreshDebugBoundary31(logger);
  let fail;
  const pending=new Promise((_resolve,reject)=>{fail=reject;});
  class Client{
    constructor(){this.opts=client.opts;}
    async request(){try{await pending;}catch(error){logger.debug(JSON.stringify({body:Buffer.from('FAKE_REFRESH_TOKEN'),secret:'FAKE_CLIENT_SECRET'}));throw error;}}
  }
  t.installApiBoundary31(Client,guard(),()=>{throw Error('No mutation expected');});
  const request=new Client().request({method:'POST',path:'/oauth2/v3/token'});
  try{
    assert.throws(()=>lease.restore(),/pending request/);
    fail(Error('offline physical failure'));await assert.rejects(request,/offline physical failure/);
    assert.deepEqual(calls,[]);lease.assertOwned();
  }finally{fail(Error('offline fixture cleanup'));await request.catch(()=>{});lease.restore();}
});

test('foreign debug replacement refuses refresh and is preserved by cleanup',async()=>{
  const logger={debug(){}},lease=t.installCredentialRefreshDebugBoundary31(logger),installed=Object.getOwnPropertyDescriptor(logger,'debug');let called=false;
  class Client{constructor(){this.opts=client.opts;}async request(){called=true;return {status:200};}}
  t.installApiBoundary31(Client,guard(),()=>{});
  const foreign=function(){};logger.debug=foreign;
  try{
    await assert.rejects(()=>new Client().request({method:'POST',path:'/oauth2/v3/token'}),/Foreign credential-refresh debug logger/);
    assert.equal(called,false);assert.throws(()=>lease.restore(),/Foreign credential-refresh debug logger/);assert.equal(logger.debug,foreign);
  }finally{Object.defineProperty(logger,'debug',installed);lease.restore();}
});
