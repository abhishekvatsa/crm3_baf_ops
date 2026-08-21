import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

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

String _canonicalSha256(Map<String, dynamic> value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

String _fileSha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

void main() {
  test('P-05 authority repair is additive, exact and privacy safe', () {
    const receiptPath =
        'release/evidence/p05-firestore-recoverability-authority-repair-live-readback.json';
    const repairPath =
        'release/evidence/p05-firestore-recoverability-authority-repair.json';
    const historicalClosurePath =
        'release/evidence/p05-firestore-recoverability-closure.json';

    final receipt = _object(jsonDecode(File(receiptPath).readAsStringSync()));
    final repair = _object(jsonDecode(File(repairPath).readAsStringSync()));
    final ledger = _object(
      jsonDecode(File('governance/programme-ledger.json').readAsStringSync()),
    );

    expect(
      _fileSha256(receiptPath),
      '80875E8284D6AB24C8B20E18E795CA24B5D37C9A4CD9BC2C308287167E35597D',
    );
    expect(File(receiptPath).lengthSync(), 8364);
    final receiptBody = Map<String, dynamic>.from(receipt)
      ..remove('receiptSha256');
    expect(_canonicalSha256(receiptBody), receipt['receiptSha256']);
    expect(
      receipt['receiptSha256'],
      '46db50312e005f60e22117a14bcf03845d489296e277eb65cf1ff6de3e3f57b0',
    );
    expect(receipt['decision'], 'PASS_FIRESTORE_RECOVERABILITY_LIVE_READBACK');
    expect(receipt['failedChecks'], isEmpty);
    expect(_object(receipt['checks']).values, everyElement(isTrue));
    expect(_object(receipt['posture'])['holds'], isEmpty);

    final before = _object(_object(receipt['source'])['before']);
    final after = _object(_object(receipt['source'])['after']);
    expect(before, after);
    expect(before['branch'], 'main');
    expect(before['commit'], 'e1e1126f0d5d86f68d9fb1cf017271014c1396e9');
    expect(before['tree'], 'dffd3d30ffcef0a4bc6ebeb570422818219f1772');
    expect(before['commit'], before['originMain']);
    expect(before['governedWorktreeClean'], isTrue);

    final outputs = _object(receipt['outputs']);
    final operations = _object(outputs['operations']);
    final sourceExport = _object(operations['isolatedRestoreSourceExport']);
    final isolated = _object(outputs['isolatedRestore']);
    final isolatedOperation = _object(isolated['operation']);
    expect(sourceExport['exactSuccessfulExport'], isTrue);
    expect(sourceExport['completedDocuments'], 81);
    expect(sourceExport['estimatedDocuments'], 81);
    expect(isolated['exactSuccessfulImportAndValidation'], isTrue);
    expect(isolatedOperation['completedDocuments'], 81);
    expect(isolatedOperation['estimatedDocuments'], 81);
    expect(
      sourceExport['outputUriPrefixSha256'],
      isolatedOperation['inputUriPrefixSha256'],
    );
    expect(_object(receipt['mutationBoundary']).values, everyElement(isFalse));

    expect(
      _fileSha256(repairPath),
      'EC7B4A3C7BB58BC67B4E8E55C2EBB9700BF793E126D0871350585F8EB97D2AAF',
    );
    expect(File(repairPath).lengthSync(), 5606);
    expect(repair['decision'], 'PASS_P05_AUTHORITY_GAPS_REPAIRED');
    expect(
      _fileSha256(historicalClosurePath),
      '176A143BACD196701A782F8959B96B69FC11CE401DB6D122E4F16DE2C1B4EE79',
    );
    final historicalBoundary = _object(repair['historicalEvidenceBoundary']);
    expect(historicalBoundary['historicalClosureRewritten'], isFalse);
    expect(historicalBoundary['historicalLiveReceiptRewritten'], isFalse);
    expect(historicalBoundary['repairIsAdditive'], isTrue);

    final sourceAuthority = _object(repair['collectorSourceAuthority']);
    expect(sourceAuthority['pullRequest'], 253);
    expect(
      _object(sourceAuthority['pullRequestRun']),
      containsPair('runId', 32503561030),
    );
    expect(_object(sourceAuthority['pullRequestRun'])['conclusion'], 'success');
    expect(
      _object(sourceAuthority['postMergeRun']),
      containsPair('runId', 32504753533),
    );
    expect(_object(sourceAuthority['postMergeRun'])['conclusion'], 'success');

    final revisionAuthority = _object(
      repair['correctedClosureRevisionAuthority'],
    );
    expect(revisionAuthority['pullRequest'], 174);
    expect(
      revisionAuthority['sourceHeadCommit'],
      '61f7f65cb52de3ce7b558edaa57b68ed22f96221',
    );
    expect(_object(revisionAuthority['pullRequestRun'])['runId'], 31396537688);
    expect(_object(revisionAuthority['postMergeRun'])['runId'], 31397464741);
    expect(
      _object(revisionAuthority['pullRequestRun'])['conclusion'],
      'success',
    );
    expect(_object(revisionAuthority['postMergeRun'])['conclusion'], 'success');

    final ownerRatification = _object(repair['ownerRatification']);
    expect(
      ownerRatification['authorizationMode'],
      'POST_IMPLEMENTATION_OWNER_RATIFICATION',
    );
    expect(ownerRatification['ownerApprovalAcknowledged'], isTrue);
    expect(ownerRatification['rawApprovalPhrasesRetained'], isFalse);
    final approvals = _objects(ownerRatification['approvalEvidence']);
    expect(approvals, hasLength(2));
    expect(
      approvals.map((entry) => entry.keys.toSet()),
      everyElement(<String>{
        'approvalPhraseSha256',
        'approvalPhraseUtf8Bytes',
        'meaning',
      }),
    );
    expect(
      approvals.map((entry) => entry['approvalPhraseSha256']).toSet(),
      <String>{
        '328A62A785E21AA2F67FC5D3DB631DD0DBD80CA149D0346E85B5002C6E225C95',
        '8CAF93C7EB3D05A3A07452B144AB769D04A33791CAAC8F4BCC105034EEC4D446',
      },
    );
    expect((ownerRatification['ratifiedScope'] as List<dynamic>), hasLength(6));
    expect(_object(repair['mutationBoundary']).values, everyElement(isFalse));

    final findings = _objects(ledger['technicalFindings']);
    final p05 = findings.singleWhere((entry) => entry['findingId'] == 'P-05');
    expect(p05['currentStatus'], 'CLOSED');
    expect(
      _objects(p05['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
    );
    expect(
      _objects(p05['evidence']).map((entry) => entry['sha256']).toSet(),
      containsAll(<String>{
        '80875E8284D6AB24C8B20E18E795CA24B5D37C9A4CD9BC2C308287167E35597D',
        'EC7B4A3C7BB58BC67B4E8E55C2EBB9700BF793E126D0871350585F8EB97D2AAF',
      }),
    );
  });
}
