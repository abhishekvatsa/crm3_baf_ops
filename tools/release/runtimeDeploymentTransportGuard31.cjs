'use strict';
// This is a refusal boundary, not a mock success layer. Unknown writes stop.
const fs=require('node:fs');
const {urlToHttpOptions}=require('node:url');
const {AsyncLocalStorage}=require('node:async_hooks');
const {need,eq,hash}=require('./backendRuntimeAdmission31.cjs').helpers;
const context=new AsyncLocalStorage();
const PROJECT='crm3-baf-ops-b8638',REGION='asia-south1';
const resource=`projects/${PROJECT}/locations/${REGION}/functions/`;
const READ_HOSTS=new Set(['cloudfunctions.googleapis.com','cloudresourcemanager.googleapis.com','firebase.googleapis.com','serviceusage.googleapis.com','run.googleapis.com','artifactregistry.googleapis.com','secretmanager.googleapis.com','iam.googleapis.com','cloudscheduler.googleapis.com','eventarc.googleapis.com','storage.googleapis.com','firebaseextensions.googleapis.com','cloudbilling.googleapis.com']);
const AUTH_HOSTS=new Set(['oauth2.googleapis.com','www.googleapis.com']);
function urlOf(client, request){const v=client.opts.apiVersion?'/'+client.opts.apiVersion:'';const u=new URL(client.opts.urlPrefix+v+'/'+request.path.replace(/^\//,''));if(request.queryParams){const q=request.queryParams instanceof URLSearchParams?request.queryParams:new URLSearchParams(Object.entries(request.queryParams).map(([k,v])=>[k,String(v)]));u.search=q.toString();}return u;}
function leaves(value,prefix='',out={}){for(const[k,v]of Object.entries(value)){const p=prefix?prefix+'.'+k:k;if(v&&typeof v==='object'&&!Array.isArray(v))leaves(v,p,out);else out[p]=v;}return out;}
function at(value,p){return p.split('.').reduce((x,k)=>x?.[k],value);}
function effectiveRequest31(input,options,defaultProtocol){const base=input instanceof URL||typeof input==='string'?urlToHttpOptions(new URL(input)):{...input};const merged={...base,...(options&&typeof options==='object'?options:{})};need(!merged.auth,'URL authentication is not admitted');const protocol=merged.protocol??defaultProtocol,hostname=merged.hostname??merged.host;need(typeof hostname==='string'&&!hostname.includes('@'),'Exact network hostname required');const authority=hostname+(merged.port?':'+merged.port:'');return {url:new URL(protocol+'//'+authority+(merged.path??'/')),method:(merged.method??'GET').toUpperCase()};}
function bodyBinding31(request){if(request.body===undefined||request.body===null)return hash(Buffer.alloc(0));if(request.body&&typeof request.body.path==='string')return hash(fs.readFileSync(request.body.path));need(typeof request.body==='object'&&!Buffer.isBuffer(request.body),'Only pinned JSON or file-stream API bodies admitted');return hash(Buffer.from(JSON.stringify(request.body)));}

class RuntimeDeploymentTransportGuard31 {
  constructor({names,allNames,baselineFunctions,baselineScheduler,sourceArchiveHash,archiveSha256,archiveBytes,endpointRuntimeHashes,phase,projectNumber}){
    need(Array.isArray(names)&&names.length>0&&new Set(names).size===names.length&&allNames.length===19&&names.every(n=>allNames.includes(n)),'Finite approved cohort required');
    this.names=[...names];this.allNames=[...allNames];this.baselineFunctions=baselineFunctions;this.baselineScheduler=baselineScheduler;this.phase=phase;this.projectNumber=projectNumber;
    this.sourceArchiveHash=sourceArchiveHash;this.archiveSha256=archiveSha256;this.archiveBytes=archiveBytes;this.endpointRuntimeHashes=endpointRuntimeHashes;
    this.prepared=false;this.uploads=new Map();this.sourceLocations=[];this.mutations=new Set();this.events=[];this.sequence=0;
  }
  preparedMatches(capture){need(!this.prepared,'CLI preparation may be captured only once');need(capture.sourceArchiveHash===this.sourceArchiveHash,'Prepared source hash differs');eq(capture.endpointRuntimeHashes,this.endpointRuntimeHashes,'Prepared endpoint labels differ');need(/^[A-F0-9]{64}$/.test(capture.archiveSha256)&&Number.isSafeInteger(capture.archiveBytes)&&capture.archiveBytes>0,'Independently verified actual ZIP binding required');this.archiveSha256=capture.archiveSha256;this.archiveBytes=capture.archiveBytes;this.prepared=true;}
  read(url,method){
    need(url.protocol==='https:'&&!url.username&&!url.password&&!url.port,'HTTPS Google API origin required');
    if(AUTH_HOSTS.has(url.hostname)&&method==='POST'&&['/token','/oauth2/v4/token'].includes(url.pathname))return {kind:'credential-refresh'};
    need(READ_HOSTS.has(url.hostname),'Unreviewed API host');
    const iamRead=method==='POST'&&((url.hostname==='cloudresourcemanager.googleapis.com'&&url.pathname===`/v1/projects/${PROJECT}:getIamPolicy`)||(url.hostname==='iam.googleapis.com'&&new RegExp(`^/v1/projects/${PROJECT}/serviceAccounts/[a-zA-Z0-9@._-]+:getIamPolicy$`).test(url.pathname)));
    need(method==='GET'||method==='HEAD'||iamRead||(method==='POST'&&url.pathname.endsWith(':testIamPermissions')),'Read-only method required');
    need(!/:access$|:run$|:enable$|:disable$/.test(url.pathname),'Secret values and scheduler invocation are forbidden');
    const numbers=typeof this.projectNumber==='string'&&/^[1-9][0-9]*$/.test(this.projectNumber)?[PROJECT,this.projectNumber]:[PROJECT];
    if(url.pathname.includes('/projects/'))need(numbers.some(p=>url.pathname.includes('/projects/'+p+'/')||url.pathname.endsWith('/projects/'+p)||url.pathname.includes('/projects/'+p+':')),'Cross-project API request forbidden');
    return {kind:'read'};
  }
  before(client,request){
    const url=urlOf(client,request),method=(request.method??'GET').toUpperCase();
    if(['GET','HEAD'].includes(method)||url.pathname.endsWith(':testIamPermissions')||url.pathname.endsWith(':getIamPolicy')||(AUTH_HOSTS.has(url.hostname)&&method==='POST'))return {...this.read(url,method),url:url.href,method};
    need(this.prepared,'No cloud write before exact prepared-input comparison');
    need(url.protocol==='https:'&&!url.username&&!url.password&&!url.port,'Exact HTTPS API required');
    if(url.hostname==='cloudfunctions.googleapis.com'&&method==='POST'&&url.pathname===`/v2/projects/${PROJECT}/locations/${REGION}/functions:generateUploadUrl`){
      need(request.body===undefined||request.body===null,'Upload request cannot change deployment options');
      need(!this.mutations.has('generate-upload'),'Automatic upload retry forbidden');this.mutations.add('generate-upload');return {kind:'generate-upload',url:url.href,method};
    }
    if(method==='PUT'&&this.uploads.has(url.href)){
      need(!this.mutations.has(url.href),'Upload retry forbidden');
      const body=request.body;need(body&&typeof body.path==='string','Source upload must use the actual retained ZIP file');
      const raw=fs.readFileSync(body.path);need(raw.length===this.archiveBytes&&hash(raw)===this.archiveSha256,'Uploaded ZIP bytes differ');
      this.mutations.add(url.href);return {kind:'source-upload',url:url.href,method};
    }
    if(url.hostname==='cloudfunctions.googleapis.com'&&method==='PATCH'&&url.pathname.startsWith('/v2/'+resource)){
      const name=url.pathname.slice(('/v2/'+resource).length);need(this.names.includes(name)&&!name.includes('/'),'Function outside approved cohort');
      need(!this.mutations.has(name),'Function update retry forbidden');
      const proposed=request.body,before=this.baselineFunctions[name];need(before&&proposed?.name===resource+name,'Update must target an existing exact Function');
      const location=proposed.buildConfig?.source?.storageSource;need(this.sourceLocations.some(x=>JSON.stringify(x)===JSON.stringify(location)),'Function source was not this verified upload');
      need(proposed.labels?.['firebase-functions-hash']===this.endpointRuntimeHashes[name],'Endpoint source/environment identity differs');
      const withoutHash=labels=>Object.fromEntries(Object.entries(labels??{}).filter(([k])=>k!=='firebase-functions-hash'));
      eq(withoutHash(proposed.labels),withoutHash(before.labels),'Existing Function labels must be preserved completely');
      eq(Object.keys(proposed.buildConfig.source),['storageSource'],'No additional Function source selector allowed');
      const changed=new Set(['buildConfig.source.storageSource.bucket','buildConfig.source.storageSource.object','buildConfig.source.storageSource.generation','labels.firebase-functions-hash']);
      for(const[k,v]of Object.entries(leaves(proposed)))if(!changed.has(k))eq(v,at(before,k),'Unapproved Function control mutation: '+k);
      const query=request.queryParams instanceof URLSearchParams?Object.fromEntries(request.queryParams):request.queryParams;
      need(typeof query?.updateMask==='string'&&query.updateMask.length>0,'Explicit Function update mask required');
      for(const field of query.updateMask.split(',')){
        need(field&&field!=='*','Wildcard update masks forbidden');
        if(field==='buildConfig.source'||field==='buildConfig.source.storageSource'||field==='labels')continue;
        if(!changed.has(field))eq(at(proposed,field),at(before,field),'Update mask would clear/change preserved control: '+field);
      }
      this.mutations.add(name);return {kind:'function-update',name,url:url.href,method};
    }
    // Scheduler edits, API enablement, IAM writes, deletion and unrecognized
    // operations are intentionally not converted into successful responses.
    throw Error('Unapproved cloud mutation refused: '+method+' '+url.hostname+url.pathname);
  }
  after(operation,result){
    if(operation.kind==='generate-upload'){
      const body=result.body,url=new URL(body?.uploadUrl);need(url.protocol==='https:'&&!url.username&&!url.password&&!url.port&&(url.hostname==='storage.googleapis.com'||url.hostname.endsWith('.storage.googleapis.com')),'Unexpected signed source-upload origin');
      need(body.storageSource&&typeof body.storageSource.bucket==='string'&&typeof body.storageSource.object==='string','Actual generated source location required');
      const retained=Object.freeze(structuredClone(body.storageSource));this.uploads.set(url.href,retained);this.sourceLocations.push(retained);
    }
    this.events.push({kind:operation.kind,...(operation.sequence?{sequence:operation.sequence}:{}),...(operation.name?{name:operation.name}:{})});
  }
  assertComplete(){eq([...this.mutations].filter(x=>this.names.includes(x)).sort(),[...this.names].sort(),'Every exact cohort Function must update once');need(this.prepared,'Actual preparation was not captured');}
}

function installNetworkBoundary31(guard){
  // Only the actual checked apiv2 write path is admitted. Other mutation
  // transports and direct sockets are refused; no request is faked successful.
  for(const mod of ['node:https','node:http']){
    const api=require(mod),original=api.request;
    api.request=function(input,options,callback){
      const effective=effectiveRequest31(input,options,mod==='node:https'?'https:':'http:'),u=effective.url,method=effective.method,admitted=context.getStore();
      if(u.protocol==='http:')need(['127.0.0.1','localhost','[::1]'].includes(u.hostname)&&method==='GET'&&['/__/functions.yaml','/__/health'].includes(u.pathname),'Only local Functions discovery is allowed over HTTP');
      else if(AUTH_HOSTS.has(u.hostname)&&method==='POST')guard.read(u,method);
      else if(!admitted)guard.read(u,method);
      else need(u.href===admitted.url&&method===admitted.method,'Cloud request method/query/redirect changed');
      const write=admitted&&!['read','credential-refresh'].includes(admitted.kind)&&!(AUTH_HOSTS.has(u.hostname)&&method==='POST');
      if(write){need(!admitted.transportUsed,'Automatic cloud mutation transport retry refused');admitted.transportUsed=true;}
      const args=arguments,receiver=this;const request=context.run({...admitted,networkVerified:true},()=>original.apply(receiver,args));
      if(write){const chunks=[];let total=0;const originalWrite=request.write,originalEnd=request.end;
        request.flushHeaders=()=>{throw Error('Unverified mutation body cannot flush headers');};
        request.write=function(chunk,encoding,cb){const bytes=Buffer.isBuffer(chunk)?chunk:Buffer.from(chunk,typeof encoding==='string'?encoding:undefined);total+=bytes.length;need(total<=128*1024*1024,'Mutation body exceeds bound');chunks.push(bytes);const callback=typeof encoding==='function'?encoding:cb;if(callback)queueMicrotask(callback);return true;};
        request.end=function(chunk,encoding,cb){if(chunk!==undefined&&chunk!==null)this.write(chunk,encoding);const bytes=Buffer.concat(chunks);try{need(hash(bytes)===admitted.bodySha256,'Effective mutation body differs from admitted source/control bytes');}catch(error){request.destroy(error);throw error;}if(bytes.length)originalWrite.call(request,bytes);return originalEnd.call(request,undefined,undefined,typeof encoding==='function'?encoding:cb);};
      }
      return request;
    };
    api.get=function(...args){const req=api.request(...args);req.end();return req;};
  }
  const socket=require('node:net').Socket.prototype,connect=socket.connect;socket.connect=function(...args){need(context.getStore()?.networkVerified===true,'Uninstrumented direct socket connection refused');return connect.apply(this,args);};
  const tls=require('node:tls'),tlsConnect=tls.connect;tls.connect=function(...args){need(context.getStore()?.networkVerified===true,'Uninstrumented TLS connection refused');return tlsConnect.apply(this,args);};
  const Module=require('node:module'),load=Module._load;Module._load=function(name,...args){need(name!=='undici'&&name!=='node:undici'&&!/[/\\]undici[/\\]/.test(name),'Uninstrumented alternative fetch transport refused');return load.call(this,name,...args);};
  globalThis.fetch=async()=>{throw Error('Uninstrumented global fetch refused; the qualified pinned CLI uses node-fetch');};
}

function installApiBoundary31(Client,guard,beforeWrite){
  const original=Client.prototype.request;
  Client.prototype.request=async function(request){const operation=guard.before(this,request);if(!['read','credential-refresh'].includes(operation.kind)){operation.sequence=++guard.sequence;operation.bodySha256=bodyBinding31(request);await beforeWrite(operation);}
    const result=await context.run(operation,()=>original.call(this,{...request,retryCodes:[],retries:0}));guard.after(operation,result);return result;};
}
module.exports={RuntimeDeploymentTransportGuard31,installApiBoundary31,installNetworkBoundary31,urlOf,leaves,effectiveRequest31,bodyBinding31};
