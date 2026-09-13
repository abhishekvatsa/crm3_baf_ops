const fs=require('node:fs');
const path=require('node:path');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,collection,getDoc,getDocs,query,where,setDoc,updateDoc,deleteDoc,setLogLevel,Timestamp}=require('firebase/firestore');
let env;
const projectId='demo-workflow-module-reopen';
const fixture=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures/workflow_module_reopen_firestore_handler.json'),'utf8'));
const storedAudit={...fixture.audit,timestamp:new Timestamp(fixture.audit.timestamp._seconds,fixture.audit.timestamp._nanoseconds)};
const auditId=`workflow_module_reopen_${fixture.command.payload.moduleFirestoreId}_${fixture.receipt.aggregateVersion}`;
const user=(roles,approved=true)=>({roles,isApproved:approved,name:'Supervisor'});
const db=uid=>env.authenticatedContext(uid).firestore();
async function seed(path,data){await env.withSecurityRulesDisabled(async ctx=>setDoc(doc(ctx.firestore(),path),data));}
beforeAll(async()=>{
 setLogLevel('silent');
 const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
 env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:fs.readFileSync(path.join(__dirname,'../firestore.rules'),'utf8')}});
});
afterAll(async()=>{await env?.cleanup();});
beforeEach(async()=>{
 await env.clearFirestore();
 await seed('users/admin-1',user(['shiftSupervisor']));
 await seed('users/other',user(['shiftSupervisor']));
 await seed('users/admin',user(['admin']));
 await seed(`audit_logs/${auditId}`,storedAudit);
});
for(const role of ['si','contractSupervisor','shiftSupervisor'])test(`original approved ${role} can get actual producer audit`,async()=>{
 await seed('users/admin-1',user([role]));
 await assertSucceeds(getDoc(doc(db('admin-1'),`audit_logs/${auditId}`)));
});
test('another supervisor and unauthenticated account cannot read original audit; admin policy remains',async()=>{
 await assertFails(getDoc(doc(db('other'),`audit_logs/${auditId}`)));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),`audit_logs/${auditId}`)));
 await assertSucceeds(getDoc(doc(db('admin'),`audit_logs/${auditId}`)));
});
for(const roles of [['operations'],['seniorMechanical'],['shiftSupervisor','invented'],[]])test(`current revoked or malformed roles ${roles} cannot read`,async()=>{
 await seed('users/admin-1',user(roles));await assertFails(getDoc(doc(db('admin-1'),`audit_logs/${auditId}`)));
});
test('unapproved and missing original account cannot read',async()=>{
 await seed('users/admin-1',user(['shiftSupervisor'],false));await assertFails(getDoc(doc(db('admin-1'),`audit_logs/${auditId}`)));
 await env.withSecurityRulesDisabled(async ctx=>deleteDoc(doc(ctx.firestore(),'users/admin-1')));
 await assertFails(getDoc(doc(db('admin-1'),`audit_logs/${auditId}`)));
});
test('new permission never authorizes collection or owner-filtered list',async()=>{
 await assertFails(getDocs(collection(db('admin-1'),'audit_logs')));
 await assertFails(getDocs(query(collection(db('admin-1'),'audit_logs'),where('performedByUid','==','admin-1'))));
});
for(const [field,value] of [['entityType','maintenance'],['action','update'],['reason','other'],['performedByUid',23],['beforeJson',{}],['afterJson',[]],['timestamp',42],['timestamp',fixture.receipt.appliedAt],['timestamp',fixture.audit.timestamp],['entityId',null],['workflowAggregateId',null],['laneKey','mechanical'],['reasonNotes',''],['unreviewed','extra']])test(`malformed/wrong audit ${field} ${typeof value} is not exposed to supervisor`,async()=>{
 await seed(`audit_logs/${auditId}`,{...storedAudit,[field]:value});
 await assertFails(getDoc(doc(db('admin-1'),`audit_logs/${auditId}`)));
});
test('same fields in unrelated namespace are not exposed',async()=>{
 await seed('audit_logs/unrelated_11',storedAudit);await assertFails(getDoc(doc(db('admin-1'),'audit_logs/unrelated_11')));
});
test('all clients including admin cannot create, update or delete server reopen audits',async()=>{
 for(const uid of ['admin-1','admin']){
  await assertFails(setDoc(doc(db(uid),`audit_logs/workflow_module_reopen_other_12`),storedAudit));
  await assertFails(updateDoc(doc(db(uid),`audit_logs/${auditId}`),{reasonNotes:'tampered'}));
  await assertFails(deleteDoc(doc(db(uid),`audit_logs/${auditId}`)));
 }
});
