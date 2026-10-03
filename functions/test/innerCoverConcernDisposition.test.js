const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');

const at = (value) => new Date(value);

const persistedTimestamp = (value) => {
  const millis = Date.parse(value);
  return {
    _seconds: Math.floor(millis / 1000),
    _nanoseconds: (millis % 1000) * 1000000,
  };
};

const seedActor = (store, uid, roles) => {
  store.seed(`users/${uid}`, {isApproved: true, roles, name: uid});
  return {uid, name: uid};
};

const assetReference = ({
  classId,
  code,
  className,
  assetId,
  assetNumber,
  assetName,
  innerCoverAssociation = null,
}) => JSON.stringify({
  schemaVersion: 3,
  scope: 'physicalAsset',
  assetClassId: classId,
  assetClassCode: code,
  assetClassName: className,
  nodeId: assetId,
  nodeVersion: 1,
  nodeName: assetName,
  assetInstanceId: assetId,
  assetInstanceVersion: 1,
  assetNumber,
  assetInstanceName: assetName,
  componentInstanceId: null,
  componentInstanceVersion: null,
  componentTag: null,
  hierarchyPath: [className, assetName],
  ownershipStatus: 'unassigned',
  ownerDiscipline: null,
  accountableRoleKeys: [],
  innerCoverAssociation,
});

const linkedInnerCoverReference = () => ({
  baseAssetInstanceId: 'base-117',
  baseAssetNumber: 117,
  positionState: 'linked',
  innerCoverId: '33333333-3333-4333-8333-333333333333',
  innerCoverSerialNumber: 'GR26',
  linkageId: 'link-gr26-base-117',
  assignmentVersion: 3,
  linkedAt: '2026-08-01T04:00:00.000Z',
  eventAt: '2026-08-20T04:00:00.000Z',
  confirmedAt: '2026-08-20T04:04:00.000Z',
  confirmedByUid: 'operations-1',
  confirmedByName: 'operations-1',
});

const seedAssets = (store) => {
  store.seed('asset_classes/base-class', {
    schemaVersion: 1,
    assetClassId: 'base-class',
    code: 'BASE',
    name: 'Base',
    legacyAssetTypeKey: 'base',
    status: 'active',
  });
  store.seed('asset_classes/furnace-class', {
    schemaVersion: 1,
    assetClassId: 'furnace-class',
    code: 'FURNACE',
    name: 'Furnace',
    legacyAssetTypeKey: 'furnace',
    status: 'active',
  });
  store.seed('asset_instances/base-117', {
    schemaVersion: 1,
    assetInstanceId: 'base-117',
    assetClassId: 'base-class',
    assetClassCode: 'BASE',
    assetClassName: 'Base',
    assetNumber: 117,
    name: 'Base 117',
    status: 'active',
    version: 1,
    ownershipStatus: 'unassigned',
    ownerDiscipline: null,
    accountableRoleKeys: [],
  });
  store.seed('asset_instances/furnace-12', {
    schemaVersion: 1,
    assetInstanceId: 'furnace-12',
    assetClassId: 'furnace-class',
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    assetNumber: 12,
    name: 'Furnace 12',
    status: 'active',
    version: 1,
    ownershipStatus: 'unassigned',
    ownerDiscipline: null,
    accountableRoleKeys: [],
  });
  store.seed('base_inner_cover_assignments/base-117', {
    schemaVersion: 1,
    baseAssetInstanceId: 'base-117',
    baseAssetClassId: 'base-class',
    baseAssetNumber: 117,
    innerCoverId: '33333333-3333-4333-8333-333333333333',
    innerCoverSerialNumber: 'GR26',
    linkageId: 'link-gr26-base-117',
    linkedAt: '2026-08-01T04:00:00.000Z',
    version: 3,
  });
  store.seed('inner_cover_profiles/33333333-3333-4333-8333-333333333333', {
    schemaVersion: 1,
    innerCoverId: '33333333-3333-4333-8333-333333333333',
    serialNumber: 'GR26',
    lifecycleState: 'installed',
    currentBaseAssetInstanceId: 'base-117',
    currentBaseAssetNumber: 117,
    currentLinkageId: 'link-gr26-base-117',
  });
};

