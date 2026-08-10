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
  test('STAGE2D-F2 closure survives successor-gate advancement', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    final programmeDecision = _object(ledger['programmeDecision']);
    expect(programmeDecision['nextMutation'], 'STAGE2D-F5');
    expect(programmeDecision['pilotHandout'], 'NOT_AUTHORIZED');

    final p02 = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'P-02');
    expect(p02['currentStatus'], 'CLOSED');

    final f2 = _objects(
      ledger['programmeGates'],
    ).singleWhere((item) => item['gateId'] == 'STAGE2D-F2');

    expect(f2['authorityType'], 'DEPLOYED_RUNTIME');
    expect(f2['transitionProfile'], 'DEPLOYED_CONTROL');
    expect(f2['currentStatus'], 'CLOSED');
    expect(f2['authorization'], 'CLOSED_PASS');

    final statuses = _objects(
      f2['statusHistory'],
    ).map((entry) => entry['status'] as String).toList(growable: false);
    expect(statuses, <String>['OPEN', 'CLOSED']);

    final evidenceShas =
        _objects(
          f2['evidence'],
        ).map((entry) => entry['sha256'] as String).toSet();

    expect(
      evidenceShas,
      containsAll(<String>[
        'B2F6F0146ABE496C9F30BC8B6E7FEE30BD28BE0C60B978C29D611586ED104310',
        'DDD9B2DA8580F618CEBB0CB221BC541288165DB475764472F4263C330F18394A',
        'B805CDABF7AA585CCEED38E02B32189A96588FAE3C03FA6A4FB0DE92B9969CF0',
        '5BC608F190E0675C9238F63ED8457388B378ABD412D50C5613678C3062DBCFA2',
      ]),
    );

    final notes = _strings(f2['notes']).join('\n');
    expect(notes, contains('All STAGE2D-F2 required exit evidence is proved.'));
    expect(
      notes,
      contains('STAGE2D-F2 is CLOSED with authorization CLOSED_PASS.'),
    );
    expect(
      notes,
      contains(
        'Pilot handout remains NOT_AUTHORIZED; STAGE2D-F3 is the next '
        'governed mutation.',
      ),
    );

    final f3 = _objects(
      ledger['programmeGates'],
    ).singleWhere((item) => item['gateId'] == 'STAGE2D-F3');

    expect(f3['currentStatus'], 'CLOSED');
    expect(f3['authorization'], 'CLOSED_PASS');
    expect(
      _objects(
        f3['statusHistory'],
      ).map((entry) => entry['status']).toList(growable: false),
      <String>['OPEN', 'CLOSED'],
    );
  });
}
