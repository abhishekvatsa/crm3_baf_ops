const {inspectionV2AuthoringEnabled, INSPECTION_V2_AUTHORING_CAPABILITY} = require('../lib/maintenanceWorkflow/inspectionAuthoringPolicy');
const {executeOriginBoundCallable} = require('../lib/originBoundCallableProtocol');
const {MaintenanceWorkflowCommandService, MemoryWorkflowStore, at, seedActor,
  seedFurnaceHierarchy, upsertDefinition, createCampaign, observation} = require('./helpers/inspectionFixture');
const flag = 'CRM_INSPECTION_V2_AUTHORING_ENABLED';
const prior = process.env[flag];
beforeEach(() => { delete process.env[flag]; });
afterEach(() => { if (prior === undefined) delete process.env[flag]; else process.env[flag] = prior; });
const denied = {code: 'failed-precondition', details: {reasonCode: 'inspection-v2-authoring-unavailable'}};
const fields = [{id: 'checked', label: 'Checked?', valueType: 'boolean', unit: null,
  choiceValues: [], minimumValue: null, maximumValue: null},
{id: 'checked_on', label: 'Checked on', valueType: 'date', unit: null,
  choiceValues: [], minimumValue: null, maximumValue: null}];
function v2(options = {}) {
  const command = upsertDefinition(options);
  for (const key of ['valueType', 'unit', 'choiceValues', 'minimumValue', 'maximumValue']) delete command.payload.definition[key];
  Object.assign(command.payload.definition, {schemaVersion: 2, readingFields: fields});
  return command;
}
function setup() {
  const store = new MemoryWorkflowStore(); seedFurnaceHierarchy(store);
  const actor = seedActor(store, 'admin', ['admin']);
  const other = seedActor(store, 'other', ['admin']);
  const service = new MaintenanceWorkflowCommandService(store);
  const run = (command, who = actor) => service.execute(command, {actor: who, serverNow: at('2026-08-21T06:00:00Z')});
  return {store, run, actor, other};
}
const probe = (data = {}) => executeOriginBoundCallable({
  callableName: 'executeMaintenanceWorkflowCommandV2', authUid: 'admin',
  data: {protocolVersion: 2, originActorUid: 'admin', probe: 'capabilities', ...data},
  readActor: async () => ({isApproved: true, roles: ['admin']}),
  execute: async () => { throw new Error('probe must not execute a business command'); },
});

test.each([undefined, '', 'false', 'TRUE', '1', ' true', 'true ', 'yes'])('flag %p fails closed for direct handler and capability', async value => {
  if (value !== undefined) process.env[flag] = value;
  expect(inspectionV2AuthoringEnabled()).toBe(false);
  expect((await probe()).capabilities).not.toContain(INSPECTION_V2_AUTHORING_CAPABILITY);
  const {store, run} = setup(); const before = store.entries();
  await expect(run(v2())).rejects.toMatchObject(denied);
  expect(store.entries()).toEqual(before);
});

test('trusted true enables both admission and optional probe without changing general revision', async () => {
  process.env[flag] = 'true';
  const result = await probe();
  expect(result.capabilityRevision).toBe('maintenanceWorkflow.v2.20260913');
  expect(result.capabilities).toContain('maintenanceWorkflow.v2');
  expect(result.capabilities).toContain(INSPECTION_V2_AUTHORING_CAPABILITY);
  const {run} = setup(); await run(v2()); await run(createCampaign({targetAssetNumbers: [1]}));
});

test('client claims cannot grant authoring', async () => {
  await expect(probe({inspectionV2AuthoringEnabled: true})).rejects.toMatchObject({code: 'invalid-argument'});
  const {store, run} = setup(); const before = store.entries();
  const command = v2(); command.payload.authoringEnabled = true;
  await expect(run(command)).rejects.toMatchObject({code: 'invalid-argument'});
  expect(store.entries()).toEqual(before);
});

test('default closed keeps v1 title edits, campaigns and observations unchanged, refusing v1 upgrade', async () => {
  const {store, run} = setup();
  await run(upsertDefinition());
  await run(upsertDefinition({commandId: 'title', expectedVersion: 1, overrides: {title: 'Reviewed title'}}));
  const campaign = createCampaign({targetAssetNumbers: [1]}); campaign.payload.definitionVersion = 2;
  await run(campaign);
  const reading = observation(); reading.payload.definitionVersion = 2;
  await run(reading);
  const before = store.entries();
  await expect(run(v2({commandId: 'upgrade', expectedVersion: 2}))).rejects.toMatchObject(denied);
  expect(store.entries()).toEqual(before);
});

test('closing gate preserves accepted definition/campaign replay before admission, exact actor and immutable payload', async () => {
  const {store, run, other} = setup(); process.env[flag] = 'true';
  const definition = v2(); const campaign = createCampaign({targetAssetNumbers: [1]});
  const defined = await run(definition); const opened = await run(campaign);
  delete process.env[flag]; const before = store.entries();
  expect(await run(definition)).toEqual(defined); expect(await run(campaign)).toEqual(opened);
  await expect(run(definition, other)).rejects.toMatchObject({code: 'permission-denied'});
  const altered = structuredClone(definition); altered.payload.definition.title = 'Changed replay';
  await expect(run(altered)).rejects.toThrow();
  await expect(run(v2({commandId: 'new-version', expectedVersion: 1}))).rejects.toMatchObject(denied);
  await expect(run(createCampaign({commandId: 'new-campaign', campaignId: 'new-campaign', targetAssetNumbers: [1]}))).rejects.toMatchObject(denied);
  expect(store.entries()).toEqual(before);
});

test('closed gate retains v2 observations and corrections without weakening value or replay validation', async () => {
  const {store, run} = setup(); process.env[flag] = 'true';
  await run(v2()); await run(createCampaign({targetAssetNumbers: [1]}));
  delete process.env[flag];
  const command = observation(); command.payload.unit = null;
  command.payload.value = {schemaVersion: 2, readings: [
    {fieldId: 'checked', valueType: 'boolean', value: false},
    {fieldId: 'checked_on', valueType: 'date', value: '2026-10-03'},
  ]};
  const accepted = await run(command); const original = store.read('inspection_observations/observation-1');
  expect(await run(command)).toEqual(accepted);
  const correction = structuredClone(command);
  correction.commandId = 'correction'; correction.expectedVersion = 2;
  correction.payload.observationId = 'correction'; correction.payload.supersedesObservationId = 'observation-1';
  correction.payload.value.readings[1].value = '2026-10-04';
  await run(correction);
  expect(store.read('inspection_observations/observation-1')).toEqual(original);
  expect(store.read('inspection_observations/correction').value).toEqual(correction.payload.value);
  const before = store.entries(); const invalid = structuredClone(correction);
  invalid.commandId = 'invalid'; invalid.payload.observationId = 'invalid'; invalid.expectedVersion = 3;
  invalid.payload.value.readings[0].value = null;
  await expect(run(invalid)).rejects.toMatchObject({code: 'invalid-argument'});
  expect(store.entries()).toEqual(before);
});
