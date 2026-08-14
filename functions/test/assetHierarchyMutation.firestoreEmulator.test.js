const admin = require('firebase-admin');

const {
  mutateAssetHierarchyWithDb,
} = require('../lib/assetHierarchyMutation');
const {
  mutateAssetRegistryWithDb,
} = require('../lib/assetRegistryMutation');
const {
  mutateAssetOperationalConditionWithDb,
} = require('../lib/assetOperationalConditionMutation');

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';
const appName = `asset-hierarchy-emulator-${process.pid}-${Date.now()}`;

const IDS = {
  classId: '11111111-1111-4111-8111-111111111111',
  classRequest: '22222222-2222-4222-8222-222222222222',
  firstNode: '33333333-3333-4333-8333-333333333333',
  firstNodeRequest: '44444444-4444-4444-8444-444444444444',
  secondNode: '55555555-5555-4555-8555-555555555555',
  secondNodeRequest: '66666666-6666-4666-8666-666666666666',
  firstAsset: '77777777-7777-4777-8777-777777777777',
  firstAssetRequest: '88888888-8888-4888-8888-888888888888',
  secondAsset: '99999999-9999-4999-8999-999999999999',
  secondAssetRequest: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  firstComponent: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  firstComponentRequest: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  secondComponent: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  secondComponentRequest: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  assetStatusRequest: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
  componentUpdateRequest: '12121212-1212-4121-8121-121212121212',
  conditionRequest: '13131313-1313-4131-8131-131313131313',
  restorationRequest: '14141414-1414-4141-8141-141414141414',
};

function classRequest() {
  return {
    requestId: IDS.classRequest,
    operation: 'CREATE_CLASS',
    assetClassId: IDS.classId,
    reason: 'Create governed furnace hierarchy for emulator verification.',
    classDraft: {
      code: 'FURNACE',
      name: 'Furnace',
      majorArea: 'BAF Shop Equipment',
      shortDescription: 'Movable direct-fired heating package.',
      longDescription: null,
      legacyAssetTypeKey: 'furnace',
    },
  };
}

function nodeDraft(name, tag) {
  return {
    parentNodeId: null,
    nodeType: 'component',
    name,
    componentTag: tag,
    shortDescription: 'Pressure measurement component.',
    longDescription: 'Measures furnace pressure for operation and protection.',
    discipline: 'Instrumentation',
    operatingType: 'Electrical sensing',
    normalState: null,
    failState: null,
    contactArrangement: 'notApplicable',
    manufacturer: null,
    model: null,
    applicability: 'All furnaces',
    sourceReference: 'Maintenance Manual',
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'Instrumentation',
    accountableRoleKeys: ['seniorInstrumentation'],
    sortOrder: 10,
  };
}

function createNodeRequest({requestId, nodeId, name, tag, allowTagTransfer}) {
  return {
    requestId,
    operation: 'CREATE_NODE',
    assetClassId: IDS.classId,
    expectedAssetClassVersion: 1,
    nodeId,
    reason: 'Create governed component with reviewed ownership and tag.',
    allowTagTransfer,
    nodeDraft: nodeDraft(name, tag),
  };
}

