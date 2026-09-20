const {requireInspectionCorrectiveSubject, inspectionCorrectiveScopeReview} = require('../lib/maintenanceWorkflow/inspectionPhysicalSubject');

const observation = {assetTypeKey: 'furnace', assetClassId: 'furnace-class', assetInstanceId: 'furnace-22',
  assetNumber: 22, componentNodeId: 'pressure-transmitter', physicalPosition: null, targetKey: 'target-pt'};
const reference = {schemaVersion: 4, scope: 'componentDefinitionOnAsset', assetClassId: 'furnace-class',
  assetInstanceId: 'furnace-22', assetNumber: 22, assetInstanceVersion: 1, nodeId: 'pressure-transmitter',
  nodeName: 'PT', nodeVersion: 1};
const ticket = (changes = {}) => ({firestoreId: 'repair-1', version: 3, isDeleted: false, assetType: 'furnace',
  assetNumber: 22, description: 'Repair pressure control', assetHierarchyRefJson: JSON.stringify({...reference, ...changes})});

test('stable component identity survives display-name and catalogue revision changes', () => {
  expect(() => requireInspectionCorrectiveSubject(ticket({nodeName: 'Renamed PT', nodeVersion: 5}), 'repair-1', observation)).not.toThrow();
});
test.each([
  {nodeId: 'gas-valve'},
  {schemaVersion: 3, scope: 'physicalAsset', nodeId: 'asset'},
  {schemaVersion: 3, scope: 'installedComponent', componentInstanceId: 'serial-7'},
])('asset coincidence is not exact component evidence: %j', (changes) => {
  expect(() => requireInspectionCorrectiveSubject(ticket(changes), 'repair-1', observation))
    .toThrow('exact inspected component and position');
});
test('position applicability is explicit, identity-bound and cannot move to another position or asset', () => {
  const located = {...observation, physicalPosition: 'North', targetKey: 'target-north'};
  const work = ticket();
  expect(() => requireInspectionCorrectiveSubject(work, 'repair-1', located)).toThrow();
  const review = inspectionCorrectiveScopeReview(work, 'repair-1', located,
    {expectedTicketVersion: 3, reason: 'This repair covers the north transmitter.'}, new Set(['admin']),
    'admin-1', 'Admin', '2026-09-20T06:00:00.000Z');
  expect(() => requireInspectionCorrectiveSubject(work, 'repair-1', located, review)).not.toThrow();
  expect(() => requireInspectionCorrectiveSubject(work, 'repair-1', {...located, physicalPosition: 'South'}, review)).toThrow();
  expect(() => requireInspectionCorrectiveSubject(ticket({assetInstanceId: 'furnace-23'}), 'repair-1', located, review)).toThrow();
  expect(() => requireInspectionCorrectiveSubject({...work, description: 'Changed work scope'}, 'repair-1', located, review)).toThrow();
});
