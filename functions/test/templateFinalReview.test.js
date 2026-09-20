const {A, ref, load} = require('./support/templateReviewFixture.cjs');
const {compareRequirementContracts} = require('../lib/requirementContract');

test('unit prefixes and normative instructions preserve meaning', () => {
  const field = {key: 'current', type: 'number', required: true, unit: 'mA'};
  expect(compareRequirementContracts(field, {...field, unit: 'MA'}).field).toBe('unit');
  expect(compareRequirementContracts(field, {...field, unit: ' mA '})).toBeNull();
  const instruction = {key: 'prepare', type: 'instruction', instructionText: 'Isolate before opening'};
  expect(compareRequirementContracts(instruction, {...instruction, instructionText: 'Open without isolation'}).field).toBe('instructions');
  expect(compareRequirementContracts(instruction, {...instruction, instructionText: ' Isolate  before opening '})).toBeNull();
});

const installed = () => A({version: {jobTemplateSnapshotJson: JSON.stringify({jobName: 'Shell work', assetType: 'furnace', assetHierarchyRefJson: JSON.stringify(ref())})}});
test.each(['missing', 'retired', 'revision', 'definition', 'ownership', 'parent', 'tag'])('fresh installed target refuses %s without writes', async (change) => {
  const a = installed();
  const component = a.store.get('asset_component_instances/installed-shell');
  if (change === 'missing') a.store.delete('asset_component_instances/installed-shell');
  if (change === 'retired') component.status = 'retired';
  if (change === 'revision') component.version++;
  if (change === 'definition') a.store.get('asset_hierarchy_nodes/shell').version++;
  if (change === 'ownership') component.ownerDiscipline = 'Electrical';
  if (change === 'parent') component.assetInstanceId = 'furnace-8';
  if (change === 'tag') component.componentTag = 'OTHER';
  await expect(a.assign()).rejects.toMatchObject({details: {reasonCode: 'assignment-installed-component-changed'}});
  expect(a.writes).toHaveLength(0);
});
test('current installed target accepts; retirement after acceptance does not block historical replay', async () => {
  const a = installed();
  const first = await a.assign();
  a.store.get('asset_component_instances/installed-shell').status = 'retired';
  const writes = a.writes.length;
  expect((await a.assign()).executionId).toBe(first.executionId);
  expect(a.writes).toHaveLength(writes);
});
test.each(['mechanical', 'electrical', 'operations'])('RED refuses explicit %s scope instead of relabelling ownership', async (discipline) => {
  const a = A({version: {moduleSnapshotsJson: JSON.stringify([{moduleCode: 'M-01', moduleTitle: 'Inspect shell', discipline}])}});
  await expect(a.red()).rejects.toMatchObject({details: {reasonCode: 'red-successor-discipline-incompatible'}});
});
test('RED retains a compatible refractory package and required fields', async () => {
  const a = A({version: {moduleSnapshotsJson: JSON.stringify([{moduleCode: 'M-01', moduleTitle: 'Inspect shell', discipline: 'refractory'}])}});
  const template = await a.red();
  const built = load('maintenanceWorkflow/redSuccessorTemplateResolver').buildRedSuccessorModule({template,
    module: template.modules[0], index: 0, executionId: 'child', assetTypeKey: 'furnace', assetNumber: 7,
    actorUid: 'admin', actorName: 'Admin', at: '2026-09-20T04:00:00.000Z'});
  expect(built.data.discipline).toBe('refractory');
  expect(JSON.parse(built.data.fieldDefinitionsJson)[0].isRequired).toBe(true);
});
test('required standalone checklist is refused by both assignment producers', async () => {
  const a = A({version: {checklistJson: JSON.stringify([{id: 'witness', moduleCode: 'M-01', isRequired: true, title: 'Torque witness'}])}});
  await expect(a.assign()).rejects.toMatchObject({details: {reasonCode: 'required-checklist-not-executable'}});
  await expect(a.red()).rejects.toMatchObject({details: {reasonCode: 'required-checklist-not-executable'}});
  expect(a.writes).toHaveLength(0);
});
