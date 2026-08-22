import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

void main() {
  test('Build 11 closure remains exact while Build 14 gates stay separate', () {
    const evidencePath =
        'release/evidence/stage2d-f6-build11-controlled-pilot-authorization.json';
    final evidence = _object(jsonDecode(File(evidencePath).readAsStringSync()));
    final ledger = _object(
      jsonDecode(File('governance/programme-ledger.json').readAsStringSync()),
    );
    final policy = _object(
      jsonDecode(
        File('release/production-release-policy.json').readAsStringSync(),
      ),
    );

    expect(
      _sha256(evidencePath),
      '878897E7DAAF26BF099F3894CAA2EB6719E5F56CED3F7546E8D48E352C4E7400',
    );
    expect(
      evidence['decision'],
      'PASS_LR07_CLOSED_AND_STAGE2D_F6_CONTROLLED_PILOT_AUTHORIZED',
    );
    final source = _object(evidence['sourceAuthority']);
    expect(source['adjudicatedPullRequest'], 201);
    expect(
      source['adjudicatedMergeCommit'],
      '38654b9385cd91cdf4dab743ca007f07d0430f76',
    );
    expect(_object(source['pullRequestCi'])['runId'], 31578415848);
    expect(_object(source['postMergeCi'])['runId'], 31579340418);
    for (final phase in <String>['pullRequestCi', 'postMergeCi']) {
      final ci = _object(source[phase]);
      expect(ci['conclusion'], 'success');
      expect(_objects(ci['jobs']), hasLength(5));
      expect(
        _objects(ci['jobs']).map((job) => job['conclusion']),
        everyElement('success'),
      );
    }

    final promotion = _object(evidence['promotion']);
    expect(promotion['authorizedBuildNumber'], 11);
    expect(
      promotion['authorizedPackageSha256'],
      '104D5ADA33244CCC9090C31A72FBF167F4D69699C93EDD75FA3F6AAB6D99D970',
    );
    expect(promotion['pilotHandoutAuthorized'], isTrue);
    expect(promotion['pilotHandoutPerformedByThisRecord'], isFalse);
    for (final key in <String>[
      'publicArtifactAuthorized',
      'githubReleaseAuthorized',
      'firebaseAppDistributionAuthorized',
      'playConsoleAuthorized',
      'playStoreAuthorized',
      'webDistributionAuthorized',
      'unrestrictedDistributionAuthorized',
      'appCheckActivationAuthorized',
    ]) {
      expect(promotion[key], isFalse, reason: key);
    }

    final transitions = _objects(evidence['gateTransitions']);
    expect(transitions.map((entry) => entry['to']), <String>[
      'CLOSED',
      'PILOT_AUTHORIZED',
      'CLOSED',
    ]);
    final gates = _objects(ledger['programmeGates']);
    expect(gates, everyElement(containsPair('currentStatus', 'CLOSED')));
    final decision = _object(ledger['programmeDecision']);
    expect(decision['internalControlledPilot'], 'GO');
    expect(decision['pilotHandout'], 'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER');
    expect(decision['nextMutation'], 'NONE_ALL_PROGRAMME_GATES_CLOSED');
    expect(decision['unrestrictedDistribution'], 'NO_GO');

    final postBuildPromotion = _object(policy['postBuildPromotion']);
    expect(postBuildPromotion['promotionReceiptFile'], evidencePath);
    expect(postBuildPromotion['promotionReceiptSha256'], _sha256(evidencePath));
    expect(postBuildPromotion['controlledPilotApproved'], isTrue);
    expect(postBuildPromotion['pilotHandoutPerformed'], isFalse);
    expect(postBuildPromotion['unrestrictedPlantReleaseApproved'], isFalse);
    final distribution = _object(policy['distribution']);
    expect(distribution['approved'], isTrue);
    expect(distribution['approvedBuildNumber'], 11);
    expect(distribution['preservedHistoricalAuthority'], isTrue);
    expect(distribution['appliesToCurrentCandidate'], isFalse);
    expect(distribution['pilotHandoutPerformed'], isFalse);
    expect(distribution['unrestrictedPlantReleaseApproved'], isFalse);
    expect(policy['knownOpenGates'], <String>[
      'BUILD14_EXACT_FIRESTORE_RULES_INDEXES_DEPLOYMENT_READBACK',
      'BUILD14_PRODUCTION_SIGNED_FINALIZATION',
      'BUILD14_SIGNED_DEVICE_MIGRATION_AND_BUSINESS_FLOW_VALIDATION',
      'BUILD14_EXPLICIT_PILOT_PROMOTION',
    ]);
  });
}
