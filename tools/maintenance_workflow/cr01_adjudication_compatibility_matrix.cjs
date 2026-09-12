'use strict';
// CR-01 rollout compatibility probe.
//
// Loads two compiled backends in one process and runs identical client request
// shapes against each, so "existing" and "new" are exercised by the same
// inputs. It reports observed behaviour and asserts nothing: the question is
// what happens across a transition, not whether a chosen answer is wanted.
//
// The cross-version replay rows do not hand-craft a receipt. They execute the
// command on one backend, which writes a real receipt, then replay the same
// command against the other backend using the store that receipt lives in.
// A fabricated receipt would test the fixture rather than the system.
//
//   BAF_BASELINE_ROOT=<baseline>/functions/lib \
//     node tools/maintenance_workflow/cr01_adjudication_compatibility_matrix.cjs
const path = require('node:path');

const newRoot = process.env.BAF_COMPILED_ROOT ||
  path.resolve(__dirname, '../../functions/lib');
const oldRoot = process.env.BAF_BASELINE_ROOT;
if (!oldRoot) {
  console.error('Set BAF_BASELINE_ROOT to the baseline functions/lib.');
  process.exit(2);
}

const load = (root) => ({
  root,
  MemoryWorkflowStore:
    require(path.join(root, 'maintenanceWorkflow/memoryStore'))
      .MemoryWorkflowStore,
  Service: require(path.join(root, 'maintenanceWorkflow/dispatcher'))
    .MaintenanceWorkflowCommandService,
});
const backends = {existing: load(oldRoot), new: load(newRoot)};

const context = {
  actor: {uid: 'admin-1', name: 'Reviewer'},
  serverNow: new Date('2026-09-11T08:00:00.000Z'),
};

// The finding is at revision 5. A request that reviewed revision 5 is current;
// one that reviewed revision 4 read evidence that has since been superseded.
function store(backend, findingVersion = 5) {
  const value = new backend.MemoryWorkflowStore();
  value.seed('users/admin-1',
    {isApproved: true, roles: ['admin'], name: 'Reviewer'});
  value.seed('inspection_campaigns/campaign-1', {version: 3});
  value.seed('inspection_findings/finding-1', {
    campaignId: 'campaign-1', version: findingVersion, status: 'open',
    currentObservationId: 'observation-new',
  });
  return value;
}

// The shape a client that predates CR-01 constructs.
const oldClient = {
  findingId: 'finding-1',
  status: 'acceptedCondition',
  reason: 'Reviewed latest evidence.',
};
// The shape a CR-01 client constructs, carrying the revision it displayed.
const newClient = (version) => ({
  findingId: 'finding-1',
  expectedFindingVersion: version,
  status: 'acceptedCondition',
  reason: 'Reviewed latest evidence.',
});

const command = (payload, commandId = 'finding-adjudication-1') => ({
  commandId, commandType: 'adjudicateInspectionFinding',
  aggregateId: 'campaign-1', expectedVersion: 3, payload,
});

async function run(backend, value, request) {
  try {
    const receipt = await new backend.Service(value).execute(request, context);
    const finding = value.read('inspection_findings/finding-1');
    return {outcome: 'accepted', detail:
      `${receipt.resultKey} finding->v${finding && finding.version}`};
  } catch (error) {
    const reason = error && error.details ? error.details.reasonCode : null;
    return {outcome: 'refused', detail:
      `${error && error.code ? error.code : '(none)'}` +
      `${reason ? ` / ${reason}` : ''}`};
  }
}

const rows = [];
const record = async (label, backend, value, request) => {
  const result = await run(backend, value, request);
  rows.push({label, ...result});
};

(async () => {
  // --- the four stated combinations -------------------------------------
  await record('existing client -> existing backend',
    backends.existing, store(backends.existing), command(oldClient));
  await record('new client      -> existing backend',
    backends.existing, store(backends.existing), command(newClient(5)));
  await record('existing client -> new backend',
    backends.new, store(backends.new), command(oldClient));
  await record('new client      -> new backend (current revision)',
    backends.new, store(backends.new), command(newClient(5)));
  await record('new client      -> new backend (stale revision)',
    backends.new, store(backends.new), command(newClient(4)));

  // --- requests that already existed when the transition happened --------
  // Accepted before the transition: a real receipt is written by the old
  // backend, then the identical command is replayed against the new one.
  const accepted = store(backends.existing);
  await record('  [setup] accepted on existing backend',
    backends.existing, accepted, command(oldClient));
  await record('ACCEPTED before transition, replayed on new backend',
    backends.new, accepted, command(oldClient));

  // Retained but never accepted: no receipt exists, so the new backend sees
  // an ordinary first execution carrying the old payload shape.
  await record('UNEXECUTED retained request, sent to new backend',
    backends.new, store(backends.new),
    command(oldClient, 'finding-adjudication-never-ran'));

  console.log(`existing backend: ${oldRoot}`);
  console.log(`new backend:      ${newRoot}\n`);
  for (const row of rows) {
    console.log(`  ${row.outcome.padEnd(8)} | ${row.label.padEnd(52)} | ${row.detail}`);
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
