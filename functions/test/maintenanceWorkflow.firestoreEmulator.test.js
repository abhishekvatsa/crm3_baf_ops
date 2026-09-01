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
      db.collection('abnormality_types').doc('ATMOSPHERE_DEVIATION').set({
        firestoreId: 'ATMOSPHERE_DEVIATION',
        code: 'ATMOSPHERE_DEVIATION',
        title: 'Atmosphere deviation',
        category: 'process',
        severity: 'high',
        applicableAssetTypes: ['furnace'],
        suggestsReannealing: true,
        isActive: true,
        isDeleted: false,
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
          chargeNoAtEvent: 12345,
          qualityIntentSchemaVersion: 2,
          qualityImpactAssessment: 'suspected',
          qualityWarningReason:
            'Burner instability may have affected temperature uniformity.',
          qualityAbnormalityTypeId: 'ATMOSPHERE_DEVIATION',
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
        abnormalityId: 'issue_quality_ticket-create',
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

  test('administrative issue closure atomically cancels active Operations coordination', async () => {
    await Promise.all([
      db.collection('maintenance_records').doc('ticket-admin-close').set({
        firestoreId: 'ticket-admin-close',
        version: 4,
        assetType: 'base',
        assetNumber: 201,
        maintenanceType: 'breakdown',
        description: 'Temporary operating context ended before repair.',
        routedTo: 'mechanical',
        status: 'acknowledged',
        isResolved: false,
        isCritical: false,
        startDate: admin.firestore.Timestamp.fromDate(
          new Date('2026-08-14T14:00:00.000Z'),
        ),
        issueLaneSchemaVersion: 1,
        issueLaneRevision: 2,
        issueAssignedLanes: ['mechanical'],
        issueAcknowledgedLanes: ['mechanical'],
        issueCompletedLanes: [],
        acknowledgedByUid: 'mechanical1',
        acknowledgedByName: 'Mechanical Supervisor',
        acknowledgedAt: admin.firestore.Timestamp.fromDate(
          new Date('2026-08-14T14:30:00.000Z'),
        ),
        workflowDeferred: true,
        workflowQueueState: 'deferred',
        workflowAggregateId: 'issue-workflow-admin-close',
        workflowComplianceId: 'issue-compliance-admin-close',
        workflowOriginLaneKey: 'mech',
        workflowTargetLaneKey: 'oprn',
        workflowConditionTypeKey: 'manual',
        workflowUpdatedAt: admin.firestore.Timestamp.fromDate(
          new Date('2026-08-14T15:00:00.000Z'),
        ),
        isDeleted: false,
      }),
      db.collection('maintenance_workflows')
        .doc('issue-workflow-admin-close').set({
          workflowSchemaVersion: 1,
          workflowKind: 'issueCoordination',
          linkedMaintenanceFirestoreId: 'ticket-admin-close',
          status: 'awaitingCompliance',
          cancelled: false,
          version: 2,
        }),
      db.collection('compliance_requests')
        .doc('issue-compliance-admin-close').set({
          linkedWorkflowId: 'issue-workflow-admin-close',
          linkedMaintenanceFirestoreId: 'ticket-admin-close',
          status: 'raised',
          version: 3,
        }),
    ]);
    const command = {
      commandId: 'ticket-admin-close-command',
      commandType: 'closeMaintenanceTicketWithoutResolution',
      aggregateId: 'ticket-admin-close',
      expectedVersion: 4,
      payload: {
        disposition: 'stillRelevant',
        reason:
          'The operating cycle ended, while the unresolved concern remains relevant for engineering review.',
      },
    };
    const first = await service.execute(command, {
      actor,
      serverNow: new Date('2026-08-14T16:00:00.000Z'),
    });
    const replay = await service.execute(command, {
      actor,
      serverNow: new Date('2026-08-14T16:01:00.000Z'),
    });

    expect(replay).toEqual(first);
    expect(first).toMatchObject({
      resultKey: 'maintenance-ticket-closed-without-resolution',
      aggregateVersion: 5,
      result: {
        ticketId: 'ticket-admin-close',
        disposition: 'stillRelevant',
        cancelledCoordination: true,
        cancelledWorkflowId: 'issue-workflow-admin-close',
        cancelledComplianceId: 'issue-compliance-admin-close',
      },
    });
    const [ticket, workflow, compliance, audit, event, receipt] =
      await Promise.all([
        db.collection('maintenance_records').doc('ticket-admin-close').get(),
        db.collection('maintenance_workflows')
          .doc('issue-workflow-admin-close').get(),
        db.collection('compliance_requests')
          .doc('issue-compliance-admin-close').get(),
        db.collection('audit_logs')
          .doc('server_maintenance_ticket_ticket-admin-close-command').get(),
        db.collection('maintenance_workflow_events')
          .doc('ticket-admin-close-command').get(),
        db.collection('maintenance_workflow_command_receipts')
          .doc('ticket-admin-close-command').get(),
      ]);

    expect(ticket.data()).toMatchObject({
      status: 'closedWithoutResolution',
      isResolved: true,
      closedByUid: actor.uid,
      issueClosureSchemaVersion: 1,
      issueClosureDisposition: 'stillRelevant',
      issueClosureReason:
        'The operating cycle ended, while the unresolved concern remains relevant for engineering review.',
      issueAssignedLanes: ['mechanical'],
      issueAcknowledgedLanes: ['mechanical'],
      issueCompletedLanes: [],
      workflowDeferred: false,
      workflowQueueState: 'released',
      version: 5,
    });
    expect(ticket.data().endDate).toBe('2026-08-14T16:00:00.000Z');
    expect(ticket.data().workflowReleasedAt).toBeInstanceOf(
      admin.firestore.Timestamp,
    );
    expect(workflow.data()).toMatchObject({
      status: 'cancelled',
      cancelled: true,
      cancelledByUid: actor.uid,
      version: 3,
    });
    expect(compliance.data()).toMatchObject({
      status: 'cancelled',
      cancelledByUid: actor.uid,
      version: 4,
    });
    expect(audit.data()).toMatchObject({
      operation: 'closeMaintenanceTicketWithoutResolution',
      entityId: 'ticket-admin-close',
      performedByUid: actor.uid,
      resultVersion: 5,
    });
    expect(event.data()).toMatchObject({
      eventType: 'issue.closedWithoutResolution',
      aggregateId: 'issue-workflow-admin-close',
      actorUid: actor.uid,
    });
    expect(receipt.data()).toMatchObject({
      commandType: 'closeMaintenanceTicketWithoutResolution',
      aggregateVersion: 5,
      actorUid: actor.uid,
    });

    const relevanceCommand = {
      commandId: 'ticket-admin-end-relevance-command',
      commandType: 'closeMaintenanceTicketWithoutResolution',
      aggregateId: 'ticket-admin-close',
      expectedVersion: 5,
      payload: {
        disposition: 'relevanceEnded',
        reason: 'The retained operating concern has now ended.',
      },
    };
    const relevanceReceipt = await service.execute(relevanceCommand, {
      actor,
      serverNow: new Date('2026-08-15T08:00:00.000Z'),
    });
    await expect(service.execute(relevanceCommand, {
      actor,
      serverNow: new Date('2026-08-15T08:01:00.000Z'),
    })).resolves.toEqual(relevanceReceipt);

    const relevanceEnded = await db.collection('maintenance_records')
      .doc('ticket-admin-close').get();
    expect(relevanceReceipt).toMatchObject({
      aggregateVersion: 6,
      result: {
        disposition: 'relevanceEnded',
        relevanceTransition: true,
        cancelledCoordination: false,
      },
    });
    expect(relevanceEnded.data()).toMatchObject({
      closedByUid: actor.uid,
      issueClosureReason:
        'The operating cycle ended, while the unresolved concern remains relevant for engineering review.',
      issueClosureDisposition: 'relevanceEnded',
      issueClosureRelevanceEndedByUid: actor.uid,
      issueClosureRelevanceEndedByName: actor.name,
      issueClosureRelevanceEndReason:
        'The retained operating concern has now ended.',
      version: 6,
    });
  });

  test('critical alarm lifecycle and replay commit as one Firestore transaction', async () => {
    const raise = {
      commandId: 'critical-fire-raise',
      commandType: 'raiseCriticalAlarm',
      aggregateId: 'critical-fire-1',
      expectedVersion: 0,
      payload: {
        alarmTypeKey: 'fire',
        location: 'Annealing shop north bay',
        assetTypeKey: 'furnace',
        assetNumber: 7,
        initialDetails: 'Visible flame reported beside Furnace 07.',
      },
    };
    const first = await service.execute(raise, {
      actor,
      serverNow: new Date('2026-08-26T08:00:00.000Z'),
    });
    const replay = await service.execute(raise, {
      actor,
      serverNow: new Date('2026-08-26T08:01:00.000Z'),
    });
    expect(replay).toEqual(first);

    await service.execute({
      commandId: 'critical-fire-support',
      commandType: 'confirmCriticalAlarmSupport',
      aggregateId: 'critical-fire-1',
      expectedVersion: 1,
      payload: {
        basis: 'supportDispatched',
        responderNote: 'Fire response support dispatched to the north bay.',
        details: null,
      },
    }, {
      actor,
      serverNow: new Date('2026-08-26T08:02:00.000Z'),
    });
    await service.execute({
      commandId: 'critical-fire-resolve',
      commandType: 'resolveCriticalAlarm',
      aggregateId: 'critical-fire-1',
      expectedVersion: 2,
      payload: {
        resolutionSummary: 'Area isolated and Fire and Safety confirmed safe state.',
      },
    }, {
      actor,
      serverNow: new Date('2026-08-26T08:05:00.000Z'),
    });

    const [alarm, raiseAudit, raiseEvent, raiseReceipt] = await Promise.all([
      db.collection('critical_alarms').doc('critical-fire-1').get(),
      db.collection('critical_alarm_audits').doc('critical-fire-raise').get(),
      db.collection('maintenance_workflow_events').doc('critical-fire-raise').get(),
      db.collection('maintenance_workflow_command_receipts')
        .doc('critical-fire-raise').get(),
    ]);
    expect(alarm.data()).toMatchObject({
      alarmTypeKey: 'fire',
      criticalityKey: 'highest',
      status: 'resolved',
      version: 3,
      assetTypeKey: 'furnace',
      assetNumber: 7,
    });
    expect(raiseAudit.data()).toMatchObject({
      operation: 'raise',
      aggregateId: 'critical-fire-1',
      performedByUid: actor.uid,
    });
    expect(raiseEvent.data()).toMatchObject({
      eventType: 'criticalAlarm.raised',
      aggregateId: 'critical-fire-1',
      actorUid: actor.uid,
    });
    expect(raiseReceipt.data()).toMatchObject({
      commandType: 'raiseCriticalAlarm',
      aggregateVersion: 1,
    });
  });

  test('critical alarm detail, withdrawal, and contact lifecycles survive Firestore timestamp decoding', async () => {
    const raise = {
      commandId: 'critical-nitrogen-raise',
      commandType: 'raiseCriticalAlarm',
      aggregateId: 'critical-nitrogen-1',
      expectedVersion: 0,
      payload: {
        alarmTypeKey: 'nitrogenFailure',
        location: 'Nitrogen header beside Base 201',
        assetTypeKey: 'base',
        assetNumber: 201,
        initialDetails: null,
      },
    };
    await service.execute(raise, {
      actor,
      serverNow: new Date('2026-08-26T09:00:00.000Z'),
    });
    const details = {
      commandId: 'critical-nitrogen-details',
      commandType: 'provideCriticalAlarmDetails',
      aggregateId: 'critical-nitrogen-1',
      expectedVersion: 1,
      payload: {
        details: 'Nitrogen header pressure fell below the operating limit.',
      },
    };
    const firstDetails = await service.execute(details, {
      actor,
      serverNow: new Date('2026-08-26T09:01:00.000Z'),
    });
    expect(await service.execute(details, {
      actor,
      serverNow: new Date('2026-08-26T09:02:00.000Z'),
    })).toEqual(firstDetails);

    const withdraw = {
      commandId: 'critical-nitrogen-withdraw',
      commandType: 'withdrawCriticalAlarmInError',
      aggregateId: 'critical-nitrogen-1',
      expectedVersion: 2,
      payload: {reason: 'Instrument calibration error confirmed at the header.'},
    };
    const firstWithdrawal = await service.execute(withdraw, {
      actor,
      serverNow: new Date('2026-08-26T09:03:00.000Z'),
    });
    expect(await service.execute(withdraw, {
      actor,
      serverNow: new Date('2026-08-26T09:04:00.000Z'),
    })).toEqual(firstWithdrawal);

    const createContact = {
      commandId: 'critical-contact-create',
      commandType: 'upsertCriticalAlarmContact',
      aggregateId: 'nitrogen-control-room',
      expectedVersion: 0,
      payload: {
        contact: {
          schemaVersion: 1,
          label: 'Nitrogen control room',
          contactKind: 'plantExtension',
          dialValue: '4210',
          alarmTypeKeys: ['nitrogenFailure'],
          priority: 1,
          notes: null,
        },
        reason: 'Initial governed nitrogen contact',
      },
    };
    const firstContact = await service.execute(createContact, {
      actor,
      serverNow: new Date('2026-08-26T09:05:00.000Z'),
    });
    expect(await service.execute(createContact, {
      actor,
      serverNow: new Date('2026-08-26T09:06:00.000Z'),
    })).toEqual(firstContact);

    const updateContact = {
      commandId: 'critical-contact-update',
      commandType: 'upsertCriticalAlarmContact',
      aggregateId: 'nitrogen-control-room',
      expectedVersion: 1,
      payload: {
        contact: {
          schemaVersion: 1,
          label: 'Nitrogen emergency desk',
          contactKind: 'plantExtension',
          dialValue: '4211',
          alarmTypeKeys: ['nitrogenFailure'],
          priority: 1,
          notes: 'Primary nitrogen-failure contact.',
        },
        reason: 'Verified emergency desk extension',
      },
    };
    const firstUpdate = await service.execute(updateContact, {
      actor,
      serverNow: new Date('2026-08-26T09:07:00.000Z'),
    });
    expect(await service.execute(updateContact, {
      actor,
      serverNow: new Date('2026-08-26T09:08:00.000Z'),
    })).toEqual(firstUpdate);

    const retire = {
      commandId: 'critical-contact-retire',
      commandType: 'setCriticalAlarmContactStatus',
      aggregateId: 'nitrogen-control-room',
      expectedVersion: 2,
      payload: {status: 'retired', reason: 'Extension temporarily unavailable'},
    };
    const firstRetire = await service.execute(retire, {
      actor,
      serverNow: new Date('2026-08-26T09:09:00.000Z'),
    });
    expect(await service.execute(retire, {
      actor,
      serverNow: new Date('2026-08-26T09:10:00.000Z'),
    })).toEqual(firstRetire);

    const [alarm, contact, detailAudit, contactAudit] = await Promise.all([
      db.collection('critical_alarms').doc('critical-nitrogen-1').get(),
      db.collection('critical_alarm_contacts').doc('nitrogen-control-room').get(),
      db.collection('critical_alarm_audits').doc('critical-nitrogen-details').get(),
      db.collection('critical_alarm_contact_audits').doc('critical-contact-update').get(),
    ]);
    expect(alarm.data()).toMatchObject({
      status: 'withdrawnInError',
      detailsPending: false,
      version: 3,
    });
    expect(alarm.data().detailsProvidedAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(contact.data()).toMatchObject({
      status: 'retired',
      version: 3,
      dialValue: '4211',
    });
    expect(contact.data().createdAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(detailAudit.data().performedAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(contactAudit.data().performedAt).toBeInstanceOf(admin.firestore.Timestamp);
  });

  test('completed maintenance classification correction consumes native Firestore timestamps', async () => {
    await Promise.all([
      db.collection('asset_classes').doc('class-furnace').set({
        schemaVersion: 1,
        assetClassId: 'class-furnace',
        status: 'active',
        legacyAssetTypeKey: 'furnace',
      }),
      db.collection('asset_instances').doc('furnace-7').set({
        schemaVersion: 1,
        assetInstanceId: 'furnace-7',
        assetClassId: 'class-furnace',
        assetNumber: 7,
        name: 'Furnace 07',
        version: 3,
        status: 'active',
        isDeleted: false,
      }),
      db.collection('job_executions').doc('classified-execution-7').set({
        firestoreId: 'classified-execution-7',
        assetType: 'furnace',
        assetNumber: 7,
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-7',
        assetInstanceVersion: 3,
        assetInstanceName: 'Furnace 07',
        workflowSchemaVersion: 1,
        isCompleted: true,
        isCancelled: false,
        isDeleted: false,
        completedAt: admin.firestore.Timestamp.fromDate(
          new Date('2026-08-01T04:00:00.000Z'),
        ),
        completedByUid: actor.uid,
        completedByName: actor.name,
        metadataJson: '{}',
        version: 3,
      }),
    ]);
    const classDefinition = (resetCounters, title) => ({
      schemaVersion: 1,
      code: 'FURNACE_MID',
      title,
      description: 'Governed Furnace maintenance classification.',
      assetTypeKeys: ['furnace'],
      assetClassIds: [],
      principalLaneKey: 'mech',
      resetCounters,
    });
    await service.execute({
      commandId: 'native-class-create',
      commandType: 'upsertMaintenanceClassDefinition',
      aggregateId: 'native-class-furnace-mid',
      expectedVersion: 0,
      payload: {
        definition: classDefinition([
          {
            key: 'FURNACE_ANY',
            label: 'Furnace any maintenance',
            thresholdDays: 30,
          },
          {
            key: 'FURNACE_MID',
            label: 'Furnace Mid maintenance',
            thresholdDays: null,
          },
        ], 'Furnace Mid Maintenance'),
        reason: 'Create native timestamp classification test policy.',
      },
    }, {actor, serverNow: new Date('2026-08-26T10:00:00.000Z')});

    const classify = (commandId, expectedVersion, definitionVersion) => ({
      commandId,
      commandType: 'classifyMaintenanceExecution',
      aggregateId: 'classified-execution-7',
      expectedVersion,
      payload: {
        definitionId: 'native-class-furnace-mid',
        definitionVersion,
        reason: 'Classify completed work using governed maintenance scope.',
      },
    });
    await service.execute(classify('native-classify-1', 3, 1), {
      actor,
      serverNow: new Date('2026-08-26T10:01:00.000Z'),
    });
    await service.execute({
      commandId: 'native-class-update',
      commandType: 'upsertMaintenanceClassDefinition',
      aggregateId: 'native-class-furnace-mid',
      expectedVersion: 1,
      payload: {
        definition: classDefinition([
          {
            key: 'FURNACE_ANY',
            label: 'Furnace any maintenance',
            thresholdDays: 30,
          },
        ], 'Furnace General Maintenance'),
        reason: 'Remove the retired Mid counter from this classification.',
      },
    }, {actor, serverNow: new Date('2026-08-26T10:02:00.000Z')});
    await service.execute(classify('native-classify-2', 4, 2), {
      actor,
      serverNow: new Date('2026-08-26T10:03:00.000Z'),
    });

    const sources = await db.collection('maintenance_completion_sources').get();
    expect(sources.size).toBe(1);
    expect(sources.docs[0].data().completedAt).toBeInstanceOf(
      admin.firestore.Timestamp,
    );
    const dueStates = await db.collection('maintenance_due_states').get();
    const byCounter = Object.fromEntries(
      dueStates.docs.map((doc) => [doc.data().counterKey, doc.data()]),
    );
    expect(byCounter.FURNACE_ANY).toMatchObject({
      classificationPending: false,
      lastMaintenanceClassCode: 'FURNACE_MID',
    });
    expect(byCounter.FURNACE_ANY.lastCompletionAt).toBeInstanceOf(
      admin.firestore.Timestamp,
    );
    expect(byCounter.FURNACE_MID).toMatchObject({
      classificationPending: true,
      lastCompletionAt: null,
      nextDueAt: null,
    });
  });
});
