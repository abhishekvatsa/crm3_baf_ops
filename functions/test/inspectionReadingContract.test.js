const {
  isInspectionDate, parseInspectionReadingFields, parseMultiReadingValue,
  multiReadingOutOfRange, compareMultiReadingValue,
} = require('../lib/maintenanceWorkflow/inspectionReadingContract');
const {MaintenanceWorkflowCommandService, MemoryWorkflowStore, at, seedActor,
  seedFurnaceHierarchy, upsertDefinition, createCampaign, observation,
} = require('./helpers/inspectionFixture');

const field = (id, valueType, extra = {}) => ({id, label: id,
  valueType, unit: valueType === 'number' ? 'bar' : null,
  choiceValues: [], minimumValue: null, maximumValue: null, ...extra});
const fields = () => [field('checked', 'boolean'), field('checked_on', 'date'),
  field('inlet', 'number', {minimumValue: 2, maximumValue: 4}),
  field('outlet', 'number', {minimumValue: 2, maximumValue: 4})];
const contract = (readingFields = fields()) => ({schemaVersion: 2, readingFields});
const values = (patch = {}) => ({schemaVersion: 2, readings: fields().map((f) => ({
  fieldId: f.id, valueType: f.valueType,
  value: ({checked: true, checked_on: '2026-10-03', inlet: 3, outlet: 3, ...patch})[f.id],
}))});
const v2Command = (overrides = {}) => {
  const command = upsertDefinition(overrides);
  for (const key of ['valueType', 'unit', 'choiceValues', 'minimumValue', 'maximumValue']) {
    delete command.payload.definition[key];
  }
  Object.assign(command.payload.definition, contract());
  return command;
};
const readingCommand = (options = {}, patch = {}) => {
  const command = observation(options);
  command.payload.value = values(patch);
  command.payload.unit = null;
  return command;
};
async function fixture() {
  const store = new MemoryWorkflowStore();
  seedFurnaceHierarchy(store);
  const admin = seedActor(store, 'admin', ['admin']);
  const observer = seedActor(store, 'observer', ['seniorInstrumentation']);
  const outsider = seedActor(store, 'outsider', ['operations']);
  const service = new MaintenanceWorkflowCommandService(store);
  const run = (command, actor = observer) => service.execute(command, {
    actor, serverNow: at('2026-08-21T06:00:00Z'),
  });
  await run(v2Command(), admin);
  await run(createCampaign({targetAssetNumbers: [1]}), admin);
  return {store, admin, observer, outsider, run};
}

describe('strict date-only inspection readings', () => {
  test.each(['0001-01-01', '2000-02-29', '2024-02-29', '9999-12-31'])('accepts %s', (value) => {
    expect(isInspectionDate(value)).toBe(true);
  });
  test.each(['0000-01-01', '1900-02-29', '2100-02-29', '2026-02-29', '2026-04-31',
    '2026-13-01', '2026-01-00', '2026-1-01', '03-10-2026', '2026-10-03T00:00:00Z',
    '2026-10-03 ', 20261003, null])('rejects non-date-only value %p', (value) => {
    expect(isInspectionDate(value)).toBe(false);
    expect(() => parseMultiReadingValue(values({checked_on: value}), contract())).toThrow();
  });
});

