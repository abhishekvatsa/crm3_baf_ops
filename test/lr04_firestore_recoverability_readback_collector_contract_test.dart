import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

void main() {
  test('LR-04 collector is target-bound, private and mutation-free', () {
    final policy = _object(
      jsonDecode(
        File(
          'release/lr04-firestore-recoverability-readback-policy.json',
        ).readAsStringSync(),
      ),
    );
    final collector =
        File(
          'tools/release/collectFirestoreRecoverabilityReadback.js',
        ).readAsStringSync();
    final collectorTests =
        File(
          'tools/release/collectFirestoreRecoverabilityReadback.test.mjs',
        ).readAsStringSync();
    final package = _object(
      jsonDecode(File('package.json').readAsStringSync()),
    );
    final workflow =
        File('.github/workflows/release-gate.yml').readAsStringSync();
    final decision =
        File(
          'docs/v4_2_r1/LR04_FIRESTORE_RECOVERABILITY_LIVE_READBACK.md',
        ).readAsStringSync();

    expect(policy['schemaVersion'], 1);
    expect(
      policy['policyId'],
      'LR04-FIRESTORE-RECOVERABILITY-READBACK-POLICY-V1',
    );
    expect(policy['productionProjectId'], 'crm3-baf-ops-b8638');
    expect(policy['productionDatabase'], '(default)');
    expect(policy['productionLocation'], 'asia-south1');
    expect(_strings(policy['gateIds']), <String>['LR-04']);
    expect(_strings(policy['findingIds']), <String>['P-05']);
    expect(policy['operationInventoryLimit'], 1000);
    final restoreSeal = _object(policy['restoreSeal']);
    expect(
      restoreSeal['sha256'],
      '982040C70DD01325870E877378D74A8A705B1F64576A46B2C98FB244576AE599',
    );
    expect(restoreSeal['bytes'], 4440);
    final isolatedRestore = _object(policy['isolatedRestore']);
    final sourceExport = _object(isolatedRestore['sourceExport']);
    expect(
      sourceExport['operationNameSha256'],
      'EF6A0FF2E809EA2D0C209B92380D1752E301D6C504D04BBA81D83168883C7F74',
    );
    expect(
      sourceExport['outputUriPrefixSha256'],
      isolatedRestore['inputUriPrefixSha256'],
    );
    expect(sourceExport['expectedDocumentCount'], 81);
    expect(_object(policy['mutationBoundary']).values, everyElement(isFalse));
    final privacy = _object(policy['privacyBoundary']);
    expect(privacy['operatorAccountIdentityRetained'], isFalse);
    expect(privacy['firestoreDocumentOrBusinessPayloadRetained'], isFalse);
    expect(privacy['operationNamesOrOutputPrefixesRetained'], isFalse);

    for (final marker in <String>[
      'collectSourceBinding',
      'sourceCommitMatchesOriginMain',
      'governedSourceClean',
      'resolveCommand',
      'platformPath.join(sdkRoot, "lib", "gcloud.py")',
      'firestore",\n      "databases",\n      "describe',
      'firestore",\n      "backups",\n      "schedules",\n      "list',
      'firestore",\n      "backups",\n      "list',
      'firestore",\n      "operations",\n      "list',
      'firestore",\n      "operations",\n      "describe',
      'PASS_FIRESTORE_RECOVERABILITY_LIVE_READBACK',
      'HOLD_FIRESTORE_RECOVERABILITY_POSTURE',
      'isolatedRestoreSourceExportExact',
      'isolatedRestoreDerivationExact',
      'collectorAuthorizesClosure: false',
      'sourceAndCiOnly: false',
      'flag: "wx"',
    ]) {
      expect(collector, contains(marker), reason: 'Missing $marker');
    }
    for (final forbidden in <String>[
      '"databases",\n      "update"',
      '"schedules",\n      "create"',
      '"schedules",\n      "update"',
      '"schedules",\n      "delete"',
      '"backups",\n      "delete"',
      '"operations",\n      "cancel"',
      'firestore import',
      'firestore export',
      'shell: true',
      'cmd.exe',
    ]) {
      expect(collector, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(
      collectorTests,
      contains(
        'strict acquisition passes while adverse recoverability posture remains explicit',
      ),
    );
    expect(
      collectorTests,
      contains(
        'summaries omit schedule, backup, operation and output identifiers',
      ),
    );
    expect(
      collectorTests,
      contains(
        'isolated import must derive from the exact successful source export',
      ),
    );
    expect(
      collectorTests,
      contains(
        'Windows gcloud uses the bundled Python entrypoint without a shell',
      ),
    );
    expect(
      _object(
        package['scripts'],
      )['test:firestore-recoverability-readback-custody'],
      'node --test tools/release/collectFirestoreRecoverabilityReadback.test.mjs',
    );
    expect(
      workflow,
      contains('npm run test:firestore-recoverability-readback-custody'),
    );
    expect(
      decision,
      contains('Collector status: SOURCE_CI_AND_LIVE_READBACK_PROVED'),
    );
    expect(decision, contains('A strict acquisition may pass while posture'));
    expect(
      decision,
      contains('Live readback evidence: PASS acquisition / HOLD'),
    );
    expect(decision, contains('closes evidence gate `LR-04`'));
    expect(decision, contains('does not close `P-05`'));
  });

  test('LR-04 closure preserves its historical P-05 boundary', () {
    final ledger = _object(
      jsonDecode(File('governance/programme-ledger.json').readAsStringSync()),
    );
    final gates = _objects(ledger['programmeGates']);
    final findings = _objects(ledger['technicalFindings']);
    final lr04 = gates.singleWhere((entry) => entry['gateId'] == 'LR-04');
    final p05 = findings.singleWhere((entry) => entry['findingId'] == 'P-05');
    expect(lr04['currentStatus'], 'CLOSED');
    expect(_objects(lr04['evidence']), hasLength(2));
    expect(
      _objects(lr04['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
    );
    expect(p05['currentStatus'], 'CLOSED');
    expect(_objects(p05['evidence']), hasLength(6));
    expect(
      _objects(p05['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
    );
    expect(_strings(p05['requiredExitEvidence']), hasLength(6));
  });
}
