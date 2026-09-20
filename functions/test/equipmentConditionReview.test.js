const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');
const {equipmentProjectionWrite, projectEquipment} = require('../lib/maintenanceWorkflow/equipmentFacts');
const actor = {uid:'ops',name:'Operator',roles:new Set(['operations'])};
const admin = {uid:'admin',name:'Admin',roles:new Set(['admin'])};
function fixture(serviceState='inService', ids=true) {
  const store=new MemoryWorkflowStore();
  store.seed('users/ops',{isApproved:true,roles:['operations'],name:'Operator'});
  store.seed('users/admin',{isApproved:true,roles:['admin'],name:'Admin'});
  store.seed('asset_classes/furnace-class',{schemaVersion:1,assetClassId:'furnace-class',legacyAssetTypeKey:'furnace',status:'active'});
  store.seed('asset_instances/furnace-7',{schemaVersion:1,assetInstanceId:'furnace-7',assetClassId:'furnace-class',assetNumber:7,status:'active',serviceState,version:1});
  store.seed('equipment_status/furnace_7',{state:'available',version:1,assetTypeKey:'furnace',assetNumber:7,...(ids?{assetClassId:'furnace-class',assetInstanceId:'furnace-7'}:{})});
  return {store,service:new MaintenanceWorkflowCommandService(store)};
}
const command=(id='deploy',type='deployEquipment',version=1,ids=false)=>({commandId:id,commandType:type,aggregateId:'equipment_furnace_7',expectedVersion:version,payload:{assetTypeKey:'furnace',assetNumber:7,...(ids?{assetClassId:'furnace-class',assetInstanceId:'furnace-7'}:{})}});
const context=(who=actor)=>({actor:who,serverNow:new Date('2026-09-20T10:00:00Z')});
test.each([true,false])('omitted request IDs still refuse withdrawal with projection IDs=%s',async(ids)=>{
 const {store,service}=fixture('outOfService',ids);
 await expect(service.execute(command(),context())).rejects.toMatchObject({details:{reasonCode:'equipment-administratively-out-of-service'}});
 expect(store.read('equipment_status/furnace_7').version).toBe(1);
});
test.each(['inService','standby'])('legacy positive control resolves %s without changing original replay identity',async(state)=>{
 const {store,service}=fixture(state,false);const request=command();const result=await service.execute(request,context());
 expect(store.read('equipment_status/furnace_7')).toMatchObject({state:'inService',assetInstanceId:'furnace-7',activeNonRedMaintenanceCount:0});
 store.seed('asset_instances/furnace-7',{...store.read('asset_instances/furnace-7'),status:'retired'});
 expect((await service.execute(request,context())).commandId).toBe(result.commandId);
 expect(store.read('equipment_status/furnace_7').version).toBe(2);
});
test('reconciliation no longer preserves an administratively withdrawn in-service claim',async()=>{
 const {store,service}=fixture('outOfService');store.seed('equipment_status/furnace_7',{...store.read('equipment_status/furnace_7'),state:'inService',inServiceSince:'2026-09-19T08:00:00.000Z'});
 await service.execute(command('reconcile','reconcileEquipment'),context(admin));
 expect(store.read('equipment_status/furnace_7')).toMatchObject({state:'available',availableSince:null,inServiceSince:null});
});
test('open work still prevents release',async()=>{
 const {store,service}=fixture();store.seed('maintenance_workflows/work',{assetTypeKey:'furnace',assetNumber:7,status:'inProgress'});
 await expect(service.execute(command(),context())).rejects.toMatchObject({code:'equipment-state-conflict'});
});
test('refresh preserves interval and original transition metadata; first reconstruction has unknown age',()=>{
 const facts={activeNonRedMaintenanceCount:0,activeRedWorkCount:0,awaitingPreparationCount:0};
 const metadata={assetTypeKey:'furnace',assetNumber:7,trigger:'reconcile:refresh',at:'2026-09-20T10:00:00.000Z',actorUid:'admin',actorName:'Admin'};
 const old={state:'available',version:1,previousState:'underMaintenance',transitionTrigger:'finished:original',availableSince:'2026-09-20T08:00:00.000Z',lastTransitionAt:'2026-09-20T08:00:00.000Z',lastTransitionByUid:'original'};
 const result=equipmentProjectionWrite(old,facts,projectEquipment(facts,false),metadata);
 expect(result).toMatchObject({...old,version:2,updatedAt:metadata.at});
 expect(equipmentProjectionWrite(null,facts,projectEquipment(facts,false),metadata).availableSince).toBeNull();
});

test.each(['missing', 'malformed', 'ambiguous'])('legacy resolution fails closed for %s registry evidence',async(kind)=>{
 const {store,service}=fixture('inService',false);
 if(kind==='missing') store.seed('asset_instances/furnace-7',{...store.read('asset_instances/furnace-7'),assetNumber:8});
 if(kind==='malformed') store.seed('asset_instances/furnace-7',{...store.read('asset_instances/furnace-7'),serviceState:'unknown'});
 if(kind==='ambiguous') store.seed('asset_instances/duplicate',{...store.read('asset_instances/furnace-7'),assetInstanceId:'duplicate'});
 await expect(service.execute(command(),context())).rejects.toMatchObject({code:'equipment-state-conflict'});
 expect(store.read('equipment_status/furnace_7').version).toBe(1);
});
