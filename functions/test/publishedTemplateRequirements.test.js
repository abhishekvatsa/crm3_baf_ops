const {
  compilePublishedTemplateRequirements,
  computeTemplateVersionContentHash,
  validatePublishedTemplatePublication,
  validatePublishedTemplateTarget,
} = require('../lib/publishedTemplateAssignment');
const {normalizeSemanticKey} = require('../lib/semanticKeys');
const {MemoryWorkflowStore} = require('../lib/maintenanceWorkflow/memoryStore');
const {
  resolveRedSuccessorTemplate,
  buildRedSuccessorModule,
} = require('../lib/maintenanceWorkflow/redSuccessorTemplateResolver');
const {moduleMissingRequiredClosureEvidence} = require('../lib/plannedJobClosure');
const {versionFixture, packageFixture, auditFixture} = require('./helpers/publishedTemplateV2Fixtures.cjs');

const moduleRow = (code = 'RED-01', extra = {}) => ({
  moduleCode: code, moduleTitle: `Inspect ${code}`, requiredForClosure: true,
  ...extra,
});
const reading = (extra = {}) => ({
  key: 'thickness', label: 'Remaining thickness', type: 'number',
  isRequired: true, unit: 'mm', moduleCode: 'red-01', ...extra,
});
const versionFor = (modules, fields) => {
  const version = versionFixture({
    moduleSnapshotsJson: JSON.stringify(modules),
    fieldDefinitionsJson: JSON.stringify(fields),
  });
  version.contentHash = computeTemplateVersionContentHash(version);
  return version;
};
const furnaceTarget = {assetTypeKey: 'furnace', assetNumber: 7, assetClassId: 'class-furnace', assetInstanceId: 'furnace-7'};
const resolve = (version, {packageOverrides = {}, auditOverrides = {}, omitAudit = false, duplicateAudit = false, registry = {}, target = furnaceTarget} = {}) => {
  const store = new MemoryWorkflowStore();
  store.seed('equipment_prompt_master/furnace_red', {
    assetTypeKey: 'furnace', active: true, redSuccessorTemplateCode: 'RED-FURNACE',
  });
  store.seed('template_packages/pkg1', packageFixture({
    packageCode: 'RED-FURNACE', title: 'RED work', lifecycleStatus: 'active',
    activeVersionFirestoreId: 'ver1', isDeleted: false, ...packageOverrides,
  }));
  store.seed('template_versions/ver1', version);
  // Installed-component publication is bound to a complete reviewed physical
  // subject. Keep the fixture aligned with that admission contract so the
  // matching-target case exercises RED resolution rather than failing for
  // absent registry evidence.
  store.seed('asset_instances/furnace-7', {
    schemaVersion: 1,
    assetInstanceId: 'furnace-7',
    assetClassId: 'class-furnace',
    assetNumber: 7,
    status: 'active',
    version: 1,
  });
  store.seed('asset_component_instances/block-7', {
    schemaVersion: 1,
    componentInstanceId: 'block-7',
    status: 'active',
    assetInstanceId: 'furnace-7',
    assetClassId: 'class-furnace',
    assetNumber: 7,
    version: 1,
    assetInstanceVersionAtMutation: 1,
    definitionNodeId: 'burner-block',
    definitionNodeVersion: 1,
    componentTag: null,
    ownershipStatus: 'confirmed',
    ownerDiscipline: 'RED',
    accountableRoleKeys: ['refractory'],
  });
  store.seed('asset_hierarchy_nodes/burner-block', {
    schemaVersion: 1,
    nodeId: 'burner-block',
    status: 'active',
    assetClassId: 'class-furnace',
    version: 1,
  });
  for (const [path, value] of Object.entries(registry)) store.seed(path, value);
  const audit = auditFixture({afterHash: version.contentHash, ...auditOverrides});
  if (!omitAudit) store.seed('template_publish_audits/audit1', audit);
  if (duplicateAudit) store.seed('template_publish_audits/audit2', {...audit, firestoreId: 'audit2'});
  return store.runTransaction((tx) => resolveRedSuccessorTemplate(tx, target));
};

