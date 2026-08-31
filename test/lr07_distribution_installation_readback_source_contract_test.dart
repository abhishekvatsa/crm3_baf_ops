import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test(
    'LR-07 policy binds exact retained artifacts and installation receipt',
    () {
      final policy =
          jsonDecode(
                read(
                  'release/lr07-distribution-installation-readback-policy.json',
                ),
              )
              as Map<String, dynamic>;
      final artifacts =
          (policy['expectedArtifactsForContainment'] as List)
              .cast<Map<String, dynamic>>();

      expect(policy['schemaVersion'], 1);
      expect(
        policy['policyId'],
        'LR07-DISTRIBUTION-INSTALLATION-READBACK-POLICY-V1',
      );
      expect(policy['repository'], 'abhishekvatsa/crm3_baf_ops');
      expect(policy['productionProjectId'], 'crm3-baf-ops-b8638');
      expect(policy['expectedRepositoryVisibility'], 'PUBLIC');
      expect(
        (policy['sourceEvidence'] as List).cast<Map<String, dynamic>>().map(
          (entry) => entry['path'],
        ),
        containsAll(<String>[
          '.github/workflows/production-artifact.yml',
          'release/evidence/build-20-finalization-closure.json',
          'release/evidence/build-19-finalization-closure.json',
          'release/evidence/build-18-device-acceptance.json',
        ]),
      );
      expect(
        (policy['workflow']
            as Map<String, dynamic>)['requiredArtifactRetentionDays'],
        1,
      );
      expect(artifacts.map((entry) => entry['buildNumber']).toList(), <int>[
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
      ]);
      expect(artifacts.map((entry) => entry['id']).toSet(), <int>{
        8711253816,
        8730747624,
        8771948980,
        8836687771,
        8866525607,
        9116320474,
        9122790773,
        9125100777,
        9307950694,
        9468702427,
        9475994815,
        9547514373,
        9567065107,
        9614787514,
        9683214490,
        9717908539,
        9748603697,
      });
      expect(
        artifacts.where((entry) => entry['dualCustodyCompleted'] == true),
        hasLength(15),
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 10,
        )['authorityReceiptPath'],
        'release/evidence/build-10-finalization-block.json',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 4,
        )['deletionBasis'],
        'CONSUMED_NON_DISTRIBUTABLE_FINALIZATION_BLOCKED',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 11,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_DEVICE_PROVED_NON_DISTRIBUTABLE',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 12,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_DEVICE_UPGRADE_PROVED_NON_DISTRIBUTABLE',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 13,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_RUNTIME_UNADJUDICATED_NON_DISTRIBUTABLE',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 14,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_DEVICE_VALIDATION_PENDING_NON_DISTRIBUTABLE',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 15,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_DEVICE_VALIDATION_PENDING_NON_DISTRIBUTABLE',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 16,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_DEVICE_VALIDATION_PENDING_NON_DISTRIBUTABLE',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 17,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_DEVICE_VALIDATION_PENDING_NON_DISTRIBUTABLE',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 18,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_DEVICE_ACCEPTED_MUTATING_FLOW_PENDING_NON_DISTRIBUTABLE',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 19,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_DEVICE_VALIDATION_PENDING_NON_DISTRIBUTABLE',
      );
      expect(
        artifacts.singleWhere(
          (entry) => entry['buildNumber'] == 20,
        )['deletionBasis'],
        'FINALIZED_DUAL_CUSTODY_DEVICE_VALIDATION_PENDING_NON_DISTRIBUTABLE',
      );
      expect(
        (policy['executionAuthority']
            as Map<String, dynamic>)['requiredPresentArtifactIds'],
        <int>[9748603697],
      );

      final installation =
          policy['installationReceipt'] as Map<String, dynamic>;
      expect(installation['bytes'], 8119);
      expect(
        installation['sha256'],
        '4BD8332FBCF80B6E809B5A3FFE94EDD7560C482D898B6B9E2F37D6F63422BCEC',
      );
      expect(installation['versionCode'], 8);
    },
  );

  test('production workflow minimizes future public artifact retention', () {
    final workflow = read('.github/workflows/production-artifact.yml');
    final verifier = read('tools/release/Test-ProductionReleasePolicy.ps1');
    final releaseGate = read('.github/workflows/release-gate.yml');
    final package = jsonDecode(read('package.json')) as Map<String, dynamic>;
    final scripts = package['scripts'] as Map<String, dynamic>;

    expect(workflow, contains('retention-days: 1'));
    expect(workflow, isNot(contains('retention-days: 90')));
    expect(verifier, contains("'retention-days: 1'"));
    expect(
      scripts['test:distribution-readback-custody'],
      contains('collectDistributionInstallationReadback.test.mjs'),
    );
    expect(
      scripts['test:distribution-readback-custody'],
      contains('containGitHubProductionArtifacts.test.mjs'),
    );
    expect(releaseGate, contains('npm run test:distribution-readback-custody'));
  });

  test('containment is exact, approval-bound and preserves workflow runs', () {
    final source = read('tools/release/containGitHubProductionArtifacts.js');

    expect(source, contains('artifactDeletionRequiresExplicitOwnerApproval'));
    expect(source, contains('requiredOwnerApprovalPhrase'));
    expect(source, contains('--owner-approval'));
    expect(source, contains('deleteOnlyExactArtifactIds'));
    expect(source, contains(r'actions/artifacts/${artifact.id}'));
    expect(source, contains('inventoryAfter.length !== 0'));
    expect(source, isNot(contains('gh run delete')));
    expect(source, isNot(contains(r'actions/runs/${artifact.id}')));
  });

  test(
    'strict readback remains non-closing and final adjudication is recorded',
    () {
      final source = read(
        'tools/release/collectDistributionInstallationReadback.js',
      );
      final decision = read(
        'docs/v4_2_r1/LR07_DISTRIBUTION_INSTALLATION_READBACK.md',
      );
      final ledger =
          jsonDecode(read('governance/programme-ledger.json'))
              as Map<String, dynamic>;
      final gates =
          (ledger['programmeGates'] as List).cast<Map<String, dynamic>>();
      final lr07 = gates.singleWhere((record) => record['gateId'] == 'LR-07');

      expect(source, contains('liveProductionArtifactInventoryEmpty'));
      expect(source, contains('githubReleaseInventoryEmpty'));
      expect(source, contains('externalInstallationReceiptExact'));
      expect(source, contains('selectProductionArtifacts'));
      expect(source, contains('productionWorkflowRuns'));
      expect(source, contains('latestContainmentFinalizationExact'));
      expect(source, contains('historicalFailedAttemptsExact'));
      expect(source, contains('latestContainmentWorkflowRunExact'));
      expect(source, contains('collectorAuthorizesClosure: false'));
      expect(source, contains('flag: "wx"'));
      expect(decision, contains('collector itself does not close `LR-07`'));
      expect(
        decision,
        contains('Status: CLOSED - EXACT BUILD 11 SEALED PILOT AUTHORIZED'),
      );
      expect(lr07['currentStatus'], 'CLOSED');
      expect(lr07['authorization'], 'CLOSED_PASS');
      expect(lr07['evidence'], hasLength(6));
      expect(lr07['requiredExitEvidence'], hasLength(6));
      expect(lr07['reArmTriggers'], hasLength(7));
      expect(lr07['statusHistory'], hasLength(6));
      expect((lr07['statusHistory'] as List).last['status'], 'CLOSED');
    },
  );
}
