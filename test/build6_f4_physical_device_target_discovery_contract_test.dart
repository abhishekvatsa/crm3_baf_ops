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
  test(
    'physical-device discovery is read-only and creates no F4 authority',
    () {
      final promotion = _readJson(
        'release/approvals/build-6-f4-physical-device-target-discovery.json',
      );
      final ledger = _readJson('governance/programme-ledger.json');

      expect(promotion['schemaVersion'], 1);
      expect(
        promotion['approvalClass'],
        'CONTROLLED_PHYSICAL_DEVICE_TARGET_DISCOVERY_ONLY',
      );
      final authority = _object(promotion['approvalAuthority']);
      expect(
        authority['baselineCommit'],
        'e48a97f4c2cc339b2316e1aaf2fc095d4f0efd93',
      );
      expect(
        authority['baselineTree'],
        '3a85ba1921e54298b82ff1ea80b5531df37bb474',
      );
      final amendment = _object(
        promotion['packageAbsenceCompatibilityAmendment'],
      );
      expect(
        amendment['priorPromotionSha256'],
        '478F33AEF7807ED4803AB4005F66C1116A5325EDF2BDD54F03A125611AFF2525',
      );
      expect(
        amendment['priorHarnessSha256'],
        'C9CF01717AA2EB18DE508CF794049819F656CD1EE6807A1EAC4FD783DECD3166',
      );
      expect(amendment['observedPackageLookupExitCode'], 1);
      expect(amendment['observedPackageLookupOutputEmpty'], isTrue);
      expect(amendment['packageInstallationAuthorized'], isFalse);
      expect(amendment['applicationLaunchAuthorized'], isFalse);
      expect(amendment['remoteMutationExpansion'], isFalse);
      expect(amendment['artifactOrTargetExpansion'], isFalse);
      expect(amendment['stage2dF4ExecutionExpansion'], isFalse);
      expect(amendment['priorAttemptCreatedDeviceEvidence'], isFalse);

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

      final channel = _object(promotion['channel']);
      expect(channel['maxTargetCount'], 1);
      expect(channel['transport'], 'DIRECT_ADB_READ_ONLY_TARGET_DISCOVERY');
      expect(channel['physicalDeviceInstallationAuthorized'], isFalse);
      expect(channel['applicationLaunchAuthorized'], isFalse);
      expect(channel['firebaseAuthenticationAuthorized'], isFalse);
      expect(channel['remoteMutationAuthorized'], isFalse);
      expect(channel['externalDistributionAuthorized'], isFalse);
      final target = _object(channel['target']);
      expect(target['kind'], 'ANDROID_PHYSICAL_DEVICE_CANDIDATE');
      expect(target['bindingStatus'], 'UNBOUND_UNTIL_DISCOVERY_RECEIPT');
      expect(target['requiresPackageAbsent'], isTrue);
      expect(target['requiresNonEmulatorEvidence'], isTrue);

      final next = _object(promotion['nextAuthorityStep']);
      expect(next['required'], isTrue);
      expect(next['mayReuseThisApprovalForInstallation'], isFalse);
      expect(next['mayReuseThisApprovalForF4Execution'], isFalse);

      final boundary = _object(promotion['programmeBoundary']);
      expect(boundary['intendedRecords'], isEmpty);
      expect(boundary['stage2dF4TargetDiscoveryAuthorized'], isTrue);
      expect(boundary['stage2dF4ExecutionAuthorized'], isFalse);
      expect(boundary['stage2dF4DeviceEvidenceCreated'], isFalse);
      expect(boundary['stage2dF4ClosureAuthorized'], isFalse);
      expect(boundary['p07ClosureAuthorized'], isFalse);
      expect(boundary['pilotHandoutAuthorized'], isFalse);

      final prohibited = _strings(promotion['prohibitedOperations']).join('\n');
      expect(prohibited, contains('install, upgrade, downgrade, uninstall'));
      expect(prohibited, contains('Google or Firebase Authentication'));
      expect(prohibited, contains('retain the raw ADB serial'));
      expect(prohibited, contains('close STAGE2D-F4'));

      final decision = _object(ledger['programmeDecision']);
      expect(decision['nextMutation'], 'STAGE2D-F6');
      expect(decision['pilotHandout'], 'NOT_AUTHORIZED');
      final f4 = (ledger['programmeGates'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .singleWhere((record) => record['gateId'] == 'STAGE2D-F4');
      expect(f4['currentStatus'], 'CLOSED');
      expect(f4['authorization'], 'CLOSED_PASS');
      expect((f4['evidence'] as List<dynamic>), hasLength(4));
    },
  );

  test('target-discovery harness rejects emulators and has no mutation path', () {
    final script =
        File(
          'tools/release/Invoke-Build6F4PhysicalDeviceTargetDiscovery.ps1',
        ).readAsStringSync();

    for (final required in <String>[
      'Get-FileHash -LiteralPath \$Path -Algorithm SHA256',
      'Get-TextSha256',
      'Expand-ExactZipEntry',
      'Target discovery requires exact tracked-clean main equal to freshly fetched origin/main.',
      'The promotion record is not effective on its unmodified baseline.',
      'EvidenceDirectory must be outside the repository.',
      'The governed Build 6 APK is unexpectedly debuggable.',
      "'ro.kernel.qemu'",
      "'ro.boot.qemu'",
      'F4 target discovery rejects Android emulators.',
      '(?i)(generic|emulator|sdk_gphone|goldfish|ranchu)',
      'The physical target does not expose Google Play Services.',
      'Physical target discovery requires the CRM-III package to be absent',
      r'$existingPackage.exitCode -in @(0, 1)',
      r'[string]::IsNullOrWhiteSpace(',
      r'$existingPackage.output',
      'CRM-III package-presence lookup failed; absence is not proved.',
      'adbSerialSha256 = Get-TextSha256 \$DeviceSerial',
      'buildFingerprintSha256 = Get-TextSha256 \$fingerprint',
      'rawAdbSerialRetained = \$false',
      'androidIdRead = \$false',
      'PASS_BUILD6_F4_PHYSICAL_DEVICE_TARGET_CANDIDATE_READ_ONLY',
    ]) {
      expect(script, contains(required), reason: required);
    }

    for (final forbidden in <String>[
      "'install'",
      "'uninstall'",
      "'pm', 'clear'",
      "'shell', 'input'",
      "'shell', 'monkey'",
      'firebase deploy',
      'gcloud ',
      'appdistribution:distribute',
      'ro.serialno',
      'android_id',
    ]) {
      expect(
        script.toLowerCase(),
        isNot(contains(forbidden.toLowerCase())),
        reason: forbidden,
      );
    }
  });
}
