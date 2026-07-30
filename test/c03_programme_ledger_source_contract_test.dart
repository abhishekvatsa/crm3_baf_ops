import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

void main() {
  test('C-03 is closed by exact PR and post-merge Android package CI', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;
    final finding = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'C-03');

    expect(finding['authorityType'], 'SOURCE_AND_CI');
    expect(finding['transitionProfile'], 'SOURCE_AND_CI');
    expect(finding['currentStatus'], 'CLOSED');
    expect(
      _objects(
        finding['statusHistory'],
      ).map((entry) => entry['status'] as String),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );

    final ledgerEvidence = _objects(finding['evidence']).single;
    expect(ledgerEvidence['pullRequest'], 79);
    expect(
      ledgerEvidence['headCommit'],
      '1021ccd0a628112f8e1e50ace1664b721e3ccb88',
    );
    expect(
      ledgerEvidence['sourceTree'],
      'f0737f16c42d4005d55108dcac3591e64a510b30',
    );
    expect(
      ledgerEvidence['mergeCommit'],
      '34ff071ee39d55c16cc7578c8898f00a371164c8',
    );
    expect(ledgerEvidence['pullRequestWorkflowRun'], 30511076330);
    expect(ledgerEvidence['pullRequestAndroidJob'], 90771130887);
    expect(ledgerEvidence['postMergeWorkflowRun'], 30524580357);
    expect(ledgerEvidence['postMergeAndroidJob'], 90812461841);
    expect(
      ledgerEvidence['decision'],
      'PASS_C03_ANDROID_PR_PACKAGING_SOURCE_AND_CI_CLOSURE',
    );

    final evidencePath = ledgerEvidence['evidenceFile'] as String;
    expect(_sha256(evidencePath), ledgerEvidence['evidenceSha256']);
    final evidence =
        jsonDecode(File(evidencePath).readAsStringSync())
            as Map<String, dynamic>;
    expect(evidence['findingId'], 'C-03');
    expect(
      evidence['decision'],
      'PASS_C03_ANDROID_PR_PACKAGING_SOURCE_AND_CI_CLOSURE',
    );

    final pullRequestCi = _object(evidence['pullRequestCi']);
    expect(pullRequestCi['runId'], 30511076330);
    expect(pullRequestCi['event'], 'pull_request');
    expect(pullRequestCi['conclusion'], 'success');
    expect(
      _objects(pullRequestCi['jobs']).map((job) => job['conclusion']).toSet(),
      <String>{'success'},
    );

    final postMergeCi = _object(evidence['postMergeCi']);
    expect(postMergeCi['runId'], 30524580357);
    expect(postMergeCi['event'], 'push');
    expect(postMergeCi['conclusion'], 'success');
    expect(
      _objects(postMergeCi['jobs']).map((job) => job['conclusion']).toSet(),
      <String>{'success'},
    );

    for (final section in <Map<String, dynamic>>[
      _object(pullRequestCi['androidProofMarkers']),
      _object(postMergeCi['androidProofMarkers']),
    ]) {
      expect(section['decision'], 'PASS_C03_ANDROID_RELEASE_PACKAGING_PROOF');
      expect(section['productionCertificateUsed'], isFalse);
      expect(section['productionSecretsReferenced'], isFalse);
      expect(section['artifactUploadPerformed'], isFalse);
    }

    final boundary = _object(evidence['nonProductionBoundary']);
    for (final value in boundary.values) {
      expect(value, isFalse);
    }

    expect(_strings(finding['requiredExitEvidence']), hasLength(4));
    expect(_strings(finding['reArmTriggers']).length, greaterThanOrEqualTo(6));
    expect(
      _strings(finding['notes']).join('\n'),
      contains('does not authorize a production artifact'),
    );

    final decision =
        File('docs/v4_2_r1/C03_ANDROID_PR_PACKAGING.md').readAsStringSync();
    expect(decision, contains('Status: CLOSED'));
    expect(decision, contains('PR #79'));
    expect(decision, contains('30511076330'));
    expect(decision, contains('30524580357'));
    expect(
      decision,
      contains('PASS_C03_ANDROID_PR_PACKAGING_SOURCE_AND_CI_CLOSURE'),
    );
    expect(decision, contains('pilot handout:'));
    expect(decision, contains('prohibited'));
  });
}