describe('multi-reading frozen contract admission', () => {
  test('keeps ordered labels and canonical primitive values', () => {
    expect(parseInspectionReadingFields(fields())).toEqual(fields());
    expect(parseMultiReadingValue(values(), contract())).toEqual(values());
  });
  test.each([
    () => [], () => Array.from({length: 21}, (_, i) => field(`f${i}`, 'boolean')),
    () => [field('same', 'boolean'), field('same', 'date')],
    () => [field('a', 'boolean', {label: ' Checked '}), field('b', 'date', {label: 'checked'})],
    () => [field('with space', 'boolean')], () => [field('a', 'date', {unit: 'day'})],
    () => [field('a', 'date', {minimumValue: 1})],
    () => [field('a', 'number', {unit: null})],
    () => [field('a', 'number', {minimumValue: 5, maximumValue: 4})],
    () => [field('a', 'number', {minimumValue: Infinity})],
    () => [field('a', 'choice')],
    () => [field('a', 'choice', {choiceValues: ['x', ' x ']})],
    () => [field('a', 'text', {unknown: true})],
    () => {const f = field('a', 'boolean'); delete f.maximumValue; return [f];},
  ])('rejects malformed field population %#', (make) => {
    expect(() => parseInspectionReadingFields(make())).toThrow();
  });
  test.each([
    (v) => {v.schemaVersion = 1;}, (v) => {v.extra = true;},
    (v) => {v.readings.pop();}, (v) => {v.readings.push(v.readings[0]);},
    (v) => {v.readings.reverse();}, (v) => {v.readings[1].fieldId = 'checked';},
    (v) => {v.readings[0].valueType = 'text';}, (v) => {v.readings[0].value = 'true';},
    (v) => {v.readings[2].value = '3';}, (v) => {v.readings[2].value = NaN;},
    (v) => {v.readings[2].unit = 'bar';}, (v) => {v.readings[1].value = null;},
  ])('rejects changed/missing/duplicated readings %#', (change) => {
    const value = values(); change(value);
    expect(() => parseMultiReadingValue(value, contract())).toThrow();
  });
  test('text and choice fields require nonempty bounded values and exact allowed choices', () => {
    const definition = contract([field('note', 'text'), field('colour', 'choice', {choiceValues: ['red', 'green']})]);
    const value = {schemaVersion: 2, readings: [
      {fieldId: 'note', valueType: 'text', value: 'checked'},
      {fieldId: 'colour', valueType: 'choice', value: 'green'},
    ]};
    expect(parseMultiReadingValue(value, definition)).toEqual(value);
    for (const bad of ['', ' '.repeat(2), ' checked', 'checked ', 'x'.repeat(1001), false]) {
      const changed = structuredClone(value); changed.readings[0].value = bad;
      expect(() => parseMultiReadingValue(changed, definition)).toThrow();
    }
    value.readings[1].value = 'blue';
    expect(() => parseMultiReadingValue(value, definition)).toThrow();
  });
  test('each governed numeric field independently causes a breach, never a date or boolean', () => {
    expect(multiReadingOutOfRange(values(), contract())).toBe(false);
    expect(multiReadingOutOfRange(values({inlet: 1}), contract())).toBe(true);
    expect(multiReadingOutOfRange(values({outlet: 5}), contract())).toBe(true);
    expect(multiReadingOutOfRange(values({checked: false, checked_on: '0001-01-01'}), contract())).toBe(false);
  });
});

