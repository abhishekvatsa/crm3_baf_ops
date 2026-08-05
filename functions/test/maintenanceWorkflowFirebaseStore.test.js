const admin = require('firebase-admin');
const initializedForThisTest = admin.apps.length === 0;
if (initializedForThisTest) admin.initializeApp({projectId: 'demo-crm3-v42'});
afterAll(async () => {
  if (initializedForThisTest && admin.apps.length > 0) await admin.app().delete();
});
const {
  workflowFirestoreDataForTest,
} = require('../lib/maintenanceWorkflow/firebaseStore');
const {
  maintenanceProjectionForAwaitingConfirmation,
  maintenanceProjectionForCorrection,
} = require('../lib/maintenanceWorkflow/maintenanceBridge');
const {
  equipmentProjectionWrite,
} = require('../lib/maintenanceWorkflow/equipmentFacts');

describe('maintenance workflow Firestore persistence adapter', () => {
  test('converts all lifecycle deadline fields from ISO instants to Timestamp', () => {
    const iso = '2026-07-21T12:34:56.789Z';
    const converted = workflowFirestoreDataForTest({
      nextEscalationAt: iso,
      acknowledgementDueAt: iso,
      complianceDueAt: iso,
      raisedAt: iso,
      updatedAt: iso,
      nested: {lastEscalatedAt: iso},
    });

    for (const value of [
      converted.nextEscalationAt,
      converted.acknowledgementDueAt,
      converted.complianceDueAt,
      converted.raisedAt,
      converted.updatedAt,
      converted.nested.lastEscalatedAt,
    ]) {
      expect(value).toBeInstanceOf(admin.firestore.Timestamp);
      expect(value.toDate().toISOString()).toBe(iso);
    }
  });

  test('does not coerce non-timestamp fields or the receipt appliedAt string', () => {
    const iso = '2026-07-21T12:34:56.789Z';
    const converted = workflowFirestoreDataForTest({
      title: iso,
      appliedAt: iso,
      payload: {conditionRef: iso},
    });

    expect(converted.title).toBe(iso);
    expect(converted.appliedAt).toBe(iso);
    expect(converted.payload.conditionRef).toBe(iso);
  });

  test('preserves native Firestore values instead of recursively flattening them', () => {
    const timestamp = admin.firestore.Timestamp.fromDate(new Date('2026-07-21T12:34:56.789Z'));
    const geoPoint = new admin.firestore.GeoPoint(23.6693, 86.1511);
    const fieldValue = admin.firestore.FieldValue.serverTimestamp();
    const bytes = Buffer.from('crm3-v4.2');
    const reference = admin.firestore().doc('maintenance_records/m-native');

    const converted = workflowFirestoreDataForTest({
      timestamp,
      nested: {timestamp, geoPoint, fieldValue, bytes, reference},
    });

    expect(converted.timestamp).toBe(timestamp);
    expect(converted.nested.timestamp).toBe(timestamp);
    expect(converted.nested.geoPoint).toBe(geoPoint);
    expect(converted.nested.fieldValue).toBe(fieldValue);
    expect(converted.nested.bytes).toBe(bytes);
    expect(converted.nested.reference).toBe(reference);
  });

  test('maintenance awaiting-confirmation path preserves an existing native reactivation time', () => {
    const existing = admin.firestore.Timestamp.fromDate(new Date('2026-07-20T01:02:03.004Z'));
    const projection = maintenanceProjectionForAwaitingConfirmation({
      maintenance: {
        version: 5,
        workflowReactivatedAt: existing,
        workflowReactivatedByUid: 'ops-1',
        workflowReactivatedByName: 'Operations',
      },
      actorUid: 'elec-1',
      actorName: 'Electrical',
      at: new Date('2026-07-21T02:00:00.000Z'),
    });

    const converted = workflowFirestoreDataForTest(projection);
    expect(converted.workflowReactivatedAt).toBe(existing);
    expect(converted.workflowUpdatedAt).toBeInstanceOf(admin.firestore.Timestamp);
  });

  test('equipment projection preserves inServiceSince while converting new transition times', () => {
    const existing = admin.firestore.Timestamp.fromDate(new Date('2026-07-19T00:00:00.000Z'));
    const at = '2026-07-21T03:00:00.000Z';
    const projection = equipmentProjectionWrite(
      {state: 'inService', inServiceSince: existing, version: 7},
      {activeNonRedMaintenanceCount: 0, activeRedWorkCount: 0, awaitingPreparationCount: 0},
      {state: 'inService', conflicts: [], counts: {}},
      {assetTypeKey: 'furnace', assetNumber: 7, trigger: 'reconcile', at, actorUid: 'admin-1', actorName: 'Admin'},
    );

    const converted = workflowFirestoreDataForTest(projection);
    expect(converted.inServiceSince).toBe(existing);
    expect(converted.lastTransitionAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(converted.updatedAt).toBeInstanceOf(admin.firestore.Timestamp);
  });

  test('counter-condition successor spread preserves inherited native timestamps', () => {
    const inherited = admin.firestore.Timestamp.fromDate(new Date('2026-07-18T05:00:00.000Z'));
    const successor = {
      linkedWorkflowId: 'wf-1',
      becameDueAt: inherited,
      priorEvidence: {observedAt: inherited},
      createdAt: '2026-07-21T04:00:00.000Z',
      updatedAt: '2026-07-21T04:00:00.000Z',
    };

    const converted = workflowFirestoreDataForTest(successor);
    expect(converted.becameDueAt).toBe(inherited);
    expect(converted.priorEvidence.observedAt).toBe(inherited);
    expect(converted.createdAt).toBeInstanceOf(admin.firestore.Timestamp);
    expect(converted.updatedAt).toBeInstanceOf(admin.firestore.Timestamp);
  });

  test('workflow correction preserves history extensions and normalizes closure time', () => {
    const closedAt = admin.firestore.Timestamp.fromDate(
      new Date('2026-07-21T05:00:00.000Z'),
    );
    const action = {
      asset: 'furnace-1',
      component: 'burner',
      actionType: 'inspection',
      isAutoResolved: false,
      createdAt: '2026-07-21T04:30:00.000Z',
      severity: 'medium',
      version: 1,
      futureActionField: {retained: true},
    };
    const projection = maintenanceProjectionForCorrection({
      maintenance: {
        version: 7,
        isResolved: true,
        endDate: closedAt,
        closedByUid: 'ops-1',
        closedByName: 'Operations',
        actionsJson: JSON.stringify([action]),
        teamsInvolved: ['operations'],
        resolutionHistoryJson: JSON.stringify([{
          resolvedAt: '2026-07-20T05:00:00.000Z',
          actionsJson: '[]',
          futureHistoryField: {retained: true},
        }]),
      },
      reason: 'Further correction required',
      actorUid: 'elec-1',
      actorName: 'Electrical',
      at: new Date('2026-07-21T05:15:00.000Z'),
    });

    const rows = JSON.parse(projection.resolutionHistoryJson);
    expect(rows).toHaveLength(2);
    expect(rows[0].futureHistoryField).toEqual({retained: true});
    expect(rows[1].resolvedAt).toBe('2026-07-21T05:00:00.000Z');
    expect(JSON.parse(rows[1].actionsJson)[0].futureActionField).toEqual({
      retained: true,
    });
  });

  test.each([
    ['malformed JSON', '{not-json', new Date('2026-07-21T05:00:00.000Z')],
    ['wrong root', '{}', new Date('2026-07-21T05:00:00.000Z')],
    ['non-object row', '["lost"]', new Date('2026-07-21T05:00:00.000Z')],
    ['missing closure time', '[]', null],
  ])('workflow correction fails closed for %s', (_label, history, endDate) => {
    let caught;
    try {
      maintenanceProjectionForCorrection({
        maintenance: {
          version: 7,
          isResolved: true,
          endDate,
          actionsJson: '[]',
          teamsInvolved: [],
          resolutionHistoryJson: history,
        },
        reason: 'Further correction required',
        actorUid: 'elec-1',
        actorName: 'Electrical',
        at: new Date('2026-07-21T05:15:00.000Z'),
      });
    } catch (error) {
      caught = error;
    }
    expect(caught).toMatchObject({
      code: 'failed-precondition',
      details: expect.objectContaining({
        reasonCode: 'maintenance-resolution-history-invalid',
      }),
    });
  });

});
