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
  test('P-06 and 70K close only on exact Build 11 device evidence', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    final p06 = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'P-06');
    expect(p06['authorityType'], 'DEPLOYED_RUNTIME');
    expect(p06['transitionProfile'], 'DEPLOYED_CONTROL');
    expect(p06['currentStatus'], 'CLOSED');
    expect(
      _objects(p06['statusHistory']).map((entry) => entry['status'] as String),
      <String>[
        'OPEN',
        'SOURCE_IMPLEMENTED',
        'MERGED',
        'DEPLOYED',
        'DEVICE_PROVED',
        'CLOSED',
      ],
    );

    final p06Notes = _strings(p06['notes']).join('\n');
    expect(p06Notes, contains('rejects unmarked or partial existing stores'));
    expect(p06Notes, contains('admitted-main run 31512254539'));
    expect(
      _objects(p06['evidence']).map((entry) => entry['sha256']),
      contains(
        'D67264FA6A93CFC07BD4A6955435D605B9062BD0F83CD53BE6BF97E12857FEF0',
      ),
    );

    final recovery = _objects(
      ledger['programmeGates'],
    ).singleWhere((item) => item['gateId'] == '70K-RECOVERY');
    expect(recovery['authorityType'], 'DEVICE_EVIDENCE');
    expect(recovery['transitionProfile'], 'DEVICE_EVIDENCE');
    expect(recovery['currentStatus'], 'CLOSED');
    expect(recovery['authorization'], 'CLOSED_PASS');
    expect(
      _objects(
        recovery['statusHistory'],
      ).map((entry) => entry['status'] as String),
      <String>['OPEN', 'DEVICE_PROVED', 'CLOSED'],
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

    final closure =
        jsonDecode(
              File(
                'release/evidence/70k-local-database-recovery-closure.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(closure['decision'], 'PASS_70K_RECOVERY_AND_P06_CLOSURE');
    final targets = _object(closure['installedTargets']);
    expect(targets['targetCount'], 2);
    expect(targets['packageUidPreservedOnEveryTarget'], isTrue);
    expect(targets['firstInstallTimePreservedOnEveryTarget'], isTrue);
    expect(targets['uninstallPerformed'], isFalse);
    expect(targets['appDataClearPerformed'], isFalse);
    final inventory = _object(targets['privacySafeInventory']);
    expect(
      inventory['overallDispositionOnEveryTarget'],
      'EXISTING_STORE_CANONICAL_CURRENT',
    );
    expect(inventory['requiresGovernedRecoveryOnAnyTarget'], isFalse);
    final native = _object(closure['nativeStoreCampaign']);
    expect(native['passed'], 21);
    expect(native['failed'], 0);
    final boundary = _object(closure['closureBoundary']);
    expect(boundary['p06ClosureAuthorized'], isTrue);
    expect(boundary['gate70kClosureAuthorized'], isTrue);
    expect(boundary['stage2dF6ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
  });
}
