import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

void main() {
  test('R-01/R-02 are closed by exact source and CI evidence', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;
    final findings = _objects(ledger['technicalFindings']);

    for (final findingId in <String>['R-01', 'R-02']) {
      final finding = findings.singleWhere(
        (item) => item['findingId'] == findingId,
      );
      expect(finding['authorityType'], 'SOURCE_AND_CI');
      expect(finding['transitionProfile'], 'SOURCE_AND_CI');
      expect(finding['currentStatus'], 'CLOSED');
      expect(
        _objects(
          finding['statusHistory'],
        ).map((entry) => entry['status'] as String),
        <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
      );
      final evidence = _objects(finding['evidence']);
      expect(evidence, hasLength(1));
      expect(evidence.single['pullRequest'], 55);
      expect(
        evidence.single['headCommit'],
        'f356835d08711e804de5f591f12794079f064024',
      );
      expect(
        evidence.single['sourceTree'],
        'f1f5feea68f712ef4ee5e281a4f26790d2d4d2a3',
      );
      expect(
        evidence.single['mergeCommit'],
        '1bf9f1e3f181e73d9cbf7ee49a14704269ef081b',
      );
      expect(evidence.single['postMergeWorkflowRun'], 30282720232);
      expect(
        evidence.single['decision'],
        'PASS_R01_R02_SERVER_CLOCK_AND_SCOPED_CURSOR_SOURCE_CLOSURE',
      );
      expect(evidence.single['runtimeContractActivated'], isFalse);
      expect(evidence.single['productionMutationPerformed'], isFalse);
      expect(_strings(finding['requiredExitEvidence']), hasLength(3));
      expect(
        _strings(finding['reArmTriggers']).length,
        greaterThanOrEqualTo(6),
      );
      expect(
        _strings(finding['notes']).join('\n'),
        contains(
          'Source-and-CI closure corrects the diagnosed source defect but '
          'does not authorize deployment, backfill, runtime activation, '
          'device proof, pilot or cutover.',
        ),
      );
    }

    final r01 = findings.singleWhere((item) => item['findingId'] == 'R-01');
    expect(
      _strings(r01['notes']).join('\n'),
      contains('client-time maximum-minus-overlap token'),
    );
    expect(
      _strings(r01['reArmTriggers']).join('\n'),
      contains('sealed zero-gap backfill receipt'),
    );

    final r02 = findings.singleWhere((item) => item['findingId'] == 'R-02');
    expect(
      _strings(r02['notes']).join('\n'),
      contains('P-06 database generation'),
    );
    expect(_strings(r02['reArmTriggers']).join('\n'), contains('wrong-typed'));

    final remediation =
        File(
          'docs/v4_2_r1/R01_R02_SERVER_CLOCK_AND_SCOPED_CURSOR_REMEDIATION.md',
        ).readAsStringSync();
    expect(remediation, contains('Status: CLOSED'));
    expect(remediation, contains('Source merge and CI evidence: COMPLETE'));
    expect(
      remediation,
      contains(
        'Deployment, backfill, activation, and device evidence: PENDING',
      ),
    );
    expect(remediation, contains('PR #55'));
    expect(remediation, contains('30282720232'));
    expect(
      remediation,
      contains('PASS_R01_R02_SERVER_CLOCK_AND_SCOPED_CURSOR_SOURCE_CLOSURE'),
    );
    expect(remediation, contains('pilot/cutover authorization: prohibited'));
  });
}
