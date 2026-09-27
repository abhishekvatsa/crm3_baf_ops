const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');
const {retainedQueueInstant} = require('../lib/maintenanceWorkflow/retainedQueueHandlers');
const {Timestamp} = require('firebase-admin/firestore');
const {typeRecord,templateRecord,executionRecord,command} = require('./helpers/retainedQueueFixtures.cjs');
const projectId='demo-crm3-cf01';
let store, service;
const context=(uid='admin', extra={})=>({actor:{uid,name:uid}, serverNow:new Date('2026-09-27T01:00:00Z'), originBoundProtocolVersion:2, projectId,...extra});
const execute=(cmd,uid='admin',extra={})=>service.execute(cmd,context(uid,extra));
beforeEach(()=>{
  store=new MemoryWorkflowStore(); service=new MaintenanceWorkflowCommandService(store);
  for(const [uid,role] of [['admin','admin'],['admin2','admin'],['si','si'],['worker','contractSupervisor'],['ops','operations']])
    store.seed(`users/${uid}`,{isApproved:true,roles:[role],name:uid});
});
test.each([
  ['upsertAbnormalityType',()=>typeRecord(),'admin','abnormality_types'],
  ['upsertLegacyJobTemplate',()=>templateRecord(),'si','job_templates'],
])('%s creates once and replays original accepted evidence after later edits',async(type,factory,uid,collection)=>{
  const record=factory(), cmd=command(type,record), first=await execute(cmd,uid);
  expect(first.result).toEqual({collection,recordId:record.firestoreId,record});
  store.seed(`${collection}/${record.firestoreId}`,{...record,version:17,title:'Later change',jobName:'Later change'});
  expect(await execute(cmd,uid)).toEqual(first);
  expect(store.entries().filter(([key])=>key.startsWith('audit_logs/'))).toHaveLength(1);
  expect(store.read(`audit_logs/server_cf01_${cmd.commandId}`).performedByUid).toBe(uid);
  expect(store.read(`audit_logs/server_cf01_${cmd.commandId}`)).toMatchObject({
    entityType:collection==='abnormality_types'?'abnormality_type':'job_template',
    entityId:record.firestoreId,severity:'low',action:'create',timestamp:first.appliedAt,
  });
});
test('project and V2 admission reject before accepted replay',async()=>{
  const cmd=command('upsertAbnormalityType',typeRecord()); await execute(cmd);
  await expect(execute(cmd,'admin',{projectId:'other-project'})).rejects.toMatchObject({code:'permission-denied',details:{reasonCode:'retained-queue-project-mismatch'}});
  await expect(execute(cmd,'admin',{originBoundProtocolVersion:undefined})).rejects.toMatchObject({code:'failed-precondition'});
});
test('same-role different actor cannot replay, and revoked actor cannot replay',async()=>{
  const cmd=command('upsertAbnormalityType',typeRecord()); await execute(cmd);
  await expect(execute(cmd,'admin2')).rejects.toMatchObject({code:'permission-denied'});
  store.seed('users/admin',{isApproved:false,roles:['admin']});
  await expect(execute(cmd)).rejects.toMatchObject({code:'permission-denied'});
});
test.each([['upsertAbnormalityType',typeRecord,'si'],['upsertLegacyJobTemplate',templateRecord,'worker']])('%s enforces catalogue authority',async(type,factory,uid)=>{
  await expect(execute(command(type,factory()),uid)).rejects.toMatchObject({code:'permission-denied'});
  expect(store.entries().filter(([key])=>key.startsWith('audit_logs/'))).toHaveLength(0);
});
test('changed payload under same ID cannot replay; stale new ID cannot overwrite',async()=>{
  const cmd=command('upsertAbnormalityType',typeRecord()); await execute(cmd);
  await expect(execute({...cmd,payload:{...cmd.payload,record:{...cmd.payload.record,title:'Changed'}}})).rejects.toMatchObject({code:'command-idempotency-conflict'});
  await expect(execute({...cmd,commandId:'another-id'})).rejects.toMatchObject({code:'workflow-version-conflict'});
});
test('deletion remains actor-bound, versioned, and retains original creation',async()=>{
  const record=typeRecord(); await execute(command('upsertAbnormalityType',record));
  const deleted={...record,version:2,isDeleted:true,isActive:false,deletedAt:record.updatedAt,deletedByUid:'admin',deletedByName:'Admin',deleteReason:'Synthetic retirement'};
  const accepted=await execute(command('upsertAbnormalityType',deleted,{commandId:'delete-type'}));
  expect(accepted.result.record).toEqual(deleted);
  expect(store.read('audit_logs/server_cf01_delete-type')).toMatchObject({entityType:'abnormality_type',action:'delete',severity:'low'});
  await expect(execute(command('upsertAbnormalityType',{...deleted,version:3,deletedByUid:'admin2'},{commandId:'bad-delete'}))).rejects.toMatchObject({code:'permission-denied'});
});
test('SI can edit templates but cannot delete or alter creator; Admin cannot undelete',async()=>{
  const original=templateRecord(); await execute(command('upsertLegacyJobTemplate',original),'si');
  const next={...original,version:2,jobName:'Edited name'};
  await expect(execute(command('upsertLegacyJobTemplate',{...next,createdByUid:'admin'}),'si')).rejects.toMatchObject({code:'permission-denied'});
  const deleted={...next,isDeleted:true,deletedAt:next.updatedAt,deletedByUid:'si'};
  await expect(execute(command('upsertLegacyJobTemplate',deleted),'si')).rejects.toMatchObject({code:'permission-denied'});
  await execute(command('upsertLegacyJobTemplate',{...deleted,deletedByUid:'admin'},{commandId:'admin-delete'}));
  await expect(execute(command('upsertLegacyJobTemplate',{...original,version:3},{commandId:'restore'}))).rejects.toMatchObject({code:'failed-precondition'});
});
test.each(['createdAt','assetNumber','assignedByUid','isCompleted','laneSetVersion','templateContentHash','completedAt','chargeNoAtEvent'])('work edits preserve pinned %s',async(field)=>{
  const before=executionRecord(); store.seed('job_executions/execution-1',before);
  const value=field.endsWith('At')?'2026-09-27T00:00:01.000Z':field==='isCompleted'?true:typeof before[field]==='number'?99:'forged';
  await expect(execute(command('updateJobExecutionWork',{...before,version:2,[field]:value}),'worker')).rejects.toBeDefined();
  expect(store.read('job_executions/execution-1')).toEqual(before);
});
test('work edit changes only work fields and returns exact accepted snapshot',async()=>{
  const before=executionRecord(); store.seed('job_executions/execution-1',{...before,serverEvidence:'retained'});
  const next={...before,version:2,remarks:'Actual observation',teamsInvolved:['mechanical'],responsesJson:'[{"fieldId":"inspection","value":"normal"}]'};
  const first=await execute(command('updateJobExecutionWork',next),'worker');
  expect(first.result.record).toEqual({...next,serverEvidence:'retained'});
  expect(store.read(`audit_logs/server_cf01_${first.commandId}`)).toMatchObject({entityType:'job_execution',action:'update',severity:'low'});
  expect(store.read('job_executions/execution-1')).toEqual({...next,serverEvidence:'retained'});
  expect(await execute(command('updateJobExecutionWork',next),'worker')).toEqual(first);
});
test.each([{isCompleted:true},{isCancelled:true},{isDeleted:true}])('closed/deleted executions refuse work edits %j',async(state)=>{
  const before={...executionRecord(),...state}; store.seed('job_executions/execution-1',before);
  await expect(execute(command('updateJobExecutionWork',{...executionRecord(),version:2}),'worker')).rejects.toMatchObject({code:'failed-precondition'});
});
test('execution cannot be created through work command or edited by operations',async()=>{
  await expect(execute(command('updateJobExecutionWork',executionRecord()),'worker')).rejects.toMatchObject({code:'failed-precondition'});
  store.seed('job_executions/execution-1',executionRecord());
  await expect(execute(command('updateJobExecutionWork',{...executionRecord(),version:2}),'ops')).rejects.toMatchObject({code:'permission-denied'});
});
test.each([
  {createdAt:'2026-02-30T00:00:00Z'}, {updatedAt:'2026-09-26T23:00:00Z'},
  {version:7},{firestoreId:'other'}, {unknownField:true}, {fields:[{name:'different'}]},
])('invalid immutable payload is rejected without writes %j',async(change)=>{
  await expect(execute({...command('upsertLegacyJobTemplate',{...templateRecord(),...change},{expectedVersion:0}),aggregateId:'template-1'},'si')).rejects.toBeDefined();
  expect(store.read('job_templates/template-1')).toBeNull();
});
test.each([
  ['2026-09-27T05:30:00.123456','2026-09-27T00:00:00.123456Z'],
  ['2026-09-27T05:30:00.123456+05:30','2026-09-27T00:00:00.123456Z'],
  ['2026-09-27T00:00:00.123Z','2026-09-27T00:00:00.123000Z'],
  [new Timestamp(1790467200,123456000),'2026-09-27T00:00:00.123456Z'],
])('canonical instant preserves exact microseconds %s',(value,expected)=>expect(retainedQueueInstant(value)).toBe(expected));
test('nested template metadata remains verbatim, not mistaken for record timestamps',async()=>{
  const fields=[{key:'inspection',label:'Inspection',type:'text',meta:{createdAt:'a descriptive label',_globalPullNote:'authored evidence'}}];
  const record={...templateRecord(),fields,fieldsJson:JSON.stringify(fields)};
  const accepted=await execute(command('upsertLegacyJobTemplate',record),'si');
  expect(accepted.result.record).toEqual(record);
});
test('original creator name and historical creation instant cannot be revised',async()=>{
  const record=typeRecord();await execute(command('upsertAbnormalityType',record));
  await expect(execute(command('upsertAbnormalityType',{...record,version:2,createdByName:'Reattributed'}))).rejects.toMatchObject({code:'permission-denied'});
});
test('permanent purge evidence prevents recreating a catalogue identity',async()=>{
  const hash=require('node:crypto').createHash('sha256').update('abnormality_types/type-1').digest('hex');
  store.seed(`pilot_record_purge_manifests/purge_${hash}`,{entityId:'type-1'});
  await expect(execute(command('upsertAbnormalityType',typeRecord()))).rejects.toMatchObject({code:'failed-precondition'});
  expect(store.read('abnormality_types/type-1')).toBeNull();
});
test('accepted replay refuses contradictory retained audit evidence',async()=>{
  const cmd=command('upsertAbnormalityType',typeRecord());await execute(cmd);
  const path=`audit_logs/server_cf01_${cmd.commandId}`;
  store.seed(path,{...store.read(path),afterJson:'{}'});
  await expect(execute(cmd)).rejects.toMatchObject({code:'failed-precondition'});
});
test.each([{severity:null},{entityType:'abnormality_types'},{action:'delete'},{entityId:'other'},{timestamp:'2026-09-27T01:00:01Z'}])('replay refuses malformed or reattributed audit history %j',async(change)=>{
  const cmd=command('upsertAbnormalityType',typeRecord());await execute(cmd);
  const path=`audit_logs/server_cf01_${cmd.commandId}`;
  store.seed(path,{...store.read(path),...change});
  await expect(execute(cmd)).rejects.toMatchObject({code:'failed-precondition'});
});
test('checked Dart audit fixture exactly matches fresh dispatcher output',async()=>{
  const fixture=require('../../test/fixtures/retained_queue_dispatcher_audits.json');
  const {produceRetainedQueueAudits}=require('./helpers/produceRetainedQueueAudits.cjs');
  expect(await produceRetainedQueueAudits()).toEqual(fixture);
});
describe.each([
  ['upsertAbnormalityType','abnormality_types',typeRecord],
  ['upsertLegacyJobTemplate','job_templates',templateRecord],
])('%s tombstone validation preserves canonical evidence', (type,collection,factory)=>{
  test.each(['absent','null','malformed','before-created','after-updated','wrong-owner'])('refuses %s deletion without a record, audit, or receipt change',async(variant)=>{
    const original=factory('deletion-safety','admin');
    await execute(command(type,original));
    const before=store.read(`${collection}/${original.firestoreId}`);
    const audits=store.entries().filter(([key])=>key.startsWith('audit_logs/'));
    const receipts=store.entries().filter(([key])=>key.startsWith('maintenance_workflow_command_receipts/'));
    const deleted={...original,version:2,isDeleted:true,isActive:false,
      deletedAt:original.updatedAt,deletedByUid:'admin',deletedByName:'admin',deleteReason:'Synthetic retirement'};
    switch(variant){
    case 'absent':delete deleted.deletedAt;break;
    case 'null':deleted.deletedAt=null;break;
    case 'malformed':deleted.deletedAt='not-a-timestamp';break;
    case 'before-created':deleted.deletedAt='2026-09-26T23:59:59.999999Z';break;
    case 'after-updated':deleted.deletedAt='2026-09-27T00:02:00.000000Z';break;
    case 'wrong-owner':deleted.deletedByUid='admin2';break;
    }
    await expect(execute(command(type,deleted))).rejects.toMatchObject({
      code:variant==='wrong-owner'?'permission-denied':'invalid-argument',
    });
    expect(store.read(`${collection}/${original.firestoreId}`)).toEqual(before);
    expect(store.entries().filter(([key])=>key.startsWith('audit_logs/'))).toEqual(audits);
    expect(store.entries().filter(([key])=>key.startsWith('maintenance_workflow_command_receipts/'))).toEqual(receipts);
  });
});
