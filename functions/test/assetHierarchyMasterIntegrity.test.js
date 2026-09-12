const fs = require('fs');
const path = require('path');
const {createHash} = require('crypto');
const {Timestamp} = require('firebase-admin/firestore');
const {mutateAssetHierarchyWithDb} = require('../lib/assetHierarchyMutation');
const {mutateAssetRegistryWithDb} = require('../lib/assetRegistryMutation');
const {mutateBurnerConditionRoundWithDb} = require('../lib/burnerConditionRoundMutation');
const {mutateInnerCoverLifecycleWithDb} = require('../lib/innerCoverLifecycleMutation');

const id = (n) => `${String(n).padStart(8, '0')}-1111-4111-8111-111111111111`;
const classId = id(1);
const nodeId = id(2);
const fixedTime = new Date('2026-09-12T12:00:00.000Z');
const fixturePath = path.join(__dirname, 'fixtures/hierarchy_legacy_acceptance.json');

function clone(value) {
  if (value instanceof Timestamp) return new Timestamp(value.seconds, value.nanoseconds);
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  if (value != null && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, clone(child)]));
  }
  return value;
}

function memoryDb() {
  const store = new Map([
    ['users/admin-1', {isApproved: true, roles: ['admin'], name: 'Admin One'}],
    ['users/admin-2', {isApproved: true, roles: ['admin'], name: 'Admin Two'}],
  ]);
  const revisions = new Map();
  const writes = [];
  const document = (key) => ({exists: store.has(key), id: key.split('/').at(-1),
    data: () => clone(store.get(key))});
  const ref = (key) => ({path: key, id: key.split('/').at(-1), get: async () => document(key)});
  const query = (name, filters = [], max = Infinity) => ({name, filters, max,
    where: (field, op, value) => query(name, [...filters, [field, op, value]], max),
    limit: (limit) => query(name, filters, limit)});
  const db = {
    collection: (name) => ({...query(name), doc: (key) => ref(`${name}/${key}`)}),
    async runTransaction(body) {
      for (let attempt = 0; attempt < 15; attempt++) {
        const reads = new Map(); const staged = [];
        const read = (key) => {
          if (!reads.has(key)) reads.set(key, revisions.get(key) ?? 0);
          return document(key);
        };
        const result = await body({
          get: async (target) => {
            if (staged.length > 0) throw new Error('Transaction read after write');
            if (target.path) return read(target.path);
            const matching = [...store].filter(([key, data]) => key.startsWith(`${target.name}/`) &&
              target.filters.every(([field, op, value]) => {
                if (op !== '==') throw new Error(`Unsupported query operator ${op}`);
                return data[field] === value;
              })).slice(0, target.max);
            // Deliberately no invented empty-query lock: the shared document
            // guard must serialize otherwise disjoint class/profile writers.
            return {docs: matching.map(([key]) => read(key))};
          },
          set: (target, value) => staged.push([target.path, clone(value)]),
          delete: (target) => staged.push([target.path, undefined]),
        });
        if ([...reads].some(([key, revision]) => (revisions.get(key) ?? 0) !== revision)) continue;
        for (const [key, value] of staged) {
          if (value === undefined) store.delete(key); else store.set(key, value);
          revisions.set(key, (revisions.get(key) ?? 0) + 1);
          writes.push(key);
        }
        return result;
      }
      throw new Error('Transaction retry limit exceeded');
    },
  };
  return {store, writes, db};
}
const invoke = (memory, data, authUid = 'admin-1') => mutateAssetHierarchyWithDb({
  db: memory.db, data, authUid, now: () => fixedTime, timestampFromDate: Timestamp.fromDate,
});
const invokeCover = (memory, data) => mutateInnerCoverLifecycleWithDb({
  db: memory.db, data, authUid: 'admin-1', now: () => fixedTime, timestampFromDate: Timestamp.fromDate,
});
const createClass = (overrides = {}) => ({requestId: id(10), operation: 'CREATE_CLASS',
  assetClassId: classId, reason: 'Create the reviewed operational class.',
  classDraft: {code: 'FURNACE', name: 'Furnace', majorArea: 'BAF',
    shortDescription: null, longDescription: null, legacyAssetTypeKey: 'furnace'}, ...overrides});
