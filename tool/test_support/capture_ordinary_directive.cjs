const fs=require('node:fs');
const {mutateOrdinaryDirectiveWithDb:mutate}=require('../../functions/lib/ordinaryDirectiveMutation');
const {fakeDb}=require('../../functions/test/helpers/qualityMemoryFirestore.cjs');
(async()=>{const t='2026-09-20T06:00:00.123456Z',id='directive-fixture',uid='issuer';const f=fakeDb({'users/issuer':{isApproved:true,roles:['admin','operations'],name:'Issuer'}});let before=null;const results=[];
let after={firestoreId:id,title:'Inspect cooler',description:'Record temperature',directedTo:'operations',status:'open',priority:'medium',createdByUid:uid,createdByName:'Issuer',issuedByUid:uid,issuedByName:'Issuer',issuedAt:t,isActive:true,closedWithoutAcknowledgement:false,isDeleted:false,createdAt:t,updatedAt:t,version:1};
for(const action of ['create','acknowledge','amend','close']){
 if(before){after={...before,version:before.version+1,updatedAt:'2026-09-20T06:01:00.123456Z'};
 if(action==='acknowledge')Object.assign(after,{status:'acknowledged',acknowledgedByUid:uid,acknowledgedByName:'Issuer',acknowledgedAt:after.updatedAt});
 if(action==='amend')Object.assign(after,{title:'Revised cooler instruction',status:'open',acknowledgedByUid:null,acknowledgedByName:null,acknowledgedAt:null});
 if(action==='close')Object.assign(after,{status:'closed',isActive:false,closedByUid:uid,closedByName:'Issuer',closedAt:after.updatedAt,closedWithoutAcknowledgement:true});}
 const result=await mutate({db:f.db,authUid:uid,now:()=>new Date('2026-09-20T07:00:00Z'),data:{requestId:`fixture-${action}`,operation:'APPLY_ORDINARY_DIRECTIVE',directiveId:id,expectedVersion:before?.version??0,action,reason:'Reviewed action',before,after}});results.push(result);before=result.entity;
}fs.writeFileSync('test/fixtures/ordinary_directive_actual_handler.json',JSON.stringify(results,null,2)+'\n');})().catch(e=>{console.error(e);process.exitCode=1;});
