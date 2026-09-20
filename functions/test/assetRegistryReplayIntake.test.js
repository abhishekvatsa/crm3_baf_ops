const fs = require('fs');
const path = require('path');
const {createHash} = require('crypto');
const {Timestamp} = require('firebase-admin/firestore');
const {mutateAssetRegistryWithDb, parseAssetRegistryMutationRequest} = require('../lib/assetRegistryMutation');
const {MaintenanceWorkflowCommandService} = require('../lib/maintenanceWorkflow/dispatcher');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');
const replacementDart = require('./fixtures/component_replacement_dart_request.json');
const replacementLegacyDart = require('./fixtures/component_replacement_legacy_dart_request.json');
const legacyReceiptPath = path.join(__dirname, 'fixtures/component_replacement_legacy_receipt.json');

const classId = '11111111-1111-4111-8111-111111111111';
const assetId = '33333333-3333-4333-8333-333333333333';
const requestA = '77777777-7777-4777-8777-777777777777';
const requestB = '88888888-8888-4888-8888-888888888888';

// Mirror Firestore's timestamp boundary. Node's structuredClone runs outside
// Jest's realm and also removes Timestamp methods, so it is not a faithful
// snapshot clone for the server acceptance evidence validated by this suite.
function cloneDocument(value) {
  if (value instanceof Timestamp) return new Timestamp(value.seconds, value.nanoseconds);
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(cloneDocument);
  if (value != null && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, cloneDocument(child)]));
  }
  return value;
}

function memoryDb(classFields = {}) {
  const store = new Map([
    ['users/admin-1', {isApproved: true, roles: ['admin'], name: 'Admin One'}],
    ['users/admin-2', {isApproved: true, roles: ['admin'], name: 'Admin Two'}],
    [`asset_classes/${classId}`, {schemaVersion: 1, assetClassId: classId,
      code: 'FURNACE', legacyAssetTypeKey: 'furnace', name: 'Furnace',
      status: 'active', version: 1, ...classFields}],
  ]);
  const snapshot = (path) => ({exists: store.has(path), data: () => cloneDocument(store.get(path))});
  const ref = (path) => ({path, get: async () => snapshot(path)});
  return {store, writes: [], db: {
    collection: (name) => ({doc: (id) => ref(`${name}/${id}`)}),
    async runTransaction(body) {
      const writes = [];
      const result = await body({
        get: async (target) => snapshot(target.path),
        set: (target, value) => writes.push([target.path, cloneDocument(value)]),
        delete: (target) => writes.push([target.path, undefined]),
      });
      for (const [path, value] of writes) {
        if (value === undefined) store.delete(path); else store.set(path, value);
      }
      return result;
    },
  }};
}
function create() {
  return {requestId: requestA, operation: 'CREATE_ASSET_INSTANCE',
    assetClassId: classId, assetInstanceId: assetId, expectedAssetClassVersion: 1,
    reason: 'Register the physical furnace.',
    assetDraft: {assetNumber: 30, name: 'Furnace 30', plantTag: null, location: 'BAF shop',
      manufacturer: null, model: null, serialNumber: null,
      commissionedOn: '2026-08-01T00:00:00.000Z',
      serviceState: 'inService', ownershipStatus: 'confirmed',
      ownerDiscipline: 'Operations', accountableRoleKeys: ['operations']}};
}
const invoke = (memory, request, actor = 'admin-1') => mutateAssetRegistryWithDb({
  db: memory.db, authUid: actor, data: request, now: () => new Date('2026-09-12T10:00:00.000Z'),
  timestampFromDate: Timestamp.fromDate,
});

async function replacementMemory(request) {
  const memory = memoryDb();
  memory.store.set(`asset_hierarchy_nodes/${request.componentDraft.definitionNodeId}`, {
    assetClassId: request.assetClassId, nodeType: 'component', status: 'active', version: 1,
    name: 'Pressure transmitter', hierarchyPath: ['Pressure transmitter'],
  });
  const asset = create();
  await invoke(memory, {...asset, assetInstanceId: request.assetInstanceId,
    assetDraft: {...asset.assetDraft, assetNumber: 1, name: 'Furnace 1'}});
  await invoke(memory, {requestId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    operation: 'CREATE_COMPONENT_INSTANCE', assetClassId: request.assetClassId,
    assetInstanceId: request.assetInstanceId, componentInstanceId: request.componentInstanceId,
    expectedAssetInstanceVersion: 1, reason: 'Install original transmitter.',
    componentDraft: {...request.componentDraft, serialNumber: 'PT-OLD-001',
      installedOn: '2026-08-01T08:30:00.000Z'}});
  return memory;
}

