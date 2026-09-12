const {executeOriginBoundCallable} = require('../lib/originBoundCallableProtocol');

const names = [
  ['mutateChargeAbnormalityV2', 'request', ['chargeAbnormality.v2', 'qualityMonitoring.v1']],
  ['assignPublishedTemplateVersionV2', 'request', ['publishedTemplateAssignment.v2']],
  ['mutateAssetHierarchyV2', 'request', ['assetHierarchy.v2', 'innerCoverAcceptance.v1']],
  ['executeMaintenanceWorkflowCommandV2', 'command', ['maintenanceWorkflow.v2',
    'inspectionFindingExpectedVersion.v1', 'inspectionCampaignReopen.v1', 'maintenancePlanRevalidation.v1']],
];
const origin = 'actor-a';
const payload = {requestId: 'saved-original', commandId: 'saved-command', nested: {observedAt: '2026-09-12T00:00:00.123456Z'}};
const invoke = (callableName, data, extra = {}) => executeOriginBoundCallable({callableName, data,
  authUid: origin, readActor: async () => ({isApproved: true, roles: ['admin']}),
  execute: async (received) => received, ...extra});

describe.each(names)('%s origin-bound callable protocol', (name, key, capabilities) => {
  test('same-origin business payload is delegated unchanged without parsing a second fingerprint', async () => {
    const received = await invoke(name, {protocolVersion: 2, originActorUid: origin, [key]: payload});
    expect(received).toBe(payload);
    expect(received.nested.observedAt).toBe('2026-09-12T00:00:00.123456Z');
  });
  test.each(['business', 'probe'])('wrong-origin %s reaches no account reads, quota admission or business execution', async (kind) => {
    const readActor = jest.fn(); const execute = jest.fn();
    const data = {protocolVersion: 2, originActorUid: 'actor-b',
      ...(kind === 'probe' ? {probe: 'capabilities'} : {[key]: payload})};
    await expect(invoke(name, data, {readActor, execute})).rejects.toMatchObject({
      code: 'permission-denied', details: {reasonCode: 'origin-bound-actor-mismatch'},
    });
    expect(readActor).not.toHaveBeenCalled(); expect(execute).not.toHaveBeenCalled();
  });
  test('probe returns executable capabilities without calling the business delegate', async () => {
    const execute = jest.fn(); const readActor = jest.fn(async () => ({isApproved: true, roles: ['operations']}));
    const response = await invoke(name, {protocolVersion: 2, originActorUid: origin, probe: 'capabilities'}, {execute, readActor});
    expect(response).toEqual({schemaVersion: 1, callableName: name, protocolVersion: 2,
      capabilityRevision: ({mutateAssetHierarchyV2: 'assetHierarchy.v2.20260912',
        executeMaintenanceWorkflowCommandV2: 'maintenanceWorkflow.v2.20260912',
        mutateChargeAbnormalityV2: 'chargeAbnormality.v2.20260912',
        assignPublishedTemplateVersionV2: 'publishedTemplateAssignment.v2.20260912'})[name],
      capabilities});
    expect(readActor).toHaveBeenCalledWith(origin); expect(execute).not.toHaveBeenCalled();
  });
  test.each([null, {isApproved: false, roles: ['admin']}, {approved: true, role: 'admin'}])(
    'unapproved/alias-only probe account cannot claim executable capability: %j', async (actor) => {
      const execute = jest.fn();
      await expect(invoke(name, {protocolVersion: 2, originActorUid: origin, probe: 'capabilities'},
        {readActor: async () => actor, execute})).rejects.toMatchObject({code: 'permission-denied'});
      expect(execute).not.toHaveBeenCalled();
    });
  test.each([
    {}, {protocolVersion: 1, originActorUid: origin},
    {protocolVersion: 2, originActorUid: origin, probe: 'capabilities', request: {}},
    {protocolVersion: 2, originActorUid: origin, probe: 'somethingElse'},
    {protocolVersion: 2, originActorUid: origin, request: null, command: null},
  ])('malformed or mixed probe/business shape cannot become an empty business command: %j', async (data) => {
    const execute = jest.fn();
    await expect(invoke(name, data, {execute})).rejects.toMatchObject({code: 'invalid-argument'});
    expect(execute).not.toHaveBeenCalled();
  });
  test('missing authentication cannot acquire an origin from the payload', async () => {
    await expect(invoke(name, {protocolVersion: 2, originActorUid: origin, [key]: payload}, {authUid: null}))
      .rejects.toMatchObject({code: 'unauthenticated'});
  });
});