const createCommand = (ticketId = 'stuckup-case-1') => ({
  commandId: `createMaintenanceTicket_${ticketId}`,
  commandType: 'createMaintenanceTicket',
  aggregateId: ticketId,
  expectedVersion: 0,
  payload: {
    ticket: {
      schemaVersion: 1,
      version: 1,
      assetType: 'furnace',
      assetNumber: 12,
      component: 'Furnace / Inner Cover interface',
      subsystem: 'Furnace positioning and sealing',
      tag: null,
      hierarchyPath: ['Furnace', 'Furnace positioning and sealing'],
      assetHierarchyRefJson: assetReference({
        classId: 'furnace-class',
        code: 'FURNACE',
        className: 'Furnace',
        assetId: 'furnace-12',
        assetNumber: 12,
        assetName: 'Furnace 12',
      }),
      maintenanceType: 'breakdown',
      classification: 'furnaceStuckup',
      description: 'Furnace remains stuck on the Base during post-annealing removal.',
      routedTo: 'mechanical',
      otherDepartment: null,
      isCritical: true,
      startDate: '2026-08-20T04:00:00.000Z',
      chargeNoAtEvent: 12345,
      qualityIntentSchemaVersion: 1,
      qualityImpactAssessment: 'notSuspected',
      qualityWarningReason: null,
      furnaceStuckupSchemaVersion: 1,
      stuckupBaseNumber: 117,
      stuckupBaseAssetRefJson: assetReference({
        classId: 'base-class',
        code: 'BASE',
        className: 'Base',
        assetId: 'base-117',
        assetNumber: 117,
        assetName: 'Base 117',
        innerCoverAssociation: linkedInnerCoverReference(),
      }),
      stuckupSuspectedCause: 'innerCoverBulging',
      stuckupOperatingContext: 'postAnnealingRemoval',
    },
  },
});


