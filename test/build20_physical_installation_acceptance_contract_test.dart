import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readObject(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

void main() {
  test('Build 20 physical installation condition is exact and bounded', () {
    const receiptPath =
        'release/evidence/build-20-physical-installation-acceptance.json';
    final receipt = _readObject(receiptPath);
    final release = (receipt['release'] as Map).cast<String, dynamic>();
    final physical = (receipt['physicalDevice'] as Map).cast<String, dynamic>();
    final startup = (receipt['startup'] as Map).cast<String, dynamic>();
    final migration =
        (receipt['localStoreMigration'] as Map).cast<String, dynamic>();
    final recovery =
        (receipt['synchronizationRecovery'] as Map).cast<String, dynamic>();
    final backend =
        (receipt['backendIdentityQualification'] as Map)
            .cast<String, dynamic>();
    final mutations =
        (receipt['businessMutationBoundary'] as Map).cast<String, dynamic>();
    final adjudication =
        (receipt['adjudication'] as Map).cast<String, dynamic>();
    final boundary =
        (receipt['releaseBoundary'] as Map).cast<String, dynamic>();
    final finalization = _readObject(
      release['finalizationReceiptFile'] as String,
    );
    final policy = _readObject('release/production-release-policy.json');
    final policyFinalization =
        (policy['finalization'] as Map).cast<String, dynamic>();
    final policyRelease = (policy['release'] as Map).cast<String, dynamic>();
    final versionPolicy =
        (policy['versionPolicy'] as Map).cast<String, dynamic>();
    final priorCompletedBuild =
        (policyFinalization['priorCompletedBuild'] as Map)
            .cast<String, dynamic>();
    final currentBuildNumber = policyRelease['buildNumber'] as int;
    final priorCompletedBuildNumber = priorCompletedBuild['buildNumber'] as int;
    final ledger = _readObject('release/build-number-ledger.json');
    final ledgerEntry = (ledger['entries'] as List)
        .cast<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .singleWhere((entry) => entry['buildNumber'] == 20);
    final governedPackage =
        (finalization['governedPackage'] as Map).cast<String, dynamic>();

    expect(
      receipt['evidenceType'],
      'production-build-physical-installation-acceptance',
    );
    expect(
      receipt['status'],
      'passed-exact-build20-physical-in-place-authenticated-startup-and-local-recovery',
    );
    expect(release['buildNumber'], 20);
    expect(currentBuildNumber, greaterThan(20));
    expect(priorCompletedBuildNumber, currentBuildNumber - 1);
    expect(versionPolicy['ledgerFile'], 'release/build-number-ledger.json');
    expect(
      release['sourceCommit'],
      (finalization['sourceAuthority'] as Map)['commit'],
    );
    expect(
      _sha256(release['finalizationReceiptFile'] as String),
      release['finalizationReceiptSha256'],
    );
    expect(release['apkSha256'], governedPackage['apkSha256']);
    expect(release['certificateSha256'], governedPackage['certificateSha256']);
    expect(
      ledgerEntry['completionReceiptFile'],
      release['finalizationReceiptFile'],
    );
    expect(
      ledgerEntry['completionReceiptSha256'],
      _sha256(release['finalizationReceiptFile'] as String),
    );
    expect(ledgerEntry['physicalInstallationConditionPassed'], isTrue);
    expect(ledgerEntry['physicalInstallationReceiptFile'], receiptPath);
    expect(
      ledgerEntry['physicalInstallationReceiptSha256'],
      _sha256(receiptPath),
    );
    expect(ledgerEntry['runtimeValidationPassed'], isFalse);
    expect(ledgerEntry['controlledPilotApproved'], isFalse);

    expect(physical['deviceSerialRecorded'], isFalse);
    expect(physical['accountIdentifierRecorded'], isFalse);
    expect(physical['priorVersionCode'], 19);
    expect(physical['installedVersionCode'], 20);
    expect(physical['exactGovernedApkMatch'], isTrue);
    expect(physical['signerContinuityVerifiedByInPlaceUpdate'], isTrue);
    expect(physical['firstInstallTimePreserved'], isTrue);
    expect(physical['applicationDataPreserved'], isTrue);
    expect(physical['applicationDataCleared'], isFalse);
    expect(physical['applicationUninstalled'], isFalse);

    expect(startup['coldLaunchResult'], 'passed');
    expect(startup['approvedAuthenticatedSessionPreserved'], isTrue);
    expect(startup['authenticatedHomeRendered'], isTrue);
    expect(startup['startupMigrationBlockObserved'], isFalse);
    expect(migration['preOpenSchemaVersion'], 8);
    expect(migration['targetSchemaVersion'], 9);
    expect(migration['governedOpenCompleted'], isTrue);

    expect(recovery['recordIdentifierRecorded'], isFalse);
    expect(recovery['serverReadbackPerformed'], isTrue);
    expect(recovery['authoritativeServerRecordDeleted'], isTrue);
    expect(recovery['firebaseBusinessRecordMutated'], isFalse);
    expect(recovery['finalSyncResult'], 'success');
    expect(recovery['finalUnsyncedRows'], 0);
    expect(recovery['finalUnresolvedRejections'], 0);
    expect(recovery['finalLikelyPermanentRejections'], 0);
    expect(recovery['finalFullSyncConflicts'], 0);

    expect(backend['backendParityConfirmed'], isFalse);
    expect(backend['clientAppCheckActivated'], isFalse);
    expect(backend['identityCallableAppCheckEnforced'], isTrue);
    expect(mutations.values, everyElement(isFalse));
    expect(adjudication['minimumHandoutCondition4Passed'], isTrue);
    expect(
      adjudication['twoAccountTwoDeviceMutationConvergencePassed'],
      isFalse,
    );
    expect(adjudication['separateControlledPilotPromotionPassed'], isFalse);
    expect(boundary.values, everyElement(isFalse));
  });
}
