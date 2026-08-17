const {
  readComponentActionPayload,
} = require('../lib/persistedActionPayload');

const validAction = (overrides = {}) => ({
  asset: 'base-1',
  component: 'hydraulic valve',
  actionType: 'repair',
  isAutoResolved: false,
  createdAt: '2026-08-05T08:00:00.000Z',
  severity: 'high',
  version: 1,
  ...overrides,
});

describe('persisted component-action payload', () => {
  test('accepts canonical and schema-versioned actions', () => {
    const raw = JSON.stringify([
      validAction({schemaVersion: 1}),
    ]);
    const parsed = readComponentActionPayload(raw, {field: 'actionsJson'});

    expect(parsed.text).toBe(raw);
    expect(parsed.rows[0].schemaVersion).toBe(1);
  });

  test.each([
    ['malformed JSON', '{not-json'],
    ['wrong root', '{}'],
    ['non-object row', '["action"]'],
    ['missing asset', JSON.stringify([validAction({asset: undefined})])],
    ['unknown action type', JSON.stringify([validAction({actionType: 'weld'})])],
    ['wrong boolean', JSON.stringify([validAction({isAutoResolved: 0})])],
    ['missing timestamp', JSON.stringify([validAction({createdAt: undefined})])],
    ['invalid timestamp', JSON.stringify([validAction({createdAt: 'soon'})])],
    ['invalid severity', JSON.stringify([validAction({severity: 'urgent'})])],
    ['invalid version', JSON.stringify([validAction({version: 0})])],
    ['coerced hierarchy', JSON.stringify([validAction({hierarchyPath: [3]})])],
    ['future schema', JSON.stringify([validAction({schemaVersion: 2})])],
    ['unknown extension', JSON.stringify([validAction({futureAuthority: true})])],
    ['partial burner evidence', JSON.stringify([validAction({burnerPosition: 2})])],
    ['empty metadata object text', JSON.stringify([validAction({metadataJson: ''})])],
    ['conflicting action aliases', JSON.stringify([
      validAction({action: 'replacement'}),
    ])],
  ])('rejects %s', (_label, raw) => {
    expect(() => readComponentActionPayload(raw, {field: 'actionsJson'}))
      .toThrow(/Invalid persisted component-action field/);
  });

  test('only an entirely missing legacy payload may initialize empty', () => {
    expect(readComponentActionPayload(null, {
      field: 'actionsJson',
      allowMissing: true,
    }).rows).toEqual([]);
    expect(() => readComponentActionPayload('', {
      field: 'actionsJson',
      allowMissing: true,
    })).toThrow();
  });
});