describe('versioned multi-reading workflow boundaries', () => {
  test.each([[['number']], [['date']], [{valueType: 'number'}]])('definition handler rejects non-string type %p without writing', async (badType) => {
    const {store, run, admin} = await fixture();
    const command = v2Command({commandId: 'invalid-type', expectedVersion: 1});
    command.payload.definition.readingFields[0].valueType = badType;
    const before = store.entries();
    await expect(run(command, admin)).rejects.toMatchObject({code: 'invalid-argument'});
    expect(store.entries()).toEqual(before);
  });
  test('freezes full contract, records canonical value only and replays exact command without writes', async () => {
    const {store, run, admin} = await fixture();
    const beforeDefinition = store.read('inspection_campaigns/campaign-furnace-pt-august').definition;
    const update = v2Command({commandId: 'edit-definition', expectedVersion: 1});
    update.payload.definition.readingFields[1].label = 'Later date label';
    await run(update, admin);
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august').definition).toEqual(beforeDefinition);
    const command = readingCommand();
    const receipt = await run(command);
    const saved = store.read('inspection_observations/observation-1');
    expect(saved).toMatchObject({schemaVersion: 2, value: values(), definition: beforeDefinition, outOfRange: false});
    for (const key of ['readings', 'numericValue', 'booleanValue', 'textValue', 'choiceValue', 'valueType', 'unit', 'minimumValue', 'maximumValue']) {
      expect(saved).not.toHaveProperty(key);
    }
    const beforeReplay = store.entries();
    expect(await run(command)).toEqual(receipt);
    expect(store.entries()).toEqual(beforeReplay);
    const changed = structuredClone(command); changed.payload.value.readings[1].value = '2026-10-04';
    await expect(run(changed)).rejects.toThrow();
    expect(store.entries()).toEqual(beforeReplay);
  });
  test('denied actors and stale revisions cannot record or correct', async () => {
    const {store, run, outsider} = await fixture();
    const before = store.entries();
    await expect(run(readingCommand(), outsider)).rejects.toMatchObject({code: 'permission-denied'});
    await expect(run(readingCommand({expectedVersion: 0}))).rejects.toMatchObject({code: 'aborted'});
    expect(store.entries()).toEqual(before);
  });
  test('accepted v2 replay still requires the exact original approved actor and authority', async () => {
    const {store, run, admin} = await fixture();
    const command = readingCommand();
    await run(command);
    const before = store.entries();
    await expect(run(command, admin)).rejects.toMatchObject({code: 'permission-denied'});
    expect(store.entries()).toEqual(before);
    store.seed('users/observer', {name: 'observer', isApproved: false, roles: ['seniorInstrumentation']});
    const revoked = store.entries();
    await expect(run(command)).rejects.toMatchObject({code: 'permission-denied'});
    expect(store.entries()).toEqual(revoked);
  });
  test('v2 envelope and top-level unit admission fails atomically', async () => {
    const {store, run} = await fixture();
    const before = store.entries();
    for (const value of [observation().payload.value, {...values(), numericValue: 3}, values({checked_on: '2026-02-30'})]) {
      const command = readingCommand(); command.payload.value = value;
      await expect(run(command)).rejects.toMatchObject({code: 'invalid-argument'});
    }
    for (const unit of ['bar', '', ' ']) {
      const command = readingCommand(); command.payload.unit = unit;
      await expect(run(command)).rejects.toMatchObject({code: 'invalid-argument'});
    }
    expect(store.entries()).toEqual(before);
  });
  test('numeric second field opens finding; correction preserves original and requires a separate adjudication', async () => {
    const {store, run} = await fixture();
    const assets = store.entries().filter(([path]) => path.startsWith('asset_'));
    await run(readingCommand({}, {outlet: 8}));
    expect(store.read('inspection_findings/inspection-finding-observation-1').status).toBe('open');
    const original = store.read('inspection_observations/observation-1');
    const correction = readingCommand({commandId: 'correction', observationId: 'correction',
      expectedVersion: 2, supersedesObservationId: 'observation-1'});
    await run(correction);
    expect(store.read('inspection_observations/observation-1')).toEqual(original);
    expect(store.read('inspection_observations/correction').value).toEqual(values());
    expect(store.read('inspection_findings/inspection-finding-observation-1').status).toBe('awaitingVerification');
    expect(store.entries().filter(([path]) => path.startsWith('asset_'))).toEqual(assets);
    expect(store.entries().filter(([path]) => path.startsWith('equipment') || path.startsWith('inner_cover_assessments'))).toEqual([]);
  });
  test('v1 title edits keep scalar shape; explicit upgrade removes obsolete keys and leaves old campaign usable', async () => {
    const store = new MemoryWorkflowStore(); seedFurnaceHierarchy(store);
    const admin = seedActor(store, 'admin', ['admin']);
    const observer = seedActor(store, 'observer', ['seniorInstrumentation']);
    const service = new MaintenanceWorkflowCommandService(store);
    const run = (command, actor = admin) => service.execute(command, {actor, serverNow: at('2026-08-21T06:00:00Z')});
    await run(upsertDefinition());
    await run(createCampaign({targetAssetNumbers: [1]}));
    const snapshot = store.read('inspection_campaigns/campaign-furnace-pt-august').definition;
    await run(upsertDefinition({commandId: 'title-edit', expectedVersion: 1, overrides: {title: 'Revised title'}}));
    expect(store.read('inspection_definitions/inspection-definition-furnace-pt')).toMatchObject({schemaVersion: 1, valueType: 'number'});
    expect(store.read('inspection_definitions/inspection-definition-furnace-pt')).not.toHaveProperty('readingFields');
    await run(v2Command({commandId: 'upgrade', expectedVersion: 2}));
    const definition = store.read('inspection_definitions/inspection-definition-furnace-pt');
    expect(definition.schemaVersion).toBe(2);
    expect(definition).not.toHaveProperty('valueType');
    expect(definition).not.toHaveProperty('unit');
    expect(store.read('inspection_campaigns/campaign-furnace-pt-august').definition).toEqual(snapshot);
    await run(observation(), observer);
    const saved = store.read('inspection_observations/observation-1');
    expect(saved).toMatchObject({schemaVersion: 1, numericValue: 1.8, value: observation().payload.value});
    expect(saved).not.toHaveProperty('readings');
  });
});

