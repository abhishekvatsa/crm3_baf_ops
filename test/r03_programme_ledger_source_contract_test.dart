import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

List<Map<String, dynamic>> _objects(dynamic value) {
  return (value as List<dynamic>).map(_object).toList(growable: false);
}

List<String> _strings(dynamic value) {
  return (value as List<dynamic>).cast<String>();
}

void main() {
  test('R-03 is source implemented without claiming CI closure', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    final r03 = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'R-03');

    expect(r03['authorityType'], 'SOURCE_AND_CI');
    expect(r03['transitionProfile'], 'SOURCE_AND_CI');
    expect(r03['currentStatus'], 'SOURCE_IMPLEMENTED');
    expect(r03['evidence'], isEmpty);
    expect(
      _objects(r03['statusHistory']).map((entry) => entry['status'] as String),
      <String>['OPEN', 'SOURCE_IMPLEMENTED'],
    );

    final exitEvidence = _strings(r03['requiredExitEvidence']).join('\n');
    expect(
      exitEvidence,
      contains('distinct succeeded, failed, queued and throttled outcomes'),
    );
    expect(
      exitEvidence,
      contains('exact-head pull-request CI and post-merge CI pass'),
    );

    final notes = _strings(r03['notes']).join('\n');
    expect(
      notes,
      contains(
        'Deferred admission remains non-successful for startup, retry '
        'cancellation and governed publish confirmation',
      ),
    );
    expect(
      notes,
      contains('SOURCE_IMPLEMENTED is not merge or SOURCE_AND_CI closure'),
    );
  });
}