const {createHash} = require('crypto');
const {stableJson} = require('../lib/maintenanceWorkflow/utils');
const hash = data => createHash('sha256').update(stableJson(data), 'utf8').digest('hex');
const casePath = 'furnace_stuckup_cases/stuckup-case-1';
const ticketPath = 'maintenance_records/stuckup-case-1';
const profilePath = 'inner_cover_profiles/33333333-3333-4333-8333-333333333333';
const auditPath = 'inner_cover_lifecycle_audits/inner_cover_88888888-8888-4888-8888-888888888888';
const receiptPath = 'inner_cover_lifecycle_receipts/88888888-8888-4888-8888-888888888888';
async function fixture() {
  const store = new MemoryWorkflowStore(); seedAssets(store);
  const admin = seedActor(store, 'admin-1', ['admin']);
  const si = seedActor(store, 'si-1', ['si']);
  const operations = seedActor(store, 'operations-1', ['operations']);
  const service = new MaintenanceWorkflowCommandService(store);
  await service.execute(createCommand(), {actor: operations, serverNow: at('2026-08-20T04:05:00Z')});
  await service.execute({commandId: 'release-1', commandType: 'releaseFurnaceStuckup', aggregateId: 'stuckup-case-1',
    expectedVersion: 1, payload: {releaseNotes: 'Furnace lifted clear and verified.'}},
    {actor: operations, serverNow: at('2026-08-20T05:00:00Z')});
  await service.execute({commandId: 'adjudicate-1', commandType: 'adjudicateFurnaceStuckup', aggregateId: 'stuckup-case-1',
    expectedVersion: 2, payload: {confirmedCause: 'innerCoverBulging', adjudicationNotes: 'Physical bulging confirmed.'}},
    {actor: si, serverNow: at('2026-08-20T06:00:00Z')});
  await service.execute({commandId: 'withdraw-1', commandType: 'correctMaintenanceTicket', aggregateId: 'stuckup-case-1',
    expectedVersion: store.read(ticketPath).version,
    payload: {withdrawInError: true, corrections: {}, reason: 'Issue withdrawn; technical concern retained.'}},
    {actor: admin, serverNow: at('2026-08-20T07:00:00Z')});
  // In-memory immutable acceptance fixture. Actual lifecycle form coverage is separate.
  const before = {innerCoverId: '33333333-3333-4333-8333-333333333333', serialNumber: 'GR26', version: 4,
    lifecycleState: 'underInspection', currentBaseAssetInstanceId: null, currentBaseAssetNumber: null,
    currentLinkageId: null, acceptedAt: '2026-08-01T00:00:00.000Z',
    assuranceInvalidatedAt: '2026-08-20T08:00:00.000Z',
    assuranceInvalidatedRecordedAt: '2026-08-20T08:00:00.000Z', assuranceEpisodeId: 'repair-episode-1',
    assuranceInvalidationReason: 'Repair after physical inspection'};
  const after = {...before, version: 5, lifecycleState: 'available', acceptedAt: '2026-08-21T08:00:00.000Z',
    acceptedByUid: admin.uid, acceptedByName: admin.name, acceptanceReference: 'INSPECTION-41',
    leakTestReference: 'LEAK-41', ndtReference: 'NDT-41', acceptanceNotes: 'Post-event inspection resolves this concern.'};
  const audit = {schemaVersion: 1, auditId: 'inner_cover_88888888-8888-4888-8888-888888888888', entityType: 'inner_cover',
    entityId: '33333333-3333-4333-8333-333333333333', secondaryEntityId: null, operation: 'ACCEPT_INNER_COVER', reason: 'Repair inspection',
    beforeJson: JSON.stringify(before), afterJson: JSON.stringify(after), secondaryAfterJson: null,
    relatedEntityChangesJson: null, performedAt: '2026-08-21T09:00:00.000Z',
    performedByUid: admin.uid, performedByName: admin.name, requestId: '88888888-8888-4888-8888-888888888888',
    fingerprint: 'v3:acceptance-fixture', timestampInstants: {inspectedOn: after.acceptedAt}};
  store.seed(auditPath, audit);
  store.seed(receiptPath, {schemaVersion: 1, requestId: '88888888-8888-4888-8888-888888888888', actorUid: admin.uid,
    operation: 'ACCEPT_INNER_COVER', innerCoverId: '33333333-3333-4333-8333-333333333333', version: 5, secondaryVersion: null,
    auditId: audit.auditId, committedAt: audit.performedAt, committedAtIso: audit.performedAt,
    fingerprint: audit.fingerprint, timestampInstants: audit.timestampInstants, auditEvidenceSha256: hash(audit)});
  store.seed(profilePath, {...after, assetClassId: '11111111-1111-4111-8111-111111111111', lastMutationId: '88888888-8888-4888-8888-888888888888'});
  store.seed('asset_classes/11111111-1111-4111-8111-111111111111', {legacyAssetTypeKey: 'innerCover', status: 'active'});
  const command = {commandId: 'settle-1', commandType: 'settleInnerCoverAssessment', aggregateId: 'stuckup-case-1',
    expectedVersion: 3, payload: {innerCoverId: '33333333-3333-4333-8333-333333333333', innerCoverSerialNumber: 'GR26',
      eventLinkageId: 'link-gr26-base-117', expectedTicketVersion: store.read(ticketPath).version,
      expectedCoverVersion: 5, acceptanceRequestId: '88888888-8888-4888-8888-888888888888', assessorConfirmed: true,
      reason: 'I reviewed the post-event inspection and accept its technical resolution of this case.'}};
  return {store, service, command, context: {actor: si, serverNow: at('2026-08-22T08:00:00Z')}, admin, si, operations};
}
describe('explicit withdrawn Inner Cover assessment settlement', () => {
  test.each(['si','admin'])('%s changes only case while preserving tombstone and all existing evidence', async role => {
    const f = await fixture(); const original = f.store.entries();
    const result = await f.service.execute(f.command, {...f.context, actor: f[role]});
    expect(result.resultKey).toBe('inner-cover-assessment-settled'); expect(result.aggregateVersion).toBe(4);
    expect(f.store.read(casePath).concernDisposition).toMatchObject({kind: 'postEventInspectionAccepted',
      acceptanceReference: 'INSPECTION-41', assessorConfirmed: true, settledByUid: f[role].uid});
    for (const [path,data] of original) if(path !== casePath) expect(f.store.read(path)).toEqual(data);
  });
  test('lost response is idempotent even after later cover movement', async () => {
    const f=await fixture(); const receipt=await f.service.execute(f.command,f.context); const count=f.store.entries().length;
    f.store.seed(profilePath,{...f.store.read(profilePath),version:6,lifecycleState:'installed',lastMutationId:'later'});
    expect(await f.service.execute(f.command,f.context)).toEqual(receipt); expect(f.store.entries()).toHaveLength(count);
    await expect(f.service.execute({...f.command,commandId:'settle-again',expectedVersion:4},f.context)).rejects.toThrow();
  });
  test('native Firestore disposition instants replay without writes after later movement', async () => {
    const {workflowFirestoreDataForTest} = require('../lib/maintenanceWorkflow/firebaseStore');
    const f = await fixture();
    // Use the production write adapter for the complete preexisting fixture and
    // accepted result, not a hand-built ISO-only substitute.
    for (const [path, data] of f.store.entries()) {
      f.store.seed(path, workflowFirestoreDataForTest(data));
    }
    const first = await f.service.execute(f.command, f.context);
    for (const [path, data] of f.store.entries()) {
      f.store.seed(path, workflowFirestoreDataForTest(data));
    }
    expect(f.store.read(casePath).concernDisposition.inspectedAt._seconds).toBeDefined();
    expect(f.store.read(casePath).concernDisposition.settledAt._seconds).toBeDefined();
    f.store.seed(profilePath, {...f.store.read(profilePath), version: 6,
      lifecycleState: 'installed', lastMutationId: 'later'});
    const before = f.store.entries();
    expect(await f.service.execute(f.command, f.context)).toEqual(first);
    expect(f.store.entries()).toEqual(before);
  });
  test.each(['inspectedAt', 'settledAt'])('native replay rejects changed %s without writes', async field => {
    const {workflowFirestoreDataForTest} = require('../lib/maintenanceWorkflow/firebaseStore');
    const {Timestamp} = require('firebase-admin/firestore');
    const f = await fixture();
    await f.service.execute(f.command, f.context);
    const row = workflowFirestoreDataForTest(f.store.read(casePath));
    row.concernDisposition[field] = Timestamp.fromMillis(row.concernDisposition[field].toMillis() + 1000);
    f.store.seed(casePath, row);
    const before = f.store.entries();
    await expect(f.service.execute(f.command, f.context)).rejects.toThrow();
    expect(f.store.entries()).toEqual(before);
  });
  test.each(['inspectedAt', 'settledAt'])('native replay rejects unsupported fractional %s without writes', async field => {
    const {workflowFirestoreDataForTest} = require('../lib/maintenanceWorkflow/firebaseStore');
    const {Timestamp} = require('firebase-admin/firestore');
    const f = await fixture();
    await f.service.execute(f.command, f.context);
    const row = workflowFirestoreDataForTest(f.store.read(casePath));
    const previous = row.concernDisposition[field];
    row.concernDisposition[field] = new Timestamp(previous.seconds, previous.nanoseconds + 1);
    f.store.seed(casePath, row);
    const before = f.store.entries();
    await expect(f.service.execute(f.command, f.context)).rejects.toThrow();
    expect(f.store.entries()).toEqual(before);
  });
  test('native replay still rejects an extra disposition field', async () => {
    const {workflowFirestoreDataForTest} = require('../lib/maintenanceWorkflow/firebaseStore');
    const f = await fixture();
    await f.service.execute(f.command, f.context);
    const row = workflowFirestoreDataForTest(f.store.read(casePath));
    row.concernDisposition.unexpected = true;
    f.store.seed(casePath, row);
    const before = f.store.entries();
    await expect(f.service.execute(f.command, f.context)).rejects.toThrow();
    expect(f.store.entries()).toEqual(before);
  });
  test.each([
    ['operations actor',f=>{f.context.actor=f.operations;}],
    ['unapproved SI',f=>f.store.seed('users/si-1',{isApproved:false,roles:['si'],name:'si-1'})],
    ['stale case',f=>{f.command.expectedVersion=2;}],
    ['stale ticket',f=>{f.command.payload.expectedTicketVersion++;}],
    ['stale cover',f=>{f.command.payload.expectedCoverVersion++;}],
    ['wrong serial',f=>{f.command.payload.innerCoverSerialNumber='OTHER';}],
    ['wrong event',f=>{f.command.payload.eventLinkageId='OTHER';}],
    ['no assessor confirmation',f=>{f.command.payload.assessorConfirmed=false;}],
    ['no reason',f=>{f.command.payload.reason='okay';}],
    ['not withdrawn',f=>f.store.seed(ticketPath,{...f.store.read(ticketPath),isDeleted:false})],
    ['not released',f=>f.store.seed(casePath,{...f.store.read(casePath),obstructionStatus:'active'})],
    ['not confirmed',f=>f.store.seed(casePath,{...f.store.read(casePath),adjudicationStatus:'inconclusive'})],
    ['still installed',f=>f.store.seed(profilePath,{...f.store.read(profilePath),lifecycleState:'installed'})],
    ['later manual restore',f=>f.store.seed(profilePath,{...f.store.read(profilePath),lastMutationId:'manual'})],
    ['acceptance audit missing',f=>f.store.seed(auditPath,{})],
    ['acceptance audit tampered',f=>f.store.seed(auditPath,{...f.store.read(auditPath),reason:'changed'})],
    ['acceptance actor mismatch',f=>f.store.seed(receiptPath,{...f.store.read(receiptPath),actorUid:'stranger'})],
    ['different assurance episode',f=>f.store.seed(profilePath,{...f.store.read(profilePath),assuranceEpisodeId:'other'})],
    ['different acceptance facts',f=>f.store.seed(profilePath,{...f.store.read(profilePath),acceptanceReference:'other'})],
    ['missing original cause evidence',f=>f.store.seed('asset_condition_evidence/'+f.store.read(casePath).conditionEvidenceId,{})],
    ['future recorded acceptance',f=>{const audit=f.store.read(auditPath);audit.performedAt='2027-01-01T00:00:00.000Z';
      f.store.seed(auditPath,audit);f.store.seed(receiptPath,{...f.store.read(receiptPath),
        committedAt:audit.performedAt,committedAtIso:audit.performedAt,auditEvidenceSha256:hash(audit)});}],
    ['unsupported fractional immutable time',f=>{const audit=f.store.read(auditPath);
      audit.performedAt={_seconds:1787302800,_nanoseconds:123};f.store.seed(auditPath,audit);}],
    ['withdrawal receipt missing',f=>f.store.seed('maintenance_workflow_command_receipts/withdraw-1',{})],
    ['withdrawal audit missing',f=>f.store.seed('audit_logs/server_maintenance_ticket_withdraw-1',{})],
    ['pre-event inspection',f=>{const audit=f.store.read(auditPath);const date='2026-08-19T08:00:00.000Z';
      audit.afterJson=JSON.stringify({...JSON.parse(audit.afterJson),acceptedAt:date});f.store.seed(auditPath,audit);
      f.store.seed(receiptPath,{...f.store.read(receiptPath),auditEvidenceSha256:hash(audit)});
      f.store.seed(profilePath,{...f.store.read(profilePath),acceptedAt:date});}],
  ])('denies %s without writes',async(_,mutate)=>{const f=await fixture();mutate(f);const before=f.store.entries();
    await expect(f.service.execute(f.command,f.context)).rejects.toThrow();expect(f.store.entries()).toEqual(before);});
  test.each([auditPath,receiptPath,'audit_logs/server_maintenance_ticket_withdraw-1',
    'maintenance_workflow_command_receipts/withdraw-1'])('retry refuses changed evidence %s',async path=>{
    const f=await fixture();await f.service.execute(f.command,f.context);f.store.seed(path,{...f.store.read(path),tampered:true});
    await expect(f.service.execute(f.command,f.context)).rejects.toThrow();});
});

