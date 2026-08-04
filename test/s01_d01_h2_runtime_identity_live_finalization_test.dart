import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('H2, S-01 and D-01 close on exact live and source authority', () {
    final evidence = _json(
      'release/evidence/s01-d01-h2-runtime-identity-live-finalization.json',
    );
    final authority = evidence['authority'] as Map<String, dynamic>;
    final campaign = evidence['campaign'] as Map<String, dynamic>;
    final receipts =
        (campaign['receipts'] as List<dynamic>).cast<Map<String, dynamic>>();
    final posture = evidence['finalPosture'] as Map<String, dynamic>;
    final checks = evidence['checks'] as Map<String, dynamic>;
    final mutation = evidence['mutationBoundary'] as Map<String, dynamic>;
    final privacy = evidence['privacyBoundary'] as Map<String, dynamic>;
    final adjudication =
        evidence['sourceAndCiAdjudication'] as Map<String, dynamic>;
    final boundary = evidence['programmeBoundary'] as Map<String, dynamic>;

    expect(authority['branch'], 'main');
    expect(authority['commit'], 'bdc5c6ed870e7f947c40ea053cd587a56d77d48a');
    expect(authority['postMergeWorkflowRun'], 30913630958);
    expect(authority['postMergeWorkflowConclusion'], 'success');
    expect(
      (authority['postMergeJobs'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .every((job) => job['conclusion'] == 'success'),
      isTrue,
    );

    expect(receipts, hasLength(9));
    expect(
      receipts.map((receipt) => receipt['decision']),
      containsAll(<String>[
        'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_PREFLIGHT',
        'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_PROVISIONED',
        'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_CALLABLES',
        'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_EVENTS',
        'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FLEET',
        'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FINAL',
        'PASS_FUNCTIONS_IAM_DEPENDENCY_LIVE_READBACK',
      ]),
    );
    for (final receipt in receipts) {
      expect(receipt['fileSha256'], matches(RegExp(r'^[0-9A-F]{64}$')));
      expect(receipt['receiptSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
    }

    expect(posture['deployedFunctionCount'], 14);
    expect(posture['defaultComputeFunctionCount'], 0);
    expect(posture['broadRuntimeProjectGrantCount'], 0);
    expect(posture['callableProbeCount'], 8);
    expect(posture['schedulerBacklogCount'], 0);
    expect(posture['defaultComputeProjectRoles'], <String>[
      'roles/cloudbuild.builds.builder',
    ]);
    expect(posture['globalPullReaderProjectRoles'], <String>[
      'roles/datastore.viewer',
    ]);
    expect(posture['globalPullWriterProjectRoles'], <String>[
      'roles/datastore.user',
      'roles/eventarc.eventReceiver',
    ]);
    expect(posture['dependencyInventoryMatchesCurrentFunctionCount'], 14);
    expect(posture['dependencyVersionMatchesCurrentFunctionCount'], 14);
    expect(
      posture['dependencyPostureDecision'],
      'PASS_RUNTIME_IDENTITY_DEPENDENCY_POSTURE',
    );
    expect(posture['dependencyPostureHoldCount'], 0);
    expect(checks.values.every((value) => value == true), isTrue);

    expect(
      mutation['functionRedeploymentPerformedDuringFinalization'],
      isFalse,
    );
    expect(mutation['defaultComputeEditorRemoved'], isTrue);
    expect(mutation['defaultComputeEditorRollbackNeeded'], isFalse);
    expect(mutation['businessDataMutationPerformed'], isFalse);
    expect(privacy.values.every((value) => value == false), isTrue);

    expect(adjudication['status'], 'PASS_EXACT_HEAD_PULL_REQUEST_CI');
    expect(adjudication['pullRequest'], 149);
    expect(adjudication['workflowRun'], 30922839115);
    expect(adjudication['workflowEvent'], 'pull_request');
    expect(
      adjudication['headCommit'],
      '06658f8a2e5d1dca4624094da4938cda94095cf6',
    );
    expect(
      adjudication['headTree'],
      '3de31f1cae2fd91fe8def4d7d3fe72e2f3777ad5',
    );
    expect(adjudication['conclusion'], 'success');
    expect(
      (adjudication['jobs'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((job) => job['jobId'])
          .toSet(),
      <int>{92037560472, 92037560487, 92037560507, 92037560592},
    );
    expect(
      (adjudication['jobs'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .every((job) => job['conclusion'] == 'success'),
      isTrue,
    );
    expect(boundary['h2IamClosed'], isTrue);
    expect(boundary['s01Closed'], isTrue);
    expect(boundary['d01Closed'], isTrue);
    expect(boundary['stage2dF4Status'], 'OPEN');
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['distributionAuthorized'], isFalse);
    expect(
      evidence['decision'],
      'PASS_H2_S01_D01_RUNTIME_IDENTITY_AND_DEPENDENCY_CLOSURE',
    );
  });
}
