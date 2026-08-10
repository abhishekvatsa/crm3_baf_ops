import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(Object? value) => (value as Map<String, dynamic>);

Map<String, dynamic> _readJson(String path) =>
    _object(jsonDecode(File(path).readAsStringSync()));

void main() {
  test('Build 8 sync marker is exact-receipt adjudicated', () {
    final evidence = _readJson(
      'release/evidence/build-8-f4-sync-marker-adjudication.json',
    );

    expect(evidence['schemaVersion'], 1);
    expect(evidence['decision'], 'PASS_BUILD8_F4_SYNC_MARKER_ADJUDICATED');
    final receipt = _object(evidence['externalReceipt']);
    expect(
      receipt['sha256'],
      '304F9F4D9CBA6DAD71B2FBF9B26B17F32C2830C1AFD74316B283E44A83ED9E8E',
    );
    expect(receipt['bytes'], 4775);
    expect(receipt['sourceCommit'], receipt['sourceOriginMain']);
    expect(receipt['postMergeRunId'], 30864309478);
    expect(receipt['decision'], 'PASS_BUILD8_F4_POST_ACTIVATION_SYNC_MARKER');

    final facts = _object(evidence['verifiedFacts']);
    expect(facts['fourJobPostMergeReleaseGatePassed'], isTrue);
    expect(facts['backendInventoryMissing'], 0);
    expect(facts['backendInventoryMalformed'], 0);
    expect(facts['installedVersionCode'], 8);
    expect(facts['productionSignerVerified'], isTrue);
    expect(facts['physicalDeviceVerified'], isTrue);
    expect(facts['approvedSessionVerified'], isTrue);
    expect(facts['pendingLocalBusinessWritesBefore'], 0);
    expect(facts['unresolvedLocalRejectionsBefore'], 0);
    expect(facts['manualSyncOutcome'], 'SUCCESS');
    expect(facts['pendingLocalBusinessWritesAfter'], 0);
    expect(facts['unresolvedLocalRejectionsAfter'], 0);

    final privacy = _object(evidence['privacyBoundary']);
    expect(privacy.values, everyElement(isFalse));
    final evidenceText = jsonEncode(evidence);
    expect(evidenceText, isNot(contains(r'C:\Users\')));
    expect(evidenceText, isNot(contains('AppData')));
  });

  test('offline promotion authorizes one exact-restoration phase only', () {
    final promotion = _readJson(
      'release/approvals/build-8-f4-offline-reconnect-promotion.json',
    );

    expect(promotion['approved'], isTrue);
    expect(
      promotion['approvalClass'],
      'CONTROLLED_EXACT_TARGET_BUILD8_OFFLINE_RECONNECT',
    );
    final authority = _object(promotion['approvalAuthority']);
    expect(
      authority['baselineCommit'],
      'f038cbe90ef0d85d99dc4f6be28b06b893a5ed69',
    );
    expect(
      authority['baselineTree'],
      'd58aeabb1699822fc4d022020274eb131d53b91c',
    );

    final sync = _object(promotion['syncAuthority']);
    expect(
      sync['adjudicationSha256'],
      'A165DFD44ED2B2BE9DDC27F20D4D982585EA7C0DC5749915BEE1C545DFAB5F5C',
    );
    expect(
      sync['externalReceiptSha256'],
      '304F9F4D9CBA6DAD71B2FBF9B26B17F32C2830C1AFD74316B283E44A83ED9E8E',
    );
    expect(sync['pendingLocalBusinessWritesAfter'], 0);
    expect(sync['unresolvedLocalRejectionsAfter'], 0);

    final apk = _object(_object(promotion['artifactAuthority'])['apk']);
    expect(apk['versionCode'], 8);
    expect(apk['debuggable'], isFalse);
    final target = _object(promotion['targetAuthority']);
    expect(target['maxTargetCount'], 1);
    expect(target['physicalDeviceRequired'], isTrue);
    expect(target['rawAdbSerialRetained'], isFalse);

    final mutations = _object(promotion['authorizedMutations']);
    expect(
      mutations['applicationInstallOrUpgrade'],
      'PROHIBITED_ALREADY_EXACT',
    );
    expect(
      mutations['wifiAndMobileData'],
      'TEMPORARY_DISABLE_THEN_EXACT_RESTORE',
    );
    expect(mutations['airplaneMode'], 'READ_ONLY_UNCHANGED');
    expect(mutations['firebaseBackend'], 'PROHIBITED');
    expect(mutations['deviceDataClearOrUninstall'], 'PROHIBITED');
    expect(mutations['distribution'], 'PROHIBITED');

    final boundary = _object(promotion['programmeBoundary']);
    expect(boundary['stage2dF4Status'], 'OPEN');
    expect(boundary['stage2dF4SyncMarkerCriterionProved'], isTrue);
    expect(boundary['offlineReconnectAuthorized'], isTrue);
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['p07ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['distributionAuthorized'], isFalse);
    expect(boundary['weakNetworkAuthorized'], isFalse);
    expect(boundary['revocationAuthorized'], isFalse);
    expect(boundary['wrongRoleExecutionAuthorized'], isFalse);
  });

  test('offline harness restores transport in finally and fails closed', () {
    final script =
        File(
          'tools/release/Invoke-Build8F4OfflineReconnect.ps1',
        ).readAsStringSync();

    for (final required in <String>[
      'PriorSyncReceiptPath must be outside the repository.',
      'Offline/reconnect requires exact tracked-clean main equal to origin/main.',
      'Post-merge release-gate must contain exactly four successful jobs.',
      'External sync-marker receipt SHA-256',
      'External sync-marker post-run pending writes',
      'Installed APK SHA-256',
      'Pre-offline pending local business writes',
      'Pre-offline unresolved local rejections',
      'FALSE_SUCCESS_WHILE_ALL_TRANSPORTS_DISABLED',
      'TRANSPORT_RESTORATION_FAILED',
      'EXACT_TRANSPORT_STATE_NOT_RESTORED',
      'POST_RECONNECT_VALIDATION_FAILED',
      'Post-reconnect pending local business writes',
      'Post-reconnect unresolved local rejections',
      'FAIL_BUILD8_OFFLINE_RECONNECT_REQUIRES_ADJUDICATION',
      'PASS_BUILD8_F4_OFFLINE_SAFE_EXACT_TRANSPORT_RESTORATION_AND_SYNC_RECOVERY',
      "stage2dF4Status = 'OPEN'",
      'stage2dF4ClosureAuthorized = \$false',
      'pilotHandoutAuthorized = \$false',
      'rawUiRetained = \$false',
      'businessPayloadRetained = \$false',
    ]) {
      expect(script, contains(required), reason: required);
    }

    expect(
      script,
      matches(
        RegExp(
          r'} finally \{\r?\n    \$transportRestoreStartedAt = '
          r'\[DateTimeOffset\]::UtcNow',
        ),
      ),
    );
    expect(
      RegExp(r'Set-TransportState').allMatches(script).length,
      greaterThanOrEqualTo(3),
    );
    expect(script, contains('-WifiOn \$initialTransport.wifiOn'));
    expect(script, contains('-MobileDataOn \$initialTransport.mobileDataOn'));
    expect(script, contains('failedPhaseMayNotBeRelabelledPass = \$true'));
    expect(script, contains('[IO.FileMode]::CreateNew'));

    final lower = script.toLowerCase();
    for (final forbidden in <String>[
      "'pm', 'clear'",
      "'uninstall'",
      'firebase deploy',
      'appdistribution:distribute',
      "'svc', 'airplane'",
    ]) {
      expect(lower, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('separate adjudication closes F4 while pilot handout stays closed', () {
    final ledger = _readJson('governance/programme-ledger.json');
    final gates =
        (ledger['programmeGates'] as List<dynamic>)
            .map(_object)
            .where((gate) => gate['gateId'] == 'STAGE2D-F4')
            .toList();
    expect(gates, hasLength(1));
    expect(gates.single['currentStatus'], 'CLOSED');
    expect(gates.single['authorization'], 'CLOSED_PASS');
    final decision = _object(ledger['programmeDecision']);
    expect(decision['nextMutation'], 'STAGE2D-F5');
    expect(decision['pilotHandout'], 'NOT_AUTHORIZED');

    final doc =
        File(
          'docs/v4_2_r1/BUILD8_F4_SYNC_MARKER_AND_OFFLINE_RECONNECT.md',
        ).readAsStringSync();
    expect(
      doc,
      contains(
        'Status: SYNC MARKER PROVED; EXACT-TARGET OFFLINE/RECONNECT PROPOSED',
      ),
    );
    expect(doc, contains('It does not close F4 or authorize distribution.'));
    expect(doc, contains('restores the exact initial Wi-Fi and mobile-data'));
  });

  test('passing offline receipt is exact-bound without overstating method', () {
    final evidence = _readJson(
      'release/evidence/build-8-f4-offline-reconnect-adjudication.json',
    );

    expect(
      evidence['decision'],
      'PASS_BUILD8_F4_OFFLINE_RECONNECT_ADJUDICATED',
    );
    final receipt = _object(evidence['externalReceipt']);
    expect(
      receipt['sha256'],
      'BE414FFFD556F0F5DEC741BF5598EFC9670524DF6DDCC68833572A192C8A3A77',
    );
    expect(receipt['bytes'], 6542);
    expect(receipt['sourceCommit'], receipt['sourceOriginMain']);
    expect(receipt['postMergeRunId'], 30932769330);
    expect(
      receipt['decision'],
      'PASS_BUILD8_F4_OFFLINE_SAFE_EXACT_TRANSPORT_RESTORATION_AND_SYNC_RECOVERY',
    );

    final facts = _object(evidence['verifiedFacts']);
    expect(facts['pendingLocalBusinessWritesBefore'], 0);
    expect(facts['unresolvedLocalRejectionsBefore'], 0);
    expect(facts['allTransportsDisabledDuringObservation'], isTrue);
    expect(facts['falseSuccessObserved'], isFalse);
    expect(facts['exactTransportStateRestored'], isTrue);
    expect(facts['initialWifiOn'], facts['restoredWifiOn']);
    expect(facts['initialMobileDataOn'], facts['restoredMobileDataOn']);
    expect(facts['initialAirplaneModeOn'], facts['restoredAirplaneModeOn']);
    expect(facts['postReconnectManualSyncOutcome'], 'SUCCESS');
    expect(facts['pendingLocalBusinessWritesAfter'], 0);
    expect(facts['unresolvedLocalRejectionsAfter'], 0);
    expect(facts['failureReceiptPresent'], isFalse);
    expect(facts['temporaryArtifactCountAfterExecution'], 0);

    final method = _object(evidence['methodQualification']);
    expect(method['offlineReconnectClaim'], 'PROVED');
    expect(method['bandwidthOrLatencyDegradationClaim'], 'NOT_TESTED');
    expect(method['nextMethodIsBandwidthThrottle'], isFalse);

    final boundary = _object(evidence['programmeBoundary']);
    expect(boundary['stage2dF4Status'], 'OPEN');
    expect(boundary['approvedSignInCriterionProved'], isTrue);
    expect(boundary['syncMarkerCriterionProved'], isTrue);
    expect(boundary['offlineReconnectCriterionProved'], isTrue);
    expect(boundary['weakNetworkCriterionProved'], isFalse);
    expect(boundary['revocationCriterionProved'], isFalse);
    expect(boundary['wrongRoleCriterionProved'], isFalse);
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['distributionAuthorized'], isFalse);

    final evidenceText = jsonEncode(evidence);
    expect(evidenceText, isNot(contains(r'C:\Users\')));
    expect(evidenceText, isNot(contains('AppData')));

    final doc =
        File(
          'docs/v4_2_r1/BUILD8_F4_OFFLINE_RECONNECT_RESULT.md',
        ).readAsStringSync();
    expect(doc, contains('Status: OFFLINE/RECONNECT PROVED; F4 REMAINS OPEN'));
    expect(doc, contains('does not claim measured low bandwidth'));
    expect(doc, contains('bandwidth-throttling result.'));
  });
}
