#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {fileURLToPath} from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..', '..');
const policyPath = path.join(root, 'governance', 'maintenance_workflow_policy_v1.json');
const tsPath = path.join(root, 'functions', 'src', 'maintenanceWorkflow', 'policy.generated.ts');
const dartPath = path.join(root, 'lib', 'features', 'maintenance_workflow', 'domain', 'workflow_policy_generated.dart');
const rulesPath = path.join(root, 'firestore.rules');
const policy = JSON.parse(fs.readFileSync(policyPath, 'utf8'));

const q = (value) => JSON.stringify(value);
const dartQ = (value) => `'${String(value).replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'`;
const dartSet = (values) => `<String>{${values.map(dartQ).join(', ')}}`;

function workflowRoleUniverse() {
  const roles = new Set(policy.laneSetFinalizerRoles);
  for (const lane of policy.lanes) {
    for (const role of lane.ackRoles) roles.add(role);
    for (const role of lane.workRoles) roles.add(role);
    for (const role of lane.closeRoles) roles.add(role);
  }
  return [...roles];
}


const disciplineAliases = Object.freeze({
  electrical: ['electrical'],
  mechanical: ['mechanical'],
  instrumentation: ['instrumentation', 'instrument', 'ia', 'iAndA', 'instrumentationAndAutomation', 'instrumentationAutomation'],
  operations: ['operations'],
  shiftInCharge: ['shiftInCharge'],
  emd: ['emd'],
  refractory: ['refractory'],
  safety: ['safety'],
  admin: ['admin'],
  shared: ['shared'],
  others: ['others'],
});

function renderRulesRoleExpression(roleMap) {
  const clauses = [];
  for (const [discipline, roles] of Object.entries(roleMap)) {
    const aliases = disciplineAliases[discipline] ?? [discipline];
    const disciplineTest = aliases.length === 1
      ? `discipline == ${q(aliases[0]).replaceAll('"', "'")}`
      : `discipline in [${aliases.map((value) => q(value).replaceAll('"', "'")).join(', ')}]`;
    clauses.push(`(${disciplineTest} && roles.hasAny([${roles.map((role) => q(role).replaceAll('"', "'")).join(', ')}]))`);
  }
  return clauses.join('\n          || ');
}

function renderRulesPolicyBlock() {
  const workRoles = policy.moduleDisciplineWorkRoles ?? {};
  const submitRoles = policy.moduleDisciplineSubmitRoles ?? workRoles;
  const work = renderRulesRoleExpression(workRoles);
  const submit = JSON.stringify(submitRoles) === JSON.stringify(workRoles)
    ? 'rolesCanSaveJobModuleWork(roles, discipline)'
    : renderRulesRoleExpression(submitRoles);
  const moderators = (policy.moduleLifecycleModeratorRoles ?? []).map((role) => q(role).replaceAll('"', "'")).join(', ');
  return `    // BEGIN GENERATED WORKFLOW MODULE AUTHORITY\n` +
    `    // Source: governance/maintenance_workflow_policy_v1.json\n` +
    `    function rolesCanSaveJobModuleWork(roles, discipline) {\n` +
    `      return ${work};\n` +
    `    }\n\n` +
    `    function rolesAreModuleLifecycleModerator(roles) {\n` +
    `      return roles.hasAny([${moderators}]);\n` +
    `    }\n\n` +
    `    function rolesCanSubmitJobModuleDiscipline(roles, discipline) {\n` +
    `      return ${submit};\n` +
    `    }\n` +
    `    // END GENERATED WORKFLOW MODULE AUTHORITY`;
}

