const admin = require('firebase-admin');

const {
  MaintenanceWorkflowCommandService,
} = require('../lib/maintenanceWorkflow/dispatcher');
const {
  FirebaseWorkflowStore,
} = require('../lib/maintenanceWorkflow/firebaseStore');

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';
const appName = `workflow-emulator-${process.pid}-${Date.now()}`;

const actor = {
  uid: 'admin1',
  name: 'Admin',
  roles: new Set(['admin']),
};
const otherActor = {
  uid: 'admin2',
  name: 'Other Admin',
  roles: new Set(['admin']),
};

function createCommand(id) {
  return {
    commandId: `create-${id}`,
    commandType: 'createLegacyWorkflowJob',
    aggregateId: id,
    expectedVersion: 0,
    payload: {
      assignmentSchemaVersion: 2,
      executionId: id,
      templateFirestoreId: 'template-1',
      expectedTemplateVersion: 1,
      assetClassId: 'base-class',
      assetInstanceId: 'base-101',
    },
  };
}

describeWithEmulator('maintenance workflow Firestore serialization', () => {
  let app;
  let db;
  let service;

  async function clearFirestore() {
    const response = await fetch(
      `http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
      {method: 'DELETE'},
    );
    if (!response.ok) {
      throw new Error(`${response.status} ${await response.text()}`);
    }
  }

  beforeAll(async () => {
    app = admin.initializeApp({projectId}, appName);
    db = app.firestore();
    db.settings({ignoreUndefinedProperties: true});
    service = new MaintenanceWorkflowCommandService(
      new FirebaseWorkflowStore(db),
    );
  });

  beforeEach(async () => {
    await clearFirestore();
    await Promise.all([
      db.collection('users').doc(actor.uid).set({
        isApproved: true,
        roles: ['admin'],
        name: actor.name,
      }),
      db.collection('users').doc(otherActor.uid).set({
        isApproved: true,
        roles: ['admin'],
        name: otherActor.name,
      }),
      db.collection('job_templates').doc('template-1').set({
        firestoreId: 'template-1',
        version: 1,
        jobName: 'Base planned maintenance',
        applicableAssetType: 'base',
        assignedAgencies: ['mechanical'],
        assetHierarchyRefJson: null,
        isActive: true,
        isDeprecated: false,
        isDeleted: false,
      }),
      db.collection('asset_classes').doc('base-class').set({
        schemaVersion: 1,
        assetClassId: 'base-class',
        legacyAssetTypeKey: 'base',
        status: 'active',
      }),
      db.collection('asset_instances').doc('base-101').set({
        schemaVersion: 1,
        assetInstanceId: 'base-101',
        assetClassId: 'base-class',
        assetNumber: 101,
        status: 'active',
        version: 1,
      }),
    ]);
  });

  afterAll(async () => {
    await db.terminate();
    await app.delete();
  });

  test('concurrent same-equipment creates preserve both workflow contributions', async () => {
    await db.collection('equipment_status').doc('base_101').set({
      assetTypeKey: 'base',
      assetNumber: 101,
      state: 'available',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });

    await Promise.all([
      service.execute(
        createCommand('workflow-a'),
        {actor, serverNow: new Date('2026-07-25T12:00:00.000Z')},
      ),
      service.execute(
        createCommand('workflow-b'),
        {actor, serverNow: new Date('2026-07-25T12:00:01.000Z')},
      ),
    ]);

    const workflows = await db.collection('maintenance_workflows').get();
    const executions = await db.collection('job_executions').get();
    const equipment = await db.collection('equipment_status').doc('base_101').get();

    expect(workflows.size).toBe(2);
    for (const workflow of workflows.docs) {
      expect(workflow.data()).toMatchObject({
        assetClassId: 'base-class',
        assetInstanceId: 'base-101',
        assetNumber: 101,
      });
    }
    expect(executions.size).toBe(2);
    for (const execution of executions.docs) {
      expect(execution.data()).toMatchObject({
        assetClassId: 'base-class',
        assetInstanceId: 'base-101',
        assetNumber: 101,
      });
    }
    expect(equipment.data()).toMatchObject({
      state: 'underMaintenance',
      assetClassId: 'base-class',
      assetInstanceId: 'base-101',
      activeNonRedMaintenanceCount: 2,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 2,
    });
  });

  test('transaction denies a stale preflight actor revoked before transaction start', async () => {
    await db.collection('equipment_status').doc('base_101').set({
      assetTypeKey: 'base',
      assetNumber: 101,
      state: 'available',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });

    // `actor` represents the successfully authorized callable preflight.
    // Revocation commits before the business transaction starts.
    await db.collection('users').doc(actor.uid).update({
      isApproved: false,
    });

    await expect(service.execute(
      createCommand('workflow-revocation-race'),
      {
        actor,
        serverNow: new Date('2026-07-26T09:00:00.000Z'),
      },
    )).rejects.toMatchObject({
      code: 'permission-denied',
      details: {reasonCode: 'workflow-actor-authority-invalid'},
    });

    expect((await db.collection('maintenance_workflows').get()).empty).toBe(true);
    expect((await db.collection(
      'maintenance_workflow_command_receipts',
    ).get()).empty).toBe(true);
    expect((await db.collection('equipment_status').doc('base_101').get())
      .data()).toMatchObject({
      activeNonRedMaintenanceCount: 0,
      version: 0,
    });
  });

  test('role-narrowed owner and cross-actor attempts cannot replay a receipt', async () => {
    await db.collection('equipment_status').doc('base_101').set({
      assetTypeKey: 'base',
      assetNumber: 101,
      state: 'available',
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      version: 0,
    });
    const command = createCommand('workflow-replay-guard');
    const first = await service.execute(command, {
      actor,
      serverNow: new Date('2026-07-26T09:10:00.000Z'),
    });

    await db.collection('users').doc(actor.uid).update({
      roles: ['operations'],
    });
    await expect(service.execute(command, {
      actor,
      serverNow: new Date('2026-07-26T09:11:00.000Z'),
    })).rejects.toMatchObject({code: 'permission-denied'});

    for (const replay of [
      command,
      {...command, payload: {...command.payload, remarks: 'changed'}},
    ]) {
      await expect(service.execute(replay, {
        actor: otherActor,
        serverNow: new Date('2026-07-26T09:12:00.000Z'),
      })).rejects.toMatchObject({
        code: 'permission-denied',
        details: {reasonCode: 'workflow-receipt-owner-mismatch'},
      });
    }

    const workflows = await db.collection('maintenance_workflows').get();
    const receipts = await db.collection(
      'maintenance_workflow_command_receipts',
    ).get();
    expect(workflows.size).toBe(1);
    expect(receipts.size).toBe(1);
    expect(receipts.docs[0].data()).toMatchObject({
      receiptSchemaVersion: 2,
      actorUid: actor.uid,
      payloadFingerprint: expect.stringMatching(/^sha256:[0-9a-f]{64}$/),
      resultKey: first.resultKey,
    });
  });

  test('ticket creation atomically writes canonical issue and derived evidence', async () => {
    await Promise.all([
      db.collection('asset_classes').doc('furnace-class').set({
        schemaVersion: 1,
        assetClassId: 'furnace-class',
        legacyAssetTypeKey: 'furnace',
        code: 'FR',
        name: 'Furnace',
        status: 'active',
      }),
      db.collection('asset_instances').doc('furnace-7').set({
        schemaVersion: 1,
        assetInstanceId: 'furnace-7',
        assetClassId: 'furnace-class',
        assetClassCode: 'FR',
        assetClassName: 'Furnace',
        assetNumber: 7,
        name: 'Furnace 7',
        status: 'active',
        version: 4,
        ownershipStatus: 'confirmed',
        ownerDiscipline: 'Operations',
        accountableRoleKeys: ['operations'],
      }),
    ]);
    const command = {
      commandId: 'ticket-create-command',
      commandType: 'createMaintenanceTicket',
      aggregateId: 'ticket-create',
      expectedVersion: 0,
      payload: {
        ticket: {
          schemaVersion: 1,
          version: 1,
          assetType: 'furnace',
          assetNumber: 7,
          component: 'Burner system',
          subsystem: 'Client supplied path is not authoritative',
          tag: null,
          hierarchyPath: ['Untrusted', 'Client path'],
          assetHierarchyRefJson: JSON.stringify({
            schemaVersion: 3,
            scope: 'physicalAsset',
            assetClassId: 'furnace-class',
            assetInstanceId: 'furnace-7',
            assetInstanceVersion: 4,
          }),
          maintenanceType: 'breakdown',
          classification: 'furnaceBurnerLockout',
          description: 'Burners 2 and 5 remain locked out during firing.',
          routedTo: 'instrumentation',
          otherDepartment: null,
          isCritical: true,
          startDate: '2026-08-14T16:20:00.000Z',
          chargeNoAtEvent: 123456,
          qualityIntentSchemaVersion: 1,
          qualityImpactAssessment: 'suspected',
          qualityWarningReason:
            'Burner instability may have affected temperature uniformity.',
          burnerLockoutSchemaVersion: 1,
          burnerPositions: [2, 5],
          burnerCommonMode: true,
          burnerCycleStage: 'firing',
          burnerHmiAlarm: 'Flame failure',
          burnerFlameObservation: 'notSeen',
          burnerSparkObservation: 'seen',
          burnerRelightAttempts: 1,
          burnerRemainsLockedOut: true,
          burnerRedHotPositions: [5],
          burnerAttendedPositions: [],
          burnerResolutionEvidence: {},
        },
      },
    };
    const first = await service.execute(command, {
      actor,
      serverNow: new Date('2026-08-14T17:00:00.000Z'),
    });
    const replay = await service.execute(command, {
      actor,
      serverNow: new Date('2026-08-14T17:01:00.000Z'),
    });

    expect(replay).toEqual(first);
    expect(first).toMatchObject({
      resultKey: 'maintenance-ticket-created',
      result: {
        ticketId: 'ticket-create',
        warningId: 'issue_ticket-create',
        directiveId: 'burner_red_hot_ticket-create',
      },
    });
    const [ticket, warning, directive, audit, receipt] = await Promise.all([
      db.collection('maintenance_records').doc('ticket-create').get(),
      db.collection('quality_warnings').doc('issue_ticket-create').get(),
      db.collection('directives').doc('burner_red_hot_ticket-create').get(),
      db.collection('audit_logs')
        .doc('server_maintenance_ticket_ticket-create-command').get(),
      db.collection('maintenance_workflow_command_receipts')
        .doc('ticket-create-command').get(),
    ]);
    expect(ticket.data()).toMatchObject({
      loggedByUid: actor.uid,
      hierarchyPath: ['Furnace', 'Furnace 7'],
      qualityImpactAssessment: 'suspected',
      burnerRedHotPositions: [5],
      status: 'open',
      version: 1,
    });
    expect(ticket.data().createdAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(JSON.parse(ticket.data().assetHierarchyRefJson)).toMatchObject({
      assetClassId: 'furnace-class',
      assetInstanceId: 'furnace-7',
      hierarchyPath: ['Furnace', 'Furnace 7'],
    });
    expect(warning.data()).toMatchObject({
      sourceId: 'ticket-create',
      createdByUid: actor.uid,
    });
    expect(directive.data()).toMatchObject({
      linkedMaintenanceFirestoreId: 'ticket-create',
      createdByUid: actor.uid,
    });
    expect(audit.data()).toMatchObject({
      action: 'create',
      operation: 'createMaintenanceTicket',
      entityId: 'ticket-create',
    });
    expect(receipt.data()).toMatchObject({
      commandType: 'createMaintenanceTicket',
      aggregateVersion: 1,
    });

    await directive.ref.delete();
    await expect(service.execute(command, {
      actor,
      serverNow: new Date('2026-08-14T17:02:00.000Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-create-replay-directive-invalid'},
    });
  });

  test('ticket acknowledgement commits ticket, audit, and receipt atomically', async () => {
    await db.collection('maintenance_records').doc('ticket-ack').set({
      firestoreId: 'ticket-ack',
      version: 2,
      assetType: 'furnace',
      assetNumber: 4,
      maintenanceType: 'breakdown',
      description: 'Burner flame signal is intermittent',
      routedTo: 'electrical',
      status: 'open',
      isResolved: false,
      isCritical: true,
      workflowDeferred: false,
      isDeleted: false,
    });
    const command = {
      commandId: 'ticket-ack-command',
      commandType: 'acknowledgeMaintenanceTicket',
      aggregateId: 'ticket-ack',
      expectedVersion: 2,
      payload: {},
    };
    const first = await service.execute(command, {
      actor,
      serverNow: new Date('2026-08-14T17:00:00.000Z'),
    });
    const replay = await service.execute(command, {
      actor,
      serverNow: new Date('2026-08-14T17:01:00.000Z'),
    });

    expect(replay).toEqual(first);
    const [ticket, audit, receipt] = await Promise.all([
      db.collection('maintenance_records').doc('ticket-ack').get(),
      db.collection('audit_logs')
        .doc('server_maintenance_ticket_ticket-ack-command').get(),
      db.collection('maintenance_workflow_command_receipts')
        .doc('ticket-ack-command').get(),
    ]);
    expect(ticket.data()).toMatchObject({
      status: 'acknowledged',
      acknowledgedByUid: actor.uid,
      version: 3,
    });
    expect(ticket.data().acknowledgedAt).toBeInstanceOf(
      admin.firestore.Timestamp,
    );
    expect(audit.data()).toMatchObject({
      operation: 'acknowledgeMaintenanceTicket',
      entityId: 'ticket-ack',
      performedByUid: actor.uid,
      resultVersion: 3,
    });
    expect(receipt.data()).toMatchObject({
      commandType: 'acknowledgeMaintenanceTicket',
      aggregateVersion: 3,
    });

    await audit.ref.delete();
    await expect(service.execute(command, {
      actor,
      serverNow: new Date('2026-08-14T17:02:00.000Z'),
    })).rejects.toMatchObject({
      code: 'failed-precondition',
      details: {reasonCode: 'maintenance-ticket-replay-audit-invalid'},
    });
  });
});
