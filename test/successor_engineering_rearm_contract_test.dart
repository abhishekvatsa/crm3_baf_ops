import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readObject(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

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
    final successorSource = (state['source'] as Map).cast<String, dynamic>();
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
    final deploymentApproval = _readObject(
      'release/approvals/build12-backend-rules-indexes-deployment-authorization.json',
    );
    final deploymentSource =
        (deployment['source'] as Map).cast<String, dynamic>();
    final deploymentBoundary =
        (deployment['authorityBoundary'] as Map).cast<String, dynamic>();

    expect(
      state['status'],
      'BUILD12_FINALIZED_DEVICE_UPGRADE_PROVED_POST_ASSET_LIVE_WORKFLOW_AND_PILOT_PENDING',
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
      'BUILD12_PRODUCTION_SIGNED_FINALIZED_NON_DISTRIBUTABLE',
    );
    expect(
      deployment['status'],
      'PASS_BUILD12_BACKEND_RULES_INDEXES_IAM_DEPLOYED_EXACT',
    );
    expect(deploymentApproval['approved'], isTrue);
    expect(deploymentApproval['approvalReference'], 'BAF-FIREBASE-DEPLOY-012');
    expect(
      deploymentApproval['recordingTiming'],
      'POST_DEPLOYMENT_RECORD_OF_PREEXISTING_TASK_AUTHORIZATION',
    );
    expect(
      (deployment['authorization'] as Map<String, dynamic>)['recordSha256'],
      _sha256(
        'release/approvals/build12-backend-rules-indexes-deployment-authorization.json',
      ),
    );
    final deploymentControls =
        (deploymentApproval['requiredControls'] as Map).cast<String, dynamic>();
    expect(deploymentControls['exactCleanMergedMain'], isTrue);
    expect(deploymentControls['fullReleaseGateRequired'], isTrue);
    expect(
      deploymentControls['productionBusinessDataMutationAuthorized'],
      isFalse,
    );
    expect(deploymentControls['appCheckActivationAuthorized'], isFalse);
    expect(deploymentControls['pilotHandoutAuthorized'], isFalse);
    expect(
      deploymentSource['liveDeploymentAuthorityCommit'],
      'ce2a85acc9eca322dc1288c1df600d4c84f0e738',
    );
    expect(
      deploymentSource['artifactDispatchCommit'],
      '8ba5b237cef151b001d9bea41e16e68015091e43',
    );
    expect(
      deploymentSource['finalizationReceiptSha256'],
      _sha256('release/evidence/build-12-finalization-closure.json'),
    );
    expect(
      successorSource['build12FinalizationReceiptSha256'],
      _sha256('release/evidence/build-12-finalization-closure.json'),
    );
    expect(
      deploymentSource['functionsSourceUnchangedThroughLiveDeploymentAuthorityCommit'],
      isTrue,
    );
    expect((deployment['externalEvidence'] as List<dynamic>), hasLength(4));
    expect(deploymentBoundary['backendDeploymentProved'], isTrue);
    expect(deploymentBoundary['rulesAndIndexesDeploymentProved'], isTrue);
    expect(deploymentBoundary['runtimeIamProved'], isTrue);
    expect(deploymentBoundary['productionSignedClientConstructed'], isTrue);
    expect(deploymentBoundary['deviceUpgradeProved'], isTrue);
    expect(
      deploymentBoundary['postAssetPopulationLiveWorkflowValidationProved'],
      isFalse,
    );
    expect(deploymentBoundary['pilotHandoutAuthorized'], isFalse);
    expect(
      device['currentSuccessorDeviceProof'],
      'PASS_EXACT_BUILD12_PHYSICAL_IN_PLACE_UPGRADE_AND_FEATURE_SURFACES',
    );
    expect(device['postAssetPopulationLiveWorkflowProof'], 'PENDING');
    expect(device['currentSuccessorPilotHandout'], 'NOT_AUTHORIZED');
    expect(device['unrestrictedDistribution'], 'NO_GO');
  });
}