function replacementUpdate(request) {
  return {requestId: requestB, operation: 'UPDATE_COMPONENT_INSTANCE',
    assetClassId: request.assetClassId, assetInstanceId: request.assetInstanceId,
    componentInstanceId: request.replacementComponentInstanceId, expectedVersion: 1,
    reason: 'Correct the replacement manufacturer record.',
    componentDraft: {...request.componentDraft, manufacturer: 'Reviewed Works',
      installedOn: '2026-09-12T09:00:00.000Z'}};
}

describe('registry intake and immutable replay', () => {
  test.each([
    {legacyAssetTypeKey: 'innerCover', code: 'RENAMED_IC'},
    {legacyAssetTypeKey: null, code: 'INNER_COVER'},
  ])('rejects generic serial Inner Cover creation at the server boundary: %j', async (fields) => {
    const memory = memoryDb(fields);
    const before = cloneDocument([...memory.store]);
    await expect(invoke(memory, create())).rejects.toMatchObject({
      code: 'failed-precondition', details: {reasonCode: 'inner-cover-lifecycle-registration-required'},
    });
    expect([...memory.store]).toEqual(before);
  });

  test('create A, legitimate update B, replay A preserves B and returns original acceptance', async () => {
    const memory = memoryDb(); const a = create();
    const accepted = await invoke(memory, a);
    const b = {...a, requestId: requestB, operation: 'UPDATE_ASSET_INSTANCE',
      expectedVersion: 1, assetDraft: {...a.assetDraft, name: 'Furnace 30 reviewed'},
      reason: 'Reviewed asset description.'};
    await invoke(memory, b);
    const beforeReplay = cloneDocument([...memory.store]);
    expect(await invoke(memory, a)).toEqual({...accepted, idempotentReplay: true});
    expect([...memory.store]).toEqual(beforeReplay);
    expect(memory.store.get(`asset_instances/${assetId}`).version).toBe(2);
  });

  test.each(['actor', 'payload', 'date', 'audit', 'after'])('refuses contradictory or missing immutable evidence: %s', async (kind) => {
    const memory = memoryDb(); const a = create(); await invoke(memory, a);
    let actor = 'admin-1'; let replay = a;
    const path = `asset_hierarchy_audits/asset_registry_${requestA}`;
    if (kind === 'actor') actor = 'admin-2';
    if (kind === 'payload') replay = {...a, reason: 'Different reason.'};
    if (kind === 'date') replay = {...a, assetDraft: {...a.assetDraft, commissionedOn: '2026-08-02T00:00:00.000Z'}};
    if (kind === 'audit') memory.store.delete(path);
    if (kind === 'after') memory.store.get(path).afterJson = JSON.stringify({version: 1});
    const before = cloneDocument([...memory.store]);
    await expect(invoke(memory, replay, actor)).rejects.toMatchObject({
      code: kind === 'audit' ? 'not-found' : 'data-loss',
    });
    expect([...memory.store]).toEqual(before);
  });
});

