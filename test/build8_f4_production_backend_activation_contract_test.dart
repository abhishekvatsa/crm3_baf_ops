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

  test('post-activation sync retry is exact-target and non-distributable', () {
    final readiness = _object(
      jsonDecode(
        File(
          'release/evidence/build-8-f4-production-backend-readiness.json',
        ).readAsStringSync(),
      ),
    );
    final retry = _object(
      jsonDecode(
        File(
          'release/approvals/'
          'build-8-f4-physical-sync-retry-promotion.json',
        ).readAsStringSync(),
      ),
    );

    expect(readiness['decision'], 'PASS_BUILD8_F4_BACKEND_READY');
    final readback = _object(readiness['liveReadback']);
    expect(readback['globalPullContractState'], 'ACTIVE');
    expect(readback['inventoryTotal'], 42);
    expect(readback['inventoryStamped'], 42);
    expect(readback['inventoryMissing'], 0);
    expect(readback['inventoryMalformed'], 0);

    expect(retry['approved'], isTrue);
    expect(
      retry['approvalClass'],
      'CONTROLLED_EXACT_TARGET_BUILD8_POST_ACTIVATION_SYNC_RETRY',
    );
    final backend = _object(retry['backendAuthority']);
    expect(
      backend['evidenceSha256'],
      '73295B13B7DC7C476A7F094B779A58DF5B3491B32DB4E349A2CDD5C695BC7096',
    );
    expect(backend['inventoryMissing'], 0);
    expect(backend['inventoryMalformed'], 0);
    final artifact = _object(retry['artifactAuthority']);
    expect(
      artifact['finalizationEvidenceSha256'],
      '9DA20D9997DC11D305317F4A594F3A139E9AC2FF3111523FDD4E288C0D31B446',
    );
    final apk = _object(artifact['apk']);
    expect(apk['versionCode'], 8);
    expect(apk['debuggable'], isFalse);
    final target = _object(retry['targetAuthority']);
    expect(target['maxTargetCount'], 1);
    expect(target['physicalDeviceRequired'], isTrue);
    expect(target['rawAdbSerialRetained'], isFalse);
    expect(target['rawBuildFingerprintRetained'], isFalse);

    final mutations = _object(retry['authorizedMutations']);
    expect(
      mutations['applicationInstallOrUpgrade'],
      'PROHIBITED_ALREADY_EXACT',
    );
    expect(mutations['inAppManualSync'], 'ONE_ATTEMPT');
    expect(
      mutations['productionBusinessWrites'],
      'PROHIBITED_BY_ZERO_PENDING_LOCAL_WRITES_PREFLIGHT',
    );
    expect(mutations['networkState'], 'READ_ONLY_CURRENT_STATE');
    expect(mutations['authenticationSession'], 'PRESERVE_EXISTING_ONLY');
    expect(mutations['firebaseBackend'], 'PROHIBITED');
    expect(mutations['deviceDataClearOrUninstall'], 'PROHIBITED');
    expect(mutations['distribution'], 'PROHIBITED');

    final boundary = _object(retry['programmeBoundary']);
    expect(boundary['stage2dF4Status'], 'OPEN');
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['p07ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['offlineReconnectAuthorized'], isFalse);
    expect(boundary['weakNetworkAuthorized'], isFalse);
    expect(boundary['revocationAuthorized'], isFalse);
    expect(boundary['wrongRoleExecutionAuthorized'], isFalse);
  });

  test('physical retry harness preserves data and fails closed', () {
    final script =
        File(
          'tools/release/Invoke-Build8F4PhysicalSyncRetry.ps1',
        ).readAsStringSync();
    final home =
        File('lib/home_screen.dart').readAsStringSync() +
        File('lib/home_insight_widgets.dart').readAsStringSync();

    for (final required in <String>[
      'EvidenceDirectory must be outside the repository.',
      'Physical sync retry requires exact tracked-clean main equal to origin/main.',
      'Post-merge release-gate must contain exactly four successful jobs.',
      '\$priorErrorActionPreference = \$ErrorActionPreference',
      "\$ErrorActionPreference = 'Continue'",
      '\$exitCode = \$LASTEXITCODE',
      '\$ErrorActionPreference = \$priorErrorActionPreference',
      'External command failed (\$exitCode)',
      'Backend missing-watermark count',
      'Backend malformed-watermark count',
      'Installed APK SHA-256',
      'Preserved first-install time',
      'Preserved last-update time',
      'Pending local business writes are nonzero; sync retry is prohibited.',
      'Manual sync completed.',
      'PASS_BUILD8_F4_POST_ACTIVATION_SYNC_MARKER',
      'stage2dF4Status = \'OPEN\'',
      'stage2dF4ClosureAuthorized = \$false',
      'pilotHandoutAuthorized = \$false',
      'rawUiRetained = \$false',
      'businessPayloadRetained = \$false',
    ]) {
      expect(script, contains(required), reason: required);
    }

    for (final marker in <String>[
      "'Home'",
      "'Issues'",
      "'Work'",
      "'Directives'",
      "'More'",
      "'Raise issue'",
      "'Needs attention'",
    ]) {
      expect(script, contains(marker), reason: marker);
    }
    expect(script, isNot(contains("'Core modules'")));
    expect(script, contains(r'$homeEvidence = Move-ToApprovedHome'));
    expect(script, contains("'Support diagnostics'"));
    expect(home, contains("title: 'Support diagnostics'"));
    expect(script, isNot(contains("'Support Diagnostics'")));
    expect(
      RegExp(
        r'^\s*\$home\s*=',
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(script),
      isFalse,
    );
    expect(home, contains("label: const Text('Raise issue')"));
    expect(home, contains("'Needs attention'"));

    for (final forbidden in <String>[
      "'install'",
      "'uninstall'",
      "'pm', 'clear'",
      "'svc', 'wifi'",
      "'svc', 'data'",
      'firebase deploy',
      'appdistribution:distribute',
      'stage2dF4ClosureAuthorized = \$true',
      'pilotHandoutAuthorized = \$true',
    ]) {
      expect(script.toLowerCase(), isNot(contains(forbidden.toLowerCase())));
    }
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
