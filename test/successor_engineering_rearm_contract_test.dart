import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readObject(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

void main() {
  test(
    'successor engineering is re-armed without changing Build 11 authority',
    () {
      final ledger = _readObject('governance/programme-ledger.json');
      final sealedDecision =
          (ledger['programmeDecision'] as Map).cast<String, dynamic>();
      final successorDecision =
          (ledger['successorEngineeringDecision'] as Map)
              .cast<String, dynamic>();
      final authority = _readObject(
        'governance/successor-engineering-rearm-2026-08-16.json',
      );

      expect(
        sealedDecision['decisionScope'],
        'SEALED_BUILD11_STAGE2D_PROGRAMME',
      );
      expect(
        sealedDecision['pilotHandout'],
        'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER',
      );
      expect(sealedDecision['nextMutation'], 'NONE_ALL_PROGRAMME_GATES_CLOSED');
      expect(successorDecision['status'], 'RE_ARMED_SOURCE_AND_CI');
      expect(successorDecision['releaseAuthority'], 'NONE_SOURCE_AND_CI_ONLY');
      expect(successorDecision['sealedBuild11AuthorityChanged'], isFalse);
      expect(authority['status'], 'ACTIVE_SOURCE_AND_CI_ONLY');
      expect(
        _strings(authority['notAuthorized']),
        containsAll(<String>[
          'production Firebase deployment',
          'App Check or Play Integrity activation',
          'reuse of the Build 11 package identity',
          'unrestricted distribution',
        ]),
      );
    },
  );

  test('current successor index distinguishes every release authority plane', () {
    final state = _readObject('release/current-successor-state.json');
    final localStore = (state['localStore'] as Map).cast<String, dynamic>();
    final backend = (state['deployedBackend'] as Map).cast<String, dynamic>();
    final rules = (state['rulesAndIndexes'] as Map).cast<String, dynamic>();
    final runtimeIam = (state['runtimeIam'] as Map).cast<String, dynamic>();
    final appCheck = (state['appCheck'] as Map).cast<String, dynamic>();
    final client = (state['client'] as Map).cast<String, dynamic>();
    final device = (state['deviceAndPilot'] as Map).cast<String, dynamic>();
    final deployment = _readObject(
      'release/build12-live-deployment-authority.json',
    );
    final deploymentSource =
        (deployment['source'] as Map).cast<String, dynamic>();
    final deploymentBoundary =
        (deployment['authorityBoundary'] as Map).cast<String, dynamic>();

    expect(
      state['status'],
      'BUILD12_BACKEND_RULES_INDEXES_DEPLOYED_PENDING_SIGNING_AND_DEVICE_PROOF',
    );
    expect(localStore['schemaVersion'], 6);
    expect(
      backend['currentSuccessorSourceDeployment'],
      'PROVED_EXACT_FUNCTION_FLEET',
    );
    expect(
      rules['currentSuccessorDeploymentReadback'],
      'PASS_EXACT_RULES_AND_61_READY_INDEXES',
    );
    expect(
      runtimeIam['currentSuccessorDeploymentBinding'],
      'PASS_EXACT_LIVE_READBACK',
    );
    expect(appCheck['mutatingCallableSourceDefault'], isFalse);
    expect(
      client['successorBuild'],
      'BUILD12_LIVE_BACKEND_READY_PENDING_REMOTE_SIGNING',
    );
    expect(
      deployment['status'],
      'PASS_BUILD12_BACKEND_RULES_INDEXES_IAM_DEPLOYED_EXACT',
    );
    expect(
      deploymentSource['liveDeploymentAuthorityCommit'],
      'ce2a85acc9eca322dc1288c1df600d4c84f0e738',
    );
    expect(
      deploymentSource['artifactDispatchCommit'],
      'PENDING_EVIDENCE_MERGE',
    );
    expect(
      deploymentSource['functionsSourceUnchangedThroughLiveDeploymentAuthorityCommit'],
      isTrue,
    );
    expect((deployment['externalEvidence'] as List<dynamic>), hasLength(4));
    expect(deploymentBoundary['backendDeploymentProved'], isTrue);
    expect(deploymentBoundary['rulesAndIndexesDeploymentProved'], isTrue);
    expect(deploymentBoundary['runtimeIamProved'], isTrue);
    expect(deploymentBoundary['productionSignedClientConstructed'], isFalse);
    expect(deploymentBoundary['deviceUpgradeProved'], isFalse);
    expect(deploymentBoundary['pilotHandoutAuthorized'], isFalse);
    expect(device['currentSuccessorPilotHandout'], 'NOT_AUTHORIZED');
    expect(device['unrestrictedDistribution'], 'NO_GO');
  });
}
