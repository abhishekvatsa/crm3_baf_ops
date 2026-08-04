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
  test('LR-03 and LR-06 close on sealed acquisition, not posture fiction', () {
    const receiptPath =
        'release/evidence/lr03-lr06-functions-iam-dependency-live-readback.json';
    const closurePath = 'release/evidence/lr03-lr06-live-readback-closure.json';
    final receipt =
        jsonDecode(File(receiptPath).readAsStringSync())
            as Map<String, dynamic>;
    final closure =
        jsonDecode(File(closurePath).readAsStringSync())
            as Map<String, dynamic>;
    final policy =
        jsonDecode(
              File(
                'release/lr03-lr06-functions-live-readback-policy.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    final receiptBody = Map<String, dynamic>.from(receipt)
      ..remove('receiptSha256');
    expect(_canonicalSha256(receiptBody), receipt['receiptSha256']);
    expect(
      receipt['receiptSha256'],
      '7077afc11478848c2b400afab6e86622a40cc7510fd1abcf24eee3f128f239df',
    );
    expect(receipt['mode'], 'STRICT');
    expect(receipt['projectId'], 'crm3-baf-ops-b8638');
    expect(receipt['region'], 'asia-south1');
    expect(receipt['decision'], 'PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK');
    expect(receipt['failedChecks'], isEmpty);
    expect(_object(receipt['checks']).values, everyElement(isTrue));

    final before = _object(_object(receipt['source'])['before']);
    final after = _object(_object(receipt['source'])['after']);
    for (final source in <Map<String, dynamic>>[before, after]) {
      expect(source['branch'], 'main');
      expect(source['commit'], 'b194dfe1a137256c3bfe0e113753a37f796a2e32');
      expect(source['originMain'], source['commit']);
      expect(source['governedWorktreeClean'], isTrue);
      expect(source['materialChangeCount'], 0);
    }

    final posture = _object(receipt['posture']);
    expect(posture['sourceFunctionCount'], 14);
    expect(posture['deployedFunctionCount'], 9);
    expect(posture['decision'], 'HOLD_RUNTIME_IDENTITY_DEPENDENCY_POSTURE');
    expect(_strings(posture['missingFromLive']), <String>[
      'executeMaintenanceWorkflowCommand',
      'maintenanceWorkflowEscalationSweep',
      'mutateChargeAbnormality',
      'mutateUserAuthority',
      'onMaintenanceWorkflowEventCreated',
    ]);
    expect(_strings(posture['defaultComputeFunctionNames']), hasLength(7));
    expect(_strings(posture['dependencyDriftFunctionNames']), hasLength(9));
    expect(_strings(posture['holds']), <String>[
      'deployedFunctionFleetDiffersFromSource',
      'sourceDeclaredRuntimeBindingNotDeployed',
      'functionsStillUseDefaultComputeIdentity',
      'runtimeIdentityHasBroadProjectRole',
      'deployedDependencyInventoryDiffersFromCurrentSource',
    ]);
    final outputs = _object(receipt['outputs']);
    final iam = _object(outputs['iam']);
    expect(iam['runtimeIdentityCount'], 3);
    expect(iam['defaultComputeHasUnconditionalEditor'], isTrue);
    expect(_object(receipt['mutationBoundary']).values, everyElement(isFalse));
    final privacy = _object(receipt['privacyBoundary']);
    expect(privacy['operatorAccountIdentityRetained'], isFalse);
    expect(privacy['userOrBusinessDocumentsRead'], isFalse);
    expect(privacy['sourceArchiveContentRetained'], isFalse);
    expect(privacy['packageManifestOrLockfileContentRetained'], isFalse);

    final liveReceipt = _object(closure['liveReceipt']);
    expect(liveReceipt['path'], receiptPath);
    expect(_fileSha256(receiptPath), liveReceipt['fileSha256']);
    expect(File(receiptPath).lengthSync(), liveReceipt['fileBytes']);
    expect(liveReceipt['receiptSha256'], receipt['receiptSha256']);
    expect(
      closure['decision'],
      'PASS_LR03_LR06_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK_CLOSURE_WITH_ADVERSE_POSTURE',
    );
    final authorities = _objects(closure['sourceAuthorities']);
    expect(authorities.map((entry) => entry['pullRequest']), <int>[136, 137]);
    expect(
      authorities.map((entry) => _object(entry['pullRequestCi'])['runId']),
      <int>[30885081117, 30887358479],
    );
    expect(
      authorities.map((entry) => _object(entry['postMergeCi'])['runId']),
      <int>[30885486289, 30887896661],
    );
    for (final authority in authorities) {
      expect(authority['sourceTree'], authority['mergeTree']);
      expect(_object(authority['pullRequestCi'])['conclusion'], 'success');
      expect(_object(authority['postMergeCi'])['conclusion'], 'success');
    }
    expect(_object(closure['closureBoundary']).values, everyElement(isFalse));
    expect(policy['collectorStatus'], 'SOURCE_CI_AND_LIVE_READBACK_PROVED');

    final gates = _objects(ledger['programmeGates']);
    final findings = _objects(ledger['technicalFindings']);
    for (final gateId in <String>['LR-03', 'LR-06']) {
      final record = gates.singleWhere((entry) => entry['gateId'] == gateId);
      expect(record['authorityType'], 'LIVE_READBACK');
      expect(record['currentStatus'], 'CLOSED');
      expect(record['authorization'], 'CLOSED_PASS');
      expect(
        _objects(record['statusHistory']).map((entry) => entry['status']),
        <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
      );
      expect(
        _objects(record['evidence']).map((entry) => entry['sha256']).toSet(),
        <String>{
          '6B7AE10D01DB8141F0403BE6563AA49C4557A980282BFFAB65DD1548D8B9DDB5',
          '6BCD937E7AD77A2C54F532C82C1D8CA681190498F17650C321DAAA8EAA23E7B4',
        },
      );
      expect(_strings(record['reArmTriggers']), hasLength(6));
    }
    for (final findingId in <String>['S-01', 'D-01']) {
      final record = findings.singleWhere(
        (entry) => entry['findingId'] == findingId,
      );
      expect(record['currentStatus'], 'CLOSED');
      expect(
        _objects(record['statusHistory']).map((entry) => entry['status']),
        findingId == 'S-01'
            ? <String>['OPEN', 'CLOSED']
            : <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
      );
      expect(_objects(record['evidence']), hasLength(3));
      expect(
        _objects(record['evidence']).map((entry) => entry['sha256']),
        contains(
          'B9862804EA98080FC4BCD74DC92717C0D47A3DEE8A8DD5B17F20A23E584FC5FA',
        ),
      );
      expect(_strings(record['requiredExitEvidence']), isNotEmpty);
    }
    final p05 = findings.singleWhere((entry) => entry['findingId'] == 'P-05');
    expect(p05['currentStatus'], 'OPEN');
    expect(
      _objects(p05['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN'],
    );
    expect(_objects(p05['evidence']), hasLength(2));
    expect(_object(ledger['programmeDecision'])['nextMutation'], 'STAGE2D-F4');
    expect(
      _object(ledger['programmeDecision'])['pilotHandout'],
      'NOT_AUTHORIZED',
    );
  });
}