describeWithEmulator('governed asset-hierarchy mutation', () => {
  let app;
  let db;

  async function clearFirestore() {
    const response = await fetch(
      `http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
      {method: 'DELETE'},
    );
    if (!response.ok) throw new Error(`${response.status} ${await response.text()}`);
  }

  async function invoke(data, authUid = 'admin-1') {
    return mutateAssetHierarchyWithDb({
      db,
      authUid,
      data,
      now: () => new Date('2026-08-13T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
  }

  async function invokeRegistry(data, authUid = 'admin-1') {
    return mutateAssetRegistryWithDb({
      db,
      authUid,
      data,
      now: () => new Date('2026-08-13T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
  }

  async function invokeCondition(data, authUid) {
    return mutateAssetOperationalConditionWithDb({
      db,
      authUid,
      data,
      now: () => new Date('2026-08-13T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
  }

  function assetRequest({requestId, assetInstanceId, assetNumber, name}) {
    return {
      requestId,
      operation: 'CREATE_ASSET_INSTANCE',
      assetClassId: IDS.classId,
      assetInstanceId,
      expectedAssetClassVersion: 1,
      reason: 'Register a physical furnace for governed maintenance work.',
      assetDraft: {
        assetNumber,
        name,
        plantTag: null,
        location: 'BAF shop',
        manufacturer: null,
        model: null,
        serialNumber: null,
        commissionedOn: null,
        serviceState: 'inService',
        ownershipStatus: 'confirmed',
        ownerDiscipline: 'Operations',
        accountableRoleKeys: ['operations'],
      },
    };
  }

  function componentRequest({
    requestId,
    assetInstanceId,
    componentInstanceId,
    tag,
    allowTagTransfer,
    expectedTagOwnerComponentId = null,
  }) {
    return {
      requestId,
      operation: 'CREATE_COMPONENT_INSTANCE',
      assetClassId: IDS.classId,
      assetInstanceId,
      componentInstanceId,
      expectedAssetInstanceVersion: 1,
      reason: 'Install the governed furnace pressure transmitter.',
      allowTagTransfer,
      expectedTagOwnerComponentId,
      componentDraft: {
        definitionNodeId: IDS.firstNode,
        componentTag: tag,
        manufacturer: 'Example Instruments',
        model: 'PX-1',
        serialNumber: null,
        installedOn: null,
        serviceState: 'inService',
        ownershipStatus: 'confirmed',
        ownerDiscipline: 'Instrumentation',
        accountableRoleKeys: ['seniorInstrumentation'],
      },
    };
  }

  beforeAll(async () => {
    app = admin.initializeApp({projectId}, appName);
    db = admin.firestore(app);
  });

  beforeEach(async () => {
    await clearFirestore();
    await db.collection('users').doc('admin-1').set({
      name: 'Admin One',
      email: 'admin-1@test.local',
      isApproved: true,
      roles: ['admin'],
      createdAt: new Date('2026-08-13T00:00:00.000Z'),
    });
    await db.collection('users').doc('ops-1').set({
      name: 'Operations One',
      email: 'ops-1@test.local',
      isApproved: true,
      roles: ['operations'],
      createdAt: new Date('2026-08-13T00:00:00.000Z'),
    });
    await db.collection('users').doc('shift-1').set({
      name: 'Shift Supervisor',
      email: 'shift-1@test.local',
      isApproved: true,
      roles: ['shiftSupervisor'],
      createdAt: new Date('2026-08-13T00:00:00.000Z'),
    });
  });

  afterAll(async () => {
    if (app) await app.delete();
  });

  test('creates a reusable definition and exact replay returns the same evidence', async () => {
    const first = await invoke(classRequest());
    const replay = await invoke(classRequest());

    expect(first).toMatchObject({
      idempotentReplay: false,
      assetClassId: IDS.classId,
      version: 1,
    });
    expect(replay).toEqual({...first, idempotentReplay: true});

    const nodeResult = await invoke(createNodeRequest({
      requestId: IDS.firstNodeRequest,
      nodeId: IDS.firstNode,
      name: 'Furnace pressure transmitter',
      tag: 'Typical PT reference',
      allowTagTransfer: false,
    }));
    expect(nodeResult.version).toBe(1);
    const node = (
      await db.collection('asset_hierarchy_nodes').doc(IDS.firstNode).get()
    ).data();
    expect(node).toMatchObject({
      normalizedComponentTag: 'TYPICALPTREFERENCE',
      ownershipStatus: 'confirmed',
      ownerDiscipline: 'Instrumentation',
      accountableRoleKeys: ['seniorInstrumentation'],
      hierarchyPath: ['Furnace pressure transmitter'],
    });
    expect((await db.collection('asset_tag_claims').get()).empty).toBe(true);
  });

  test('Operations declares an asset down and Shift Supervisor restores it', async () => {
    await invoke(classRequest());
    await invokeRegistry(assetRequest({
      requestId: IDS.firstAssetRequest,
      assetInstanceId: IDS.firstAsset,
      assetNumber: 1,
      name: 'Furnace 1',
    }));
    await db.collection('maintenance_records').doc('issue-1').set({
      firestoreId: 'issue-1',
      isDeleted: false,
      isResolved: false,
      assetHierarchyRefJson: JSON.stringify({
        schemaVersion: 2,
        scope: 'installedComponent',
        assetInstanceId: IDS.firstAsset,
        assetClassId: IDS.classId,
        assetNumber: 1,
      }),
    });

    const declaration = await invokeCondition({
      requestId: IDS.conditionRequest,
      operation: 'DECLARE_ASSET_CONDITION',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      expectedVersion: 0,
      condition: 'down',
      causeKeys: ['breakdown'],
      reason: 'Drive fault prevents safe furnace operation.',
      linkedIssueIds: ['issue-1'],
    }, 'ops-1');
    expect(declaration).toMatchObject({condition: 'down', version: 1});
    await expect(invokeRegistry({
      requestId: IDS.assetStatusRequest,
      operation: 'SET_ASSET_INSTANCE_STATUS',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      expectedVersion: 1,
      status: 'retired',
      reason: 'Retire the asset after operational closure and review.',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'asset-instance-active-operational-condition',
      }),
    });
    await expect(invokeCondition({
      requestId: IDS.restorationRequest,
      operation: 'RESTORE_ASSET_CONDITION',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      expectedVersion: 1,
      reason: 'Safe operation proved after drive repair.',
    }, 'ops-1')).rejects.toMatchObject({code: 'permission-denied'});

    const restoration = await invokeCondition({
      requestId: IDS.restorationRequest,
      operation: 'RESTORE_ASSET_CONDITION',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      expectedVersion: 1,
      reason: 'Safe operation proved after drive repair.',
    }, 'shift-1');
    expect(restoration).toMatchObject({condition: 'available', version: 2});
    expect((await db.collection('asset_operational_conditions')
      .doc(IDS.firstAsset).get()).data()).toMatchObject({
      active: false,
      restoredByUid: 'shift-1',
      version: 2,
    });
    expect((await db.collection('asset_operational_condition_audits').get()).size)
      .toBe(2);
  });

  test('a linked issue resolved before commit is rejected transactionally', async () => {
    await invoke(classRequest());
    await invokeRegistry(assetRequest({
      requestId: IDS.firstAssetRequest,
      assetInstanceId: IDS.firstAsset,
      assetNumber: 1,
      name: 'Furnace 1',
    }));
    await db.collection('maintenance_records').doc('issue-1').set({
      firestoreId: 'issue-1',
      isDeleted: false,
      isResolved: true,
      assetHierarchyRefJson: JSON.stringify({
        schemaVersion: 2,
        scope: 'installedComponent',
        assetInstanceId: IDS.firstAsset,
        assetClassId: IDS.classId,
        assetNumber: 1,
      }),
    });

    await expect(invokeCondition({
      requestId: IDS.conditionRequest,
      operation: 'DECLARE_ASSET_CONDITION',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      expectedVersion: 0,
      condition: 'down',
      causeKeys: ['breakdown'],
      reason: 'Drive fault prevents safe furnace operation.',
      linkedIssueIds: ['issue-1'],
    }, 'ops-1')).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'asset-condition-linked-issue-resolved',
      }),
    });
    expect((await db.collection('asset_operational_conditions').get()).empty)
      .toBe(true);
    expect((await db.collection('asset_operational_condition_audits').get()).empty)
      .toBe(true);
    expect((await db.collection('asset_operational_condition_receipts').get()).empty)
      .toBe(true);
  });

  test('two furnaces share one definition while installed tag transfer stays atomic', async () => {
    await invoke(classRequest());
    await invoke(createNodeRequest({
      requestId: IDS.firstNodeRequest,
      nodeId: IDS.firstNode,
      name: 'Furnace pressure transmitter',
      tag: null,
      allowTagTransfer: false,
    }));
    await invokeRegistry(assetRequest({
      requestId: IDS.firstAssetRequest,
      assetInstanceId: IDS.firstAsset,
      assetNumber: 1,
      name: 'Furnace 1',
    }));
    await invokeRegistry(assetRequest({
      requestId: IDS.secondAssetRequest,
      assetInstanceId: IDS.secondAsset,
      assetNumber: 2,
      name: 'Furnace 2',
    }));
    await invokeRegistry(componentRequest({
      requestId: IDS.firstComponentRequest,
      assetInstanceId: IDS.firstAsset,
      componentInstanceId: IDS.firstComponent,
      tag: 'PT-101',
      allowTagTransfer: false,
    }));
    const second = componentRequest({
      requestId: IDS.secondComponentRequest,
      assetInstanceId: IDS.secondAsset,
      componentInstanceId: IDS.secondComponent,
      tag: 'PT 101',
      allowTagTransfer: false,
    });

    await expect(invokeRegistry(second)).rejects.toMatchObject({
      code: 'already-exists',
      details: expect.objectContaining({
        reasonCode: 'asset-tag-collision',
        normalizedTag: 'PT101',
        existingComponentInstanceId: IDS.firstComponent,
        existingAssetInstanceName: 'Furnace 1',
        existingNodeName: 'Furnace pressure transmitter',
        existingOwnershipStatus: 'confirmed',
        existingOwnerDiscipline: 'Instrumentation',
        existingAccountableRoleKeys: ['seniorInstrumentation'],
        transferSupported: true,
      }),
    });
    expect(
      (await db.collection('asset_component_instances').doc(IDS.secondComponent).get()).exists,
    ).toBe(false);

    await expect(invokeRegistry({
      ...second,
      requestId: '30303030-3030-4303-8303-303030303030',
      allowTagTransfer: true,
      expectedTagOwnerComponentId: IDS.secondComponent,
    })).rejects.toMatchObject({
      code: 'aborted',
      details: expect.objectContaining({
        reasonCode: 'asset-tag-transfer-owner-changed',
        reviewedComponentInstanceId: IDS.secondComponent,
        currentComponentInstanceId: IDS.firstComponent,
      }),
    });

    const transferred = await invokeRegistry({
      ...second,
      allowTagTransfer: true,
      expectedTagOwnerComponentId: IDS.firstComponent,
    });
    expect(transferred.idempotentReplay).toBe(false);
    const first = (
      await db.collection('asset_component_instances').doc(IDS.firstComponent).get()
    ).data();
    const replacement = (
      await db.collection('asset_component_instances').doc(IDS.secondComponent).get()
    ).data();
    expect(first.componentTag).toBeNull();
    expect(first.normalizedComponentTag).toBeNull();
    expect(replacement.normalizedComponentTag).toBe('PT101');
    expect(first.definitionNodeId).toBe(IDS.firstNode);
    expect(replacement.definitionNodeId).toBe(IDS.firstNode);
    expect(replacement.assetInstanceName).toBe('Furnace 2');

    const claims = await db.collection('asset_tag_claims').get();
    expect(claims.docs).toHaveLength(1);
    expect(claims.docs[0].data()).toMatchObject({
      normalizedTag: 'PT101',
      ownerType: 'installed_component',
      componentInstanceId: IDS.secondComponent,
      assetInstanceId: IDS.secondAsset,
      ownershipStatus: 'confirmed',
      ownerDiscipline: 'Instrumentation',
      accountableRoleKeys: ['seniorInstrumentation'],
    });
    expect(
      (await db.collection('asset_hierarchy_audits').get()).docs
        .filter((doc) => doc.id.endsWith('_tag_source')),
    ).toHaveLength(1);
  });

  test('asset number is unique inside its class', async () => {
    await invoke(classRequest());
    await invokeRegistry(assetRequest({
      requestId: IDS.firstAssetRequest,
      assetInstanceId: IDS.firstAsset,
      assetNumber: 1,
      name: 'Furnace 1',
    }));
    await expect(invokeRegistry(assetRequest({
      requestId: IDS.secondAssetRequest,
      assetInstanceId: IDS.secondAsset,
      assetNumber: 1,
      name: 'Duplicate Furnace 1',
    }))).rejects.toMatchObject({
      code: 'already-exists',
      details: expect.objectContaining({
        reasonCode: 'asset-instance-number-collision',
        assetNumber: 1,
      }),
    });
  });

  test('existing asset mutation fails closed when its number claim disappeared', async () => {
    await invoke(classRequest());
    await invokeRegistry(assetRequest({
      requestId: IDS.firstAssetRequest,
      assetInstanceId: IDS.firstAsset,
      assetNumber: 1,
      name: 'Furnace 1',
    }));
    const numberClaims = await db.collection('asset_instance_numbers').get();
    expect(numberClaims.docs).toHaveLength(1);
    await numberClaims.docs[0].ref.delete();

    await expect(invokeRegistry({
      requestId: IDS.assetStatusRequest,
      operation: 'SET_ASSET_INSTANCE_STATUS',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      expectedVersion: 1,
      status: 'retired',
      reason: 'Retire the physical furnace after controlled verification.',
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'asset-instance-number-claim-drift',
      }),
    });
  });

  test('active component mutation fails closed when its tag claim disappeared', async () => {
    await invoke(classRequest());
    await invoke(createNodeRequest({
      requestId: IDS.firstNodeRequest,
      nodeId: IDS.firstNode,
      name: 'Furnace pressure transmitter',
      tag: null,
      allowTagTransfer: false,
    }));
    await invokeRegistry(assetRequest({
      requestId: IDS.firstAssetRequest,
      assetInstanceId: IDS.firstAsset,
      assetNumber: 1,
      name: 'Furnace 1',
    }));
    const create = componentRequest({
      requestId: IDS.firstComponentRequest,
      assetInstanceId: IDS.firstAsset,
      componentInstanceId: IDS.firstComponent,
      tag: 'PT-101',
      allowTagTransfer: false,
    });
    await invokeRegistry(create);
    const claims = await db.collection('asset_tag_claims').get();
    expect(claims.docs).toHaveLength(1);
    await claims.docs[0].ref.delete();

    await expect(invokeRegistry({
      ...create,
      requestId: IDS.componentUpdateRequest,
      operation: 'UPDATE_COMPONENT_INSTANCE',
      expectedVersion: 1,
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'asset-tag-claim-missing',
        normalizedTag: 'PT101',
      }),
    });
  });

  test('unapproved role cannot mutate and confirmed ownership cannot be incomplete', async () => {
    await expect(invoke(classRequest(), 'ops-1')).rejects.toMatchObject({
      code: 'permission-denied',
    });
    await invoke(classRequest());
    const invalid = createNodeRequest({
      requestId: IDS.firstNodeRequest,
      nodeId: IDS.firstNode,
      name: 'Unowned confirmed component',
      tag: null,
      allowTagTransfer: false,
    });
    invalid.nodeDraft.ownerDiscipline = null;
    invalid.nodeDraft.accountableRoleKeys = [];
    await expect(invoke(invalid)).rejects.toMatchObject({
      code: 'invalid-argument',
      details: expect.objectContaining({
        field: 'nodeDraft.ownershipStatus',
      }),
    });

    const contradictory = createNodeRequest({
      requestId: '10101010-1010-4101-8101-101010101010',
      nodeId: '20202020-2020-4202-8202-202020202020',
      name: 'Contradictory unassigned component',
      tag: null,
      allowTagTransfer: false,
    });
    contradictory.nodeDraft.ownershipStatus = 'unassigned';
    await expect(invoke(contradictory)).rejects.toMatchObject({
      code: 'invalid-argument',
      details: expect.objectContaining({
        field: 'nodeDraft.ownershipStatus',
      }),
    });
  });
});
