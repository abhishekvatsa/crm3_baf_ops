import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

List<Map<String, dynamic>> _objects(dynamic value) {
  return (value as List<dynamic>).cast<Map<String, dynamic>>();
}

List<String> _strings(dynamic value) {
  return (value as List<dynamic>).cast<String>();
}

void main() {
  test('physical F4 execution promotion is exact, bounded and non-closing', () {
    final promotion = _readJson(
      'release/approvals/build-6-f4-physical-device-execution-promotion.json',
    );
    final ledger = _readJson('governance/programme-ledger.json');

    expect(promotion['schemaVersion'], 1);
    expect(
      promotion['approvalClass'],
      'CONTROLLED_EXACT_TARGET_PHYSICAL_DEVICE_F4_EXECUTION',
    );
    final authority = _object(promotion['approvalAuthority']);
    expect(
      authority['baselineCommit'],
      '999600ce02045afa7806645020292f3036535ce3',
    );
    expect(
      authority['baselineTree'],
      '38b5829b86b154bf675aceb8cd2dc19012f3227f',
    );
    final amendment = _object(
      promotion['apiLevelBindingCompatibilityAmendment'],
    );
    expect(
      amendment['priorPromotionSha256'],
      '4E3ACCB9AFAFE59FED02B9904A4B2A108D9194834366860908327DCAEBBEABC5',
    );
    expect(
      amendment['priorHarnessSha256'],
      'EAF1F5B39195F006817290415EAD568376F7E5648348F80214DC578610CD1E8D',
    );
    expect(amendment['preflightReceiptCreated'], isFalse);
    expect(amendment['evidenceDirectoryCreated'], isFalse);
    expect(amendment['packageInstallationPerformed'], isFalse);
    expect(amendment['applicationLaunchPerformed'], isFalse);
    expect(amendment['authenticationSessionCreated'], isFalse);
    expect(amendment['remoteMutationPerformed'], isFalse);
    expect(amendment['artifactOrTargetExpansion'], isFalse);
    expect(amendment['stage2dF4AuthorityExpansion'], isFalse);
    expect(amendment['pilotOrDistributionExpansion'], isFalse);

    final discovery = _object(promotion['discoveryAuthority']);
    expect(
      discovery['promotionSha256'],
      'A000789E637109EC238C7E6AC718850239F452BA7FD6F1E48EF8782A6142ABC4',
    );
    expect(
      discovery['receiptSha256'],
      '440874E51450BABA99ADD59AB47D19BF8D240F07BE9323373822E2FD81DB2825',
    );
    expect(
      discovery['decision'],
      'PASS_BUILD6_F4_PHYSICAL_DEVICE_TARGET_CANDIDATE_READ_ONLY',
    );
    expect(discovery['zeroMutationBoundaryProved'], isTrue);

    final artifact = _object(promotion['artifactAuthority']);
    expect(artifact['applicationId'], 'in.co.sail.bsl.crm3.bafops');
    expect(artifact['versionCode'], 6);
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

    final target = _object(promotion['targetAuthority']);
    expect(target['kind'], 'ANDROID_PHYSICAL_DEVICE');
    expect(target['adbSerialSha256'], hasLength(64));
    expect(target['buildFingerprintSha256'], hasLength(64));
    expect(target['apiLevel'], 36);
    expect(target['requiresGooglePlayServices'], isTrue);
    expect(target['requiresPackageAbsentAtPreflight'], isTrue);
    expect(target['rawAdbSerialRetained'], isFalse);
    expect(target['rawBuildFingerprintRetained'], isFalse);
    expect(target['androidIdRead'], isFalse);

    final channel = _object(promotion['channel']);
    expect(channel['maxTargetCount'], 1);
    expect(channel['physicalDeviceInstallationAuthorized'], isTrue);
    expect(channel['applicationLaunchAuthorized'], isTrue);
    expect(channel['firebaseAuthenticationAuthorized'], isTrue);
    expect(channel['boundedRemoteMutationAuthorized'], isTrue);
    expect(channel['externalDistributionAuthorized'], isFalse);
    expect(channel['pilotHandoutAuthorized'], isFalse);

    final identities = _object(promotion['identitySeparation']);
    expect(identities['subjectRequiredRolesInclude'], <dynamic>['si']);
    expect(identities['subjectProhibitedRoles'], <dynamic>['admin']);
    expect(identities['subjectMustNotBeLastApprovedAdmin'], isTrue);
    expect(identities['subjectInitialRolesMustBeCaptured'], isTrue);
    expect(identities['operatorMustRemainApprovedAdmin'], isTrue);
    expect(identities['stopIfSeparationCannotBeProved'], isTrue);

    final phaseIds =
        _objects(
          promotion['requiredPhases'],
        ).map((phase) => phase['id']).toSet();
    expect(phaseIds, <String>{
      'approved-sign-in',
      'sync-marker',
      'offline-reconnect',
      'weak-network',
      'revocation-next-operation-denial',
      'wrong-role-denials',
    });
    final sync = _objects(
      promotion['requiredPhases'],
    ).singleWhere((phase) => phase['id'] == 'sync-marker');
    expect(sync['operation'], contains('zero queued local business writes'));
    final wrongRole = _objects(
      promotion['requiredPhases'],
    ).singleWhere((phase) => phase['id'] == 'wrong-role-denials');
    expect(
      _strings(wrongRole['requiredEvidence']).join('\n'),
      contains('server-authoritative admin/SI mutation attempt is denied'),
    );

    final prohibited = _strings(promotion['prohibitedOperations']).join('\n');
    expect(prohibited, contains('synthetic production tickets'));
    expect(prohibited, contains('direct Firestore write'));
    expect(prohibited, contains('leave the subject revoked'));
    expect(prohibited, contains('claim DEVICE_PROVED'));

    final failurePolicy = _object(promotion['failurePolicy']);
    expect(
      failurePolicy['interruptedInstallEvidenceFinalizationAuthorized'],
      isTrue,
    );
    expect(failurePolicy['finalizationRequiresExactInstalledApkHash'], isTrue);
    expect(failurePolicy['reinstallDuringFinalizationAuthorized'], isFalse);

    final boundary = _object(promotion['programmeBoundary']);
    expect(boundary['intendedRecords'], isEmpty);
    expect(boundary['stage2dF4ExecutionAuthorized'], isTrue);
    expect(boundary['stage2dF4DeviceEvidenceCreated'], isFalse);
    expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
    expect(boundary['p07ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['separateEvidenceAdjudicationRequired'], isTrue);

    final decision = _object(ledger['programmeDecision']);
    expect(decision['nextMutation'], 'STAGE2D-F4');
    expect(decision['pilotHandout'], 'NOT_AUTHORIZED');
    final f4 = (ledger['programmeGates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((record) => record['gateId'] == 'STAGE2D-F4');
    expect(f4['currentStatus'], 'OPEN');
    expect((f4['evidence'] as List<dynamic>), isEmpty);
  });

  test('physical F4 harness is target-bound and privacy-minimized', () {
    final script =
        File(
          'tools/release/Invoke-Build6F4PhysicalDeviceCampaign.ps1',
        ).readAsStringSync();

    for (final required in <String>[
      "'FinalizeInstall'",
      "'BeginApprovedSignIn'",
      'Target-discovery receipt SHA-256',
      'Physical F4 execution requires exact tracked-clean main equal to freshly fetched origin/main.',
      'The execution promotion is not effective on its unmodified baseline.',
      'EvidenceDirectory must be outside the repository.',
      'Get-TextSha256 \$DeviceSerial',
      "-Name 'ro.build.fingerprint'",
      "-Name 'ro.kernel.qemu'",
      r'$observedApiLevel = [int](Get-DeviceProperty',
      r'$expectedApiLevel = [int]$promotion.targetAuthority.apiLevel',
      'Assert-Equal `\n  -Actual \$observedApiLevel `\n  -Expected \$expectedApiLevel `\n  -Label \'Physical target API level\'',
      "'install', '--no-streaming', \$apkPath",
      'Installed APK SHA-256',
      "'Sign in with Google'",
      "'Awaiting Approval'",
      'rawUiRetained = \$false',
      'accountEmailRetained = \$false',
      'firebaseUidRetained = \$false',
      'PASS_APPROVED_SIGNIN_CAPTURED_FULL_F4_MATRIX_REMAINS_OPEN',
    ]) {
      expect(script, contains(required), reason: required);
    }

    for (final forbidden in <String>[
      "'uninstall'",
      "'pm', 'clear'",
      'firebase deploy',
      'gcloud ',
      'appdistribution:distribute',
      'android_id',
      'ro.serialno',
      'stage2dF4Status = \'CLOSED\'',
      'pilotHandoutAuthorized = \$true',
      "Assert-Equal `\n  [int](Get-DeviceProperty",
    ]) {
      expect(
        script.toLowerCase(),
        isNot(contains(forbidden.toLowerCase())),
        reason: forbidden,
      );
    }
  });
}
