'use strict';
// This is a refusal boundary, not a mock success layer. Unknown writes stop.
const fs=require('node:fs');
const path=require('node:path');
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
const PINNED_CLI_VERSION = "15.22.4";
const ONE_DAY_MS = 86400000;
function motdNeed31(value, message) { if (!value) throw Error("Business31 MOTD: " + message); }
function parseVersion31(value) {
  motdNeed31(typeof value === "string" && value.length <= 128, "canonical minimum version required");
  const m = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/.exec(value);
  motdNeed31(m, "canonical minimum version required");
  const core = m.slice(1, 4).map(Number), pre = m[4]?.split(".") ?? [];
  motdNeed31(core.every(Number.isSafeInteger) && pre.every(x => !/^[0-9]+$/.test(x) || x === "0" || x[0] !== "0"), "minimum version component differs");
  return { core, pre };
}
function compareVersions31(a, b) {
  a = parseVersion31(a); b = parseVersion31(b);
  for (let i = 0; i < 3; i++) if (a.core[i] !== b.core[i]) return a.core[i] < b.core[i] ? -1 : 1;
  if (!a.pre.length || !b.pre.length) return a.pre.length === b.pre.length ? 0 : a.pre.length ? -1 : 1;
  for (let i = 0; i < Math.max(a.pre.length, b.pre.length); i++) {
    if (a.pre[i] === undefined || b.pre[i] === undefined) return a.pre[i] === b.pre[i] ? 0 : a.pre[i] === undefined ? -1 : 1;
    const x = a.pre[i], y = b.pre[i]; if (x === y) continue;
    const xn = /^[0-9]+$/.test(x), yn = /^[0-9]+$/.test(y);
    if (xn !== yn) return xn ? -1 : 1;
    if (xn && x.length !== y.length) return x.length < y.length ? -1 : 1;
    return x < y ? -1 : 1;
  }
  return 0;
}
function assertMotdVersion31(motd, version = PINNED_CLI_VERSION) {
  motdNeed31(version === PINNED_CLI_VERSION, "selected CLI version differs from pinned version");
  motdNeed31(motd === undefined || motd === null || (typeof motd === "object" && !Array.isArray(motd) && Object.getPrototypeOf(motd) === Object.prototype), "MOTD object required");
  if (motd?.minVersion !== undefined) motdNeed31(compareVersions31(motd.minVersion, version) <= 0, "cached minimum version exceeds pinned CLI");
  return true;
}
function inspectMotdCache31(motd, now = Date.now(), version = PINNED_CLI_VERSION) {
  assertMotdVersion31(motd, version);
  motdNeed31(Number.isSafeInteger(now) && now >= 0, "actual cache-check clock required");
  const fetched = motd?.fetched ?? 0;
  motdNeed31(Number.isSafeInteger(fetched) && fetched >= 0 && fetched <= now, "MOTD cache timestamp differs");
  return { cachePresent: !!motd, fetchedAtEpochMs: fetched, fresh: !!motd && fetched > now - ONE_DAY_MS,
    minVersion: motd?.minVersion ?? null, pinnedVersion: version, minVersionAccepted: true };
}

