import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('O-01 to O-05 governed production-release contracts', () {
    test('O-01 authority binds corrected 70I-C parity evidence', () {
      final authority =
          jsonDecode(read('release/backend-authority.prod.json'))
              as Map<String, dynamic>;

      expect(authority['schemaVersion'], 2);
      expect(
        authority['authorityClass'],
        'verified-production-backend-composite',
      );
      expect(
        authority['authorityDigest'],
        '59474B02385322F948B8EFB26361F293F1F2A4E9841B7005DAC43BE5664FC525',
      );
      expect(authority.containsKey('deployedIndexesParityStatus'), isFalse);
      expect(authority.containsKey('deployedIndexesParityEvidence'), isFalse);

      final firestore = authority['firestore'] as Map<String, dynamic>;
      final indexes = firestore['indexes'] as Map<String, dynamic>;

      expect(indexes['status'], 'EXACT');
      expect(indexes['sourceCompositeIndexes'], 28);
      expect(indexes['deployedCompositeIndexes'], 28);
      expect(indexes['allReady'], isTrue);
      expect(indexes['fieldOverrideCount'], 0);
      expect(
        indexes['sourceSha256'],
        'D0D7120DB00D8FAB3130861776AB6E956CE6E224FB40665B3A28CB1C7B7C7D33',
      );
      expect(
        indexes['fieldOverrideFingerprint'],
        '4F53CDA18C2BAA0C0354BB5F9A3ECBE5ED12AB4D8E11BA873C2F11161202B945',
      );
      expect(
        indexes['indexIdentityFingerprint'],
        'AFAB9E0C800AD37F9E90011648C0D322E3DF9CD26C8D9FEC05CAE66A654E8134',
      );

      final evidenceChain = authority['evidenceChain'] as List<dynamic>;
      final parityEvidence = evidenceChain
          .whereType<Map<String, dynamic>>()
          .singleWhere(
            (entry) =>
                entry['role'] ==
                'LIVE_PARITY_FUNCTION_ARCHIVES_IAM_AND_TOPOLOGY',
          );

      expect(
        parityEvidence['filename'],
        'CRM3_Live_Backend_Rules_Parity_Hardened_Hybrid_v7_2_'
        'COMPLETE_WITH_FINDINGS_20260628_214116.zip',
      );
      expect(
        parityEvidence['sha256'],
        '035EF7B582EE6EAF99C64DC74D7C414FDA4ACA25A986A8E6F6189DE5C506B700',
      );

      final mergeEvidence = evidenceChain
          .whereType<Map<String, dynamic>>()
          .singleWhere(
            (entry) =>
                entry['role'] == 'STAGE2B_V2_MERGE_AND_POSTMERGE_CI_CUSTODY',
          );
      expect(
        mergeEvidence['sha256'],
        '096AED1DA366E3698008C579DE6B3875039DE76A95D8D97360AE6D583B12C529',
      );
    });

    test('production builder is CI-only and has no quality-gate bypass', () {
      final text = read('tools/release/New-ProductionArtifact.ps1');

      expect(text, contains("\$env:GITHUB_ACTIONS -ne 'true'"));
      expect(text, contains('GITHUB_WORKFLOW_REF'));
      expect(text, contains("GITHUB_REF -ne 'refs/heads/main'"));
      expect(text, contains('SOURCE_ARCHIVE_SHA256'));
      expect(text, contains('actor = [string]\$env:GITHUB_ACTOR'));
      expect(text, contains('actorId = [string]\$env:GITHUB_ACTOR_ID'));
      expect(
        text,
        contains('triggeringActor = [string]\$env:GITHUB_TRIGGERING_ACTOR'),
      );
      expect(text, contains('Remote reservation tag is absent'));
      expect(text, contains('temporary AAB verification truststore'));
      expect(text, contains('jarsigner'));
      expect(text, contains('exactly one unique signer certificate'));
      expect(text, contains('independently approved authority'));
      expect(text, contains('Test-BackendAuthority.ps1'));
      expect(text, contains('authority.firestore'));
      expect(text, contains('authority.sourceCustody'));
      expect(
        text,
        isNot(contains('manifest.backend.deployedIndexesParityStatus')),
      );
      expect(
        text,
        isNot(contains('manifest.backend.deployedIndexesParityEvidence')),
      );
      expect(text, isNot(contains('authority.deployedIndexesParityStatus')));
      expect(text, isNot(contains('authority.backendGitCommit')));
      expect(text, isNot(contains('SkipQualityGates')));
      expect(text, isNot(contains("CiRunId = 'local'")));
    });

    test('independent verifier reproduces signer and source custody', () {
      final text = read('tools/release/Test-ProductionReleaseManifest.ps1');

      expect(text, contains('schemaVersion -ne 6'));
      expect(text, contains('certificateDerFile'));
      expect(text, contains('sourceArchiveEntrySha256'));
      expect(text, contains('reservationTagMessageSha256'));
      expect(text, contains('firebaseToolsLockfileSha256'));
      expect(text, contains('linuxIsarCoreSha256'));
      expect(text, contains("'crm3-aab-trust-'"));
      expect(text, contains('RandomNumberGenerator]::GetBytes(24)'));
      expect(text, contains(r'Remove-Item -LiteralPath $trustStore'));
      expect(text, contains('sourceArchiveSha256'));
      expect(text, contains('exactly one unique signer certificate'));
      expect(text, contains('backupProofSha256'));
      expect(text, contains('recoveryProofSha256'));
      expect(text, contains('COMPOSITE_LIVE_STATE'));
      expect(text, contains('firestore.indexes.sourceSha256'));
      expect(text, contains('Get-LedgerReservationMatches'));
      expect(text, contains('LedgerSelectionSelfTest'));
      expect(text, contains(r'[string]$_.reservationId -eq $ReservationId'));
      expect(text, isNot(contains('Where-Object reservationId -eq')));
      expect(
        text,
        isNot(contains('manifest.backend.deployedIndexesParityStatus')),
      );
      expect(
        text,
        isNot(contains('manifest.backend.deployedIndexesParityEvidence')),
      );
      expect(text, isNot(contains('authority.deployedIndexesParityStatus')));
    });

    test('policy remains non-distributable and binds remote issuance', () {
      final text = read('tools/release/Test-ProductionReleasePolicy.ps1');

      expect(text, contains("schemaVersion -ne 3"));
      expect(text, contains('remoteReservationTag'));
      expect(text, contains('remoteBuiltTag'));
      expect(text, contains('failedOrWithdrawnBuildConsumesNumber'));
      expect(text, contains('production-signed-pre-release-candidate'));
      expect(text, contains('operationalCutoverBoundary'));
      expect(text, contains('backupProofSha256'));
      expect(text, contains('recoveryProofSha256'));
      expect(text, contains('bundletoolUrl must use HTTPS'));
      expect(text, contains('unrestrictedPlantReleaseApproved'));
      expect(text, contains('-LedgerSelectionSelfTest'));
      expect(
        text,
        contains('Production release manifest runtime self-test failed.'),
      );
    });

    test('release gate executes production package verifier runtime proof', () {
      final text = read('.github/workflows/release-gate.yml');

      expect(
        text,
        contains('Production policy and package-verifier runtime gate'),
      );
      expect(text, contains('Test-ProductionReleasePolicy.ps1'));
      expect(
        text,
        contains(
          'name: Checkout\n'
          '        uses: actions/checkout@'
          '34e114876b0b11c390a56381ad16ebd13914f8d5\n'
          '        with:\n'
          '          fetch-depth: 0',
        ),
      );
    });

    test('workflow atomically reserves number and pins release toolchain', () {
      final text = read('.github/workflows/production-artifact.yml');
      final policyVerifier = read(
        'tools/release/Test-ProductionReleasePolicy.ps1',
      );

      expect(text, contains('crm3-production-build-number-'));
      expect(text, contains('contents: write'));
      expect(text, contains('refs/tags/'));
      expect(text, contains('This number is consumed even if the build fails'));
      expect(text, contains("test \"\$GITHUB_REF\" = 'refs/heads/main'"));
      expect(text, contains('tooling/firebase-cli/package-lock.json'));
      expect(text, contains('CRM_EXPECTED_ISAR_CORE_SHA256'));
      expect(
        text,
        contains(
          r'CRM_DISPATCH_APPROVAL_REFERENCE: '
          r'${{ inputs.approval_reference }}',
        ),
      );
      expect(text, contains(r'CRM_DISPATCH_ACTOR: ${{ github.actor }}'));
      expect(text, contains(r'CRM_DISPATCH_ACTOR_ID: ${{ github.actor_id }}'));
      expect(
        text,
        contains(r'CRM_TRIGGERING_ACTOR: ${{ github.triggering_actor }}'),
      );
      expect(
        text,
        contains('Environment-review exception requires a private repository.'),
      );
      expect(
        text,
        contains(
          'A required-reviewer rule now exists; exception mode is invalid.',
        ),
      );
      expect(
        text,
        contains(
          'Workflow dispatcher identity differs from approved authority.',
        ),
      );
      expect(text, contains('Isar native-core load probe: PASS'));
      expect(text, contains('crm3-isar-approved-matches.txt'));
      expect(text, contains('Upload governed package and mandatory sidecar'));
      expect(text, contains('/*-GOVERNED-PACKAGE.zip'));
      expect(text, contains('/*-GOVERNED-PACKAGE.zip.sha256.txt'));
      expect(
        text,
        contains('Pre-reservation production policy verification failed.'),
      );
      expect(
        text.indexOf('Test-ProductionReleasePolicy.ps1'),
        lessThan(text.indexOf('- name: Atomically consume the build number')),
      );
      expect(
        text,
        contains('Prove Android dependency configuration before reservation'),
      );
      expect(text, contains('crm3-android-preflight-placeholder.p12'));
      expect(
        text,
        contains(
          './gradlew :app:assembleRelease --dry-run --no-daemon --stacktrace',
        ),
      );
      expect(
        text,
        contains(
          './gradlew :app:compileReleaseSources --no-daemon --stacktrace',
        ),
      );
      expect(
        text.indexOf('- name: Restore locked dependencies and Firebase CLI'),
        lessThan(
          text.indexOf(
            '- name: Prove Android dependency configuration before reservation',
          ),
        ),
      );
      expect(
        text.indexOf(
          '- name: Prove Android dependency configuration before reservation',
        ),
        lessThan(
          text.indexOf(
            '- name: Prove production environment secrets before reservation',
          ),
        ),
      );
      expect(
        text.indexOf(
          '- name: Prove production environment secrets before reservation',
        ),
        lessThan(text.indexOf('- name: Atomically consume the build number')),
      );
      expect(
        text.indexOf('- name: Atomically consume the build number'),
        lessThan(text.indexOf('- name: Build once and independently verify')),
      );
      expect(
        text,
        contains(r'CRM_DISPATCH_COMMIT_SHA: ${{ inputs.commit_sha }}'),
      );
      expect(
        text,
        contains(
          r'[[ "$CRM_DISPATCH_RELEASE_ID" =~ '
          r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]',
        ),
      );
      expect(
        text,
        contains(
          r'[[ "$CRM_DISPATCH_RESERVATION_ID" =~ '
          r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]',
        ),
      );
      expect(
        text,
        contains(r'test "$GITHUB_SHA" = "$CRM_DISPATCH_COMMIT_SHA"'),
      );
      expect(
        text,
        contains(
          r'-ExpectedApprovalReference '
          r'$env:CRM_DISPATCH_APPROVAL_REFERENCE',
        ),
      );
      expect(policyVerifier, contains('Get-YamlRunBlocks'));
      expect(policyVerifier, contains(r'(?:inputs|github\.event\.inputs)'));
      expect(text, isNot(contains(r'path: ${{env.CRM_PRODUCTION_OUTPUT}}/')));
      expect(text, isNot(matches(RegExp(r'uses:\s+[^\s]+@v\d'))));
    });

    test('release signing fails closed and never falls back to debug', () {
      final text = read('android/app/build.gradle.kts');

      expect(text, contains('create("production")'));
      expect(text, contains('CRM_ANDROID_RELEASE_STORE_FILE'));
      expect(text, contains('CRM_ANDROID_RELEASE_STORE_PASSWORD'));
      expect(text, contains('CRM_ANDROID_RELEASE_KEY_ALIAS'));
      expect(text, contains('CRM_ANDROID_RELEASE_KEY_PASSWORD'));
      expect(text, contains('signingConfigs.getByName("production")'));
      expect(text, contains('compileSdk = 36'));
      expect(text, contains('isDebuggable = false'));
      expect(text, isNot(contains('signingConfigs.getByName("debug")')));
    });

    test('locked legacy Isar library receives only its approved namespace', () {
      final rootGradle = read('android/build.gradle.kts');
      final lock = read('pubspec.lock');

      expect(rootGradle, contains('name == "isar_flutter_libs"'));
      expect(
        rootGradle,
        contains('pluginManager.withPlugin("com.android.library")'),
      );
      expect(
        rootGradle,
        contains(
          'extensions.configure<com.android.build.api.variant.'
          'LibraryAndroidComponentsExtension>',
        ),
      );
      expect(rootGradle, contains('finalizeDsl { libraryExtension ->'));
      expect(rootGradle, contains('if (libraryExtension.namespace == null)'));
      expect(
        rootGradle,
        contains('libraryExtension.namespace = "dev.isar.isar_flutter_libs"'),
      );
      expect(rootGradle, contains('libraryExtension.compileSdk = 36'));
      expect(
        lock,
        contains(RegExp(r'isar_flutter_libs:[\s\S]*?version: "3\.1\.0\+1"')),
      );
    });

    test('builds 1 to 6 are preserved and build 7 is finalized', () {
      final ledger =
          jsonDecode(read('release/build-number-ledger.json'))
              as Map<String, dynamic>;
      final entries =
          (ledger['entries'] as List<dynamic>).cast<Map<String, dynamic>>();
      final build1 = entries.singleWhere((entry) => entry['buildNumber'] == 1);
      final build2 = entries.singleWhere((entry) => entry['buildNumber'] == 2);
      final build3 = entries.singleWhere((entry) => entry['buildNumber'] == 3);
      final build4 = entries.singleWhere((entry) => entry['buildNumber'] == 4);
      final build5 = entries.singleWhere((entry) => entry['buildNumber'] == 5);
      final build6 = entries.singleWhere((entry) => entry['buildNumber'] == 6);
      final build7 = entries.singleWhere((entry) => entry['buildNumber'] == 7);

      expect(build1['status'], 'remote-consumed-build-failed');
      expect(build1['githubRunId'], 30387521656);
      expect(build1['artifactConstructed'], isFalse);
      expect(build1['artifactUploaded'], isFalse);
      expect(build1['remoteBuiltTagCreated'], isFalse);
      expect(build1['failedOrWithdrawnBuildConsumesNumber'], isTrue);

      expect(build2['status'], 'remote-consumed-build-failed');
      expect(build2['githubRunId'], 30392976122);
      expect(
        build2['remoteReservationTagObject'],
        '47e2063c3826c1c7ba4192b1796a745800a8815a',
      );
      expect(
        build2['remoteReservationCommit'],
        '4d5ea36327c3e7bc9d4ad162de362a3f94528610',
      );
      expect(build2['productionKeystoreRestored'], isTrue);
      expect(build2['artifactConstructed'], isFalse);
      expect(build2['artifactUploaded'], isFalse);
      expect(build2['remoteBuiltTagCreated'], isFalse);

      expect(build3['status'], 'remote-consumed-build-failed');
      expect(build3['githubRunId'], 30397899144);
      expect(build3['remoteReservationTag'], 'crm3-build-reserved/3');
      expect(build3['remoteBuiltTag'], 'crm3-build-built/3');
      expect(
        build3['remoteReservationTagObject'],
        '43b6bc2da1beb7f90bc8f3bc82ebc961a5fc48d6',
      );
      expect(
        build3['remoteReservationCommit'],
        'a808376dbc4d2e4b198127e2d66fc698daac800e',
      );
      expect(build3['productionKeystoreRestored'], isTrue);
      expect(build3['signedApkConstructed'], isTrue);
      expect(build3['signedAabConstructed'], isTrue);
      expect(build3['independentPackageVerificationCompleted'], isFalse);
      expect(build3['artifactConstructed'], isFalse);
      expect(build3['artifactUploaded'], isFalse);
      expect(build3['remoteBuiltTagCreated'], isFalse);

      expect(
        build4['status'],
        'remote-consumed-artifact-built-finalization-blocked',
      );
      expect(build4['remoteReservationTag'], 'crm3-build-reserved/4');
      expect(build4['remoteBuiltTag'], 'crm3-build-built/4');
      expect(build4['githubRunId'], 30418210455);
      expect(build4['conclusion'], 'success');
      expect(build4['independentPackageVerificationCompleted'], isTrue);
      expect(build4['artifactConstructed'], isTrue);
      expect(build4['artifactUploaded'], isTrue);
      expect(build4['closureFinalizationCompleted'], isFalse);
      expect(build4['dualCustodyCompleted'], isFalse);
      expect(build4['remoteBuiltTagCreated'], isFalse);

      expect(
        build5['status'],
        'remote-consumed-artifact-built-finalized-non-distributable',
      );
      expect(build5['remoteReservationTag'], 'crm3-build-reserved/5');
      expect(build5['remoteBuiltTag'], 'crm3-build-built/5');
      expect(build5['versionApprovalReference'], 'BAF-REF-003-C4');
      expect(build5['githubRunId'], 30466468245);
      expect(
        build5['governedPackageSha256'],
        'E702A72A6603B6187E9282FC12E1E633F9BF59057ED331464BE590579FFB29C1',
      );
      expect(build5['closureFinalizationCompleted'], isTrue);
      expect(build5['dualCustodyCompleted'], isTrue);
      expect(build5['remoteBuiltTagCreated'], isTrue);
      expect(build5['remoteTagPushRecoveryRequired'], isTrue);
      expect(build5['remoteTagPushRecoveryForceUsed'], isFalse);
      expect(build5['firebaseBackendDeploymentPerformed'], isFalse);
      expect(build5['controlledPilotApproved'], isFalse);
      expect(build5['unrestrictedPlantReleaseApproved'], isFalse);
      expect(build5['distributionPerformed'], isFalse);

      final approval =
          jsonDecode(
                read(
                  'release/approvals/'
                  'build-number-7-rollover-approval.json',
                ),
              )
              as Map<String, dynamic>;
      expect(approval['approved'], isTrue);
      expect(approval['distributionApproved'], isFalse);
      expect(
        (approval['consumedBuild'] as Map<String, dynamic>)['githubRunId'],
        30572342725,
      );
      expect(
        (approval['consumedBuild']
            as Map<String, dynamic>)['signedApkConstructed'],
        isTrue,
      );
      expect(
        (approval['consumedBuild']
            as Map<String, dynamic>)['signedAabConstructed'],
        isTrue,
      );
      expect(
        (approval['consumedBuild']
            as Map<String, dynamic>)['artifactConstructed'],
        isTrue,
      );
      expect(
        (approval['consumedBuild']
            as Map<String, dynamic>)['closureFinalizationCompleted'],
        isTrue,
      );
      expect(
        (approval['consumedBuild']
            as Map<String, dynamic>)['dualCustodyCompleted'],
        isTrue,
      );
      expect(
        (approval['consumedBuild']
            as Map<String, dynamic>)['distributionPerformed'],
        isFalse,
      );
      expect((approval['nextBuild'] as Map<String, dynamic>)['buildNumber'], 7);
      expect(
        (approval['requiredSource']
            as Map<String, dynamic>)['firestoreValueNormalizationPullRequest'],
        111,
      );
      expect(
        (approval['requiredSource']
            as Map<String, dynamic>)['firestoreValueNormalizationMergeCommit'],
        '53b10006bc8e34240e2ec94b861ef907311071c0',
      );
      expect(
        (approval['controls']
            as Map<
              String,
              dynamic
            >)['manifestVerifierRuntimeSelfTestBeforeReservation'],
        isTrue,
      );
      expect(
        (approval['controls']
            as Map<
              String,
              dynamic
            >)['androidReleaseSourceCompilationBeforeReservation'],
        isTrue,
      );
      expect(
        (approval['controls']
            as Map<
              String,
              dynamic
            >)['privateRepositoryEnvironmentReviewerExceptionApproved'],
        isTrue,
      );

      expect(
        build6['status'],
        'remote-consumed-artifact-built-finalized-non-distributable',
      );
      expect(build6['remoteReservationTag'], 'crm3-build-reserved/6');
      expect(build6['remoteBuiltTag'], 'crm3-build-built/6');
      expect(build6['versionApprovalReference'], 'BAF-REF-003-C5');
      expect(build6['githubRunId'], 30572342725);
      expect(
        build6['remoteReservationTagObject'],
        '9c82843b84194c9eeef9a4d7ec7b81d1d0c8caa7',
      );
      expect(
        build6['remoteBuiltTagObject'],
        '189f668f8f59f934b1baec0b9bdf723dc7960b6c',
      );
      final preReservationFailures =
          build6['preReservationDispatchFailures'] as List<dynamic>;
      expect(preReservationFailures, hasLength(1));
      final preReservationFailure =
          preReservationFailures.single as Map<String, dynamic>;
      expect(preReservationFailure['githubRunId'], 30531942779);
      expect(
        preReservationFailure['failureBoundary'],
        'java-distribution-resolution-before-secret-preflight-and-reservation',
      );
      expect(
        preReservationFailure['productionEnvironmentSecretsProved'],
        isFalse,
      );
      expect(preReservationFailure['productionKeystoreRestored'], isFalse);
      expect(preReservationFailure['remoteReservationTagCreated'], isFalse);
      expect(preReservationFailure['artifactConstructed'], isFalse);
      expect(preReservationFailure['numberConsumed'], isFalse);
      expect(
        build6['governedPackageSha256'],
        'E36C39E40C4B92B0721DAD916F050F439644FDF7FC40A36C1EB579571EBD074E',
      );
      expect(build6['closureFinalizationCompleted'], isTrue);
      expect(build6['dualCustodyCompleted'], isTrue);
      expect(build6['remoteBuiltTagCreated'], isTrue);
      expect(build6['finalizationRetryRequired'], isTrue);
      expect(build6['finalizationReusedSameGithubRun'], isTrue);
      expect(build6['finalizationReusedSameArtifactName'], isTrue);
      expect(build6['remoteTagPushRecoveryRequired'], isFalse);
      expect(build6['remoteTagPushRecoveryForceUsed'], isFalse);
      expect(build6['firebaseBackendDeploymentPerformed'], isFalse);
      expect(build6['controlledPilotApproved'], isFalse);
      expect(build6['unrestrictedPlantReleaseApproved'], isFalse);
      expect(build6['distributionPerformed'], isFalse);

      expect(
        build7['status'],
        'remote-consumed-artifact-built-finalized-non-distributable',
      );
      expect(build7['remoteReservationTag'], 'crm3-build-reserved/7');
      expect(build7['remoteBuiltTag'], 'crm3-build-built/7');
      expect(build7['versionApprovalReference'], 'BAF-REF-003-C6');
      expect(build7['githubRunId'], 30757692948);
      expect(
        build7['remoteReservationTagObject'],
        '5e351f0b5acf1f887e14c5ad70c60864a5d6c470',
      );
      expect(
        build7['remoteBuiltTagObject'],
        'b06edcbcd4fdb2d27fc4b844dd16f54340aa0c3d',
      );
      expect(
        build7['governedPackageSha256'],
        'D6E2710481681F63651B13A9C5872B16BDADE90EB288E610DD59BE1B9B07ACE7',
      );
      expect(build7['closureFinalizationCompleted'], isTrue);
      expect(build7['dualCustodyCompleted'], isTrue);
      expect(build7['remoteBuiltTagCreated'], isTrue);
      expect(build7['localFinalizerPreflightIncidentCount'], 2);
      expect(build7['localFinalizerPreflightIncidentsRecorded'], isTrue);
      expect(build7['finalizationRetryRequired'], isTrue);
      expect(build7['finalizationReusedSameGithubRun'], isTrue);
      expect(build7['finalizationReusedSameArtifactName'], isTrue);
      expect(build7['remoteTagPushRecoveryRequired'], isFalse);
      expect(build7['remoteTagPushRecoveryForceUsed'], isFalse);
      expect(build7['firebaseBackendDeploymentPerformed'], isFalse);
      expect(build7['controlledPilotApproved'], isFalse);
      expect(build7['unrestrictedPlantReleaseApproved'], isFalse);
      expect(build7['distributionPerformed'], isFalse);
    });

    test('private-repository reviewer exception is narrow and fail-closed', () {
      final policy =
          jsonDecode(read('release/production-release-policy.json'))
              as Map<String, dynamic>;
      final github = policy['github'] as Map<String, dynamic>;
      final control =
          github['environmentReviewControl'] as Map<String, dynamic>;
      final exception =
          jsonDecode(
                read(
                  'release/approvals/'
                  'private-repository-environment-reviewer-exception-build-7.json',
                ),
              )
              as Map<String, dynamic>;
      final scope = exception['scope'] as Map<String, dynamic>;
      final compensatingControls =
          exception['compensatingControls'] as Map<String, dynamic>;
      final liveStateEvidence =
          exception['liveStateEvidence'] as Map<String, dynamic>;
      final authorizedDispatcher =
          liveStateEvidence['authorizedDispatcher'] as Map<String, dynamic>;
      final finalizer = read('tools/release/Finalize-ProductionRelease.ps1');

      expect(control['mode'], 'private-repository-plan-exception');
      expect(control['requiredReviewerAvailable'], isFalse);
      expect(control['manualDispatchApprovalReferenceRequired'], isTrue);
      expect(control['failClosedIfRequiredReviewerRuleAppears'], isTrue);
      expect(exception['approved'], isTrue);
      expect(scope['repositoryVisibility'], 'private');
      expect(scope['buildNumber'], 7);
      expect(scope['versionApprovalReference'], 'BAF-REF-003-C6');
      expect(scope['singleBuildOnly'], isTrue);
      expect(authorizedDispatcher['login'], 'abhishekvatsa');
      expect(authorizedDispatcher['id'], 213690022);
      expect(
        compensatingControls['authorizedDispatcherIdentityRequired'],
        isTrue,
      );
      expect(compensatingControls['distributionApproved'], isFalse);
      expect(compensatingControls['firebaseDeploymentApproved'], isFalse);
      expect(
        finalizer,
        contains(
          'Live GitHub state does not satisfy the private-repository '
          'plan exception.',
        ),
      );
      expect(finalizer, contains('github-environment-secrets.json'));
      expect(finalizer, contains('Authorized dispatcher ID:'));
      expect(finalizer, contains(r'environmentSecretValuesInspected = $false'));
      expect(finalizer, contains(r'$prCommits.Count -lt 1'));
      expect(
        finalizer,
        contains(
          r'git push origin "refs/tags/${builtTag}:refs/tags/${builtTag}"',
        ),
      );
      expect(
        finalizer,
        isNot(
          contains(
            r'git push origin "refs/tags/$builtTag:refs/tags/$builtTag"',
          ),
        ),
      );
      expect(finalizer, isNot(contains('expectedCommitHeadlines')));
      expect(
        finalizer,
        contains(r'$currentBranchOutput = @(git branch --show-current)'),
      );
      expect(
        finalizer,
        contains(r'$currentBranch = ($currentBranchOutput -join "`n").Trim()'),
      );
      final policyVerifier = read(
        'tools/release/Test-ProductionReleasePolicy.ps1',
      );
      expect(
        policyVerifier,
        contains(r'$recoveryIncident.occurred -eq $false'),
      );
      expect(policyVerifier, contains("'pending-source-authorized'"));
      expect(
        policyVerifier,
        contains('firestoreValueNormalizationRemediationRequired'),
      );
      expect(
        policyVerifier,
        contains('firestoreValueNormalizationMergeCommit'),
      );
      expect(
        policyVerifier,
        contains(
          'Dispatch source does not contain the Firestore '
          'value-normalization remediation.',
        ),
      );
    });

    test('build 7 closure is exact and remains non-distributable', () {
      final policy =
          jsonDecode(read('release/production-release-policy.json'))
              as Map<String, dynamic>;
      final finalization = policy['finalization'] as Map<String, dynamic>;
      final receipt =
          jsonDecode(read(finalization['completionReceiptFile'] as String))
              as Map<String, dynamic>;
      final sourceAuthority =
          receipt['sourceAuthority'] as Map<String, dynamic>;
      final workflow = receipt['workflow'] as Map<String, dynamic>;
      final governedPackage =
          receipt['governedPackage'] as Map<String, dynamic>;
      final remoteAuthority =
          receipt['remoteAuthority'] as Map<String, dynamic>;
      final dualCustody = receipt['dualCustody'] as Map<String, dynamic>;
      final closure = receipt['closure'] as Map<String, dynamic>;
      final localPreflight =
          receipt['localPreflightIncidents'] as Map<String, dynamic>;
      final finalizationRetry =
          receipt['finalizationRetryIncident'] as Map<String, dynamic>;
      final tagRecovery = receipt['recoveryIncident'] as Map<String, dynamic>;
      final releaseBoundary =
          receipt['releaseBoundary'] as Map<String, dynamic>;

      expect(finalization['status'], 'completed-non-distributable');
      expect(finalization['dualCustodyCompleted'], isTrue);
      expect(
        finalization['completionReceiptSha256'],
        'F9788C0DD9BB7DB0B21A43FF461D68CEBC85A2135E16DA68E1ABA8342B1B1337',
      );
      expect(receipt['schemaVersion'], 1);
      expect(receipt['status'], 'passed-non-distributable');
      expect(
        sourceAuthority['commit'],
        'd8619ef1a9c7bf53828523c4bca3efe33e4074f0',
      );
      expect(sourceAuthority['pullRequestNumber'], 112);
      expect(workflow['runId'], 30757692948);
      expect(workflow['actor'], 'abhishekvatsa');
      expect(workflow['actorId'], 213690022);
      expect(workflow['secretValuesInspected'], isFalse);
      expect(
        governedPackage['sha256'],
        'D6E2710481681F63651B13A9C5872B16BDADE90EB288E610DD59BE1B9B07ACE7',
      );
      expect(governedPackage['independentVerificationCompleted'], isTrue);
      expect(
        remoteAuthority['builtTagObjectSha'],
        'b06edcbcd4fdb2d27fc4b844dd16f54340aa0c3d',
      );
      expect(dualCustody['distinctVolumes'], isTrue);
      expect(dualCustody['filesVerifiedInBothLocations'], 6);
      expect(dualCustody['allFileHashesMatched'], isTrue);
      expect(
        closure['closurePackageSha256'],
        'C15D8655E2F27D0F87BAFEC97A32208926BD62130E268E13945E6C32F2FDD876',
      );
      expect(localPreflight['occurred'], isTrue);
      final incidents = localPreflight['incidents'] as List<dynamic>;
      expect(incidents, hasLength(2));
      expect(
        (incidents[1] as Map<String, dynamic>)['failureBoundary'],
        'detached-head-branch-preflight-before-fetch',
      );
      expect(localPreflight['buildWorkflowRerunPerformed'], isFalse);
      expect(localPreflight['rebuildPerformed'], isFalse);
      expect(finalizationRetry['occurred'], isTrue);
      expect(
        finalizationRetry['failureBoundary'],
        'github-artifact-download-before-custody-and-built-tag',
      );
      expect(
        (finalizationRetry['retry']
            as Map<String, dynamic>)['sameGithubRunReused'],
        isTrue,
      );
      expect(tagRecovery['occurred'], isFalse);
      expect(tagRecovery['forceUsed'], isFalse);
      expect(releaseBoundary['firebaseBackendDeploymentPerformed'], isFalse);
      expect(releaseBoundary['controlledPilotApproved'], isFalse);
      expect(releaseBoundary['unrestrictedPlantReleaseApproved'], isFalse);
      expect(releaseBoundary['distributionPerformed'], isFalse);
    });

    test('permanent identity and public version are committed', () {
      final gradle = read('android/app/build.gradle.kts');
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      final pubspec = read('pubspec.yaml');
      final policy = read('release/production-release-policy.json');

      expect(gradle, isNot(contains('com.example.crm3_baf_ops')));
      expect(manifest, isNot(contains('android:label="crm3_baf_ops"')));
      expect(
        pubspec,
        contains(RegExp(r'^version:\s+1\.0\.0-rc\.1\+7$', multiLine: true)),
      );
      expect(policy, contains('"releaseId": "crm3-baf-ops-1.0.0-rc.1-b7"'));
      expect(
        policy,
        contains('"remoteReservationTag": "crm3-build-reserved/7"'),
      );
      expect(policy, contains('"approved": false'));
      expect(policy, contains('"unrestrictedPlantReleaseApproved": false'));
      expect(
        policy,
        contains('"restorationReference": "CRM3-FB-RESTORE-001-C1"'),
      );
      expect(
        policy,
        contains(
          '"googleServicesSha256": "2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B"',
        ),
      );
      expect(
        policy,
        contains(
          '"googleServicesSha256Representation": "UTF8_CRLF_RESTORATION_ARTIFACT"',
        ),
      );
      expect(
        policy,
        contains(
          '"repositoryGoogleServicesSha256": "6CBC8F2E9D021999433636E9AD517EEC461C9811A19DC7DAA28EEE7C28D750C7"',
        ),
      );
      expect(
        policy,
        contains(
          '"repositoryGoogleServicesSha256Representation": "UTF8_LF_GIT_BLOB"',
        ),
      );
      expect(
        policy,
        contains(
          '"restorationReceiptSha256": "FAD4C1516BD681E7A6756282B241B52AE54FC1AB9290AA15DC27719925EFBF3B"',
        ),
      );
      expect(
        policy,
        contains(
          '"repositoryRestorationReceiptSha256": "CCE70C3FC7E541C72E29F6732502BDF313633B3AF4A49F1923DD2D440AFBEA13"',
        ),
      );
      expect(
        read('tools/release/Test-ProductionReleasePolicy.ps1'),
        contains('repositoryGoogleServicesSha256'),
      );
      expect(
        read('tools/release/Test-ProductionReleasePolicy.ps1'),
        contains('repositoryRestorationReceiptSha256'),
      );
      expect(
        read('tools/release/Test-ProductionReleasePolicy.ps1'),
        contains('Get-Utf8CrlfSha256'),
      );
      expect(
        read('tools/release/New-ProductionArtifact.ps1'),
        contains('firebase-production-signing-restoration-receipt.json'),
      );
    });
  });
}
