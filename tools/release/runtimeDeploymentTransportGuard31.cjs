'use strict';
// This is a refusal boundary, not a mock success layer. Unknown writes stop.
const fs=require('node:fs');
const {urlToHttpOptions}=require('node:url');
const {AsyncLocalStorage}=require('node:async_hooks');
const {need,eq,hash}=require('./backendRuntimeAdmission31.cjs').helpers;
const context=new AsyncLocalStorage();
let credentialDebugLease=null,credentialRefreshInFlight=0;
function installCredentialRefreshDebugBoundary31(logger){
  need(!credentialDebugLease&&credentialRefreshInFlight===0,'Credential-refresh debug boundary must be installed once before requests');
  const original=Object.getOwnPropertyDescriptor(logger,'debug');
  need(original&&Object.hasOwn(original,'value')&&typeof original.value==='function'&&original.writable&&original.configurable,'Owned writable CLI debug logger required');
  let restored=false;
  const wrapped=function(...args){
    lease.assertOwned();
    // The pinned CLI can stringify a token FormData Buffer when fetch rejects.
    // Drop the entire debug call in this async context; do not inspect secrets.
    if(context.getStore()?.kind==='credential-refresh')return this;
    return original.value.apply(this,args);
  };
  const installed={...original,value:wrapped};
  const lease={
    assertOwned(){need(!restored&&credentialDebugLease===lease,'Credential-refresh debug boundary is not active');eq(Object.getOwnPropertyDescriptor(logger,'debug'),installed,'Foreign credential-refresh debug logger preserved');},
    restore(){
      if(restored)return;
      need(credentialRefreshInFlight===0,'Credential-refresh debug boundary cannot restore during a pending request');
      lease.assertOwned();Object.defineProperty(logger,'debug',original);restored=true;credentialDebugLease=null;
    }
  };
  Object.defineProperty(logger,'debug',installed);credentialDebugLease=lease;return lease;
}
const PROJECT='crm3-baf-ops-b8638',REGION='asia-south1';
const resource=`projects/${PROJECT}/locations/${REGION}/functions/`;
const READ_HOSTS=new Set(['cloudfunctions.googleapis.com','cloudresourcemanager.googleapis.com','firebase.googleapis.com','serviceusage.googleapis.com','run.googleapis.com','artifactregistry.googleapis.com','secretmanager.googleapis.com','iam.googleapis.com','cloudscheduler.googleapis.com','eventarc.googleapis.com','storage.googleapis.com','firebaseextensions.googleapis.com','cloudbilling.googleapis.com']);
const AUTH_HOSTS=new Set(['oauth2.googleapis.com','www.googleapis.com']);
const CLI_TOKEN_URL='https://www.googleapis.com/oauth2/v3/token';
function cliTokenRequest31(url,method,rawUrl=url.href){
  if(url.hostname!=='www.googleapis.com')return false;
  need(method==='POST'&&url.href===CLI_TOKEN_URL&&rawUrl===CLI_TOKEN_URL,'Only the exact pinned CLI credential-refresh endpoint is admitted');
  return true;
}
function cliTokenHostHeader31(headers){
  if(headers===undefined||headers===null)return;
  need(typeof headers==='object','Credential-refresh headers must be explicit');
  const entries=Array.isArray(headers)?Array.from({length:headers.length/2},(_,i)=>[headers[i*2],headers[i*2+1]]):Object.entries(headers);
  need(!Array.isArray(headers)||headers.length%2===0,'Credential-refresh raw headers must be pairs');
  let hosts=0;
  for(const[name,value]of entries)if(String(name).toLowerCase()==='host')need(++hosts===1&&value==='www.googleapis.com','Credential-refresh Host header differs');
}
// Only the default database location lookup is reviewed; Firestore is not a general read host.
const FIRESTORE_LOCATION_URL='https://firestore.googleapis.com/v1/projects/'+PROJECT+'/databases/(default)';
function firestoreLocationRead31(url,method,rawUrl=url.href){
  if(url.hostname!=='firestore.googleapis.com')return false;
  need(method==='GET'&&url.href===FIRESTORE_LOCATION_URL&&rawUrl===FIRESTORE_LOCATION_URL,'Only the exact Firestore default-database location GET is admitted');
  return true;
}