function clone(value) {
  if (value == null) return value;
  // structuredClone returns a Date from another realm, so `instanceof Date`
  // fails on it and stored instants read as unparseable. Rebuild them the way
  // a real read would hand them back.
  if (value instanceof Date) return new Date(value.valueOf());
  if (Array.isArray(value)) return value.map(clone);
  if (typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, clone(item)]),
    );
  }
  return structuredClone(value);
}


function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];

  function snapshot(path, id) {
    const value = store.get(path);
    return {exists: value != null, id, data: () => clone(value)};
  }

  function ref(collection, id) {
    const path = `${collection}/${id}`;
    return {
      id,
      path,
      async get() { return snapshot(path, id); },
    };
  }

  function query(collection, clauses = [], max = null) {
    return {
      where(field, op, value) {
        return query(collection, [...clauses, [field, op, value]], max);
      },
      limit(value) {
        return query(collection, clauses, value);
      },
      _query: {collection, clauses, max},
    };
  }

  return {
    store,
    writes,
    db: {
      collection(name) {
        return {
          doc(id) { return ref(name, id); },
          where(field, op, value) { return query(name, [[field, op, value]]); },
        };
      },
      async runTransaction(fn) {
        const staged = [];
        const transaction = {
          async get(documentRef) {
            if (staged.length > 0) throw new Error('Transaction read after write');
            if (documentRef._query != null) {
              const {collection, clauses, max} = documentRef._query;
              const rows = [...store.entries()]
                .filter(([path]) => path.startsWith(`${collection}/`))
                .filter(([, value]) => clauses.every(([field, op, expected]) =>
                  op === '==' && value?.[field] === expected))
                .slice(0, max ?? Number.MAX_SAFE_INTEGER)
                .map(([path, value]) => snapshot(path, path.split('/').pop()));
              return {docs: rows};
            }
            return snapshot(documentRef.path, documentRef.id);
          },
          set(documentRef, data) {
            staged.push({kind: 'set', path: documentRef.path, data: clone(data)});
          },
          delete(documentRef) {
            staged.push({kind: 'delete', path: documentRef.path});
          },
        };
        const result = await fn(transaction);
        for (const write of staged) {
          if (write.kind === 'delete') store.delete(write.path);
          else store.set(write.path, clone(write.data));
          writes.push(write);
        }
        return result;
      },
    },
  };
}


