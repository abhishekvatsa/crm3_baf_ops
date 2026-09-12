// Deliberately opt-in fixture generator: execute the actual recorded deployed
// source graph in memory. It never modifies source, compiled output or receipts.
const {execFileSync} = require('child_process');
const {createHash} = require('crypto');
const Module = require('module');
const path = require('path');
const ts = require('typescript');

async function captureLegacyFindingAdjudication() {
  const sourceCommit = 'c00c77e2';
  const repository = path.resolve(__dirname, '../../..');
  const modules = new Map(); const sourceSha256 = {};
  const load = (relative) => {
    relative = path.posix.normalize(relative);
    if (modules.has(relative)) return modules.get(relative).exports;
    const source = execFileSync('git', ['show', `${sourceCommit}:functions/src/${relative}.ts`],
      {cwd: repository, encoding: 'utf8', maxBuffer: 4 * 1024 * 1024});
    sourceSha256[`${relative}.ts`] = createHash('sha256').update(source).digest('hex');
    const filename = path.join(repository, 'functions/lib', `${relative}.js`);
    const loaded = new Module(filename, module);
    loaded.filename = filename; loaded.paths = Module._nodeModulePaths(path.dirname(filename));
    const externalRequire = Module.createRequire(filename);
    loaded.require = (specifier) => specifier.startsWith('.') ?
      load(path.posix.join(path.posix.dirname(relative), specifier)) : externalRequire(specifier);
    modules.set(relative, loaded);
    loaded._compile(ts.transpileModule(source, {compilerOptions: {
      target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS, esModuleInterop: true,
    }}).outputText, filename);
    return loaded.exports;
  };
  const {MaintenanceWorkflowCommandService} = load('maintenanceWorkflow/dispatcher');
  const {MemoryWorkflowStore} = load('maintenanceWorkflow/memoryStore');
  const store = new MemoryWorkflowStore();
  const actor = {uid: 'admin-legacy', name: 'Legacy Admin'};
  store.seed(`users/${actor.uid}`, {name: actor.name, isApproved: true, roles: ['admin']});
  store.seed('inspection_campaigns/legacy-campaign', {schemaVersion: 1, campaignId: 'legacy-campaign', status: 'open', version: 4});
  store.seed('inspection_findings/legacy-finding', {schemaVersion: 1, findingId: 'legacy-finding',
    campaignId: 'legacy-campaign', status: 'open', version: 2});
  const command = {commandId: 'adjudicateInspectionFinding_legacy-confirmed', commandType: 'adjudicateInspectionFinding',
    aggregateId: 'legacy-campaign', expectedVersion: 4,
    payload: {findingId: 'legacy-finding', status: 'acceptedCondition', reason: 'SI reviewed the historical observation.'}};
  const accepted = await new MaintenanceWorkflowCommandService(store).execute(command,
    {actor, serverNow: new Date('2026-09-07T12:00:00.000Z')});
  return {provenance: {sourceCommit, sourceSha256,
    description: 'Actual old deployed source graph transpiled in memory; no current handler or fabricated receipt hash.'},
  command, actor, accepted, documents: store.entries()};
}
module.exports = {captureLegacyFindingAdjudication};
