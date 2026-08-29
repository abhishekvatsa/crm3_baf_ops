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

String _gitTreeObjectId(String commit, String path) {
  final result = Process.runSync('git', <String>[
    'rev-parse',
    '--verify',
    '$commit:$path',
  ]);
  final tree = (result.stdout as String).trim().toLowerCase();
  if (result.exitCode != 0 ||
      !RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(tree)) {
    throw StateError('Unable to resolve Git tree for $commit:$path.');
  }
  return tree;
}

const _approvedArtifactExactSourcePaths = <String>[
  '.firebaserc',
  '.github/workflows/production-artifact.yml',
  '.metadata',
  '.npmrc',
  'analysis_options.yaml',
  'android',
  'assets',
  'firebase.json',
  'firestore.indexes.json',
  'firestore.rules',
  'functions',
  'integration_test',
  'jest.config.js',
  'lib',
  'package.json',
  'package-lock.json',
  'pubspec.lock',
  'release/approvals/linux-isar-core-authority.json',
  'release/github-actions-pins.json',
  'release_gate.ps1',
  'test',
  'tool',
  'tooling',
  'tools/release',
];

String _gitFileText(String commit, String path) {
  final result = Process.runSync('git', <String>['show', '$commit:$path']);
  if (result.exitCode != 0) {
    throw StateError('Unable to read Git file for $commit:$path.');
  }
  return (result.stdout as String).replaceAll('\r\n', '\n');
}

String? _normalizedArtifactPubspec(String text, {String? expectedVersion}) {
  final pattern = RegExp(r'^version:[ \t]*(\S+)[ \t]*$', multiLine: true);
  final matches = pattern.allMatches(text).toList(growable: false);
  if (matches.length != 1) {
    throw StateError('Artifact pubspec must have one version declaration.');
  }
  if (expectedVersion != null && matches.single.group(1) != expectedVersion) {
    return null;
  }
  return text.replaceFirst(pattern, 'version: <governed-artifact-version>');
}

bool _approvedArtifactSourceMatches(
  String baselineCommit,
  String expectedPackageVersion,
) {
  final exactPathsMatch = _approvedArtifactExactSourcePaths.every(
    (path) =>
        _gitTreeObjectId(baselineCommit, path) ==
        _gitTreeObjectId('HEAD', path),
  );
  final baselinePubspec = _normalizedArtifactPubspec(
    _gitFileText(baselineCommit, 'pubspec.yaml'),
  );
  final currentPubspec = _normalizedArtifactPubspec(
    _gitFileText('HEAD', 'pubspec.yaml'),
    expectedVersion: expectedPackageVersion,
  );
  return exactPathsMatch &&
      currentPubspec != null &&
      baselinePubspec == currentPubspec;
}

bool _artifactConstructionAuthority({
  required bool pendingSourceAuthorization,
  required bool backendMatchesDeployed,
  required bool artifactSourceMatchesApproval,
}) =>
    pendingSourceAuthorization &&
    backendMatchesDeployed &&
    artifactSourceMatchesApproval;

String _functionDeploymentStatus(String deployedTree, String currentTree) =>
    deployedTree == currentTree
        ? 'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK'
        : 'SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';

String _firestoreRelationship({
  required bool rulesChanged,
  required bool indexesChanged,
}) {
  if (!rulesChanged && !indexesChanged) {
    return 'EXACT_SOURCE_RULES_AND_INDEXES_DEPLOYED_AND_VERIFIED';
  }
  if (rulesChanged && indexesChanged) {
    return 'RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';
  }
  return rulesChanged
      ? 'RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
      : 'RULES_MATCH_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';
}

String _firestoreDeploymentStatus({
  required bool rulesChanged,
  required bool indexesChanged,
}) {
  if (!rulesChanged && !indexesChanged) {
    return 'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK';
  }
  if (rulesChanged && indexesChanged) {
    return 'SOURCE_RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';
  }
  return rulesChanged
      ? 'SOURCE_RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
      : 'SOURCE_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';
}

