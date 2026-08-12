import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

List<Map<String, dynamic>> _objects(dynamic value) {
  return (value as List<dynamic>).map(_object).toList(growable: false);
}

void main() {
  test('F6 operational pack is complete but LR-07 still blocks handout', () {
    final readiness =
        jsonDecode(
              File(
                'release/evidence/stage2d-f6-build11-pilot-readiness.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(readiness['decision'], 'READY_AWAITING_LR07_CONTAINMENT');
    final authority = _object(readiness['releaseAuthority']);
    expect(authority['buildNumber'], 11);
    expect(
      authority['sourceCommit'],
      'ca65d3deead23cccdf07ca24255bc073221d84db',
    );
    expect(
      authority['localRecoveryReceiptSha256'],
      'D67264FA6A93CFC07BD4A6955435D605B9062BD0F83CD53BE6BF97E12857FEF0',
    );

    expect(_object(readiness['support'])['primaryOwner'], 'Abhishek Vatsa');
    expect(_object(readiness['support'])['backupCustodian'], 'Priya');
    expect(readiness['stopConditions'], hasLength(7));
    expect(_object(readiness['deviceInventory'])['admittedTargetCount'], 2);
    expect(
      _object(
        readiness['backupAndRestore'],
      )['productionPointInTimeRecoveryEnabled'],
      isTrue,
    );
    expect(
      _object(
        readiness['backupAndRestore'],
      )['isolatedFirestoreRestoreDocuments'],
      81,
    );
    expect(
      _object(readiness['privacy'])['rawDeviceIdentifiersCommitted'],
      isFalse,
    );
    expect(
      _object(
        readiness['incidentAndRollback'],
      )['automaticDowngradeOrDataClearAllowed'],
      isFalse,
    );
    expect(readiness['pilotAcceptanceScript'], hasLength(11));

    final boundary = _object(readiness['authorizationBoundary']);
    expect(boundary['allSevenF6EvidenceCategoriesAuthored'], isTrue);
    expect(boundary['lr07CurrentStatusObserved'], 'OPEN');
    expect(boundary['f6ClosureAuthorized'], isFalse);
    expect(boundary['pilotHandoutAuthorized'], isFalse);

    final gates = _objects(ledger['programmeGates']);
    final f6 = gates.singleWhere((entry) => entry['gateId'] == 'STAGE2D-F6');
    final lr07 = gates.singleWhere((entry) => entry['gateId'] == 'LR-07');
    expect(f6['currentStatus'], 'OPEN');
    expect(f6['authorization'], 'BLOCKS_PILOT_HANDOUT');
    expect(
      _objects(f6['evidence']).single['decision'],
      'READY_AWAITING_LR07_CONTAINMENT',
    );
    expect(lr07['currentStatus'], 'OPEN');
    expect(
      _object(ledger['programmeDecision'])['pilotHandout'],
      'NOT_AUTHORIZED',
    );
    expect(_object(ledger['programmeDecision'])['nextMutation'], 'STAGE2D-F6');
  });
}