describe('registry timestamp compatibility from actual Dart requests', () => {
  (process.env.UPDATE_REGISTRY_LEGACY_RECEIPT_FIXTURE === '1' ? test : test.skip)(
    'capture the historical receipt only with the pre-upgrade compiled handler', async () => {
    const memory = await replacementMemory(replacementDart);
    // Preserve the original capture's Date-valued adapter and JSON encoding.
    const accepted = await mutateAssetRegistryWithDb({db: memory.db,
      authUid: 'admin-1', data: replacementDart,
      now: () => new Date('2026-09-12T10:00:00.000Z')});
    const receipt = memory.store.get(`asset_hierarchy_mutation_receipts/${replacementDart.requestId}`);
    expect(receipt.fingerprint).toBe('assetreg2-sha256:a318a0a4096e7bf233eadc1ad1e38698a2528ae2ecaf2769a34c25f87dacdb99');
    expect(receipt.timestampInstants).toBeUndefined();
    fs.writeFileSync(legacyReceiptPath, JSON.stringify({
      provenance: 'Executed pre-timestamp-upgrade compiled registry handler on real Dart three-digit command; not a rewritten modern receipt.',
      compiledHandlerSha256: createHash('sha256').update(fs.readFileSync(require.resolve('../lib/assetRegistryMutation'))).digest('hex'),
      request: replacementDart, accepted, receipt,
      audit: memory.store.get(`asset_hierarchy_audits/${accepted.auditId}`),
      sourceAudit: memory.store.get(`asset_hierarchy_audits/${accepted.auditId}_replacement_source`),
    }, null, 2) + '\n');
  });

  test.each([['new', replacementDart], ['installed', replacementLegacyDart]])(
    '%s Dart replacement A, legitimate edit B, A replay retains exact timestamp without writes', async (_, request) => {
      const memory = await replacementMemory(request);
      const accepted = await invoke(memory, request);
      const receipt = memory.store.get(`asset_hierarchy_mutation_receipts/${request.requestId}`);
      expect(receipt.fingerprint).toMatch(/^assetreg4-sha256:/);
      expect(receipt.timestampInstants).toEqual({installedOn: request.componentDraft.installedOn});
      expect(memory.store.get(`asset_hierarchy_audits/${accepted.auditId}`).timestampInstants).toEqual(receipt.timestampInstants);
      expect(receipt.committedAt).toBeInstanceOf(Timestamp);
      expect(receipt.committedAt.toDate().toISOString()).toBe(accepted.committedAt);
      expect(memory.store.get(`asset_hierarchy_audits/${accepted.auditId}`).performedAt).toBeInstanceOf(Timestamp);
      expect(memory.store.get(`asset_hierarchy_audits/${accepted.auditId}_replacement_source`).performedAt).toBeInstanceOf(Timestamp);
      await invoke(memory, replacementUpdate(request));
      const before = cloneDocument([...memory.store]);
      expect(await invoke(memory, request)).toEqual({...accepted, idempotentReplay: true});
      expect([...memory.store]).toEqual(before);
      expect(memory.store.get(`asset_component_instances/${request.replacementComponentInstanceId}`).version).toBe(2);
      expect(memory.store.get(`asset_component_instances/${request.componentInstanceId}`).status).toBe('retired');
    },
  );

  test.each(['microsecond', 'date', 'receiptDate', 'auditDate', 'sourceAudit', 'downgrade'])(
    'refuses %s drift without writes after a real accepted replacement', async (kind) => {
      const request = replacementLegacyDart;
      const memory = await replacementMemory(request); await invoke(memory, request);
      const receipt = memory.store.get(`asset_hierarchy_mutation_receipts/${request.requestId}`);
      let retry = request;
      if (kind === 'microsecond' || kind === 'date') retry = {...request,
        componentDraft: {...request.componentDraft, installedOn: kind === 'microsecond' ?
          '2026-09-12T08:30:00.123457Z' : '2026-09-13T08:30:00.123456Z'}};
      if (kind === 'receiptDate') receipt.timestampInstants.installedOn = '2026-09-12T08:30:00.123457Z';
      if (kind === 'auditDate') memory.store.get(`asset_hierarchy_audits/${receipt.auditId}`).timestampInstants.installedOn = '2026-09-12T08:30:00.123457Z';
      if (kind === 'sourceAudit') memory.store.delete(`asset_hierarchy_audits/${receipt.auditId}_replacement_source`);
      if (kind === 'downgrade') receipt.fingerprint = 'assetreg2-sha256:a318a0a4096e7bf233eadc1ad1e38698a2528ae2ecaf2769a34c25f87dacdb99';
      const before = cloneDocument([...memory.store]);
      await expect(invoke(memory, retry)).rejects.toMatchObject({code: kind === 'sourceAudit' ? 'not-found' : 'data-loss'});
      expect([...memory.store]).toEqual(before);
    },
  );

  test('actual historical receipt replays after later edit without changing its fingerprint', async () => {
    const legacy = JSON.parse(fs.readFileSync(legacyReceiptPath, 'utf8'));
    const memory = await replacementMemory(legacy.request);
    await invoke(memory, legacy.request);
    memory.store.set(`asset_hierarchy_mutation_receipts/${legacy.request.requestId}`, legacy.receipt);
    memory.store.set(`asset_hierarchy_audits/${legacy.accepted.auditId}`, legacy.audit);
    memory.store.set(`asset_hierarchy_audits/${legacy.accepted.auditId}_replacement_source`, legacy.sourceAudit);
    expect(parseAssetRegistryMutationRequest(legacy.request).legacyFingerprint).toBe(legacy.receipt.fingerprint);
    await invoke(memory, replacementUpdate(legacy.request));
    const before = cloneDocument([...memory.store]);
    expect(await invoke(memory, legacy.request)).toEqual({...legacy.accepted, idempotentReplay: true});
    expect([...memory.store]).toEqual(before);
    const changedDate = {...legacy.request, componentDraft: {...legacy.request.componentDraft,
      installedOn: '2026-09-13T08:30:00.123Z'}};
    expect(parseAssetRegistryMutationRequest(changedDate).legacyFingerprint).toBe(legacy.receipt.fingerprint);
    await expect(invoke(memory, changedDate)).rejects.toMatchObject({code: 'data-loss'});
    expect([...memory.store]).toEqual(before);
  });

  test('three-digit modern evidence cannot be downgraded to an eligible historical hash', async () => {
    const request = replacementDart;
    const memory = await replacementMemory(request);
    await invoke(memory, request);
    const parsed = parseAssetRegistryMutationRequest(request);
    expect(parsed.legacyFingerprint).toMatch(/^assetreg2-sha256:/);
    const receipt = memory.store.get(`asset_hierarchy_mutation_receipts/${request.requestId}`);
    receipt.fingerprint = parsed.legacyFingerprint;
    // Even erasing the receipt markers cannot hide the audit's modern evidence.
    delete receipt.timestampInstants;
    delete receipt.auditEvidenceSha256;
    delete receipt.sourceAuditEvidenceSha256;
    const before = cloneDocument([...memory.store]);
    await expect(invoke(memory, request)).rejects.toMatchObject({
      code: 'data-loss', details: {reasonCode: 'asset-registry-replay-evidence-drift'},
    });
    expect([...memory.store]).toEqual(before);
  });

  test('commissioning accepts installed-client precision and binds sub-millisecond changes', async () => {
    const memory = memoryDb();
    const base = create();
    const request = {...base, assetDraft: {...base.assetDraft,
      commissionedOn: '2026-09-12T08:30:00.123456Z'}};
    const accepted = await invoke(memory, request);
    const receipt = memory.store.get(`asset_hierarchy_mutation_receipts/${request.requestId}`);
    expect(receipt.timestampInstants).toEqual({commissionedOn: request.assetDraft.commissionedOn});
    expect(parseAssetRegistryMutationRequest(request).legacyFingerprint).toBeNull();
    const before = cloneDocument([...memory.store]);
    expect(await invoke(memory, request)).toEqual({...accepted, idempotentReplay: true});
    await expect(invoke(memory, {...request, assetDraft: {...request.assetDraft,
      commissionedOn: '2026-09-12T08:30:00.123457Z'}})).rejects.toMatchObject({code: 'data-loss'});
    expect([...memory.store]).toEqual(before);
  });

  for (const historical of [false, true]) {
    test.each([
      'receiptIsoMalformed', 'receiptIsoNoncanonical', 'receiptIsoShifted',
      'receiptTimeMalformed', 'receiptTimeShifted', 'receiptTimeMicrosecond',
      'auditTimeMalformed', 'auditTimeShifted', 'sourceTimeMalformed', 'sourceTimeShifted',
    ])(`${historical ? 'historical' : 'modern'} acceptance refuses %s without writes`, async (kind) => {
      const request = replacementDart;
      const memory = await replacementMemory(request);
      const accepted = await invoke(memory, request);
      const receiptPath = `asset_hierarchy_mutation_receipts/${request.requestId}`;
      const auditPath = `asset_hierarchy_audits/${accepted.auditId}`;
      const sourcePath = `${auditPath}_replacement_source`;
      if (historical) {
        const legacy = JSON.parse(fs.readFileSync(legacyReceiptPath, 'utf8'));
        memory.store.set(receiptPath, legacy.receipt);
        memory.store.set(auditPath, legacy.audit);
        memory.store.set(sourcePath, legacy.sourceAudit);
      }
      // Each negative starts with a successful replay of this exact evidence.
      expect(await invoke(memory, request)).toEqual({...accepted, idempotentReplay: true});
      const receipt = memory.store.get(receiptPath);
      const shifted = new Date('2026-09-12T10:00:01.000Z');
      if (kind === 'receiptIsoMalformed') receipt.committedAtIso = 'not-a-time';
      if (kind === 'receiptIsoNoncanonical') receipt.committedAtIso = '2026-09-12T10:00:00Z';
      if (kind === 'receiptIsoShifted') receipt.committedAtIso = shifted.toISOString();
      if (kind === 'receiptTimeMalformed') receipt.committedAt = null;
      if (kind === 'receiptTimeShifted') receipt.committedAt = shifted;
      if (kind === 'receiptTimeMicrosecond') receipt.committedAt = '2026-09-12T10:00:00.000001Z';
      if (kind === 'auditTimeMalformed') memory.store.get(auditPath).performedAt = {};
      if (kind === 'auditTimeShifted') memory.store.get(auditPath).performedAt = shifted;
      if (kind === 'sourceTimeMalformed') memory.store.get(sourcePath).performedAt = '2026-02-30T10:00:00.000Z';
      if (kind === 'sourceTimeShifted') memory.store.get(sourcePath).performedAt = shifted;
      const before = cloneDocument([...memory.store]);
      await expect(invoke(memory, request)).rejects.toMatchObject({code: 'data-loss'});
      expect([...memory.store]).toEqual(before);
    });
  }

  test.each(['receipt', 'audit', 'sourceAudit'])(
    'refuses one nanosecond of %s acceptance-time drift after a successful replay', async (kind) => {
      const request = replacementDart;
      const memory = await replacementMemory(request);
      const accepted = await invoke(memory, request);
      expect(await invoke(memory, request)).toEqual({...accepted, idempotentReplay: true});
      const path = kind === 'receipt' ? `asset_hierarchy_mutation_receipts/${request.requestId}` :
        `asset_hierarchy_audits/${accepted.auditId}${kind === 'sourceAudit' ? '_replacement_source' : ''}`;
      const field = kind === 'receipt' ? 'committedAt' : 'performedAt';
      const evidence = memory.store.get(path);
      const exact = evidence[field];
      evidence[field] = new Timestamp(exact.seconds, exact.nanoseconds + 1);
      // The millisecond projection is unchanged; the evidence itself is not.
      expect(evidence[field].toDate().toISOString()).toBe(accepted.committedAt);
      const before = cloneDocument([...memory.store]);
      await expect(invoke(memory, request)).rejects.toMatchObject({code: 'data-loss'});
      expect([...memory.store]).toEqual(before);
      evidence[field] = exact;
      expect(await invoke(memory, request)).toEqual({...accepted, idempotentReplay: true});
    },
  );

  test.each([
    '2026-02-30T08:30:00.123456Z', '2026-09-12T08:30:60.123456Z',
    '2026-09-12T08:30:00.123456+00:00', '2026-09-12T08:30:00.12Z',
    '2026-09-12T08:30:00.1234Z', '2026-09-12T08:30:00.1234567Z',
    '2026-09-12', '2026-09-12T08:30:00Z',
  ])('rejects unsupported timestamp grammar: %s', (installedOn) => {
    expect(() => parseAssetRegistryMutationRequest({...replacementDart,
      componentDraft: {...replacementDart.componentDraft, installedOn}})).toThrow(/UTC ISO timestamp/);
  });
});