function firestoreLocationHeaders31(headers){
  if(headers===undefined||headers===null)return;
  need(typeof headers==='object','Firestore location headers must be explicit');
  let entries;
  if(Array.isArray(headers)){
    need(headers.length%2===0,'Firestore location raw headers must be pairs');
    entries=[];for(let i=0;i<headers.length;i+=2)entries.push([headers[i],headers[i+1]]);
  }else entries=Object.entries(headers);
  for(const[name,value]of entries){
    need(typeof name==='string','Firestore location header name must be a string');
    const key=name.toLowerCase();
    need(key!=='transfer-encoding'&&key!=='trailer','Firestore location GET cannot use body framing or trailers');
    if(key==='content-length')need(value===0||value==='0','Firestore location GET content length must be zero');
  }
}
const IDENTITY_SERVICES=Object.freeze(['pubsub.googleapis.com','eventarc.googleapis.com']);
const IDENTITY_TYPE='type.googleapis.com/google.api.serviceusage.v1beta1.ServiceIdentity';
function existingServiceIdentityBindings31({project,projectIam}) {
  const origin='https://cloudresourcemanager.googleapis.com/v1/projects/'+PROJECT;
  function body(wrapper,url,method) {
    need(wrapper&&wrapper.url===url&&wrapper.method===method&&wrapper.httpStatus===200&&typeof wrapper.bodyText==='string','Verified original project/IAM response required');
    return JSON.parse(wrapper.bodyText);
  }
  const selected=body(project,origin,'GET'),policy=body(projectIam,origin+':getIamPolicy','POST');
  need(selected.projectId===PROJECT&&typeof selected.projectNumber==='string'&&/^[1-9][0-9]*$/.test(selected.projectNumber),'Exact observed project identity required');
  need(Array.isArray(policy.bindings),'Original IAM bindings required');
  const emails={};
  for(const service of IDENTITY_SERVICES) {
    const short=service.split('.')[0],rows=policy.bindings.filter(row=>row.role==='roles/'+short+'.serviceAgent');
    need(rows.length===1&&!Object.hasOwn(rows[0],'condition')&&Array.isArray(rows[0].members)&&rows[0].members.length===1,'One unconditional existing service-agent role member required');
    const member=rows[0].members[0];
    need(typeof member==='string'&&member==='serviceAccount:service-'+selected.projectNumber+'@gcp-sa-'+short+'.iam.gserviceaccount.com','Existing service-agent member differs from observed project');
    emails[service]=member.slice('serviceAccount:'.length);
  }
  return Object.freeze({projectNumber:selected.projectNumber,emails:Object.freeze(emails)});
}
function identityAttempt31(url) {
  return url.hostname==='serviceusage.googleapis.com'&&/generateserviceidentity/i.test(decodeURIComponent(url.pathname));
}
function identityUrl31(url,rawUrl=url.href) {
  if(!identityAttempt31(url))return;
  need(url.protocol==='https:'&&!url.username&&!url.password&&!url.port&&!url.search&&!url.hash&&rawUrl===url.href,'Exact service-identity URL required');
  need(/^https:\/\/serviceusage\.googleapis\.com\/v1beta1\/projects\/[1-9][0-9]*\/services\/(pubsub|eventarc)\.googleapis\.com:generateServiceIdentity$/.test(rawUrl),'Unapproved service-identity resource');
}
function verifyServiceIdentityResponse31(operation,result) {
  const body=result?.body,response=body?.response;
  need(operation.kind==='existing-service-identity'&&body&&body.done===true&&!Object.hasOwn(body,'error'),'Completed error-free service-identity Operation required');
  need(response&&response['@type']===IDENTITY_TYPE&&response.email===operation.expectedEmail,'Service identity must equal the observed existing IAM member');
  need(Object.keys(response).every(key=>['@type','email','uniqueId'].includes(key)),'Unknown service-identity response field');
  if(Object.hasOwn(response,'uniqueId'))need(typeof response.uniqueId==='string'&&/^[1-9][0-9]{0,39}$/.test(response.uniqueId),'Invalid service identity uniqueId');
  // No numeric continuity claim: the original IAM response proves email membership only.
}

