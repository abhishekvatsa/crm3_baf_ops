import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(Object? value) =>
    Map<String, dynamic>.from(value! as Map);

void main() {
  late Map<String, dynamic> recovery;
  late Map<String, dynamic> promotion;
  late String harness;
  late String recoveryDoc;

  setUpAll(() {
    recovery = _object(
      jsonDecode(
        File(
          'release/approvals/build-7-f4-prove-read-locator-recovery.json',
        ).readAsStringSync(),
      ),
    );
    promotion = _object(
      jsonDecode(
        File(
          'release/approvals/'
          'build-7-f4-firestore-compatibility-promotion.json',
        ).readAsStringSync(),
      ),
    );
    harness =
        File(
          'tools/release/Invoke-Build7F4FirestoreCompatibilityCampaign.ps1',
        ).readAsStringSync();
    recoveryDoc =
        File(
          'docs/v4_2_r1/BUILD7_F4_PROVE_READ_LOCATOR_RECOVERY.md',
        ).readAsStringSync();
  });

  test('recovery is bound to the unchanged passing campaign chain', () {
    expect(recovery['schemaVersion'], 1);
    expect(
      recovery['approvalClass'],
      'CONTROLLED_BUILD7_PROVE_READ_LOCATOR_RECOVERY',
    );

    final original = _object(recovery['originalPromotion']);
    expect(
      original['path'],
      'release/approvals/build-7-f4-firestore-compatibility-promotion.json',
    );
    expect(
      original['sha256'],
      '39818BA2550AB962F87992467D0BD0AD7DD4B1D8CAE6D65CC738B80B6CB689F9',
    );
    expect(original['remainsUnmodified'], isTrue);
    expect(original['failedPhaseMayNotBeRelabelledPass'], isTrue);

    final source = _object(recovery['authorizedSourceCorrection']);
    expect(
      source['failedHarnessCommit'],
      '59489c25ff5e43faa6cca2fed6d9de1ff88cd126',
    );
    expect(
      source['failedHarnessTree'],
      '3e354bb648061e830a591e3b4781eee267c65fb3',
    );
    expect(source['mergedSuccessorRequired'], isTrue);

    final campaign = _object(recovery['campaignAuthority']);
    expect(
      campaign['evidenceDirectoryName'],
      'CRM3_BUILD7_F4_PHYSICAL_COMPATIBILITY_20260803_003953',
    );
    expect(campaign['sameCampaignRequired'], isTrue);
    expect(
      campaign['preflightReceiptSha256'],
      '11B8AD068F6ED082B7D8FCE430C9A1D0329465DD13E009253E52E13945F8599D',
    );
    expect(
      campaign['upgradeReceiptSha256'],
      'CB36DBBBACE68175782E55EA7509AF2B91D449D786D7B733A9F6768DFEBFB716',
    );
    expect(campaign['readReceiptExistedAfterFailure'], isFalse);
    expect(campaign['retirementReceiptExistedAfterFailure'], isFalse);

    final artifact = _object(recovery['artifactAndTargetAuthority']);
    final build7 = _object(promotion['build7ArtifactAuthority']);
    expect(artifact['build7ApkSha256'], _object(build7['apk'])['sha256']);
    expect(
      artifact['adbSerialSha256'],
      _object(promotion['targetAuthority'])['adbSerialSha256'],
    );
    expect(
      artifact['buildFingerprintSha256'],
      _object(promotion['targetAuthority'])['buildFingerprintSha256'],
    );
    expect(artifact['rawIdentifiersRetained'], isFalse);
    expect(
      recovery['controlledRecord'],
      'knowledge_base/zz-f4-global-pull-compat-v1',
    );
  });

  test('single recovery attempt is read-only and privacy-minimized', () {
    final failure = _object(recovery['failureAdjudication']);
    expect(failure['failedPhase'], 'ProveRead');
    expect(
      failure['stableFailureReason'],
      'Could not find UI control: Search rowCode',
    );
    expect(failure['markerPresentInHint'], isTrue);
    expect(failure['markerPresentInText'], isFalse);
    expect(failure['markerPresentInContentDescription'], isFalse);
    expect(failure['oldLocatorCouldResolve'], isFalse);
    expect(failure['correctedLocatorCanResolve'], isTrue);
    expect(failure['productionWriteOccurred'], isFalse);
    expect(failure['rawUiRetained'], isFalse);

    final retry = _object(recovery['retryAuthority']);
    expect(retry['phase'], 'RecoverProveReadLocator');
    expect(retry['maximumAttempts'], 1);
    expect(retry['sameEvidenceDirectoryRequired'], isTrue);
    expect(retry['readOnly'], isTrue);
    expect(retry['installAuthorized'], isFalse);
    expect(retry['reinstallAuthorized'], isFalse);
    expect(retry['remoteMutationAuthorized'], isFalse);
    expect(retry['retirementAuthorizedDuringRecovery'], isFalse);
    expect(retry['failureReproductionWitnessRequiredBeforeRetry'], isTrue);
    expect(retry['rawUiMustBeDeletedAfterHashing'], isTrue);

    final override = _object(recovery['narrowFailurePolicyOverride']);
    expect(override['originalField'], 'newEvidenceDirectoryRequiredForRestart');
    expect(override['originalValue'], isTrue);
    expect(override['scope'], 'READ_ONLY_UI_LOCATOR_RECOVERY_ONLY');
    expect(override['allOtherOriginalFailurePoliciesRemainEffective'], isTrue);

    final boundary = _object(recovery['programmeBoundary']);
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['p07ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['productionBackfillAuthorized'], isFalse);
    expect(boundary['runtimeContractActivationAuthorized'], isFalse);

    final originalFailurePolicy = _object(promotion['failurePolicy']);
    expect(
      originalFailurePolicy['newEvidenceDirectoryRequiredForRestart'],
      isTrue,
    );
  });

  test('harness reproduces hint-only mismatch before corrected read', () {
    for (final required in <String>[
      "'RecoverProveReadLocator'",
      'build-7-f4-prove-read-locator-recovery.json',
      'CONTROLLED_BUILD7_PROVE_READ_LOCATOR_RECOVERY',
      "'merge-base', '--is-ancestor'",
      'prove-read-locator-failure-witness.json',
      'Get-UiLocatorAttributeEvidence',
      "GetAttribute('hint')",
      'oldLocatorCouldResolve',
      'correctedLocatorCouldResolve',
      'PASS_BUILD7_PROVE_READ_LOCATOR_FAILURE_REPRODUCED_PRIVACY_SAFE',
      'READ_ONLY_HINT_ATTRIBUTE_LOCATOR_RECOVERY',
      r'locatorRecoveryApprovalSha256 = $locatorRecoveryApprovalSha256',
      r'locatorFailureWitnessSha256 = $locatorFailureWitnessSha256',
      "contains(@hint,'Search rowCode')",
      r'rawUiRetained = $false',
      r'remoteMutationPerformed = $false',
    ]) {
      expect(harness, contains(required), reason: required);
    }

    final readStart = harness.indexOf(
      "if (\$Phase -in @('ProveRead', 'RecoverProveReadLocator'))",
    );
    final readEnd = harness.indexOf(r'$readReceipt = Get-Content', readStart);
    expect(readStart, greaterThanOrEqualTo(0));
    expect(readEnd, greaterThan(readStart));
    final readBlock = harness.substring(readStart, readEnd);
    expect(readBlock, isNot(contains("'install'")));
    expect(readBlock, isNot(contains('ShouldProcess')));
    expect(readBlock, isNot(contains('Retire the exact controlled')));
    expect(readBlock, contains('remoteMutationPerformed = \$false'));

    expect(
      recoveryDoc,
      contains('does not relabel the failed `ProveRead` attempt as passing'),
    );
    expect(recoveryDoc, contains('does not close `STAGE2D-F4` or `P-07`'));
    expect(
      recoveryDoc,
      contains('does not activate the global-pull runtime contract'),
    );
  });
}
