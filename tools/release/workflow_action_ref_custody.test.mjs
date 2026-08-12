import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import {
  auditWorkflowActionReferences,
  collectActionReferences,
  findMutableActionReferences,
} from './workflow_action_ref_custody.mjs';
import {
  discoverWorkflowPaths,
  parseWorkflow,
  repositoryRoot,
} from './workflow_dispatch_input_custody.mjs';

test('rejects mutable step actions and reusable job workflows', () => {
  const workflow = parseWorkflow([
    'jobs:',
    '  reused:',
    '    uses: owner/repository/.github/workflows/build.yml@main',
    '  build:',
    '    runs-on: ubuntu-latest',
    '    steps:',
    '      - name: Mutable action',
    '        uses: actions/checkout@v4',
    '      - name: Mutable container',
    '        uses: docker://alpine:3.20',
  ].join('\n'));

  assert.deepEqual(
    findMutableActionReferences(workflow).map((finding) => ({
      location: finding.location,
      reference: finding.reference,
      reason: finding.reason,
    })),
    [
      {
        location: 'job',
        reference: 'owner/repository/.github/workflows/build.yml@main',
        reason: 'action-not-commit-pinned',
      },
      {
        location: 'step',
        reference: 'actions/checkout@v4',
        reason: 'action-not-commit-pinned',
      },
      {
        location: 'step',
        reference: 'docker://alpine:3.20',
        reason: 'container-not-digest-pinned',
      },
    ],
  );
});

test('accepts commit-pinned, digest-pinned, and local action references', () => {
  const workflow = parseWorkflow([
    'jobs:',
    '  build:',
    '    runs-on: ubuntu-latest',
    '    steps:',
    '      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1',
    '      - uses: ./tools/local-action',
    "      - uses: 'docker://alpine@sha256:" +
      "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'",
  ].join('\n'));

  assert.deepEqual(findMutableActionReferences(workflow), []);
});

test('all repository workflow action references are immutable', () => {
  const workflowPaths = discoverWorkflowPaths();
  assert.deepEqual(
    workflowPaths.map((workflowPath) =>
      path.relative(repositoryRoot, workflowPath)),
    [
      path.join('.github', 'workflows', 'production-artifact.yml'),
      path.join('.github', 'workflows', 'release-gate.yml'),
      path.join('.github', 'workflows', 'verification-artifact.yml'),
    ],
  );
  assert.deepEqual(auditWorkflowActionReferences(), []);

  const referenceCount = workflowPaths.reduce((count, workflowPath) => {
    const workflow = parseWorkflow(
      fs.readFileSync(workflowPath, 'utf8'),
      workflowPath,
    );
    return count + collectActionReferences(workflow, workflowPath).length;
  }, 0);
  assert.equal(referenceCount, 27);
});
