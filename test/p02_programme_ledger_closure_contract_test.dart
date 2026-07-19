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
  test('P-02 remains at live readback pending authenticated behaviour', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    final programmeDecision = _object(ledger['programmeDecision']);
    expect(programmeDecision['nextMutation'], 'STAGE2D-F2');
    expect(programmeDecision['pilotHandout'], 'NOT_AUTHORIZED');

    final p02 = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'P-02');

    expect(p02['authorityType'], 'DEPLOYED_RUNTIME');
    expect(p02['transitionProfile'], 'DEPLOYED_CONTROL');
    expect(p02['currentStatus'], 'LIVE_READBACK_PROVED');

    final statuses = _objects(
      p02['statusHistory'],
    ).map((entry) => entry['status'] as String).toList(growable: false);

    expect(statuses, <String>[
      'OPEN',
      'SOURCE_IMPLEMENTED',
      'MERGED',
      'DEPLOYED',
      'LIVE_READBACK_PROVED',
    ]);
    expect(statuses, isNot(contains('CLOSED')));

    final evidenceShas =
        _objects(
          p02['evidence'],
        ).map((entry) => entry['sha256'] as String).toSet();

    expect(
      evidenceShas,
      contains(
        'BA95EE61032BC19FF2D44288CA6C033FCDE5DBA31BAFB689FC7DB45FF97A6372',
      ),
    );
    expect(
      evidenceShas,
      contains(
        '7DBF7B6052CED29F1BC140050DF6FD58FA8FBC78C51E5A09B1CAD5DC082FCB02',
      ),
    );
    expect(
      evidenceShas,
      contains(
        'F05C0C520C2671DE68249ED4AE55099C7C8C7512309A180ED2FC47D98260D36A',
      ),
    );

    final exitEvidence = _strings(p02['requiredExitEvidence']);
    expect(
      exitEvidence,
      containsAll(<String>[
        'verified matching token email -> ALLOW',
        'verified mismatched email -> DENY',
        'missing token email claim -> DENY',
        'email_verified != true -> DENY',
        'valid self-update -> ALLOW',
        'email substitution during update -> DENY',
      ]),
    );

    final notes = _strings(p02['notes']).join('\n');
    expect(
      notes,
      contains('P-02 source, deployment and live parity are proved.'),
    );
    expect(
      notes,
      contains(
        'P-02 closure remains pending authenticated live behaviour proof.',
      ),
    );

    final f2 = _objects(
      ledger['programmeGates'],
    ).singleWhere((item) => item['gateId'] == 'STAGE2D-F2');

    expect(f2['currentStatus'], 'OPEN');
    expect(f2['authorization'], 'BLOCKS_PILOT_HANDOUT');

    final f2Notes = _strings(f2['notes']).join('\n');
    expect(
      f2Notes,
      contains('P-02 source, deployment and live parity are proved.'),
    );
    expect(
      f2Notes,
      contains(
        'P-02 closure remains pending authenticated live behaviour proof.',
      ),
    );
    expect(f2Notes, contains('STAGE2D-F2 remains OPEN.'));
  });
}
