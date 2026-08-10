import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

void main() {
  test('staging backend receipt is exact and cannot close F4', () {
    final evidence = _readJson(
      'release/evidence/build-6-f4-staging-backend-tranche.json',
    );
    final ledger = _readJson('governance/programme-ledger.json');

    expect(evidence['schemaVersion'], 1);
    expect(evidence['decision'], 'PASS_BOUNDED_STAGING_BACKEND_TRANCHE');

    final source = _object(evidence['sourceAuthority']);
    expect(
      source['deploymentCommit'],
      '6366a415f23ed2f5d31aa22d8401186b27062d2e',
    );
    expect(source['originParityVerified'], isTrue);
    expect(source['trackedWorktreeClean'], isTrue);
    expect(_object(source['functionsBuild'])['cleanEmitPerformed'], isTrue);

    final target = _object(evidence['target']);
    expect(target['environment'], 'staging');
    expect(target['projectId'], 'crm3-baf-ops-staging');
    expect(target['productionProjectId'], 'crm3-baf-ops-b8638');
    expect(target['firestoreLocation'], 'asia-south1');

    final boundary = _object(evidence['deploymentBoundary']);
    expect(boundary['explicitProjectOnEveryCloudMutation'], isTrue);
    expect(boundary['productionRulesMutationPerformed'], isFalse);
    expect(boundary['productionIndexMutationPerformed'], isFalse);
    expect(boundary['productionFunctionMutationPerformed'], isFalse);
    expect(boundary['productionIamMutationPerformed'], isFalse);
    expect(boundary['productionDataMutationPerformed'], isFalse);
    expect(boundary['productionFunctionCountAfterDeployment'], 7);
    expect(boundary['productionContainsBeginGlobalPullRun'], isFalse);
    expect(boundary['productionContainsStampGlobalPullServerClock'], isFalse);

    final firestore = _object(evidence['firestore']);
    final indexes = _object(firestore['indexes']);
    expect(indexes['sourceCount'], 51);
    expect(indexes['deployedCount'], 51);
    expect(indexes['readyCount'], 51);
    expect(indexes['nonReadyCount'], 0);

    final rules = _object(firestore['rules']);
    expect(rules['byteExact'], isTrue);
    expect(rules['activeSha256'], rules['repositorySha256']);

    final contract = _object(firestore['runtimeContract']);
    expect(contract['state'], 'ABSENT');
    expect(contract['readStatus'], 404);
    expect(contract['activationPerformed'], isFalse);

    final smoke = _object(firestore['syntheticClockSmoke']);
    expect(smoke['serverStampAdded'], isTrue);
    expect(smoke['stampOnlyFollowUpRewroteDocument'], isFalse);
    expect(smoke['recordRetainedForStagingEvidence'], isTrue);

    final functions = _object(evidence['functions']);
    expect(functions['deployedCount'], 2);
    final inventory =
        (functions['inventory'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(inventory.map((item) => item['name']).toSet(), <String>{
      'beginGlobalPullRun',
      'stampGlobalPullServerClock',
    });
    for (final function in inventory) {
      expect(function['state'], 'ACTIVE');
      expect(function['region'], 'asia-south1');
      expect(function['runtime'], 'nodejs22');
      expect(
        function['runtimeServiceAccount'],
        endsWith('@crm3-baf-ops-staging.iam.gserviceaccount.com'),
      );
    }
    final callable = inventory.singleWhere(
      (item) => item['name'] == 'beginGlobalPullRun',
    );
    expect(callable['unauthenticatedProbeStatus'], 401);
    expect(callable['unauthenticatedProbeReachedCallableHandler'], isTrue);
    final trigger = inventory.singleWhere(
      (item) => item['name'] == 'stampGlobalPullServerClock',
    );
    expect(trigger['retryPolicy'], 'RETRY_POLICY_RETRY');
    expect(trigger['documentPattern'], '{collectionId}/{documentId}');

    final remaining = _object(evidence['remainingPrerequisites']);
    for (final key in <String>[
      'authenticationProviderParityVerified',
      'stagingSpecificClientConfigurationCreated',
      'visibleStagingClientIdentityCreated',
      'syntheticUserRoleMatrixCreated',
      'fullStagingWorkflowWalkthroughCompleted',
      'productionRestorePackCreated',
      'productionRulesIndexesOrFunctionsDeployed',
      'productionGlobalPullBackfillCompleted',
      'productionRuntimeContractActivated',
      'build6F4BackendReadyReceiptCreated',
      'physicalDeviceF4Resumed',
    ]) {
      expect(remaining[key], isFalse, reason: key);
    }

    final programme = _object(evidence['programmeBoundary']);
    expect(programme['stage2dF4CurrentStatus'], 'OPEN');
    expect(programme['stage2dF4ClosureAuthorized'], isFalse);
    expect(programme['p07ClosureAuthorized'], isFalse);
    expect(programme['pilotHandoutAuthorized'], isFalse);
    expect(programme['heldPullRequests87Through93ReAdjudicated'], isFalse);
    expect(programme['decisionMayBeUsedAsPassBuild6F4BackendReady'], isFalse);

    final ledgerDecision = _object(ledger['programmeDecision']);
    expect(ledgerDecision['nextMutation'], 'STAGE2D-F5');
    expect(ledgerDecision['pilotHandout'], 'NOT_AUTHORIZED');
    final f4 = (ledger['programmeGates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((record) => record['gateId'] == 'STAGE2D-F4');
    expect(f4['currentStatus'], 'CLOSED');
    expect(f4['authorization'], 'CLOSED_PASS');
  });

  test('staging report retains the production and device stop boundary', () {
    final report =
        File(
          'docs/v4_2_r1/BUILD6_F4_STAGING_BACKEND_TRANCHE.md',
        ).readAsStringSync();
    final blocker =
        File(
          'docs/v4_2_r1/BUILD6_F4_BACKEND_READINESS_BLOCKER.md',
        ).readAsStringSync();

    for (final required in <String>[
      'not `PASS_BUILD6_F4_BACKEND_READY`',
      'does not close `STAGE2D-F4`',
      'Production retained its prior seven-function inventory',
      'authentication-provider parity',
      'staging-specific client configuration',
      'sealed restore pack',
      'contract activation',
    ]) {
      expect(report, contains(required), reason: required);
    }
    expect(blocker, contains('Status: CONTROLLED STOP'));
    expect(blocker, contains('Staging Tranche Update - 2026-08-02'));
    expect(blocker, contains('does not change the controlled stop'));
  });
}