const CLI_MOTD_HOST='firebase-public.firebaseio.com',CLI_MOTD_URL='https://'+CLI_MOTD_HOST+'/cli.json';
function motdRequest31(url,method,rawUrl=url.href){
  if(url.hostname!==CLI_MOTD_HOST)return false;
  need(method==='GET'&&url.href===CLI_MOTD_URL&&rawUrl===CLI_MOTD_URL,'Only the exact public CLI MOTD GET is admitted');
  return true;
}
function bodylessPublicHeaders31(headers,host,label){
  if(headers===undefined||headers===null)return;
  need(typeof headers==='object',label+' headers must be explicit');
  let entries;
  if(Array.isArray(headers)){
    need(headers.length%2===0,label+' raw headers must be pairs');entries=[];
    for(let i=0;i<headers.length;i+=2)entries.push([headers[i],headers[i+1]]);
  }else entries=typeof headers.entries==='function'?[...headers.entries()]:Object.entries(headers);
  let hosts=0;
  for(const[name,value]of entries){
    need(typeof name==='string',label+' header name must be a string');const key=name.toLowerCase();
    need(!['authorization','proxy-authorization','cookie','cookie2','x-goog-api-key','x-api-key','x-firebase-appcheck','x-auth-token','transfer-encoding','trailer'].includes(key),label+' must be unauthenticated and bodyless');
    if(key==='host')need(++hosts===1&&value===host,label+' Host header differs');
    if(key==='content-length')need(value===0||value==='0',label+' content length must be zero');
  }
}
function safeRequestMetadata31(client,request){
  // Do not stringify request/options/errors: OAuth payloads and query values are secret.
  let host='UNKNOWN',path='UNKNOWN';
  try{const v=client.opts.apiVersion?'/'+client.opts.apiVersion:'';const u=new URL(client.opts.urlPrefix+v+'/'+request.path.replace(/^\//,''));host=u.hostname.length<=253?u.hostname:'UNKNOWN';path=u.pathname.length<=2048?u.pathname:'OVERSIZE_PATH';}catch{}
  const method=request?.method===undefined||request?.method===null?'GET':typeof request.method==='string'&&/^[A-Z]{1,12}$/.test(request.method)?request.method:'UNKNOWN';
  return {method,host,path,status:null};
}
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

function urlOf(client, request){
  const v=client.opts.apiVersion?'/'+client.opts.apiVersion:'';
  const raw=client.opts.urlPrefix+v+'/'+request.path.replace(/^\//,'');const u=new URL(raw);
  if(request.queryParams){const q=request.queryParams instanceof URLSearchParams?request.queryParams:new URLSearchParams(Object.entries(request.queryParams).map(([k,v])=>[k,String(v)]));u.search=q.toString();}
  identityUrl31(u,raw);
  if(cliTokenRequest31(u,request.method??'GET',raw))cliTokenHostHeader31(request.headers);
  if(motdRequest31(u,request.method??'GET',raw)){
    need(client.opts.auth===false,'CLI MOTD Client must explicitly disable authentication');
    need(request.body===undefined||request.body===null,'CLI MOTD GET cannot carry a body');
    need(request.queryParams===undefined||request.queryParams===null,'CLI MOTD GET cannot carry query parameters');
    bodylessPublicHeaders31(request.headers,CLI_MOTD_HOST,'CLI MOTD GET');
  }
  if(u.hostname==='firestore.googleapis.com'){firestoreLocationRead31(u,(request.method??'GET').toUpperCase(),raw);need(request.body===undefined||request.body===null,'Firestore location GET cannot carry a body');}
  return u;
}
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
  if(url.hostname===CLI_MOTD_HOST||base.hostname===CLI_MOTD_HOST||base.host===CLI_MOTD_HOST){
    need(url.hostname===CLI_MOTD_HOST,'CLI MOTD destination override refused');
    need(merged.port===undefined||merged.port===null||merged.port==='','CLI MOTD explicit port refused');
    motdRequest31(url,merged.method??'GET',raw);
    if(fromUrl)motdRequest31(new URL(input),merged.method??'GET',typeof input==='string'?input:input.href);
    for(const key of ['protocol','hostname','host','port','path','method'])if(Object.hasOwn(base,key)&&Object.hasOwn(overrides,key))need(base[key]===overrides[key],'CLI MOTD request option differs: '+key);
    need(!merged.host||merged.host===CLI_MOTD_HOST,'CLI MOTD host option differs');
    need(!merged.search&&!merged.hash,'CLI MOTD query or fragment refused');
    bodylessPublicHeaders31(merged.headers,CLI_MOTD_HOST,'CLI MOTD GET');
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
    this.discoveryRequired=false;this.discoveryRows=[];this.motdRequested=false;this.motdAccepted=false;this.motdFailed=false;this.motdCompletion=null;this.motdResolve=null;
  }
  preparedMatches(capture){need(!this.prepared,'CLI preparation may be captured only once');need(capture.sourceArchiveHash===this.sourceArchiveHash,'Prepared source hash differs');eq(capture.endpointRuntimeHashes,this.endpointRuntimeHashes,'Prepared endpoint labels differ');need(/^[A-F0-9]{64}$/.test(capture.archiveSha256)&&Number.isSafeInteger(capture.archiveBytes)&&capture.archiveBytes>0,'Independently verified actual ZIP binding required');this.archiveSha256=capture.archiveSha256;this.archiveBytes=capture.archiveBytes;this.prepared=true;}
  read(url,method){
    need(url.protocol==='https:'&&!url.username&&!url.password&&!url.port,'HTTPS Google API origin required');
    need(!identityAttempt31(url),'Service identity requires its exact guarded write path');
    if(cliTokenRequest31(url,method)||(url.hostname==='oauth2.googleapis.com'&&method==='POST'&&['/token','/oauth2/v4/token'].includes(url.pathname)))return {kind:'credential-refresh'};
    if(motdRequest31(url,method))return {kind:'cli-motd'};
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
    if(url.hostname===CLI_MOTD_HOST){
      need(!this.motdRequested&&!this.prepared&&!this.identityRequests.size,'CLI MOTD request retry or late initialization refused');
      const operation={...this.read(url,method),url:url.href,method};this.motdRequested=true;
      this.motdCompletion=new Promise(resolve=>{this.motdResolve=resolve;});return operation;
    }
    if(identityAttempt31(url)) {
      identityUrl31(url);
      this.assertInitializationSettled31();
      this.assertDiscoveryStopped31();
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
    if(operation.kind==='cli-motd'){
      need(result?.status===200&&result.body&&Object.getPrototypeOf(result.body)===Object.prototype,'Complete original public CLI MOTD object required');
      assertMotdVersion31(result?.body);
      need(!this.motdFailed,'CLI MOTD initialization already failed');this.finishMotd31(true);
      this.events.push({kind:'cli-motd',method:'GET',host:CLI_MOTD_HOST,path:'/cli.json',status:Number.isInteger(result?.status)?result.status:null});return;
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
  finishMotd31(accepted){
    if(!accepted)this.motdFailed=true;this.motdAccepted=accepted&&!this.motdFailed;
    if(this.motdResolve){this.motdResolve(this.motdAccepted);this.motdResolve=null;}
  }
  assertInitializationSettled31(){need(!this.motdRequested||(this.motdAccepted&&!this.motdFailed),'CLI MOTD must settle with an accepted minimum version before identity');}
  async awaitInitialization31(){
    if(!this.motdRequested)return;
    let timer;
    const okay=await Promise.race([this.motdCompletion,new Promise(resolve=>{timer=setTimeout(()=>resolve(false),15000);})]);
    clearTimeout(timer);if(!okay)this.finishMotd31(false);this.assertInitializationSettled31();
  }
  requireDiscovery31(assertOwned){
    need(!this.discoveryRequired&&!this.prepared&&!this.identityRequests.size&&typeof assertOwned==='function','Fresh owned discovery lifecycle required');
    this.discoveryRequired=true;this.discoveryAssertOwned=assertOwned;this.discoveryRefused=false;
  }
  registerDiscovery31(child,port){
    need(this.discoveryRequired&&!this.prepared&&!this.identityRequests.size,'Discovery must precede identity and preparation');
    this.discoveryAssertOwned();
    need(typeof port==='string'&&/^[1-9][0-9]{3,4}$/.test(port)&&Number(port)>=1024&&Number(port)<=65535,'Exact unprivileged discovery port required');
    need(this.discoveryRows.length===0&&child&&Number.isSafeInteger(child.pid)&&child.pid>0&&typeof child.once==='function'&&child.exitCode===null&&child.signalCode===null,'One actual running owned discovery child required');
    const row={child,port,shutdownAdmitted:false,shutdownStatus:null,shutdownEnded:false,exited:false,failed:false,settled:false};
    child.once('exit',()=>{row.exited=true;});child.once('error',()=>{row.failed=true;});this.discoveryRows.push(row);
    this.events.push({kind:'discovery-started',port:Number(port),pid:child.pid});return row;
  }
  claimDiscoveryShutdown31(url,method){
    try{
      need(this.discoveryRequired&&!this.prepared&&!this.identityRequests.size,'Discovery shutdown must precede identity and preparation');this.discoveryAssertOwned();
      const row=this.discoveryRows.find(row=>url.href==='http://localhost:'+row.port+'/__/quitquitquit');
      need(method==='GET'&&row&&!row.exited&&!row.failed&&!row.shutdownAdmitted,'Only the exact running owned discovery shutdown GET is admitted once');
      row.shutdownAdmitted=true;this.events.push({kind:'discovery-shutdown-admitted',method:'GET',host:'localhost',path:'/__/quitquitquit',port:Number(row.port)});return row;
    }catch(error){this.discoveryRefused=true;throw error;}
  }
  settleDiscovery31(child){
    this.discoveryAssertOwned();const row=this.discoveryRows.find(row=>row.child===child);
    need(row&&!row.failed&&row.exited&&child.exitCode===0&&child.signalCode===null&&row.shutdownAdmitted&&row.shutdownStatus===200&&row.shutdownEnded,'Discovery must shut down successfully and exit before identity');
    row.settled=true;this.events.push({kind:'discovery-stopped',port:Number(row.port),pid:child.pid});
  }
  assertDiscoveryStopped31(){
    // Pure saved-response replay does not claim a live process lifecycle. The
    // operational phase always installs this requirement before real CLI entry.
    if(!this.discoveryRequired)return;
    this.discoveryAssertOwned();need(!this.discoveryRefused&&this.discoveryRows.length===1&&this.discoveryRows.every(row=>row.settled&&row.exited&&!row.failed),'Owned discovery shutdown must complete before identity');
  }
  assertComplete(){eq([...this.mutations].filter(x=>this.names.includes(x)).sort(),[...this.names].sort(),'Every exact cohort Function must update once');need(this.prepared,'Actual preparation was not captured');}
}

function installDiscoveryLifecycle31({Delegate,guard,sourceDirectory,projectId}){
  need(projectId===PROJECT&&typeof sourceDirectory==='string'&&path.isAbsolute(sourceDirectory),'Exact discovery project/source required');
  need(guard instanceof RuntimeDeploymentTransportGuard31&&!guard.discoveryRequired&&!guard.prepared&&!guard.identityRequests.size,'Fresh live discovery guard required');
  const proto=Delegate?.prototype,slots=['spawnFunctionsProcess','serveAdmin'];
  const originals=slots.map(key=>Object.getOwnPropertyDescriptor(proto,key));
  need(originals.every(d=>d&&typeof d.value==='function'&&d.writable&&d.configurable),'Owned pinned CLI discovery methods required');
  const normalize=value=>process.platform==='win32'?path.resolve(value).toLowerCase():path.resolve(value);
  const expected=normalize(sourceDirectory);let restored=false;
  const checkDelegate=value=>need(value.projectId===PROJECT&&typeof value.sourceDir==='string'&&normalize(value.sourceDir)===expected,'Discovery child must use the exact selected Functions source');
  const installed=[];
  const lease={assertOwned(){need(!restored&&slots.every((key,i)=>require('node:util').isDeepStrictEqual(Object.getOwnPropertyDescriptor(proto,key),installed[i])),'Discovery method ownership changed');},
    restore(){if(restored)return;lease.assertOwned();slots.forEach((key,i)=>Object.defineProperty(proto,key,originals[i]));restored=true;}};
  const spawn=function(config,env){
    lease.assertOwned();checkDelegate(this);need(env&&typeof env.PORT==='string'&&!env.FUNCTIONS_MANIFEST_OUTPUT_PATH,'Only the selected HTTP discovery route is admitted');
    need(/^[1-9][0-9]{3,4}$/.test(env.PORT)&&Number(env.PORT)>=1024&&Number(env.PORT)<=65535&&guard.discoveryRows.length===0&&!guard.prepared&&!guard.identityRequests.size,'One fresh bounded discovery port required before spawn');
    const child=originals[0].value.apply(this,arguments);guard.registerDiscovery31(child,env.PORT);return child;
  };
  const serve=async function(config,env,port){
    lease.assertOwned();checkDelegate(this);const stop=await originals[1].value.apply(this,arguments);
    const row=guard.discoveryRows.find(value=>value.port===port);need(row&&typeof stop==='function','Original discovery stop callback required');
    return async function(){lease.assertOwned();try{await stop();guard.settleDiscovery31(row.child);}catch(error){row.failed=true;throw error;}};
  };
  installed.push({...originals[0],value:spawn},{...originals[1],value:serve});
  slots.forEach((key,i)=>Object.defineProperty(proto,key,installed[i]));guard.requireDiscovery31(()=>lease.assertOwned());return lease;
}

function installNetworkBoundary31(guard){
  // Only the actual checked apiv2 write path is admitted. Other mutation
  // transports and direct sockets are refused; no request is faked successful.
  for(const mod of ['node:https','node:http']){
    const api=require(mod),original=api.request;
    api.request=function(input,options,callback){
      const effective=effectiveRequest31(input,options,mod==='node:https'?'https:':'http:'),u=effective.url,method=effective.method,admitted=context.getStore();
      let networkOperation=admitted,discovery=null;
      if(admitted?.kind==='existing-service-identity'){guard.assertInitializationSettled31();guard.assertDiscoveryStopped31();}
      if(admitted?.kind==='credential-refresh'){
        credentialDebugLease?.assertOwned();
        need(u.href===admitted.url&&method===admitted.method,'Credential-refresh method or redirect changed');
        need(!admitted.transportUsed,'Credential-refresh transport retry or redirect refused');
        admitted.transportUsed=true;
      }
      if(u.protocol==='http:'){
        if(u.pathname==='/__/quitquitquit'){
          if(typeof input==='string')need(input===u.href,'Exact owned discovery shutdown URL required');
          discovery=guard.claimDiscoveryShutdown31(u,method);networkOperation={kind:'discovery-shutdown',url:u.href,method};
        }else need(['127.0.0.1','localhost','[::1]'].includes(u.hostname)&&method==='GET'&&['/__/functions.yaml','/__/health'].includes(u.pathname),'Only local Functions discovery is allowed over HTTP');
      }
      else if(u.hostname===CLI_MOTD_HOST){
        need(admitted?.kind==='cli-motd'&&u.href===admitted.url&&method===admitted.method,'CLI MOTD requires its checked unauthenticated Client context');
        need(!admitted.transportUsed,'CLI MOTD transport retry or redirect refused');admitted.transportUsed=true;
      }
      else if(AUTH_HOSTS.has(u.hostname)&&method==='POST'){
        credentialDebugLease?.assertOwned();
        const operation=guard.read(u,method);
        if(admitted?.kind!=='credential-refresh')networkOperation={...operation,url:u.href,method,transportUsed:true};
      }
      else if(!admitted)guard.read(u,method);
      else need(u.href===admitted.url&&method===admitted.method,'Cloud request method/query/redirect changed');
      const bodylessFirestore=u.href===FIRESTORE_LOCATION_URL&&method==='GET';
      const bodylessMotd=u.href===CLI_MOTD_URL&&method==='GET';
      const bodylessLabel=bodylessMotd?'CLI MOTD GET':discovery?'Owned discovery shutdown GET':'Firestore location GET';
      const checkedHeaders=headers=>bodylessFirestore?firestoreLocationHeaders31(headers):bodylessPublicHeaders31(headers,bodylessMotd?CLI_MOTD_HOST:'localhost:'+discovery.port,bodylessLabel);
      if(bodylessFirestore)firestoreLocationHeaders31({...((input instanceof URL||typeof input==='string')?{}:input),...(options&&typeof options==='object'?options:{})}.headers);
      if(bodylessMotd||discovery)checkedHeaders({...((input instanceof URL||typeof input==='string')?{}:input),...(options&&typeof options==='object'?options:{})}.headers);
      const write=admitted&&!['read','credential-refresh','cli-motd'].includes(admitted.kind)&&!(AUTH_HOSTS.has(u.hostname)&&method==='POST');
      if(write){need(!admitted.transportUsed,'Automatic cloud mutation transport retry refused');admitted.transportUsed=true;}
      const args=arguments,receiver=this;const request=context.run({...networkOperation,networkVerified:true},()=>original.apply(receiver,args));
      if(discovery){
        request.once('error',()=>{discovery.failed=true;});
        request.prependOnceListener('response',response=>{
          discovery.shutdownStatus=response.statusCode;
          response.once('end',()=>{discovery.shutdownEnded=true;});
          response.once('aborted',()=>{discovery.failed=true;});response.once('error',()=>{discovery.failed=true;});
        });
      }
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
      if(bodylessFirestore||bodylessMotd||discovery){
        let refused=false;
        const headers=()=>{checkedHeaders(request.getHeaders());need(request.useChunkedEncodingByDefault!==true&&request.chunkedEncoding!==true,bodylessLabel+' cannot use chunked body framing');};
        const checked=action=>{try{need(!refused,bodylessLabel+' was already refused');headers();return action();}catch(error){refused=true;if(discovery)discovery.failed=true;request.destroy();throw error;}};
        const empty=chunk=>typeof chunk==='string'?chunk.length===0:chunk instanceof Uint8Array&&chunk.byteLength===0;
        const originalWrite=request.write,originalEnd=request.end,originalFlush=request.flushHeaders;
        request.write=function(chunk){const args=arguments,receiver=this;return checked(()=>{need(empty(chunk),bodylessLabel+' cannot carry a wire body');return originalWrite.apply(receiver,args);});};
        request.end=function(chunk){const args=arguments,receiver=this;return checked(()=>{need(chunk===undefined||chunk===null||typeof chunk==='function'||empty(chunk),bodylessLabel+' cannot carry a wire body');return originalEnd.apply(receiver,args);});};
        request.flushHeaders=function(){const args=arguments,receiver=this;return checked(()=>originalFlush.apply(receiver,args));};
        for(const name of ['setHeader','appendHeader']){const originalHeader=request[name];request[name]=function(key,value){const args=arguments,receiver=this;return checked(()=>{checkedHeaders({[key]:value});const result=originalHeader.apply(receiver,args);headers();return result;});};}
        request.addTrailers=()=>checked(()=>{throw Error(bodylessLabel+' cannot carry trailers');});
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
  Client.prototype.request=async function(request){
    if(identityAttempt31(urlOf(this,request)))await guard.awaitInitialization31();
    const operation=guard.before(this,request);if(!['read','credential-refresh','cli-motd'].includes(operation.kind)){operation.sequence=++guard.sequence;operation.bodySha256=operation.kind==='existing-service-identity'?hash(Buffer.from('{}')):bodyBinding31(request);await beforeWrite(operation);}
    const credential=operation.kind==='credential-refresh';
    if(credential){credentialDebugLease?.assertOwned();credentialRefreshInFlight++;}
    try{const result=await context.run(operation,()=>original.call(this,{...request,retryCodes:[],retries:0,...(operation.kind==='cli-motd'?{timeout:15000}:{})}));guard.after(operation,result);return result;}
    catch(error){if(operation.kind==='cli-motd')guard.finishMotd31(false);throw error;}
    finally{if(credential)credentialRefreshInFlight--;}
  };
}
module.exports={PINNED_CLI_VERSION,ONE_DAY_MS,compareVersions31,assertMotdVersion31,inspectMotdCache31,existingServiceIdentityBindings31,verifyServiceIdentityResponse31,RuntimeDeploymentTransportGuard31,installApiBoundary31,installNetworkBoundary31,installCredentialRefreshDebugBoundary31,installDiscoveryLifecycle31,safeRequestMetadata31,urlOf,leaves,effectiveRequest31,bodyBinding31};
