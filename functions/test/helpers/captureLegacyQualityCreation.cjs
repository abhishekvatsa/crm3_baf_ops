// Deliberately opt-in fixture generator: execute the actual recorded deployed
// source graph in memory. It never modifies source, compiled output or receipts.
const {execFileSync} = require('child_process');
const {createHash} = require('crypto');
const Module = require('module');
const path = require('path');
const ts = require('typescript');

async function captureLegacyQualityCreation({db, data, actorUid, timestampFromDate}) {
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
  const {mutateQualityWithDb} = load('qualityMutation');
  const accepted = await mutateQualityWithDb({db, data, authUid: actorUid,
    timestampFromDate, now: () => new Date('2026-09-07T12:00:00.000Z')});
  return {provenance: {sourceCommit, sourceSha256,
    description: 'Actual deployed c00 quality source graph transpiled in memory; accepted audit and receipt emitted by its handler.'},
    request: data, actorUid, accepted};
}
module.exports = {captureLegacyQualityCreation};