const updateClass = (a, fields = {}) => ({...a, requestId: id(11), operation: 'UPDATE_CLASS',
  expectedVersion: 1, classDraft: {...a.classDraft, ...fields}});
const classStatus = (status, expectedVersion = 1, assetClassId = classId) => ({
  requestId: id(12), operation: 'SET_CLASS_STATUS', assetClassId, expectedVersion,
  status, reason: 'Review the class availability.',
});
const draft = (name, parentNodeId = null) => ({parentNodeId, nodeType: 'component', name,
  componentTag: null, shortDescription: null, longDescription: null, discipline: null,
  operatingType: null, normalState: null, failState: null, contactArrangement: 'notStated',
  manufacturer: null, model: null, applicability: null, sourceReference: null,
  ownershipStatus: 'unassigned', ownerDiscipline: null, accountableRoleKeys: [], sortOrder: 1});
const createNode = (n, parent = null) => ({requestId: id(100 + n), operation: 'CREATE_NODE',
  assetClassId: classId, nodeId: id(n), expectedAssetClassVersion: 1,
  reason: 'Create the reviewed hierarchy definition.', nodeDraft: draft(`Node ${n}`, parent)});
const updateNode = (n, parent, expectedVersion = 1) => ({...createNode(n, parent),
  requestId: id(200 + n), operation: 'UPDATE_NODE', expectedVersion,
  expectedAssetClassVersion: undefined});
const nodeStatus = (n, status, version) => ({requestId: id(300 + n), operation: 'SET_NODE_STATUS',
  assetClassId: classId, nodeId: id(n), expectedVersion: version, status,
  reason: 'Review this definition availability.'});
const state = (memory) => clone([...memory.store]);
const storedNode = (memory, n) => memory.store.get(`asset_hierarchy_nodes/${id(n)}`);

const coverClass = () => createClass({classDraft: {...createClass().classDraft,
  code: 'INNER_COVER', name: 'Inner Cover', legacyAssetTypeKey: 'innerCover'}});
const registration = () => ({requestId: id(500), operation: 'REGISTER_INNER_COVER',
  innerCoverId: id(501), innerCoverAssetClassId: classId, reason: 'Register received serial inventory.',
  registrationDraft: {serialNumber: 'IC-501', sourceType: 'purchased',
    originClassification: 'documentedPurchase', supplierOrFabricator: 'Approved supplier',
    receivedOrCompletedOn: '2026-09-01T00:00:00.000Z', incorporatedOn: '2026-09-01T12:00:00.000Z',
    drawingReference: 'IC-001', materialGrade: 'SS 321', notes: null, fabricationSections: []}});
async function acceptedCover(m) {
  await invoke(m, coverClass()); await invokeCover(m, registration());
  await invokeCover(m, {requestId: id(502), operation: 'ACCEPT_INNER_COVER', innerCoverId: id(501),
    expectedVersion: 1, reason: 'Inspection complete.', acceptanceDraft: {
      inspectedOn: '2026-09-02T00:00:00.000Z', acceptanceReference: 'ACC-501',
      leakTestReference: null, ndtReference: null, notes: null}});
}
async function retiredCover(m) {
  await acceptedCover(m);
  await invokeCover(m, {requestId: id(503), operation: 'SET_INNER_COVER_STATE', innerCoverId: id(501),
    expectedVersion: 2, targetState: 'retiredForSalvage', retirementCondition: 'notBulged',
    reason: 'Retired after service inspection.'});
}

