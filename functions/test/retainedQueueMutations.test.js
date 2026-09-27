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

describe('abnormality catalogue actor names remain readable',()=>{
  for (const field of ['createdByName','lastEditedByName']) {
    for (const [label,value] of [['missing',undefined],['null',null],['empty',''],['whitespace','  ']]) {
      test.each(['create','update'])(`%s refuses ${label} ${field} with a retained UID and no writes`,async(mode)=>{
        const original=typeRecord();
        if(mode==='update') await execute(command('upsertAbnormalityType',original));
        const candidate={...original,version:mode==='create'?1:2,[field]:value};
        if(label==='missing') delete candidate[field];
        const cmd=command('upsertAbnormalityType',candidate);
        const before=store.entries();
        await expect(execute(cmd)).rejects.toMatchObject({
          code:mode==='update'&&field==='createdByName'?'permission-denied':'invalid-argument',
        });
        expect(store.entries()).toEqual(before);
        expect(store.read(`audit_logs/server_cf01_${cmd.commandId}`)).toBeNull();
        expect(store.read(`maintenance_workflow_command_receipts/${cmd.commandId}`)).toBeNull();
      });
    }
  }
  test('valid original and later editor names retain exact attribution and replay',async()=>{
    const original={...typeRecord(),createdByName:'Original Author',lastEditedByName:'Original Author'};
    const firstCommand=command('upsertAbnormalityType',original);
    const first=await execute(firstCommand);
    expect(first.result.record).toEqual(original);
    const edited={...original,version:2,title:'Reviewed catalogue title',lastEditedByUid:'admin2',lastEditedByName:'Second Reviewer'};
    const editCommand=command('upsertAbnormalityType',edited);
    expect((await execute(editCommand,'admin2')).result.record).toEqual(edited);
    const beforeReplay=store.entries();
    expect(await execute(firstCommand)).toEqual(first);
    expect(store.entries()).toEqual(beforeReplay);
    expect(store.read('abnormality_types/type-1')).toEqual(edited);
  });
  for(const [field,limit] of [['description',4000],['deletedByName',500],['deleteReason',2000]]) {
    test.each(['','  ',7,'x'.repeat(limit+1)])(`catalogue ${field} refuses unreadable present text without writes`,async(value)=>{
      const original=typeRecord();
      await execute(command('upsertAbnormalityType',original));
      const candidate={...original,version:2,[field]:value};
      if(field!=='description') Object.assign(candidate,{
        isDeleted:true,isActive:false,deletedAt:original.updatedAt,deletedByUid:'admin',
      });
      const cmd=command('upsertAbnormalityType',candidate);
      const before=store.entries();
      await expect(execute(cmd)).rejects.toMatchObject({code:'invalid-argument'});
      expect(store.entries()).toEqual(before);
      expect(store.read(`audit_logs/server_cf01_${cmd.commandId}`)).toBeNull();
      expect(store.read(`maintenance_workflow_command_receipts/${cmd.commandId}`)).toBeNull();
    });
  }
  test.each(['null','missing'])('legacy optional catalogue deletion text may remain %s',async(mode)=>{
    const original=typeRecord();
    await execute(command('upsertAbnormalityType',original));
    const deleted={...original,version:2,isDeleted:true,isActive:false,
      deletedAt:original.updatedAt,deletedByUid:'admin',description:null,deletedByName:null,deleteReason:null};
    if(mode==='missing') for(const field of ['description','deletedByName','deleteReason']) delete deleted[field];
    const cmd=command('upsertAbnormalityType',deleted);
    const accepted=await execute(cmd);
    expect(accepted.result.record).toMatchObject({isDeleted:true,isActive:false,createdByName:'admin',lastEditedByName:'admin'});
    for(const field of ['description','deletedByName','deleteReason']) expect(accepted.result.record[field]??null).toBeNull();
    const beforeReplay=store.entries();
    expect(await execute(cmd)).toEqual(accepted);
    expect(store.entries()).toEqual(beforeReplay);
  });
});
describe('historical catalogue creator compatibility',()=>{
  const historical=(mode)=>{
    const original={...typeRecord(),version:7,createdByUid:'historical-creator',
      createdByName:null,lastEditedByUid:'historical-creator',lastEditedByName:null};
    if(mode==='missing'||mode==='both-missing') delete original.createdByName;
    if(mode==='both-missing') delete original.createdByUid;
    if(mode==='both-null') original.createdByUid=null;
    return original;
  };
  const currentEdit=(original)=>({...original,version:8,updatedAt:'2026-09-27T00:02:00.234567Z',
    lastEditedByUid:'admin2',lastEditedByName:'Current approved editor'});
  for(const mode of ['missing','null','both-missing','both-null']) {
    test.each(['edit','deactivate','soft-delete'])(`%s preserves historical ${mode} creator name and exact replay`,async(operation)=>{
      const original=historical(mode);
      store.seed('abnormality_types/type-1',original);
      const edited=currentEdit(original);
      if(operation==='edit') edited.description='Current catalogue clarification';
      if(operation==='deactivate') edited.isActive=false;
      if(operation==='soft-delete') Object.assign(edited,{isActive:false,isDeleted:true,
        deletedAt:edited.updatedAt,deletedByUid:'admin2',deletedByName:'Current approved editor',
        deleteReason:'Retired catalogue entry'});
      const cmd=command('upsertAbnormalityType',edited);
      const accepted=await execute(cmd,'admin2');
      expect(accepted.result.record).toEqual(edited);
      expect(store.read('abnormality_types/type-1')).toEqual(edited);
      const audit=store.read(`audit_logs/server_cf01_${cmd.commandId}`);
      expect(audit).toMatchObject({performedByUid:'admin2',action:operation==='soft-delete'?'delete':'update'});
      expect(JSON.parse(audit.beforeJson)).toEqual(original);
      expect(JSON.parse(audit.afterJson)).toEqual(edited);
      store.seed('abnormality_types/type-1',{...edited,version:9,title:'Later canonical title'});
      const beforeReplay=store.entries();
      expect(await execute(cmd,'admin2')).toEqual(accepted);
      expect(store.entries()).toEqual(beforeReplay);
    });
    test.each([
      ['invented creator name',{createdByName:'Invented historical name'},'permission-denied'],
      ['substituted creator UID',{createdByUid:'admin2'},'permission-denied'],
      ['blank creator name',{createdByName:'  '},'permission-denied'],
      ['null current editor name',{lastEditedByName:null},'invalid-argument'],
      ['blank current editor name',{lastEditedByName:'  '},'invalid-argument'],
      ['another current editor UID',{lastEditedByUid:'admin'},'permission-denied'],
    ])(`${mode} creator refuses %s without record, audit or receipt writes`,async(_label,change,code)=>{
      const original=historical(mode);
      store.seed('abnormality_types/type-1',original);
      const cmd=command('upsertAbnormalityType',{...currentEdit(original),...change});
      const before=store.entries();
      await expect(execute(cmd,'admin2')).rejects.toMatchObject({code});
      expect(store.entries()).toEqual(before);
      expect(store.read(`audit_logs/server_cf01_${cmd.commandId}`)).toBeNull();
      expect(store.read(`maintenance_workflow_command_receipts/${cmd.commandId}`)).toBeNull();
    });
  }
  test('client null serialization preserves absent historical creator name without inventing one',async()=>{
    const original=historical('missing');
    store.seed('abnormality_types/type-1',original);
    const edited={...currentEdit(original),createdByName:null};
    const cmd=command('upsertAbnormalityType',edited);
    expect((await execute(cmd,'admin2')).result.record).toEqual(edited);
    const audit=store.read(`audit_logs/server_cf01_${cmd.commandId}`);
    expect(JSON.parse(audit.beforeJson)).toEqual(original);
    expect(JSON.parse(audit.afterJson).createdByName).toBeNull();
  });
  test.each(['','  '])('already-malformed historical blank creator name cannot be carried forward (%j)',async(name)=>{
    const original={...historical('null'),createdByName:name};
    store.seed('abnormality_types/type-1',original);
    const before=store.entries();
    await expect(execute(command('upsertAbnormalityType',currentEdit(original)),'admin2'))
      .rejects.toMatchObject({code:'invalid-argument'});
    expect(store.entries()).toEqual(before);
  });
  test.each([
    ['name without UID',{createdByUid:null,createdByName:'Unbound name'}],
    ['blank UID',{createdByUid:'  ',createdByName:null}],
    ['non-string UID',{createdByUid:7,createdByName:null}],
    ['non-string name',{createdByName:7}],
  ])('already-malformed historical %s cannot be carried forward',async(_label,change)=>{
    const original={...historical('null'),...change};
    store.seed('abnormality_types/type-1',original);
    const before=store.entries();
    await expect(execute(command('upsertAbnormalityType',currentEdit(original)),'admin2'))
      .rejects.toMatchObject({code:'invalid-argument'});
    expect(store.entries()).toEqual(before);
  });
});
describe('historical catalogue creator whitespace compatibility',()=>{
  const historical=(creator)=>({...typeRecord(),version:7,
    createdByUid:'  historical-creator\t',createdByName:'\t Historical Author  ',...creator});
  const edit=(original)=>({...original,version:8,updatedAt:'2026-09-27T00:02:00.234567Z',
    createdByUid:original.createdByUid?.trim()??null,
    createdByName:original.createdByName?.trim()??null,
    lastEditedByUid:'admin2',lastEditedByName:'Current approved editor'});
  for(const [label,creator] of [
    ['padded pair',{}],['padded UID only',{createdByName:null}],
    ['padded name only',{createdByUid:'historical-creator'}],
  ]) {
    test.each(['edit','deactivate','soft-delete'])(`%s accepts normalized ${label} and preserves raw creator evidence`,async(operation)=>{
      const original=historical(creator);
      store.seed('abnormality_types/type-1',original);
      const candidate=edit(original);
      if(operation==='edit') candidate.description='Updated catalogue description';
      if(operation==='deactivate') candidate.isActive=false;
      if(operation==='soft-delete') Object.assign(candidate,{isActive:false,isDeleted:true,
        deletedAt:candidate.updatedAt,deletedByUid:'admin2',deletedByName:'Current approved editor',
        deleteReason:'Retired catalogue entry'});
      const cmd=command('upsertAbnormalityType',candidate);
      const frozenCommand=JSON.stringify(cmd);
      const expected={...candidate,createdByUid:original.createdByUid,createdByName:original.createdByName};
      const receipt=await execute(cmd,'admin2');
      expect(receipt.result.record).toEqual(expected);
      expect(store.read('abnormality_types/type-1')).toEqual(expected);
      expect(JSON.stringify(cmd)).toBe(frozenCommand);
      const audit=store.read(`audit_logs/server_cf01_${cmd.commandId}`);
      expect(JSON.parse(audit.beforeJson)).toEqual(original);
      expect(JSON.parse(audit.afterJson)).toEqual(expected);
      store.seed('abnormality_types/type-1',{...expected,version:9,title:'Later current title'});
      const beforeReplay=store.entries();
      expect(await execute(cmd,'admin2')).toEqual(receipt);
      expect(store.entries()).toEqual(beforeReplay);
    });
  }
  test('trimmed creator bounds match the reader while preserving padded original bytes',async()=>{
    const original=historical({createdByUid:` ${'u'.repeat(512)} `,createdByName:` ${'n'.repeat(500)} `});
    store.seed('abnormality_types/type-1',original);
    const candidate=edit(original);
    const expected={...candidate,createdByUid:original.createdByUid,createdByName:original.createdByName};
    expect((await execute(command('upsertAbnormalityType',candidate),'admin2')).result.record).toEqual(expected);
    expect(store.read('abnormality_types/type-1')).toEqual(expected);
  });
  test.each([
    ['unrelated UID',{createdByUid:'different-creator'}],
    ['unrelated name',{createdByName:'Different Author'}],
    ['case-changed UID',{createdByUid:'HISTORICAL-CREATOR'}],
    ['case-changed name',{createdByName:'HISTORICAL AUTHOR'}],
    ['blank UID',{createdByUid:'  '}],['blank name',{createdByName:'\t'}],
    ['removed UID',{createdByUid:null}],['removed name',{createdByName:null}],
  ])('normalized edit refuses %s without canonical, audit or receipt writes',async(_label,change)=>{
    const original=historical();
    store.seed('abnormality_types/type-1',original);
    const cmd=command('upsertAbnormalityType',{...edit(original),...change});
    const before=store.entries();
    await expect(execute(cmd,'admin2')).rejects.toMatchObject({code:'permission-denied'});
    expect(store.entries()).toEqual(before);
    expect(store.read(`audit_logs/server_cf01_${cmd.commandId}`)).toBeNull();
    expect(store.read(`maintenance_workflow_command_receipts/${cmd.commandId}`)).toBeNull();
  });
  test('equivalent submitted padding cannot replace original creator spelling',async()=>{
    const original=historical();store.seed('abnormality_types/type-1',original);
    const candidate={...edit(original),createdByUid:'\thistorical-creator ',createdByName:' Historical Author\n'};
    const receipt=await execute(command('upsertAbnormalityType',candidate),'admin2');
    expect(receipt.result.record).toEqual({...candidate,createdByUid:original.createdByUid,createdByName:original.createdByName});
  });
});
describe('historical template creator whitespace compatibility',()=>{
  const historical=(creator)=>({...templateRecord(),version:7,
    createdByUid:'  historical-creator\t',createdByName:'\t Historical Author  ',...creator});
  const edit=(original)=>({...original,version:8,updatedAt:'2026-09-27T00:02:00.234567Z',
    createdByUid:original.createdByUid?.trim()||null,createdByName:original.createdByName?.trim()||null});
  test.each(['edit','deactivate','soft-delete'])('%s accepts normalized template creator and preserves raw evidence',async(operation)=>{
    const original=historical();store.seed('job_templates/template-1',original);
    const candidate=edit(original);
    const actor=operation==='soft-delete'?'admin':'si';
    if(operation==='edit') candidate.description='Updated template description';
    if(operation==='deactivate') candidate.isActive=false;
    if(operation==='soft-delete') Object.assign(candidate,{isActive:false,isDeleted:true,
      deletedAt:candidate.updatedAt,deletedByUid:actor,deletedByName:actor,deleteReason:'Retired template'});
    const cmd=command('upsertLegacyJobTemplate',candidate), frozen=JSON.stringify(cmd);
    const expected={...candidate,createdByUid:original.createdByUid,createdByName:original.createdByName};
    const receipt=await execute(cmd,actor);
    expect(receipt.result.record).toEqual(expected);
    expect(store.read('job_templates/template-1')).toEqual(expected);
    expect(JSON.stringify(cmd)).toBe(frozen);
    const audit=store.read(`audit_logs/server_cf01_${cmd.commandId}`);
    expect(audit.performedByUid).toBe(actor);
    expect(JSON.parse(audit.beforeJson)).toEqual(original);
    expect(JSON.parse(audit.afterJson)).toEqual(expected);
    store.seed('job_templates/template-1',{...expected,version:9,jobName:'Later template title'});
    const beforeReplay=store.entries();
    expect(await execute(cmd,actor)).toEqual(receipt);
    expect(store.entries()).toEqual(beforeReplay);
  });
  test('template historical padded text within trimmed limits remains editable',async()=>{
    const original=historical({createdByUid:` ${'u'.repeat(500)} `,createdByName:` ${'n'.repeat(500)} `});
    store.seed('job_templates/template-1',original);
    const candidate=edit(original);
    const expected={...candidate,createdByUid:original.createdByUid,createdByName:original.createdByName};
    expect((await execute(command('upsertLegacyJobTemplate',candidate),'si')).result.record).toEqual(expected);
  });
  test.each(['',' \t '])('readable historical blank template creator remains raw when client submits null (%j)',async(blank)=>{
    const original=historical({createdByUid:blank,createdByName:blank});
    store.seed('job_templates/template-1',original);
    const candidate=edit(original), cmd=command('upsertLegacyJobTemplate',candidate);
    const expected={...candidate,createdByUid:blank,createdByName:blank};
    const receipt=await execute(cmd,'si');
    expect(receipt.result.record).toEqual(expected);
    expect(store.read('job_templates/template-1')).toEqual(expected);
    expect(JSON.parse(store.read(`audit_logs/server_cf01_${cmd.commandId}`).afterJson)).toEqual(expected);
    const beforeReplay=store.entries();
    expect(await execute(cmd,'si')).toEqual(receipt);
    expect(store.entries()).toEqual(beforeReplay);
  });
  test.each(['null','missing'])('historical %s template creator cannot be rewritten as equivalent blank text',async(mode)=>{
    const original=historical({createdByUid:null,createdByName:null});
    if(mode==='missing') { delete original.createdByUid; delete original.createdByName; }
    store.seed('job_templates/template-1',original);
    const candidate={...edit(original),createdByUid:' \t ',createdByName:'  '};
    const cmd=command('upsertLegacyJobTemplate',candidate), frozen=JSON.stringify(cmd);
    const expected={...candidate,createdByUid:null,createdByName:null};
    if(mode==='missing') { delete expected.createdByUid; delete expected.createdByName; }
    const receipt=await execute(cmd,'si');
    expect(receipt.result.record).toEqual(expected);
    expect(store.read('job_templates/template-1')).toEqual(expected);
    expect(JSON.stringify(cmd)).toBe(frozen);
    const audit=store.read(`audit_logs/server_cf01_${cmd.commandId}`);
    expect(JSON.parse(audit.beforeJson)).toEqual(original);
    expect(JSON.parse(audit.afterJson)).toEqual(expected);
    const beforeReplay=store.entries();
    expect(await execute(cmd,'si')).toEqual(receipt);
    expect(store.entries()).toEqual(beforeReplay);
  });
  test.each([
    ['unrelated UID',{createdByUid:'different-creator'}],['unrelated name',{createdByName:'Different Author'}],
    ['case-changed UID',{createdByUid:'HISTORICAL-CREATOR'}],['case-changed name',{createdByName:'HISTORICAL AUTHOR'}],
    ['blank UID',{createdByUid:'  '}],['blank name',{createdByName:'\t'}],
    ['removed UID',{createdByUid:null}],['removed name',{createdByName:null}],
  ])('template edit refuses %s without canonical, audit or receipt writes',async(_label,change)=>{
    const original=historical();store.seed('job_templates/template-1',original);
    const cmd=command('upsertLegacyJobTemplate',{...edit(original),...change}), before=store.entries();
    await expect(execute(cmd,'si')).rejects.toMatchObject({code:'permission-denied'});
    expect(store.entries()).toEqual(before);
    expect(store.read(`audit_logs/server_cf01_${cmd.commandId}`)).toBeNull();
    expect(store.read(`maintenance_workflow_command_receipts/${cmd.commandId}`)).toBeNull();
  });
  test('normalized template creator does not authorize SI deletion',async()=>{
    const original=historical();store.seed('job_templates/template-1',original);
    const candidate={...edit(original),isDeleted:true,deletedAt:'2026-09-27T00:02:00.234567Z',deletedByUid:'si'};
    const before=store.entries();
    await expect(execute(command('upsertLegacyJobTemplate',candidate),'si'))
      .rejects.toMatchObject({code:'permission-denied',message:'Only Admin may write a deleted template.'});
    expect(store.entries()).toEqual(before);
  });
  test('new template still requires the actual originating creator UID',async()=>{
    const candidate={...templateRecord(),createdByUid:'  si  '};
    const before=store.entries();
    await expect(execute(command('upsertLegacyJobTemplate',candidate),'si'))
      .rejects.toMatchObject({code:'permission-denied',message:'Template creator must be the origin actor.'});
    expect(store.entries()).toEqual(before);
  });
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

test('checked Dart nested evidence fixture exactly matches fresh dispatcher output',async()=>{
  const fixture=require('../../test/fixtures/retained_queue_nested_dispatcher_records.json');
  const {produceRetainedQueueNestedEvidence}=require('./helpers/produceRetainedQueueNestedEvidence.cjs');
  expect(await produceRetainedQueueNestedEvidence()).toEqual(fixture);
});

describe('nested retained evidence uses the strict persisted payload readers',()=>{
  const action=(change={})=>({asset:'Furnace 1',component:'Seal',action:'inspect',
    isAutoResolved:false,createdAt:'2026-09-27T00:00:20.123456Z',severity:'low',version:1,...change});
  const reference=(change={})=>({schemaVersion:1,assetClassId:'furnace-class',assetClassCode:'FURNACE',
    assetClassName:'Furnace',nodeId:'seal-node',nodeVersion:1,nodeName:'Seal',hierarchyPath:['Furnace','Seal'],
    ownershipStatus:'unassigned',ownerDiscipline:null,accountableRoleKeys:[],...change});
  test.each([
    ['responsesJson','[{}]'],
    ['actionsJson','[{}]'],
    ['responsesJson','[{"key":"pressure"}]'],
    ['responsesJson','[{"key":"pressure","value":1},{"fieldId":"PRESSURE","answer":2}]'],
    ['responsesJson','[{"schemaVersion":2,"key":"pressure","value":1}]'],
    ['responsesJson','[{"key":"pressure","value":1,"futureAuthority":true}]'],
    ['actionsJson',JSON.stringify([action({isAutoResolved:'false'})])],
    ['actionsJson',JSON.stringify([action({assetHierarchyRef:{}})])],
    ['actionsJson',JSON.stringify([action({metadataJson:'[]'})])],
    ['actionsJson',JSON.stringify([action({burnerPosition:2})])],
    ['actionsJson',JSON.stringify([action({schemaVersion:2})])],
    ['actionsJson',JSON.stringify([action({createdAt:'September 27, 2026'})])],
    ['actionsJson',JSON.stringify([action({burnerPosition:2,attendanceSessionId:' ',burnerActionCode:'inspect',burnerOutcome:'normal'})])],
    ['metadataJson',{}],
  ])('malformed execution %s cannot change canonical work, audit, or receipt',async(field,raw)=>{
    const original=executionRecord();store.seed('job_executions/execution-1',original);
    const before=store.entries();
    await expect(execute(command('updateJobExecutionWork',{...original,version:2,[field]:raw}),'worker'))
      .rejects.toMatchObject({code:'invalid-argument'});
    expect(store.entries()).toEqual(before);
  });
  test.each([
    {fields:[{}],fieldsJson:'[{}]'},
    {metadataJson:{}},
    {assetHierarchyRefJson:'{}'},
    ...[
      [{key:'test',type:'unregistered'}],
      [{key:'test'},{fieldId:'TEST'}],
      [{key:'test',required:'true'}],
      [{key:'test',schemaVersion:2}],
      [{key:'test',moduleCode:'module-only-field'}],
      [{key:'test',validationJson:'[]'}],
      [{key:'test',validationJson:'null'}],
    ].map(fields=>({fields,fieldsJson:JSON.stringify(fields)})),
    {assetHierarchyRefJson:JSON.stringify(reference({schemaVersion:9}))},
    {assetHierarchyRefJson:JSON.stringify(reference({ownershipStatus:'confirmed'}))},
    {assetHierarchyRefJson:JSON.stringify(reference({schemaVersion:2,scope:'installedComponent'}))},
    {assetHierarchyRefJson:JSON.stringify(reference({nodeVersion:0}))},
    {assetHierarchyRefJson:JSON.stringify(reference({ownershipStatus:'provisional',accountableRoleKeys:Array(11).fill('si')}))},
    {assetHierarchyRefJson:JSON.stringify(reference({ownershipStatus:'provisional',accountableRoleKeys:['x'.repeat(81)]}))},
    {assetHierarchyRefJson:JSON.stringify(reference({schemaVersion:4,scope:'componentDefinitionOnAsset',assetInstanceId:'furnace-1',
      assetInstanceVersion:1,assetNumber:1,assetInstanceName:'Furnace 1',componentTag:''}))},
  ])('malformed template nested evidence is refused before any write %j',async(change)=>{
    const before=store.entries();
    await expect(execute(command('upsertLegacyJobTemplate',{...templateRecord(),...change}),'si'))
      .rejects.toMatchObject({code:'invalid-argument'});
    expect(store.entries()).toEqual(before);
  });
  test('valid legacy fields, definition reference, aliases, and free template metadata retain exact bytes',async()=>{
    const fields=[{fieldId:'pressure',title:'Pressure',fieldType:'numericWithUnit',isRequired:true,
      options:['bar'],validation:'{"min":0}',validationJson:{min:0},meta:'{"createdAt":"authored note"}'}];
    const record={...templateRecord(),fields,fieldsJson:JSON.stringify(fields,null,2),
      assetHierarchyRefJson:JSON.stringify(reference()),metadataJson:'{"customNote":"Original evidence"}'};
    const receipt=await execute(command('upsertLegacyJobTemplate',record),'si');
    expect(receipt.result.record).toEqual(record);
    expect(store.read('job_templates/template-1')).toEqual(record);
    expect(await execute(command('upsertLegacyJobTemplate',record),'si')).toEqual(receipt);
  });
  test.each(['','  '])('blank legacy optional metadata remains readable and unchanged %j',async(metadataJson)=>{
    const template={...templateRecord(),metadataJson};
    expect((await execute(command('upsertLegacyJobTemplate',template),'si')).result.record).toEqual(template);
    const original={...executionRecord(),metadataJson};store.seed('job_executions/execution-1',original);
    const next={...original,version:2,remarks:'Actual observation'};
    expect((await execute(command('updateJobExecutionWork',next),'worker')).result.record).toEqual(next);
  });
  test.each(['','  '])('client optional text can remain blank without changing evidence %j',async(blank)=>{
    const template={...templateRecord(),description:blank,component:blank,subsystem:blank,createdByName:blank};
    expect((await execute(command('upsertLegacyJobTemplate',template),'si')).result.record).toEqual(template);
    const original=executionRecord();store.seed('job_executions/execution-1',original);
    const next={...original,version:2,remarks:blank};
    expect((await execute(command('updateJobExecutionWork',next),'worker')).result.record).toEqual(next);
  });
  test.each([{remarks:17},{remarks:'x'.repeat(20001)}])('optional text still refuses invalid type/size %j',async(change)=>{
    const original=executionRecord();store.seed('job_executions/execution-1',original);const before=store.entries();
    await expect(execute(command('updateJobExecutionWork',{...original,version:2,...change}),'worker'))
      .rejects.toMatchObject({code:'invalid-argument'});
    expect(store.entries()).toEqual(before);
  });
  test('valid legacy action/response aliases and unrelated work metadata remain editable verbatim',async()=>{
    const provenance={source:'server_governed_legacy_template_assignment',assignmentSchemaVersion:1,
      assignmentAssetIdentity:{assetClassId:'furnace-class',assetInstanceId:'furnace-1',assetNumber:1},
      jobTemplateSnapshot:JSON.stringify({assetHierarchyRefJson:JSON.stringify(reference())})};
    const original={...executionRecord(),metadataJson:JSON.stringify(provenance)};
    store.seed('job_executions/execution-1',original);
    const next={...original,version:2,
      responsesJson:'[ {"fieldId":"pressure","answer":null,"type":"numericWithUnit"} ]',
      actionsJson:JSON.stringify([action({assetHierarchyRef:reference(),remarks:'',metadataJson:'{"note":"inspection"}'})]),
      metadataJson:JSON.stringify({...provenance,operatorNote:{text:'Actual work',shift:2}})};
    const receipt=await execute(command('updateJobExecutionWork',next),'worker');
    expect(receipt.result.record).toEqual(next);
    expect(store.read('job_executions/execution-1')).toEqual(next);
    expect(await execute(command('updateJobExecutionWork',next),'worker')).toEqual(receipt);
  });
  test.each(['assignmentAssetIdentity','assignmentInnerCoverPosition','jobTemplateSnapshot','publicationAuditId',
    'source','assignmentSchemaVersion','contentHash','maintenanceClassification','maintenanceClassificationRevision','closureAttestation'])
  ('work cannot introduce, change, or remove reserved %s',async(key)=>{
    const prior={...executionRecord(),metadataJson:JSON.stringify({[key]:'unchanged provenance'})};
    for(const metadata of [{}, {[key]:'reattributed'}]) {
      store.seed('job_executions/execution-1',prior);
      const before=store.entries();
      await expect(execute(command('updateJobExecutionWork',{...prior,version:2,metadataJson:JSON.stringify(metadata)}),'worker'))
        .rejects.toMatchObject({code:'permission-denied'});
      expect(store.entries()).toEqual(before);
    }
    const empty=executionRecord();store.seed('job_executions/execution-1',empty);
    const before=store.entries();
    await expect(execute(command('updateJobExecutionWork',{...empty,version:2,metadataJson:JSON.stringify({[key]:'forged'})}),'worker'))
      .rejects.toMatchObject({code:'permission-denied'});
    expect(store.entries()).toEqual(before);
  });
  test.each([
    {jobTemplateSnapshot:[]}, {jobTemplateSnapshot:{assetHierarchyRefJson:'{}'}},
    {assignmentAssetIdentity:null}, {assignmentAssetIdentity:{}},
    {assignmentAssetIdentity:{assetClassId:'class',assetInstanceId:'asset',assetNumber:2}},
    {assignmentInnerCoverPosition:{}},
  ])('invalid stored assignment structure cannot be copied into newly accepted work %j',async(metadata)=>{
    const original={...executionRecord(),metadataJson:JSON.stringify(metadata)};
    store.seed('job_executions/execution-1',original);const before=store.entries();
    await expect(execute(command('updateJobExecutionWork',{...original,version:2,remarks:'New observation'}),'worker'))
      .rejects.toMatchObject({code:'invalid-argument'});
    expect(store.entries()).toEqual(before);
  });
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
