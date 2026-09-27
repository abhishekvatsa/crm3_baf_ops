// Actual accepted dispatcher output for the strict Dart eager and lazy readers.
const {MaintenanceWorkflowCommandService}=require('../../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore}=require('../../lib/maintenanceWorkflow/memoryStore');
const {templateRecord,executionRecord,command}=require('./retainedQueueFixtures.cjs');
async function produceRetainedQueueNestedEvidence() {
  const store=new MemoryWorkflowStore();
  for(const [uid,role] of [['si','si'],['worker','contractSupervisor']]) {
    store.seed(`users/${uid}`,{isApproved:true,roles:[role],name:uid});
  }
  const service=new MaintenanceWorkflowCommandService(store);
  const execute=(record,type,uid)=>service.execute(command(type,record),{actor:{uid,name:uid},
    serverNow:new Date('2026-09-27T01:00:00Z'),originBoundProtocolVersion:2,projectId:'demo-crm3-cf01'});
  const reference={schemaVersion:1,assetClassId:'furnace-class',assetClassCode:'FURNACE',assetClassName:'Furnace',
    nodeId:'seal-node',nodeVersion:1,nodeName:'Seal',hierarchyPath:['Furnace','Seal'],ownershipStatus:'unassigned',
    ownerDiscipline:null,accountableRoleKeys:[]};
  const fields=[{fieldId:'inspection',title:'Inspection',fieldType:'text',isRequired:false,
    validation:'{"maxLength":200}',validationJson:{maxLength:200},meta:'{"note":"legacy encoded bag"}'}];
  const template={...templateRecord(),fields,fieldsJson:JSON.stringify(fields,null,2),
    assetHierarchyRefJson:JSON.stringify(reference),metadataJson:'  '};
  const templateAccepted=await execute(template,'upsertLegacyJobTemplate','si');
  const metadata={source:'server_governed_legacy_template_assignment',assignmentSchemaVersion:1,
    assignmentAssetIdentity:{assetClassId:'furnace-class',assetInstanceId:'furnace-1',assetNumber:1},
    jobTemplateSnapshot:JSON.stringify({assetHierarchyRefJson:JSON.stringify(reference)})};
  const original={...executionRecord(),metadataJson:JSON.stringify(metadata)};
  store.seed('job_executions/execution-1',original);
  const execution={...original,version:2,remarks:'Synthetic inspection',
    responsesJson:JSON.stringify([
      {fieldId:'inspection',answer:null},
      {name:'structured-observation',type:'text',value:{readings:[1,2.5,null],checked:true,
        note:'Synthetic bounded response',details:{units:'mm'}}},
    ]),
    actionsJson:JSON.stringify([{asset:'Furnace 1',component:'Seal',action:'inspect',isAutoResolved:false,
      createdAt:'2026-09-27 00:00:20.123456',severity:'low',version:1,remarks:'',assetHierarchyRef:reference}]),
    metadataJson:JSON.stringify({...metadata,operatorNote:{text:'Original work',shift:2}})};
  const executionAccepted=await execute(execution,'updateJobExecutionWork','worker');
  const legacy={...executionRecord('legacy-execution'),metadataJson:' '};
  store.seed('job_executions/legacy-execution',legacy);
  const legacyAccepted=await execute({...legacy,version:2,remarks:''},'updateJobExecutionWork','worker');
  const coverMetadata={assignmentAssetIdentity:{assetClassId:'base-class',assetInstanceId:'base-1',assetNumber:1},
    assignmentInnerCoverPosition:{baseAssetClassId:'base-class',baseAssetInstanceId:'base-1',baseAssetNumber:1,
      innerCoverId:'synthetic-cover',innerCoverSerialNumber:'DEV-IC-1',linkageId:'synthetic-link',assignmentVersion:2},
    jobTemplateSnapshot:null};
  const cover={...executionRecord('cover-execution'),assetType:'innerCover',metadataJson:JSON.stringify(coverMetadata)};
  store.seed('job_executions/cover-execution',cover);
  const coverAccepted=await execute({...cover,version:2,remarks:'Recorded cover position retained'},'updateJobExecutionWork','worker');
  return [templateAccepted,executionAccepted,legacyAccepted,coverAccepted].map(receipt=>receipt.result);
}
module.exports={produceRetainedQueueNestedEvidence};
if(require.main===module)produceRetainedQueueNestedEvidence().then(rows=>process.stdout.write(JSON.stringify(rows,null,2)+'\n'))
  .catch(error=>{process.stderr.write(String(error));process.exitCode=1;});