describe('serial-aware class retirement', () => {
  test.each(['available', 'reserved', 'installed', 'awaitingInspection', 'underInspection',
    'underRepair', 'underFabrication', 'quarantined', 'rejected', 'unknown'])
  ('live or unrecognized serial state prevents retirement: %s', async (lifecycleState) => {
    const m = memoryDb(); await acceptedCover(m);
    m.store.get(`inner_cover_profiles/${id(501)}`).lifecycleState = lifecycleState;
    const before = state(m);
    await expect(invoke(m, classStatus('retired'))).rejects.toMatchObject({
      details: {reasonCode: 'asset-class-live-inner-covers'},
    });
    expect(state(m)).toEqual(before);
  });
  test.each(['retiredForSalvage', 'partiallyDismantled', 'fullyConsumedAsDonor', 'disposed'])
  ('canonical retired/dismantled history permits retirement: %s', async (target) => {
    const m = memoryDb(); await retiredCover(m);
    let version = 3;
    const steps = target === 'retiredForSalvage' ? [] : target === 'disposed' ? ['disposed'] :
      target === 'partiallyDismantled' ? ['partiallyDismantled'] : ['partiallyDismantled', 'fullyConsumedAsDonor'];
    for (const targetState of steps) {
      await invokeCover(m, {requestId: id(510 + version), operation: 'SET_INNER_COVER_STATE',
        innerCoverId: id(501), expectedVersion: version++, targetState,
        reason: 'Record the retained salvage disposition.'});
    }
    const retained = clone(m.store.get(`inner_cover_profiles/${id(501)}`));
    await invoke(m, classStatus('retired'));
    expect(m.store.get(`asset_classes/${classId}`).status).toBe('retired');
    expect(m.store.get(`inner_cover_profiles/${id(501)}`)).toEqual(retained);
  });
  test('registration versus initially empty retirement cannot both commit', async () => {
    const m = memoryDb(); await invoke(m, coverClass());
    const results = await Promise.allSettled([invoke(m, classStatus('retired')), invokeCover(m, registration())]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(m.store.get(`asset_classes/${classId}`).status === 'retired' &&
      m.store.has(`inner_cover_profiles/${id(501)}`)).toBe(false);
  });
  test('return from salvage requires active class and serializes against retirement', async () => {
    const m = memoryDb(); await retiredCover(m);
    const returning = {requestId: id(520), operation: 'SET_INNER_COVER_STATE', innerCoverId: id(501),
      expectedVersion: 3, targetState: 'awaitingInspection', reason: 'Return for inspection.'};
    const results = await Promise.allSettled([invoke(m, classStatus('retired')), invokeCover(m, returning)]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(m.store.get(`asset_classes/${classId}`).status === 'retired' &&
      m.store.get(`inner_cover_profiles/${id(501)}`).lifecycleState === 'awaitingInspection').toBe(false);
    if (m.store.get(`asset_classes/${classId}`).status === 'retired') {
      await expect(invokeCover(m, returning)).rejects.toMatchObject({code: 'failed-precondition'});
    }
  });
  test.each(['retirement', 'registration'])('malformed serial guard blocks %s without writes', async (operation) => {
    const m = memoryDb(); await invoke(m, coverClass());
    m.store.set(`asset_class_mutation_guards/serialInventory:${classId}`, {schemaVersion: 1, version: 1});
    const before = state(m);
    await expect(operation === 'retirement' ? invoke(m, classStatus('retired')) : invokeCover(m, registration()))
      .rejects.toMatchObject({details: {reasonCode: 'asset-class-guard-malformed'}});
    expect(state(m)).toEqual(before);
  });
});

describe('class display rename preserves stable operational identity', () => {
  test('actual create-class, register-furnace, rename-class, burner-round journey succeeds without rewriting old snapshots', async () => {
    const m = memoryDb(); const a = createClass(); await invoke(m, a);
    await mutateAssetRegistryWithDb({db: m.db, authUid: 'admin-1', now: () => fixedTime,
      timestampFromDate: Timestamp.fromDate, data: {requestId: id(600), operation: 'CREATE_ASSET_INSTANCE',
        assetClassId: classId, assetInstanceId: id(601), expectedAssetClassVersion: 1,
        reason: 'Register Furnace 7.', assetDraft: {assetNumber: 7, name: 'Furnace 7', plantTag: null,
          location: null, manufacturer: null, model: null, serialNumber: null, commissionedOn: null,
          serviceState: 'inService', ownershipStatus: 'unassigned', ownerDiscipline: null, accountableRoleKeys: []}}});
    const physicalBefore = clone(m.store.get(`asset_instances/${id(601)}`));
    await invoke(m, updateClass(a, {name: 'BAF Heating Furnaces'}));
    const result = await mutateBurnerConditionRoundWithDb({db: m.db, authUid: 'admin-1', now: () => fixedTime,
      timestampFromDate: Timestamp.fromDate, data: {requestId: id(602), operation: 'RECORD_BURNER_CONDITION_ROUND',
        assetClassId: classId, assetInstanceId: id(601), expectedAssetVersion: 1, roundNote: 'Routine round.',
        observations: Array.from({length: 8}, (_, n) => ({position: n + 1, flameObservation: 'seen',
          redHotObserved: false, microampReading: null, remarks: null}))}});
    expect(result.ok).toBe(true);
    expect(m.store.get(`asset_instances/${id(601)}`)).toEqual(physicalBefore);
    expect(m.store.get(`asset_classes/${classId}`).name).toBe('BAF Heating Furnaces');
    expect(m.store.get(`burner_condition_rounds/${id(602)}`).assetClassName).toBe('Furnace');
  });
});

describe('master-data topology and canonical roles', () => {
  test('move a leaf to root: actual handler clears ancestry/path and decrements only the old parent', async () => {
    const m = memoryDb(); await invoke(m, createClass());
    await invoke(m, createNode(2)); await invoke(m, createNode(3, nodeId));
    const result = await invoke(m, updateNode(3, null));
    expect(storedNode(m, 3)).toMatchObject({parentNodeId: null, ancestorNodeIds: [],
      hierarchyPath: ['Node 3'], version: 2});
    expect(storedNode(m, 2)).toMatchObject({activeChildCount: 0, version: 3});
    const before = state(m);
    expect(await invoke(m, updateNode(3, null))).toEqual({...result, idempotentReplay: true});
    expect(state(m)).toEqual(before);
  });
  test('root to parent, parent to parent, and status-only commands preserve topology and exact counters', async () => {
    const m = memoryDb(); await invoke(m, createClass());
    for (const n of [2, 3, 4]) await invoke(m, createNode(n));
    await invoke(m, updateNode(4, id(2)));
    await invoke(m, {...updateNode(4, id(3), 2), requestId: id(401)});
    expect(storedNode(m, 2).activeChildCount).toBe(0);
    expect(storedNode(m, 3).activeChildCount).toBe(1);
    expect(storedNode(m, 4)).toMatchObject({parentNodeId: id(3), ancestorNodeIds: [id(3)],
      hierarchyPath: ['Node 3', 'Node 4']});
    await invoke(m, nodeStatus(4, 'retired', 3));
    expect(storedNode(m, 4).parentNodeId).toBe(id(3));
    expect(storedNode(m, 3).activeChildCount).toBe(0);
    await invoke(m, {...nodeStatus(4, 'active', 4), requestId: id(402)});
    expect(storedNode(m, 3).activeChildCount).toBe(1);
  });
  test.each(['count', 'children', 'cross-class', 'cycle'])('bad topology fails without partial writes: %s', async (kind) => {
    const m = memoryDb(); await invoke(m, createClass());
    await invoke(m, createNode(2)); await invoke(m, createNode(3, nodeId));
    let request = updateNode(3, null);
    if (kind === 'count') storedNode(m, 2).activeChildCount = 0;
    if (kind === 'children') { await invoke(m, createNode(4, id(3))); request.expectedVersion = 2; }
    if (kind === 'cross-class') {
      await invoke(m, createNode(4)); storedNode(m, 4).assetClassId = id(9);
      request.nodeDraft.parentNodeId = id(4);
    }
    if (kind === 'cycle') request.nodeDraft.parentNodeId = id(3);
    const before = state(m);
    await expect(invoke(m, request)).rejects.toMatchObject({code: 'failed-precondition'});
    expect(state(m)).toEqual(before);
  });
  test('concurrent distinct codes cannot acquire the same canonical role', async () => {
    const m = memoryDb(); const a = createClass();
    const b = createClass({requestId: id(20), assetClassId: id(21),
      classDraft: {...a.classDraft, code: 'FURNACE_ALT'}});
    const results = await Promise.allSettled([invoke(m, a), invoke(m, b)]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(results.find((r) => r.status === 'rejected').reason.details.reasonCode)
      .toBe('asset-class-legacy-role-collision');
    expect([...m.store].filter(([key]) => key.startsWith('asset_classes/'))).toHaveLength(1);
  });
  test('legacy bootstrap queries real owners; edit and restore cannot duplicate a role', async () => {
    const m = memoryDb(); const a = createClass(); await invoke(m, a);
    m.store.delete('asset_class_mutation_guards/legacyRole:furnace');
    const b = createClass({requestId: id(20), assetClassId: id(21),
      classDraft: {...a.classDraft, code: 'OTHER', legacyAssetTypeKey: null}});
    await invoke(m, b);
    await expect(invoke(m, {...updateClass(b, {legacyAssetTypeKey: 'furnace'}), requestId: id(22)}))
      .rejects.toMatchObject({details: {reasonCode: 'asset-class-legacy-role-collision'}});
    await invoke(m, classStatus('retired'));
    await invoke(m, {...updateClass(b, {legacyAssetTypeKey: 'furnace'}), requestId: id(22)});
    await expect(invoke(m, {...classStatus('active', 2), requestId: id(23)}))
      .rejects.toMatchObject({details: {reasonCode: 'asset-class-legacy-role-collision'}});
  });
  test.each(['update', 'restore'])('concurrent %s commands serialize role acquisition across existing classes', async (kind) => {
    const m = memoryDb();
    const a = createClass({classDraft: {...createClass().classDraft, legacyAssetTypeKey: null}});
    const b = createClass({requestId: id(20), assetClassId: id(21),
      classDraft: {...a.classDraft, code: 'SECOND'}});
    await invoke(m, a); await invoke(m, b);
    if (kind === 'restore') {
      for (const [n, request] of [[30, a], [40, b]]) {
        await invoke(m, {...updateClass(request, {legacyAssetTypeKey: 'furnace'}), requestId: id(n)});
        await invoke(m, {...classStatus('retired', 2, request.assetClassId), requestId: id(n + 1)});
      }
    }
    const commands = [a, b].map((request, n) => kind === 'update' ?
      {...updateClass(request, {legacyAssetTypeKey: 'furnace'}), requestId: id(50 + n)} :
      {...classStatus('active', 3, request.assetClassId), requestId: id(50 + n)});
    const results = await Promise.allSettled(commands.map((command) => invoke(m, command)));
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(results.find((r) => r.status === 'rejected').reason.details.reasonCode)
      .toBe('asset-class-legacy-role-collision');
  });
  test('releasing a role allows the next owner and malformed guards fail closed', async () => {
    const m = memoryDb(); const a = createClass(); await invoke(m, a);
    await invoke(m, updateClass(a, {legacyAssetTypeKey: null}));
    await invoke(m, createClass({requestId: id(20), assetClassId: id(21),
      classDraft: {...a.classDraft, code: 'FURNACE_ALT'}}));
    m.store.get('asset_class_mutation_guards/legacyRole:furnace').key = 'base';
    const before = state(m);
    await expect(invoke(m, {...classStatus('retired', 1, id(21)), requestId: id(24)}))
      .rejects.toMatchObject({details: {reasonCode: 'asset-class-guard-malformed'}});
    expect(state(m)).toEqual(before);
  });
});

describe('hierarchy immutable acceptance', () => {
  (process.env.CAPTURE_HIERARCHY_LEGACY === '1' ? test : test.skip)(
    'capture unmodified pre-upgrade handler evidence once', async () => {
      const m = memoryDb(); const request = createClass(); await invoke(m, request);
      const encode = (value) => {
        if (value instanceof Timestamp) return {fixtureTimestampIso: value.toDate().toISOString()};
        if (Array.isArray(value)) return value.map(encode);
        if (value != null && typeof value === 'object') return Object.fromEntries(
          Object.entries(value).map(([key, child]) => [key, encode(child)]));
        return value;
      };
      const source = fs.readFileSync(path.join(__dirname, '../lib/assetHierarchyMutation.js'));
      const receipt = m.store.get(`asset_hierarchy_mutation_receipts/${request.requestId}`);
      expect(receipt.fingerprint).toMatch(/^assetreq1-sha256:/);
      fs.writeFileSync(fixturePath, JSON.stringify({provenance: {
        sourceCommit: '2ae7cbb45720fe61566b70a38d1bf9a1519e05ca',
        compiledHandlerSha256: createHash('sha256').update(source).digest('hex'),
        description: 'Actual pre-upgrade compiled mutation, no rebased receipt or fingerprint.',
      }, request, documents: encode([...m.store])}, null, 2) + '\n');
    });
  test.each(['class', 'node', 'parent-count'])('A/B/A returns original acceptance and preserves B: %s', async (kind) => {
    const m = memoryDb(); const a = kind === 'class' ? createClass() : createNode(2);
    if (kind !== 'class') await invoke(m, createClass());
    const accepted = await invoke(m, a);
    if (kind === 'class') await invoke(m, updateClass(a, {name: 'Reviewed Furnace'}));
    if (kind === 'node') await invoke(m, {...updateNode(2, null), nodeDraft: draft('Reviewed definition')});
    if (kind === 'parent-count') await invoke(m, createNode(3, nodeId));
    const before = state(m);
    expect(await invoke(m, a)).toEqual({...accepted, idempotentReplay: true});
    expect(state(m)).toEqual(before);
  });
  test.each(['actor', 'payload', 'receipt-id', 'receipt-time', 'audit-time', 'after', 'audit-id',
    'audit-missing', 'audit-actor', 'audit-fingerprint', 'proof-removed', 'downgrade'])('contradictory evidence refuses replay: %s', async (kind) => {
    const m = memoryDb(); let request = createClass(); await invoke(m, request);
    const receipt = m.store.get(`asset_hierarchy_mutation_receipts/${request.requestId}`);
    const audit = m.store.get(`asset_hierarchy_audits/asset_hierarchy_${request.requestId}`);
    let actor = 'admin-1';
    if (kind === 'actor') actor = 'admin-2';
    if (kind === 'payload') request = {...request, reason: 'Another request.'};
    if (kind === 'receipt-id') receipt.requestId = id(999);
    if (kind === 'receipt-time') receipt.committedAt = new Timestamp(receipt.committedAt.seconds, 1);
    if (kind === 'audit-time') audit.performedAt = new Timestamp(audit.performedAt.seconds, 1);
    if (kind === 'after') audit.afterJson = JSON.stringify({...JSON.parse(audit.afterJson), name: 'Tampered'});
    if (kind === 'audit-id') receipt.auditId = 'another_audit';
    if (kind === 'audit-missing') m.store.delete(`asset_hierarchy_audits/asset_hierarchy_${request.requestId}`);
    if (kind === 'audit-actor') audit.performedByUid = 'admin-2';
    if (kind === 'audit-fingerprint') audit.fingerprint = receipt.fingerprint.replace('assetreq2', 'assetreq1');
    if (kind === 'proof-removed') { delete receipt.evidenceVersion; delete receipt.auditEvidenceSha256; }
    if (kind === 'downgrade') {
      receipt.fingerprint = receipt.fingerprint.replace('assetreq2', 'assetreq1');
      delete receipt.evidenceVersion; delete receipt.auditEvidenceSha256;
    }
    const before = state(m);
    await expect(invoke(m, request, actor)).rejects.toMatchObject({code: kind === 'audit-missing' ? 'not-found' : 'data-loss'});
    expect(state(m)).toEqual(before);
  });
  test.each(['name', 'creator', 'creator-name'])('actual historical receipt survives B; legacy %s tamper refuses replay', async (kind) => {
    const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
    const decode = (value) => {
      if (value?.fixtureTimestampIso) return Timestamp.fromDate(new Date(value.fixtureTimestampIso));
      if (Array.isArray(value)) return value.map(decode);
      if (value != null && typeof value === 'object') return Object.fromEntries(
        Object.entries(value).map(([key, child]) => [key, decode(child)]));
      return value;
    };
    const m = memoryDb(); for (const [key, value] of decode(fixture.documents)) m.store.set(key, value);
    await invoke(m, updateClass(fixture.request, {name: 'Reviewed Furnace'}));
    const before = state(m);
    expect(await invoke(m, fixture.request)).toMatchObject({idempotentReplay: true, version: 1});
    expect(state(m)).toEqual(before);
    const audit = m.store.get(`asset_hierarchy_audits/asset_hierarchy_${fixture.request.requestId}`);
    const changed = {...JSON.parse(audit.afterJson)};
    if (kind === 'name') changed.name = 'Changed historical draft';
    if (kind === 'creator') changed.createdByUid = 'admin-2';
    if (kind === 'creator-name') changed.createdByName = 'Another name';
    audit.afterJson = JSON.stringify(changed);
    await expect(invoke(m, fixture.request)).rejects.toMatchObject({code: 'data-loss'});
  });
});