function urlOf(client, request){const v=client.opts.apiVersion?'/'+client.opts.apiVersion:'';const raw=client.opts.urlPrefix+v+'/'+request.path.replace(/^\//,'');const u=new URL(raw);if(request.queryParams){const q=request.queryParams instanceof URLSearchParams?request.queryParams:new URLSearchParams(Object.entries(request.queryParams).map(([k,v])=>[k,String(v)]));u.search=q.toString();}identityUrl31(u,raw);if(cliTokenRequest31(u,request.method??'GET',raw))cliTokenHostHeader31(request.headers);if(u.hostname==='firestore.googleapis.com'){firestoreLocationRead31(u,(request.method??'GET').toUpperCase(),raw);need(request.body===undefined||request.body===null,'Firestore location GET cannot carry a body');}return u;}
function leaves(value,prefix='',out={}){for(const[k,v]of Object.entries(value)){const p=prefix?prefix+'.'+k:k;if(v&&typeof v==='object'&&!Array.isArray(v))leaves(v,p,out);else out[p]=v;}return out;}
function at(value,p){return p.split('.').reduce((x,k)=>x?.[k],value);}
function effectiveRequest31(input,options,defaultProtocol){
  const fromUrl=input instanceof URL||typeof input==='string',base=fromUrl?urlToHttpOptions(new URL(input)):{...input};
  const overrides=options&&typeof options==='object'?options:{},merged={...base,...overrides};
  need(!merged.auth,'URL authentication is not admitted');
  const protocol=merged.protocol??defaultProtocol,hostname=merged.hostname??merged.host;
  need(typeof hostname==='string'&&!hostname.includes('@'),'Exact network hostname required');
  const authority=hostname+(merged.port?':'+merged.port:''),raw=protocol+'//'+authority+(merged.path??'/'),url=new URL(raw),method=(merged.method??'GET').toUpperCase();
  if(url.hostname==='www.googleapis.com'||base.hostname==='www.googleapis.com'||base.host==='www.googleapis.com'){
    need(url.hostname==='www.googleapis.com','Credential-refresh destination override refused');
    need(merged.port===undefined||merged.port===null||merged.port==='','Credential-refresh explicit port refused');
    cliTokenRequest31(url,merged.method??'GET',raw);
    if(fromUrl)cliTokenRequest31(new URL(input),merged.method??'GET',typeof input==='string'?input:input.href);
    for(const key of ['protocol','hostname','host','port','path','method'])if(Object.hasOwn(base,key)&&Object.hasOwn(overrides,key))need(base[key]===overrides[key],'Credential-refresh request option differs: '+key);
    need(!merged.host||merged.host==='www.googleapis.com','Credential-refresh host option differs');
    need(!merged.search&&!merged.hash,'Credential-refresh query or fragment refused');
    cliTokenHostHeader31(merged.headers);
  }
  identityUrl31(url,raw);
  if(identityAttempt31(url)&&typeof input==='string')identityUrl31(new URL(input),input);
  if(firestoreLocationRead31(url,method,raw)&&typeof input==='string'&&new URL(input).hostname==='firestore.googleapis.com')need(input===FIRESTORE_LOCATION_URL,'Noncanonical Firestore location URL refused');
  return {url,method};
}
function bodyBinding31(request){if(request.body===undefined||request.body===null)return hash(Buffer.alloc(0));if(request.body&&typeof request.body.path==='string')return hash(fs.readFileSync(request.body.path));need(typeof request.body==='object'&&!Buffer.isBuffer(request.body),'Only pinned JSON or file-stream API bodies admitted');return hash(Buffer.from(JSON.stringify(request.body)));}

class RuntimeDeploymentTransportGuard31 {
  constructor({names,allNames,baselineFunctions,baselineScheduler,sourceArchiveHash,archiveSha256,archiveBytes,endpointRuntimeHashes,phase,projectNumber,serviceIdentityBaseline}){
    need(Array.isArray(names)&&names.length>0&&new Set(names).size===names.length&&allNames.length===19&&names.every(n=>allNames.includes(n)),'Finite approved cohort required');
    this.names=[...names];this.allNames=[...allNames];this.baselineFunctions=baselineFunctions;this.baselineScheduler=baselineScheduler;this.phase=phase;this.projectNumber=projectNumber;
    this.sourceArchiveHash=sourceArchiveHash;this.archiveSha256=archiveSha256;this.archiveBytes=archiveBytes;this.endpointRuntimeHashes=endpointRuntimeHashes;
    this.serviceIdentities=serviceIdentityBaseline?existingServiceIdentityBindings31(serviceIdentityBaseline):null;
    if(this.serviceIdentities)need(this.serviceIdentities.projectNumber===projectNumber,'Service identity baseline project differs');
    this.identityRequests=new Set();this.identityResponses=new Set();
    this.prepared=false;this.uploads=new Map();this.sourceLocations=[];this.mutations=new Set();this.events=[];this.sequence=0;
  }
  preparedMatches(capture){need(!this.prepared,'CLI preparation may be captured only once');need(capture.sourceArchiveHash===this.sourceArchiveHash,'Prepared source hash differs');eq(capture.endpointRuntimeHashes,this.endpointRuntimeHashes,'Prepared endpoint labels differ');need(/^[A-F0-9]{64}$/.test(capture.archiveSha256)&&Number.isSafeInteger(capture.archiveBytes)&&capture.archiveBytes>0,'Independently verified actual ZIP binding required');this.archiveSha256=capture.archiveSha256;this.archiveBytes=capture.archiveBytes;this.prepared=true;}
  read(url,method){
    need(url.protocol==='https:'&&!url.username&&!url.password&&!url.port,'HTTPS Google API origin required');
    need(!identityAttempt31(url),'Service identity requires its exact guarded write path');
    if(cliTokenRequest31(url,method)||(url.hostname==='oauth2.googleapis.com'&&method==='POST'&&['/token','/oauth2/v4/token'].includes(url.pathname)))return {kind:'credential-refresh'};
    if(firestoreLocationRead31(url,method))return {kind:'read'};
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
    if(identityAttempt31(url)) {
      identityUrl31(url);
      need(request.method==='POST'&&method==='POST'&&!this.prepared&&this.serviceIdentities,'Only bound pre-comparison service-identity POSTs are admitted');
      const service=IDENTITY_SERVICES.find(value=>url.href==='https://serviceusage.googleapis.com/v1beta1/projects/'+this.serviceIdentities.projectNumber+'/services/'+value+':generateServiceIdentity');
      need(service,'Service identity project/service differs');
      need(request.body&&Object.getPrototypeOf(request.body)===Object.prototype&&Reflect.ownKeys(request.body).length===0,'Exact empty JSON service-identity body required');
      need(bodyBinding31(request)===hash(Buffer.from('{}')),'Exact serialized empty JSON body required');
      need(request.headers&&Object.keys(request.headers).length===1&&request.headers['x-goog-user-project']===this.serviceIdentities.projectNumber,'Service identity quota project differs');
      need(!this.identityRequests.has(service),'Service identity retry forbidden');
      this.identityRequests.add(service);
      return {kind:'existing-service-identity',service,expectedEmail:this.serviceIdentities.emails[service],url:url.href,method};
    }
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
    if(operation.kind==='credential-refresh'){
      const url=new URL(operation.url);
      this.events.push({kind:'credential-refresh',method:operation.method,host:url.hostname,path:url.pathname,status:Number.isInteger(result?.status)?result.status:null});
      return;
    }
    if(operation.kind==='existing-service-identity'){verifyServiceIdentityResponse31(operation,result);need(!this.identityResponses.has(operation.service),'Duplicate identity response');this.identityResponses.add(operation.service);}
    if(operation.kind==='generate-upload'){
      const body=result.body,url=new URL(body?.uploadUrl);need(url.protocol==='https:'&&!url.username&&!url.password&&!url.port&&(url.hostname==='storage.googleapis.com'||url.hostname.endsWith('.storage.googleapis.com')),'Unexpected signed source-upload origin');
      need(body.storageSource&&typeof body.storageSource.bucket==='string'&&typeof body.storageSource.object==='string','Actual generated source location required');
      const retained=Object.freeze(structuredClone(body.storageSource));this.uploads.set(url.href,retained);this.sourceLocations.push(retained);
    }
    this.events.push({kind:operation.kind,...(operation.sequence?{sequence:operation.sequence}:{}),...(operation.name?{name:operation.name}:{})});
  }
  assertExistingServiceIdentitiesComplete(){eq([...this.identityRequests].sort(),[...IDENTITY_SERVICES].sort(),'Two exact identity requests required');eq([...this.identityResponses].sort(),[...IDENTITY_SERVICES].sort(),'Two verified existing identity responses required');}
  assertComplete(){eq([...this.mutations].filter(x=>this.names.includes(x)).sort(),[...this.names].sort(),'Every exact cohort Function must update once');need(this.prepared,'Actual preparation was not captured');}
}

function installNetworkBoundary31(guard){
  // Only the actual checked apiv2 write path is admitted. Other mutation
  // transports and direct sockets are refused; no request is faked successful.
  for(const mod of ['node:https','node:http']){
    const api=require(mod),original=api.request;
    api.request=function(input,options,callback){
      const effective=effectiveRequest31(input,options,mod==='node:https'?'https:':'http:'),u=effective.url,method=effective.method,admitted=context.getStore();
      let networkOperation=admitted;
      if(admitted?.kind==='credential-refresh'){
        credentialDebugLease?.assertOwned();
        need(u.href===admitted.url&&method===admitted.method,'Credential-refresh method or redirect changed');
        need(!admitted.transportUsed,'Credential-refresh transport retry or redirect refused');
        admitted.transportUsed=true;
      }
      if(u.protocol==='http:')need(['127.0.0.1','localhost','[::1]'].includes(u.hostname)&&method==='GET'&&['/__/functions.yaml','/__/health'].includes(u.pathname),'Only local Functions discovery is allowed over HTTP');
      else if(AUTH_HOSTS.has(u.hostname)&&method==='POST'){
        credentialDebugLease?.assertOwned();
        const operation=guard.read(u,method);
        if(admitted?.kind!=='credential-refresh')networkOperation={...operation,url:u.href,method,transportUsed:true};
      }
      else if(!admitted)guard.read(u,method);
      else need(u.href===admitted.url&&method===admitted.method,'Cloud request method/query/redirect changed');
      const bodylessFirestore=u.href===FIRESTORE_LOCATION_URL&&method==='GET';
      if(bodylessFirestore)firestoreLocationHeaders31({...((input instanceof URL||typeof input==='string')?{}:input),...(options&&typeof options==='object'?options:{})}.headers);
      const write=admitted&&!['read','credential-refresh'].includes(admitted.kind)&&!(AUTH_HOSTS.has(u.hostname)&&method==='POST');
      if(write){need(!admitted.transportUsed,'Automatic cloud mutation transport retry refused');admitted.transportUsed=true;}
      const args=arguments,receiver=this;const request=context.run({...networkOperation,networkVerified:true},()=>original.apply(receiver,args));
      if(u.hostname==='www.googleapis.com'){
        let refused=false;
        const checked=action=>{try{need(!refused,'Credential-refresh request was already refused');return action();}catch(error){refused=true;request.destroy();throw error;}};
        const originalSetHeader=request.setHeader,originalAppendHeader=request.appendHeader,originalWrite=request.write,originalEnd=request.end;
        request.setHeader=function(name,value){const receiver=this;return checked(()=>{cliTokenHostHeader31({[name]:value});return originalSetHeader.call(receiver,name,value);});};
        if(originalAppendHeader)request.appendHeader=function(name,value){const receiver=this;return checked(()=>{need(String(name).toLowerCase()!=='host','Credential-refresh Host header cannot be appended');return originalAppendHeader.call(receiver,name,value);});};
        request.write=function(){const args=arguments,receiver=this;return checked(()=>originalWrite.apply(receiver,args));};
        request.end=function(){const args=arguments,receiver=this;return checked(()=>originalEnd.apply(receiver,args));};
      }
      if(write){const chunks=[];let total=0;const originalWrite=request.write,originalEnd=request.end;
        request.flushHeaders=()=>{throw Error('Unverified mutation body cannot flush headers');};
        request.write=function(chunk,encoding,cb){const bytes=Buffer.isBuffer(chunk)?chunk:Buffer.from(chunk,typeof encoding==='string'?encoding:undefined);total+=bytes.length;need(total<=128*1024*1024,'Mutation body exceeds bound');chunks.push(bytes);const callback=typeof encoding==='function'?encoding:cb;if(callback)queueMicrotask(callback);return true;};
        request.end=function(chunk,encoding,cb){if(chunk!==undefined&&chunk!==null)this.write(chunk,encoding);const bytes=Buffer.concat(chunks);try{need(hash(bytes)===admitted.bodySha256,'Effective mutation body differs from admitted source/control bytes');}catch(error){request.destroy(error);throw error;}if(bytes.length)originalWrite.call(request,bytes);return originalEnd.call(request,undefined,undefined,typeof encoding==='function'?encoding:cb);};
      }
      if(bodylessFirestore){
        let refused=false;
        const headers=()=>{firestoreLocationHeaders31(request.getHeaders());need(request.useChunkedEncodingByDefault!==true&&request.chunkedEncoding!==true,'Firestore location GET cannot use chunked body framing');};
        const checked=action=>{try{need(!refused,'Firestore location GET was already refused');headers();return action();}catch(error){refused=true;request.destroy();throw error;}};
        const empty=chunk=>typeof chunk==='string'?chunk.length===0:chunk instanceof Uint8Array&&chunk.byteLength===0;
        const originalWrite=request.write,originalEnd=request.end,originalFlush=request.flushHeaders;
        request.write=function(chunk){const args=arguments,receiver=this;return checked(()=>{need(empty(chunk),'Firestore location GET cannot carry a wire body');return originalWrite.apply(receiver,args);});};
        request.end=function(chunk){const args=arguments,receiver=this;return checked(()=>{need(chunk===undefined||chunk===null||typeof chunk==='function'||empty(chunk),'Firestore location GET cannot carry a wire body');return originalEnd.apply(receiver,args);});};
        request.flushHeaders=function(){const args=arguments,receiver=this;return checked(()=>originalFlush.apply(receiver,args));};
        for(const name of ['setHeader','appendHeader']){const originalHeader=request[name];request[name]=function(key,value){const args=arguments,receiver=this;return checked(()=>{firestoreLocationHeaders31({[key]:value});const result=originalHeader.apply(receiver,args);headers();return result;});};}
        request.addTrailers=()=>checked(()=>{throw Error('Firestore location GET cannot carry trailers');});
        checked(()=>{});
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
  Client.prototype.request=async function(request){const operation=guard.before(this,request);if(!['read','credential-refresh'].includes(operation.kind)){operation.sequence=++guard.sequence;operation.bodySha256=operation.kind==='existing-service-identity'?hash(Buffer.from('{}')):bodyBinding31(request);await beforeWrite(operation);}
    const credential=operation.kind==='credential-refresh';
    if(credential){credentialDebugLease?.assertOwned();credentialRefreshInFlight++;}
    try{const result=await context.run(operation,()=>original.call(this,{...request,retryCodes:[],retries:0}));guard.after(operation,result);return result;}
    finally{if(credential)credentialRefreshInFlight--;}
  };
}
module.exports={existingServiceIdentityBindings31,verifyServiceIdentityResponse31,RuntimeDeploymentTransportGuard31,installApiBoundary31,installNetworkBoundary31,installCredentialRefreshDebugBoundary31,urlOf,leaves,effectiveRequest31,bodyBinding31};
