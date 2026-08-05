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
  test('C-02 closes on exact audit-package source and CI evidence', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;
    final finding = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'C-02');

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
    expect(ledgerEvidence['pullRequest'], 154);
    expect(
      ledgerEvidence['headCommit'],
      '06dac6a5b2048592652005f83324b5dc0009dc77',
    );
    expect(
      ledgerEvidence['sourceTree'],
      '18f1c9881c971132a16a5f092dbc7fc3cd7d40b2',
    );
    expect(
      ledgerEvidence['mergeCommit'],
      'a3d3a95c44ab788a44952b8de9260fa39b96f462',
    );
    expect(ledgerEvidence['mergeTree'], ledgerEvidence['sourceTree']);
    expect(ledgerEvidence['pullRequestWorkflowRun'], 30971588062);
    expect(ledgerEvidence['postMergeWorkflowRun'], 30972062651);
    expect(ledgerEvidence['productionMutationPerformed'], isFalse);
    expect(ledgerEvidence['deviceEvidenceClaimed'], isFalse);
    expect(
      ledgerEvidence['decision'],
      'PASS_C02_AUDIT_PACKAGE_COVERAGE_SOURCE_AND_CI_CLOSURE',
    );

    final evidencePath = ledgerEvidence['evidenceFile'] as String;
    expect(_sha256(evidencePath), ledgerEvidence['evidenceSha256']);
    final evidence =
        jsonDecode(File(evidencePath).readAsStringSync())
            as Map<String, dynamic>;
    expect(evidence['findingId'], 'C-02');
    expect(
      evidence['decision'],
      'PASS_C02_AUDIT_PACKAGE_COVERAGE_SOURCE_AND_CI_CLOSURE',
    );

    expect(_strings(evidence['auditCriticalPaths']), <String>[
      'release_gate.ps1',
      'jest.config.js',
      'governance/programme-ledger.json',
      'tooling/firebase-cli/package.json',
      'tooling/firebase-cli/package-lock.json',
    ]);

    final sourceControls = _object(evidence['sourceControls']);
    for (final control in sourceControls.values) {
      final item = _object(control);
      expect(_sha256(item['path'] as String), item['sha256']);
    }

    final pullRequestCi = _object(evidence['pullRequestCi']);
    expect(pullRequestCi['runId'], 30971588062);
    expect(pullRequestCi['event'], 'pull_request');
    expect(
      pullRequestCi['headSha'],
      '06dac6a5b2048592652005f83324b5dc0009dc77',
    );
    expect(pullRequestCi['conclusion'], 'success');

    final postMergeCi = _object(evidence['postMergeCi']);
    expect(postMergeCi['runId'], 30972062651);
    expect(postMergeCi['event'], 'push');
    expect(postMergeCi['headSha'], 'a3d3a95c44ab788a44952b8de9260fa39b96f462');
    expect(postMergeCi['conclusion'], 'success');

    const expectedJobs = <String>{
      'Android release APK + AAB packaging proof',
      'Cloud Functions build + test',
      'Firestore rules + governed transaction emulator',
      'Flutter analyze + tests + no-loss spine',
    };
    for (final section in <Map<String, dynamic>>[pullRequestCi, postMergeCi]) {
      final jobs = _objects(section['jobs']);
      expect(jobs, hasLength(4));
      expect(jobs.map((job) => job['name']).toSet(), expectedJobs);
      expect(jobs.map((job) => job['conclusion']).toSet(), <String>{'success'});
    }

    final boundary = _object(evidence['operationalBoundary']);
    expect(boundary, isNotEmpty);
    for (final value in boundary.values) {
      expect(value, isFalse);
    }

    expect(_strings(finding['requiredExitEvidence']), hasLength(4));
    expect(_strings(finding['reArmTriggers']).length, greaterThanOrEqualTo(5));
    expect(
      _strings(finding['notes']).join('\n'),
      contains('does not construct or distribute a production artifact'),
    );

    final decision =
        File('docs/v4_2_r1/C02_AUDIT_PACKAGE_COVERAGE.md').readAsStringSync();
    expect(decision, contains('Status: CLOSED'));
    expect(decision, contains('PR #154'));
    expect(decision, contains('30971588062'));
    expect(decision, contains('30972062651'));
    expect(
      decision,
      contains('PASS_C02_AUDIT_PACKAGE_COVERAGE_SOURCE_AND_CI_CLOSURE'),
    );
  });
}
