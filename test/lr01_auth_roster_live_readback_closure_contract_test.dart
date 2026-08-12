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
  test('LR-01 closes only on complete privacy-safe clean-main evidence', () {
    const receiptPath = 'release/evidence/lr01-auth-roster-live-readback.json';
    const closurePath =
        'release/evidence/lr01-auth-roster-live-readback-closure.json';
    final receiptRaw = File(receiptPath).readAsStringSync();
    final receipt = jsonDecode(receiptRaw) as Map<String, dynamic>;
    final closure =
        jsonDecode(File(closurePath).readAsStringSync())
            as Map<String, dynamic>;
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(receipt['decision'], 'PASS_GATE_1B_READ_ONLY_AUTHORITY_INTEGRITY');
    expect(receipt['readOnly'], isTrue);
    expect(receipt['cloudMutationCapability'], 'NONE');
    final project = _object(receipt['project']);
    expect(project['projectId'], 'crm3-baf-ops-b8638');
    expect(project['production'], isTrue);
    expect(project['firestoreEmulator'], isNull);
    expect(project['authEmulator'], isNull);

    final source = _object(receipt['sourceAuthority']);
    expect(source['commit'], '5af6d8d3a6f8d7b1c5176b82f1dff68234920371');
    expect(source['tree'], 'dcf3a6a4349b29188d715e268f1b6c8394b2367a');
    expect(source['branch'], 'main');
    expect(source['originMainCommit'], source['commit']);
    expect(source['cleanWorktree'], isTrue);
    expect(source['materialChangeCount'], 0);
    expect(source['materialPathSha256'], isEmpty);

    final coverage = _object(receipt['coverage']);
    expect(coverage['firestoreUsers'], 'COMPLETE');
    expect(coverage['firebaseAuthUsers'], 'COMPLETE');
    expect(coverage['customClaims'], 'COMPLETE');
    expect(coverage['firestoreUserCount'], 3);
    expect(coverage['firebaseAuthUserCount'], 3);
    expect(coverage['joinedSubjectCount'], 3);
    final summary = _object(receipt['summary']);
    expect(summary['blockingFindingCount'], 0);
    expect(summary['blockingSubjectCount'], 0);
    expect(summary['canonicalApprovedAdminCount'], 2);
    expect(summary['enabledApprovedAdminCount'], 2);

    final privacy = _object(receipt['privacy']);
    expect(privacy['subjectIdentifier'], 'HMAC_SHA256');
    expect(privacy['rawIdentifiersEmitted'], isFalse);
    expect(privacy['customClaimValuesEmitted'], isFalse);
    expect(receiptRaw.contains('@'), isFalse);
    for (final subject in _objects(receipt['subjects'])) {
      expect(subject.keys, contains('subjectPseudonym'));
      expect(subject.keys, isNot(contains('uid')));
      expect(subject.keys, isNot(contains('email')));
      expect(subject.keys, isNot(contains('name')));
      expect(
        subject['subjectPseudonym'],
        matches(RegExp(r'^hmac256:[0-9a-f]{64}$')),
      );
    }

    final liveReceipt = _object(closure['liveReceipt']);
    expect(liveReceipt['path'], receiptPath);
    expect(_fileSha256(receiptPath), liveReceipt['fileSha256']);
    expect(File(receiptPath).lengthSync(), liveReceipt['fileBytes']);
    expect(closure['decision'], 'PASS_LR01_AUTH_ROSTER_LIVE_READBACK_CLOSURE');
    final collector = _object(closure['collectorAuthority']);
    expect(collector['pullRequest'], 132);
    expect(collector['sourceTree'], collector['mergeTree']);
    expect(_object(collector['pullRequestCi'])['runId'], 30873830850);
    expect(_object(collector['pullRequestCi'])['conclusion'], 'success');
    expect(_object(collector['postMergeCi'])['runId'], 30874252831);
    expect(_object(collector['postMergeCi'])['conclusion'], 'success');
    expect(_object(closure['closureBoundary']).values, everyElement(isFalse));

    final gates = _objects(ledger['programmeGates']);
    final lr01 = gates.singleWhere((record) => record['gateId'] == 'LR-01');
    expect(lr01['authorityType'], 'LIVE_READBACK');
    expect(lr01['currentStatus'], 'CLOSED');
    expect(lr01['authorization'], 'CLOSED_PASS');
    expect(
      _objects(lr01['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
    );
    expect(_objects(lr01['evidence']).map((entry) => entry['sha256']).toSet(), {
      '6D7FFAA78A77E2B5A413AB5CCFBF9C4DEF90C00FCFB4133355B0A6E97C6334AC',
      '9B30CDD3403A596510F3FE2AF4370E5AB05F8584D28EDCC7A8A89C555A52B05A',
    });
    expect(_strings(lr01['reArmTriggers']), hasLength(5));
    expect(
      _object(ledger['programmeDecision'])['nextMutation'],
      'NONE_ALL_PROGRAMME_GATES_CLOSED',
    );
    expect(
      _object(ledger['programmeDecision'])['pilotHandout'],
      'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER',
    );
  });
}
