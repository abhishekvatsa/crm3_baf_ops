const admin = require('firebase-admin');

const {
  completePlannedJobWithDb,
} = require('../lib/plannedJobClosure');

jest.setTimeout(30000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;

const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  'crm3-baf-ops-b8638';

const appName = `closure-emulator-${process.pid}-${Date.now()}`;

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function deferred() {
  let resolve;
  const promise = new Promise((resolver) => {
    resolve = resolver;
  });
  return {promise, resolve};
}

function baseExecution(executionId, overrides = {}) {
  return {
    firestoreId: executionId,
    assetType: 'base',
    assetNumber: 209,
    isDeleted: false,
    isCompleted: false,
    version: 6,
    modulePopulationVersion: 1,
    modulePopulationSchemaVersion: 1,
    metadataJson: '{}',
    createdAt: '2026-06-21T00:00:00.000Z',
    updatedAt: '2026-06-21T00:00:00.000Z',
    ...overrides,
  };
}

function baseModule(executionId, overrides = {}) {
  return {
    firestoreId: `module_${executionId}`,
    jobExecutionFirestoreId: executionId,
    templateModuleId: 'seed:B-02',
    moduleCode: 'B-02',
    moduleTitle: 'Base Hydraulic Clamping System',
    version: 4,
    status: 'accepted',
    requiredForClosure: true,
    isRequired: true,
    isDeleted: false,
    requiresFollowUp: false,
    pendingIssue: null,
    fieldDefinitionsJson: JSON.stringify([
      {
        key: 'observation',
        type: 'text',
        isRequired: true,
      },
    ]),
    responsesJson: JSON.stringify([
      {
        key: 'observation',
        value: 'verified',
      },
    ]),
    ...overrides,
  };
}

function burnerBlockReplacementAction() {
  return {
    schemaVersion: 1,
    id: 'legacy-burner-block-action-1',
    asset: 'Furnace 7',
    component: 'Burner blocks and firing tubes',
    hierarchyPath: ['Refractory system', 'Burner blocks and firing tubes'],
    assetHierarchyRef: {
      schemaVersion: 4,
      scope: 'componentDefinitionOnAsset',
      assetClassId: 'class-furnace',
      assetClassCode: 'FR',
      assetClassName: 'Furnace',
      nodeId: 'node-burner-block',
      nodeVersion: 2,
      nodeName: 'Burner blocks and firing tubes',
      assetInstanceId: 'asset-furnace-7',
      assetInstanceVersion: 2,
      assetNumber: 7,
      assetInstanceName: 'Furnace 7',
      componentInstanceId: null,
      componentInstanceVersion: null,
      componentTag: null,
      hierarchyPath: ['Refractory system', 'Burner blocks and firing tubes'],
      ownershipStatus: 'confirmed',
      ownerDiscipline: 'RED',
      accountableRoleKeys: ['seniorRefractory'],
      innerCoverAssociation: null,
    },
    system: 'Furnace',
    subsystem: 'Refractory system',
    subComponent: null,
    tag: null,
    instance: null,
    actionType: 'replacement',
    replacement: 'revised',
    issue: 'Burner block required replacement.',
    resolution: null,
    remarks: null,
    templateFieldKey: null,
    isAutoResolved: true,
    status: 'resolved',
    createdAt: '2026-06-21T03:00:00.000Z',
    severity: 'medium',
    performedBy: 'Mechanical Technician',
    updatedAt: null,
    version: 1,
    metadataJson: null,
    attendanceSessionId: null,
    burnerPosition: 4,
    burnerActionCode: null,
    burnerOutcome: null,
    burnerMicroampReading: null,
    burnerBlockSupplyMode: 'purchased',
    burnerBlockSupplierName: 'Industrial Refractories Ltd',
    burnerBlockPurchaseOrderNumber: 'PO-2026-500',
  };
}

function uvDetectorReplacementAction() {
  return {
    schemaVersion: 1,
    id: 'legacy-uv-detector-action-1',
    asset: 'Furnace 7',
    component: 'UV flame scanner and peep sight',
    hierarchyPath: [
      'Burner and flame supervision',
      'UV flame scanner and peep sight',
    ],
    assetHierarchyRef: {
      schemaVersion: 4,
      scope: 'componentDefinitionOnAsset',
      assetClassId: 'class-furnace',
      assetClassCode: 'FR',
      assetClassName: 'Furnace',
      nodeId: 'node-uv-detector',
      nodeVersion: 2,
      nodeName: 'UV flame scanner and peep sight',
      assetInstanceId: 'asset-furnace-7',
      assetInstanceVersion: 2,
      assetNumber: 7,
      assetInstanceName: 'Furnace 7',
      componentInstanceId: null,
      componentInstanceVersion: null,
      componentTag: null,
      hierarchyPath: [
        'Burner and flame supervision',
        'UV flame scanner and peep sight',
      ],
      ownershipStatus: 'confirmed',
      ownerDiscipline: 'Instrumentation & Automation',
      accountableRoleKeys: ['seniorInstrumentation'],
      innerCoverAssociation: null,
    },
    system: 'Furnace',
    subsystem: 'Burner and flame supervision',
    subComponent: null,
    tag: null,
    instance: null,
    actionType: 'replacement',
    replacement: 'newPart',
    issue: 'UV detector was missing.',
    resolution: 'UV detector installed and proved.',
    remarks: null,
    templateFieldKey: null,
    isAutoResolved: true,
    status: 'resolved',
    createdAt: '2026-06-21T03:00:00.000Z',
    severity: 'high',
    performedBy: 'I&A Technician',
    updatedAt: null,
    version: 1,
    metadataJson: null,
    attendanceSessionId: null,
    burnerPosition: 4,
    burnerActionCode: null,
    burnerOutcome: null,
    burnerMicroampReading: null,
    burnerBlockSupplyMode: null,
    burnerBlockSupplierName: null,
    burnerBlockPurchaseOrderNumber: null,
  };
}

describeWithEmulator(
  'completePlannedJobWithDb with a real Firestore emulator transaction',
  () => {
    let app;
    let db;

    async function clearFirestore() {
      const response = await fetch(
        `http://${emulatorHost}/emulator/v1/projects/` +
          `${projectId}/databases/(default)/documents`,
        {method: 'DELETE'},
      );

      if (!response.ok) {
        throw new Error(
          `Unable to clear Firestore emulator: ` +
            `${response.status} ${await response.text()}`,
        );
      }
    }

    async function seedUser(uid, overrides = {}) {
      await db.collection('users').doc(uid).set({
        isApproved: true,
        roles: ['shiftSupervisor'],
        name: 'Shift Supervisor',
        ...overrides,
      });
    }

    async function seedExecution(executionId, overrides = {}) {
      const data = baseExecution(executionId, overrides);
      await db.collection('job_executions').doc(executionId).set(data);
      return data;
    }

    async function seedModule(executionId, overrides = {}) {
      const data = baseModule(executionId, overrides);
      await db.collection('job_modules').doc(data.firestoreId).set(data);
      return data;
    }

    async function captureState(executionId) {
      const executionSnapshot = await db
        .collection('job_executions')
        .doc(executionId)
        .get();

      const modulesSnapshot = await db
        .collection('job_modules')
        .where('jobExecutionFirestoreId', '==', executionId)
        .get();

      const auditsSnapshot = await db
        .collection('audit_logs')
        .where('entityId', '==', executionId)
        .get();

      return {
        execution: executionSnapshot.exists
          ? clone(executionSnapshot.data())
          : null,
        modules: modulesSnapshot.docs
          .map((doc) => ({
            id: doc.id,
            data: clone(doc.data()),
          }))
          .sort((a, b) => a.id.localeCompare(b.id)),
        audits: auditsSnapshot.docs
          .map((doc) => ({
            id: doc.id,
            data: clone(doc.data()),
          }))
          .sort((a, b) => a.id.localeCompare(b.id)),
      };
    }

    beforeAll(async () => {
      app = admin.initializeApp({projectId}, appName);
      db = app.firestore();
      db.settings({ignoreUndefinedProperties: true});
    });

    beforeEach(async () => {
      await clearFirestore();
    });

    afterAll(async () => {
      await db.terminate();
      await app.delete();
    });

    test(
      'stale version rejects with no execution, module, or audit mutation',
      async () => {
        const executionId = 'integration_stale_version';
        const uid = 'supervisor_stale';

        await seedUser(uid);
        await seedExecution(executionId, {version: 6});
        await seedModule(executionId);

        const before = await captureState(executionId);

        await expect(
          completePlannedJobWithDb({
            db,
            authUid: uid,
            data: {
              executionId,
              expectedCompletionVersion: 99,
            },
            timestampFromDate:
              admin.firestore.Timestamp.fromDate,
          }),
        ).rejects.toMatchObject({
          code: 'failed-precondition',
        });

        const after = await captureState(executionId);
        expect(after).toEqual(before);
      },
    );

    test(
      'open required module rejects with no execution, module, or audit mutation',
      async () => {
        const executionId = 'integration_open_required';
        const uid = 'supervisor_open';

        await seedUser(uid);
        await seedExecution(executionId, {version: 6});
        await seedModule(executionId, {status: 'inProgress'});

        const before = await captureState(executionId);

        await expect(
          completePlannedJobWithDb({
            db,
            authUid: uid,
            data: {
              executionId,
              expectedCompletionVersion: 7,
            },
            timestampFromDate:
              admin.firestore.Timestamp.fromDate,
          }),
        ).rejects.toMatchObject({
          code: 'failed-precondition',
          details: {
            issues: expect.arrayContaining([
              expect.objectContaining({
                type: 'openRequiredModule',
              }),
            ]),
          },
        });

        const after = await captureState(executionId);
        expect(after).toEqual(before);
      },
    );

    test(
      'unauthorized role rejects with no execution, module, or audit mutation',
      async () => {
        const executionId = 'integration_unauthorized';
        const uid = 'operations_user';

        await seedUser(uid, {
          roles: ['operations'],
          name: 'Operations User',
        });

        await seedExecution(executionId, {version: 6});
        await seedModule(executionId);

        const before = await captureState(executionId);

        await expect(
          completePlannedJobWithDb({
            db,
            authUid: uid,
            data: {
              executionId,
              expectedCompletionVersion: 7,
            },
            timestampFromDate:
              admin.firestore.Timestamp.fromDate,
          }),
        ).rejects.toMatchObject({
          code: 'permission-denied',
        });

        const after = await captureState(executionId);
        expect(after).toEqual(before);
      },
    );

    test(
      'authority revoked before transaction start fails closed with no business mutation',
      async () => {
        const executionId = 'integration_authority_revoked';
        const uid = 'supervisor_revoked';
        const transactionMayStart = deferred();
        const invocationReachedTransaction = deferred();

        await seedUser(uid);
        await seedExecution(executionId, {version: 6});
        await seedModule(executionId);

        const before = await captureState(executionId);
        const closurePromise = completePlannedJobWithDb({
          db,
          authUid: uid,
          data: {
            executionId,
            expectedCompletionVersion: 7,
          },
          timestampFromDate: admin.firestore.Timestamp.fromDate,
          beforeTransactionForTest: async () => {
            invocationReachedTransaction.resolve();
            await transactionMayStart.promise;
          },
        });

        await invocationReachedTransaction.promise;
        await db.collection('users').doc(uid).update({
          isApproved: false,
          roles: [],
        });
        transactionMayStart.resolve();

        await expect(closurePromise).rejects.toMatchObject({
          code: 'permission-denied',
          details: {reasonCode: 'closure-authority-denied'},
        });

        const after = await captureState(executionId);
        expect(after).toEqual(before);
      },
    );

    test(
      'successful closure binds attestation to the current module-population version',
      async () => {
        const executionId = 'integration_population_attestation';
        const uid = 'supervisor_population';

        await seedUser(uid);
        await seedExecution(executionId, {
          version: 6,
          modulePopulationVersion: 4,
        });
        await seedModule(executionId);

        const result = await completePlannedJobWithDb({
          db,
          authUid: uid,
          data: {
            executionId,
            expectedCompletionVersion: 7,
          },
          timestampFromDate: admin.firestore.Timestamp.fromDate,
        });

        expect(result).toMatchObject({
          ok: true,
          alreadyCompleted: false,
          executionId,
          version: 7,
        });

        const after = await captureState(executionId);
        expect(after.execution.isCompleted).toBe(true);
        expect(after.execution.modulePopulationVersion).toBe(4);
        expect(after.execution.modulePopulationSchemaVersion).toBe(1);

        const metadata = JSON.parse(after.execution.metadataJson);
        expect(metadata.closureAttestation.schemaVersion).toBe(2);
        const canonical = JSON.parse(
          metadata.closureAttestation.canonicalJson,
        );
        expect(canonical.modulePopulationVersionAtCompletion).toBe(4);
        expect(after.audits).toHaveLength(1);
      },
    );

    test(
      'legacy planned-job module replacement creates burner-block lifecycle evidence',
      async () => {
        const executionId = 'integration_burner_block_lifecycle';
        const uid = 'supervisor_burner_block';

        await seedUser(uid);
        await db.collection('asset_classes').doc('class-furnace').set({
          schemaVersion: 1,
          assetClassId: 'class-furnace',
          code: 'FR',
          name: 'Furnace',
          legacyAssetTypeKey: 'furnace',
          status: 'active',
        });
        await db.collection('asset_instances').doc('asset-furnace-7').set({
          schemaVersion: 1,
          assetInstanceId: 'asset-furnace-7',
          assetClassId: 'class-furnace',
          assetClassCode: 'FR',
          assetClassName: 'Furnace',
          assetNumber: 7,
          name: 'Furnace 7',
          status: 'active',
          version: 2,
        });
        await db.collection('asset_hierarchy_nodes').doc('node-burner-block').set({
          schemaVersion: 1,
          nodeId: 'node-burner-block',
          assetClassId: 'class-furnace',
          name: 'Burner blocks and firing tubes',
          hierarchyPath: ['Refractory system', 'Burner blocks and firing tubes'],
          nodeType: 'component',
          status: 'active',
          version: 2,
        });
        await seedExecution(executionId, {
          assetType: 'furnace',
          assetNumber: 7,
          version: 6,
        });
        await seedModule(executionId, {
          discipline: 'mechanical',
          actionsJson: JSON.stringify([burnerBlockReplacementAction()]),
        });

        await completePlannedJobWithDb({
          db,
          authUid: uid,
          data: {
            executionId,
            expectedCompletionVersion: 7,
            teamsInvolved: ['mechanical'],
          },
          timestampFromDate: admin.firestore.Timestamp.fromDate,
        });

        const lifecycle = await db
          .collection('burner_block_lifecycle_events')
          .where('sourceId', '==', executionId)
          .get();
        const current = await db
          .collection('burner_block_lifecycle_current')
          .where('sourceId', '==', executionId)
          .get();
        expect(lifecycle.docs).toHaveLength(1);
        expect(current.docs).toHaveLength(1);
        expect(lifecycle.docs[0].data()).toMatchObject({
          burnerPosition: 4,
          supplyMode: 'purchased',
          supplierName: 'Industrial Refractories Ltd',
          purchaseOrderNumber: 'PO-2026-500',
          sourceType: 'legacyPlannedJob',
          sourceModuleId: `module_${executionId}`,
          installationDiscipline: 'mechanical',
          performedByName: 'Mechanical Technician',
        });
        expect(current.docs[0].data()).toMatchObject({
          currentEventId: lifecycle.docs[0].id,
          eventId: lifecycle.docs[0].id,
          burnerPosition: 4,
        });
      },
    );

    test(
      'legacy planned-job module replacement creates UV lifecycle evidence',
      async () => {
        const executionId = 'integration_uv_detector_lifecycle';
        const uid = 'supervisor_uv_detector';

        await seedUser(uid);
        await db.collection('asset_classes').doc('class-furnace').set({
          schemaVersion: 1,
          assetClassId: 'class-furnace',
          code: 'FR',
          name: 'Furnace',
          legacyAssetTypeKey: 'furnace',
          status: 'active',
        });
        await db.collection('asset_instances').doc('asset-furnace-7').set({
          schemaVersion: 1,
          assetInstanceId: 'asset-furnace-7',
          assetClassId: 'class-furnace',
          assetClassCode: 'FR',
          assetClassName: 'Furnace',
          assetNumber: 7,
          name: 'Furnace 7',
          status: 'active',
          version: 2,
        });
        await db.collection('asset_hierarchy_nodes').doc('node-uv-detector').set({
          schemaVersion: 1,
          nodeId: 'node-uv-detector',
          assetClassId: 'class-furnace',
          name: 'UV flame scanner and peep sight',
          hierarchyPath: [
            'Burner and flame supervision',
            'UV flame scanner and peep sight',
          ],
          nodeType: 'component',
          status: 'active',
          version: 2,
        });
        await seedExecution(executionId, {
          assetType: 'furnace',
          assetNumber: 7,
          version: 6,
        });
        await seedModule(executionId, {
          discipline: 'instrumentation',
          actionsJson: JSON.stringify([uvDetectorReplacementAction()]),
        });

        await completePlannedJobWithDb({
          db,
          authUid: uid,
          data: {
            executionId,
            expectedCompletionVersion: 7,
            teamsInvolved: ['instrumentation'],
          },
          timestampFromDate: admin.firestore.Timestamp.fromDate,
        });

        const lifecycle = await db
          .collection('uv_detector_lifecycle_events')
          .where('sourceId', '==', executionId)
          .get();
        const current = await db
          .collection('uv_detector_lifecycle_current')
          .where('sourceId', '==', executionId)
          .get();
        expect(lifecycle.docs).toHaveLength(1);
        expect(current.docs).toHaveLength(1);
        expect(lifecycle.docs[0].data()).toMatchObject({
          burnerPosition: 4,
          replacementDisposition: 'newPart',
          sourceType: 'legacyPlannedJob',
          sourceModuleId: `module_${executionId}`,
          installationDiscipline: 'instrumentation',
          performedByName: 'I&A Technician',
          resultingCondition: 'serviceable',
        });
        expect(current.docs[0].data()).toMatchObject({
          currentEventId: lifecycle.docs[0].id,
          eventId: lifecycle.docs[0].id,
          burnerPosition: 4,
          resultingCondition: 'serviceable',
        });
      },
    );

    test(
      'already-completed retry returns existing attestation and creates no mutation',
      async () => {
        const executionId = 'integration_idempotent_retry';
        const uid = 'supervisor_retry';
        const existingHash = 'existing_attestation_hash';

        await seedUser(uid);

        await seedExecution(executionId, {
          isCompleted: true,
          version: 7,
          completedAt: '2026-06-21T04:37:12.313Z',
          completedByUid: uid,
          completedByName: 'Shift Supervisor',
          metadataJson: JSON.stringify({
            closureAttestation: {
              schemaVersion: 1,
              hash: existingHash,
              canonicalJson: '{"existing":true}',
            },
          }),
        });

        // Deliberately invalid if evaluated. A correct idempotent path
        // returns before the canonical module query and closure guard.
        await seedModule(executionId, {
          status: 'inProgress',
          responsesJson: '[]',
        });

        const auditId =
          `server_closure_${executionId}_7`;

        await db.collection('audit_logs').doc(auditId).set({
          entityType: 'execution',
          entityId: executionId,
          action: 'resolve',
          timestamp:
            admin.firestore.Timestamp.fromDate(
              new Date('2026-06-21T04:37:12.313Z'),
            ),
          summary: 'existing closure audit',
          marker: 'must remain unchanged',
        });

        const before = await captureState(executionId);

        const result = await completePlannedJobWithDb({
          db,
          authUid: uid,
          data: {
            executionId,
            expectedCompletionVersion: 99,
          },
          timestampFromDate:
            admin.firestore.Timestamp.fromDate,
        });

        expect(result).toMatchObject({
          ok: true,
          alreadyCompleted: true,
          executionId,
          version: 7,
          closureAttestationHash: existingHash,
        });

        const after = await captureState(executionId);

        expect(after).toEqual(before);
        expect(after.audits).toHaveLength(1);
        expect(after.audits[0].id).toBe(auditId);
        expect(after.audits[0].data.marker)
          .toBe('must remain unchanged');
      },
    );
  },
);
