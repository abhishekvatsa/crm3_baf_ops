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
  test('P-06 is source implemented while 70K remains device blocked', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    final p06 = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'P-06');
    expect(p06['authorityType'], 'DEPLOYED_RUNTIME');
    expect(p06['transitionProfile'], 'DEPLOYED_CONTROL');
    expect(p06['currentStatus'], 'SOURCE_IMPLEMENTED');
    expect(
      _objects(p06['statusHistory']).map((entry) => entry['status'] as String),
      <String>['OPEN', 'SOURCE_IMPLEMENTED'],
    );

    final p06Notes = _strings(p06['notes']).join('\n');
    expect(p06Notes, contains('rejects unmarked or partial existing stores'));
    expect(
      p06Notes,
      contains(
        'SOURCE_IMPLEMENTED is not a merge, deployment, device-proof, pilot, '
        'or cutover claim.',
      ),
    );

    final recovery = _objects(
      ledger['programmeGates'],
    ).singleWhere((item) => item['gateId'] == '70K-RECOVERY');
    expect(recovery['authorityType'], 'DEVICE_EVIDENCE');
    expect(recovery['transitionProfile'], 'DEVICE_EVIDENCE');
    expect(recovery['currentStatus'], 'OPEN');
    expect(
      _objects(
        recovery['statusHistory'],
      ).map((entry) => entry['status'] as String),
      <String>['OPEN'],
    );

    final recoveryEvidence = _strings(recovery['requiredExitEvidence']);
    expect(
      recoveryEvidence,
      containsAll(<String>[
        'installed-device inventory that classifies absent, partial, complete '
            'legacy and canonical markers without mutation',
        'forced interruption and restart proof across PREPARED, Isar open, '
            'post-open repair and COMMITTED boundaries',
      ]),
    );
  });
}
