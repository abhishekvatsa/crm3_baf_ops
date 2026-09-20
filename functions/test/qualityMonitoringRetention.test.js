const {
  planQualityMonitoringArchive,
} = require('../lib/qualityMonitoringRetention');

const requestId = '44444444-4444-4444-8444-444444444444';
const closedAt = new Date('2026-08-14T12:00:00.000Z');
const visibleUntil = new Date('2026-08-21T12:00:00.000Z');

function monitoring(overrides = {}) {
  return {
    schemaVersion: 2,
    requestId,
    baseNumber: 12,
    grade: 'CRGO M4',
    cycleReference: 'Cycle family 7A',
    chargeNumbers: [12001, 12002],
    reason: 'Monitor atmosphere stability during the campaign.',
    status: 'closed',
    visibilityState: 'recent',
    visibleUntil,
    archivedAt: null,
    createdAt: new Date('2026-08-14T08:00:00.000Z'),
    createdByUid: 'si-1',
    createdByName: 'SI One',
    closedAt,
    closedByUid: 'admin-1',
    closedByName: 'Admin One',
    closeReason: 'The monitoring campaign is complete.',
    updatedAt: closedAt,
    updatedByUid: 'admin-1',
    updatedByName: 'Admin One',
    version: 2,
    lastMutationId: '55555555-5555-4555-8555-555555555555',
    ...overrides,
  };
}

describe('quality monitoring operational retention', () => {
  test('keeps a recent closure visible until the exact server deadline', () => {
    expect(planQualityMonitoringArchive({
      data: monitoring(),
      requestId,
      now: new Date('2026-08-21T11:59:59.999Z'),
    })).toBeNull();
  });

  test('archives at the server deadline without changing business version', () => {
    const patch = planQualityMonitoringArchive({
      data: monitoring(),
      requestId,
      now: visibleUntil,
    });

    expect(patch).toEqual({
      schemaVersion: 2,
      visibilityState: 'archived',
      visibleUntil: null,
      archivedAt: visibleUntil,
    });
    expect(patch).not.toHaveProperty('version');
    expect(patch).not.toHaveProperty('lastMutationId');
  });

  test('preserves governed Base identity and schema while archiving', () => {
    const patch = planQualityMonitoringArchive({
      data: monitoring({
        schemaVersion: 3,
        baseAssetClassId: 'base-class',
        baseAssetInstanceId: 'base-12',
        baseAssetInstanceVersion: 4,
      }),
      requestId,
      now: visibleUntil,
    });

    expect(patch).toEqual({
      schemaVersion: 3,
      visibilityState: 'archived',
      visibleUntil: null,
      archivedAt: visibleUntil,
    });
  });

  test('archives an exact legacy closure through a schema-v2 upgrade', () => {
    const legacy = monitoring({schemaVersion: 1});
    delete legacy.visibilityState;
    delete legacy.visibleUntil;
    delete legacy.archivedAt;

    expect(planQualityMonitoringArchive({
      data: legacy,
      requestId,
      now: visibleUntil,
    })).toEqual({
      schemaVersion: 2,
      visibilityState: 'archived',
      visibleUntil: null,
      archivedAt: visibleUntil,
    });
  });

  test('an archived record is idempotently ignored', () => {
    expect(planQualityMonitoringArchive({
      data: monitoring({
        visibilityState: 'archived',
        visibleUntil: null,
        archivedAt: visibleUntil,
      }),
      requestId,
      now: new Date('2026-08-22T12:00:00.000Z'),
    })).toBeNull();
  });

  test.each([
    ['missing deadline', {visibleUntil: null}],
    ['wrong deadline', {visibleUntil: new Date('2026-08-21T11:59:59.999Z')}],
    ['premature archive', {
      visibilityState: 'archived',
      visibleUntil: null,
      archivedAt: new Date('2026-08-21T11:59:59.999Z'),
    }],
  ])('fails closed for %s', (_label, overrides) => {
    expect(() => planQualityMonitoringArchive({
      data: monitoring(overrides),
      requestId,
      now: new Date('2026-08-22T12:00:00.000Z'),
    })).toThrow();
  });
});

