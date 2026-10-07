'use strict';
// Fresh portable controller. Only public Git/source facts and sanitized hosted
// measurements return here; raw evidence and WIF stay inside independently V.
if (require.main !== module || process.execArgv.length !== 1 || process.execArgv[0] !== '--no-global-search-paths' ||
    ['NODE_OPTIONS', 'NODE_PATH', 'LD_PRELOAD', 'LD_LIBRARY_PATH', 'DYLD_INSERT_LIBRARIES'].some(k => process.env[k]) ||
    Object.keys(require.cache).some(file => file !== __filename)) throw Error('BUSINESS_PREREQUISITE_FRESH_ENTRY_REQUIRED');
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const {performance} = require('node:perf_hooks');
const ROOT = path.resolve(__dirname, '../..');
function need(ok) { if (!ok) throw Error('BUSINESS_PREREQUISITE_REFUSED'); }
function sha(bytes) { return crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase(); }
function initialRead(file, limit) {
  need(typeof file === 'string' && path.isAbsolute(file));
  let current = path.parse(file).root;
  for (const part of path.resolve(file).slice(current.length).split(path.sep).filter(Boolean)) {
    current = path.join(current, part); need(!fs.lstatSync(current).isSymbolicLink());
  }
  need(fs.lstatSync(file).isFile() && fs.statSync(file).size > 0 && fs.statSync(file).size <= limit);
  const bytes = fs.readFileSync(file); need(bytes.length <= limit); return bytes;
}
async function main() {
  const resumeMode = process.argv.length === 12;
  need((process.argv.length === 10 || resumeMode) && process.argv[2] === '--config' && process.argv[4] === '--config-sha256' &&
    process.argv[6] === '--input' && process.argv[8] === '--output' && /^[A-F0-9]{64}$/.test(process.argv[5]) &&
    (!resumeMode || process.argv[10] === '--resume-request'));
  const configBytes = initialRead(process.argv[3], 2 * 1024 * 1024);
  need(sha(configBytes) === process.argv[5]);
  const bootstrap = JSON.parse(configBytes.toString('utf8'));
  // The external commitment is checked with built-ins before any local code.
  for (const name of ['business31Controller.cjs', 'business31HostedProtocol.cjs']) {
    const digest = bootstrap?.controller?.files?.['tools/release/' + name];
    need(typeof digest === 'string' && /^[A-F0-9]{64}$/.test(digest) &&
      sha(initialRead(path.join(__dirname, name), 2 * 1024 * 1024)) === digest);
  }
  const p = require('./business31HostedProtocol.cjs'), c = require('./business31Controller.cjs');
  const config = c.readController31(process.argv[3], process.argv[5]);
  c.verifyController31(config, ROOT);
  const inputBytes = initialRead(process.argv[7], 128 * 1024), input = p.json(inputBytes, 128 * 1024);
  const files = c.measureFiles31(input), selected = config.selected, trust = config.replayTrust;
  const local = c.verifyLocalSelection31(config, input);
  const workingPolicy = path.join(input.repositoryRoot, 'release/production-release-policy.json');
  p.need(p.sha(initialRead(workingPolicy, 2 * 1024 * 1024)) === local.policySha256, 'CONTROLLER_WORKING_POLICY');
  const output = path.resolve(process.argv[9]);
  p.need(path.isAbsolute(process.argv[9]) && !fs.existsSync(output), 'CONTROLLER_OUTPUT');
  p.regular(path.dirname(output), true);
  const inActions = process.env.GITHUB_ACTIONS === 'true';
  let resumeBytes = null, resumed = null;
  if (resumeMode) {
    p.need(input.purpose === 'construction' && inActions, 'RESUME_CONTEXT');
    resumeBytes = initialRead(process.argv[11], 128 * 1024);
    const locator = p.json(resumeBytes, 128 * 1024);
    p.exact(locator, ['schemaVersion', 'profile', 'controllerConfigSha256', 'request'], 'RESUME_FIELDS');
    p.need(locator.schemaVersion === 1 && locator.profile === 'build31-business-prerequisite-resume-v1' &&
      locator.controllerConfigSha256 === process.argv[5], 'RESUME_CONFIG');
    resumed = c.selectedRequest31(config, locator.request);
    const q = resumed.challenge;
    p.need(resumed.runAttempt === '1' && q.purpose === 'construction' && q.fileBindings.length === 0 &&
      q.requester.kind === 'github-actions' && q.requester.runId === process.env.GITHUB_RUN_ID &&
      q.requester.runAttempt === process.env.GITHUB_RUN_ATTEMPT && Date.parse(q.requestedAtUtc) <= Date.now() &&
      Date.now() < Date.parse(q.expiresAtUtc), 'RESUME_REQUEST');
  }
  const requester = resumed ? resumed.challenge.requester : {kind: inActions ? 'github-actions' : 'local',
    runId: inActions ? process.env.GITHUB_RUN_ID : null,
    runAttempt: inActions ? process.env.GITHUB_RUN_ATTEMPT : null, invocationId: crypto.randomBytes(32).toString('hex')};
  async function parent31() {
    if (!inActions) { p.need(input.purpose !== 'construction', 'CONSTRUCTION_HOST'); return; }
    // All Actions invocations are confined to this enrolled production job.
    // Its later package check is a separate fresh purpose, not construction.
    p.need(selected.candidate.kind === 'main' && process.env.GITHUB_REPOSITORY === trust.repository.name &&
      process.env.GITHUB_SHA === selected.candidate.commit && process.env.GITHUB_REF === 'refs/heads/main' &&
      process.env.GITHUB_WORKFLOW_REF === trust.repository.name + '/' + config.requester.path + '@refs/heads/main',
    'CONSTRUCTION_CONTEXT');
    const run = await p.github31(trust, '/actions/runs/' + requester.runId, process.env.GITHUB_TOKEN);
    p.need(String(run.id) === requester.runId && String(run.run_attempt) === requester.runAttempt &&
      String(run.workflow_id) === config.requester.workflowId && run.path === config.requester.path &&
      run.head_sha === selected.candidate.commit && run.event === 'workflow_dispatch' && run.head_branch === 'main' &&
      run.status === 'in_progress' && run.conclusion === null && String(run.repository?.id) === trust.repository.id &&
      String(run.head_repository?.id) === trust.repository.id && config.requester.actorIds.includes(String(run.actor?.id)) &&
      String(run.triggering_actor?.id) === String(run.actor?.id), 'CONSTRUCTION_LIVE_RUN');
    const jobs = await p.github31(trust, '/actions/runs/' + requester.runId + '/attempts/' + requester.runAttempt + '/jobs?per_page=100', process.env.GITHUB_TOKEN);
    p.need(Number.isSafeInteger(jobs.total_count) && jobs.total_count > 0 && jobs.total_count <= 100 &&
      Array.isArray(jobs.jobs) && jobs.jobs.length === jobs.total_count, 'CONSTRUCTION_JOB_POPULATION');
    const matches = jobs.jobs.filter(j => j.name === config.requester.jobName);
    p.need(matches.length === 1 && String(matches[0].run_id) === requester.runId &&
      matches[0].head_sha === selected.candidate.commit && matches[0].status === 'in_progress' &&
      matches[0].conclusion === null && (matches[0].run_attempt === undefined ||
      String(matches[0].run_attempt) === requester.runAttempt), 'CONSTRUCTION_LIVE_JOB');
  }
  const now = Date.now(), deadline = performance.now() + config.maximumWaitSeconds * 1000;
  const challenge = resumed ? resumed.challenge : {schemaVersion: 1, nonce: crypto.randomBytes(32).toString('hex'), purpose: input.purpose,
    requestedAtUtc: new Date(now).toISOString(), expiresAtUtc: new Date(now + config.maximumWaitSeconds * 1000).toISOString(),
    requester, clientSelectionSha256: selected.clientSelectionSha256, fileBindings: files};
  p.validateChallenge31(challenge, selected.candidate);
  await parent31();
  p.validateRepository31(await p.github31(trust, '', process.env.GITHUB_TOKEN), trust);
  p.validateCandidate31(await p.github31(trust, selected.candidate.kind === 'main' ? '/git/ref/heads/main' :
    '/pulls/' + selected.candidate.pullRequest, process.env.GITHUB_TOKEN), trust, {candidate: selected.candidate});
  const data = {schemaVersion: 2, candidate: selected.candidate, descriptorPointer: selected.descriptorPointer, challenge};
  // GitHub's 2026-03-10 API returns the created run identity. Refuse an older
  // empty response; never guess the latest run or dispatch again after timeout.
  let request = resumed;
  if (!resumed) {
    const response = await p.request31('https://api.github.com/repos/' + trust.repository.name + '/actions/workflows/' + trust.workflow.id + '/dispatches', {
      method: 'POST', headers: {Accept: 'application/vnd.github+json', 'Content-Type': 'application/json',
        'X-GitHub-Api-Version': '2026-03-10', 'User-Agent': 'business31-prerequisite',
        Authorization: 'Bearer ' + p.token(process.env.GITHUB_TOKEN)},
      body: Buffer.from(JSON.stringify({ref: trust.workflow.ref.replace(/^refs\/(heads|tags)\//, ''), inputs: {request_json: JSON.stringify(data)}})),
      maxBytes: 32768
    });
    const dispatched = p.json(response.bytes, 32768);
    p.exact(dispatched, ['workflow_run_id', 'run_url', 'html_url'], 'DISPATCH_RESULT');
    p.need(Number.isSafeInteger(dispatched.workflow_run_id) && dispatched.workflow_run_id > 0, 'DISPATCH_RUN');
    const runId = String(dispatched.workflow_run_id);
    p.need(dispatched.run_url === 'https://api.github.com/repos/' + trust.repository.name + '/actions/runs/' + runId &&
      dispatched.html_url === 'https://github.com/' + trust.repository.name + '/actions/runs/' + runId, 'DISPATCH_URLS');
    request = c.selectedRequest31(config, {...data, runId, runAttempt: '1'});
  }
  const runId = request.runId;
  for (;;) {
    p.need(performance.now() < deadline && Date.now() < Date.parse(challenge.expiresAtUtc), 'PREREQUISITE_DEADLINE');
    const run = await p.github31(trust, '/actions/runs/' + runId, process.env.GITHUB_TOKEN);
    if (resumed) { p.validateRun31(run, trust, request, true); break; }
    // Check every immutable run field while permitting only finite waiting
    // states. The completed branch below requires actual successful completion.
    p.validateRun31({...run, status: 'in_progress', conclusion: null}, trust, request, false);
    if (run.status === 'completed') { p.validateRun31(run, trust, request, true); break; }
    p.need(['queued', 'in_progress', 'waiting', 'pending', 'requested'].includes(run.status) && run.conclusion === null,
      'PREREQUISITE_RUN_STATE');
    await new Promise(resolve => setTimeout(resolve, 30000));
  }
  const authenticated = await p.retrieveResult31(trust, request, process.env.GITHUB_TOKEN);
  const value = authenticated.value;
  const originalPolicy = c.verifyCommittedPolicy31(config, input, value.client.policy);
  p.need(p.sha(initialRead(workingPolicy, 2 * 1024 * 1024)) === value.client.policy.bindings.policy.sha256,
    'CONTROLLER_WORKING_POLICY');
  p.same(p.json(initialRead(workingPolicy, 2 * 1024 * 1024)), originalPolicy, 'CONTROLLER_WORKING_POLICY');
  p.same(c.measureFiles31(input), files, 'CONTROLLER_PACKAGE_CHANGED');
  p.need(initialRead(process.argv[7], 128 * 1024).equals(inputBytes), 'CONTROLLER_INPUT_CHANGED');
  p.same(c.readController31(process.argv[3], process.argv[5]), config, 'CONTROLLER_CONFIG_CHANGED');
  await parent31();
  await p.observe31(trust, request, process.env.GITHUB_TOKEN, true);
  c.verifyController31(config, ROOT);
  // Recheck local bytes after the final awaited platform reads as well.
  p.same(c.measureFiles31(input), files, 'CONTROLLER_FINAL_PACKAGE_CHANGED');
  p.need(p.sha(initialRead(workingPolicy, 2 * 1024 * 1024)) === local.policySha256,
    'CONTROLLER_FINAL_POLICY_CHANGED');
  p.need(initialRead(process.argv[7], 128 * 1024).equals(inputBytes), 'CONTROLLER_FINAL_INPUT_CHANGED');
  p.same(c.readController31(process.argv[3], process.argv[5]), config, 'CONTROLLER_FINAL_CONFIG_CHANGED');
  if (resumed) p.need(initialRead(process.argv[11], 128 * 1024).equals(resumeBytes), 'RESUME_LOCATOR_CHANGED');
  p.need(performance.now() < deadline && Date.now() < Date.parse(challenge.expiresAtUtc), 'PREREQUISITE_DEADLINE');
  const result = {schemaVersion: 1, profile: 'build31-business-prerequisite-measurement-v1', purpose: input.purpose,
    verifier: value.verifier, source: value.source, candidate: value.candidate, descriptorPointer: value.descriptorPointer,
    closurePointer: value.closurePointer, commitments: value.commitments, client: value.client, challenge,
    runId, runAttempt: request.runAttempt, artifactId: authenticated.artifactId, resultSha256: authenticated.resultSha256,
    replayMode: resumed ? 'same-parent-reauthentication' : 'fresh-dispatch',
    freshHostedReplayVerified: true, limits: {deploymentAuthorized: false, constructionAuthorized: false,
      signingAuthorized: false, distributionAuthorized: false}};
  fs.writeFileSync(output, JSON.stringify(result) + '\n', {flag: 'wx', mode: 0o600});
}
main().catch(() => { process.stderr.write('Fresh exact-source business prerequisite did not complete; no action is authorized.\n'); process.exitCode = 1; });
