import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
const yaml = require('js-yaml');
const dispatchExpression =
  /\$\{\{\s*(?:inputs|github\.event\.inputs)\.[^}]+\}\}/g;

export const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);

export function parseWorkflow(source, workflowPath = '<workflow>') {
  const workflow = yaml.safeLoad(source, { schema: yaml.JSON_SCHEMA });
  if (workflow == null || typeof workflow !== 'object' || Array.isArray(workflow)) {
    throw new TypeError(`${workflowPath} must contain a YAML mapping`);
  }
  return workflow;
}

export function isManualWorkflow(workflow) {
  return workflow.on?.workflow_dispatch != null;
}

export function discoverWorkflowPaths(root = repositoryRoot) {
  const workflowDirectory = path.join(root, '.github', 'workflows');
  return fs.readdirSync(workflowDirectory)
    .filter((name) => name.endsWith('.yml') || name.endsWith('.yaml'))
    .map((name) => path.join(workflowDirectory, name))
    .sort();
}

export function findUnsafeRunInterpolations(
  workflow,
  workflowPath = '<workflow>',
) {
  const findings = [];
  const jobs = workflow.jobs;
  if (jobs == null || typeof jobs !== 'object' || Array.isArray(jobs)) {
    return findings;
  }

  for (const [jobName, job] of Object.entries(jobs)) {
    if (job == null || typeof job !== 'object' || !Array.isArray(job.steps)) {
      continue;
    }
    job.steps.forEach((step, index) => {
      if (step == null || typeof step !== 'object' || typeof step.run !== 'string') {
        return;
      }
      const expressions = [...step.run.matchAll(dispatchExpression)]
        .map((match) => match[0]);
      if (expressions.length > 0) {
        findings.push({
          workflowPath,
          jobName,
          stepIndex: index,
          stepName: typeof step.name === 'string' ? step.name : '<unnamed>',
          expressions,
        });
      }
    });
  }
  return findings;
}

export function discoverManualWorkflowPaths(root = repositoryRoot) {
  return discoverWorkflowPaths(root)
    .filter((workflowPath) => {
      const workflow = parseWorkflow(
        fs.readFileSync(workflowPath, 'utf8'),
        workflowPath,
      );
      return isManualWorkflow(workflow);
    });
}

export function auditManualWorkflows(root = repositoryRoot) {
  const findings = [];
  for (const workflowPath of discoverManualWorkflowPaths(root)) {
    const workflow = parseWorkflow(
      fs.readFileSync(workflowPath, 'utf8'),
      workflowPath,
    );
    findings.push(...findUnsafeRunInterpolations(workflow, workflowPath));
  }
  return findings;
}

function main() {
  const workflowPaths = discoverManualWorkflowPaths();
  const findings = auditManualWorkflows();
  if (findings.length > 0) {
    for (const finding of findings) {
      console.error(
        `UNSAFE_WORKFLOW_INPUT: ${finding.workflowPath} ` +
        `job=${finding.jobName} step=${finding.stepName} ` +
        `expressions=${finding.expressions.join(',')}`,
      );
    }
    process.exitCode = 1;
    return;
  }
  console.log(
    `PASS_WORKFLOW_DISPATCH_INPUT_CUSTODY: workflows=${workflowPaths.length}`,
  );
}

if (
  process.argv[1]
  && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  main();
}