// Exercise the complete worker and its persistent checkpoint, not just the patch planner.
const {archiveDueQualityMonitoringRequests} = require('../lib/qualityMonitoringRetention');
const {Timestamp} = require('firebase-admin/firestore');
const logger = require('firebase-functions/logger');
function pagedStore(seed) {
  const store = new Map(Object.entries(seed)); const limits=[];
  const millis=v=>v instanceof Date?v.valueOf():v?.toMillis?.() ?? Date.parse(v);
  const snapshot=(path)=>({id:path.split('/').pop(),ref:ref(path),exists:store.has(path),data:()=>store.get(path)});
  const ref=path=>({path,id:path.split('/').pop(),get:async()=>snapshot(path)});
  let rejectCheckpoint=false;
  const db={collection(name){return {doc:id=>ref(`${name}/${id}`),where(field,op,value){
    let cursor=null,limit=200;
    const q={orderBy(){return q;},startAfter(...values){cursor=values;return q;},limit(n){if(n<=0)throw Error('nonpositive limit');limits.push(n);limit=n;return q;},async get(){
      let rows=[...store].filter(([p,d])=>p.startsWith(name+'/') && (op==='=='?d[field]===value:d[field]!=null && millis(d[field])<=millis(value)));
      rows.sort((a,b)=>field==='visibleUntil'?(millis(a[1][field])-millis(b[1][field]) || a[0].localeCompare(b[0])):a[0].localeCompare(b[0]));
      if(cursor)rows=rows.filter(([p,d])=>field==='visibleUntil'?millis(d[field])>millis(cursor[0]) || millis(d[field])===millis(cursor[0])&&p.split('/').pop()>cursor[1]:p.split('/').pop()>cursor[0]);
      const docs=rows.slice(0,limit).map(([p])=>snapshot(p));return {docs,size:docs.length};
    }};return q;}};},async runTransaction(fn){
      const pending=[];const result=await fn({get:async r=>snapshot(r.path),update:(r,d)=>pending.push([r.path,{...store.get(r.path),...d}]),set:(r,d)=>pending.push([r.path,d])});
      if(rejectCheckpoint && pending.some(([p])=>p.startsWith('_maintenance_cursors/')))throw Error('checkpoint interrupted');
      for(const [p,d]of pending)store.set(p,d);return result;
    }};
  return {db,store,limits,set rejectCheckpoint(value){rejectCheckpoint=value;}};
}
const workerNow=Timestamp.fromDate(new Date('2026-08-22T12:00:00Z'));
const checkpoint='_maintenance_cursors/quality-monitoring-archive-v1';
test('more than one scan budget of poison rows cannot starve later good rows or the legacy lane',async()=>{
  const silence=jest.spyOn(logger,'error').mockImplementation(()=>{});
  try{
    const seed={};for(let i=0;i<5001;i++)seed[`quality_monitoring_requests/a-${String(i).padStart(5,'0')}`]={visibleUntil};
    seed['quality_monitoring_requests/z-good']=monitoring({requestId:'z-good'});
    const legacy=monitoring({requestId:'legacy',schemaVersion:1});for(const k of ['visibilityState','visibleUntil','archivedAt'])delete legacy[k];
    seed['quality_monitoring_requests/legacy']=legacy;
    const m=pagedStore(seed);const first=await archiveDueQualityMonitoringRequests({db:m.db,now:workerNow});
    expect(first).toMatchObject({archived:1,rejected:100,capped:true});expect(m.store.get(checkpoint).due.id).toBe('a-04999');
    expect(m.store.get('quality_monitoring_requests/legacy').visibilityState).toBe('archived');
    const second=await archiveDueQualityMonitoringRequests({db:m.db,now:workerNow});
    expect(second.archived).toBe(1);expect(m.store.get('quality_monitoring_requests/z-good').visibilityState).toBe('archived');
    expect(m.store.get('quality_monitoring_requests/a-00000')).toEqual({visibleUntil});
    expect(m.store.get(checkpoint).due).toBeNull();expect(Math.min(...m.limits)).toBeGreaterThan(0);
  }finally{silence.mockRestore();}
});
test('full eligible budget advances and a failed checkpoint safely repeats without deleting evidence',async()=>{
  const seed={};for(let i=0;i<1001;i++){const id=`valid-${String(i).padStart(5,'0')}`;seed[`quality_monitoring_requests/${id}`]=monitoring({requestId:id});}
  const m=pagedStore(seed);m.rejectCheckpoint=true;
  await expect(archiveDueQualityMonitoringRequests({db:m.db,now:workerNow})).rejects.toThrow('checkpoint interrupted');
  expect(m.store.has(checkpoint)).toBe(false);
  expect([...m.store.values()].filter(d=>d.visibilityState==='archived')).toHaveLength(1000);
  m.rejectCheckpoint=false;const resumed=await archiveDueQualityMonitoringRequests({db:m.db,now:workerNow});
  expect(resumed.archived).toBe(1);expect([...m.store.values()].filter(d=>d.visibilityState==='archived')).toHaveLength(1001);
  expect(Math.min(...m.limits)).toBeGreaterThan(0);
});