describe('installation facts correction without physical reactivation', () => {
  test('unchanged installation time allows a detail correction with undated legacy predecessor', async () => {
    const memory = await replacementMemory(replacementDart);
    await invoke(memory, replacementDart);
    memory.store.get(`asset_component_instances/${replacementDart.componentInstanceId}`).installedOn = null;
    const update = replacementUpdate(replacementDart);
    update.componentDraft.installedOn = replacementDart.componentDraft.installedOn;
    expect((await invoke(memory, update)).version).toBe(2);
    expect(memory.store.get(`asset_component_instances/${replacementDart.replacementComponentInstanceId}`).manufacturer).toBe('Reviewed Works');
  });
  test.each(['remove', 'change'])('cannot %s a linked installation date with unproved legacy chronology', async (kind) => {
    const memory = await replacementMemory(replacementDart);
    await invoke(memory, replacementDart);
    memory.store.get(`asset_component_instances/${replacementDart.componentInstanceId}`).installedOn = null;
    const update = replacementUpdate(replacementDart);
    if (kind === 'remove') update.componentDraft.installedOn = null;
    const before = cloneDocument([...memory.store]);
    await expect(invoke(memory, update)).rejects.toMatchObject({code: 'failed-precondition'});
    expect([...memory.store]).toEqual(before);
  });

  const correction = () => ({requestId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    operation: 'CORRECT_COMPONENT_INSTANCE', assetClassId: replacementDart.assetClassId,
    assetInstanceId: replacementDart.assetInstanceId, componentInstanceId: replacementDart.componentInstanceId,
    expectedVersion: 2, reason: 'Correct the original commissioning record against the signed installation log.',
    componentDraft: {...replacementDart.componentDraft, serialNumber: 'PT-CORRECTED-001', installedOn: '2026-07-31T08:30:00.000Z'}});
  test('corrects retired predecessor with immutable replay while current installation and counts stay intact', async () => {
    const memory = await replacementMemory(replacementDart);
    const replacementReceipt = await invoke(memory, replacementDart);
    const currentPath = `asset_component_instances/${replacementDart.replacementComponentInstanceId}`;
    const assetPath = `asset_instances/${replacementDart.assetInstanceId}`;
    const current = cloneDocument(memory.store.get(currentPath));
    const asset = cloneDocument(memory.store.get(assetPath));
    const accepted = await invoke(memory, correction());
    const previous = memory.store.get(`asset_component_instances/${replacementDart.componentInstanceId}`);
    expect(previous.status).toBe('retired'); expect(previous.serialNumber).toBe('PT-CORRECTED-001');
    expect(previous.replacedByComponentInstanceId).toBe(replacementDart.replacementComponentInstanceId);
    expect(memory.store.get(currentPath)).toEqual(current); expect(memory.store.get(assetPath)).toEqual(asset);
    expect(await invoke(memory, correction())).toEqual({...accepted, idempotentReplay: true});
    expect(await invoke(memory, replacementDart)).toEqual({...replacementReceipt, idempotentReplay: true});
  });
  test.each(['future', 'after-successor', 'identity', 'stale'])('refuses unsafe %s correction without writes', async (kind) => {
    const memory = await replacementMemory(replacementDart); await invoke(memory, replacementDart);
    const input = correction();
    if (kind === 'future') input.componentDraft.installedOn = '2027-01-01T00:00:00.000Z';
    if (kind === 'after-successor') input.componentDraft.installedOn = '2026-09-12T09:30:00.000Z';
    if (kind === 'identity') input.componentDraft.componentTag = 'DIFFERENT-TAG';
    if (kind === 'stale') input.expectedVersion = 1;
    const before = cloneDocument([...memory.store]);
    await expect(invoke(memory, input)).rejects.toBeDefined(); expect([...memory.store]).toEqual(before);
  });

  test('reviewed correction repairs a legacy date-only predecessor while preserving original evidence and replay', async () => {
    const memory = await replacementMemory(replacementDart);
    const replacementReceipt = await invoke(memory, replacementDart);
    const previousPath = `asset_component_instances/${replacementDart.componentInstanceId}`;
    memory.store.get(previousPath).installedOn = '2026-08-01';
    const input = correction();
    const accepted = await invoke(memory, input);
    const audit = memory.store.get(`asset_hierarchy_audits/${accepted.auditId}`);
    expect(JSON.parse(audit.beforeJson).installedOn).toBe('2026-08-01');
    expect(memory.store.get(previousPath).installedOn.toDate().toISOString()).toBe(input.componentDraft.installedOn);
    expect(memory.store.get(previousPath).status).toBe('retired');
    expect(await invoke(memory, input)).toEqual({...accepted, idempotentReplay: true});
    expect(await invoke(memory, replacementDart)).toEqual({...replacementReceipt, idempotentReplay: true});
  });

  test.each(['2026-09-12T10:00:01.000Z', '2026-07-31T23:59:59.000Z'])('rejects replacement installation outside proved physical chronology: %s', async (installedOn) => {
    const memory = await replacementMemory(replacementDart);
    const before = cloneDocument([...memory.store]);
    await expect(invoke(memory, {...replacementDart,
      componentDraft: {...replacementDart.componentDraft, installedOn}})).rejects.toMatchObject({code: 'failed-precondition'});
    expect([...memory.store]).toEqual(before);
  });

  test('date-only predecessor cannot silently become precise replacement chronology', async () => {
    const memory = await replacementMemory(replacementDart);
    memory.store.get(`asset_component_instances/${replacementDart.componentInstanceId}`).installedOn = '2026-08-01';
    const before = cloneDocument([...memory.store]);
    await expect(invoke(memory, replacementDart)).rejects.toMatchObject({code: 'failed-precondition'});
    expect([...memory.store]).toEqual(before);
  });
});

