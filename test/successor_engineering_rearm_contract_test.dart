import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readObject(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

List<Map<String, dynamic>> _objects(dynamic value) => (value as List<dynamic>)
    .map((entry) => (entry as Map).cast<String, dynamic>())
    .toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

String _packageVersion() {
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync());
  return match!.group(1)!;
}

void main() {
  test(
    'successor engineering is re-armed without changing Build 11 authority',
    () {
      final ledger = _readObject('governance/programme-ledger.json');
      final sealedDecision =
          (ledger['programmeDecision'] as Map).cast<String, dynamic>();
      final successorDecision =
          (ledger['successorEngineeringDecision'] as Map)
              .cast<String, dynamic>();
      final authority = _readObject(
        'governance/successor-engineering-rearm-2026-08-16.json',
      );

      expect(
        sealedDecision['decisionScope'],
        'SEALED_BUILD11_STAGE2D_PROGRAMME',
      );
      expect(
        sealedDecision['pilotHandout'],
        'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER',
      );
      expect(sealedDecision['nextMutation'], 'NONE_ALL_PROGRAMME_GATES_CLOSED');
      expect(successorDecision['status'], 'RE_ARMED_SOURCE_AND_CI');
      expect(successorDecision['releaseAuthority'], 'NONE_SOURCE_AND_CI_ONLY');
      expect(successorDecision['sealedBuild11AuthorityChanged'], isFalse);
      expect(authority['status'], 'ACTIVE_SOURCE_AND_CI_ONLY');
      expect(
        _strings(authority['notAuthorized']),
        containsAll(<String>[
          'production Firebase deployment',
          'App Check or Play Integrity activation',
          'reuse of the Build 11 package identity',
          'unrestricted distribution',
        ]),
      );
    },
  );

  test(
    'current index derives each release plane from live authority records',
    () {
      final state = _readObject('release/current-successor-state.json');
      final planes = (state['authorityPlanes'] as Map).cast<String, dynamic>();
      final currentSource =
          (planes['currentSource'] as Map).cast<String, dynamic>();
      final artifact =
          (planes['latestFinalizedArtifact'] as Map).cast<String, dynamic>();
      final deployed =
          (planes['deployedBackend'] as Map).cast<String, dynamic>();
      final pilot = (planes['controlledPilot'] as Map).cast<String, dynamic>();
      final next = (planes['nextCandidate'] as Map).cast<String, dynamic>();
      final policy = _readObject('release/production-release-policy.json');
      final release = (policy['release'] as Map).cast<String, dynamic>();
      final finalization =
          (policy['finalization'] as Map).cast<String, dynamic>();
      final priorFinalization =
          (finalization['priorCompletedBuild'] as Map).cast<String, dynamic>();
      final firestoreAuthority =
          (finalization['exactFirestoreRulesIndexesLiveReadback'] as Map)
              .cast<String, dynamic>();
      final promotion =
          (policy['postBuildPromotion'] as Map).cast<String, dynamic>();
      final ledger = _readObject('release/build-number-ledger.json');
      final ledgerEntries = _objects(ledger['entries']);
      final latestLedgerEntry = ledgerEntries.last;
      final latestFinalizedLedgerEntry =
          ledgerEntries
              .where((entry) => entry['buildNumber'] == artifact['buildNumber'])
              .single;
      final receipt = _readObject(
        priorFinalization['completionReceiptFile'] as String,
      );
      final receiptRelease =
          (receipt['release'] as Map).cast<String, dynamic>();
      final liveBackend = _readObject(
        deployed['functionFleetEvidenceFile'] as String,
      );
      final rulesReadback = _readObject(
        deployed['rulesAndIndexesEvidenceFile'] as String,
      );
      final historicalRulesHold = _readObject(
        'release/evidence/build15-firestore-rules-readback-hold.json',
      );
      final nextApproval = _readObject(next['sourceApprovalFile'] as String);
      final nextEnvironment = _readObject(
        next['signingEnvironmentApprovalFile'] as String,
      );
      final requiredSource =
          (nextApproval['requiredSource'] as Map).cast<String, dynamic>();
      final nextApprovalBuild =
          (nextApproval['nextBuild'] as Map).cast<String, dynamic>();
      final backendAuthority =
          (liveBackend['sourceAuthority'] as Map).cast<String, dynamic>();
      final backendDeployment =
          (liveBackend['deployment'] as Map).cast<String, dynamic>();
      final backendBoundary =
          (liveBackend['controlBoundary'] as Map).cast<String, dynamic>();
      final rulesReadbackOutputs =
          (rulesReadback['outputs'] as Map).cast<String, dynamic>();
      final verifiedRules =
          (rulesReadbackOutputs['rules'] as Map).cast<String, dynamic>();
      final verifiedIndexes =
          (rulesReadbackOutputs['indexes'] as Map).cast<String, dynamic>();
      final historicalHoldBoundary =
          (historicalRulesHold['releaseBoundary'] as Map)
              .cast<String, dynamic>();
      final predecessor =
          (requiredSource['predecessorFinalizationReceipt'] as Map)
              .cast<String, dynamic>();
      final environmentScope =
          (nextEnvironment['scope'] as Map).cast<String, dynamic>();
      final environmentEvidence =
          (nextEnvironment['liveStateEvidence'] as Map).cast<String, dynamic>();

      expect(state['schemaVersion'], 2);
      expect(
        state['status'],
        'BUILD15_SOURCE_AUTHORIZED_BACKEND_READY_AWAITING_SIGNED_CONSTRUCTION',
      );
      expect(currentSource['reference'], 'refs/heads/main');
      expect(currentSource['packageVersion'], _packageVersion());
      expect(
        currentSource['relationshipToLatestFinalizedArtifact'],
        'BUILD15_SOURCE_SUCCESSOR_OF_FINALIZED_BUILD14',
      );
      expect(currentSource['sourceAndCiAuthority'], isTrue);
      expect(currentSource['artifactConstructionAuthority'], isTrue);
      expect(currentSource['deploymentAuthority'], isFalse);
      expect(currentSource['distributionAuthority'], isFalse);
      expect(currentSource['sameBuildNumberReuseProhibited'], isTrue);

      expect(artifact['buildNumber'], priorFinalization['buildNumber']);
      expect(
        artifact['buildNumber'],
        latestFinalizedLedgerEntry['buildNumber'],
      );
      expect(artifact['buildNumber'], receiptRelease['buildNumber']);
      expect(artifact['version'], '1.0.0-rc.4+14');
      expect(artifact['sourceCommit'], priorFinalization['sourceCommit']);
      expect(release['buildNumber'], latestLedgerEntry['buildNumber']);
      expect(
        latestLedgerEntry['status'],
        'source-reserved-awaiting-remote-consumption',
      );
      expect(latestLedgerEntry.containsKey('githubRunId'), isFalse);
      expect(latestLedgerEntry.containsKey('governedPackageSha256'), isFalse);
      final artifactIsAncestor = Process.runSync('git', <String>[
        'merge-base',
        '--is-ancestor',
        artifact['sourceCommit'] as String,
        'HEAD',
      ]);
      expect(
        artifactIsAncestor.exitCode,
        0,
        reason: 'Current source must descend from the finalized artifact.',
      );
      expect(artifact['status'], 'COMPLETED_NON_DISTRIBUTABLE');
      expect(
        artifact['completionReceiptFile'],
        priorFinalization['completionReceiptFile'],
      );
      expect(
        artifact['completionReceiptSha256'],
        priorFinalization['completionReceiptSha256'],
      );
      expect(
        _sha256(artifact['completionReceiptFile'] as String),
        artifact['completionReceiptSha256'],
      );
      expect(artifact['pilotPromotion'], 'NOT_AUTHORIZED');
      expect(artifact['unrestrictedDistribution'], 'NOT_AUTHORIZED');

      expect(
        deployed['functionFleetEvidenceFile'],
        requiredSource['exactFunctionFleetDeploymentReceiptFile'],
      );
      expect(
        deployed['functionFleetEvidenceFile'],
        finalization['exactFunctionFleetDeploymentReceiptFile'],
      );
      expect(
        _sha256(deployed['functionFleetEvidenceFile'] as String),
        requiredSource['exactFunctionFleetDeploymentReceiptSha256'],
      );
      expect(
        deployed['currentSourceFunctionDeployment'],
        'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK',
      );
      expect(
        deployed['currentSourceRulesAndIndexesDeployment'],
        'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK',
      );
      expect(
        liveBackend['decision'],
        deployed['currentSourceFunctionDeployment'],
      );
      expect(backendAuthority['commit'], deployed['functionFleetSourceCommit']);
      expect(
        backendAuthority['commit'],
        (nextApproval['sourceBaseline'] as Map)['commit'],
      );
      expect(
        backendAuthority['pullRequestNumber'],
        requiredSource['exactFunctionFleetDeploymentPullRequest'],
      );
      expect(backendDeployment['functionCount'], 15);
      expect(backendDeployment['allFunctionsExactSourceVerified'], isTrue);
      expect(backendDeployment['existingIamPreservationEnforced'], isTrue);
      expect(backendBoundary['iamMutated'], isFalse);
      expect(backendBoundary['productionBusinessDataMutated'], isFalse);
      expect(backendBoundary['distributionPerformed'], isFalse);
      expect(
        _objects(
          (liveBackend['privacySafeExternalEvidence'] as Map)['receipts'],
        ),
        hasLength(9),
      );
      expect(
        rulesReadback['decision'],
        'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK',
      );
      expect(
        firestoreAuthority['receiptFile'],
        deployed['rulesAndIndexesEvidenceFile'],
      );
      expect(
        _sha256(deployed['rulesAndIndexesEvidenceFile'] as String),
        firestoreAuthority['receiptFileSha256'],
      );
      expect(
        rulesReadback['receiptSha256'],
        firestoreAuthority['receiptCanonicalSha256'],
      );
      expect(verifiedRules['sourceSha256'], _sha256('firestore.rules'));
      expect(
        verifiedRules['sourceSha256'],
        requiredSource['exactFirestoreRulesSha256'],
      );
      expect(verifiedRules['activeSha256'], verifiedRules['sourceSha256']);
      expect(verifiedRules['byteExact'], isTrue);
      expect(
        verifiedIndexes['sourceCount'],
        requiredSource['exactFirestoreIndexCount'],
      );
      expect(verifiedIndexes['apiCount'], verifiedIndexes['sourceCount']);
      expect(verifiedIndexes['apiReadyCount'], verifiedIndexes['sourceCount']);
      expect(verifiedIndexes['allApiIndexesReady'], isTrue);
      expect(
        verifiedIndexes['sourceSetSha256'],
        requiredSource['exactFirestoreIndexSetSha256'],
      );
      final sourceIndexProbe = Process.runSync('node', <String>[
        'tools/release/collectFirestoreRulesIndexesReadback.js',
        '--source-index-set',
        'firestore.indexes.json',
      ]);
      expect(sourceIndexProbe.exitCode, 0);
      final sourceIndexBinding =
          (jsonDecode(sourceIndexProbe.stdout as String) as Map)
              .cast<String, dynamic>();
      expect(sourceIndexBinding['count'], verifiedIndexes['sourceCount']);
      expect(
        sourceIndexBinding['indexSetSha256'],
        requiredSource['exactFirestoreIndexSetSha256'],
      );
      expect(
        historicalRulesHold['decision'],
        'HOLD_BUILD15_EXACT_FIRESTORE_RULES_READBACK',
      );
      expect(
        historicalHoldBoundary['build15ConstructionAuthorizedByThisEvidence'],
        isFalse,
      );
      expect(
        historicalHoldBoundary['productionRulesDeploymentApprovedByThisEvidence'],
        isFalse,
      );
      expect(historicalHoldBoundary['pilotPromotionApproved'], isFalse);
      expect(predecessor['buildNumber'], artifact['buildNumber']);
      expect(predecessor['file'], artifact['completionReceiptFile']);
      expect(predecessor['sha256'], artifact['completionReceiptSha256']);
      expect(nextApproval['approved'], isTrue);
      expect(nextApprovalBuild['buildNumber'], 15);
      expect(nextApproval['distributionApproved'], isFalse);
      expect(nextEnvironment['approved'], isTrue);
      expect(environmentScope['buildNumber'], nextApprovalBuild['buildNumber']);
      expect(environmentEvidence['requiredReviewerRulePresent'], isTrue);
      expect(environmentEvidence['secretValuesInspected'], isFalse);
      expect(
        (environmentEvidence['requiredReviewer'] as Map)['login'],
        'abhishekvatsa',
      );
      expect(pilot['buildNumber'], promotion['buildNumber']);
      expect(
        pilot['buildNumber'],
        policy['distribution']['approvedBuildNumber'],
      );
      expect(pilot['handoutPerformed'], isFalse);
      expect(pilot['appliesToCurrentSource'], isFalse);
      expect(pilot['appliesToBuild14'], isFalse);
      expect(pilot['appliesToBuild15'], isFalse);
      expect(next['minimumBuildNumber'], release['buildNumber']);
      expect(
        next['status'],
        'SOURCE_AUTHORIZED_AWAITING_SIGNED_BUILD15_CONSTRUCTION',
      );
      expect(next['constructionRequiresFreshGovernedApproval'], isTrue);
      expect(next['deviceValidationRequiresExactNewArtifact'], isTrue);
      expect(next['pilotPromotionRequiresSeparateDecision'], isTrue);
      expect(state['localStore']['schemaVersion'], 7);
      expect(state['appCheck']['mutatingCallableSourceDefault'], isFalse);

      final readme = File('README.md').readAsStringSync();
      expect(readme, contains('Build 14 (`1.0.0-rc.4+14`)'));
      expect(readme, contains('Build 15 (`1.0.0-rc.5+15`)'));
      expect(readme, isNot(contains('Build 12 is source authorized')));
    },
  );

  test('historical Build 12 deployment record remains exact', () {
    final deployment = _readObject(
      'release/build12-live-deployment-authority.json',
    );
    final approval = _readObject(
      'release/approvals/build12-backend-rules-indexes-deployment-authorization.json',
    );
    final source = (deployment['source'] as Map).cast<String, dynamic>();
    final boundary =
        (deployment['authorityBoundary'] as Map).cast<String, dynamic>();

    expect(
      deployment['status'],
      'PASS_BUILD12_BACKEND_RULES_INDEXES_IAM_DEPLOYED_EXACT',
    );
    expect(approval['approved'], isTrue);
    expect(approval['approvalReference'], 'BAF-FIREBASE-DEPLOY-012');
    expect(
      (deployment['authorization'] as Map)['recordSha256'],
      _sha256(
        'release/approvals/build12-backend-rules-indexes-deployment-authorization.json',
      ),
    );
    expect(
      source['finalizationReceiptSha256'],
      _sha256('release/evidence/build-12-finalization-closure.json'),
    );
    expect(boundary['backendDeploymentProved'], isTrue);
    expect(boundary['rulesAndIndexesDeploymentProved'], isTrue);
    expect(boundary['runtimeIamProved'], isTrue);
    expect(boundary['productionSignedClientConstructed'], isTrue);
    expect(boundary['deviceUpgradeProved'], isTrue);
    expect(
      boundary['postAssetPopulationLiveWorkflowValidationProved'],
      isFalse,
    );
    expect(boundary['pilotHandoutAuthorized'], isFalse);
  });

  test('legacy receipt labels resolve to exact predecessor evidence', () {
    final registry = _readObject(
      'release/predecessor-finalization-receipt-bindings.json',
    );
    final legacy =
        (registry['legacyFieldNames'] as Map).cast<String, dynamic>();
    final future =
        (registry['futureFieldContract'] as Map).cast<String, dynamic>();
    final bindings = _objects(registry['compatibilityBindings']);

    expect(registry['schemaVersion'], 1);
    expect(registry['historicalApprovalFilesImmutable'], isTrue);
    expect(legacy['file'], 'build11FinalizationReceiptFile');
    expect(legacy['sha256'], 'build11FinalizationReceiptSha256');
    expect(future['object'], 'predecessorFinalizationReceipt');
    expect(future['legacyAliasPermittedOnlyWhenRegisteredHere'], isTrue);
    expect(
      bindings.map((entry) => entry['successorBuildNumber']),
      orderedEquals(<int>[12, 13, 14]),
    );

    for (final binding in bindings) {
      final approvalPath = binding['approvalFile'] as String;
      final receiptPath = binding['receiptFile'] as String;
      final approval = _readObject(approvalPath);
      final requiredSource =
          (approval['requiredSource'] as Map).cast<String, dynamic>();
      final preserved =
          (approval['preservedCompletedBuild'] as Map).cast<String, dynamic>();
      final receipt = _readObject(receiptPath);
      final receiptRelease =
          (receipt['release'] as Map).cast<String, dynamic>();

      expect(_sha256(approvalPath), binding['approvalSha256']);
      expect(_sha256(receiptPath), binding['receiptSha256']);
      expect(
        binding['successorBuildNumber'],
        (binding['predecessorBuildNumber'] as int) + 1,
      );
      expect(
        (approval['nextBuild'] as Map)['buildNumber'],
        binding['successorBuildNumber'],
      );
      expect(preserved['buildNumber'], binding['predecessorBuildNumber']);
      expect(requiredSource[legacy['file']], binding['receiptFile']);
      expect(requiredSource[legacy['sha256']], binding['receiptSha256']);
      expect(receiptRelease['buildNumber'], binding['predecessorBuildNumber']);
    }

    final verifier =
        File(
          'tools/release/Test-ProductionReleasePolicy.ps1',
        ).readAsStringSync();
    expect(verifier, contains('predecessorFinalizationReceipt'));
    expect(
      verifier,
      contains(
        'Legacy predecessor receipt alias is not explicitly registered.',
      ),
    );
    expect(
      verifier,
      contains(
        'Resolved predecessor finalization receipt differs from authority.',
      ),
    );
  });
}
