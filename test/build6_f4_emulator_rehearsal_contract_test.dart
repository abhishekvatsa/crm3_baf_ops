import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

List<String> _strings(dynamic value) {
  return (value as List<dynamic>).cast<String>();
}

void main() {
  test('Build 6 emulator rehearsal is exact and carries no F4 closure', () {
    final promotion = _readJson(
      'release/approvals/build-6-f4-emulator-rehearsal-promotion.json',
    );
    final ledger = _readJson('governance/programme-ledger.json');

    expect(promotion['schemaVersion'], 1);
    expect(
      promotion['approvalClass'],
      'CONTROLLED_INTERNAL_RUNTIME_REHEARSAL_ONLY',
    );
    final finalization = _object(promotion['upgradeFinalizationAmendment']);
    expect(
      finalization['priorPromotionSha256'],
      'C85F139AFCDD499354DC44AA9E3AF57E6216C3BB4A98D2DD570014C978BCAAED',
    );
    expect(finalization['evidenceOnlyFinalizationAuthorized'], isTrue);
    expect(finalization['reinstallAuthorized'], isFalse);
    expect(finalization['uninstallOrDataClearAuthorized'], isFalse);
    expect(finalization['artifactOrTargetExpansion'], isFalse);
    expect(finalization['remoteMutationExpansion'], isFalse);
    expect(finalization['pilotOrPhysicalDeviceExpansion'], isFalse);

    final artifact = _object(promotion['artifactAuthority']);
    expect(
      artifact['sourceCommit'],
      'f6fccc662119790bcc742ff91e00934117030948',
    );
    expect(artifact['versionCode'], 6);
    expect(artifact['applicationId'], 'in.co.sail.bsl.crm3.bafops');
    expect(
      _object(artifact['governedPackage'])['sha256'],
      'E36C39E40C4B92B0721DAD916F050F439644FDF7FC40A36C1EB579571EBD074E',
    );
    expect(
      _object(artifact['apk'])['sha256'],
      '01D26049E200730EC1DBF0FEE85D483A9FA820D68F020110E57AC95AF2EBE755',
    );
    expect(_object(artifact['apk'])['debuggable'], isFalse);
    expect(
      _object(artifact['signer'])['certificateSha256'],
      '6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C',
    );
    expect(
      _object(artifact['sourceRemediation'])['containedInArtifact'],
      isTrue,
    );

    final channel = _object(promotion['channel']);
    expect(channel['transport'], 'DIRECT_ADB_FROM_GOVERNED_LOCAL_CUSTODY');
    expect(channel['maxTargetCount'], 1);
    expect(channel['physicalDeviceInstallationAuthorized'], isFalse);
    expect(channel['firebaseAppDistributionUploadAuthorized'], isFalse);
    expect(channel['playConsoleUploadAuthorized'], isFalse);
    expect(channel['webOrPublicLinkAuthorized'], isFalse);

    final target = _object(channel['target']);
    expect(target['kind'], 'ANDROID_VIRTUAL_DEVICE');
    expect(target['avdName'], 'Pixel_9');
    expect(target['adbSerial'], 'emulator-5554');
    expect(target['minimumApiLevel'], 36);

    final provenance = _object(promotion['deviceProvenance']);
    final prior = _object(provenance['requiredPriorPackage']);
    expect(prior['versionCode'], 5);
    expect(prior['debuggable'], isFalse);
    expect(
      prior['apkSha256'],
      '1A39F9F375D785817862AA86BF3810FB5D99545E1E8BFFB7BA4F3CA69253774C',
    );
    expect(provenance['appDataClearAuthorized'], isFalse);
    expect(provenance['uninstallAuthorized'], isFalse);
    expect(provenance['downgradeAuthorized'], isFalse);

    final remote = _object(promotion['expectedRemoteMutationBoundary']);
    expect(remote['firebaseAuthenticationSessionCreated'], isTrue);
    expect(remote['ownUserProfileHydrationPermitted'], isTrue);
    expect(remote['otherFirestoreBusinessWritesAuthorized'], isFalse);
    expect(remote['otherUserReadsAuthorized'], isFalse);
    expect(remote['userAuthorityMutationAuthorized'], isFalse);
    expect(remote['backendDeploymentAuthorized'], isFalse);

    final boundary = _object(promotion['programmeBoundary']);
    expect(boundary['stage2dF4RehearsalAuthorized'], isTrue);
    expect(boundary['stage2dF4DeviceEvidenceCreated'], isFalse);
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['p07ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['physicalDevicePromotionRequiredNext'], isTrue);

    final decision = _object(ledger['programmeDecision']);
    expect(decision['nextMutation'], 'STAGE2D-F4');
    expect(decision['pilotHandout'], 'NOT_AUTHORIZED');
    final f4 = (ledger['programmeGates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((record) => record['gateId'] == 'STAGE2D-F4');
    expect(f4['currentStatus'], 'OPEN');
    expect((f4['evidence'] as List<dynamic>), isEmpty);

    final prohibited = _strings(promotion['prohibitedOperations']).join('\n');
    expect(prohibited, contains('physical-device installation'));
    expect(prohibited, contains('production business-record writes'));
    expect(prohibited, contains('user approval, revocation or role mutation'));
    expect(prohibited, contains('closing STAGE2D-F4'));
  });

  test('rehearsal harness fails closed around artifact, target and phases', () {
    final script =
        File(
          'tools/release/Invoke-Build6F4EmulatorRehearsal.ps1',
        ).readAsStringSync();

    for (final required in <String>[
      "'Preflight'",
      "'Upgrade'",
      "'FinalizeUpgrade'",
      "'PrepareSignIn'",
      "'BeginFreshSignIn'",
      "'VerifyFreshSignIn'",
      'Get-ZipEntrySha256',
      'Get-FileHash -LiteralPath \$Path -Algorithm SHA256',
      'Upgrade requires an exact clean main equal to origin/main.',
      'The promotion record is not effective on its unmodified baseline.',
      'The installed prerequisite is not exact Build 5.',
      "'install', '-r', '--no-streaming'",
      'Upgrade refuses to replace an existing receipt.',
      'FinalizeUpgrade refuses to replace an existing receipt.',
      'INTERRUPTED_AFTER_EXACT_IN_PLACE_UPGRADE_BEFORE_UI_RECEIPT',
      'FinalizeUpgrade does not reinstall the package.',
      'Get-UpgradeReceiptPromotionSha256',
      "PSObject.Properties['promotionSha256']",
      "PSObject.Properties['promotionLineage']",
      "PSObject.Properties['currentPromotionSha256']",
      'Upgrade receipt recovery lineage is incomplete.',
      'application sandbox was preserved',
      "//node[@content-desc='Sign Out']",
      'Choose an account',
      'Same-process first-listener proof',
      'User profile error',
      '[cloud_firestore/permission-denied]',
      'accountEmailRetained = \$false',
      'firebaseUidRetained = \$false',
      'PASS_BUILD6_FIRST_LISTENER_REMEDIATION_EMULATOR_REHEARSAL',
    ]) {
      expect(script, contains(required), reason: required);
    }

    for (final forbidden in <String>[
      'firebase deploy',
      'gcloud ',
      'appdistribution:distribute',
      'play.google.com',
      'adb uninstall',
      'pm clear',
    ]) {
      expect(
        script.toLowerCase(),
        isNot(contains(forbidden.toLowerCase())),
        reason: forbidden,
      );
    }
  });
}
