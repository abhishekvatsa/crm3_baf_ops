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
  const waitForStamped=async(path,record,previousStamp)=>{
    // The real trigger asynchronously adds its pull watermark. Establish the
    // full canonical baseline after that legitimate write, then compare every
    // field (including the watermark) across each refused mutation.
    const deadline=Date.now()+15000;
    while(Date.now()<deadline) {
      const data=(await db.doc(path).get()).data();
      if(data?._globalPullServerUpdatedAt instanceof Timestamp &&
          (!previousStamp || !data._globalPullServerUpdatedAt.isEqual(previousStamp))) {
        expect(data).toEqual({...record,_globalPullServerUpdatedAt:data._globalPullServerUpdatedAt});
        return data;
      }
      await new Promise(resolve=>setTimeout(resolve,50));
    }
    throw Error('Synthetic canonical fixture did not receive its server pull stamp.');
  };
  const seedStamped=async(path,record)=>{
    await db.doc(path).set(record);
    return waitForStamped(path,record);
  };
  const value=(v)=>v===null?{nullValue:null}:typeof v==='string'?{stringValue:v}:typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?{integerValue:String(v)}:Array.isArray(v)?{arrayValue:{values:v.map(value)}}:{mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,value(x)]))}};
  beforeAll(async()=>{
    if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(base)||!projectId?.startsWith('demo-')||
      !/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST||'')||
      !/^127\.0\.0\.1:\d+$/.test(process.env.FIREBASE_AUTH_EMULATOR_HOST||'')) throw Error('Isolated loopback demo emulators are required.');
    app=initializeApp({projectId},prefix);db=getFirestore(app);
    for(const [name,role] of [['admin','admin'],['admin2','admin'],['catalogueAuthor','admin'],['catalogueEditor','admin'],['historicalEditor','admin'],['paddedEditor','admin'],['paddedTemplateSi','si'],['paddedTemplateAdmin','admin'],['si','si'],['worker','contractSupervisor'],['worker2','contractSupervisor'],['omissionWorker','contractSupervisor'],['representationWorker','contractSupervisor'],['ops','operations']]){
      const response=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only`,{
        method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`${prefix}-${name}@example.invalid`,password:'synthetic-test-only',returnSecureToken:true})});
      const auth=await response.json();if(!auth.idToken)throw Error(`Auth fixture failed for ${name}`);
      // This suite shares the CI emulators with the later Android journeys.
      // Leave complete AppUser records, including after authority negatives.
      const profile={name:`Synthetic ${name}`,email:`${prefix}-${name}@example.invalid`,
        isApproved:true,roles:[role],accessDisposition:'approved',authorityRevision:1,
        createdAt:Timestamp.now(),photoUrl:null,fcmToken:null};
      actors[name]={uid:auth.localId,token:auth.idToken,profile};
      await db.doc(`users/${auth.localId}`).set(profile);
    }
  },120000);
  afterAll(async()=>{
    try {
      // Assert the shared roster retains the full readable profile and that
      // no temporary revocation state leaks into the subsequent UI journeys.
      for(const actor of Object.values(actors)) {
        const profile=(await db.doc(`users/${actor.uid}`).get()).data();
        expect(profile).toEqual(actor.profile);
        expect(profile.createdAt).toBeInstanceOf(Timestamp);
        expect(profile.email).toMatch(/@example\.invalid$/);
        expect(profile.accessDisposition).toBe('approved');
        expect(profile.isApproved).toBe(true);
      }
    } finally {if(app)await deleteApp(app);}
  });
  test.each([
    ['upsertAbnormalityType','abnormality_types','admin','admin2',typeRecord],
    ['upsertLegacyJobTemplate','job_templates','si','admin2',templateRecord],
    ['updateJobExecutionWork','job_executions','worker','worker2',executionRecord],
  ])('%s refuses same-role account switch, accepts original once, retains replay evidence',async(type,collection,owner,other,factory)=>{
    const record=factory(`${prefix}-${collection}`,actors[owner].uid);
    if(type==='updateJobExecutionWork'){
      await db.doc(`${collection}/${record.firestoreId}`).set({...record,createdAt:Timestamp.fromDate(new Date('2026-09-27T00:00:00.123Z'))});
      record.createdAt='2026-09-27T00:00:00.123000Z';record.version=2;record.remarks='Saved by original actor';
      record.responsesJson='[ {"fieldId":"inspection","answer":null} ]';
      record.actionsJson=JSON.stringify([{asset:'Furnace 1',component:'Seal',action:'inspect',isAutoResolved:false,
        createdAt:'2026-09-27T00:00:20.123456Z',severity:'low',version:1,remarks:''}]);
    } else if(type==='upsertLegacyJobTemplate') {
      record.fields=[{fieldId:'inspection',title:'Inspection',fieldType:'text',isRequired:false,meta:{note:'legacy alias'}}];
      record.fieldsJson=JSON.stringify(record.fields,null,2);
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
    const profile=actors[owner].profile;
    await db.doc(`users/${actors[owner].uid}`).update({isApproved:false,
      accessDisposition:'revoked',authorityRevision:profile.authorityRevision+1});
    expect((await invoke(actors[owner],cmd)).error.status).toBe('PERMISSION_DENIED');
    profile.authorityRevision+=2;
    await db.doc(`users/${actors[owner].uid}`).update({isApproved:true,
      accessDisposition:'approved',authorityRevision:profile.authorityRevision});
    expect(await accepted(actors[owner],cmd)).toEqual(first);
    if(type==='updateJobExecutionWork') {
      const proveWork=async(original,candidate,expected,suffix,actor)=>{
        const path=`job_executions/${original.firestoreId}`, seeded=await seedStamped(path,original);
        const work=make('updateJobExecutionWork',candidate,`work-parity-${suffix}`), frozen=JSON.stringify(work);
        const receipt=await accepted(actor,work);
        expect(receipt.result.record).toEqual(expected);
        expect(JSON.stringify(work)).toBe(frozen);
        const baseline=await waitForStamped(path,expected,seeded._globalPullServerUpdatedAt);
        const snapshot=await db.doc(path).get();
        const audit=await db.doc(`audit_logs/server_cf01_${work.commandId}`).get();
        const storedReceipt=await db.doc(`maintenance_workflow_command_receipts/${work.commandId}`).get();
        expect(storedReceipt.data().result.record).toEqual(expected);
        expect(JSON.parse(audit.data().beforeJson)).toEqual(original);
        expect(JSON.parse(audit.data().afterJson)).toEqual(expected);
        expect(await accepted(actor,work)).toEqual(receipt);
        const replayed=await db.doc(path).get();
        expect(replayed.data()).toEqual(baseline);
        expect(replayed.updateTime.isEqual(snapshot.updateTime)).toBe(true);
        expect((await audit.ref.get()).updateTime.isEqual(audit.updateTime)).toBe(true);
        expect((await storedReceipt.ref.get()).updateTime.isEqual(storedReceipt.updateTime)).toBe(true);
      };
      for(const [field,value] of [['remarks','Existing observation'],['metadataJson',' {"operatorNote":"Existing evidence"} ']]) {
        for(const state of ['value','missing','null']) {
          for(const input of ['omitted','null']) {
            const suffix=`${field}-${state}-${input}`;
            const original={...executionRecord(`${prefix}-work-${suffix}`),[field]:state==='value'?value:null};
            if(state==='missing') delete original[field];
            const candidate={...original,version:2,updatedAt:'2026-09-27T00:02:00.234567Z'};
            if(input==='omitted') delete candidate[field]; else candidate[field]=null;
            await proveWork(original,candidate,{...original,...candidate},suffix,actors.omissionWorker);
          }
        }
      }
      for(const [field,value] of [['assignedAgencies',[]],['isCancelled',false]]) {
        for(const mode of ['stored-default','stored-missing']) {
          const suffix=`${field}-${mode}`;
          const original={...executionRecord(`${prefix}-work-${suffix}`),[field]:value};
          if(mode==='stored-missing') delete original[field];
          const candidate={...original,version:2,[field]:mode==='stored-default'?null:value};
          await proveWork(original,candidate,{...original,version:2},suffix,actors.representationWorker);
        }
      }
      const complete=executionRecord(`${prefix}-work-complete`);
      const completeWork={...complete,version:2,updatedAt:'2026-09-27T00:02:00.234567Z',remarks:null,
        teamsInvolved:['mechanical'],responsesJson:'[{"fieldId":"inspection","value":"normal"}]',
        actionsJson:'[]',metadataJson:'{"operatorNote":"Current evidence"}'};
      await proveWork(complete,completeWork,completeWork,'complete',actors.representationWorker);
      const reserved={...executionRecord(`${prefix}-work-reserved`),metadataJson:'{"source":"server_governed_legacy_template_assignment","assignmentSchemaVersion":1}'};
      const reservedPath=`job_executions/${reserved.firestoreId}`, baseline=await seedStamped(reservedPath,reserved);
      const snapshot=await db.doc(reservedPath).get();
      for(const [suffix,field,value,status] of [
        ['metadata-omitted','metadataJson',undefined,'PERMISSION_DENIED'],
        ['metadata-null','metadataJson',null,'PERMISSION_DENIED'],
        ['required-omitted','responsesJson',undefined,'INVALID_ARGUMENT'],
        ['required-null','teamsInvolved',null,'INVALID_ARGUMENT'],
        ['physical-target','assetNumber',99,'PERMISSION_DENIED'],
      ]) {
        const candidate={...reserved,version:2};
        if(value===undefined) delete candidate[field]; else candidate[field]=value;
        const bad=make('updateJobExecutionWork',candidate,`work-parity-refused-${suffix}`);
        expect((await invoke(actors.representationWorker,bad)).error.status).toBe(status);
        const retained=await db.doc(reservedPath).get();
        expect(retained.data()).toEqual(baseline);
        expect(retained.updateTime.isEqual(snapshot.updateTime)).toBe(true);
        expect((await db.doc(`audit_logs/server_cf01_${bad.commandId}`).get()).exists).toBe(false);
        expect((await db.doc(`maintenance_workflow_command_receipts/${bad.commandId}`).get()).exists).toBe(false);
      }
    }
  },120000);
  test('fresh wrong-role and forged work identity are refused without receipt',async()=>{
    const id=`${prefix}-negative`, type=make('upsertAbnormalityType',typeRecord(id,actors.ops.uid),'wrong-role');
    expect((await invoke(actors.ops,type)).error.status).toBe('PERMISSION_DENIED');
    const original=executionRecord(id),baseline=await seedStamped(`job_executions/${id}`,original);
    const cmd=make('updateJobExecutionWork',{...original,version:2,assetNumber:999},'forged-work');
    expect((await invoke(actors.worker,cmd)).error.status).toBe('PERMISSION_DENIED');
    expect((await db.doc(`job_executions/${id}`).get()).data()).toEqual(baseline);
    expect((await db.doc(`audit_logs/server_cf01_${cmd.commandId}`).get()).exists).toBe(false);
    // Keep these cases inside the same HTTP test: the CI gate requires all
    // seven boundary scenarios, and every invalid attempt must leave no row,
    // audit, or receipt while the shared emulator stays readable for Android.
    const invalid=[
      ['responses',{responsesJson:'[{}]'}],['actions',{actionsJson:'[{}]'}],
      ['metadata',{metadataJson:{}}],
      ['assignment',{metadataJson:'{"assignmentAssetIdentity":{"assetClassId":"other","assetInstanceId":"other","assetNumber":1}}'}],
    ];
    for(const [suffix,change] of invalid) {
      const bad=make('updateJobExecutionWork',{...original,version:2,...change},`invalid-${suffix}`);
      const result=await invoke(actors.worker,bad);
      expect(result.error.status).toBe(suffix==='assignment'?'PERMISSION_DENIED':'INVALID_ARGUMENT');
      expect((await db.doc(`job_executions/${id}`).get()).data()).toEqual(baseline);
      expect((await db.doc(`audit_logs/server_cf01_${bad.commandId}`).get()).exists).toBe(false);
      expect((await db.doc(`maintenance_workflow_command_receipts/${bad.commandId}`).get()).exists).toBe(false);
    }
    for(const [suffix,change] of [
      ['fields',{fields:[{}],fieldsJson:'[{}]'}],['hierarchy',{assetHierarchyRefJson:'{}'}],
      ['template-metadata',{metadataJson:{}}],
    ]) {
      const bad=make('upsertLegacyJobTemplate',{...templateRecord(`${prefix}-invalid-${suffix}`,actors.si.uid),...change},`invalid-${suffix}`);
      expect((await invoke(actors.si,bad)).error.status).toBe('INVALID_ARGUMENT');
      expect((await db.doc(`job_templates/${bad.aggregateId}`).get()).exists).toBe(false);
      expect((await db.doc(`audit_logs/server_cf01_${bad.commandId}`).get()).exists).toBe(false);
      expect((await db.doc(`maintenance_workflow_command_receipts/${bad.commandId}`).get()).exists).toBe(false);
    }

    // New V2 records must not introduce UID-only or blank attribution, and
    // known creation attribution cannot be removed. Full data/updateTime and absent receipts
    // prove refusals cannot add a malformed row to the later pull population.
    // Keep this independent negative campaign within the existing per-actor
    // anomaly budget; no counter resets or runtime guard exceptions are used.
    const author=actors.catalogueAuthor, editor=actors.catalogueEditor;
    const named=typeRecord(`${prefix}-actor-names`,author.uid);
    named.createdByName='Original Catalogue Author';
    named.lastEditedByName='Original Catalogue Author';
    const namedCommand=make('upsertAbnormalityType',named,'valid-actor-names');
    const firstNamed=await accepted(author,namedCommand);
    expect(firstNamed.result.record).toEqual(named);
    const namedPath=`abnormality_types/${named.firestoreId}`;
    const namedBaseline=await waitForStamped(namedPath,named);
    const namedSnapshot=await db.doc(namedPath).get();
    for(const field of ['createdByName','lastEditedByName']) {
      for(const [label,missingName] of [['missing',undefined],['null',null],['empty',''],['whitespace','  ']]) {
        for(const mode of ['create','update']) {
          const suffix=`name-${mode}-${field}-${label}`;
          const candidate=mode==='create'?typeRecord(`${prefix}-${suffix}`,author.uid):{...named,version:2};
          candidate[field]=missingName;
          if(label==='missing') delete candidate[field];
          const bad=make('upsertAbnormalityType',candidate,suffix);
          expect((await invoke(author,bad)).error.status)
            .toBe(mode==='update'&&field==='createdByName'?'PERMISSION_DENIED':'INVALID_ARGUMENT');
          const retained=await db.doc(namedPath).get();
          expect(retained.data()).toEqual(namedBaseline);
          expect(retained.updateTime.isEqual(namedSnapshot.updateTime)).toBe(true);
          if(mode==='create') expect((await db.doc(`abnormality_types/${candidate.firestoreId}`).get()).exists).toBe(false);
          expect((await db.doc(`audit_logs/server_cf01_${bad.commandId}`).get()).exists).toBe(false);
          expect((await db.doc(`maintenance_workflow_command_receipts/${bad.commandId}`).get()).exists).toBe(false);
        }
      }
    }
    for(const [field,limit] of [['description',4000],['deletedByName',500],['deleteReason',2000]]) {
      for(const [label,invalidText] of [['empty',''],['whitespace','  '],['wrong-type',7],['too-long','x'.repeat(limit+1)]]) {
        const candidate={...named,version:2,[field]:invalidText};
        if(field!=='description') Object.assign(candidate,{
          isDeleted:true,isActive:false,deletedAt:named.updatedAt,deletedByUid:author.uid,
        });
        const bad=make('upsertAbnormalityType',candidate,`invalid-${field}-${label}`);
        expect((await invoke(author,bad)).error.status).toBe('INVALID_ARGUMENT');
        const retained=await db.doc(namedPath).get();
        expect(retained.data()).toEqual(namedBaseline);
        expect(retained.updateTime.isEqual(namedSnapshot.updateTime)).toBe(true);
        expect((await db.doc(`audit_logs/server_cf01_${bad.commandId}`).get()).exists).toBe(false);
        expect((await db.doc(`maintenance_workflow_command_receipts/${bad.commandId}`).get()).exists).toBe(false);
      }
    }
    const namedEdit={...named,version:2,title:'Reviewed catalogue title',
      lastEditedByUid:editor.uid,lastEditedByName:'Second Catalogue Reviewer'};
    expect((await accepted(editor,make('upsertAbnormalityType',namedEdit,'valid-actor-name-edit'))).result.record).toEqual(namedEdit);
    const editedBaseline=await waitForStamped(namedPath,namedEdit,namedBaseline._globalPullServerUpdatedAt);
    const editedSnapshot=await db.doc(namedPath).get();
    expect(await accepted(author,namedCommand)).toEqual(firstNamed);
    const afterOriginalReplay=await db.doc(namedPath).get();
    expect(afterOriginalReplay.data()).toEqual(editedBaseline);
    expect(afterOriginalReplay.updateTime.isEqual(editedSnapshot.updateTime)).toBe(true);
    const namedDeleted={...namedEdit,version:3,isDeleted:true,isActive:false,
      deletedAt:namedEdit.updatedAt,deletedByUid:editor.uid,deletedByName:null,deleteReason:null};
    const deleteCommand=make('upsertAbnormalityType',namedDeleted,'valid-null-deletion-text');
    const deleteReceipt=await accepted(editor,deleteCommand);
    expect(deleteReceipt.result.record).toEqual(namedDeleted);
    const deletedBaseline=await waitForStamped(namedPath,namedDeleted,editedBaseline._globalPullServerUpdatedAt);
    const deletedSnapshot=await db.doc(namedPath).get();
    expect(await accepted(editor,deleteCommand)).toEqual(deleteReceipt);
    const afterDeleteReplay=await db.doc(namedPath).get();
    expect(afterDeleteReplay.data()).toEqual(deletedBaseline);
    expect(afterDeleteReplay.updateTime.isEqual(deletedSnapshot.updateTime)).toBe(true);

    // Directly seed supported historical shapes, rather than creating them
    // through the stricter new-record contract. A separate approved actor keeps
    // this campaign independent of the preceding anomaly-budget negatives.
    const historicalEditor=actors.historicalEditor;
    for(const mode of ['missing','null','both-missing','both-null']) {
      const historical={...typeRecord(`${prefix}-historical-${mode}`,'historical-creator'),
        createdByName:null,lastEditedByUid:'historical-creator',lastEditedByName:null};
      if(mode==='missing'||mode==='both-missing') delete historical.createdByName;
      if(mode==='both-missing') delete historical.createdByUid;
      if(mode==='both-null') historical.createdByUid=null;
      const path=`abnormality_types/${historical.firestoreId}`;
      let baseline=await seedStamped(path,historical);
      let snapshot=await db.doc(path).get();
      let current={...historical,createdByUid:historical.createdByUid??null,createdByName:null,
        version:2,updatedAt:'2026-09-27T00:02:00.234567Z',
        lastEditedByUid:historicalEditor.uid,lastEditedByName:historicalEditor.profile.name};
      for(const [suffix,change,status] of [
        ['invented-name',{createdByName:'Invented historical name'},'PERMISSION_DENIED'],
        ['missing-editor',{lastEditedByName:null},'INVALID_ARGUMENT'],
      ]) {
        const bad=make('upsertAbnormalityType',{...current,...change},`historical-${mode}-${suffix}`);
        expect((await invoke(historicalEditor,bad)).error.status).toBe(status);
        const unchanged=await db.doc(path).get();
        expect(unchanged.data()).toEqual(baseline);
        expect(unchanged.updateTime.isEqual(snapshot.updateTime)).toBe(true);
        expect((await db.doc(`audit_logs/server_cf01_${bad.commandId}`).get()).exists).toBe(false);
        expect((await db.doc(`maintenance_workflow_command_receipts/${bad.commandId}`).get()).exists).toBe(false);
      }
      const retained=[];
      let previous=historical;
      for(const operation of ['edit','deactivate','soft-delete']) {
        if(operation==='edit') current.description='Current clarification without invented creator history';
        if(operation==='deactivate') current={...current,version:3,isActive:false};
        if(operation==='soft-delete') current={...current,version:4,isDeleted:true,
          deletedAt:current.updatedAt,deletedByUid:historicalEditor.uid,
          deletedByName:historicalEditor.profile.name,deleteReason:'Retired catalogue entry'};
        const cmd=make('upsertAbnormalityType',current,`historical-${mode}-${operation}`);
        const receipt=await accepted(historicalEditor,cmd);
        expect(receipt.result.record).toEqual(current);
        baseline=await waitForStamped(path,current,baseline._globalPullServerUpdatedAt);
        snapshot=await db.doc(path).get();
        const audit=await db.doc(`audit_logs/server_cf01_${cmd.commandId}`).get();
        expect(audit.data()).toMatchObject({performedByUid:historicalEditor.uid,
          action:operation==='soft-delete'?'delete':'update',entityType:'abnormality_type'});
        expect(JSON.parse(audit.data().beforeJson)).toEqual(previous);
        expect(JSON.parse(audit.data().afterJson)).toEqual(current);
        retained.push({cmd,receipt,audit});
        previous={...current};
      }
      // Every original accepted snapshot remains replayable after later edits
      // and deletion, without altering the current row or rewriting its audit.
      for(const {cmd,receipt,audit} of retained) {
        expect(await accepted(historicalEditor,cmd)).toEqual(receipt);
        const unchanged=await db.doc(path).get();
        expect(unchanged.data()).toEqual(baseline);
        expect(unchanged.updateTime.isEqual(snapshot.updateTime)).toBe(true);
        expect((await audit.ref.get()).updateTime.isEqual(audit.updateTime)).toBe(true);
      }
    }

    // The strict client trims readable creator text. Preserve the original raw
    // spelling on disk while accepting exactly that normalized identity.
    const paddedEditor=actors.paddedEditor;
    for(const mode of ['pair','uid-only']) {
      const original={...typeRecord(`${prefix}-padded-${mode}`,'  historical-creator\t'),
        createdByName:mode==='pair'?'\t Historical Author  ':null};
      const path=`abnormality_types/${original.firestoreId}`;
      let baseline=await seedStamped(path,original);
      let snapshot=await db.doc(path).get();
      let candidate={...original,createdByUid:original.createdByUid.trim(),
        createdByName:original.createdByName?.trim()??null,version:2,
        updatedAt:'2026-09-27T00:02:00.234567Z',
        lastEditedByUid:paddedEditor.uid,lastEditedByName:paddedEditor.profile.name};
      for(const [suffix,change] of [
        ['unrelated-uid',{createdByUid:'different-creator'}],
        ['unrelated-name',{createdByName:'Different Author'}],
        ['blank-uid',{createdByUid:'  '}],['blank-name',{createdByName:'\t'}],
      ]) {
        const bad=make('upsertAbnormalityType',{...candidate,...change},`padded-${mode}-${suffix}`);
        expect((await invoke(paddedEditor,bad)).error.status).toBe('PERMISSION_DENIED');
        const unchanged=await db.doc(path).get();
        expect(unchanged.data()).toEqual(baseline);
        expect(unchanged.updateTime.isEqual(snapshot.updateTime)).toBe(true);
        expect((await db.doc(`audit_logs/server_cf01_${bad.commandId}`).get()).exists).toBe(false);
        expect((await db.doc(`maintenance_workflow_command_receipts/${bad.commandId}`).get()).exists).toBe(false);
      }
      const retained=[];
      let previous=original;
      for(const operation of ['edit','deactivate','soft-delete']) {
        if(operation==='edit') candidate.description='Current clarification with original creator evidence';
        if(operation==='deactivate') candidate={...candidate,version:3,isActive:false};
        if(operation==='soft-delete') candidate={...candidate,version:4,isDeleted:true,
          deletedAt:candidate.updatedAt,deletedByUid:paddedEditor.uid,
          deletedByName:paddedEditor.profile.name,deleteReason:'Retired catalogue entry'};
        const cmd=make('upsertAbnormalityType',candidate,`padded-${mode}-${operation}`);
        const frozen=JSON.stringify(cmd);
        const expected={...candidate,createdByUid:original.createdByUid,createdByName:original.createdByName};
        const receipt=await accepted(paddedEditor,cmd);
        expect(receipt.result.record).toEqual(expected);
        expect(JSON.stringify(cmd)).toBe(frozen);
        baseline=await waitForStamped(path,expected,baseline._globalPullServerUpdatedAt);
        snapshot=await db.doc(path).get();
        const audit=await db.doc(`audit_logs/server_cf01_${cmd.commandId}`).get();
        expect(JSON.parse(audit.data().beforeJson)).toEqual(previous);
        expect(JSON.parse(audit.data().afterJson)).toEqual(expected);
        expect(audit.data().performedByUid).toBe(paddedEditor.uid);
        retained.push({cmd,receipt,audit});
        previous=expected;
      }
      for(const {cmd,receipt,audit} of retained) {
        expect(await accepted(paddedEditor,cmd)).toEqual(receipt);
        const unchanged=await db.doc(path).get();
        expect(unchanged.data()).toEqual(baseline);
        expect(unchanged.updateTime.isEqual(snapshot.updateTime)).toBe(true);
        expect((await audit.ref.get()).updateTime.isEqual(audit.updateTime)).toBe(true);
      }
      const first=retained[0].cmd;
      // Semantically equal creator spelling never permits changing a saved
      // command's exact payload identity after that command was accepted.
      expect((await invoke(paddedEditor,{...first,payload:{...first.payload,
        record:{...first.payload.record,createdByUid:original.createdByUid}}})).error.status).toBe('ABORTED');
      const unchanged=await db.doc(path).get();
      expect(unchanged.data()).toEqual(baseline);
      expect(unchanged.updateTime.isEqual(snapshot.updateTime)).toBe(true);
    }

    // Legacy templates have the same normalized creator identity, but their
    // optional-text reader also maps historical blank strings to null.
    for(const mode of ['pair','blank','null','missing']) {
      const original={...templateRecord(`${prefix}-padded-template-${mode}`),
        createdByUid:mode==='pair'?'  historical-template-creator\t':' \t ',
        createdByName:mode==='pair'?'\t Historical Template Author  ':''};
      if(mode==='null') Object.assign(original,{createdByUid:null,createdByName:null});
      if(mode==='missing') { delete original.createdByUid; delete original.createdByName; }
      const path=`job_templates/${original.firestoreId}`;
      let baseline=await seedStamped(path,original), snapshot=await db.doc(path).get();
      let candidate={...original,createdByUid:original.createdByUid?.trim()||null,
        createdByName:original.createdByName?.trim()||null,version:2,
        updatedAt:'2026-09-27T00:02:00.234567Z'};
      if(mode==='null'||mode==='missing') Object.assign(candidate,{createdByUid:' \t ',createdByName:'  '});
      for(const [suffix,change] of [
        ['unrelated-uid',{createdByUid:'different-creator'}],
        ['unrelated-name',{createdByName:'Different Author'}],
        ['si-deletion',{isDeleted:true,deletedAt:candidate.updatedAt,deletedByUid:actors.paddedTemplateSi.uid}],
      ]) {
        const bad=make('upsertLegacyJobTemplate',{...candidate,...change},`padded-template-${mode}-${suffix}`);
        expect((await invoke(actors.paddedTemplateSi,bad)).error.status).toBe('PERMISSION_DENIED');
        const unchanged=await db.doc(path).get();
        expect(unchanged.data()).toEqual(baseline);
        expect(unchanged.updateTime.isEqual(snapshot.updateTime)).toBe(true);
        expect((await db.doc(`audit_logs/server_cf01_${bad.commandId}`).get()).exists).toBe(false);
        expect((await db.doc(`maintenance_workflow_command_receipts/${bad.commandId}`).get()).exists).toBe(false);
      }
      const retained=[];
      let previous=original;
      for(const operation of ['edit','deactivate','soft-delete']) {
        const actor=operation==='soft-delete'?actors.paddedTemplateAdmin:actors.paddedTemplateSi;
        if(operation==='edit') candidate.description='Current template clarification';
        if(operation==='deactivate') candidate={...candidate,version:3,isActive:false};
        if(operation==='soft-delete') candidate={...candidate,version:4,isDeleted:true,
          deletedAt:candidate.updatedAt,deletedByUid:actor.uid,
          deletedByName:actor.profile.name,deleteReason:'Retired template'};
        const cmd=make('upsertLegacyJobTemplate',candidate,`padded-template-${mode}-${operation}`), frozen=JSON.stringify(cmd);
        const expected={...candidate};
        for(const field of ['createdByUid','createdByName']) {
          if(Object.hasOwn(original,field)) expected[field]=original[field];
          else delete expected[field];
        }
        const receipt=await accepted(actor,cmd);
        expect(receipt.result.record).toEqual(expected);
        expect(JSON.stringify(cmd)).toBe(frozen);
        baseline=await waitForStamped(path,expected,baseline._globalPullServerUpdatedAt);
        snapshot=await db.doc(path).get();
        const audit=await db.doc(`audit_logs/server_cf01_${cmd.commandId}`).get();
        expect(JSON.parse(audit.data().beforeJson)).toEqual(previous);
        expect(JSON.parse(audit.data().afterJson)).toEqual(expected);
        expect(audit.data().performedByUid).toBe(actor.uid);
        retained.push({cmd,receipt,audit,actor});previous=expected;
      }
      for(const {cmd,receipt,audit,actor} of retained) {
        expect(await accepted(actor,cmd)).toEqual(receipt);
        const unchanged=await db.doc(path).get();
        expect(unchanged.data()).toEqual(baseline);
        expect(unchanged.updateTime.isEqual(snapshot.updateTime)).toBe(true);
        expect((await audit.ref.get()).updateTime.isEqual(audit.updateTime)).toBe(true);
      }
    }
  },120000);
  test.each([
    ['abnormality_types','admin',typeRecord],['job_templates','si',templateRecord],['job_executions','worker',executionRecord],
  ])('Rules deny same-role direct %s update and permit approved read',async(collection,owner,factory)=>{
    const record=factory(`${prefix}-raw-${collection}`,actors[owner].uid);
    const baseline=await seedStamped(`${collection}/${record.firestoreId}`,record);
    const url=`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${projectId}/databases/(default)/documents/${collection}/${record.firestoreId}`;
    const headers={Authorization:`Bearer ${actors[owner].token}`,'Content-Type':'application/json'};
    const response=await fetch(url,{method:'PATCH',headers,body:JSON.stringify({fields:value({...record,version:2}).mapValue.fields})});
    expect(response.status).toBe(403);
    expect((await fetch(url,{headers})).status).toBe(200);
    expect((await db.doc(`${collection}/${record.firestoreId}`).get()).data()).toEqual(baseline);
  },120000);
});
