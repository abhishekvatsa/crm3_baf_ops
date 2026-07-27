import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import {
  auditManualWorkflows,
  discoverManualWorkflowPaths,
  findUnsafeRunInterpolations,
  parseWorkflow,
  repositoryRoot,
} from './workflow_dispatch_input_custody.mjs';

test('rejects dispatch expressions in block or inline script source', () => {
  const unsafe = parseWorkflow([
    'on:',
    '  workflow_dispatch:',
    '    inputs:',
    '      release_id:',
    '        type: string',
    'jobs:',
    '  build:',
    '    runs-on: ubuntu-latest',
    '    steps:',
    '      - name: unsafe',
    '        shell: pwsh',
    '        run: |',
    "          Write-Output '${{ inputs.release_id }}'",
    '      - name: unsafe inline',
    '        shell: bash',
    '        run: echo "${{ github.event.inputs.release_id }}"',
  ].join('\n'));

  assert.deepEqual(
    findUnsafeRunInterpolations(unsafe).map((finding) => finding.expressions),
    [
      ['${{ inputs.release_id }}'],
      ['${{ github.event.inputs.release_id }}'],
    ],
  );
});

test('accepts dispatch expressions mapped to environment data', () => {
  const safe = parseWorkflow([
    'on:',
    '  workflow_dispatch:',
    '    inputs:',
    '      release_id:',
    '        type: string',
    'jobs:',
    '  build:',
    '    runs-on: ubuntu-latest',
    '    env:',
    '      CRM_DISPATCH_RELEASE_ID: ${{ inputs.release_id }}',
    '    steps:',
    '      - name: safe',
    '        shell: bash',
    '        run: |',
    '          printf "%s\\n" "$CRM_DISPATCH_RELEASE_ID"',
  ].join('\n'));

  assert.deepEqual(findUnsafeRunInterpolations(safe), []);
});

test('all current manual workflows keep dispatch inputs out of run blocks', () => {
  const workflowPaths = discoverManualWorkflowPaths();
  assert.deepEqual(
    workflowPaths.map((workflowPath) => path.relative(repositoryRoot, workflowPath)),
    [
      path.join('.github', 'workflows', 'production-artifact.yml'),
      path.join('.github', 'workflows', 'verification-artifact.yml'),
    ],
  );
  assert.deepEqual(auditManualWorkflows(), []);

  const sources = workflowPaths.map((workflowPath) =>
    fs.readFileSync(workflowPath, 'utf8'));
  assert.ok(sources.every((source) => source.includes('CRM_DISPATCH_')));
  assert.ok(sources.every((source) =>
    source.includes('^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$')));
});

test('C-01 closure is bound to exact merge and post-merge evidence', () => {
  const ledger = JSON.parse(fs.readFileSync(
    path.join(repositoryRoot, 'governance', 'programme-ledger.json'),
    'utf8',
  ));
  const finding = ledger.technicalFindings
    .filter((entry) => entry.findingId === 'C-01');
  assert.equal(finding.length, 1);
  assert.equal(finding[0].currentStatus, 'CLOSED');
  assert.deepEqual(
    finding[0].statusHistory.map((entry) => entry.status),
    ['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
  );
  assert.equal(finding[0].evidence.length, 1);
  assert.deepEqual(
    finding[0].evidence[0],
    {
      repository: 'abhishekvatsa/crm3_baf_ops',
      pullRequest: 57,
      headCommit: '7b3582768c84fef276b08617212efe1e6a996f38',
      sourceTree: '9508441e7261ca8bdeb80afab31b0a63df2f55f3',
      mergeCommit: '34e8f4a314fcd03991d535d050614b96eeaf3204',
      mergeTree: '9508441e7261ca8bdeb80afab31b0a63df2f55f3',
      postMergeWorkflowRun: 30293820019,
      postMergeWorkflowUrl:
        'https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/30293820019',
      decision: 'PASS_C01_WORKFLOW_DISPATCH_INPUT_CUSTODY',
      productionWorkflowDispatched: false,
      productionMutationPerformed: false,
    },
  );
  assert.ok(finding[0].requiredExitEvidence.length >= 4);
  assert.ok(finding[0].reArmTriggers.length >= 5);

  const decision = fs.readFileSync(
    path.join(
      repositoryRoot,
      'docs',
      'v4_2_r1',
      'C01_WORKFLOW_DISPATCH_INPUT_CUSTODY.md',
    ),
    'utf8',
  );
  assert.match(decision, /Status: CLOSED/);
  assert.match(decision, /Pull request: #57|PR #57/);
  assert.match(decision, /Post-merge release-gate run\s+`30293820019`/);
  assert.match(decision, /PASS_C01_WORKFLOW_DISPATCH_INPUT_CUSTODY/);
  assert.match(decision, /No production workflow was dispatched/);
});