const {mutateInnerCoverLifecycleWithDb} = require('../lib/innerCoverLifecycleMutation');
test('settlement consumes the real lifecycle handler acceptance audit and receipt', async () => {
  const f = await fixture();
  const cover = f.command.payload.innerCoverId;
  const classId = '11111111-1111-4111-8111-111111111111';
  const profile = {schemaVersion: 1, innerCoverId: cover, assetClassId: classId,
    assetClassCode: 'INNER_COVER', assetClassName: 'Inner Cover', serialNumber: 'GR26',
    normalizedSerialNumber: 'GR26', sourceType: 'legacyExisting', lifecycleState: 'underInspection',
    traceabilityGrade: 'T0', acceptanceReference: 'prior', acceptedAt: new Date('2026-08-01T00:00:00Z'),
    acceptedByUid: f.admin.uid, acceptedByName: f.admin.name,
    currentBaseAssetInstanceId: null, currentBaseAssetNumber: null, currentBaseAssetName: null,
    currentLinkageId: null, version: 4, lastMutationId: 'prior', assuranceEpisodeId: 'repair-episode-1',
    assuranceInvalidatedAt: new Date('2026-08-20T08:00:00Z'),
    assuranceInvalidatedRecordedAt: new Date('2026-08-20T08:00:00Z'),
    assuranceInvalidatedByUid: f.admin.uid, assuranceInvalidatedByName: f.admin.name,
    assuranceInvalidationReason: 'Physical repair for retained concern'};
  const memory = fakeDb({[profilePath]: profile,
    ['asset_classes/'+classId]: {schemaVersion:1,assetClassId:classId,code:'INNER_COVER',name:'Inner Cover',
      legacyAssetTypeKey:'innerCover',status:'active',version:1},
    'users/admin-1': {isApproved:true,roles:['admin'],name:f.admin.name}});
  await mutateInnerCoverLifecycleWithDb({db:memory.db,authUid:f.admin.uid,
    now:()=>new Date('2026-08-21T09:00:00Z'),timestampFromDate:date=>date,
    data:{requestId:f.command.payload.acceptanceRequestId,operation:'ACCEPT_INNER_COVER',
      innerCoverId:cover,expectedVersion:4,reason:'Post-event inspection verified after repair.',
      acceptanceDraft:{inspectedOn:'2026-08-21T08:00:00.000Z',acceptanceReference:'REAL-HANDLER-41',
        leakTestReference:'LEAK-41',ndtReference:'NDT-41',notes:'Actual handler evidence proves inspection after this event.'}}});
  for (const [path,data] of memory.store) f.store.seed(path,data);
  const result = await f.service.execute(f.command,f.context);
  expect(result.resultKey).toBe('inner-cover-assessment-settled');
  expect(f.store.read(casePath).concernDisposition.acceptanceReference).toBe('REAL-HANDLER-41');
  expect(await f.service.execute(f.command,f.context)).toEqual(result);
});
