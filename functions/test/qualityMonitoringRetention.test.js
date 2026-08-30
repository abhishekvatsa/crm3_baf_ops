const {
  planQualityMonitoringArchive,
} = require('../lib/qualityMonitoringRetention');

const requestId = '44444444-4444-4444-8444-444444444444';
const closedAt = new Date('2026-08-14T12:00:00.000Z');
const visibleUntil = new Date('2026-08-21T12:00:00.000Z');

function monitoring(overrides = {}) {
  return {
    schemaVersion: 2,
    requestId,
    baseNumber: 12,
    grade: 'CRGO M4',
    cycleReference: 'Cycle family 7A',
    chargeNumbers: [12001, 12002],
    reason: 'Monitor atmosphere stability during the campaign.',
    status: 'closed',
    visibilityState: 'recent',
    visibleUntil,
    archivedAt: null,
    createdAt: new Date('2026-08-14T08:00:00.000Z'),
    createdByUid: 'si-1',
    createdByName: 'SI One',
    closedAt,
    closedByUid: 'admin-1',
    closedByName: 'Admin One',
    closeReason: 'The monitoring campaign is complete.',
    updatedAt: closedAt,
    updatedByUid: 'admin-1',
    updatedByName: 'Admin One',
    version: 2,
    lastMutationId: '55555555-5555-4555-8555-555555555555',
    ...overrides,
  };
}

describe('quality monitoring operational retention', () => {
  test('keeps a recent closure visible until the exact server deadline', () => {
    expect(planQualityMonitoringArchive({
      data: monitoring(),
      requestId,
      now: new Date('2026-08-21T11:59:59.999Z'),
    })).toBeNull();
  });

  test('archives at the server deadline without changing business version', () => {
    const patch = planQualityMonitoringArchive({
      data: monitoring(),
      requestId,
      now: visibleUntil,
    });

    expect(patch).toEqual({
      schemaVersion: 2,
      visibilityState: 'archived',
      visibleUntil: null,
      archivedAt: visibleUntil,
    });
    expect(patch).not.toHaveProperty('version');
    expect(patch).not.toHaveProperty('lastMutationId');
  });

  test('archives an exact legacy closure through a schema-v2 upgrade', () => {
    const legacy = monitoring({schemaVersion: 1});
    delete legacy.visibilityState;
    delete legacy.visibleUntil;
    delete legacy.archivedAt;

    expect(planQualityMonitoringArchive({
      data: legacy,
      requestId,
      now: visibleUntil,
    })).toEqual({
      schemaVersion: 2,
      visibilityState: 'archived',
      visibleUntil: null,
      archivedAt: visibleUntil,
    });
  });

  test('an archived record is idempotently ignored', () => {
    expect(planQualityMonitoringArchive({
      data: monitoring({
        visibilityState: 'archived',
        visibleUntil: null,
        archivedAt: visibleUntil,
      }),
      requestId,
      now: new Date('2026-08-22T12:00:00.000Z'),
    })).toBeNull();
  });

  test.each([
    ['missing deadline', {visibleUntil: null}],
    ['wrong deadline', {visibleUntil: new Date('2026-08-21T11:59:59.999Z')}],
    ['premature archive', {
      visibilityState: 'archived',
      visibleUntil: null,
      archivedAt: new Date('2026-08-21T11:59:59.999Z'),
    }],
  ])('fails closed for %s', (_label, overrides) => {
    expect(() => planQualityMonitoringArchive({
      data: monitoring(overrides),
      requestId,
      now: new Date('2026-08-22T12:00:00.000Z'),
    })).toThrow();
  });
});
