"use strict";
// Separate pre-comparison evidence; never a prepared upload/function transcript.
const {AsyncLocalStorage}=require("node:async_hooks");
const {isDeepStrictEqual:same,TextDecoder}=require("node:util");
const zlib=require("node:zlib");
const neutral=require("./runtimeDeploymentTransportGuard31.cjs");
const {need,hash,time}=require("./backendRuntimeAdmission31.cjs").helpers;
const RESPONSE_LIMIT=16*1024*1024;
const instant=value=>{need(typeof value==="string"&&/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value)&&new Date(value).toISOString()===value,"Exact identity observation time required");return value;};
function admitServiceIdentity31(operation,{currentControls,verifyControls,assertClean,assertWindow}) {
  need(operation.kind==="existing-service-identity"&&currentControls,"Verified current controls required before service identity");
  verifyControls(currentControls);assertClean();assertWindow();
  return currentControls;
}
function decode(bytes,encoding) {
  need([null,"","identity","gzip","deflate","br"].includes(encoding),"Unsupported identity response encoding");
  let decoded=bytes;
  if(encoding==="gzip")decoded=zlib.gunzipSync(bytes,{maxOutputLength:RESPONSE_LIMIT});
  if(encoding==="deflate")decoded=zlib.inflateSync(bytes,{maxOutputLength:RESPONSE_LIMIT});
  if(encoding==="br")decoded=zlib.brotliDecompressSync(bytes,{maxOutputLength:RESPONSE_LIMIT});
  need(decoded.length<=RESPONSE_LIMIT,"Identity response exceeds bound");
  return new TextDecoder("utf-8",{fatal:true}).decode(decoded);
}
function installServiceIdentityCapture31({Client,guard,phase,source,approvalPointer,baselinePointer,assertAdmission,assertWindow,save,now=()=>new Date().toISOString()}) {
  const local=new AsyncLocalStorage(),rows=[];let pending=0,failed=false,finished=false,refusals=0,queue=Promise.resolve();
  const at=()=>instant(now()),window=()=>instant(assertWindow());
  function finalize(item,apiSuccess,result) {
    need(!item.finalized&&pending>0,"Identity capture finalized twice");item.finalized=true;
    const row=item.row;
    try {
      row.completedAtUtc=at();
      row.wireBody=save(item.prefix+"-wire.bin",Buffer.concat(item.wire));
      const raw=Buffer.concat(item.response),responseRaw=save(item.prefix+"-response-wire.bin",raw);
      let bodyText=null;try{if(item.responseEnded)bodyText=decode(raw,item.encoding);}catch{item.captureError=true;}
      if(bodyText!==null&&Number.isSafeInteger(item.status))row.response=save(item.prefix+"-response.json",{httpStatus:item.status,bodyText});
      row.responseBinding=save(item.prefix+"-wire-response-binding.json",{responseRaw,contentEncoding:item.encoding,responseComplete:item.responseEnded,retainedBytes:raw.length,httpStatus:item.status??null});
      let okay=apiSuccess&&!item.captureError&&item.transports===1&&item.wireEnded&&item.responseEnded&&item.status>=200&&item.status<300&&row.response!==null&&hash(Buffer.concat(item.wire))===item.operation.bodySha256;
      // Retain even an invalid response above, before replaying any response predicate.
      if(okay)try{const body=JSON.parse(bodyText);need(same(body,result.body),"API result differs from retained identity response");neutral.verifyServiceIdentityResponse31(item.operation,{body});}catch{okay=false;}
      if(!okay){failed=true;row.error={code:"EXISTING_IDENTITY_NOT_PROVEN",apiSucceeded:apiSuccess,responseReceived:item.responseEnded,requestComplete:item.wireEnded};}
      item.success=okay;item.pointer=save(item.prefix+".json",row);return okay;
    }catch(error){failed=true;throw error;}finally{pending--;item.wire=[];item.response=[];}
  }
  for(const api of [require("node:https"),require("node:http")]) {
    const request=api.request;
    api.request=function(...args) {
      const candidate=local.getStore()?.item,effective=neutral.effectiveRequest31(args[0],args[1],api===require("node:https")?"https:":"http:");
      const item=candidate&&effective.url.href===candidate.operation.url&&effective.method===candidate.operation.method?candidate:null;
      if(item){need(!failed&&!finished,"Identity capture failed before physical request");guard.assertInitializationSettled31();guard.assertDiscoveryStopped31();need(++item.transports===1,"Second identity transport refused");item.row.requestAdmittedAtUtc=window();}
      const req=request.apply(this,args);if(!item)return req;
      const write=req.write,end=req.end;let sent=false;
      function first(){if(!sent){try{need(!failed&&!finished,"Identity capture failed before first outbound bytes");guard.assertInitializationSettled31();guard.assertDiscoveryStopped31();item.row.firstOutboundAtUtc=window();}catch(error){failed=true;item.captureError=true;req.destroy(error);throw error;}sent=true;}}
      function retain(chunk){if(chunk===undefined||chunk===null)return;need(Buffer.isBuffer(chunk),"Original identity wire must be bytes");need(item.wireBytes+chunk.length<=2,"Identity body exceeds exact empty-object size");item.wire.push(Buffer.from(chunk));item.wireBytes+=chunk.length;}
      req.write=function(chunk,...rest){retain(chunk);first();return write.call(this,chunk,...rest);};
      req.end=function(chunk,...rest){retain(chunk);first();item.wireEnded=true;return end.call(this,chunk,...rest);};
      req.prependListener("response",res=>{
        item.status=res.statusCode;item.encoding=res.headers?.["content-encoding"]??null;
        res.prependListener("data",chunk=>{if(!Buffer.isBuffer(chunk)||item.responseBytes+chunk.length>RESPONSE_LIMIT){item.captureError=true;res.destroy(Error("Identity response bound/type refused"));return;}item.response.push(Buffer.from(chunk));item.responseBytes+=chunk.length;});
        res.prependListener("end",()=>{item.responseEnded=true;});
        res.on("aborted",()=>{item.captureError=true;});res.on("error",()=>{item.captureError=true;});
      });return req;
    };
  }
  neutral.installNetworkBoundary31(guard);
  neutral.installApiBoundary31(Client,guard,operation=>{
    const scope=local.getStore();need(scope,"Identity capture context missing");
    const run=queue.then(async()=>{
      need(!failed&&!finished&&operation.kind==="existing-service-identity","Only existing identities may write before preparation");
      const currentControls=await assertAdmission(operation);need(currentControls,"Current control evidence required");
      need(!failed&&!finished,"Identity capture failed during admission");guard.assertInitializationSettled31();guard.assertDiscoveryStopped31();
      window();const startedAtUtc=at(),sequence=rows.length+1;need(sequence<=2&&operation.sequence===sequence,"Identity initiation count differs");
      const request={client:{urlPrefix:scope.client.opts.urlPrefix,apiVersion:scope.client.opts.apiVersion??""},
        request:{method:scope.request.method,path:scope.request.path,queryParams:scope.request.queryParams??null,body:structuredClone(scope.request.body),
          headers:{"x-goog-user-project":scope.request.headers["x-goog-user-project"]}}};
      const prefix="service-identity-"+String(sequence).padStart(2,"0"),row={schemaVersion:1,documentType:"build31-existing-service-identity",phase,sequence,
        service:operation.service,startedAtUtc,requestAdmittedAtUtc:null,firstOutboundAtUtc:null,completedAtUtc:null,currentControls,
        request:save(prefix+"-request.json",request),wireBody:null,response:null,responseBinding:null,error:null};
      const item={row,prefix,operation,wire:[],wireBytes:0,response:[],responseBytes:0,encoding:null,wireEnded:false,responseEnded:false,transports:0};
      scope.item=item;rows.push(item);pending++;
      save(prefix+"-intent.json",{phase,source,approvalPointer,baselinePointer,sequence,service:operation.service,startedAtUtc,currentControls,request:row.request});
    });
    queue=run.catch(()=>{});return run;
  });
  const guarded=Client.prototype.request;
  Client.prototype.request=function(request) {
    const scope={client:this,request};
    return local.run(scope,async()=>{
      let result,success=false;
      try{result=await guarded.call(this,request);success=true;return result;}
      catch(error){failed=true;if(!scope.item)save("service-identity-refusal-"+(++refusals)+".json",{phase,observedAtUtc:at(),code:"PREPARATION_REQUEST_REFUSED",rawErrorRetained:false,...neutral.safeRequestMetadata31(this,request)});throw error;}
      finally{if(scope.item){const okay=finalize(scope.item,success,result);if(success&&!okay)throw Error("Incomplete original identity response");}}
    });
  };
  return {finish() {
    need(!finished&&!failed&&pending===0&&rows.length===2&&rows.every(item=>item.success),"Two complete original identity requests required");
    guard.assertExistingServiceIdentitiesComplete();finished=true;
    return save("service-identities-complete.json",{schemaVersion:1,documentType:"build31-existing-service-identities-complete",phase,source,approvalPointer,baselinePointer,
      records:rows.map(item=>item.pointer),completedAtUtc:at(),historicalUniqueIdContinuityClaimed:false,error:null});
  }};
}
function replayServiceIdentityCapture31({pointer,read,readBytes,verifyResponse,guardInputs,phase,source,approvalPointer,baselinePointer,currentControls,executionWindow,earliestUtc,latestUtc}) {
  const completion=read(pointer),expected=["schemaVersion","documentType","phase","source","approvalPointer","baselinePointer","records","completedAtUtc","historicalUniqueIdContinuityClaimed","error"];
  need(same(Object.keys(completion).sort(),expected.sort())&&completion.schemaVersion===1&&completion.documentType==="build31-existing-service-identities-complete"&&completion.phase===phase&&completion.error===null&&completion.historicalUniqueIdContinuityClaimed===false,"Exact separate identity completion required");
  need(same(completion.source,source)&&same(completion.approvalPointer,approvalPointer)&&same(completion.baselinePointer,baselinePointer),"Identity authority/baseline differs");
  need(Array.isArray(completion.records)&&completion.records.length===2,"Two identity originals required");
  const guard=new neutral.RuntimeDeploymentTransportGuard31({...guardInputs,phase});let previous=instant(earliestUtc),last=previous;
  const windowStart=time(executionWindow.notBeforeUtc),windowEnd=time(executionWindow.notAfterUtc);
  for(const [index,p] of completion.records.entries()) {
    const row=read(p),keys=["schemaVersion","documentType","phase","sequence","service","startedAtUtc","requestAdmittedAtUtc","firstOutboundAtUtc","completedAtUtc","currentControls","request","wireBody","response","responseBinding","error"];
    need(same(Object.keys(row).sort(),keys.sort())&&row.schemaVersion===1&&row.documentType==="build31-existing-service-identity"&&row.phase===phase&&row.sequence===index+1&&row.error===null,"Identity original shape/order differs");
    need(same(row.currentControls,currentControls),"Identity current control evidence differs");
    const start=instant(row.startedAtUtc),admitted=instant(row.requestAdmittedAtUtc),outbound=instant(row.firstOutboundAtUtc),ended=instant(row.completedAtUtc);
    need(previous<=start&&windowStart<=time(start)&&start<=admitted&&admitted<=outbound&&time(outbound)<=windowEnd&&outbound<=ended&&ended<=latestUtc,"Identity initiation/settlement chronology differs");previous=start;if(last<ended)last=ended;
    const saved=read(row.request);
    need(same(Object.keys(saved).sort(),["client","request"])&&same(Object.keys(saved.client).sort(),["apiVersion","urlPrefix"])&&same(Object.keys(saved.request).sort(),["body","headers","method","path","queryParams"]),"Identity request shape differs");
    const operation=guard.before({opts:saved.client},saved.request);
    need(operation.kind==="existing-service-identity"&&operation.service===row.service&&readBytes(row.wireBody).equals(Buffer.from("{}")),"Identity kind/service/wire differs");
    const response=verifyResponse(row.response,row.responseBinding);
    guard.after(operation,{body:JSON.parse(response.bodyText)});
  }
  guard.assertExistingServiceIdentitiesComplete();
  need(last<=instant(completion.completedAtUtc)&&completion.completedAtUtc<=latestUtc,"Identity completion chronology differs");
  return completion;
}
module.exports={admitServiceIdentity31,installServiceIdentityCapture31,replayServiceIdentityCapture31};