void main() {
  test('backend source-drift expectations cover every parity branch', () {
    expect(
      _functionDeploymentStatus('a' * 40, 'a' * 40),
      'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK',
    );
    expect(
      _functionDeploymentStatus('a' * 40, 'b' * 40),
      'SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreRelationship(rulesChanged: false, indexesChanged: false),
      'EXACT_SOURCE_RULES_AND_INDEXES_DEPLOYED_AND_VERIFIED',
    );
    expect(
      _firestoreRelationship(rulesChanged: true, indexesChanged: false),
      'RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreRelationship(rulesChanged: false, indexesChanged: true),
      'RULES_MATCH_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreRelationship(rulesChanged: true, indexesChanged: true),
      'RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreDeploymentStatus(rulesChanged: true, indexesChanged: false),
      'SOURCE_RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreDeploymentStatus(rulesChanged: false, indexesChanged: true),
      'SOURCE_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    expect(
      _firestoreDeploymentStatus(rulesChanged: true, indexesChanged: true),
      'SOURCE_RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
    );
    for (final pending in <bool>[false, true]) {
      for (final backend in <bool>[false, true]) {
        for (final source in <bool>[false, true]) {
          expect(
            _artifactConstructionAuthority(
              pendingSourceAuthorization: pending,
              backendMatchesDeployed: backend,
              artifactSourceMatchesApproval: source,
            ),
            pending && backend && source,
          );
        }
      }
    }
  });

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
      final currentFirestoreSource =
          (currentSource['firestoreRulesAndIndexes'] as Map)
              .cast<String, dynamic>();
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
      final pendingConstruction =
          finalization['status'] == 'pending-source-authorized';
      final finalizedAuthority =
          pendingConstruction ? priorFinalization : finalization;
      final runtimeValidationPassed =
          finalizedAuthority['runtimeValidationPassed'] == true;
      final candidateBuildNumber = release['buildNumber'] as int;
      final finalizedBuildNumber =
          finalizedAuthority['buildNumber'] as int? ?? candidateBuildNumber;
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
        finalizedAuthority['completionReceiptFile'] as String,
      );
      final receiptRelease =
          (receipt['release'] as Map).cast<String, dynamic>();
      final liveBackend = _readObject(
        deployed['functionFleetEvidenceFile'] as String,
      );
      final rulesReadback = _readObject(
        deployed['rulesAndIndexesEvidenceFile'] as String,
      );
      final rulesReadbackSource =
          (rulesReadback['source'] as Map).cast<String, dynamic>();
      final rulesReadbackBefore =
          (rulesReadbackSource['before'] as Map).cast<String, dynamic>();
      final historicalRulesHold = _readObject(
        'release/evidence/build15-firestore-rules-readback-hold.json',
      );
      final nextApproval = _readObject(
        (policy['versionPolicy'] as Map)['sourceDocumentFile'] as String,
      );
      final nextEnvironment = _readObject(
        ((policy['github'] as Map)['environmentReviewControl']
                as Map)['approvalReceiptFile']
            as String,
      );
      final requiredSource =
          (nextApproval['requiredSource'] as Map).cast<String, dynamic>();
      final functionReadback = _readObject(
        requiredSource['exactFunctionFleetCleanMainReadbackFile'] as String,
      );
      final iamReadback = _readObject(
        requiredSource['exactFunctionsIamDependenciesReadbackFile'] as String,
      );
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
      final deployedFunctionsTree = _gitTreeObjectId(
        backendAuthority['commit'] as String,
        'functions',
      );
      final currentFunctionsTree = _gitTreeObjectId('HEAD', 'functions');
      final expectedFunctionDeployment = _functionDeploymentStatus(
        deployedFunctionsTree,
        currentFunctionsTree,
      );
      final functionsMatchDeployed =
          expectedFunctionDeployment ==
          'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK';
      final sourceIndexProbe = Process.runSync('node', <String>[
        'tools/release/collectFirestoreRulesIndexesReadback.js',
        '--source-index-set',
        'firestore.indexes.json',
      ]);
      expect(sourceIndexProbe.exitCode, 0);
      final sourceIndexBinding =
          (jsonDecode(sourceIndexProbe.stdout as String) as Map)
              .cast<String, dynamic>();
      final currentRulesSha = _sha256('firestore.rules');
      final rulesChanged = currentRulesSha != firestoreAuthority['rulesSha256'];
      final indexesChanged =
          sourceIndexBinding['count'] != firestoreAuthority['indexCount'] ||
          sourceIndexBinding['indexSetSha256'] !=
              firestoreAuthority['indexSetSha256'];
      final firestoreMatchesDeployed = !rulesChanged && !indexesChanged;
      final backendMatchesDeployed =
          functionsMatchDeployed && firestoreMatchesDeployed;
      final sourceBaseline =
          (nextApproval['sourceBaseline'] as Map).cast<String, dynamic>();
      final artifactSourceMatchesApproval = _approvedArtifactSourceMatches(
        sourceBaseline['commit'] as String,
        '${release['versionName']}+$candidateBuildNumber',
      );
      final evidenceBoundAt = DateTime.parse(
        nextApproval['evidenceBoundAtUtc'] as String,
      );
      for (final capturedAt in <String>[
        functionReadback['capturedAtUtc'] as String,
        iamReadback['capturedAtUtc'] as String,
        rulesReadback['capturedAtUtc'] as String,
        liveBackend['recordedAtUtc'] as String,
      ]) {
        expect(evidenceBoundAt.isBefore(DateTime.parse(capturedAt)), isFalse);
      }
      final expectedFirestoreRelationship = _firestoreRelationship(
        rulesChanged: rulesChanged,
        indexesChanged: indexesChanged,
      );
      final expectedFirestoreDeployment = _firestoreDeploymentStatus(
        rulesChanged: rulesChanged,
        indexesChanged: indexesChanged,
      );
      final expectedBackendStatus =
          backendMatchesDeployed
              ? 'EXACT_SOURCE_BACKEND_DEPLOYED_AND_VERIFIED'
              : 'SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT';

      expect(state['schemaVersion'], 2);
      expect(
        state['status'],
        pendingConstruction
            ? !backendMatchesDeployed
                ? 'BUILD${candidateBuildNumber}_SOURCE_AUTHORIZED_'
                    'BACKEND_PENDING_GOVERNED_DEPLOYMENT'
                : !artifactSourceMatchesApproval
                ? 'BUILD${candidateBuildNumber}_SOURCE_SUCCESSOR_'
                    'BACKEND_READY_AWAITING_ARTIFACT_SOURCE_REBIND'
                : 'BUILD${candidateBuildNumber}_SOURCE_AUTHORIZED_'
                    'BACKEND_READY_AWAITING_SIGNED_CONSTRUCTION'
            : backendMatchesDeployed
            ? runtimeValidationPassed
                ? 'BUILD${candidateBuildNumber}_FINALIZED_BACKEND_READY_'
                    'DEVICE_ACCEPTED_AWAITING_MUTATING_FLOW_AND_'
                    'PILOT_DECISIONS'
                : 'BUILD${candidateBuildNumber}_FINALIZED_BACKEND_READY_'
                    'AWAITING_DEVICE_AND_PILOT_DECISIONS'
            : runtimeValidationPassed
            ? 'BUILD${candidateBuildNumber}_FINALIZED_SOURCE_SUCCESSOR_'
                'AWAITING_GOVERNED_BACKEND_DEPLOYMENT_MUTATING_FLOW_AND_'
                'PILOT_DECISIONS'
            : 'BUILD${candidateBuildNumber}_FINALIZED_SOURCE_SUCCESSOR_'
                'AWAITING_GOVERNED_BACKEND_DEPLOYMENT_DEVICE_AND_'
                'PILOT_DECISIONS',
      );
      expect(currentSource['reference'], 'refs/heads/main');
      expect(currentSource['packageVersion'], _packageVersion());
      expect(
        currentSource['relationshipToLatestFinalizedArtifact'],
        pendingConstruction
            ? 'BUILD${candidateBuildNumber}_SOURCE_SUCCESSOR_OF_'
                'FINALIZED_BUILD$finalizedBuildNumber'
            : 'BUILD${candidateBuildNumber}_SOURCE_CONTAINS_'
                'FINALIZED_BUILD$finalizedBuildNumber',
      );
      expect(currentSource['sourceAndCiAuthority'], isTrue);
      expect(
        currentSource['artifactConstructionAuthority'],
        _artifactConstructionAuthority(
          pendingSourceAuthorization: pendingConstruction,
          backendMatchesDeployed: backendMatchesDeployed,
          artifactSourceMatchesApproval: artifactSourceMatchesApproval,
        ),
      );
      expect(currentSource['deploymentAuthority'], isFalse);
      expect(currentSource['distributionAuthority'], isFalse);
      expect(currentSource['sameBuildNumberReuseProhibited'], isTrue);
      expect(currentSource['backendDeploymentStatus'], expectedBackendStatus);
      expect(currentSource['productionRuntimeUseAuthorized'], isFalse);

      expect(artifact['buildNumber'], finalizedBuildNumber);
      expect(
        artifact['buildNumber'],
        latestFinalizedLedgerEntry['buildNumber'],
      );
      expect(artifact['buildNumber'], receiptRelease['buildNumber']);
      expect(
        artifact['version'],
        '${latestFinalizedLedgerEntry['versionName']}+$finalizedBuildNumber',
      );
      expect(artifact['sourceCommit'], finalizedAuthority['sourceCommit']);
      expect(release['buildNumber'], latestLedgerEntry['buildNumber']);
      expect(
        latestLedgerEntry['status'],
        pendingConstruction
            ? 'source-reserved-awaiting-remote-consumption'
            : 'remote-consumed-artifact-built-finalized-non-distributable',
      );
      if (!pendingConstruction) {
        expect(latestLedgerEntry['githubRunId'], finalization['githubRunId']);
        expect(
          latestLedgerEntry['governedPackageSha256'],
          finalization['governedPackageSha256'],
        );
      }
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
        finalizedAuthority['completionReceiptFile'],
      );
      expect(
        artifact['completionReceiptSha256'],
        finalizedAuthority['completionReceiptSha256'],
      );
      expect(
        _sha256(artifact['completionReceiptFile'] as String),
        artifact['completionReceiptSha256'],
      );
      expect(
        artifact['runtimeValidation'],
        runtimeValidationPassed
            ? 'PASSED_EXACT_BUILD${finalizedBuildNumber}_PHYSICAL_IN_PLACE_'
                'AUTHENTICATED_READ_ONLY_SURFACES'
            : 'NOT_ADJUDICATED_FOR_EXACT_BUILD$finalizedBuildNumber',
      );
      if (runtimeValidationPassed) {
        expect(
          artifact['deviceAcceptanceReceiptFile'],
          finalizedAuthority['deviceAcceptanceReceiptFile'],
        );
        expect(
          artifact['deviceAcceptanceReceiptSha256'],
          finalizedAuthority['deviceAcceptanceReceiptSha256'],
        );
        expect(
          _sha256(artifact['deviceAcceptanceReceiptFile'] as String),
          artifact['deviceAcceptanceReceiptSha256'],
        );
        expect(
          artifact['fullBusinessFlowValidation'],
          'MUTATING_FLOWS_NOT_ADJUDICATED',
        );
      }
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
        deployed['functionFleetReadbackDecision'],
        'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK',
      );
      expect(
        deployed['rulesAndIndexesReadbackDecision'],
        'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK',
      );
      expect(
        liveBackend['decision'],
        deployed['functionFleetReadbackDecision'],
      );
      expect(
        deployed['currentSourceFunctionDeployment'],
        expectedFunctionDeployment,
      );
      expect(
        deployed['currentSourceRulesAndIndexesDeployment'],
        expectedFirestoreDeployment,
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
        deployed['rulesAndIndexesReadbackDecision'],
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
        (rulesReadback['receiptSha256'] as String).toUpperCase(),
        (firestoreAuthority['receiptCanonicalSha256'] as String).toUpperCase(),
      );
      expect(
        deployed['rulesAndIndexesSourceCommit'],
        firestoreAuthority['sourceCommit'],
      );
      expect(
        deployed['rulesAndIndexesSourceCommit'],
        rulesReadbackBefore['commit'],
      );
      expect(
        verifiedRules['sourceSha256'],
        requiredSource['exactFirestoreRulesSha256'],
      );
      expect(currentFirestoreSource['rulesSha256'], currentRulesSha);
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
      expect(sourceIndexBinding['count'], currentFirestoreSource['indexCount']);
      expect(
        sourceIndexBinding['indexSetSha256'],
        currentFirestoreSource['indexSetSha256'],
      );
      expect(
        currentFirestoreSource['relationshipToDeployedBackend'],
        expectedFirestoreRelationship,
      );
      expect(
        currentFirestoreSource['productionDeploymentPerformed'],
        firestoreMatchesDeployed,
      );
      expect(
        currentFirestoreSource['productionRuntimeUseAuthorized'],
        firestoreMatchesDeployed,
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
      expect(predecessor['buildNumber'], priorFinalization['buildNumber']);
      expect(predecessor['file'], priorFinalization['completionReceiptFile']);
      expect(
        predecessor['sha256'],
        priorFinalization['completionReceiptSha256'],
      );
      expect(nextApproval['approved'], isTrue);
      expect(nextApprovalBuild['buildNumber'], candidateBuildNumber);
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
      expect(pilot['appliesToBuild16'], isFalse);
      expect(pilot['appliesToBuild17'], isFalse);
      expect(pilot['appliesToBuild$candidateBuildNumber'], isFalse);
      expect(
        next['minimumBuildNumber'],
        candidateBuildNumber + (pendingConstruction ? 0 : 1),
      );
      expect(
        next['status'],
        pendingConstruction
            ? !backendMatchesDeployed
                ? 'SOURCE_AUTHORIZED_AWAITING_GOVERNED_BACKEND_DEPLOYMENT'
                : !artifactSourceMatchesApproval
                ? 'SOURCE_SUCCESSOR_AWAITING_BUILD${candidateBuildNumber}_'
                    'ARTIFACT_SOURCE_REBIND'
                : 'SOURCE_AUTHORIZED_AWAITING_SIGNED_'
                    'BUILD${candidateBuildNumber}_CONSTRUCTION'
            : 'AWAITING_FRESH_GOVERNED_BUILD${candidateBuildNumber + 1}_'
                'APPROVAL',
      );
      expect(next.containsKey('sourceApprovalFile'), pendingConstruction);
      expect(
        next.containsKey('signingEnvironmentApprovalFile'),
        pendingConstruction,
      );
      expect(next['constructionRequiresFreshGovernedApproval'], isTrue);
      expect(next['deviceValidationRequiresExactNewArtifact'], isTrue);
      expect(next['pilotPromotionRequiresSeparateDecision'], isTrue);
      expect(state['localStore']['schemaVersion'], 8);
      expect(state['appCheck']['mutatingCallableSourceDefault'], isFalse);

      final readme = File('README.md').readAsStringSync();
      expect(
        readme,
        contains('Build $candidateBuildNumber (`${_packageVersion()}`)'),
      );
      expect(readme, isNot(contains('Build 12 is source authorized')));
    },
  );

  test('Build 16 phone smoke never implies migration or pilot authority', () {
    final build17Approval = _readObject(
      'release/approvals/build-number-17-successor-approval.json',
    );
    final build16Authority =
        (build17Approval['preservedCompletedBuild'] as Map)
            .cast<String, dynamic>();
    final receipt = _readObject(
      build16Authority['completionReceiptFile'] as String,
    );
    final smoke = _readObject(
      'release/evidence/build-16-device-installation-smoke.json',
    );
    final governedPackage =
        (receipt['governedPackage'] as Map).cast<String, dynamic>();
    final physical = (smoke['physicalDevice'] as Map).cast<String, dynamic>();
    final emulator = (smoke['emulator'] as Map).cast<String, dynamic>();
    final boundary = (smoke['boundary'] as Map).cast<String, dynamic>();
    final releaseBoundary =
        (receipt['releaseBoundary'] as Map).cast<String, dynamic>();

    expect(build16Authority['status'], 'completed-non-distributable');
    expect(build16Authority['buildNumber'], 16);
    expect(
      _sha256(build16Authority['completionReceiptFile'] as String),
      build16Authority['completionReceiptSha256'],
    );
    expect(
      _sha256('release/evidence/build-16-device-installation-smoke.json'),
      'FBAAFB5EBFC68F630C5576D41362EC50F4A502FADE65511A98A7F279BCD63BB0',
    );
    expect(smoke['status'], 'passed-to-authentication-boundary');
    expect(
      (smoke['release'] as Map)['apkSha256'],
      governedPackage['apkSha256'],
    );
    expect(physical['installedVersionCode'], 16);
    expect(physical['installationMode'], 'fresh-install');
    expect(physical['applicationDataCleared'], isFalse);
    expect(physical['deviceSerialRecorded'], isFalse);
    expect(physical['authenticatedBusinessFlowValidationCompleted'], isFalse);
    expect(
      emulator['upgradeResult'],
      'blocked-existing-installation-signer-mismatch',
    );
    expect(emulator['existingInstallationPreserved'], isTrue);
    expect(emulator['applicationUninstalled'], isFalse);
    expect(emulator['applicationDataCleared'], isFalse);
    expect(boundary.values, everyElement(isFalse));
    expect(build16Authority['runtimeValidationPassed'], isFalse);
    expect(releaseBoundary['controlledPilotApproved'], isFalse);
  });

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
