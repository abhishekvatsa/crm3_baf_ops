import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(Object? value) =>
    Map<String, dynamic>.from(value! as Map);

void main() {
  late Map<String, dynamic> promotion;

  setUpAll(() {
    promotion = _object(
      jsonDecode(
        File(
          'release/approvals/'
          'build-8-f4-production-backend-activation-promotion.json',
        ).readAsStringSync(),
      ),
    );
  });

  test('Build 8 backend activation is exact-project and tightly bounded', () {
    expect(promotion['schemaVersion'], 1);
    expect(promotion['approved'], isTrue);
    expect(
      promotion['approvalClass'],
      'CONTROLLED_PRODUCTION_GLOBAL_PULL_BACKEND_ACTIVATION',
    );

    final authority = _object(promotion['approvalAuthority']);
    expect(
      authority['baselineCommit'],
      '731a02980d38e4e3a8f61ff2bca74a1e85771478',
    );
    expect(
      authority['baselineTree'],
      '8805af93cf0d99d5527a835dcf43fa16d3bfa3f0',
    );
    expect(
      authority['humanApprovalReference'],
      'CODEX_TASK_BUILD8_BACKEND_AND_ADB_APPROVAL_20260803',
    );

    final target = _object(promotion['target']);
    expect(target['environment'], 'production');
    expect(target['projectId'], 'crm3-baf-ops-b8638');
    expect(target['projectNumber'], '894346496105');
    expect(target['region'], 'asia-south1');
    expect(target['firestoreDatabase'], '(default)');

    final source = _object(promotion['sourceAuthority']);
    expect(source['protocolVersion'], 1);
    expect(
      source['protocolFingerprint'],
      'cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321',
    );
    expect(source['functionsTrackedFileCount'], 112);
    expect(
      source['functionsTrackedManifestSha256'],
      'E5ADD15B6732ADDCF059D8992EE0F7CE4DBC7F558CCD505A3AF3EE2BF0E0DCAC',
    );
    final sourceFiles =
        (source['deploymentFiles'] as List<dynamic>).map(_object).toList();
    expect(sourceFiles.length, 13);
    expect(
      sourceFiles.map((file) => file['path']).toSet(),
      containsAll(<String>{
        'firebase.json',
        'firestore.rules',
        'firestore.indexes.json',
        'functions/src/index.ts',
        'functions/src/globalPullServerClock.ts',
        'functions/src/globalPullSecurityConfig.ts',
        'functions/src/callableSecurityConfig.ts',
        'functions/tools/global-pull-server-clock.mjs',
        'functions/package.json',
        'functions/package-lock.json',
        'governance/global-pull-protocol-v1.json',
        'tooling/firebase-cli/package.json',
        'tooling/firebase-cli/package-lock.json',
      }),
    );
    for (final file in sourceFiles) {
      expect(file['sha256'], matches(RegExp(r'^[0-9A-F]{64}$')));
    }

    final preflight = _object(promotion['preflightEvidence']);
    expect(preflight['readOnly'], isTrue);
    expect(preflight['totalDocuments'], 42);
    expect(preflight['stampedDocuments'], 1);
    expect(preflight['missingDocuments'], 41);
    expect(preflight['malformedDocuments'], 0);
    expect(preflight['documentIdsRetained'], isFalse);
    expect(preflight['requiredFunctionsActive'], isTrue);
    expect(preflight['liveIndexCount'], 51);
    expect(preflight['sourceIndexCount'], 51);

    final restore = _object(promotion['restoreAuthority']);
    expect(
      restore['decision'],
      'PASS_PRIVATE_PRODUCTION_RESTORE_PACK_SEALED_AND_INDEPENDENTLY_VERIFIED',
    );
    expect(restore['privateCustodyCopyCount'], 2);
    expect(restore['liveRollbackAutomaticallyAuthorized'], isFalse);

    final mutations = _object(promotion['authorizedMutations']);
    expect(mutations['firestoreRules'], 'EXACT_SOURCE_ONLY');
    expect(mutations['firestoreIndexes'], 'READ_ONLY_PARITY');
    expect((mutations['functions'] as List<dynamic>).cast<String>(), <String>[
      'beginGlobalPullRun',
      'stampGlobalPullServerClock',
    ]);
    expect(mutations['functionFleetOutsideNamedScope'], 'PROHIBITED');
    expect(mutations['iam'], 'PROHIBITED');
    expect(mutations['appCheck'], 'PROHIBITED');
    expect(mutations['businessFields'], 'PROHIBITED');
    expect(mutations['distribution'], 'PROHIBITED');

    final migration = _object(promotion['migrationBoundary']);
    expect(migration['maximumObservedDocuments'], 100);
    expect(migration['maximumBackfillUpdates'], 50);
    expect(migration['malformedWatermarksAllowed'], 0);
    expect(migration['documentIdsMayBeRetained'], isFalse);
    expect(migration['writePrecondition'], 'lastUpdateTime');

    final boundary = _object(promotion['programmeBoundary']);
    expect(boundary['stage2dF4CurrentStatus'], 'OPEN');
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['p07ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['externalDistributionAuthorized'], isFalse);
    expect(boundary['build8DeviceSyncRetryAuthorizedByThisPromotion'], isFalse);
    expect(
      boundary['separateBuild8PhysicalExecutionPromotionRequired'],
      isTrue,
    );
  });

  test('activation harness chains four phases and excludes wider mutation', () {
    final script =
        File(
          'tools/release/Invoke-ProductionGlobalPullActivation.ps1',
        ).readAsStringSync();

    for (final required in <String>[
      "[ValidateSet('Preflight', 'Deploy', 'Backfill', 'Activate')]",
      "[ValidatePattern('^crm3-baf-ops-b8638\$')]",
      '[long]\$PostMergeRunId',
      'ConfirmProjectId must exactly match ProjectId',
      'EvidenceDirectory must be outside the repository.',
      "'fetch', '--quiet', 'origin', 'main'",
      'Production activation requires exact tracked-clean main equal to freshly fetched origin/main.',
      "'run', 'view', [string]\$PostMergeRunId",
      "'databaseId,headSha,conclusion,event,workflowName,jobs,url'",
      "Assert-Equal \$run.workflowName 'release-gate'",
      "Assert-Equal \$run.event 'push'",
      "Assert-Equal \$run.conclusion 'success'",
      'Post-merge release-gate must contain exactly four successful jobs.',
      "'firestore:rules'",
      "'functions:beginGlobalPullRun,functions:stampGlobalPullServerClock'",
      'CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK=false',
      'Refusing to overwrite existing deployment environment file',
      'Remove-Item -LiteralPath \$parameterFile -Force',
      '--verify-receipt',
      'Production activation promotion path',
      'Production deployment inputs contain tracked or untracked worktree changes.',
      'PASS_BUILD8_PRODUCTION_GLOBAL_PULL_ACTIVATION_PREFLIGHT',
      'GLOBAL_PULL_SERVER_CLOCK_BACKFILL_VERIFIED',
      'PASS_BUILD8_F4_BACKEND_READY',
      'Pre-activation inventory missing count',
      'Pre-activation inventory malformed count',
      'Activated global-pull zero-gap inventory',
      '01-global-pull-inventory-preflight.json',
      '05-global-pull-backfill.json',
      '07-global-pull-activation.json',
      '09-build8-f4-backend-readiness.json',
    ]) {
      expect(script, contains(required), reason: required);
    }

    for (final forbidden in <String>[
      "'firestore:indexes'",
      "'deploy', '--only', 'functions'",
      'add-iam-policy-binding',
      'service-accounts create',
      'appcheck:',
      "'firestore', 'import'",
      "'firestore', 'delete'",
      'appdistribution:distribute',
      "'--force'",
      "'pm', 'clear'",
      "'uninstall'",
      'stage2dF4ClosureAuthorized = \$true',
      'pilotHandoutAuthorized = \$true',
    ]) {
      expect(script.toLowerCase(), isNot(contains(forbidden.toLowerCase())));
    }
  });

  test('readback collector is privacy-minimized and fail-closed', () {
    final collector =
        File(
          'tools/release/collectProductionGlobalPullBackend.js',
        ).readAsStringSync();

    for (final required in <String>[
      'Only the exact production project',
      'Backend evidence output must be outside the repository.',
      'receipts are append-only',
      'Backend evidence requires exact tracked-clean main equal to origin/main.',
      'The production activation promotion is not effective on its baseline.',
      'documentIdsRetained === false',
      'inventory.inventory.malformed === 0',
      'inventory.inventory.missing <= limits.maximumBackfillUpdates',
      'requiredFunctionsShareSourceHash',
      'runtimeIdentitiesExact',
      'functionsTrackedManifestSha256',
      'Only the merged promotion at',
      'deploymentInputStatus',
      'verifyReceiptSeal',
      'PASS_BUILD8_PRODUCTION_GLOBAL_PULL_ACTIVATION_PREFLIGHT',
      'PASS_BUILD8_F4_BACKEND_READY',
      'appCheckActivationPerformed: false',
      'distributionAuthorized: false',
    ]) {
      expect(collector, contains(required), reason: required);
    }

    expect(collector, isNot(contains('include-document-ids')));
    expect(collector, isNot(contains('documents:list')));
    expect(collector, isNot(contains('clients.firestore.post(')));
    expect(collector, isNot(contains('clients.firestore.patch(')));
    expect(collector, isNot(contains('clients.firestore.delete(')));
  });

  test('readback collector executable contracts pass under Node', () {
    final result = Process.runSync('node', <String>[
      '--test',
      'tools/release/production_global_pull_backend_readiness.test.mjs',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
