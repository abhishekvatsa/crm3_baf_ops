import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readObject(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

List<Map<String, dynamic>> _objects(dynamic value) => (value as List<dynamic>)
    .map((entry) => (entry as Map).cast<String, dynamic>())
    .toList(growable: false);

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

void main() {
  const deviceEvidencePath = 'release/evidence/build-27-device-acceptance.json';
  const ownerApprovalPath =
      'release/approvals/build27-staged-controlled-pilot-approval.json';
  const promotionPath =
      'release/evidence/build-27-staged-controlled-pilot-authorization.json';
  const finalizationPath =
      'release/evidence/build-27-finalization-closure.json';

  const deviceEvidenceSha =
      'DF9D15B5538D935BC0AAB754D6AE715137B93A544E26A25EC96F80FEF0E05382';
  const ownerApprovalSha =
      'A51EC5BD36854A4F0AD9353F771FAD2FD84A0695601219921467143A40D2DDF4';
  const promotionSha =
      'E5C22E28C09D5835BF5BCFC3F7F6BEF33A339ADF44DFF2CF6A73660600641750';
  const finalizationSha =
      '8F789CB5B8727048E541BCDA0DED6591A66DD04D440CFF10DE935481F6C281A6';
  const packageSha =
      'BCA671188C2CDA1298E415A4DF0EBD30DDA694A23DFEB27BF1D669A6956E2B42';
  const apkSha =
      '00846ABFD6342C938C7228601B528664C2FBC3B265B9BF74EF53607D3092AD6C';

  test('Build 27 exact evidence is immutable and privacy safe', () {
    expect(_sha256(finalizationPath), finalizationSha);
    expect(_sha256(deviceEvidencePath), deviceEvidenceSha);
    expect(_sha256(ownerApprovalPath), ownerApprovalSha);
    expect(_sha256(promotionPath), promotionSha);

    final finalization = _readObject(finalizationPath);
    final finalizationRelease = (finalization['release'] as Map)
        .cast<String, dynamic>();
    final finalizationBoundary = (finalization['releaseBoundary'] as Map)
        .cast<String, dynamic>();
    expect(finalizationRelease['buildNumber'], 27);
    expect(finalizationRelease['versionName'], '1.0.0-rc.17');
    expect(finalizationBoundary['controlledPilotApproved'], isFalse);
    expect(finalizationBoundary['distributionPerformed'], isFalse);

    final device = _readObject(deviceEvidencePath);
    final deviceRelease = (device['release'] as Map).cast<String, dynamic>();
    final physicalDevice = (device['physicalDevice'] as Map)
        .cast<String, dynamic>();
    final sync = (device['synchronization'] as Map).cast<String, dynamic>();
    final mutation = (device['businessMutationBoundary'] as Map)
        .cast<String, dynamic>();
    final deviceBoundary = (device['releaseBoundary'] as Map)
        .cast<String, dynamic>();
    expect(deviceRelease['buildNumber'], 27);
    expect(deviceRelease['governedPackageSha256'], packageSha);
    expect(deviceRelease['apkSha256'], apkSha);
    expect(deviceRelease['finalizationReceiptSha256'], finalizationSha);
    expect(physicalDevice['deviceSerialRecorded'], isFalse);
    expect(physicalDevice['accountIdentifierRecorded'], isFalse);
    expect(physicalDevice['installationMode'], 'adb-install-r-in-place');
    expect(physicalDevice['applicationDataPreserved'], isTrue);
    expect(physicalDevice['applicationDataCleared'], isFalse);
    expect(sync['lastSyncResult'], 'success');
    expect(sync['unsyncedRows'], 0);
    expect(sync['unresolvedRejections'], 0);
    expect(sync['pushFailed'], 0);
    expect(sync['processingErrors'], 0);
    expect(mutation['productionBusinessDataCreatedUpdatedOrDeleted'], isFalse);
    expect(deviceBoundary['controlledPilotApprovedByThisReceipt'], isFalse);
    expect(deviceBoundary['pilotHandoutPerformed'], isFalse);
  });

  test('Build 27 promotion is staged, bounded, and not a handout claim', () {
    final approval = _readObject(ownerApprovalPath);
    final exactArtifact = (approval['exactArtifact'] as Map)
        .cast<String, dynamic>();
    final authorizedPilot = (approval['authorizedPilot'] as Map)
        .cast<String, dynamic>();
    final approvalBoundary = (approval['mutationBoundary'] as Map)
        .cast<String, dynamic>();
    expect(
      approval['approvalClass'],
      'EXACT_BUILD27_STAGED_CONTROLLED_PILOT_PROMOTION',
    );
    expect(exactArtifact['buildNumber'], 27);
    expect(exactArtifact['governedPackageSha256'], packageSha);
    expect(exactArtifact['apkSha256'], apkSha);
    expect(authorizedPilot['maximumApprovedUsers'], 25);
    expect(authorizedPilot['maximumCanaryUsers'], 2);
    expect(authorizedPilot['maximumCanaryPhysicalDevices'], 2);
    expect(authorizedPilot['perHandoutExecutionReceiptRequired'], isTrue);
    expect(authorizedPilot['deviceDataClearAllowed'], isFalse);
    for (final key in <String>[
      'publicArtifactAuthorized',
      'githubActionsArtifactAsDistributionChannelAuthorized',
      'githubReleaseAuthorized',
      'firebaseAppDistributionAuthorized',
      'playConsoleAuthorized',
      'playStoreAuthorized',
      'webDistributionAuthorized',
      'unrestrictedDistributionAuthorized',
      'appCheckActivationAuthorized',
    ]) {
      expect(authorizedPilot[key], isFalse, reason: key);
    }
    expect(
      approvalBoundary['firebaseBusinessDataMutationAuthorizedByThisApproval'],
      isFalse,
    );
    expect(approvalBoundary['githubArtifactDeletionAuthorized'], isFalse);
    expect(approvalBoundary['pilotHandoutPerformedByThisApproval'], isFalse);

    final promotion = _readObject(promotionPath);
    final ownerApproval = (promotion['ownerApproval'] as Map)
        .cast<String, dynamic>();
    final admittedEvidence = (promotion['admittedEvidence'] as Map)
        .cast<String, dynamic>();
    final admittedBuild = (admittedEvidence['governedBuild'] as Map)
        .cast<String, dynamic>();
    final promotionScope = (promotion['promotion'] as Map)
        .cast<String, dynamic>();
    final closure = (promotion['closureBoundary'] as Map)
        .cast<String, dynamic>();
    expect(
      promotion['decision'],
      'PASS_BUILD27_STAGED_CONTROLLED_PILOT_AUTHORIZED',
    );
    expect(ownerApproval['receipt'], ownerApprovalPath);
    expect(ownerApproval['sha256'], ownerApprovalSha);
    expect(admittedBuild['buildNumber'], 27);
    expect(admittedBuild['finalizationReceiptSha256'], finalizationSha);
    expect(admittedBuild['mutatingBusinessFlowValidationCompleted'], isFalse);
    expect(promotionScope['authorizedPackageSha256'], packageSha);
    expect(promotionScope['authorizedApkSha256'], apkSha);
    expect(promotionScope['maximumApprovedUsers'], 25);
    expect(promotionScope['canaryUserCeiling'], 2);
    expect(promotionScope['canaryPhysicalDeviceCeiling'], 2);
    expect(promotionScope['pilotHandoutAuthorized'], isTrue);
    expect(promotionScope['pilotHandoutPerformedByThisRecord'], isFalse);
    expect(closure['approvedRosterFrozenByThisRecord'], isFalse);
    expect(closure['githubArtifactDeleted'], isFalse);
    expect(closure['firebaseMutationPerformed'], isFalse);
    expect(closure['businessDataReadOrWritten'], isFalse);
    expect(closure['unrestrictedDistributionAuthorized'], isFalse);
  });

  test('current policy projects Build 27 and preserves Build 11 history', () {
    final policy = _readObject('release/production-release-policy.json');
    final finalization = (policy['finalization'] as Map)
        .cast<String, dynamic>();
    final promotion = (policy['postBuildPromotion'] as Map)
        .cast<String, dynamic>();
    final distribution = (policy['distribution'] as Map)
        .cast<String, dynamic>();
    final historicalPromotions = _objects(
      policy['historicalPostBuildPromotions'],
    );
    final historicalAuthorities = _objects(
      policy['historicalDistributionAuthorities'],
    );

    expect(finalization['runtimeValidationPassed'], isTrue);
    expect(finalization['physicalInstallationReceiptFile'], deviceEvidencePath);
    expect(
      finalization['physicalInstallationReceiptSha256'],
      deviceEvidenceSha,
    );
    expect(finalization['fullBusinessFlowValidationCompleted'], isFalse);
    expect(finalization['controlledPilotApproved'], isTrue);
    expect(finalization['unrestrictedPlantReleaseApproved'], isFalse);
    expect(promotion['buildNumber'], 27);
    expect(promotion['promotionReceiptFile'], promotionPath);
    expect(promotion['promotionReceiptSha256'], promotionSha);
    expect(promotion['pilotHandoutPerformed'], isFalse);
    expect(distribution['authority'], 'exact-build27-staged-controlled-pilot');
    expect(distribution['approvedBuildNumber'], 27);
    expect(distribution['approvedPackageSha256'], packageSha);
    expect(distribution['approvedApkSha256'], apkSha);
    expect(distribution['maximumApprovedUsers'], 25);
    expect(distribution['canaryUserCeiling'], 2);
    expect(distribution['canaryPhysicalDeviceCeiling'], 2);
    expect(distribution['pilotHandoutPerformed'], isFalse);
    expect(distribution['unrestrictedPlantReleaseApproved'], isFalse);
    expect(
      policy['knownOpenGates'],
      containsAll(<String>[
        'BUILD27_MUTATING_BUSINESS_FLOW_VALIDATION',
        'BUILD27_STAGED_PILOT_HANDOUT_EXECUTION_RECEIPTS',
      ]),
    );

    final build11Promotion = historicalPromotions.singleWhere(
      (entry) => entry['buildNumber'] == 11,
    );
    final build11Authority = historicalAuthorities.singleWhere(
      (entry) => entry['approvedBuildNumber'] == 11,
    );
    expect(
      build11Promotion['promotionReceiptSha256'],
      '878897E7DAAF26BF099F3894CAA2EB6719E5F56CED3F7546E8D48E352C4E7400',
    );
    expect(
      build11Authority['authority'],
      'exact-build11-sealed-small-group-pilot',
    );
    expect(build11Authority['preservedHistoricalAuthority'], isTrue);
    expect(build11Authority['appliesToCurrentCandidate'], isFalse);
  });

  test('ledger and current index do not claim a distribution occurred', () {
    final ledger = _readObject('release/build-number-ledger.json');
    final build27 = _objects(
      ledger['entries'],
    ).singleWhere((entry) => entry['buildNumber'] == 27);
    expect(build27['runtimeValidationPassed'], isTrue);
    expect(build27['physicalInstallationReceiptSha256'], deviceEvidenceSha);
    expect(build27['controlledPilotApproved'], isTrue);
    expect(build27['pilotPromotionReceiptSha256'], promotionSha);
    expect(build27['fullBusinessFlowValidationCompleted'], isFalse);
    expect(build27['distributionPerformed'], isFalse);

    final state = _readObject('release/current-successor-state.json');
    final planes = (state['authorityPlanes'] as Map).cast<String, dynamic>();
    final artifact = (planes['latestFinalizedArtifact'] as Map)
        .cast<String, dynamic>();
    final pilot = (planes['controlledPilot'] as Map).cast<String, dynamic>();
    final historicalPilot = (planes['historicalControlledPilot'] as Map)
        .cast<String, dynamic>();
    expect(artifact['buildNumber'], 27);
    expect(artifact['pilotPromotionReceiptSha256'], promotionSha);
    expect(artifact['unrestrictedDistribution'], 'NOT_AUTHORIZED');
    expect(pilot['buildNumber'], 27);
    expect(pilot['handoutPerformed'], isFalse);
    expect(pilot['maximumApprovedUsers'], 25);
    expect(pilot['canaryUserCeiling'], 2);
    expect(pilot['canaryPhysicalDeviceCeiling'], 2);
    expect(pilot['appliesToCurrentSource'], isTrue);
    expect(historicalPilot['buildNumber'], 11);
    expect(historicalPilot['appliesToCurrentSource'], isFalse);
  });
}
