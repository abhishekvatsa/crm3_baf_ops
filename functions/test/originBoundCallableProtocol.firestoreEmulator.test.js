const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId = process.env.GCLOUD_PROJECT || 'demo-crm3-system-assessment';
jest.setTimeout(30000);
const revisions = {mutateAssetHierarchyV2: 'assetHierarchy.v2.20260913',
  executeMaintenanceWorkflowCommandV2: 'maintenanceWorkflow.v2.20260913',
  mutateChargeAbnormalityV2: 'chargeAbnormality.v2.20260913',
  assignPublishedTemplateVersionV2: 'publishedTemplateAssignment.v2.20260913'};

describeWithEmulator('actual V2 callable handler boundary', () => {
  let db; let endpoints;
  const request = (data, uid = 'admin-1') => ({data, auth: {uid, token: {name: uid}}});
  const probe = (uid = 'admin-1') => ({protocolVersion: 2, originActorUid: uid, probe: 'capabilities'});
  const classRequest = () => ({requestId: '00000010-1111-4111-8111-111111111111', operation: 'CREATE_CLASS',
    assetClassId: '00000001-1111-4111-8111-111111111111', reason: 'Create reviewed class.',
    classDraft: {code: 'FURNACE', name: 'Furnace', majorArea: 'BAF',
      shortDescription: null, longDescription: null, legacyAssetTypeKey: 'furnace'}});
  const evidence = async (includeQuota = true) => {
    const data = [];
    for (const collection of await db.listCollections()) {
      if (!includeQuota && collection.id === 'callable_abuse_controls') continue;
      for (const document of (await collection.get()).docs) {
        data.push([document.ref.path, document.data(), document.updateTime]);
      }
    }
    return data.sort(([a], [b]) => a.localeCompare(b));
  };
  beforeAll(() => {
    if (!projectId.startsWith('demo-')) throw new Error('This suite requires an isolated demo project.');
    endpoints = require('../lib/index');
    db = admin.firestore();
  });
  beforeEach(async () => {
    const response = await fetch(`http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
    if (!response.ok) throw new Error('Local emulator reset failed.');
    await db.doc('users/admin-1').set({name: 'Admin One', isApproved: true, roles: ['admin']});
  });
  afterAll(async () => { await admin.app().delete(); });

  test.each(Object.keys(revisions))(
    '%s capability probe verifies actual approved identity with zero quota/business writes', async (name) => {
      expect(typeof endpoints[name].run).toBe('function');
      const before = await evidence();
      expect(await endpoints[name].run(request(probe()))).toMatchObject({schemaVersion: 1,
        callableName: name, protocolVersion: 2,
        capabilityRevision: revisions[name]});
      expect(await evidence()).toEqual(before);
      await db.doc('users/admin-1').update({isApproved: false});
      const revoked = await evidence();
      await expect(endpoints[name].run(request(probe()))).rejects.toMatchObject({code: 'permission-denied'});
      expect(await evidence()).toEqual(revoked);
    });

  test.each([
    ['mutateAssetHierarchyV2', 'request'], ['executeMaintenanceWorkflowCommandV2', 'command'],
    ['mutateChargeAbnormalityV2', 'request'], ['assignPublishedTemplateVersionV2', 'request'],
  ])('%s rejects origin mismatch before any real quota or business write', async (name, key) => {
    const before = await evidence();
    await expect(endpoints[name].run(request({protocolVersion: 2, originActorUid: 'another-admin', [key]: classRequest()})))
      .rejects.toMatchObject({code: 'permission-denied', details: {reasonCode: 'origin-bound-actor-mismatch'}});
    expect(await evidence()).toEqual(before);
  });

  test('V2 .run executes the actual V1 mutation and both routes share the existing quota record', async () => {
    const command = classRequest();
    const accepted = await endpoints.mutateAssetHierarchyV2.run(request({protocolVersion: 2, originActorUid: 'admin-1', request: command}));
    expect(accepted).toMatchObject({ok: true, requestId: command.requestId, idempotentReplay: false});
    const beforeReplay = await evidence(false);
    expect(await endpoints.mutateAssetHierarchy.run(request(command))).toEqual({...accepted, idempotentReplay: true});
    expect(await endpoints.mutateAssetHierarchyV2.run(request({protocolVersion: 2, originActorUid: 'admin-1', request: command})))
      .toEqual({...accepted, idempotentReplay: true});
    expect(await evidence(false)).toEqual(beforeReplay);
    const quota = await db.collection('callable_abuse_controls').get();
    expect(quota.size).toBe(1);
    expect(quota.docs[0].data()).toMatchObject({callableName: 'mutateAssetHierarchy', burstRequestCount: 3});
  });

  test('V2 hierarchy route replays captured actual assetreq1 acceptance without rewriting its receipt', async () => {
    const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/hierarchy_legacy_acceptance.json'), 'utf8'));
    const decode = (value) => {
      if (value?.fixtureTimestampIso) return admin.firestore.Timestamp.fromDate(new Date(value.fixtureTimestampIso));
      if (Array.isArray(value)) return value.map(decode);
      if (value != null && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, decode(child)]));
      return value;
    };
    for (const [key, value] of fixture.documents) await db.doc(key).set(decode(value));
    const before = await evidence(false);
    expect(await endpoints.mutateAssetHierarchyV2.run(request({protocolVersion: 2, originActorUid: 'admin-1', request: fixture.request})))
      .toMatchObject({idempotentReplay: true, version: 1});
    expect(await evidence(false)).toEqual(before);
  });

  test('V2 workflow route preserves old accepted adjudication and refuses never-accepted missing revision', async () => {
    const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/finding_adjudication_legacy_receipt.json'), 'utf8'));
    for (const [key, value] of fixture.documents) await db.doc(key).set(value);
    const before = await evidence(false);
    const raw = {protocolVersion: 2, originActorUid: fixture.actor.uid, command: fixture.command};
    expect(await endpoints.executeMaintenanceWorkflowCommandV2.run(request(raw, fixture.actor.uid))).toEqual(fixture.accepted);
    expect(await evidence(false)).toEqual(before);
    const fresh = {...raw, command: {...fixture.command, commandId: 'unaccepted-old-client-shape'}};
    await expect(endpoints.executeMaintenanceWorkflowCommandV2.run(request(fresh, fixture.actor.uid)))
      .rejects.toMatchObject({code: 'failed-precondition', details: {reasonCode: 'inspection-finding-client-update-required'}});
    expect(await evidence(false)).toEqual(before);
  });

  test('quality monitoring V1 acceptance replays through V2 with original request, receipt and shared quota', async () => {
    await db.doc('asset_classes/base-class').set({schemaVersion: 1, assetClassId: 'base-class',
      code: 'BASE', name: 'Base', legacyAssetTypeKey: 'base', status: 'active'});
    await db.doc('asset_instances/base-12').set({schemaVersion: 1, assetInstanceId: 'base-12',
      assetClassId: 'base-class', assetClassCode: 'BASE', assetClassName: 'Base', assetNumber: 12,
      name: 'Base 12', status: 'active', version: 4});
    const command = {requestId: '11111111-1111-4111-8111-111111111111',
      operation: 'CREATE_QUALITY_MONITORING_REQUEST', monitoringRequestId: '44444444-4444-4444-8444-444444444444',
      expectedVersion: 0, reason: 'Monitor atmosphere for reviewed product campaign.', baseNumber: 12,
      baseAssetClassId: 'base-class', baseAssetInstanceId: 'base-12', baseAssetInstanceVersion: 4,
      grade: 'CRGO M4', cycleReference: 'Cycle family 7A', chargeNumbers: [12011, 12012]};
    const accepted = await endpoints.mutateChargeAbnormality.run(request(command));
    await endpoints.mutateChargeAbnormality.run(request({
      requestId: '22222222-2222-4222-8222-222222222222', operation: 'CLOSE_QUALITY_MONITORING_REQUEST',
      monitoringRequestId: command.monitoringRequestId, expectedVersion: 1, reason: 'Later monitoring completed.',
    }));
    const before = await evidence(false);
    expect(await endpoints.mutateChargeAbnormalityV2.run(request({protocolVersion: 2,
      originActorUid: 'admin-1', request: command}))).toEqual({...accepted, idempotentReplay: true});
    expect(await evidence(false)).toEqual(before);
    const quotas = await db.collection('callable_abuse_controls').get();
    expect(quotas.size).toBe(1);
    expect(quotas.docs[0].data()).toMatchObject({callableName: 'mutateChargeAbnormality', burstRequestCount: 3});
  });

  test('actual historical c00 monitoring creation replays after a later closure through V2', async () => {
    const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/quality_monitoring_legacy_creation.json'), 'utf8'));
    const decode = (value) => {
      if (value && typeof value === 'object' && Object.keys(value).length === 2 &&
          Number.isInteger(value._seconds) && Number.isInteger(value._nanoseconds)) {
        return new admin.firestore.Timestamp(value._seconds, value._nanoseconds);
      }
      if (Array.isArray(value)) return value.map(decode);
      if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, decode(v)]));
      return value;
    };
    for (const [key, value] of fixture.documents) await db.doc(key).set(decode(value));
    await endpoints.mutateChargeAbnormality.run(request({requestId: '22222222-2222-4222-8222-222222222222',
      operation: 'CLOSE_QUALITY_MONITORING_REQUEST', monitoringRequestId: fixture.request.monitoringRequestId,
      expectedVersion: 1, reason: 'Later monitoring completed.'}));
    const before = await evidence(false);
    expect(await endpoints.mutateChargeAbnormalityV2.run(request({protocolVersion: 2,
      originActorUid: fixture.actorUid, request: fixture.request})))
      .toEqual({...fixture.accepted, idempotentReplay: true});
    expect(await evidence(false)).toEqual(before);
    const auditRef = db.doc(`audit_logs/server_quality_${fixture.request.requestId}`);
    const originalTime = (await auditRef.get()).data().timestamp;
    const drift = new admin.firestore.Timestamp(originalTime.seconds, originalTime.nanoseconds + 1000);
    await auditRef.update({timestamp: drift});
    expect((await auditRef.get()).data().timestamp.isEqual(drift)).toBe(true);
    await expect(endpoints.mutateChargeAbnormalityV2.run(request({protocolVersion: 2,
      originActorUid: fixture.actorUid, request: fixture.request})))
      .rejects.toMatchObject({code: 'data-loss'});
  });

  test('published assignment V2 acceptance replays through V1 with original request, receipt and shared quota', async () => {
    const fixtures = require('./helpers/publishedTemplateV2Fixtures.cjs');
    await db.doc('template_packages/pkg1').set(fixtures.packageFixture());
    await db.doc('template_versions/ver1').set(fixtures.versionFixture());
    await db.doc('template_publish_audits/audit1').set(fixtures.auditFixture());
    const command = fixtures.requestFixture();
    const accepted = await endpoints.assignPublishedTemplateVersionV2.run(request({protocolVersion: 2,
      originActorUid: 'admin-1', request: command}));
    const before = await evidence(false);
    const replay = await endpoints.assignPublishedTemplateVersion.run(request(command));
    expect(replay).toEqual({...accepted, idempotentReplay: true});
    expect(await evidence(false)).toEqual(before);
    const quotas = await db.collection('callable_abuse_controls').get();
    expect(quotas.size).toBe(1);
    expect(quotas.docs[0].data()).toMatchObject({callableName: 'assignPublishedTemplateVersion', burstRequestCount: 2});
  });
});
