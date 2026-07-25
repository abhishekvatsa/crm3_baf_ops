const {
  equipmentFactsFromProjection,
} = require('../lib/maintenanceWorkflow/equipmentFacts');

const completeProjection = {
  activeNonRedMaintenanceCount: 0,
  activeRedWorkCount: 0,
  awaitingPreparationCount: 0,
};

describe('serialized equipment facts', () => {
  test('accepts a complete reconciled zero-counter projection', () => {
    expect(equipmentFactsFromProjection(completeProjection)).toEqual(
      completeProjection,
    );
  });

  test('rejects a wholly absent projection', () => {
    expect(() => equipmentFactsFromProjection(null)).toThrow(
      expect.objectContaining({
        code: 'equipment-state-conflict',
        details: {reasonCode: 'equipment-projection-missing'},
      }),
    );
  });

  test('rejects a partial counter set even when the active contribution is present', () => {
    expect(() => equipmentFactsFromProjection({
      activeNonRedMaintenanceCount: 1,
      awaitingPreparationCount: 0,
    })).toThrow(expect.objectContaining({
      code: 'equipment-state-conflict',
      details: {
        reasonCode: 'equipment-projection-counter-set-incomplete',
        missingFields: ['activeRedWorkCount'],
      },
    }));
  });

  test.each([
    ['negative', -1],
    ['fractional', 0.5],
    ['string', '1'],
    ['null', null],
  ])('rejects a %s serialized counter', (_label, value) => {
    expect(() => equipmentFactsFromProjection({
      ...completeProjection,
      activeRedWorkCount: value,
    })).toThrow(expect.objectContaining({
      code: 'equipment-state-conflict',
      details: expect.objectContaining({
        reasonCode: 'equipment-projection-counter-invalid',
        field: 'activeRedWorkCount',
      }),
    }));
  });
});
