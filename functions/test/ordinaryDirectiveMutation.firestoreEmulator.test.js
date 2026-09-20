const admin=require('firebase-admin');
const {mutateOrdinaryDirectiveWithDb:mutate}=require('../lib/ordinaryDirectiveMutation');
const fixture=require('../../test/fixtures/ordinary_directive_actual_handler.json');
const host=process.env.FIRESTORE_EMULATOR_HOST, projectId=process.env.GCLOUD_PROJECT;
const local=host?describe:describe.skip;
jest.setTimeout(45000);
local('ordinary directive actual Firestore transaction boundaries',()=>{
 let app,db;
 beforeAll(async()=>{if(!/^127\.0\.0\.1:\d+$/.test(host)||projectId!=='demo-crm3-governed')throw Error('Isolated local demo required');app=admin.initializeApp({projectId},'ordinary-directive-test');db=app.firestore();await db.doc('users/issuer').set({isApproved:true,roles:['admin','operations'],name:'Issuer'});});
 afterAll(async()=>{if(app)await app.delete();});
 const createRequest=id=>({requestId:`create-${id}`,operation:'APPLY_ORDINARY_DIRECTIVE',directiveId:id,action:'create',expectedVersion:0,reason:'Issue reviewed instruction',before:null,after:{...fixture[0].entity,firestoreId:id}});
 const invoke=(data,database=db)=>mutate({db:database,authUid:'issuer',data,now:()=>new Date('2026-09-20T10:00:00Z')});
 test('two competing acknowledgements cannot both accept the same reviewed revision',async()=>{
  const id=`ordinary-race-${Date.now()}`,created=await invoke(createRequest(id));
  const make=n=>({requestId:`ack-${id}-${n}`,operation:'APPLY_ORDINARY_DIRECTIVE',directiveId:id,action:'acknowledge',expectedVersion:1,reason:'Received reviewed wording',before:created.entity,after:{...fixture[1].entity,firestoreId:id}});
  const results=await Promise.allSettled([invoke(make(1)),invoke(make(2))]);expect(results.filter(r=>r.status==='fulfilled')).toHaveLength(1);expect(results.filter(r=>r.status==='rejected')[0].reason.details.reasonCode).toBe('directive-reviewed-basis-changed');
  expect((await db.doc(`directives/${id}`).get()).data().version).toBe(2);
  const receipts=await Promise.all([1,2].map(n=>db.doc(`ordinary_directive_receipts/ack-${id}-${n}`).get()));expect(receipts.filter(r=>r.exists)).toHaveLength(1);
 });
 test('audit write failure leaves no business row or acceptance receipt',async()=>{
  const id=`ordinary-atomic-${Date.now()}`,request=createRequest(id);
  const proxy={collection:name=>db.collection(name),runTransaction:body=>db.runTransaction(tx=>body({get:ref=>tx.get(ref),set:(ref,data)=>{if(ref.path.startsWith('audit_logs/'))throw Error('Injected audit failure');return tx.set(ref,data);}}))};
  await expect(invoke(request,proxy)).rejects.toThrow('Injected audit failure');
  expect((await db.doc(`directives/${id}`).get()).exists).toBe(false);expect((await db.doc(`ordinary_directive_receipts/${request.requestId}`).get()).exists).toBe(false);
 });
});
