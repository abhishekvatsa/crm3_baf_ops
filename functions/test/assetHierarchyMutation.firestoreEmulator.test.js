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
const {
  mutateOperationalEventWithDb,
} = require('../lib/operationalEventMutation');
const {
  mutateOperationalEventIssueLinkWithDb,
} = require('../lib/operationalEventIssueLinkMutation');
const {
  mutateDeviceRecoveryWithDb,
} = require('../lib/deviceRecoveryMutation');

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
  eventId: '15151515-1515-4151-8151-151515151515',
  eventCreateRequest: '16161616-1616-4161-8161-161616161616',
  eventResolveRequest: '17171717-1717-4171-8171-171717171717',
  eventIssue: '18181818-1818-4181-8181-181818181818',
  eventIssueLinkRequest: '19191919-1919-4191-8191-191919191919',
  replacementComponent: '21212121-2121-4121-8121-212121212121',
  replacementRequest: '23232323-2323-4232-8232-232323232323',
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

  async function invokeEvent(data, authUid) {
    return mutateOperationalEventWithDb({
      db,
      authUid,
      data,
      now: () => new Date('2026-08-13T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
  }

  async function invokeEventIssueLink(data, authUid) {
    return mutateOperationalEventIssueLinkWithDb({
      db,
      authUid,
      data,
      now: () => new Date('2026-08-13T12:00:00.000Z'),
      timestampFromDate: admin.firestore.Timestamp.fromDate,
    });
  }

  async function invokeDeviceRecovery(data, authUid) {
    return mutateDeviceRecoveryWithDb({
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

  test('admin recovery targets one non-admin phone with reserved audit custody', async () => {
    const selectedInstallation = '41414141-4141-4141-8141-414141414141';
    const otherInstallation = '42424242-4242-4242-8242-424242424242';
    const requestId = '43434343-4343-4343-8343-434343434343';
    const webInstallation = '45454545-4545-4545-8545-454545454545';
    const updatedAt = admin.firestore.Timestamp.fromDate(
      new Date('2026-08-13T11:30:00.000Z'),
    );
    const target = db.collection('users').doc('ops-1');
    await Promise.all([
      target.collection('notification_installations')
        .doc(selectedInstallation)
        .set({
          schemaVersion: 1,
          token: 'private-selected-token',
          platform: 'android',
          updatedAt,
        }),
      target.collection('notification_installations')
        .doc(otherInstallation)
        .set({
          schemaVersion: 1,
          token: 'private-other-token',
          platform: 'android',
          updatedAt,
        }),
      target.collection('notification_installations')
        .doc(webInstallation)
        .set({
          schemaVersion: 1,
          token: 'private-web-token',
          platform: 'web',
          updatedAt,
        }),
      ...Array.from({length: 9}, (_, index) => {
        const suffix = String(index + 1).padStart(12, '0');
        return target.collection('notification_installations')
          .doc(`aaaaaaaa-aaaa-4aaa-8aaa-${suffix}`)
          .set({
            schemaVersion: 1,
            token: `private-newer-web-token-${index}`,
            platform: 'web',
            updatedAt: admin.firestore.Timestamp.fromDate(
              new Date(`2026-08-13T11:4${index}:00.000Z`),
            ),
          });
      }),
      ...Array.from({length: 9}, (_, index) => {
        const suffix = String(index + 1).padStart(12, '0');
        return target.collection('notification_installations')
          .doc(`bbbbbbbb-bbbb-4bbb-8bbb-${suffix}`)
          .set({
            schemaVersion: 1,
            token: `private-older-supported-token-${index}`,
            platform: index % 2 === 0 ? 'android' : 'ios',
            updatedAt: admin.firestore.Timestamp.fromDate(
              new Date(`2026-08-13T10:0${index}:00.000Z`),
            ),
          });
      }),
    ]);

    const inventory = await invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_LIST',
      targetUid: 'ops-1',
    }, 'admin-1');
    expect(inventory.installations).toHaveLength(8);
    expect(inventory.installations.map(({installationId}) => installationId))
      .toContain(selectedInstallation);
    expect(inventory.installations.map(({installationId}) => installationId))
      .toContain(otherInstallation);
    expect(inventory.installations.map(({installationId}) => installationId))
      .not.toContain('bbbbbbbb-bbbb-4bbb-8bbb-000000000001');
    expect(JSON.stringify(inventory)).not.toContain('private-selected-token');
    expect(inventory.installations.map(({installationId}) => installationId))
      .not.toContain(webInstallation);

    await expect(invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_REQUEST',
      requestId: '46464646-4646-4646-8646-464646464646',
      targetUid: 'ops-1',
      installationId: webInstallation,
      reason: 'Web clients cannot perform a protected local Isar reset.',
    }, 'admin-1')).rejects.toMatchObject({code: 'not-found'});

    await expect(invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_REQUEST',
      requestId,
      targetUid: 'ops-1',
      installationId: selectedInstallation,
      reason: 'Safely remove stale pilot records from the selected phone.',
    }, 'ops-1')).rejects.toMatchObject({code: 'permission-denied'});

    const request = await invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_REQUEST',
      requestId,
      targetUid: 'ops-1',
      installationId: selectedInstallation,
      reason: 'Safely remove stale pilot records from the selected phone.',
    }, 'admin-1');
    expect(request).toMatchObject({status: 'pending', notificationQueued: true});
    const event = (await db.collection('maintenance_workflow_events')
      .doc(`device_recovery_${requestId}`).get()).data();
    expect(event.payload).toEqual({deviceRecoveryRequestId: requestId});
    expect(JSON.stringify(event)).not.toContain('ops-1');
    expect(JSON.stringify(event)).not.toContain('private-selected-token');

    const wrongPhone = await invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_POLL',
      installationId: otherInstallation,
    }, 'ops-1');
    expect(wrongPhone.request).toBeNull();

    const selectedPhone = await invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_POLL',
      installationId: selectedInstallation,
    }, 'ops-1');
    expect(selectedPhone.request).toMatchObject({
      requestId,
      targetUid: 'ops-1',
      installationId: selectedInstallation,
    });

    const claim = await invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_CLAIM',
      requestId,
      installationId: selectedInstallation,
    }, 'ops-1');
    expect(claim).toMatchObject({status: 'in_progress', targetUid: 'ops-1'});
    await expect(invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_CANCEL',
      requestId,
      targetUid: 'ops-1',
      installationId: selectedInstallation,
      reason: 'Cancellation cannot race the already claimed phone reset.',
    }, 'admin-1')).rejects.toMatchObject({code: 'failed-precondition'});

    await target.update({isApproved: false});
    expect(await invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_POLL',
      installationId: selectedInstallation,
    }, 'ops-1')).toMatchObject({request: {status: 'in_progress'}});
    expect(await invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_CLAIM',
      requestId,
      installationId: selectedInstallation,
    }, 'ops-1')).toMatchObject({
      status: 'in_progress',
      idempotentReplay: true,
    });
    await target.collection('notification_installations')
      .doc(selectedInstallation).delete();
    expect(await invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_POLL',
      installationId: selectedInstallation,
    }, 'ops-1')).toMatchObject({request: {status: 'in_progress'}});
    expect(await invokeDeviceRecovery({
      operation: 'DEVICE_RECOVERY_CLAIM',
      requestId,
      installationId: selectedInstallation,
    }, 'ops-1')).toMatchObject({
      status: 'in_progress',
      idempotentReplay: true,
    });

    const completionRequest = {
      operation: 'DEVICE_RECOVERY_COMPLETE',
      requestId,
      installationId: selectedInstallation,
      backupFileCount: 2,
      clearedCursorCount: 3,
      backedUpUnsyncedRows: 1,
    };
    const completion = await invokeDeviceRecovery(completionRequest, 'ops-1');
    expect(completion).toMatchObject({
      status: 'completed',
      idempotentReplay: false,
    });
    expect(await invokeDeviceRecovery(completionRequest, 'ops-1'))
      .toMatchObject({status: 'completed', idempotentReplay: true});
    const audits = await db.collection('audit_logs').get();
    expect(audits.docs.map((snapshot) => snapshot.id).sort()).toEqual([
      `server_authority_device_recovery_${requestId}_claimed`,
      `server_authority_device_recovery_${requestId}_completed`,
      `server_authority_device_recovery_${requestId}_requested`,
    ]);
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

  test('component replacement preserves lineage, count, tag custody, and replay evidence', async () => {
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

    const replacement = {
      requestId: IDS.replacementRequest,
      operation: 'REPLACE_COMPONENT_INSTANCE',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      componentInstanceId: IDS.firstComponent,
      replacementComponentInstanceId: IDS.replacementComponent,
      expectedVersion: 1,
      expectedAssetInstanceVersion: 2,
      reason: 'Replace the pressure transmitter after confirmed calibration failure.',
      allowTagTransfer: false,
      expectedTagOwnerComponentId: null,
      componentDraft: {
        ...create.componentDraft,
        serialNumber: 'PT-NEW-001',
        installedOn: '2026-08-13T11:45:00.000Z',
      },
    };
    const firstResult = await invokeRegistry(replacement);
    const replay = await invokeRegistry(replacement);
    expect(firstResult).toMatchObject({
      nodeId: IDS.replacementComponent,
      version: 1,
      idempotentReplay: false,
    });
    expect(replay).toEqual({...firstResult, idempotentReplay: true});

    const source = (
      await db.collection('asset_component_instances').doc(IDS.firstComponent).get()
    ).data();
    const incoming = (
      await db.collection('asset_component_instances').doc(IDS.replacementComponent).get()
    ).data();
    const asset = (
      await db.collection('asset_instances').doc(IDS.firstAsset).get()
    ).data();
    expect(source).toMatchObject({
      status: 'retired',
      version: 2,
      componentLineageId: IDS.firstComponent,
      replacedByComponentInstanceId: IDS.replacementComponent,
      componentTag: 'PT-101',
    });
    expect(incoming).toMatchObject({
      status: 'active',
      version: 1,
      componentLineageId: IDS.firstComponent,
      replacesComponentInstanceId: IDS.firstComponent,
      componentTag: 'PT-101',
      serialNumber: 'PT-NEW-001',
    });
    expect(asset).toMatchObject({activeComponentCount: 1, version: 3});
    const claims = await db.collection('asset_tag_claims').get();
    expect(claims.docs).toHaveLength(1);
    expect(claims.docs[0].data()).toMatchObject({
      componentInstanceId: IDS.replacementComponent,
      normalizedTag: 'PT101',
    });
    const primaryAudit = (
      await db.collection('asset_hierarchy_audits')
        .doc(`asset_registry_${IDS.replacementRequest}`).get()
    ).data();
    const sourceAudit = (
      await db.collection('asset_hierarchy_audits')
        .doc(`asset_registry_${IDS.replacementRequest}_replacement_source`).get()
    ).data();
    expect(primaryAudit).toMatchObject({
      action: 'replacement_installed',
      entityId: IDS.replacementComponent,
      relatedEntityId: IDS.firstComponent,
      componentLineageId: IDS.firstComponent,
    });
    expect(sourceAudit).toMatchObject({
      action: 'replaced',
      entityId: IDS.firstComponent,
      relatedEntityId: IDS.replacementComponent,
      componentLineageId: IDS.firstComponent,
    });
    await expect(invokeRegistry({
      requestId: '24242424-2424-4242-8242-242424242424',
      operation: 'SET_COMPONENT_INSTANCE_STATUS',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      componentInstanceId: IDS.firstComponent,
      expectedVersion: 2,
      status: 'active',
      reason: 'Attempt to restore a component superseded by replacement.',
      allowTagTransfer: false,
      expectedTagOwnerComponentId: null,
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'asset-component-replaced-terminal',
      }),
    });
  });

  test('component replacement snapshots exact resolved-issue evidence and replays it', async () => {
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
    await db.collection('maintenance_records').doc('resolved-issue-1').set({
      version: 4,
      isDeleted: false,
      isResolved: true,
      status: 'resolved',
      description: 'Pressure transmitter failed calibration repeatedly.',
      endDate: '2026-08-13T11:30:00.000Z',
      closedByUid: 'admin-1',
      closedByName: 'Admin One',
      assetHierarchyRefJson: JSON.stringify({
        schemaVersion: 2,
        scope: 'installedComponent',
        assetClassId: IDS.classId,
        assetInstanceId: IDS.firstAsset,
        assetNumber: 1,
        componentInstanceId: IDS.firstComponent,
      }),
    });
    const replacement = {
      requestId: IDS.replacementRequest,
      operation: 'REPLACE_COMPONENT_INSTANCE',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      componentInstanceId: IDS.firstComponent,
      replacementComponentInstanceId: IDS.replacementComponent,
      expectedVersion: 1,
      expectedAssetInstanceVersion: 2,
      reason: 'Replace the failed transmitter against resolved issue evidence.',
      allowTagTransfer: false,
      expectedTagOwnerComponentId: null,
      evidenceReference: {
        sourceType: 'maintenanceIssue',
        sourceId: 'resolved-issue-1',
        expectedVersion: 4,
      },
      componentDraft: {
        ...create.componentDraft,
        serialNumber: 'PT-NEW-002',
        installedOn: '2026-08-13T11:45:00.000Z',
      },
    };

    await db.collection('maintenance_records').doc('resolved-issue-1').update({
      endDate: '2026-08-13T11:30:00.000',
    });
    await expect(invokeRegistry(replacement)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'asset-component-replacement-evidence-malformed',
        field: 'issue endDate',
      }),
    });
    await db.collection('maintenance_records').doc('resolved-issue-1').update({
      endDate: '2026-08-13T11:30:00.000Z',
    });

    const first = await invokeRegistry(replacement);
    expect(await invokeRegistry(replacement)).toEqual({
      ...first,
      idempotentReplay: true,
    });
    const audit = (
      await db.collection('asset_hierarchy_audits')
        .doc(`asset_registry_${IDS.replacementRequest}`).get()
    ).data();
    const sourceAudit = (
      await db.collection('asset_hierarchy_audits')
        .doc(`asset_registry_${IDS.replacementRequest}_replacement_source`).get()
    ).data();
    const receipt = (
      await db.collection('asset_hierarchy_mutation_receipts')
        .doc(IDS.replacementRequest).get()
    ).data();
    for (const record of [audit, sourceAudit, receipt]) {
      expect(record).toMatchObject({
        acceptedEvidenceType: 'maintenanceIssue',
        acceptedEvidenceId: 'resolved-issue-1',
        acceptedEvidenceVersion: 4,
      });
      expect(JSON.parse(record.acceptedEvidenceSnapshotJson)).toMatchObject({
        sourceType: 'maintenanceIssue',
        sourceId: 'resolved-issue-1',
        sourceVersion: 4,
        assetClassId: IDS.classId,
        assetInstanceId: IDS.firstAsset,
        assetNumber: 1,
        componentInstanceId: IDS.firstComponent,
        completedByUid: 'admin-1',
      });
    }
    expect(receipt.fingerprint).toMatch(/^assetreg3-sha256:/);
    await db.collection('asset_hierarchy_audits')
      .doc(`asset_registry_${IDS.replacementRequest}`)
      .update({acceptedEvidenceSnapshotJson: '{"sourceId":"tampered"}'});
    await expect(invokeRegistry(replacement)).rejects.toMatchObject({
      code: 'data-loss',
      details: expect.objectContaining({
        reasonCode: 'asset-registry-replay-evidence-drift',
      }),
    });
  });

  test('component replacement rejects stale or cross-asset planned-work evidence', async () => {
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
    await db.collection('job_executions').doc('completed-job-1').set({
      version: 3,
      isDeleted: false,
      isCompleted: true,
      isCancelled: false,
      templateName: 'Pressure transmitter replacement',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.secondAsset,
      assetNumber: 2,
      completedAt: admin.firestore.Timestamp.fromDate(
        new Date('2026-08-13T11:30:00.000Z'),
      ),
      completedByUid: 'admin-1',
      completedByName: 'Admin One',
      metadataJson: JSON.stringify({
        assignmentAssetIdentity: {
          assetClassId: IDS.classId,
          assetInstanceId: IDS.secondAsset,
          assetNumber: 2,
        },
      }),
    });
    const replacement = {
      requestId: IDS.replacementRequest,
      operation: 'REPLACE_COMPONENT_INSTANCE',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      componentInstanceId: IDS.firstComponent,
      replacementComponentInstanceId: IDS.replacementComponent,
      expectedVersion: 1,
      expectedAssetInstanceVersion: 2,
      reason: 'Attempt replacement against unrelated planned-work evidence.',
      allowTagTransfer: false,
      expectedTagOwnerComponentId: null,
      evidenceReference: {
        sourceType: 'plannedJob',
        sourceId: 'completed-job-1',
        expectedVersion: 3,
      },
      componentDraft: {
        ...create.componentDraft,
        installedOn: '2026-08-13T11:45:00.000Z',
      },
    };
    await expect(invokeRegistry(replacement)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'asset-component-replacement-evidence-asset-mismatch',
      }),
    });
    await db.collection('job_executions').doc('completed-job-1').update({
      assetInstanceId: IDS.firstAsset,
      assetNumber: 1,
      metadataJson: JSON.stringify({
        assignmentAssetIdentity: {
          assetClassId: IDS.classId,
          assetInstanceId: IDS.firstAsset,
          assetNumber: 1,
        },
      }),
    });
    await expect(invokeRegistry({
      ...replacement,
      evidenceReference: {...replacement.evidenceReference, expectedVersion: 2},
    })).rejects.toMatchObject({
      code: 'aborted',
      details: expect.objectContaining({
        reasonCode: 'asset-component-replacement-evidence-version-mismatch',
      }),
    });
    await db.collection('job_executions').doc('completed-job-1').update({
      isCancelled: admin.firestore.FieldValue.delete(),
    });
    const accepted = await invokeRegistry(replacement);
    expect(accepted.operation).toBe('REPLACE_COMPONENT_INSTANCE');
  });

  test('component replacement rejects a different definition and cross-asset mutation', async () => {
    await invoke(classRequest());
    await invoke(createNodeRequest({
      requestId: IDS.firstNodeRequest,
      nodeId: IDS.firstNode,
      name: 'Furnace pressure transmitter',
      tag: null,
      allowTagTransfer: false,
    }));
    await invoke({
      ...createNodeRequest({
        requestId: IDS.secondNodeRequest,
        nodeId: IDS.secondNode,
        name: 'Furnace burner block',
        tag: null,
        allowTagTransfer: false,
      }),
      expectedAssetClassVersion: 1,
    });
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
    const create = componentRequest({
      requestId: IDS.firstComponentRequest,
      assetInstanceId: IDS.firstAsset,
      componentInstanceId: IDS.firstComponent,
      tag: 'PT-101',
      allowTagTransfer: false,
    });
    await invokeRegistry(create);
    const replacement = {
      requestId: IDS.replacementRequest,
      operation: 'REPLACE_COMPONENT_INSTANCE',
      assetClassId: IDS.classId,
      assetInstanceId: IDS.firstAsset,
      componentInstanceId: IDS.firstComponent,
      replacementComponentInstanceId: IDS.replacementComponent,
      expectedVersion: 1,
      expectedAssetInstanceVersion: 2,
      reason: 'Attempt a replacement against the wrong governed definition.',
      allowTagTransfer: false,
      expectedTagOwnerComponentId: null,
      componentDraft: {
        ...create.componentDraft,
        definitionNodeId: IDS.secondNode,
        installedOn: '2026-08-13T11:45:00.000Z',
      },
    };
    await expect(invokeRegistry(replacement)).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'asset-component-replacement-definition-mismatch',
      }),
    });
    await expect(invokeRegistry({
      ...create,
      requestId: IDS.componentUpdateRequest,
      operation: 'UPDATE_COMPONENT_INSTANCE',
      assetInstanceId: IDS.secondAsset,
      expectedVersion: 1,
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'asset-component-owner-mismatch',
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

  test('records and resolves an asset-scoped operational event with exact replay evidence', async () => {
    await invoke(classRequest());
    await invokeRegistry(assetRequest({
      requestId: IDS.firstAssetRequest,
      assetInstanceId: IDS.firstAsset,
      assetNumber: 1,
      name: 'Furnace 1',
    }));
    const create = {
      requestId: IDS.eventCreateRequest,
      operation: 'CREATE_OPERATIONAL_EVENT',
      eventId: IDS.eventId,
      expectedVersion: 0,
      reason: 'Record the crane outage affecting Furnace 1 movement.',
      eventDraft: {
        eventType: 'crane',
        title: 'Charging crane unavailable',
        description: 'Furnace movement is waiting for the charging crane.',
        severity: 'significant',
        scope: 'assets',
        affectedAssetClassIds: [IDS.classId],
        affectedAssetInstanceIds: [IDS.firstAsset],
        startedAt: '2026-08-13T11:30:00.000Z',
      },
      resolutionNote: null,
    };
    const first = await invokeEvent(create, 'ops-1');
    const replay = await invokeEvent(create, 'ops-1');
    expect(first).toMatchObject({status: 'open', version: 1});
    expect(replay).toEqual({...first, idempotentReplay: true});

    const resolved = await invokeEvent({
      requestId: IDS.eventResolveRequest,
      operation: 'RESOLVE_OPERATIONAL_EVENT',
      eventId: IDS.eventId,
      expectedVersion: 1,
      reason: 'Close after Operations verifies that crane service is restored.',
      eventDraft: null,
      resolutionNote: 'Crane trial completed and Furnace 1 movement resumed safely.',
    }, 'shift-1');
    expect(resolved).toMatchObject({status: 'resolved', version: 2});
    expect((await db.collection('operational_events').doc(IDS.eventId).get()).data())
      .toMatchObject({
        eventType: 'crane',
        scope: 'assets',
        affectedAssetInstanceIds: [IDS.firstAsset],
        resolvedByUid: 'shift-1',
        version: 2,
      });
    expect((await db.collection('operational_event_audits').get()).size).toBe(2);
    expect((await db.collection('operational_event_receipts').get()).size).toBe(2);
  });

  test('atomically links an operational event occurrence to a governed issue', async () => {
    await invoke(classRequest());
    await invokeRegistry(assetRequest({
      requestId: IDS.firstAssetRequest,
      assetInstanceId: IDS.firstAsset,
      assetNumber: 1,
      name: 'Furnace 1',
    }));
    await invokeEvent({
      requestId: IDS.eventCreateRequest,
      operation: 'CREATE_OPERATIONAL_EVENT',
      eventId: IDS.eventId,
      expectedVersion: 0,
      reason: 'Record the crane outage affecting Furnace 1 movement.',
      eventDraft: {
        eventType: 'crane',
        title: 'Charging crane unavailable',
        description: 'Furnace movement is waiting for the charging crane.',
        severity: 'significant',
        scope: 'assets',
        affectedAssetClassIds: [IDS.classId],
        affectedAssetInstanceIds: [IDS.firstAsset],
        startedAt: '2026-08-13T11:30:00.000Z',
      },
      resolutionNote: null,
    }, 'ops-1');
    await db.collection('maintenance_records').doc(IDS.eventIssue).set({
      firestoreId: IDS.eventIssue,
      version: 4,
      status: 'open',
      isResolved: false,
      isDeleted: false,
      assetType: 'furnace',
      assetNumber: 1,
      assetHierarchyRefJson: JSON.stringify({
        schemaVersion: 3,
        scope: 'physicalAsset',
        assetClassId: IDS.classId,
        assetInstanceId: IDS.firstAsset,
      }),
      description: 'Inspect the furnace after crane movement was interrupted.',
      routedTo: 'mechanical',
      component: null,
      subsystem: 'Furnace handling',
      tag: null,
      startDate: admin.firestore.Timestamp.fromDate(
        new Date('2026-08-13T11:35:00.000Z'),
      ),
      createdAt: admin.firestore.Timestamp.fromDate(
        new Date('2026-08-13T11:36:00.000Z'),
      ),
      updatedAt: admin.firestore.Timestamp.fromDate(
        new Date('2026-08-13T11:36:00.000Z'),
      ),
    });
    const command = {
      requestId: IDS.eventIssueLinkRequest,
      operation: 'LINK_OPERATIONAL_EVENT_ISSUE',
      eventId: IDS.eventId,
      issueId: IDS.eventIssue,
      expectedEventVersion: 1,
      expectedIssueVersion: 4,
      relationship: 'responseToEvent',
      reason: 'The inspection was raised in response to the crane interruption.',
    };
    const first = await invokeEventIssueLink(command, 'ops-1');
    const replay = await invokeEventIssueLink(command, 'ops-1');
    expect(first).toMatchObject({
      eventVersion: 2,
      issueVersion: 5,
      idempotentReplay: false,
    });
    expect(replay).toEqual({...first, idempotentReplay: true});
    expect((await db.collection('operational_events').doc(IDS.eventId).get()).data())
      .toMatchObject({
        issueLinkIds: [first.linkId],
        linkedIssueIds: [IDS.eventIssue],
        version: 2,
      });
    expect((await db.collection('maintenance_records').doc(IDS.eventIssue).get()).data())
      .toMatchObject({operationalEventIssueLinkIds: [first.linkId], version: 5});
    expect((await db.collection('operational_event_issue_links').doc(first.linkId).get()).data())
      .toMatchObject({
        eventId: IDS.eventId,
        issueId: IDS.eventIssue,
        relationship: 'responseToEvent',
      });
    expect((await db.collection('operational_event_issue_link_audits').get()).size)
      .toBe(1);
    expect((await db.collection('operational_event_issue_link_receipts').get()).size)
      .toBe(1);
  });
});
