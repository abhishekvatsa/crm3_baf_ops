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
  test('LR-04 closes only on sealed strict clean-main evidence', () {
    const receiptPath =
        'release/evidence/lr04-firestore-recoverability-live-readback.json';
    const closurePath =
        'release/evidence/lr04-firestore-recoverability-live-readback-closure.json';
    final receipt = _object(jsonDecode(File(receiptPath).readAsStringSync()));
    final closure = _object(jsonDecode(File(closurePath).readAsStringSync()));
    final ledger = _object(
      jsonDecode(File('governance/programme-ledger.json').readAsStringSync()),
    );
    final policy = _object(
      jsonDecode(
        File(
          'release/lr04-firestore-recoverability-readback-policy.json',
        ).readAsStringSync(),
      ),
    );

    final receiptBody = Map<String, dynamic>.from(receipt)
      ..remove('receiptSha256');
    expect(_canonicalSha256(receiptBody), receipt['receiptSha256']);
    expect(receipt['decision'], 'PASS_FIRESTORE_RECOVERABILITY_LIVE_READBACK');
    expect(receipt['mode'], 'STRICT');
    expect(receipt['projectId'], 'crm3-baf-ops-b8638');
    expect(receipt['database'], '(default)');
    expect(receipt['location'], 'asia-south1');
    expect(receipt['failedChecks'], isEmpty);
    expect(_object(receipt['checks']).values, everyElement(isTrue));

    final source = _object(receipt['source']);
    final before = _object(source['before']);
    final after = _object(source['after']);
    for (final binding in <Map<String, dynamic>>[before, after]) {
      expect(binding['branch'], 'main');
      expect(binding['commit'], '0d323449be267849e7043772dbfea0a7dc3bd107');
      expect(binding['tree'], 'fbdb9de46305d62af53fd764281fa577e2c94276');
      expect(binding['originMain'], binding['commit']);
      expect(binding['governedWorktreeClean'], isTrue);
      expect(binding['materialChangeCount'], 0);
    }

    final outputs = _object(receipt['outputs']);
    final database = _object(outputs['database']);
    expect(
      database['pointInTimeRecoveryEnablement'],
      'POINT_IN_TIME_RECOVERY_DISABLED',
    );
    expect(database['deleteProtectionState'], 'DELETE_PROTECTION_DISABLED');
    expect(_object(outputs['schedules'])['count'], 0);
    expect(_object(outputs['backups'])['count'], 0);
    final operations = _object(outputs['operations']);
    expect(operations['inventoryLimit'], 1000);
    expect(operations['count'], 24);
    expect(operations['inventoryBelowLimit'], isTrue);
    expect(operations['successfulExportOperationCount'], 1);
    expect(operations['successfulImportOperationCount'], 0);
    expect(
      _object(operations['sealedExport'])['exactSuccessfulExport'],
      isTrue,
    );
    expect(_object(outputs['restoreSeal'])['exactFile'], isTrue);
    expect(_object(outputs['restoreSeal'])['mutationBoundaryAllFalse'], isTrue);
    expect(
      _object(receipt['posture'])['decision'],
      'HOLD_FIRESTORE_RECOVERABILITY_POSTURE',
    );
    expect(_strings(_object(receipt['posture'])['holds']), <String>[
      'pointInTimeRecoveryDisabled',
      'deleteProtectionDisabled',
      'noNativeBackupSchedule',
      'noNativeBackup',
      'noRestoreImportProof',
    ]);
    expect(_object(receipt['mutationBoundary']).values, everyElement(isFalse));
    final privacy = _object(receipt['privacyBoundary']);
    expect(privacy['operatorAccountIdentityRetained'], isFalse);
    expect(privacy['firestoreDocumentOrBusinessPayloadRetained'], isFalse);
    expect(privacy['operationNamesOrOutputPrefixesRetained'], isFalse);

    final liveReceipt = _object(closure['liveReceipt']);
    expect(liveReceipt['path'], receiptPath);
    expect(_fileSha256(receiptPath), liveReceipt['fileSha256']);
    expect(File(receiptPath).lengthSync(), liveReceipt['fileBytes']);
    expect(liveReceipt['receiptSha256'], receipt['receiptSha256']);
    expect(
      closure['decision'],
      'PASS_LR04_FIRESTORE_RECOVERABILITY_LIVE_READBACK_CLOSURE_WITH_ADVERSE_POSTURE',
    );
    final collector = _object(closure['collectorAuthority']);
    expect(collector['pullRequest'], 139);
    expect(collector['sourceTree'], collector['mergeTree']);
    expect(_object(collector['pullRequestCi'])['runId'], 30892607011);
    expect(_object(collector['pullRequestCi'])['conclusion'], 'success');
    expect(_object(collector['postMergeCi'])['runId'], 30893195416);
    expect(_object(collector['postMergeCi'])['conclusion'], 'success');
    expect(_object(closure['closureBoundary']).values, everyElement(isFalse));
    expect(
      _object(closure['recordTransitions'])['lr04'],
      'OPEN_TO_LIVE_READBACK_PROVED_TO_CLOSED',
    );
    expect(
      _object(closure['recordTransitions'])['p05'],
      contains('REMAINS_OPEN'),
    );

    final gates = _objects(ledger['programmeGates']);
    final findings = _objects(ledger['technicalFindings']);
    final lr04 = gates.singleWhere((record) => record['gateId'] == 'LR-04');
    final p05 = findings.singleWhere((record) => record['findingId'] == 'P-05');
    expect(lr04['currentStatus'], 'CLOSED');
    expect(lr04['authorization'], 'CLOSED_PASS');
    expect(
      _objects(lr04['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
    );
    expect(p05['currentStatus'], 'OPEN');
    expect(
      p05['title'],
      'Production Firestore recovery posture lacks PITR, delete protection, native backups and restore proof',
    );
    expect(
      _objects(p05['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN'],
    );
    for (final record in <Map<String, dynamic>>[lr04, p05]) {
      expect(_objects(record['evidence']), hasLength(2));
      expect(
        _objects(record['evidence']).map((entry) => entry['sha256']).toSet(),
        <String>{
          'E339FC49400BA1817084270E4E8503C12797A00A9095FE937A30EE48D8A0F18D',
          'E760C24874C3905A675C213E1997E6BFFEE9C403683CE0F86B07CABD05A36302',
        },
      );
    }
    expect(_strings(lr04['reArmTriggers']), hasLength(7));
    expect(_strings(p05['requiredExitEvidence']), hasLength(6));
    expect(_strings(p05['reArmTriggers']), hasLength(7));
    expect(policy['collectorStatus'], 'SOURCE_CI_AND_LIVE_READBACK_PROVED');
    expect(_object(ledger['programmeDecision'])['nextMutation'], 'STAGE2D-F4');
    expect(
      _object(ledger['programmeDecision'])['pilotHandout'],
      'NOT_AUTHORIZED',
    );
  });
}