describe('replacement work applicability', () => {
  function hierarchy(scope = 'definition', overrides = {}) {
    return {schemaVersion: scope === 'componentDefinitionOnAsset' ? 4 : 2, scope,
      assetClassId: replacementDart.assetClassId, assetClassCode: 'FURNACE', assetClassName: 'Furnace',
      nodeId: replacementDart.componentDraft.definitionNodeId, nodeVersion: 1, nodeName: 'Pressure transmitter',
      assetInstanceId: scope === 'definition' ? null : replacementDart.assetInstanceId,
      assetInstanceVersion: scope === 'definition' ? null : 2,
      assetNumber: scope === 'definition' ? null : 1,
      assetInstanceName: scope === 'definition' ? null : 'Furnace 1',
      componentInstanceId: scope === 'installedComponent' ? replacementDart.componentInstanceId : null,
      componentInstanceVersion: scope === 'installedComponent' ? 1 : null, componentTag: null,
      hierarchyPath: ['Pressure transmitter'], ownershipStatus: 'confirmed',
      ownerDiscipline: 'Instrumentation', accountableRoleKeys: ['seniorInstrumentation'], ...overrides};
  }

  async function completedPlannedWork(memory, target) {
    const workflow = new MemoryWorkflowStore();
    for (const [path, data] of memory.store) workflow.seed(path, data);
    workflow.seed(`asset_hierarchy_nodes/${target.nodeId}`, {
      schemaVersion: 1, nodeId: target.nodeId, assetClassId: target.assetClassId,
      status: 'active', version: 1, nodeType: 'component', name: target.nodeName,
      hierarchyPath: target.hierarchyPath, ownershipStatus: 'confirmed',
      ownerDiscipline: 'Instrumentation', accountableRoleKeys: ['seniorInstrumentation'],
    });
    workflow.seed('job_templates/replacement-template', {
      firestoreId: 'replacement-template', version: 1, jobName: 'Reviewed planned work',
      applicableAssetType: 'furnace', assignedAgencies: ['instrumentation'],
      assetHierarchyRefJson: JSON.stringify(target), isActive: true, isDeprecated: false, isDeleted: false,
    });
    const service = new MaintenanceWorkflowCommandService(workflow);
    const actor = {uid: 'admin-1', name: 'Admin One', roles: new Set(['admin'])};
    const executionId = 'component-work';
    async function execute(commandType, expectedVersion, payload, minute) {
      return service.execute({commandId: `component-work-${commandType}`, commandType,
        aggregateId: executionId, expectedVersion, payload},
      {actor, serverNow: new Date(`2026-09-12T08:${minute}:00.000Z`)});
    }
    await execute('createLegacyWorkflowJob', 0, {assignmentSchemaVersion: 2, executionId,
      templateFirestoreId: 'replacement-template', expectedTemplateVersion: 1,
      assetClassId: replacementDart.assetClassId, assetInstanceId: replacementDart.assetInstanceId}, '00');
    await execute('finalizeLaneSet', 1, {laneKeys: ['inst']}, '05');
    await execute('acknowledgeLane', 2, {laneKey: 'inst'}, '10');
    await execute('closeLane', 3, {laneKey: 'inst'}, '15');
    await execute('finalizeJob', 4, {redRequired: false, actionTargetContractVersion: 1,
      actionsJson: JSON.stringify([{
        asset: 'Furnace 1', component: target.nodeName, actionType: 'replacement',
        isAutoResolved: false, createdAt: '2026-09-12T08:18:00.000Z',
        severity: 'medium', version: 1, tag: null,
        assetHierarchyRef: {schemaVersion: 4, scope: 'componentDefinitionOnAsset',
          assetClassId: target.assetClassId, assetInstanceId: replacementDart.assetInstanceId,
          assetInstanceVersion: 2, nodeId: target.nodeId, nodeVersion: 1},
      }])}, '20');
    const execution = workflow.read(`job_executions/${executionId}`);
    expect(execution.isCompleted).toBe(true);
    expect(JSON.parse(execution.actionsJson)[0]).toMatchObject({actionType: 'replacement',
      performedBy: 'Admin One', assetHierarchyRef: {schemaVersion: 4, nodeId: target.nodeId}});
    expect(JSON.parse(execution.metadataJson).jobTemplateSnapshot.assetHierarchyRefJson).toBe(JSON.stringify(target));
    memory.store.set(`job_executions/${executionId}`, execution);
    return {...replacementDart, evidenceReference: {
      sourceType: 'plannedJob', sourceId: executionId, expectedVersion: execution.version,
    }};
  }

  test('actual assignment and closure for a different definition cannot justify replacement on the same asset', async () => {
    const memory = await replacementMemory(replacementDart);
    const request = await completedPlannedWork(memory, hierarchy('definition', {nodeId: 'furnace-shell'}));
    const before = cloneDocument([...memory.store]);
    await expect(invoke(memory, request)).rejects.toMatchObject({code: 'failed-precondition',
      details: {reasonCode: 'asset-component-replacement-evidence-definition-mismatch'}});
    expect([...memory.store]).toEqual(before);
  });

  test.each([1, 2, 3])('actual definition-schema-%s assignment and closure link their component and replay after a later replacement', async (schemaVersion) => {
    const memory = await replacementMemory(replacementDart);
    const request = await completedPlannedWork(memory, hierarchy('definition', {schemaVersion}));
    const accepted = await invoke(memory, request);
    const audit = memory.store.get(`asset_hierarchy_audits/${accepted.auditId}`);
    expect(JSON.parse(audit.acceptedEvidenceSnapshotJson)).toMatchObject({
      applicabilitySchemaVersion: 1, applicabilityScope: 'componentDefinitionOnAsset',
      definitionNodeId: replacementDart.componentDraft.definitionNodeId, componentInstanceId: null,
    });
    const later = {...replacementDart, requestId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      componentInstanceId: replacementDart.replacementComponentInstanceId,
      replacementComponentInstanceId: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
      expectedAssetInstanceVersion: 3,
      componentDraft: {...replacementDart.componentDraft, serialNumber: 'PT-NEWER-003',
        installedOn: '2026-09-12T09:30:00.000Z'}};
    await invoke(memory, later);
    memory.store.delete(`job_executions/${request.evidenceReference.sourceId}`);
    const beforeReplay = cloneDocument([...memory.store]);
    expect(await invoke(memory, request)).toEqual({...accepted, idempotentReplay: true});
    expect([...memory.store]).toEqual(beforeReplay);
  });

  test.each(['unknown-scope', 'wrong-definition', 'contradictory-serial', 'contradictory-physical-node', 'malformed-snapshot'])('rejects %s instead of silently falling back to asset-only identity', async (kind) => {
    const memory = await replacementMemory(replacementDart);
    const request = await completedPlannedWork(memory, hierarchy());
    const work = memory.store.get(`job_executions/${request.evidenceReference.sourceId}`);
    const metadata = JSON.parse(work.metadataJson);
    let reference = hierarchy('componentDefinitionOnAsset');
    if (kind === 'unknown-scope') reference.scope = 'unrecognizedScope';
    if (kind === 'wrong-definition') reference.nodeId = 'furnace-shell';
    if (kind === 'contradictory-serial') reference.componentInstanceVersion = 2;
    if (kind === 'contradictory-physical-node') reference = hierarchy('physicalAsset', {schemaVersion: 3, nodeId: 'furnace-shell'});
    metadata.jobTemplateSnapshot = kind === 'malformed-snapshot' ? [] :
      {...metadata.jobTemplateSnapshot, assetHierarchyRefJson: JSON.stringify(reference)};
    work.metadataJson = JSON.stringify(metadata);
    const before = cloneDocument([...memory.store]);
    await expect(invoke(memory, request)).rejects.toMatchObject({code: 'failed-precondition'});
    expect([...memory.store]).toEqual(before);
  });

  test.each(['componentDefinitionOnAsset', 'installedComponent'])('accepts relevant %s issue context with exact scope retained', async (scope) => {
    const memory = await replacementMemory(replacementDart);
    memory.store.set('maintenance_records/resolved-component-work', {
      version: 4, isDeleted: false, isResolved: true, status: 'resolved',
      description: 'Calibration issue resolved', endDate: '2026-09-12T08:20:00.000Z',
      closedByUid: 'admin-1', closedByName: 'Admin One',
      assetHierarchyRefJson: JSON.stringify(hierarchy(scope)),
    });
    const accepted = await invoke(memory, {...replacementDart, evidenceReference: {
      sourceType: 'maintenanceIssue', sourceId: 'resolved-component-work', expectedVersion: 4,
    }});
    const snapshot = JSON.parse(memory.store.get(`asset_hierarchy_audits/${accepted.auditId}`).acceptedEvidenceSnapshotJson);
    expect(snapshot.applicabilityScope).toBe(scope);
    expect(snapshot.componentInstanceId).toBe(scope === 'installedComponent' ? replacementDart.componentInstanceId : null);
  });

  test('unscoped legacy planned work remains asset context without claiming serial or definition evidence', async () => {
    const memory = await replacementMemory(replacementDart);
    const request = await completedPlannedWork(memory, hierarchy());
    const work = memory.store.get(`job_executions/${request.evidenceReference.sourceId}`);
    const metadata = JSON.parse(work.metadataJson);
    delete metadata.jobTemplateSnapshot;
    work.metadataJson = JSON.stringify(metadata);
    const accepted = await invoke(memory, request);
    expect(JSON.parse(memory.store.get(`asset_hierarchy_audits/${accepted.auditId}`).acceptedEvidenceSnapshotJson)).toMatchObject({
      applicabilitySchemaVersion: 1, applicabilityScope: 'assetContext',
      definitionNodeId: null, componentInstanceId: null,
    });
  });
});
