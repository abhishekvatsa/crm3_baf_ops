const createdAt = '2026-09-27T00:00:00.123456Z';
const updatedAt = '2026-09-27T00:01:00.234567Z';
const common = (id) => ({firestoreId:id, version:1, createdAt, updatedAt,
  isDeleted:false, deletedAt:null, deletedByUid:null, deletedByName:null, deleteReason:null});
const typeRecord = (id='type-1', uid='admin') => ({...common(id), code:'PROCESS-TEST',
  title:'Synthetic process observation', description:null, category:'process', severity:'medium',
  applicableAssetTypes:['furnace'], suggestsReannealing:false, isActive:true,
  createdByUid:uid, createdByName:uid, lastEditedByUid:uid, lastEditedByName:uid});
const templateRecord = (id='template-1', uid='si') => ({...common(id), jobName:'Synthetic planned inspection',
  description:null, applicableAssetType:'furnace', assignedAgencies:['mechanical'],
  component:null, subsystem:null, hierarchyPath:null, assetHierarchyRefJson:null,
  fields:[], fieldsJson:'[]', createdByUid:uid, createdByName:uid,
  isActive:true, isDeprecated:false, metadataJson:null});
const executionRecord = (id='execution-1') => ({...common(id), templateFirestoreId:'template-1',
  templateName:'Synthetic planned inspection', templatePackageId:null, templateVersionId:null,
  templateVersionNumber:null, templateVersionLabel:null, templateContentHash:null, templatePackageCode:null,
  assetType:'furnace', assetNumber:1, isCompleted:false, isCancelled:false, cancelledAt:null,
  cancelledByUid:null, cancelledByName:null, cancellationReason:null, assignedByUid:'si', assignedByName:'SI',
  assignedAgencies:['mechanical'], workflowSchemaVersion:2, laneSetVersion:1,
  laneSetFinalizedAt:'2026-09-27T00:00:30.000000Z', laneSetFinalizedByUid:'si', laneSetFinalizedByName:'SI',
  laneMappingReview:false, parentExecutionFirestoreId:null, spawnedRedExecutionFirestoreId:null,
  redAnswerJson:null, completedByUid:null, completedByName:null, remarks:null, teamsInvolved:[],
  chargeNoAtEvent:12345, responsesJson:'[]', actionsJson:'[]', metadataJson:null, completedAt:null});
const command = (commandType, record, {projectId='demo-crm3-cf01', commandId=`${commandType}-${record.firestoreId}-v${record.version}`, expectedVersion=record.version-1}={}) =>
  ({commandId, commandType, aggregateId:record.firestoreId, expectedVersion, payload:{projectId,record}});
module.exports={createdAt,updatedAt,typeRecord,templateRecord,executionRecord,command};
