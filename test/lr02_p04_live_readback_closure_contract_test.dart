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
  test('LR-02 and P-04 close only on sealed strict clean-main evidence', () {
    const receiptPath =
        'release/evidence/lr02-p04-firestore-live-readback.json';
    const closurePath = 'release/evidence/lr02-p04-live-readback-closure.json';
    final receipt =
        jsonDecode(File(receiptPath).readAsStringSync())
            as Map<String, dynamic>;
    final closure =
        jsonDecode(File(closurePath).readAsStringSync())
            as Map<String, dynamic>;
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    final receiptBody = Map<String, dynamic>.from(receipt)
      ..remove('receiptSha256');
    expect(_canonicalSha256(receiptBody), receipt['receiptSha256']);
    expect(receipt['decision'], 'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK');
    expect(receipt['mode'], 'STRICT');
    expect(receipt['projectId'], 'crm3-baf-ops-b8638');
    expect(receipt['failedChecks'], isEmpty);
    expect(_object(receipt['checks']).values, everyElement(isTrue));

    final before = _object(_object(receipt['source'])['before']);
    final after = _object(_object(receipt['source'])['after']);
    for (final source in <Map<String, dynamic>>[before, after]) {
      expect(source['branch'], 'main');
      expect(source['commit'], 'b6f5838360f46d8f164338164f295b93fe3335ad');
      expect(source['originMain'], source['commit']);
      expect(source['governedWorktreeClean'], isTrue);
      expect(source['materialChangeCount'], 0);
    }

    final outputs = _object(receipt['outputs']);
    final rules = _object(outputs['rules']);
    expect(rules['byteExact'], isTrue);
    expect(rules['sourceByteCount'], 136651);
    expect(rules['activeByteCount'], 136651);
    expect(rules['sourceSha256'], rules['activeSha256']);
    final indexes = _object(outputs['indexes']);
    expect(indexes['sourceCount'], 51);
    expect(indexes['cliCount'], 51);
    expect(indexes['apiCount'], 51);
    expect(indexes['apiReadyCount'], 51);
    expect(indexes['sourceSetSha256'], indexes['cliSetSha256']);
    expect(indexes['sourceSetSha256'], indexes['apiSetSha256']);
    expect(indexes['fieldOverridesMatchSource'], isTrue);
    expect(indexes['sourceFieldOverrideCount'], 0);
    expect(_object(receipt['mutationBoundary']).values, everyElement(isFalse));
    final privacyBoundary = _object(receipt['privacyBoundary']);
    expect(privacyBoundary['rulesContentRetained'], isFalse);
    expect(privacyBoundary['indexDefinitionsRetained'], isFalse);
    expect(privacyBoundary['accountIdentityRetained'], isFalse);
    expect(
      privacyBoundary['sourceMaterialRepresentedByHashesAndCountsOnly'],
      isTrue,
    );

    final liveReceipt = _object(closure['liveReceipt']);
    expect(liveReceipt['path'], receiptPath);
    expect(_fileSha256(receiptPath), liveReceipt['fileSha256']);
    expect(File(receiptPath).lengthSync(), liveReceipt['fileBytes']);
    expect(liveReceipt['receiptSha256'], receipt['receiptSha256']);
    expect(
      closure['decision'],
      'PASS_LR02_P04_FIRESTORE_RULES_INDEXES_LIVE_READBACK_CLOSURE',
    );
    final collector = _object(closure['collectorAuthority']);
    expect(collector['pullRequest'], 130);
    expect(collector['sourceTree'], collector['mergeTree']);
    expect(_object(collector['pullRequestCi'])['runId'], 30870605924);
    expect(_object(collector['pullRequestCi'])['conclusion'], 'success');
    expect(_object(collector['postMergeCi'])['runId'], 30871016815);
    expect(_object(collector['postMergeCi'])['conclusion'], 'success');
    expect(_object(closure['closureBoundary']).values, everyElement(isFalse));

    final gates = _objects(ledger['programmeGates']);
    final findings = _objects(ledger['technicalFindings']);
    final lr02 = gates.singleWhere((record) => record['gateId'] == 'LR-02');
    final p04 = findings.singleWhere((record) => record['findingId'] == 'P-04');
    for (final record in <Map<String, dynamic>>[lr02, p04]) {
      expect(record['authorityType'], 'LIVE_READBACK');
      expect(record['currentStatus'], 'CLOSED');
      expect(
        _objects(record['statusHistory']).map((entry) => entry['status']),
        <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
      );
      final evidence = _objects(record['evidence']);
      expect(evidence, hasLength(2));
      expect(evidence.map((entry) => entry['sha256']).toSet(), <String>{
        'F2DB0F6491F427636D18E1CC4EF8C95FA03A8B0E738B74E175BF97C8ECC71815',
        'E8EBE9289F235C645AB791513F5EE394C3999E95801CFC4198C757FFD647E8C6',
      });
      expect(_strings(record['reArmTriggers']), hasLength(5));
    }
    expect(lr02['authorization'], 'CLOSED_PASS');
    expect(_object(ledger['programmeDecision'])['nextMutation'], 'STAGE2D-F6');
    expect(
      _object(ledger['programmeDecision'])['pilotHandout'],
      'NOT_AUTHORIZED',
    );
  });
}
