import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

String _fileSha256(String path) {
  return sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();
}

void main() {
  test('LR-07 historical closure stays exact after the Build 9 re-arm', () {
    const containmentPath =
        'release/evidence/lr07-public-production-artifact-containment.json';
    const readbackPath =
        'release/evidence/lr07-distribution-installation-live-readback.json';
    const closurePath =
        'release/evidence/lr07-distribution-installation-live-readback-closure.json';
    const build11ContainmentPath =
        'release/evidence/lr07-public-production-artifact-containment-builds9-11.json';
    const build11ReadbackPath =
        'release/evidence/lr07-distribution-installation-live-readback-build11.json';

    final containment = _object(
      jsonDecode(File(containmentPath).readAsStringSync()),
    );
    final readback = _object(jsonDecode(File(readbackPath).readAsStringSync()));
    final closure = _object(jsonDecode(File(closurePath).readAsStringSync()));
    final ledger = _object(
      jsonDecode(File('governance/programme-ledger.json').readAsStringSync()),
    );

    expect(
      containment['decision'],
      'PASS_LR07_PUBLIC_PRODUCTION_ARTIFACTS_CONTAINED',
    );
    final containmentSource = _object(containment['source']);
    expect(containmentSource['branch'], 'main');
    expect(
      containmentSource['commit'],
      '02731af8a79f0da4a731ff9f28eb96df10458eef',
    );
    expect(
      containmentSource['tree'],
      '44f657df6ffe54b885f5c994d8a604c7255089c4',
    );
    expect(containmentSource['originMain'], containmentSource['commit']);
    expect(containmentSource['governedWorktreeClean'], isTrue);
    expect(containmentSource['materialChangeCount'], 0);

    final externalReceipts = _object(containment['externalReceipts']);
    final preflight = _object(externalReceipts['preflight']);
    final containmentReceipt = _object(externalReceipts['containment']);
    expect(preflight['fileBytes'], 1919);
    expect(
      preflight['fileSha256'],
      '374DE3E58E368545F4806B069F5D0DBEF109D51786AD0E1466C1464EF8585820',
    );
    expect(
      preflight['decision'],
      'PASS_LR07_PUBLIC_ARTIFACT_CONTAINMENT_PREFLIGHT',
    );
    expect(containmentReceipt['fileBytes'], 1814);
    expect(
      containmentReceipt['fileSha256'],
      '07EA164C0B2D7E281DAAFFD3BCB7B3E1921702D7E3769AEBAD8192AD3E2A55CD',
    );

    final inventoryBefore = _object(containment['inventoryBefore']);
    expect(inventoryBefore['count'], 5);
    expect(inventoryBefore['totalBytes'], 765143034);
    expect(inventoryBefore['artifactIds'], <int>[
      8711253816,
      8730747624,
      8771948980,
      8836687771,
      8866525607,
    ]);
    expect(inventoryBefore['exact'], isTrue);
    expect(inventoryBefore['mismatched'], isEmpty);
    expect(inventoryBefore['unexpected'], isEmpty);

    final containmentResult = _object(containment['result']);
    expect(containmentResult['deletedNow'], inventoryBefore['artifactIds']);
    expect(containmentResult['alreadyAbsent'], isEmpty);
    expect(containmentResult['remainingProductionArtifactCount'], 0);
    expect(containmentResult['ownerApprovalAcknowledged'], isTrue);
    expect(containmentResult['workflowRunsPreserved'], isTrue);
    expect(containmentResult['repositoryVisibilityChanged'], isFalse);
    final containmentBoundary = _object(containment['mutationBoundary']);
    expect(containmentBoundary['githubArtifactsDeleted'], isTrue);
    expect(containmentBoundary['githubArtifactDeleteCount'], 5);
    for (final entry in containmentBoundary.entries.where(
      (entry) =>
          entry.key != 'githubArtifactsDeleted' &&
          entry.key != 'githubArtifactDeleteCount',
    )) {
      expect(entry.value, isFalse, reason: entry.key);
    }
    expect(
      _object(containment['privacyBoundary']).values,
      everyElement(isFalse),
    );

    expect(
      readback['decision'],
      'PASS_LR07_DISTRIBUTION_INSTALLATION_LIVE_READBACK',
    );
    expect(readback['mode'], 'STRICT');
    expect(readback['projectId'], 'crm3-baf-ops-b8638');
    expect(readback['applicationId'], 'in.co.sail.bsl.crm3.bafops');
    final externalReadback = _object(readback['externalReceipt']);
    expect(externalReadback['fileBytes'], 7346);
    expect(
      externalReadback['fileSha256'],
      '1EEE0A26D02E73BB4F26090E18CDFC4709C37FF6BB7ABF4F53C8D43181AA3AB2',
    );
    expect(
      externalReadback['receiptSha256'],
      '5eb021d7367f0ded7f544ec78700e8bd8036f4b9780ad8378d57d5d304fc1db6',
    );

    final source = _object(readback['source']);
    for (final binding in <Map<String, dynamic>>[
      _object(source['before']),
      _object(source['after']),
    ]) {
      expect(binding['branch'], 'main');
      expect(binding['commit'], containmentSource['commit']);
      expect(binding['tree'], containmentSource['tree']);
      expect(binding['originMain'], binding['commit']);
      expect(binding['governedWorktreeClean'], isTrue);
      expect(binding['materialChangeCount'], 0);
    }
    expect(source['validatedSourceEvidenceCount'], 7);
    expect(source['allSourceEvidenceExact'], isTrue);
    expect(_objects(readback['commands']), hasLength(8));

    final outputs = _object(readback['outputs']);
    final installation = _object(outputs['installation']);
    expect(installation['fileBytes'], 8119);
    expect(
      installation['fileSha256'],
      '4BD8332FBCF80B6E809B5A3FFE94EDD7560C482D898B6B9E2F37D6F63422BCEC',
    );
    expect(installation['versionCode'], 8);
    expect(installation['physicalDevice'], isTrue);
    expect(installation['productionSignerVerified'], isTrue);
    expect(installation['approvedSessionVerified'], isTrue);
    expect(installation['exact'], isTrue);

    final live = _object(outputs['live']);
    expect(live['repositoryVisibility'], 'PUBLIC');
    expect(live['productionWorkflowRunCount'], 9);
    expect(live['productionArtifactCount'], 0);
    expect(live['productionArtifactTotalBytes'], 0);
    expect(live['githubReleaseCount'], 0);
    expect(_object(live['build8WorkflowRun'])['conclusion'], 'success');
    expect(_object(readback['posture'])['holds'], isEmpty);
    expect(_object(readback['checks']).values, everyElement(isTrue));
    expect(readback['failedChecks'], isEmpty);
    expect(_object(readback['mutationBoundary']).values, everyElement(isFalse));
    final readbackPrivacy = _object(readback['privacyBoundary']);
    expect(readbackPrivacy['artifactNamesRepresentedBySha256Only'], isTrue);
    for (final entry in readbackPrivacy.entries.where(
      (entry) => entry.key != 'artifactNamesRepresentedBySha256Only',
    )) {
      expect(entry.value, isFalse, reason: entry.key);
    }
    final collectorScope = _object(readback['closureScope']);
    expect(collectorScope['lr07Closed'], isFalse);
    expect(collectorScope['collectorAuthorizesClosure'], isFalse);
    expect(collectorScope['separateAdjudicationRequired'], isTrue);

    expect(
      closure['decision'],
      'PASS_LR07_DISTRIBUTION_INSTALLATION_LIVE_READBACK_CLOSURE',
    );
    final collector = _object(closure['collectorAuthority']);
    expect(collector['pullRequest'], 169);
    expect(collector['sourceTree'], collector['mergeTree']);
    expect(_object(collector['pullRequestCi'])['runId'], 31087258758);
    expect(_object(collector['pullRequestCi'])['conclusion'], 'success');
    expect(_objects(_object(collector['pullRequestCi'])['jobs']), hasLength(5));
    expect(_object(collector['postMergeCi'])['runId'], 31088013593);
    expect(_object(collector['postMergeCi'])['conclusion'], 'success');
    expect(_objects(_object(collector['postMergeCi'])['jobs']), hasLength(5));

    final admitted = _object(closure['admittedEvidence']);
    final admittedContainment = _object(admitted['containment']);
    final admittedReadback = _object(admitted['liveReadback']);
    expect(admittedContainment['path'], containmentPath);
    expect(_fileSha256(containmentPath), admittedContainment['fileSha256']);
    expect(
      File(containmentPath).lengthSync(),
      admittedContainment['fileBytes'],
    );
    expect(admittedReadback['path'], readbackPath);
    expect(_fileSha256(readbackPath), admittedReadback['fileSha256']);
    expect(File(readbackPath).lengthSync(), admittedReadback['fileBytes']);
    expect(_object(closure['provedReadback'])['allChecksPassed'], isTrue);
    expect(_object(closure['closureBoundary']).values, everyElement(isFalse));
    expect(
      _object(closure['recordTransitions'])['lr07'],
      'OPEN_TO_LIVE_READBACK_PROVED_TO_CLOSED',
    );

    final gates = _objects(ledger['programmeGates']);
    final lr07 = gates.singleWhere((record) => record['gateId'] == 'LR-07');
    expect(lr07['currentStatus'], 'LIVE_READBACK_PROVED');
    expect(lr07['authorization'], 'AWAITING_SOURCE_CI_CLOSURE');
    expect(
      _objects(lr07['statusHistory']).map((entry) => entry['status']),
      <String>[
        'OPEN',
        'LIVE_READBACK_PROVED',
        'CLOSED',
        'OPEN',
        'LIVE_READBACK_PROVED',
      ],
    );
    expect(_strings(lr07['requiredExitEvidence']), hasLength(6));
    expect(_strings(lr07['reArmTriggers']), hasLength(7));
    final ledgerEvidence = _objects(lr07['evidence']);
    expect(ledgerEvidence, hasLength(5));
    expect(ledgerEvidence.map((entry) => entry['sha256']).toSet(), <String>{
      _fileSha256(containmentPath),
      _fileSha256(readbackPath),
      _fileSha256(closurePath),
      _fileSha256(build11ContainmentPath),
      _fileSha256(build11ReadbackPath),
    });
    expect(_strings(closure['reArmConditions']).last, contains('Build 8'));
    expect(
      _strings(lr07['reArmTriggers']).last,
      contains('latest admitted build authority'),
    );
    final programmeDecision = _object(ledger['programmeDecision']);
    expect(programmeDecision['nextMutation'], 'STAGE2D-F6');
    expect(programmeDecision['pilotHandout'], 'NOT_AUTHORIZED');
    expect(programmeDecision['unrestrictedDistribution'], 'NO_GO');
  });

  test('Builds 9-11 containment and strict readback are exact and non-closing', () {
    const containmentPath =
        'release/evidence/lr07-public-production-artifact-containment-builds9-11.json';
    const readbackPath =
        'release/evidence/lr07-distribution-installation-live-readback-build11.json';
    final containment = _object(
      jsonDecode(File(containmentPath).readAsStringSync()),
    );
    final readback = _object(jsonDecode(File(readbackPath).readAsStringSync()));

    expect(
      containment['decision'],
      'PASS_LR07_BUILDS_9_10_11_PUBLIC_PRODUCTION_ARTIFACTS_CONTAINED',
    );
    final source = _object(containment['source']);
    expect(source['branch'], 'main');
    expect(source['commit'], '1fdc68e4fdb6caf301cde0946505d071e5bed0ed');
    expect(source['originMain'], source['commit']);
    expect(source['governedWorktreeClean'], isTrue);
    expect(source['materialChangeCount'], 0);

    final receipts = _object(containment['externalReceipts']);
    expect(_object(receipts['preflight'])['fileBytes'], 1898);
    expect(
      _object(receipts['preflight'])['receiptSha256'],
      'f51be14f8d7ac8ff2046c82b2b9ac90951e08992132e0006b3adc52199208a43',
    );
    expect(_object(receipts['containment'])['fileBytes'], 1836);
    expect(
      _object(receipts['containment'])['receiptSha256'],
      'bb94e2240df836699fd6a95baa508c6f6513d8584ab6cff2483a812f651aef36',
    );

    final inventory = _object(containment['inventoryBefore']);
    expect(inventory['count'], 3);
    expect(inventory['totalBytes'], 431389958);
    expect(inventory['artifactIds'], <int>[9116320474, 9122790773, 9125100777]);
    expect(
      _object(containment['result'])['deletedNow'],
      inventory['artifactIds'],
    );
    expect(
      _object(containment['result'])['remainingProductionArtifactCount'],
      0,
    );
    expect(_object(containment['result'])['workflowRunsPreserved'], isTrue);
    expect(
      _object(containment['mutationBoundary'])['githubArtifactDeleteCount'],
      3,
    );
    expect(
      _object(containment['privacyBoundary']).values,
      everyElement(isFalse),
    );

    expect(
      readback['decision'],
      'PASS_LR07_BUILD11_DISTRIBUTION_INSTALLATION_LIVE_READBACK',
    );
    expect(readback['mode'], 'STRICT');
    final readbackSource = _object(readback['source']);
    expect(readbackSource['before'], readbackSource['after']);
    expect(readbackSource['validatedSourceEvidenceCount'], 10);
    expect(readbackSource['semanticMutableAuthorityValidated'], isTrue);
    expect(
      readbackSource['build10HistoricalFailureAuthorityPreserved'],
      isTrue,
    );
    final live = _object(_object(readback['outputs'])['live']);
    expect(live['productionWorkflowRunCount'], 14);
    expect(live['productionArtifactCount'], 0);
    expect(live['productionArtifactTotalBytes'], 0);
    expect(live['githubReleaseCount'], 0);
    expect(_object(live['build11WorkflowRun'])['id'], 31552161470);
    expect(_object(readback['checks']).values, everyElement(isTrue));
    expect(readback['failedChecks'], isEmpty);
    final scope = _object(readback['closureScope']);
    expect(scope['lr07LiveReadbackProved'], isTrue);
    expect(scope['lr07Closed'], isFalse);
    expect(scope['stage2dF6Closed'], isFalse);
    expect(scope['pilotHandoutAuthorized'], isFalse);
  });
}
