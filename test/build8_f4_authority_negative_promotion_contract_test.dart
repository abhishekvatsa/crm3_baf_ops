import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

List<String> _strings(dynamic value) {
  return (value as List<dynamic>).cast<String>();
}

void main() {
  test('Build 8 authority-negative promotion is exact and non-closing', () {
    final promotion = _json(
      'release/approvals/build-8-f4-authority-negative-promotion.json',
    );
    final ledger = _json('governance/programme-ledger.json');

    expect(promotion['schemaVersion'], 1);
    expect(
      promotion['approvalClass'],
      'CONTROLLED_BUILD8_F4_AUTHORITY_NEGATIVE_EVIDENCE',
    );
    final authority = _object(promotion['approvalAuthority']);
    expect(
      authority['authoringBaselineCommit'],
      'a0a0c7d8b7e854bf37e97c04e3fbaba32c7f7b24',
    );
    expect(
      authority['priorPhysicalPromotionSha256'],
      '39199AF090789F8A78F4372E8D05F6DBDEACAB635C9256F40B5DA3033312DFC1',
    );
    expect(authority['effectiveOnlyAfterMergedToCleanMain'], isTrue);

    final prerequisites = _object(promotion['adjudicatedPrerequisites']);
    expect(_strings(prerequisites['provedCriteria']), hasLength(4));
    expect(_strings(prerequisites['remainingCriteria']), <String>[
      'revocation next-operation denial',
      'wrong-role denials',
    ]);
    expect(prerequisites['evidence'], hasLength(3));

    final artifact = _object(promotion['artifactAuthority']);
    expect(artifact['versionCode'], 8);
    expect(artifact['applicationId'], 'in.co.sail.bsl.crm3.bafops');
    expect(
      artifact['governedPackageSha256'],
      '75362F9875CC5067012B4A5768720CB4AE0AD2C6A94B38C1F174E0FD1E1CA91F',
    );
    expect(
      artifact['apkSha256'],
      '7F6CD741431230689193A0DD9505918B2E865C0A500649B7F242EA4747303CCD',
    );
    expect(
      artifact['signerCertificateSha256'],
      '6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C',
    );

    final topology = _object(promotion['runtimeTopology']);
    expect(_object(topology['subject'])['kind'], 'PHYSICAL_ANDROID_DEVICE');
    expect(_object(topology['operator'])['kind'], 'ANDROID_VIRTUAL_DEVICE');
    expect(
      topology['subjectAndOperatorMustBeDifferentFirebaseIdentities'],
      isTrue,
    );
    expect(topology['rawIdentityRetained'], isFalse);

    expect(_strings(promotion['phaseOrder']), <String>[
      'Preflight',
      'CaptureRevoked',
      'CaptureRevocationRestored',
      'CaptureWrongRole',
      'CaptureFinalRestoration',
    ]);

    final composite = _object(promotion['wrongRoleCompositeEvidencePolicy']);
    expect(composite['mayClaimLivePhysicalMutationDenial'], isFalse);
    expect(composite['mayClaimWrongRoleCriterionReadyForAdjudication'], isTrue);
    expect(
      composite['reasonForCompositeMethod'],
      contains('guaranteed zero-write'),
    );

    final prohibited = _strings(promotion['prohibitedOperations']).join('\n');
    expect(prohibited, contains('direct Firestore'));
    expect(prohibited, contains('synthetic production'));
    expect(prohibited, contains('leave the subject revoked'));
    expect(prohibited, contains('claim a live server mutation denial'));
    expect(prohibited, contains('close STAGE2D-F4'));

    final boundary = _object(promotion['programmeBoundary']);
    expect(boundary['stage2dF4ExecutionAuthorized'], isTrue);
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
    expect(f4['evidence'], isEmpty);
  });

  test('authority-negative collector is byte-bound and restoration-gated', () {
    final script =
        File(
          'tools/release/Invoke-Build8F4AuthorityNegativeCampaign.ps1',
        ).readAsStringSync();

    for (final required in <String>[
      "'Preflight'",
      "'CaptureRevoked'",
      "'CaptureRevocationRestored'",
      "'CaptureWrongRole'",
      "'CaptureFinalRestoration'",
      "'fetch', 'origin', 'main'",
      "'Tracked-clean main'",
      "'Fresh main/origin parity'",
      'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FINAL',
      'Authority functions do not share one admitted deployed source.',
      'Authority-function deployment changed after the admitted fleet finalization.',
      'Function-fleet readback is not fresh for this campaign.',
      '\$ConfirmOperationsOnlyRoleSet',
      'EvidenceDirectory must be outside the repository.',
      "-ExpectedKind 'PHYSICAL'",
      "-ExpectedKind 'EMULATOR'",
      "'Subject target is an emulator.'",
      "'Operator target is not an emulator.'",
      'installed APK SHA-256',
      'Governed package SHA-256',
      'Embedded APK SHA-256',
      "-Name 'ro.build.fingerprint'",
      'Get-TextSha256 \$Serial',
      'Awaiting Approval',
      "'Same physical application process'",
      "'Subject Template authoring'",
      "'Subject Administration'",
      "'Operations Knowledge governance'",
      "'Operations Support diagnostics'",
      'restorationRequiredBeforeContinuation = \$true',
      'restorationRequiredBeforeFinalPass = \$true',
      'sameProcessAcrossEntireCampaign = \$true',
      'livePhysicalMutationDenialClaimed = \$false',
      'syntheticProductionMutationAttempted = \$false',
      "physicalCapabilityProfile = 'OPERATIONS_ONLY_SURFACES'",
      "operatorConfirmedRoleProfile = @('operations')",
      'stage2dF4Closed = \$false',
      'p07Closed = \$false',
      'pilotHandoutAuthorized = \$false',
      'FAIL_BUILD8_F4_AUTHORITY_NEGATIVE_REQUIRES_ADJUDICATION',
      'failedAttemptMayNotBeRelabelledPass = \$true',
      'rawUiRetained = \$false',
      'rawDeviceIdentifiersRetained = \$false',
      'rawAccountIdentifiersRetained = \$false',
      'tokensRetained = \$false',
    ]) {
      expect(script, contains(required), reason: required);
    }

    final lower = script.toLowerCase();
    for (final forbidden in <String>[
      "'uninstall'",
      "'pm', 'clear'",
      'firebase deploy',
      'gcloud ',
      'invoke-restmethod',
      'admin sdk',
      'appdistribution:distribute',
      'android_id',
      'ro.serialno',
      'stage2df4closed = \$true',
      'pilothandoutauthorized = \$true',
    ]) {
      expect(lower, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
