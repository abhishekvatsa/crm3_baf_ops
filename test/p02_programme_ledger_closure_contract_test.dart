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
  test('P-02 closes while STAGE2D-F2 and pilot handout remain blocked', () {
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
    expect(p02['currentStatus'], 'CLOSED');

    final statuses = _objects(
      p02['statusHistory'],
    ).map((entry) => entry['status'] as String).toList(growable: false);

    expect(statuses, <String>[
      'OPEN',
      'SOURCE_IMPLEMENTED',
      'MERGED',
      'DEPLOYED',
      'LIVE_READBACK_PROVED',
      'CLOSED',
    ]);

    final evidence = _objects(p02['evidence']);
    final matrixEvidence = evidence.singleWhere(
      (entry) =>
          entry['sha256'] ==
          'BFC83D4B84EB999AA830443EB8202E70372F8AC5E1EACF21EC85CE8CFC225FF3',
    );

    expect(
      matrixEvidence['decision'],
      'PASS_STAGE2D_F2B_P02_AUTHENTICATED_PRODUCTION_BEHAVIOUR_MATRIX_'
      'PROVED_CLAIM_MAP_ALIGNED_TOKEN_SUBJECT_VERIFIED_IAM_AND_FIREBASE_'
      'RESIDUE_FREE',
    );
    expect(
      matrixEvidence['authority'],
      'AUTHENTICATED_PRODUCTION_BEHAVIOUR_AND_RESIDUE_FREE_CLEANUP',
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
      contains(
        'P-02 is CLOSED by authenticated production behaviour evidence.',
      ),
    );
    expect(
      notes,
      contains(
        'The temporary IAM authority and all synthetic Firebase state were '
        'removed with zero residue.',
      ),
    );

    final f2 = _objects(
      ledger['programmeGates'],
    ).singleWhere((item) => item['gateId'] == 'STAGE2D-F2');

    expect(f2['currentStatus'], 'OPEN');
    expect(f2['authorization'], 'BLOCKS_PILOT_HANDOUT');

    final f2Statuses = _objects(
      f2['statusHistory'],
    ).map((entry) => entry['status'] as String).toList(growable: false);
    expect(f2Statuses, <String>['OPEN']);

    final f2EvidenceShas =
        _objects(
          f2['evidence'],
        ).map((entry) => entry['sha256'] as String).toSet();
    expect(
      f2EvidenceShas,
      contains(
        'BFC83D4B84EB999AA830443EB8202E70372F8AC5E1EACF21EC85CE8CFC225FF3',
      ),
    );

    final f2Notes = _strings(f2['notes']).join('\n');
    expect(f2Notes, contains('P-02 is CLOSED.'));
    expect(
      f2Notes,
      contains('STAGE2D-F2 remains OPEN and continues to block pilot handout.'),
    );
  });
}