test.each([
  ['supported case', [moduleRow()], [reading()]],
  ['supported punctuation', [moduleRow('RED & TEST')], [reading({moduleCode: 'red-and-test'})]],
  ['snapshot identity', [moduleRow('RED-01', {templateModuleId: 'physical-module'})],
    [reading({moduleCode: undefined, ownerModuleId: 'physical-module'})]],
  ['matching code and identity', [moduleRow('RED-01', {templateModuleId: 'physical-module'})],
    [reading({ownerModuleId: 'physical-module'})]],
  ['embedded-only reading', [moduleRow('RED-01', {fields: [reading()]})], []],
  ['agreeing embedded and global reading', [moduleRow('RED-01', {fields: [reading()]})], [reading()]],
])('%s retains the same requirements in ordinary compilation and RED closure', async (
  _label, modules, fields,
) => {
  const version = versionFor(modules, fields);
  const before = JSON.stringify(version);
  const ordinary = compilePublishedTemplateRequirements(version);
  const red = await resolve(version);
  expect(JSON.parse(red.modules[0].fieldDefinitionsJson)).toEqual(ordinary.modules[0].fields);
  expect(ordinary.modules[0].fields).toHaveLength(1);
  expect(red.contentHash).toBe(version.contentHash);
  expect(red.publicationAuditId).toBe('audit1');
  expect(JSON.stringify(version)).toBe(before);
  const child = buildRedSuccessorModule({
    template: red, module: red.modules[0], index: 0, executionId: 'child-1',
    assetTypeKey: 'furnace', assetNumber: 7, actorUid: 'si1', actorName: 'SI',
    at: '2026-09-20T00:00:00.000Z',
  }).data;
  expect(moduleMissingRequiredClosureEvidence({...child, status: 'accepted'})).toBe(true);
  expect(moduleMissingRequiredClosureEvidence({
    ...child, status: 'accepted',
    responsesJson: JSON.stringify([{key: 'thickness', fieldType: 'number', value: 42}]),
  })).toBe(false);
});

test.each([
  ['normalized duplicate modules', [moduleRow(), moduleRow('red_01')], [reading()], 'duplicate-module-code'],
  ['duplicate module identities', [moduleRow('RED-01', {id: 'same'}), moduleRow('RED-02', {id: 'same'})],
    [reading()], 'duplicate-module-identity'],
  ['conflicting module aliases', [moduleRow('RED-01', {code: 'RED-02'})], [reading()], 'module-code-ambiguous'],
  ['empty semantic module code', [moduleRow('---')], [], 'module-code-invalid'],
  ['two unowned required fields', [moduleRow()],
    [reading({moduleCode: undefined}), reading({moduleCode: undefined, key: 'temperature'})], 'field-module-missing'],
  ['unknown required field owner', [moduleRow()], [reading({moduleCode: 'RED-99'})], 'field-module-unknown'],
  ['contradictory owner aliases', [moduleRow(), moduleRow('RED-02')],
    [reading({ownerModuleCode: 'RED-02'})], 'field-module-ambiguous'],
  ['conflicting code and identity', [moduleRow('RED-01', {id: 'module-1'}), moduleRow('RED-02', {id: 'module-2'})],
    [reading({ownerModuleId: 'module-2'})], 'field-module-ambiguous'],
  ['ambiguous legacy identity versus code', [moduleRow('RED-01', {id: 'RED-02'}), moduleRow('RED-02')],
    [reading({moduleCode: undefined, moduleId: 'RED-02'})], 'field-module-ambiguous'],
  ['embedded list omits required reading', [moduleRow('RED-01', {fields: [reading({key: 'other'})]})],
    [reading()], 'module-field-definitions-conflict'],
  ['embedded list weakens required reading', [moduleRow('RED-01', {fields: [reading({isRequired: false})]})],
    [reading()], 'module-field-definitions-conflict'],
  ['embedded list changes reading unit', [moduleRow('RED-01', {fields: [reading({unit: 'cm'})]})],
    [reading()], 'module-field-definitions-conflict'],
])('%s fails closed in both producers', async (_label, modules, fields, reasonCode) => {
  const version = versionFor(modules, fields);
  expect(() => compilePublishedTemplateRequirements(version)).toThrow();
  try {
    compilePublishedTemplateRequirements(version);
  } catch (error) {
    expect(error.details.reasonCode).toBe(reasonCode);
  }
  await expect(resolve(version)).rejects.toMatchObject({
    code: 'red-successor-template-unconfigured', details: {reasonCode},
  });
});

test('semantic comparison preserves supported aliases without rewriting keys', () => {
  expect(normalizeSemanticKey(' RED & Test-01 ')).toBe('redandtest01');
  expect(normalizeSemanticKey('red-and-test_01')).toBe('redandtest01');
});

