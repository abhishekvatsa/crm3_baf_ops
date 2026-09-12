const {executeOriginBoundCallable} = require('../lib/originBoundCallableProtocol');

const names = [
  ['mutateChargeAbnormalityV2', 'request', ['chargeAbnormality.v2', 'qualityMonitoring.v1', 'savedSubmissionReview.v1']],
  ['assignPublishedTemplateVersionV2', 'request', ['publishedTemplateAssignment.v2', 'savedSubmissionReview.v1']],
  ['mutateAssetHierarchyV2', 'request', ['assetHierarchy.v2', 'innerCoverAcceptance.v1',
    'morningReviewExpectedPlantDay.v1', 'morningReviewReceiptLookup.v1', 'savedSubmissionReview.v1']],
  ['executeMaintenanceWorkflowCommandV2', 'command', ['maintenanceWorkflow.v2',
    'inspectionFindingExpectedVersion.v1', 'inspectionCampaignReopen.v1', 'maintenancePlanRevalidation.v1', 'inspectionTargetContextRevalidation.v1', 'savedSubmissionReview.v1']],
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
      capabilityRevision: ({mutateAssetHierarchyV2: 'assetHierarchy.v2.20260913',
        executeMaintenanceWorkflowCommandV2: 'maintenanceWorkflow.v2.20260913',
        mutateChargeAbnormalityV2: 'chargeAbnormality.v2.20260913',
        assignPublishedTemplateVersionV2: 'publishedTemplateAssignment.v2.20260913'})[name],
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
  test('recovery delegates only the exact recovery branch and never business execution', async () => {
    const recovery = {schemaVersion: 1, phase: 'inspect'};
    const execute = jest.fn(); const recoverSubmission = jest.fn(async (value) => value);
    expect(await invoke(name, {protocolVersion: 2, originActorUid: origin, recovery}, {execute, recoverSubmission})).toBe(recovery);
    expect(execute).not.toHaveBeenCalled();
    await expect(invoke(name, {protocolVersion: 2, originActorUid: 'wrong', recovery}, {execute, recoverSubmission}))
      .rejects.toMatchObject({code: 'permission-denied'});
    expect(recoverSubmission).toHaveBeenCalledTimes(1);
    for (const extra of [{probe: 'capabilities'}, {[key]: payload}, {receiptLookup: {}}]) {
      await expect(invoke(name, {protocolVersion: 2, originActorUid: origin, recovery, ...extra}, {execute, recoverSubmission}))
        .rejects.toMatchObject({code: 'invalid-argument'});
    }
    expect(recoverSubmission).toHaveBeenCalledTimes(1);
  });
  test('receipt lookup is distinct, origin-bound, and unavailable without its callback', async () => {
    const receiptLookup = {requestId: 'original-request', operation: 'START_MORNING_REVIEW'};
    const data = {protocolVersion: 2, originActorUid: origin, receiptLookup};
    const execute = jest.fn(); const recoverSubmission = jest.fn(); const readActor = jest.fn();
    const lookupReceipt = jest.fn(async (value) => value);
    await expect(invoke(name, data, {execute, recoverSubmission, readActor})).rejects.toMatchObject({code: 'invalid-argument'});
    expect(await invoke(name, data, {execute, recoverSubmission, readActor, lookupReceipt})).toBe(receiptLookup);
    await expect(invoke(name, {...data, originActorUid: 'other'}, {execute, recoverSubmission, readActor, lookupReceipt}))
      .rejects.toMatchObject({details: {reasonCode: 'origin-bound-actor-mismatch'}});
    await expect(invoke(name, {...data, [key]: payload}, {execute, recoverSubmission, readActor, lookupReceipt}))
      .rejects.toMatchObject({code: 'invalid-argument'});
    expect(lookupReceipt).toHaveBeenCalledTimes(1);
    expect(execute).not.toHaveBeenCalled(); expect(recoverSubmission).not.toHaveBeenCalled(); expect(readActor).not.toHaveBeenCalled();
  });
});
