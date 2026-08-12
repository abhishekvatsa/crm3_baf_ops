import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(Object? value) => value as Map<String, dynamic>;

List<Map<String, dynamic>> _objects(Object? value) =>
    (value as List<dynamic>).cast<Map<String, dynamic>>();

List<String> _strings(Object? value) => (value as List<dynamic>).cast<String>();

Map<String, dynamic> _readJson(String path) =>
    _object(jsonDecode(File(path).readAsStringSync()));

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

void main() {
  const closurePath =
      'release/evidence/stage2d-f5-live-authority-matrix-closure.json';
  const closureSha =
      'DD8A8BB0E155786BF54DA468E6E15005FC303EB1057E42F01CA763C9A7F9ED7B';

  test(
    'F5 closure preserves failed deployment lineage and exact live state',
    () {
      final closure = _readJson(closurePath);
      expect(_sha256(closurePath), closureSha);
      expect(
        closure['decision'],
        'PASS_STAGE2D_F5_LIVE_AUTHORITY_MATRIX_CLOSURE',
      );

      final source = _object(closure['sourceAuthority']);
      expect(source['commit'], 'e86efddf17a8c5c0284ac1f9596a85d773e5b566');
      final ci = _object(source['postMergeReleaseGate']);
      expect(ci['runId'], 31496973855);
      expect(ci['conclusion'], 'success');
      expect(ci['firestoreRulesTestsPassed'], 160);
      expect(ci['governedCallableTestsPassed'], 63);
      expect(ci['expressionLimitWarningAbsent'], isTrue);

      final deployment = _object(closure['deploymentLineage']);
      expect(deployment['mutationScope'], 'FIRESTORE_RULES_ONLY');
      for (final key in <String>[
        'indexesDeployed',
        'functionsDeployed',
        'iamMutated',
        'firestoreDocumentsWritten',
        'appCheckMutated',
        'clientArtifactChanged',
      ]) {
        expect(deployment[key], isFalse, reason: key);
      }
      final attempts = _objects(deployment['attempts']);
      expect(attempts, hasLength(2));
      expect(attempts.first['result'], 'FAILED_CLOSED');
      expect(attempts.first['liveMutationProvedAbsent'], isTrue);
      expect(
        attempts.last['result'],
        'CLI_NONZERO_LIVE_STATE_SEPARATELY_ADJUDICATED',
      );
      expect(attempts.last['cliResponseRelabelledSuccess'], isFalse);
      expect(attempts.last['liveReadbackIsSoleDeploymentAuthority'], isTrue);

      final after = _object(deployment['after']);
      expect(after['rulesByteExact'], isTrue);
      expect(after['sourceRulesSha256'], after['activeRulesSha256']);
      expect(after['sourceIndexCount'], 51);
      expect(after['liveReadyIndexCount'], 51);
      expect(after['indexesExact'], isTrue);
      expect(_sha256(after['receiptPath'] as String), after['receiptSha256']);
    },
  );

  test('F5 evidence proves every criterion without retaining private UI', () {
    final closure = _readJson(closurePath);
    final live = _object(closure['liveAuthorityEvidence']);
    final allowlist = _object(live['allowlist']);
    expect(
      _sha256(allowlist['receiptPath'] as String),
      allowlist['receiptSha256'],
    );
    expect(allowlist['joinedSubjectCount'], 3);
    expect(allowlist['canonicalApprovedCount'], 3);
    expect(allowlist['blockingSubjectCount'], 0);
    expect(allowlist['rawIdentifiersEmitted'], isFalse);

    final physical = _object(live['priorPhysicalAuthority']);
    expect(
      _sha256(physical['receiptPath'] as String),
      physical['receiptSha256'],
    );
    expect(physical['revocationNextOperationDenied'], isTrue);
    expect(physical['wrongRoleSurfaceDenied'], isTrue);
    expect(physical['finalAuthorityRestoredExactly'], isTrue);

    final client = _object(live['liveClientSurface']);
    expect(client['versionCode'], 8);
    final admin = _object(client['adminEmulator']);
    expect(admin['auditNavigationPresent'], isTrue);
    expect(admin['productionAuditReadSucceeded'], isTrue);
    final si = _object(client['siOnlyPhysicalDevice']);
    expect(si['adminNavigationPresent'], isFalse);
    expect(si['auditNavigationPresent'], isFalse);

    final criteria = _objects(closure['criterionAdjudication']);
    expect(criteria.map((item) => item['criterion']).toList(), <String>[
      'positive and negative role matrix',
      'unapproved and revoked denial',
      'server-owned write denial',
      'audit visibility',
    ]);
    expect(criteria.every((item) => item['status'] == 'PROVED'), isTrue);

    final privacy = _object(closure['privacyBoundary']);
    expect(privacy['privacySafeReceiptsOnly'], isTrue);
    expect(
      privacy.entries
          .where((entry) => entry.key != 'privacySafeReceiptsOnly')
          .every((entry) => entry.value == false),
      isTrue,
    );
  });

  test('F5 closure remains exact after the later F6 promotion', () {
    final ledger = _readJson('governance/programme-ledger.json');
    final decision = _object(ledger['programmeDecision']);
    final gates = _objects(ledger['programmeGates']);
    final f5 = gates.singleWhere((record) => record['gateId'] == 'STAGE2D-F5');
    final f6 = gates.singleWhere((record) => record['gateId'] == 'STAGE2D-F6');

    expect(decision['nextMutation'], 'NONE_ALL_PROGRAMME_GATES_CLOSED');
    expect(decision['pilotHandout'], 'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER');
    expect(f5['currentStatus'], 'CLOSED');
    expect(f5['authorization'], 'CLOSED_PASS');
    expect(_objects(f5['evidence']), hasLength(3));
    expect(
      _objects(f5['evidence']).map((record) => record['sha256']),
      contains(closureSha),
    );
    expect(_strings(f5['requiredExitEvidence']), hasLength(4));
    expect(_strings(f5['reArmTriggers']), hasLength(6));
    expect(
      _objects(f5['statusHistory']).map((record) => record['status']).toList(),
      <String>['OPEN', 'CLOSED'],
    );
    expect(f6['currentStatus'], 'CLOSED');
    expect(f6['authorization'], 'CLOSED_PASS_CONTROLLED_PILOT_AUTHORIZED');

    final result =
        File(
          'docs/v4_2_r1/STAGE2D_F5_LIVE_AUTHORITY_MATRIX_CLOSURE.md',
        ).readAsStringSync();
    expect(result, contains('`STAGE2D-F5` is closed'));
    expect(result, contains('response is retained as non-success'));
    expect(result, contains('Pilot handout remains'));
    expect(result, contains('does not close `STAGE2D-F6` or'));
    expect(result, contains('`70K-RECOVERY`'));
  });
}
