import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

void main() {
  test('production restore-pack receipt is exact and privacy-safe', () {
    const receiptPath =
        'release/evidence/production-prelive-restore-pack-seal.json';
    final receiptText = File(receiptPath).readAsStringSync();
    final receipt = _readJson(receiptPath);

    expect(receipt['schemaVersion'], 1);
    expect(
      receipt['decision'],
      'PASS_PRIVATE_PRODUCTION_RESTORE_PACK_SEALED_AND_'
      'INDEPENDENTLY_VERIFIED',
    );

    final source = _object(receipt['sourceAuthority']);
    expect(
      source['collectorCommit'],
      'f604c5e1966fc40f4ddd5d4eb75e483d807435eb',
    );
    expect(source['originParityVerified'], isTrue);
    expect(source['trackedWorktreeClean'], isTrue);
    final ci = _object(source['ci']);
    expect(ci['workflow'], 'release-gate');
    expect(ci['event'], 'push');
    expect(ci['runId'], 30747352624);
    expect(ci['headSha'], source['collectorCommit']);
    expect(ci['expectedJobCount'], 4);
    expect(ci['allExpectedJobsPassed'], isTrue);

    final export = _object(receipt['protectedFirestoreExport']);
    expect(export['projectId'], 'crm3-baf-ops-b8638');
    expect(export['operationState'], 'SUCCESSFUL');
    expect(export['objectCount'], 3);
    expect(export['totalBytes'], 229459);
    expect(export['retentionDays'], 90);
    expect(export['versioningEnabled'], isTrue);
    expect(export['publicAccessPreventionEnforced'], isTrue);

    final pack = _object(receipt['privatePack']);
    expect(
      pack['archiveSha256'],
      '0FFB2A1DCD73AFD5C452E8978E21FF96D555FE063D32DC3B054B50229594CE08',
    );
    expect(
      pack['manifestSha256'],
      'AE0652127028B54E6386848DB8FA21B2F6E1C7AF4439AAF69D45787CDE30B3EF',
    );
    expect(pack['manifestRecordedFileCount'], 44);
    expect(pack['archiveEntryCount'], 45);
    expect(pack['deployedFunctionCount'], 7);
    expect(pack['managedExportObjectCount'], 3);
    expect(pack['privateCustodyCopyCount'], 2);
    expect(pack['secondaryPrivateCustodyHashVerified'], isTrue);
    expect(pack['archiveCommittedToRepository'], isFalse);
    expect(pack['absoluteCustodyPathRecorded'], isFalse);

    final verification = _object(receipt['independentVerification']);
    expect(
      verification['decision'],
      'PASS_INDEPENDENT_RESTORE_PACK_VERIFICATION',
    );
    for (final key in <String>[
      'archiveHashRecalculated',
      'sidecarBindingVerified',
      'manifestHashRecalculated',
      'everyManifestEntryHashAndSizeVerified',
      'diskAndArchiveEntrySetsMatched',
      'archiveOpenedSuccessfully',
      'allFunctionSourceArchivesVerified',
      'allManagedExportObjectsVerified',
      'governedBuild6HashVerified',
    ]) {
      expect(verification[key], isTrue, reason: key);
    }
    expect(verification['mutationFlagsTrue'], 0);

    final failed = _object(receipt['failedClosedAttempt']);
    expect(failed['outcome'], 'FAILED_CLOSED_NO_SEALED_ARCHIVE');
    expect(failed['partialFileCount'], 12);
    expect(failed['manifestCreated'], isFalse);
    expect(failed['archiveCreated'], isFalse);
    expect(failed['sidecarCreated'], isFalse);
    expect(failed['productionMutationPerformed'], isFalse);
    expect(failed['resolutionPullRequest'], 108);

    final mutation = _object(receipt['mutationBoundary']);
    for (final entry in mutation.entries) {
      expect(entry.value, isFalse, reason: entry.key);
    }

    final privacy = _object(receipt['privacyBoundary']);
    for (final key in <String>[
      'receiptContainsProductionDocuments',
      'receiptContainsDeployedFunctionSource',
      'receiptContainsSigningMaterial',
      'receiptContainsAbsolutePrivateCustodyPaths',
      'privateRecoveryArchiveCommitted',
    ]) {
      expect(privacy[key], isFalse, reason: key);
    }
    expect(privacy['privatePackContainsSensitiveRecoveryMaterial'], isTrue);
    for (final forbidden in <String>[
      r'D:\Key',
      r'C:\Users',
      'release_output',
      'BEGIN PRIVATE KEY',
      '.p12',
      '.jks',
    ]) {
      expect(receiptText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('restore-pack seal satisfies only its prerequisite', () {
    final receipt = _readJson(
      'release/evidence/production-prelive-restore-pack-seal.json',
    );
    final ledger = _readJson('governance/programme-ledger.json');
    final programme = _object(receipt['programmeBoundary']);

    expect(programme['restorePackPrerequisiteSatisfied'], isTrue);
    expect(
      programme['productionBackendMutationAuthorizedByThisReceipt'],
      isFalse,
    );
    expect(programme['stage2dF4CurrentStatus'], 'OPEN');
    expect(programme['stage2dF4ClosureAuthorized'], isFalse);
    expect(programme['p07ClosureAuthorized'], isFalse);
    expect(programme['pilotHandoutAuthorized'], isFalse);
    expect(programme['heldPullRequests87Through93ReAdjudicated'], isFalse);

    final decision = _object(ledger['programmeDecision']);
    expect(decision['nextMutation'], 'STAGE2D-F4');
    expect(decision['pilotHandout'], 'NOT_AUTHORIZED');
    final f4 = (ledger['programmeGates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((record) => record['gateId'] == 'STAGE2D-F4');
    expect(f4['currentStatus'], 'OPEN');
  });
}