function rulesWithGeneratedPolicy(current) {
  const block = renderRulesPolicyBlock();
  const marker = /    \/\/ BEGIN GENERATED WORKFLOW MODULE AUTHORITY[\s\S]*?    \/\/ END GENERATED WORKFLOW MODULE AUTHORITY/;
  if (marker.test(current)) return current.replace(marker, block);
  const legacy = /    function rolesCanSaveJobModuleWork\(roles, discipline\) \{[\s\S]*?    function jobModuleParentExistsAndIsOpen\(\) \{/;
  if (!legacy.test(current)) throw new Error('Could not locate workflow module authority block in firestore.rules');
  return current.replace(legacy, `${block}\n\n    function jobModuleParentExistsAndIsOpen() {`);
}

function renderTs() {
  const lanes = Object.fromEntries(policy.lanes.map((lane) => [lane.key, lane]));
  const roleUniverse = workflowRoleUniverse();
  const moduleLaneMap = policy.moduleDisciplineLaneMap ?? {};
  const moduleWorkRoles = policy.moduleDisciplineWorkRoles ?? {};
  const moduleSubmitRoles = policy.moduleDisciplineSubmitRoles ?? moduleWorkRoles;
  return `// GENERATED FILE. Source: governance/maintenance_workflow_policy_v1.json\n` +
    `// Do not edit manually.\n` +
    `export const WORKFLOW_POLICY_SCHEMA_VERSION = ${policy.schemaVersion} as const;\n` +
    `export const WORKFLOW_POLICY_ID = ${q(policy.policyId)} as const;\n` +
    `export const ONLINE_ONLY_LIFECYCLE_COMMANDS = ${policy.onlineOnlyLifecycleCommands} as const;\n` +
    `export const LANE_SET_FINALIZER_ROLES = ${JSON.stringify(policy.laneSetFinalizerRoles)} as const;\n` +
    `export const MODULE_LIFECYCLE_MODERATOR_ROLES = ${JSON.stringify(policy.moduleLifecycleModeratorRoles ?? [])} as const;\n` +
    `export const COMMAND_AUTHORITY_ROLES = Object.freeze(${JSON.stringify(policy.commandAuthorityRoles ?? {})}) as Readonly<Record<string, readonly string[]>>;\n` +
    `export const WORKFLOW_ROLE_UNIVERSE = ${JSON.stringify(roleUniverse)} as const;\n` +
    `export const RED_APPLICABLE_ASSET_TYPES = new Set(${JSON.stringify(policy.redApplicableAssetTypes)});\n` +
    `export const STAND_PREPARATION_ASSET_TYPES = new Set(${JSON.stringify(policy.standPreparationAssetTypes)});\n` +
    `export const WORKFLOW_CLOCKS_MINUTES = Object.freeze(${JSON.stringify(policy.clocksMinutes)});\n` +
    `export const LANE_POLICY = Object.freeze(${JSON.stringify(lanes)}) as Readonly<Record<string, Readonly<{key:string;code:string;name:string;ackRoles:readonly string[];workRoles:readonly string[];closeRoles:readonly string[];delegated?:boolean;delegationBasis?:string}>>>;\n` +
    `export const MODULE_DISCIPLINE_LANE_MAP = Object.freeze(${JSON.stringify({})}) as Readonly<Record<string, string>>;\n`.replace('{}', JSON.stringify(moduleLaneMap)) +
    `export const MODULE_DISCIPLINE_WORK_ROLES = Object.freeze(${JSON.stringify({})}) as Readonly<Record<string, readonly string[]>>;\n`.replace('{}', JSON.stringify(moduleWorkRoles)) +
    `export const MODULE_DISCIPLINE_SUBMIT_ROLES = Object.freeze(${JSON.stringify({})}) as Readonly<Record<string, readonly string[]>>;\n`.replace('{}', JSON.stringify(moduleSubmitRoles));
}

function renderDart() {
  const roleUniverse = workflowRoleUniverse();
  const moduleLaneRows = Object.entries(policy.moduleDisciplineLaneMap ?? {}).map(([key, value]) => `    ${dartQ(key)}: ${dartQ(value)},`).join('\n');
  const moduleWorkRows = Object.entries(policy.moduleDisciplineWorkRoles ?? {}).map(([key, value]) => `    ${dartQ(key)}: ${dartSet(value)},`).join('\n');
  const moduleSubmitRows = Object.entries(policy.moduleDisciplineSubmitRoles ?? policy.moduleDisciplineWorkRoles ?? {}).map(([key, value]) => `    ${dartQ(key)}: ${dartSet(value)},`).join('\n');
  const laneRows = policy.lanes.map((lane) => `    ${dartQ(lane.key)}: WorkflowLanePolicyGenerated(\n` +
    `      key: ${dartQ(lane.key)}, code: ${dartQ(lane.code)}, name: ${dartQ(lane.name)},\n` +
    `      acknowledgementRoles: ${dartSet(lane.ackRoles)},\n` +
    `      workRoles: ${dartSet(lane.workRoles)},\n` +
    `      closureRoles: ${dartSet(lane.closeRoles)},\n` +
    `      delegated: ${lane.delegated === true},\n` +
    `      delegationBasis: ${lane.delegationBasis == null ? 'null' : dartQ(lane.delegationBasis)},\n` +
    `    ),`).join('\n');
  return `// GENERATED FILE. Source: governance/maintenance_workflow_policy_v1.json\n` +
    `// Do not edit manually.\n` +
    `abstract final class WorkflowPolicyGenerated {\n` +
    `  static const int schemaVersion = ${policy.schemaVersion};\n` +
    `  static const String policyId = ${dartQ(policy.policyId)};\n` +
    `  static const bool onlineOnlyLifecycleCommands = ${policy.onlineOnlyLifecycleCommands};\n` +
    `  static const Set<String> laneSetFinalizerRoles = ${dartSet(policy.laneSetFinalizerRoles)};\n` +
    `  static const Set<String> moduleLifecycleModeratorRoles = ${dartSet(policy.moduleLifecycleModeratorRoles ?? [])};\n` +
    `  static const Map<String, Set<String>> commandAuthorityRoles = <String, Set<String>>{\n${Object.entries(policy.commandAuthorityRoles ?? {}).map(([key, value]) => `    ${dartQ(key)}: ${dartSet(value)},`).join('\n')}\n  };\n` +
    `  static const Set<String> workflowRoleUniverse = ${dartSet(roleUniverse)};\n` +
    `  static const Set<String> redApplicableAssetTypes = ${dartSet(policy.redApplicableAssetTypes)};\n` +
    `  static const Set<String> standPreparationAssetTypes = ${dartSet(policy.standPreparationAssetTypes)};\n` +
    `  static const int criticalAcknowledgementMinutes = ${policy.clocksMinutes.criticalAcknowledgement};\n` +
    `  static const int normalAcknowledgementMinutes = ${policy.clocksMinutes.normalAcknowledgement};\n` +
    `  static const int complianceAcknowledgementMinutes = ${policy.clocksMinutes.complianceAcknowledgement};\n` +
    `  static const int complianceAfterConditionMinutes = ${policy.clocksMinutes.complianceAfterCondition};\n` +
    `  static const Map<String, WorkflowLanePolicyGenerated> lanes = <String, WorkflowLanePolicyGenerated>{\n${laneRows}\n  };\n` +
    `  static const Map<String, String> moduleDisciplineLaneMap = <String, String>{\n${moduleLaneRows}\n  };\n` +
    `  static const Map<String, Set<String>> moduleDisciplineWorkRoles = <String, Set<String>>{\n${moduleWorkRows}\n  };\n` +
    `  static const Map<String, Set<String>> moduleDisciplineSubmitRoles = <String, Set<String>>{\n${moduleSubmitRows}\n  };\n` +
    `}\n\n` +
    `class WorkflowLanePolicyGenerated {\n` +
    `  final String key;\n  final String code;\n  final String name;\n` +
    `  final Set<String> acknowledgementRoles;\n  final Set<String> workRoles;\n` +
    `  final Set<String> closureRoles;\n  final bool delegated;\n  final String? delegationBasis;\n` +
    `  const WorkflowLanePolicyGenerated({required this.key, required this.code, required this.name, required this.acknowledgementRoles, required this.workRoles, required this.closureRoles, required this.delegated, required this.delegationBasis});\n` +
    `}\n`;
}

const currentRules = fs.readFileSync(rulesPath, 'utf8');
const outputs = [[tsPath, renderTs()], [dartPath, renderDart()], [rulesPath, rulesWithGeneratedPolicy(currentRules)]];
const check = process.argv.includes('--check');
let failed = false;
for (const [file, content] of outputs) {
  if (check) {
    const current = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
    if (current !== content) {
      console.error(`OUT_OF_DATE ${path.relative(root, file)}`);
      failed = true;
    } else {
      console.log(`PASS ${path.relative(root, file)}`);
    }
  } else {
    fs.mkdirSync(path.dirname(file), {recursive: true});
    fs.writeFileSync(file, content);
    console.log(`WROTE ${path.relative(root, file)}`);
  }
}
if (failed) process.exit(1);
