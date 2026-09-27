// Cross-language producer: callers decode actual handler output, not a copied
// Dart-shaped fixture. No Firebase app or network is involved.
const {MaintenanceWorkflowCommandService}=require('../../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore}=require('../../lib/maintenanceWorkflow/memoryStore');
const {typeRecord,templateRecord,executionRecord,command}=require('./retainedQueueFixtures.cjs');
async function produceRetainedQueueAudits() {
  const store=new MemoryWorkflowStore();
  for(const [uid,role] of [['admin','admin'],['si','si'],['worker','contractSupervisor']]) {
    store.seed(`users/${uid}`,{isApproved:true,roles:[role],name:uid});
  }
  const service=new MaintenanceWorkflowCommandService(store);
  const execute=(cmd,uid)=>service.execute(cmd,{actor:{uid,name:uid},
    serverNow:new Date('2026-09-27T01:00:00Z'),originBoundProtocolVersion:2,projectId:'demo-crm3-cf01'});
  await execute(command('upsertAbnormalityType',typeRecord()),'admin');
  await execute(command('upsertLegacyJobTemplate',templateRecord()),'si');
  const execution=executionRecord();store.seed('job_executions/execution-1',execution);
  await execute(command('updateJobExecutionWork',{...execution,version:2,remarks:'Inspection recorded'}),'worker');
  const deleted={...typeRecord(),version:2,isDeleted:true,isActive:false,
    deletedAt:'2026-09-27T00:01:00.234567Z',deletedByUid:'admin',deletedByName:'admin',deleteReason:'Synthetic retirement'};
  await execute(command('upsertAbnormalityType',deleted),'admin');
  return store.entries().filter(([key])=>key.startsWith('audit_logs/'))
    .map(([path,data])=>({documentId:path.slice('audit_logs/'.length),data}));
}
module.exports={produceRetainedQueueAudits};
if(require.main===module)produceRetainedQueueAudits().then((rows)=>process.stdout.write(JSON.stringify(rows)))
  .catch((error)=>{process.stderr.write(String(error));process.exitCode=1;});
