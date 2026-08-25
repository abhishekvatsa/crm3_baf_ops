const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', 'src');

function source(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

describe('S-03 callable boundary wiring', () => {
  const indexSource = source('index.ts');
  const workflowSource = source(
    path.join('maintenanceWorkflow', 'callable.ts'),
  );

  test.each([
    ['completePlannedJobExecution', 'userCanComplete'],
    ['assignPublishedTemplateVersion', 'userCanAssignPublishedTemplate'],
    [
      'mutateRuntimeJobModulePopulation',
      'userCanMutateRuntimeJobModulePopulation',
    ],
    ['mutateUserAuthority', 'userCanMutateUserAuthority'],
  ])('%s uses authority-first shared admission through %s', (
    callableName,
    authorityPredicate,
  ) => {
    expect(indexSource).toContain(`callableName: "${callableName}"`);
    expect(indexSource).toContain(`authorize: ${authorityPredicate}`);
  });

  test('abnormality and quality mutations select exact authority before shared admission', () => {
    const callableStart = indexSource.indexOf(
      'export const mutateChargeAbnormality = onCall(',
    );
    const callableEnd = indexSource.indexOf(
      '// ─── Callable: governed asset-hierarchy mutation',
      callableStart,
    );
    const callableBlock = indexSource.slice(callableStart, callableEnd);

    expect(callableStart).toBeGreaterThan(-1);
    expect(callableEnd).toBeGreaterThan(callableStart);
    expect(callableBlock).toContain('callableName: "mutateChargeAbnormality"');
    expect(callableBlock).toContain(
      'isQualityMutationOperation(request.data?.operation)',
    );
    expect(callableBlock).toContain(
      'userCanMutateQuality(userData, request.data.operation)',
    );
    expect(callableBlock).toContain('userCanMutateChargeAbnormality(userData)');
  });

  test('asset mutations select the exact authority before shared admission', () => {
    const callableStart = indexSource.indexOf(
      'export const mutateAssetHierarchy = onCall(',
    );
    const callableEnd = indexSource.indexOf(
      '// ─── Notification triggers',
      callableStart,
    );
    const callableBlock = indexSource.slice(callableStart, callableEnd);

    expect(callableStart).toBeGreaterThan(-1);
    expect(callableEnd).toBeGreaterThan(callableStart);
    expect(callableBlock).toContain('callableName: "mutateAssetHierarchy"');
    expect(callableBlock).toContain(
      'isAssetOperationalConditionOperation(request.data?.operation)',
    );
    expect(callableBlock).toContain('userCanMutateAssetOperationalCondition(');
    expect(callableBlock).toContain('userCanMutateAssetHierarchy(userData)');
    expect(callableBlock).toContain('userCanResumeClaimedDeviceRecovery({');
  });

  test('workflow command admission follows the approved actor read', () => {
    const actorOffset = workflowSource.indexOf(
      'const actor = await actorFromRequest(request, db);',
    );
    const limiterOffset = workflowSource.indexOf(
      'executeWithCallableAbuseControl({',
    );
    const parseOffset = workflowSource.indexOf(
      'const command = parseCommand(request.data);',
    );

    expect(actorOffset).toBeGreaterThan(-1);
    expect(limiterOffset).toBeGreaterThan(actorOffset);
    expect(parseOffset).toBeGreaterThan(limiterOffset);
  });

  test.each([
    [
      'beginGlobalPullRun',
      '// ─── Callable: runtime job-module population mutation',
    ],
    [
      'getBackendReleaseIdentity',
      '// ─── Callable: atomic user-authority mutation',
    ],
  ])('read-only %s callable is outside mutation quotas', (
    callableName,
    endMarker,
  ) => {
    const identityBlock = indexSource.slice(
      indexSource.indexOf(`export const ${callableName}`),
      indexSource.indexOf(endMarker),
    );
    expect(identityBlock).not.toContain('executeAuthorizedMutation');
    expect(identityBlock).not.toContain('executeWithCallableAbuseControl');
  });
});
