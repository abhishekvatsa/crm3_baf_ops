const {HttpsError} = require('firebase-functions/v2/https');
const {
  invokeRuntimeJobModulePopulationCallable,
} = require('../lib/runtimeJobModulePopulationCallable');

const timestampFromDate = (date) => date.toISOString();

function noOpDb() {
  return {
    collection() {
      return {doc(id) { return {id, path: `x/${id}`}; }};
    },
    async runTransaction() {
      throw new Error('transaction should not run');
    },
  };
}

describe('runtime module population callable adapter', () => {
  test('maps missing auth to stable unauthenticated HttpsError', async () => {
    const error = await invokeRuntimeJobModulePopulationCallable({
      db: noOpDb(),
      authUid: null,
      data: {},
      timestampFromDate,
    }).catch((value) => value);

    expect(error).toBeInstanceOf(HttpsError);
    expect(error).toMatchObject({code: 'unauthenticated'});
  });

  test('maps validation details without losing reasonCode', async () => {
    const error = await invokeRuntimeJobModulePopulationCallable({
      db: noOpDb(),
      authUid: 'user1',
      data: {operation: 'unsupported', module: {}},
      timestampFromDate,
    }).catch((value) => value);

    expect(error).toBeInstanceOf(HttpsError);
    expect(error).toMatchObject({
      code: 'invalid-argument',
      details: {reasonCode: 'unsupported-operation'},
    });
  });

  test('maps unexpected implementation failures to internal HttpsError', async () => {
    const db = {
      collection() {
        return {doc(id) { return {id, path: `x/${id}`}; }};
      },
      async runTransaction() {
        throw new Error('unexpected');
      },
    };
    const fullModule = {
      firestoreId: 'module1',
      jobExecutionFirestoreId: 'exec1',
      moduleTitle: 'Runtime',
      assetType: 'base',
      assetNumber: 1,
      status: 'notStarted',
      useMode: 'scheduledPM',
      discipline: 'mechanical',
      safetyClass: 'normal',
      isRequired: false,
      requiredForClosure: false,
      addedDuringExecution: true,
      requiresFollowUp: false,
      isDeleted: false,
      displayOrder: 1,
      version: 1,
      moduleSnapshotJson: '{}',
      fieldDefinitionsJson: '[]',
      responsesJson: '[]',
      actionsJson: '[]',
      targetRefs: [],
      procedureRefs: [],
      safetyConfirmations: [],
      tags: [],
      operationalStatePreconditions: [],
      createdByUid: 'user1',
      addedByUid: 'user1',
      updatedByUid: 'user1',
      createdAt: '2026-06-24T00:00:00.000Z',
      addedAt: '2026-06-24T00:00:00.000Z',
      updatedAt: '2026-06-24T00:00:00.000Z',
    };

    const error = await invokeRuntimeJobModulePopulationCallable({
      db,
      authUid: 'user1',
      data: {operation: 'create', module: fullModule},
      timestampFromDate,
    }).catch((value) => value);

    expect(error).toBeInstanceOf(HttpsError);
    expect(error).toMatchObject({code: 'internal'});
  });
});
