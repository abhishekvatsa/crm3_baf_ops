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
          'build-7-f4-firestore-compatibility-promotion.json',
        ).readAsStringSync(),
      ),
    );
  });

  test('Build 7 compatibility promotion is exact-target and non-closing', () {
    expect(promotion['schemaVersion'], 1);
    expect(
      promotion['approvalClass'],
      'CONTROLLED_EXACT_TARGET_BUILD7_FIRESTORE_COMPATIBILITY_EXECUTION',
    );

    final authority = _object(promotion['approvalAuthority']);
    expect(
      authority['baselineCommit'],
      '9b6bb0c27f8585470e743f352ccd2922561344a3',
    );
    expect(
      authority['baselineTree'],
      '98842e89d23a7dbbffc7e2e98436db8bb2580481',
    );

    final build6 = _object(promotion['build6Lineage']);
    expect(build6['versionCode'], 6);
    expect(
      build6['installedApkSha256'],
      '01D26049E200730EC1DBF0FEE85D483A9FA820D68F020110E57AC95AF2EBE755',
    );
    final build6Evidence = _object(build6['privateEvidence']);
    expect(build6Evidence['storedOutsideRepository'], isTrue);
    expect(
      build6Evidence['installReceiptSha256'],
      '0884185A8ACAB9BF4E9B099E3451189F296F4FC33A8B1BB7AB67CF7F05634F51',
    );
    expect(
      build6Evidence['approvedSigninReceiptSha256'],
      '00F8A27452E27CA38A7D67C452AF53584FFBC617D80A04B69F0C75DBD4BD90A0',
    );
    expect(
      build6Evidence['syncBaselineReceiptSha256'],
      'FF07D7CF1A10204823CD85C939AA569FD793740412837986ED828F18EFCA6CDF',
    );
    expect(build6Evidence['rawIdentityRetainedInRepository'], isFalse);

    final build7 = _object(promotion['build7ArtifactAuthority']);
    expect(build7['versionCode'], 7);
    expect(build7['sourceCommit'], 'd8619ef1a9c7bf53828523c4bca3efe33e4074f0');
    expect(build7['sourceCorrectionPullRequest'], 111);
    expect(build7['githubRunId'], 30757692948);
    expect(
      _object(build7['governedPackage'])['sha256'],
      'D6E2710481681F63651B13A9C5872B16BDADE90EB288E610DD59BE1B9B07ACE7',
    );
    expect(
      _object(build7['apk'])['sha256'],
      'EE5B5B7205A37F1FEF1F1B4C98CB1446ED544A123E130D7F3A4134E6A5E6DD56',
    );
    expect(_object(build7['apk'])['debuggable'], isFalse);
    expect(
      _object(build7['finalizationReceipt'])['sha256'],
      'F9788C0DD9BB7DB0B21A43FF461D68CEBC85A2135E16DA68E1ABA8342B1B1337',
    );

    final target = _object(promotion['targetAuthority']);
    expect(target['kind'], 'ANDROID_PHYSICAL_DEVICE');
    expect(target['model'], 'SM-G990E');
    expect(target['apiLevel'], 36);
    expect((target['adbSerialSha256'] as String).length, 64);
    expect((target['buildFingerprintSha256'] as String).length, 64);
    expect(target['requiresExactBuild6InstalledAtPreflight'], isTrue);
    expect(target['rawAdbSerialRetained'], isFalse);
    expect(target['rawBuildFingerprintRetained'], isFalse);
    expect(target['androidIdRead'], isFalse);

    final channel = _object(promotion['channel']);
    expect(channel['maxTargetCount'], 1);
    expect(channel['inPlaceUpgradeAuthorized'], isTrue);
    expect(channel['freshInstallAuthorized'], isFalse);
    expect(channel['boundedRemoteMutationAuthorized'], isTrue);
    expect(channel['deviceNetworkStateMutationAuthorized'], isFalse);
    expect(channel['externalDistributionAuthorized'], isFalse);
    expect(channel['pilotHandoutAuthorized'], isFalse);

    final phases =
        (promotion['requiredPhases'] as List<dynamic>)
            .map((phase) => _object(phase)['id'])
            .toSet();
    expect(phases, <String>{
      'preflight',
      'upgrade',
      'prove-read',
      'retire-row',
    });
    final recoveries =
        (promotion['authorizedRecoveryPhases'] as List<dynamic>)
            .map((phase) => _object(phase)['id'])
            .toSet();
    expect(recoveries, <String>{'finalize-upgrade', 'finalize-retirement'});

    final boundary = _object(promotion['programmeBoundary']);
    expect(boundary['stage2dF4ExecutionAuthorized'], isTrue);
    expect(boundary['stage2dF4CompatibilityEvidenceCreated'], isFalse);
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['p07ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['heldPullRequests87Through93Adjudicated'], isFalse);
    expect(boundary['productionBackfillAuthorized'], isFalse);
    expect(boundary['runtimeContractActivationAuthorized'], isFalse);
    expect(boundary['separateEvidenceAdjudicationRequired'], isTrue);

    final ledger = _object(
      jsonDecode(File('governance/programme-ledger.json').readAsStringSync()),
    );
    final f4 = (ledger['programmeGates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((record) => record['gateId'] == 'STAGE2D-F4');
    expect(f4['currentStatus'], 'CLOSED');
    expect(f4['authorization'], 'CLOSED_PASS');
    expect(
      _object(ledger['programmeDecision'])['nextMutation'],
      'NONE_ALL_PROGRAMME_GATES_CLOSED',
    );
    expect(
      _object(ledger['programmeDecision'])['pilotHandout'],
      'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER',
    );
  });

  test('only the controlled stamped row may move from active to retired', () {
    final record = _object(promotion['controlledRecordAuthority']);
    expect(record['collection'], 'knowledge_base');
    expect(record['documentId'], 'zz-f4-global-pull-compat-v1');
    expect(record['requiredInitialLifecycle'], 'active');
    expect(record['authorizedFinalLifecycle'], 'retired');
    expect(record['maximumKnowledgeDocumentUpdates'], 1);
    expect(record['expectedServerStampFollowUpOnSameDocument'], isTrue);
    expect(record['expectedGovernanceAudit'], isTrue);
    expect(record['archiveAuthorized'], isFalse);
    expect(record['restoreAuthorized'], isFalse);
    expect(record['deleteAuthorized'], isFalse);
    expect(record['secondKnowledgeRecordAuthorized'], isFalse);
    expect(
      record['retirementReason'],
      'Retire controlled F4 compatibility row during Build 7 Timestamp proof.',
    );
    expect(
      (record['retirementReason'] as String).length,
      greaterThanOrEqualTo(15),
    );

    final prohibited = (promotion['prohibitedOperations'] as List<dynamic>)
        .cast<String>()
        .join('\n');
    expect(
      prohibited,
      contains('any knowledge row other than zz-f4-global-pull-compat-v1'),
    );
    expect(prohibited, contains('archive, restore or delete'));
    expect(prohibited, contains('invoke manual global sync'));
    expect(prohibited, contains('directly write Firestore'));
    expect(prohibited, contains('runtime contracts'));
    expect(prohibited, contains('claim DEVICE_PROVED'));

    final failure = _object(promotion['failurePolicy']);
    expect(failure['stopUnlessExactBuild6InstalledAtPreflight'], isTrue);
    expect(failure['stopIfApprovedSessionIsNotPreservedAfterUpgrade'], isTrue);
    expect(
      failure['stopIfTemplateAuthoringKnowledgeLoaderDoesNotSettle'],
      isTrue,
    );
    expect(
      failure['retirementRequiresSeparatePriorPassingReadReceipt'],
      isTrue,
    );
    expect(
      failure['stopIfGovernedRetirementPostWriteCloudPullDoesNotComplete'],
      isTrue,
    );
    expect(failure['reinstallDuringUpgradeFinalizationAuthorized'], isFalse);
    expect(
      failure['secondRetirementWriteDuringFinalizationAuthorized'],
      isFalse,
    );
    expect(failure['retirementFinalizationRequiresCompletionWitness'], isTrue);
    expect(failure['failedPhaseMayNotBeRelabelledPass'], isTrue);
  });

  test('Build 7 harness is receipt-chained and mutation-bounded', () {
    final script =
        File(
          'tools/release/Invoke-Build7F4FirestoreCompatibilityCampaign.ps1',
        ).readAsStringSync();

    for (final required in <String>[
      "'FinalizeUpgrade'",
      "'FinalizeRetirement'",
      'Build 7 compatibility execution requires exact tracked-clean main equal to freshly fetched origin/main.',
      'The Build 7 compatibility promotion is not effective on its unmodified baseline.',
      'EvidenceDirectory must be outside the repository.',
      r'$evidenceRoot.Equals($root, [StringComparison]::OrdinalIgnoreCase)',
      'Build 7 finalization receipt SHA-256',
      'Build 6 private evidence',
      "'install', '--no-streaming', '-r', \$apkPath",
      'Application sandbox first-install continuity',
      'PASS_EXACT_BUILD7_IN_PLACE_UPGRADE_SESSION_PRESERVED',
      'Template Authoring',
      'Search asset, tag, task, procedure',
      'class="android.widget.ProgressBar"',
      'Knowledge Governance',
      'Search rowCode',
      r'$promotion.controlledRecordAuthority.documentId',
      r'$promotion.controlledRecordAuthority.retirementReason',
      'PASS_BUILD7_CONTROLLED_ROW_ACTIVE_PRECONDITION',
      r'templateAuthoringKnowledgeLoaderSettled = $true',
      r'firestoreTimestampDecodeClaimed = $false',
      r'compatibilityProofDeferredToGovernedPostWritePull = $true',
      'Retire the exact controlled F4 compatibility row',
      'Reason for retired',
      'controlled-row-retirement-completion-witness.json',
      'PASS_BUILD7_GOVERNED_RETIREMENT_PULL_AUDIT_AND_RENDER',
      'PASS_BUILD7_CONTROLLED_TIMESTAMP_ROW_RETIRED_POST_WRITE_RENDERED',
      'INTERRUPTED_AFTER_UPGRADE_BEFORE_RECEIPT',
      'INTERRUPTED_AFTER_RETIREMENT_BEFORE_RECEIPT',
      'rawUiRetained = \$false',
      'directFirestoreWriteUsed = \$false',
      'secondKnowledgeRecordMutated = \$false',
      'activeRowPreconditionReceiptPassed = \$true',
      'postWriteCloudPullCompleted = \$true',
      'governanceAuditCompleted = \$true',
      'nativeTimestampDecodePassed = \$true',
      'postGovernedWriteRendered = \$true',
      'productionBackfillAuthorized = \$false',
      'runtimeContractActivationAuthorized = \$false',
      'row state alone is insufficient',
    ]) {
      expect(script, contains(required), reason: required);
    }

    final proveReadStart = script.indexOf(
      "if (\$Phase -in @('ProveRead', 'RecoverProveReadLocator'))",
    );
    final retireReadChainStart = script.indexOf(
      "\$readReceipt = Get-Content",
      proveReadStart,
    );
    expect(proveReadStart, greaterThanOrEqualTo(0));
    expect(retireReadChainStart, greaterThan(proveReadStart));
    final proveReadBlock = script.substring(
      proveReadStart,
      retireReadChainStart,
    );
    expect(proveReadBlock, isNot(contains('exactQueryMatchCount')));
    expect(proveReadBlock, isNot(contains('pickerResultUiSha256')));
    expect(
      proveReadBlock,
      isNot(contains('firestoreTimestampDecodePassed = \$true')),
    );

    for (final forbidden in <String>[
      "'uninstall'",
      "'pm', 'clear'",
      'firebase deploy',
      'gcloud ',
      'appdistribution:distribute',
      'beginGlobalPullRun',
      'stampGlobalPullServerClock',
      'android_id',
      'ro.serialno',
      'pilotHandoutAuthorized = \$true',
      'stage2dF4ClosureAuthorized = \$true',
    ]) {
      expect(
        script.toLowerCase(),
        isNot(contains(forbidden.toLowerCase())),
        reason: forbidden,
      );
    }
  });
}
