import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

dynamic _canonicalize(dynamic value) {
  if (value is List<dynamic>) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value is Map) {
    final sorted = SplayTreeMap<String, dynamic>();
    for (final entry in value.entries) {
      sorted[entry.key as String] = _canonicalize(entry.value);
    }
    return sorted;
  }
  return value;
}

String _canonicalSha256(Map<String, dynamic> value) {
  return sha256
      .convert(utf8.encode(jsonEncode(_canonicalize(value))))
      .toString();
}

String _fileSha256(String path) {
  return sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();
}

void main() {
  test('P-05 closes only on exact clean-main recovery proof', () {
    const receiptPath =
        'release/evidence/p05-firestore-recoverability-final-live-readback.json';
    const closurePath =
        'release/evidence/p05-firestore-recoverability-closure.json';
    final receipt = _object(jsonDecode(File(receiptPath).readAsStringSync()));
    final closure = _object(jsonDecode(File(closurePath).readAsStringSync()));
    final ledger = _object(
      jsonDecode(File('governance/programme-ledger.json').readAsStringSync()),
    );

    expect(
      _fileSha256(receiptPath),
      '4DDA4B23DA7F12AC958B92B7196513A7DA301D19505A489A9D88626A20BD9FCA',
    );
    expect(File(receiptPath).lengthSync(), 7492);
    final receiptBody = Map<String, dynamic>.from(receipt)
      ..remove('receiptSha256');
    expect(_canonicalSha256(receiptBody), receipt['receiptSha256']);
    expect(
      receipt['receiptSha256'],
      '38faf40444959fb208295a9cdfa752519bd0da5afd8ce77d0f2c9930c198fb79',
    );
    expect(receipt['decision'], 'PASS_FIRESTORE_RECOVERABILITY_LIVE_READBACK');
    expect(receipt['failedChecks'], isEmpty);
    expect(_object(receipt['checks']).values, everyElement(isTrue));
    expect(_object(receipt['posture'])['holds'], isEmpty);
    expect(
      _object(receipt['posture'])['decision'],
      'PASS_FIRESTORE_RECOVERABILITY_POSTURE',
    );

    final before = _object(_object(receipt['source'])['before']);
    final after = _object(_object(receipt['source'])['after']);
    expect(before, after);
    expect(before['branch'], 'main');
    expect(before['commit'], '1e9803109844eaede717337317e82865c74bbd6f');
    expect(before['tree'], 'bfec7cbbea7599887d7c7a1e8ae0b530f2d4861d');
    expect(before['commit'], before['originMain']);
    expect(before['governedWorktreeClean'], isTrue);
    expect(before['materialChangeCount'], 0);

    final outputs = _object(receipt['outputs']);
    final database = _object(outputs['database']);
    expect(
      database['pointInTimeRecoveryEnablement'],
      'POINT_IN_TIME_RECOVERY_ENABLED',
    );
    expect(database['deleteProtectionState'], 'DELETE_PROTECTION_ENABLED');
    final schedules = _object(outputs['schedules']);
    expect(schedules['count'], 2);
    expect(_object(schedules['recurrenceTypeCounts']), <String, dynamic>{
      'DAILY': 1,
      'WEEKLY': 1,
    });
    final backups = _object(outputs['backups']);
    expect(backups['count'], 5);
    expect(_object(backups['stateCounts']), <String, dynamic>{'READY': 5});
    expect(backups['allDatabasesTargetExact'], isTrue);
    expect(_object(outputs['operations'])['successfulImportOperationCount'], 0);

    final isolated = _object(outputs['isolatedRestore']);
    final isolatedDatabase = _object(isolated['database']);
    final isolatedOperation = _object(isolated['operation']);
    expect(isolatedDatabase['databaseId'], 'p05-restore-20260806');
    expect(isolatedDatabase['nameExact'], isTrue);
    expect(
      isolatedDatabase['deleteProtectionState'],
      'DELETE_PROTECTION_ENABLED',
    );
    expect(isolatedOperation['operationState'], 'SUCCESSFUL');
    expect(isolatedOperation['completedDocuments'], 81);
    expect(isolatedOperation['estimatedDocuments'], 81);
    expect(isolated['exactSuccessfulImportAndValidation'], isTrue);
    expect(_object(receipt['mutationBoundary']).values, everyElement(isFalse));

    expect(
      _fileSha256(closurePath),
      '67F6D0AED71DE697EE7F44E823EEC261B661155073C5B7C12BD8B38B7D4D4632',
    );
    expect(File(closurePath).lengthSync(), 2824);
    expect(closure['decision'], 'PASS_P05_FIRESTORE_RECOVERABILITY_CLOSED');
    expect(
      closure['recordTransition'],
      'OPEN_TO_LIVE_READBACK_PROVED_TO_CLOSED',
    );
    final liveReceipt = _object(closure['liveReceipt']);
    expect(liveReceipt['path'], receiptPath);
    expect(liveReceipt['fileSha256'], _fileSha256(receiptPath));
    expect(liveReceipt['fileBytes'], File(receiptPath).lengthSync());
    expect(liveReceipt['receiptSha256'], receipt['receiptSha256']);
    final remoteCi = _object(
      _object(closure['collectorAuthority'])['remoteCi'],
    );
    expect(remoteCi['status'], 'NOT_CREATED_ACCOUNT_ACTIONS_CAPACITY');
    expect(remoteCi['pullRequestRunCreated'], isFalse);
    expect(remoteCi['postMergeRunCreated'], isFalse);
    expect(_object(closure['closureBoundary']).values, everyElement(isFalse));
    expect(
      _object(closure['historicalBoundary']).values,
      containsAll(<bool>[true, false]),
    );

    final findings = _objects(ledger['technicalFindings']);
    final p05 = findings.singleWhere((entry) => entry['findingId'] == 'P-05');
    expect(p05['authorityType'], 'LIVE_READBACK');
    expect(p05['transitionProfile'], 'LIVE_READBACK');
    expect(p05['currentStatus'], 'CLOSED');
    expect(
      _objects(p05['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
    );
    expect(
      _objects(p05['evidence']).map((entry) => entry['sha256']).toSet(),
      <String>{
        'E339FC49400BA1817084270E4E8503C12797A00A9095FE937A30EE48D8A0F18D',
        'E760C24874C3905A675C213E1997E6BFFEE9C403683CE0F86B07CABD05A36302',
        '4DDA4B23DA7F12AC958B92B7196513A7DA301D19505A489A9D88626A20BD9FCA',
        '67F6D0AED71DE697EE7F44E823EEC261B661155073C5B7C12BD8B38B7D4D4632',
      },
    );
    expect(_strings(p05['requiredExitEvidence']), hasLength(6));
    expect(_strings(p05['reArmTriggers']), hasLength(7));

    final gates = _objects(ledger['programmeGates']);
    final f4 = gates.singleWhere((entry) => entry['gateId'] == 'STAGE2D-F4');
    expect(f4['currentStatus'], 'OPEN');
    expect(_object(ledger['programmeDecision'])['nextMutation'], 'STAGE2D-F4');
    expect(
      _object(ledger['programmeDecision'])['pilotHandout'],
      'NOT_AUTHORIZED',
    );
  });
}
