import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  discoverWorkflowPaths,
  parseWorkflow,
  repositoryRoot,
} from './workflow_dispatch_input_custody.mjs';

const commitPinnedAction = /^[^@\s]+@[0-9a-f]{40}$/i;
const digestPinnedContainer =
  /^docker:\/\/[^@\s]+@sha256:[0-9a-f]{64}$/i;

export function actionReferenceReason(reference) {
  if (typeof reference !== 'string' || reference.trim() === '') {
    return 'invalid-reference';
  }

  const value = reference.trim();
  if (value.startsWith('./')) {
    return null;
  }
  if (value.startsWith('docker://')) {
    return digestPinnedContainer.test(value)
      ? null
      : 'container-not-digest-pinned';
  }
  return commitPinnedAction.test(value)
    ? null
    : 'action-not-commit-pinned';
}

export function collectActionReferences(
  workflow,
  workflowPath = '<workflow>',
) {
  const references = [];
  const jobs = workflow.jobs;
  if (jobs == null || typeof jobs !== 'object' || Array.isArray(jobs)) {
    return references;
  }

  for (const [jobName, job] of Object.entries(jobs)) {
    if (job == null || typeof job !== 'object' || Array.isArray(job)) {
      continue;
    }
    if (Object.hasOwn(job, 'uses')) {
      references.push({
        workflowPath,
        jobName,
        location: 'job',
        stepIndex: null,
        stepName: null,
        reference: job.uses,
      });
    }
    if (!Array.isArray(job.steps)) {
      continue;
    }
    job.steps.forEach((step, index) => {
      if (
        step == null
        || typeof step !== 'object'
        || Array.isArray(step)
        || !Object.hasOwn(step, 'uses')
      ) {
        return;
      }
      references.push({
        workflowPath,
        jobName,
        location: 'step',
        stepIndex: index,
        stepName: typeof step.name === 'string' ? step.name : '<unnamed>',
        reference: step.uses,
      });
    });
  }
  return references;
}

export function findMutableActionReferences(
  workflow,
  workflowPath = '<workflow>',
) {
  return collectActionReferences(workflow, workflowPath)
    .map((entry) => ({
      ...entry,
      reason: actionReferenceReason(entry.reference),
    }))
    .filter((entry) => entry.reason != null);
}

export function auditWorkflowActionReferences(root = repositoryRoot) {
  const findings = [];
  for (const workflowPath of discoverWorkflowPaths(root)) {
    const workflow = parseWorkflow(
      fs.readFileSync(workflowPath, 'utf8'),
      workflowPath,
    );
    findings.push(...findMutableActionReferences(workflow, workflowPath));
  }
  return findings;
}

function main() {
  const workflowPaths = discoverWorkflowPaths();
  const workflows = workflowPaths.map((workflowPath) => parseWorkflow(
    fs.readFileSync(workflowPath, 'utf8'),
    workflowPath,
  ));
  const referenceCount = workflows.reduce(
    (count, workflow, index) => count
      + collectActionReferences(workflow, workflowPaths[index]).length,
    0,
  );
  const findings = auditWorkflowActionReferences();
  if (findings.length > 0) {
    for (const finding of findings) {
      const location = finding.location === 'job'
        ? 'job'
        : `step=${finding.stepName}`;
      console.error(
        `MUTABLE_WORKFLOW_ACTION: ${finding.workflowPath} ` +
        `job=${finding.jobName} ${location} ` +
        `reference=${String(finding.reference)} reason=${finding.reason}`,
      );
    }
    process.exitCode = 1;
    return;
  }
  console.log(
    `PASS_WORKFLOW_ACTION_REF_CUSTODY: workflows=${workflowPaths.length} ` +
    `references=${referenceCount}`,
  );
}

if (
  process.argv[1]
  && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  main();
}
