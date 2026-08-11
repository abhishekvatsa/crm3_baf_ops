import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(Object? value) => value as Map<String, dynamic>;

Map<String, dynamic> _readJson(String path) =>
    _object(jsonDecode(File(path).readAsStringSync()));

void main() {
  test('promotion binds exact Build 8 intermittent-connectivity scope', () {
    final promotion = _readJson(
      'release/approvals/build-8-f4-intermittent-connectivity-promotion.json',
    );

    expect(promotion['approved'], isTrue);
    expect(
      promotion['approvalClass'],
      'CONTROLLED_EXACT_TARGET_BUILD8_INTERMITTENT_CONNECTIVITY',
    );
    expect(promotion['effectiveCondition'], contains('five-job'));

    final authority = _object(promotion['approvalAuthority']);
    expect(
      authority['baselineCommit'],
      'de76c8e67e7e3693d12b6965f1d0589a9b1a7a50',
    );
    expect(
      authority['baselineTree'],
      '80fa29d2bf165f918b0adee0fcc8d2d8bbe2964d',
    );

    final offline = _object(promotion['offlineAuthority']);
    expect(
      offline['adjudicationSha256'],
      '95A5B0C0524B98104E47A69EDA1EFC7D827D9A5E8125042F83C20A742D7A0394',
    );
    expect(
      offline['externalReceiptSha256'],
      'BE414FFFD556F0F5DEC741BF5598EFC9670524DF6DDCC68833572A192C8A3A77',
    );
    expect(offline['externalReceiptBytes'], 6542);
    expect(offline['exactTransportStateRestored'], isTrue);
    expect(offline['pendingLocalBusinessWritesAfter'], 0);
    expect(offline['unresolvedLocalRejectionsAfter'], 0);

    final profile = _object(promotion['intermittentProfile']);
    expect(profile['cycleCount'], 3);
    expect(profile['minimumDisconnectedHoldSecondsPerCycle'], 5);
    expect(profile['disconnectedSyncObservationTimeoutSecondsPerCycle'], 8);
    expect(profile['minimumRestoredHoldSecondsPerCycle'], 10);
    expect(profile['maximumProfileSeconds'], 300);
    expect(profile['restoreAndReadBackAfterEveryCycle'], isTrue);
    expect(profile['falseDisconnectedSuccessFailsClosed'], isTrue);

    final amendment = _object(
      promotion['durationBoundControlledStopAmendment'],
    );
    expect(
      amendment['priorPromotionSha256'],
      '2EFA140B00BBC1D0FD6901026A4781FC2862C3C8C1DB9C19BB5EADE23520DB23',
    );
    final failure = _object(amendment['externalFailureReceipt']);
    expect(
      failure['sha256'],
      'C2104E26DA8C827DC4743CCCF5586F036B26FAB79041F00AFE31B0F6DA9F0435',
    );
    expect(failure['bytes'], 820);
    expect(failure['failureClass'], 'INTERMITTENT_PROFILE_DURATION_EXCEEDED');
    final observed = _object(amendment['observedResult']);
    expect(observed['completedCycles'], 3);
    expect(observed['profileDurationSeconds'], 233.35);
    expect(observed['priorMaximumProfileSeconds'], 180);
    expect(observed['exactTransportStateRestored'], isTrue);
    expect(observed['temporaryArtifactCountAfterExecution'], 0);
    expect(
      _object(amendment['authorityExpansion']).values,
      everyElement(isFalse),
    );

    final mutations = _object(promotion['authorizedMutations']);
    expect(mutations['preflightOnly'], 'READ_ONLY_NO_TRANSPORT_MUTATION');
    expect(
      mutations['wifiAndMobileData'],
      'THREE_TEMPORARY_DISABLE_AND_EXACT_RESTORE_CYCLES',
    );
    expect(mutations['airplaneMode'], 'READ_ONLY_UNCHANGED');
    expect(
      mutations['bandwidthLatencyPacketLossInjection'],
      'PROHIBITED_NOT_THIS_METHOD',
    );
    expect(mutations['userApprovalRevocationOrRoleMutation'], 'PROHIBITED');
    expect(mutations['firebaseBackend'], 'PROHIBITED');
    expect(mutations['deviceDataClearOrUninstall'], 'PROHIBITED');
    expect(mutations['distribution'], 'PROHIBITED');

    final boundary = _object(promotion['programmeBoundary']);
    expect(boundary['stage2dF4Status'], 'OPEN');
    expect(boundary['offlineReconnectCriterionProved'], isTrue);
    expect(boundary['intermittentConnectivityAuthorized'], isTrue);
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['p07ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['distributionAuthorized'], isFalse);
    expect(boundary['revocationAuthorized'], isFalse);
    expect(boundary['wrongRoleExecutionAuthorized'], isFalse);
  });

  test('harness restores every cycle and qualifies the evidence', () {
    final script =
        File(
          'tools/release/Invoke-Build8F4IntermittentConnectivity.ps1',
        ).readAsStringSync();

    for (final required in <String>[
      'PriorOfflineReceiptPath must be outside the repository.',
      'PriorFailureReceiptPath must be outside the repository.',
      'Intermittent connectivity requires exact tracked-clean main equal to origin/main.',
      'Post-merge release-gate must contain exactly five successful jobs.',
      'Android emulator app-shell integration (not physical-device evidence)',
      'External offline receipt SHA-256',
      'External offline transport restoration',
      'External controlled-stop receipt SHA-256',
      'Controlled-stop observed profile duration',
      'Installed APK SHA-256',
      'PASS_BUILD8_F4_INTERMITTENT_CONNECTIVITY_PREFLIGHT_READ_ONLY',
      'Pre-intermittent pending local business writes',
      'Pre-intermittent unresolved local rejections',
      'FALSE_SUCCESS_WHILE_ALL_TRANSPORTS_DISABLED',
      'TRANSPORT_RESTORATION_FAILED',
      'EXACT_TRANSPORT_STATE_NOT_RESTORED',
      'INTERMITTENT_PROFILE_DURATION_EXCEEDED',
      'FAIL_BUILD8_INTERMITTENT_CONNECTIVITY_REQUIRES_ADJUDICATION',
      'PASS_BUILD8_F4_BOUNDED_THREE_CYCLE_INTERMITTENT_CONNECTIVITY_RECOVERY',
      "stage2dF4Status = 'OPEN'",
      'stage2dF4ClosureAuthorized = \$false',
      'pilotHandoutAuthorized = \$false',
      "acceptedGateMethod = 'BOUNDED_THREE_CYCLE_INTERMITTENT_CONNECTIVITY'",
      'bandwidthThrottleClaimAuthorized = \$false',
      'rawUiRetained = \$false',
      'businessPayloadRetained = \$false',
      'priorFailureReceiptSha256 = Get-Sha256 \$priorFailureReceiptFile',
      'cycleDurationSeconds = \$cycleDurationSeconds',
      '[IO.FileMode]::CreateNew',
    ]) {
      expect(script, contains(required), reason: required);
    }

    expect(
      script,
      contains(
        r'$cycleNumber -le [int]$promotion.intermittentProfile.cycleCount',
      ),
    );
    expect(
      script.indexOf('if (\$PreflightOnly)'),
      lessThan(script.indexOf(r'$null = Set-TransportState')),
    );
    expect(
      RegExp(r'Set-TransportState').allMatches(script).length,
      greaterThanOrEqualTo(3),
    );
    expect(script, contains('-WifiOn \$initialTransport.wifiOn'));
    expect(script, contains('-MobileDataOn \$initialTransport.mobileDataOn'));
    expect(script, contains('failedPhaseMayNotBeRelabelledPass = \$true'));
    expect(
      script,
      contains("foreach (\$temporary in @(\$temporaryApk, \$installedApk))"),
    );

    final lower = script.toLowerCase();
    for (final forbidden in <String>[
      "'pm', 'clear'",
      "'uninstall'",
      'firebase deploy',
      'appdistribution:distribute',
      "'svc', 'airplane'",
      ' tc qdisc ',
    ]) {
      expect(lower, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
    'separate adjudication closes F4 while distribution stays unauthorized',
    () {
      final ledger = _readJson('governance/programme-ledger.json');
      final gate = (ledger['programmeGates'] as List<dynamic>)
          .map(_object)
          .singleWhere((record) => record['gateId'] == 'STAGE2D-F4');
      expect(gate['currentStatus'], 'CLOSED');
      expect(gate['authorization'], 'CLOSED_PASS');

      final decision = _object(ledger['programmeDecision']);
      expect(decision['nextMutation'], 'STAGE2D-F6');
      expect(decision['pilotHandout'], 'NOT_AUTHORIZED');

      final doc =
          File(
            'docs/v4_2_r1/BUILD8_F4_INTERMITTENT_CONNECTIVITY_PROMOTION.md',
          ).readAsStringSync();
      expect(
        doc,
        contains('Status: SOURCE AUTHORIZED; PHYSICAL EXECUTION PENDING'),
      );
      expect(doc, contains('does not claim low bandwidth'));
      expect(doc, contains('233.35-second profile exceeded'));
      expect(doc, contains('raises only the total ceiling to 300 seconds'));
      expect(
        doc,
        contains('Revocation and wrong-role evidence remain separate'),
      );
    },
  );

  test('passing result is exact-bound without overstating method or closure', () {
    final evidence = _readJson(
      'release/evidence/build-8-f4-intermittent-connectivity-adjudication.json',
    );

    expect(
      evidence['decision'],
      'PASS_BUILD8_F4_INTERMITTENT_CONNECTIVITY_ADJUDICATED',
    );
    final receipt = _object(evidence['externalReceipt']);
    expect(
      receipt['sha256'],
      '4BD8332FBCF80B6E809B5A3FFE94EDD7560C482D898B6B9E2F37D6F63422BCEC',
    );
    expect(receipt['bytes'], 8119);
    expect(receipt['sourceCommit'], receipt['sourceOriginMain']);
    expect(receipt['postMergeRunId'], 31030200224);
    expect(
      receipt['decision'],
      'PASS_BUILD8_F4_BOUNDED_THREE_CYCLE_INTERMITTENT_CONNECTIVITY_RECOVERY',
    );

    final lineage = _object(evidence['prerequisiteLineage']);
    expect(
      lineage['controlledStopFailureReceiptSha256'],
      'C2104E26DA8C827DC4743CCCF5586F036B26FAB79041F00AFE31B0F6DA9F0435',
    );
    expect(lineage['controlledStopFailureReceiptRelabelled'], isFalse);
    expect(lineage['controlledStopCompletedCycles'], 3);
    expect(lineage['controlledStopExactTransportStateRestored'], isTrue);

    final facts = _object(evidence['verifiedFacts']);
    expect(facts['fiveJobPostMergeReleaseGatePassed'], isTrue);
    expect(facts['pendingLocalBusinessWritesBefore'], 0);
    expect(facts['unresolvedLocalRejectionsBefore'], 0);
    expect(facts['cycleCount'], 3);
    expect(facts['requiredCycleCount'], 3);
    expect(facts['profileDurationSeconds'], 234.083);
    expect(facts['maximumProfileSeconds'], 300);
    final cycles = (facts['cycles'] as List<dynamic>).map(_object).toList();
    expect(cycles, hasLength(3));
    expect(cycles.map((cycle) => cycle['cycle']), <int>[1, 2, 3]);
    for (final cycle in cycles) {
      expect(cycle['allTransportsDisabled'], isTrue);
      expect(
        cycle['disconnectedManualSyncOutcome'],
        'TIMEOUT_WITHOUT_SUCCESS_MARKER',
      );
      expect(cycle['falseSuccessObserved'], isFalse);
      expect(cycle['exactTransportStateRestored'], isTrue);
      expect(cycle['restoredWifiOn'], facts['initialWifiOn']);
      expect(cycle['restoredMobileDataOn'], facts['initialMobileDataOn']);
      expect(cycle['restoredAirplaneModeOn'], facts['initialAirplaneModeOn']);
      expect(cycle['reconnectSyncOutcome'], 'SUCCESS');
      expect(cycle['pendingLocalBusinessWritesAfter'], 0);
      expect(cycle['unresolvedLocalRejectionsAfter'], 0);
    }
    expect(facts['everyCycleRestoredExactly'], isTrue);
    expect(facts['everyCycleRecoveredSync'], isTrue);
    expect(facts['falseSuccessObserved'], isFalse);
    expect(facts['pendingLocalBusinessWritesAfter'], 0);
    expect(facts['unresolvedLocalRejectionsAfter'], 0);
    expect(facts['failureReceiptPresent'], isFalse);
    expect(facts['retainedReceiptCount'], 1);
    expect(facts['temporaryArtifactCountAfterExecution'], 0);

    final execution = _object(evidence['executionBoundary']);
    expect(execution['networkStateTemporarilyChanged'], isTrue);
    expect(execution['exactNetworkStateRestored'], isTrue);
    expect(execution['applicationInstalledUpgradedOrCleared'], isFalse);
    expect(execution['authenticationSessionChanged'], isFalse);
    expect(execution['productionBusinessWriteAttempted'], isFalse);
    expect(execution['backendDeploymentPerformed'], isFalse);
    expect(execution['distributionPerformed'], isFalse);

    final privacy = _object(evidence['privacyBoundary']);
    expect(privacy.values, everyElement(isFalse));

    final method = _object(evidence['methodQualification']);
    expect(
      method['acceptedGateMethod'],
      'BOUNDED_THREE_CYCLE_INTERMITTENT_CONNECTIVITY',
    );
    expect(method['intermittentConnectivityClaim'], 'PROVED');
    expect(
      method['weakNetworkCriterionClaim'],
      'PROVED_BY_ACCEPTED_INTERMITTENT_METHOD',
    );
    expect(method['measuredLowBandwidth'], isFalse);
    expect(method['addedLatency'], isFalse);
    expect(method['injectedPacketLoss'], isFalse);
    expect(method['bandwidthLatencyOrPacketLossClaim'], 'NOT_TESTED');

    final boundary = _object(evidence['programmeBoundary']);
    expect(boundary['stage2dF4Status'], 'OPEN');
    expect(boundary['approvedSignInCriterionProved'], isTrue);
    expect(boundary['syncMarkerCriterionProved'], isTrue);
    expect(boundary['offlineReconnectCriterionProved'], isTrue);
    expect(boundary['intermittentConnectivityCriterionProved'], isTrue);
    expect(boundary['weakNetworkCriterionProved'], isTrue);
    expect(boundary['revocationCriterionProved'], isFalse);
    expect(boundary['wrongRoleCriterionProved'], isFalse);
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['p07ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['distributionAuthorized'], isFalse);

    final evidenceText = jsonEncode(evidence);
    expect(evidenceText, isNot(contains(r'C:\Users\')));
    expect(evidenceText, isNot(contains('AppData')));

    final doc =
        File(
          'docs/v4_2_r1/BUILD8_F4_INTERMITTENT_CONNECTIVITY_RESULT.md',
        ).readAsStringSync();
    expect(
      doc,
      contains('Status: INTERMITTENT CONNECTIVITY PROVED; F4 REMAINS OPEN'),
    );
    expect(doc, contains('does not claim measured low bandwidth'));
    expect(doc, contains('bandwidth-throttling result.'));
    expect(doc, contains('wrong-role denials remain outstanding'));
  });
}