describe('conservative full-contract baseline comparison', () => {
  const baseline = (patch = {}) => ({schemaVersion: 2, definition: contract(), value: values(patch)});
  test('retains equal evidence and refuses changed qualitative evidence or equal opposite breaches', () => {
    expect(compareMultiReadingValue(values(), baseline(), contract())).toBe('unchanged');
    expect(compareMultiReadingValue(values({checked_on: '2026-10-04'}), baseline(), contract())).toBe('notComparable');
    expect(compareMultiReadingValue(values({checked: false}), baseline(), contract())).toBe('notComparable');
    expect(compareMultiReadingValue(values({inlet: 5}), baseline({inlet: 1}), contract())).toBe('notComparable');
  });
  test.each([[3, 3.2], [3.2, 3], [2, 4], [4, 2]])('keeps in-range %s to %s unchanged', (before, after) => {
    expect(compareMultiReadingValue(values({inlet: after}), baseline({inlet: before}), contract())).toBe('unchanged');
  });
  test('in-range movement does not mask another field resolving or recurring', () => {
    expect(compareMultiReadingValue(values({inlet: 3.2}), baseline({outlet: 8}), contract())).toBe('resolved');
    expect(compareMultiReadingValue(values({inlet: 3.2, outlet: 8}), baseline(), contract())).toBe('recurred');
  });
  test('numeric recovery does not overrule a changed qualitative answer', () => {
    expect(compareMultiReadingValue(values({checked: false}), baseline({outlet: 8}), contract())).toBe('notComparable');
    expect(compareMultiReadingValue(values({checked_on: '2026-10-04'}), baseline({outlet: 8}), contract())).toBe('notComparable');
  });
  test('does not infer a trend for changed numeric readings without bounds', () => {
    const definition = contract([field('unbounded', 'number')]);
    const value = n => ({schemaVersion: 2, readings: [{fieldId: 'unbounded', valueType: 'number', value: n}]});
    expect(compareMultiReadingValue(value(3.2), {schemaVersion: 2, definition, value: value(3)}, definition)).toBe('notComparable');
    expect(compareMultiReadingValue(value(3), {schemaVersion: 2, definition, value: value(3)}, definition)).toBe('unchanged');
  });
  test.each([{minimumValue: 2}, {maximumValue: 4}])('compares in-range movement with a single bound %p', (limits) => {
    const definition = contract([field('pressure', 'number', limits)]);
    const value = n => ({schemaVersion: 2, readings: [{fieldId: 'pressure', valueType: 'number', value: n}]});
    expect(compareMultiReadingValue(value(3.2), {schemaVersion: 2, definition, value: value(3)}, definition)).toBe('unchanged');
  });
  test('does not add different unit magnitudes or hide mixed directions', () => {
    expect(compareMultiReadingValue(values({inlet: 1, outlet: 7}), baseline({inlet: 0, outlet: 6}), contract())).toBe('notComparable');
    expect(compareMultiReadingValue(values(), baseline({outlet: 8}), contract())).toBe('resolved');
    expect(compareMultiReadingValue(values({outlet: 8}), baseline(), contract())).toBe('recurred');
  });
  test.each(['id', 'label', 'valueType', 'unit', 'choiceValues', 'minimumValue', 'maximumValue'])('rejects changed frozen %s', (key) => {
    const old = baseline();
    old.definition.readingFields[2][key] = key === 'minimumValue' ? 1 : key === 'maximumValue' ? 5 : key === 'choiceValues' ? ['x'] : 'changed';
    expect(compareMultiReadingValue(values(), old, contract())).toBe('notComparable');
  });
  test('does not compare scalar or incomplete historical records to v2', () => {
    expect(compareMultiReadingValue(values(), {schemaVersion: 1, numericValue: 3}, contract())).toBe('notComparable');
    const old = baseline(); old.value.readings.pop();
    expect(compareMultiReadingValue(values(), old, contract())).toBe('notComparable');
  });
});


describe('shared Dart/server acceptance corpus', () => {
  const corpus = require('../../test/fixtures/inspection_reading_contract_v2.json');
  test.each(corpus.fieldCases)('$name', ({fields, valid}) => {
    if (valid) expect(() => parseInspectionReadingFields(fields)).not.toThrow();
    else expect(() => parseInspectionReadingFields(fields)).toThrow();
  });
  test.each(corpus.observationCases)('$name', ({fields, value, valid, outOfRange}) => {
    const definition = contract(fields);
    if (valid) {
      const parsed = parseMultiReadingValue(value, definition);
      expect(multiReadingOutOfRange(parsed, definition)).toBe(outOfRange);
    } else expect(() => parseMultiReadingValue(value, definition)).toThrow();
  });
});