test.each([
  ['package document identity', {}, {packageOverrides: {firestoreId: 'other'}}, 'package-identity-mismatch'],
  ['version document identity', {firestoreId: 'other'}, {}, 'version-identity-mismatch'],
  ['package latest version', {}, {packageOverrides: {latestVersionNumber: 2}}, 'package-version-number-mismatch'],
  ['arbitrary hash', {contentHash: 'nonempty-but-not-governed'}, {}, 'version-hash-invalid'],
  ['well-shaped mismatching hash', {contentHash: `tg2-sha256:${'a'.repeat(64)}`}, {}, 'version-hash-mismatch'],
  ['payload changed after publication', {fieldDefinitionsJson: JSON.stringify([reading({unit: 'cm'})])}, {}, 'version-hash-mismatch'],
  ['publishing actor missing', {publishedByUid: null}, {}, 'published-actor-missing'],
  ['publication audit missing', {}, {omitAudit: true}, 'publication-audit-missing'],
  ['audit actor mismatch', {}, {auditOverrides: {performedByUid: 'other'}}, 'publication-audit-missing'],
  ['audit hash mismatch', {}, {auditOverrides: {afterHash: 'other'}}, 'publication-audit-missing'],
  ['audit document identity mismatch', {}, {auditOverrides: {firestoreId: 'other'}}, 'publication-audit-missing'],
  ['equally authoritative audit ambiguity', {}, {duplicateAudit: true}, 'publication-audit-ambiguous'],
])('%s is rejected by the shared proof and automatic RED transaction', async (
  _label, versionOverrides, options, reasonCode,
) => {
  const version = {...versionFor([moduleRow()], [reading()]), ...versionOverrides};
  const audit = auditFixture({afterHash: version.contentHash, ...options.auditOverrides});
  const audits = options.omitAudit ? [] : [{id: 'audit1', exists: true, data: () => audit}];
  if (options.duplicateAudit) audits.push({id: 'audit2', exists: true, data: () => ({...audit, firestoreId: 'audit2'})});
  const ordinaryProof = () => validatePublishedTemplatePublication({
    request: {packageId: 'pkg1', versionId: 'ver1', expectedVersionNumber: version.versionNumber, expectedContentHash: version.contentHash},
    packageData: packageFixture(options.packageOverrides), versionData: version,
  }).requireAudit(audits);
  expect(ordinaryProof).toThrow();
  try { ordinaryProof(); } catch (error) { expect(error.details.reasonCode).toBe(reasonCode); }
  await expect(resolve(version, options)).rejects.toMatchObject({
    code: 'red-successor-template-unconfigured', details: {reasonCode},
  });
});

const installedTargetSnapshot = (referenceOverrides = {}, snapshotOverrides = {}) => ({
  jobName: 'Furnace installed component', assetType: 'furnace',
  assetHierarchyRefJson: JSON.stringify({
    schemaVersion: 2, scope: 'installedComponent',
    assetClassId: 'class-furnace', assetClassCode: 'FR', assetClassName: 'Furnace',
    nodeId: 'burner-block', nodeVersion: 1, nodeName: 'Burner block',
    assetInstanceId: 'furnace-7', assetInstanceVersion: 1, assetNumber: 7,
    assetInstanceName: 'Furnace 7', componentInstanceId: 'block-7', componentInstanceVersion: 1,
    ownershipStatus: 'confirmed', ownerDiscipline: 'RED', accountableRoleKeys: ['refractory'],
    ...referenceOverrides,
  }),
  ...snapshotOverrides,
});
const targetVersion = (snapshot) => {
  const version = versionFor([moduleRow()], [reading()]);
  version.jobTemplateSnapshotJson = JSON.stringify(snapshot);
  version.contentHash = computeTemplateVersionContentHash(version);
  return version;
};

test.each([
  ['declared equipment type', {}, {assetType: 'base'}, furnaceTarget, 'assignment-asset-type-mismatch'],
  ['installed equipment number', {assetNumber: 8}, {}, furnaceTarget, 'custom-snapshot-asset-number-mismatch'],
  ['governed equipment class', {assetClassId: 'class-base'}, {}, furnaceTarget, 'assignment-asset-class-mismatch'],
  ['installed equipment identity', {assetInstanceId: 'furnace-8'}, {}, furnaceTarget, 'assignment-asset-instance-mismatch'],
  ['missing parent governed identity', {}, {}, {...furnaceTarget, assetClassId: null, assetInstanceId: null}, 'assignment-target-identity-required'],
])('%s cannot be changed by a correctly published RED template', async (
  _label, referenceOverrides, snapshotOverrides, target, reasonCode,
) => {
  const version = targetVersion(installedTargetSnapshot(referenceOverrides, snapshotOverrides));
  expect(() => validatePublishedTemplateTarget(version, target)).toThrow();
  await expect(resolve(version, {target})).rejects.toMatchObject({
    code: 'red-successor-template-unconfigured', details: {reasonCode},
  });
});

test('matching published installed scope retains the current parent physical subject', async () => {
  const version = targetVersion(installedTargetSnapshot());
  expect(() => validatePublishedTemplateTarget(version, furnaceTarget)).not.toThrow();
  const result = await resolve(version, {registry: {
    'asset_instances/furnace-7': {version: 1, status: 'active'},
    'asset_hierarchy_nodes/burner-block': {schemaVersion: 1, nodeId: 'burner-block', assetClassId: 'class-furnace', version: 1, status: 'active'},
    'asset_component_instances/block-7': {schemaVersion: 1, componentInstanceId: 'block-7', assetClassId: 'class-furnace', assetInstanceId: 'furnace-7', assetNumber: 7,
      version: 1, status: 'active', definitionNodeId: 'burner-block', definitionNodeVersion: 1, assetInstanceVersionAtMutation: 1,
      ownershipStatus: 'confirmed', ownerDiscipline: 'RED', accountableRoleKeys: ['refractory']},
  }});
  expect(result.contentHash).toBe(version.contentHash);
  expect(result.publicationAuditId).toBe('audit1');
  expect(JSON.parse(result.modules[0].fieldDefinitionsJson)).toHaveLength(1);
});
