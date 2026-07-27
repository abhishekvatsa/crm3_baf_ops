import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

void main() {
  test('R-01/R-02 are source implemented without runtime overclaim', () {
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
      expect(finding['currentStatus'], 'SOURCE_IMPLEMENTED');
      expect(
        _objects(
          finding['statusHistory'],
        ).map((entry) => entry['status'] as String),
        <String>['OPEN', 'SOURCE_IMPLEMENTED'],
      );
      expect(_strings(finding['requiredExitEvidence']), hasLength(3));
      expect(
        _strings(finding['reArmTriggers']).length,
        greaterThanOrEqualTo(6),
      );
      expect(
        _strings(finding['notes']).join('\n'),
        contains(
          'SOURCE_IMPLEMENTED is not a merge, deployment, backfill, '
          'runtime-activation, device-proof, pilot, or cutover claim.',
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
    expect(remediation, contains('Status: SOURCE_IMPLEMENTED'));
    expect(
      remediation,
      contains(
        'Merge, deployment, backfill, activation, and device evidence: PENDING',
      ),
    );
    expect(remediation, contains('pilot/cutover authorization: prohibited'));
  });
}
