import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

void main() {
  test('LR-03 and LR-06 collector is complete, private and mutation-free', () {
    final policy = _object(
      jsonDecode(
        File(
          'release/lr03-lr06-functions-live-readback-policy.json',
        ).readAsStringSync(),
      ),
    );
    final collector =
        File(
          'tools/release/collectFunctionsIamDependenciesReadback.js',
        ).readAsStringSync();
    final collectorTests =
        File(
          'tools/release/collectFunctionsIamDependenciesReadback.test.mjs',
        ).readAsStringSync();
    final functionsIndex = File('functions/src/index.ts').readAsStringSync();
    final package = _object(
      jsonDecode(File('package.json').readAsStringSync()),
    );
    final workflow =
        File('.github/workflows/release-gate.yml').readAsStringSync();
    final decision =
        File(
          'docs/v4_2_r1/LR03_LR06_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK.md',
        ).readAsStringSync();

    const expectedFunctions = <String>{
      'assignPublishedTemplateVersion',
      'beginGlobalPullRun',
      'completePlannedJobExecution',
      'executeMaintenanceWorkflowCommand',
      'getBackendReleaseIdentity',
      'maintenanceWorkflowEscalationSweep',
      'mutateAssetHierarchy',
      'mutateChargeAbnormality',
      'mutateRuntimeJobModulePopulation',
      'mutateUserAuthority',
      'onJobAssigned',
      'onMaintenanceWorkflowEventCreated',
      'onTicketCreated',
      'onTicketResolved',
      'stampGlobalPullServerClock',
    };
    expect(policy['schemaVersion'], 1);
    expect(policy['productionProjectId'], 'crm3-baf-ops-b8638');
    expect(policy['productionRegion'], 'asia-south1');
    expect(_strings(policy['gateIds']), <String>['LR-03', 'LR-06']);
    expect(
      _strings(policy['sourceFunctionExports']).toSet(),
      expectedFunctions,
    );
    expect(_strings(policy['sourceFunctionExports']), hasLength(15));
    expect(_strings(policy['sourcePendingDeploymentExports']), <String>[
      'mutateAssetHierarchy',
    ]);
    expect(_strings(policy['trackedRuntimePackages']), hasLength(8));
    expect(_object(policy['mutationBoundary']).values, everyElement(isFalse));
    final privacy = _object(policy['privacyBoundary']);
    expect(privacy['operatorAccountIdentityRetained'], isFalse);
    expect(privacy['sourceArchiveContentRetained'], isFalse);
    expect(privacy['packageManifestOrLockfileContentRetained'], isFalse);

    for (final name in expectedFunctions) {
      expect(
        functionsIndex,
        contains(name),
        reason: 'Source export $name is absent',
      );
    }
    for (final marker in <String>[
      'collectSourceBinding',
      'discoverFunctionExports',
      'sourceExportInventoryMatchesPolicy',
      'resolveCommand',
      'platformPath.join(sdkRoot, "lib", "gcloud.py")',
      'sourceProvenance?.resolvedStorageSource',
      '--if-generation-match=',
      'package-lock.json',
      'summarizeIam',
      'PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK',
      'HOLD_RUNTIME_IDENTITY_DEPENDENCY_POSTURE',
      's01Closed: false',
      'd01Closed: false',
      'advisoryAssessmentPerformed: false',
      'flag: "wx"',
    ]) {
      expect(collector, contains(marker), reason: 'Missing $marker');
    }
    for (final forbidden in <String>[
      '"functions", "deploy"',
      '"functions", "delete"',
      '"projects", "add-iam-policy-binding"',
      '"projects", "remove-iam-policy-binding"',
      'firebase deploy',
      'shell: true',
      'cmd.exe',
    ]) {
      expect(collector, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(
      collectorTests,
      contains(
        'AST discovery binds the policy to all current Function exports',
      ),
    );
    expect(
      collectorTests,
      contains(
        'adverse posture does not corrupt a valid live-readback acquisition',
      ),
    );
    expect(
      collectorTests,
      contains('IAM evidence retains only deployed runtime service accounts'),
    );
    expect(
      collectorTests,
      contains(
        'Windows gcloud uses the bundled Python entrypoint without a shell',
      ),
    );
    expect(
      _object(package['scripts'])['test:functions-live-readback-custody'],
      'node --test tools/release/collectFunctionsIamDependenciesReadback.test.mjs',
    );
    expect(workflow, contains('npm run test:functions-live-readback-custody'));
    expect(
      decision,
      contains('Collector status: SOURCE_CI_AND_LIVE_READBACK_PROVED'),
    );
    expect(
      decision,
      contains(
        'Live readback evidence: PASS acquisition / HOLD runtime posture',
      ),
    );
    expect(decision, contains('`S-01` and `D-01` own remediation'));
  });

  test('live closure preserves adverse history after later remediation', () {
    final ledger = _object(
      jsonDecode(File('governance/programme-ledger.json').readAsStringSync()),
    );
    final gates = _objects(ledger['programmeGates']);
    final findings = _objects(ledger['technicalFindings']);
    for (final gateId in <String>['LR-03', 'LR-06']) {
      final record = gates.singleWhere((entry) => entry['gateId'] == gateId);
      expect(record['currentStatus'], 'CLOSED');
      expect(_objects(record['evidence']), hasLength(2));
    }
    for (final findingId in <String>['S-01', 'D-01']) {
      final record = findings.singleWhere(
        (entry) => entry['findingId'] == findingId,
      );
      expect(record['currentStatus'], 'CLOSED');
      expect(_objects(record['evidence']), hasLength(3));
      expect(
        _objects(record['evidence']).map((entry) => entry['sha256']),
        contains(
          'B9862804EA98080FC4BCD74DC92717C0D47A3DEE8A8DD5B17F20A23E584FC5FA',
        ),
      );
      expect(
        _objects(record['statusHistory']).map((entry) => entry['status']),
        findingId == 'S-01'
            ? <String>['OPEN', 'CLOSED']
            : <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
      );
    }
  });
}
