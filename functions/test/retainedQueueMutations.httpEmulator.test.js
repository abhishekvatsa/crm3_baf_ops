/** Real Auth tokens -> exported callable HTTP -> canonical Firestore.
 * Opt-in, isolated loopback demo only; never clears a database. */
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {typeRecord,templateRecord,executionRecord,command}=require('./helpers/retainedQueueFixtures.cjs');
const base=process.env.CF01_HTTP_EMULATOR_URL;
const suite=base?describe:describe.skip;
suite('CF01 authenticated HTTP boundary',()=>{
  let app, db, actors={};
  const projectId=process.env.GCLOUD_PROJECT;
  const prefix=`cf01-${Date.now()}`;
  const invoke=async(actor,cmd,{v1=false,origin=actor?.uid}={})=>{
    const response=await fetch(`${base}/${projectId}/asia-south1/executeMaintenanceWorkflowCommand${v1?'':'V2'}`,{
      method:'POST',headers:{'Content-Type':'application/json',...(actor?{Authorization:`Bearer ${actor.token}`}:{})},
      body:JSON.stringify({data:v1?cmd:{protocolVersion:2,originActorUid:origin,command:cmd}}),
      signal:AbortSignal.timeout(60000)});
    return response.json();
  };
  const accepted=async(actor,cmd)=>{const result=await invoke(actor,cmd);expect(result.error).toBeUndefined();expect(result.result).toBeDefined();return result.result;};
  const make=(type,record,id)=>command(type,record,{projectId,commandId:`${prefix}-${id}`});
  const value=(v)=>v===null?{nullValue:null}:typeof v==='string'?{stringValue:v}:typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?{integerValue:String(v)}:Array.isArray(v)?{arrayValue:{values:v.map(value)}}:{mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,value(x)]))}};
  beforeAll(async()=>{
    if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(base)||!projectId?.startsWith('demo-')||
      !/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST||'')||
      !/^127\.0\.0\.1:\d+$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST||'')) throw Error('Isolated loopback demo emulators are required.');
    app=initializeApp({projectId},prefix);db=getFirestore(app);
    for(const [name,role] of [['admin','admin'],['admin2','admin'],['si','si'],['worker','contractSupervisor'],['worker2','contractSupervisor'],['ops','operations']]){
      const response=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only`,{
        method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`${prefix}-${name}@example.invalid`,password:'synthetic-test-only',returnSecureToken:true})});
      const auth=await response.json();if(!auth.idToken)throw Error(`Auth fixture failed for ${name}`);
      actors[name]={uid:auth.localId,token:auth.idToken};
      await db.doc(`users/${auth.localId}`).set({isApproved:true,roles:[role],name:`Synthetic ${name}`});
    }
  },120000);
  afterAll(async()=>{if(app)await deleteApp(app);});
  test.each([
    ['upsertAbnormalityType','abnormality_types','admin','admin2',typeRecord],
    ['upsertLegacyJobTemplate','job_templates','si','admin2',templateRecord],
    ['updateJobExecutionWork','job_executions','worker','worker2',executionRecord],
  ])('%s refuses same-role account switch, accepts original once, retains replay evidence',async(type,collection,owner,other,factory)=>{
    const record=factory(`${prefix}-${collection}`,actors[owner].uid);
    if(type==='updateJobExecutionWork'){
      await db.doc(`${collection}/${record.firestoreId}`).set({...record,createdAt:Timestamp.fromDate(new Date('2026-09-27T00:00:00.123Z'))});
      record.createdAt='2026-09-27T00:00:00.123000Z';record.version=2;record.remarks='Saved by original actor';
    }
    const cmd=make(type,record,collection);
    expect((await invoke(actors[other],cmd,{origin:actors[owner].uid})).error).toMatchObject({status:'PERMISSION_DENIED',details:{reasonCode:'origin-bound-actor-mismatch'}});
    expect((await invoke(actors[owner],cmd,{v1:true})).error).toMatchObject({status:'FAILED_PRECONDITION',details:{reasonCode:'retained-queue-v2-required'}});
    const first=await accepted(actors[owner],cmd);
    expect(first.result).toEqual({collection,recordId:record.firestoreId,record});
    const audit=db.doc(`audit_logs/server_cf01_${cmd.commandId}`);
    const auditBefore=await audit.get();expect(auditBefore.data().performedByUid).toBe(actors[owner].uid);
    expect(auditBefore.data()).toMatchObject({entityType:({abnormality_types:'abnormality_type',job_templates:'job_template',job_executions:'job_execution'})[collection],
      entityId:record.firestoreId,severity:'low',action:type==='updateJobExecutionWork'?'update':'create'});
    expect(auditBefore.data().timestamp).toBeInstanceOf(Timestamp);
    expect(auditBefore.data().timestamp.toMillis()).toBe(Date.parse(first.appliedAt));
    expect((await db.doc(`${collection}/${record.firestoreId}`).get()).data().version).toBe(record.version);
    // A later accepted/current document cannot replace original receipt evidence.
    await db.doc(`${collection}/${record.firestoreId}`).update({version:record.version+7});
    expect(await accepted(actors[owner],cmd)).toEqual(first);
    expect((await audit.get()).updateTime.isEqual(auditBefore.updateTime)).toBe(true);
    expect((await invoke(actors[owner],{...cmd,payload:{...cmd.payload,projectId:'demo-wrong-project'}})).error).toMatchObject({status:'PERMISSION_DENIED',details:{reasonCode:'retained-queue-project-mismatch'}});
    expect((await invoke(actors[owner],{...cmd,payload:{...cmd.payload,record:{...record,updatedAt:'2026-09-27T00:02:00.000000Z'}}})).error.status).toBe('ABORTED');
    expect((await invoke(actors[other],cmd)).error.status).toBe('PERMISSION_DENIED');
    await db.doc(`users/${actors[owner].uid}`).update({isApproved:false});
    expect((await invoke(actors[owner],cmd)).error.status).toBe('PERMISSION_DENIED');
    await db.doc(`users/${actors[owner].uid}`).update({isApproved:true});
    expect(await accepted(actors[owner],cmd)).toEqual(first);
  },120000);
  test('fresh wrong-role and forged work identity are refused without receipt',async()=>{
    const id=`${prefix}-negative`, type=make('upsertAbnormalityType',typeRecord(id,actors.ops.uid),'wrong-role');
    expect((await invoke(actors.ops,type)).error.status).toBe('PERMISSION_DENIED');
    const original=executionRecord(id);await db.doc(`job_executions/${id}`).set(original);
    const cmd=make('updateJobExecutionWork',{...original,version:2,assetNumber:999},'forged-work');
    expect((await invoke(actors.worker,cmd)).error.status).toBe('PERMISSION_DENIED');
    expect((await db.doc(`job_executions/${id}`).get()).data()).toEqual(original);
    expect((await db.doc(`audit_logs/server_cf01_${cmd.commandId}`).get()).exists).toBe(false);
  },120000);
  test.each([
    ['abnormality_types','admin',typeRecord],['job_templates','si',templateRecord],['job_executions','worker',executionRecord],
  ])('Rules deny same-role direct %s update and permit approved read',async(collection,owner,factory)=>{
    const record=factory(`${prefix}-raw-${collection}`,actors[owner].uid);
    await db.doc(`${collection}/${record.firestoreId}`).set(record);
    const url=`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${projectId}/databases/(default)/documents/${collection}/${record.firestoreId}`;
    const headers={Authorization:`Bearer ${actors[owner].token}`,'Content-Type':'application/json'};
    const response=await fetch(url,{method:'PATCH',headers,body:JSON.stringify({fields:value({...record,version:2}).mapValue.fields})});
    expect(response.status).toBe(403);
    expect((await fetch(url,{headers})).status).toBe(200);
    expect((await db.doc(`${collection}/${record.firestoreId}`).get()).data()).toEqual(record);
  },120000);
});
