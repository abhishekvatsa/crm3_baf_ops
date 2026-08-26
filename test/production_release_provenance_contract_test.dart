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
      expect(text, contains('artifactConstructionBoundary'));
      expect(text, contains('production-signed-pre-release-candidate'));
      expect(text, contains('postBuildPromotionRequiredForAnyDistribution'));
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
      expect(text, contains('artifactConstructionBoundary'));
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

    test('policy binds remote issuance and exact sealed-pilot promotion', () {
      final text = read('tools/release/Test-ProductionReleasePolicy.ps1');

      expect(text, contains("schemaVersion -ne 3"));
      expect(text, contains('remoteReservationTag'));
      expect(text, contains('remoteBuiltTag'));
      expect(text, contains('failedOrWithdrawnBuildConsumesNumber'));
      expect(text, contains('exact-build11-sealed-small-group-pilot'));
      expect(text, contains('completed-controlled-pilot-only'));
      expect(text, contains('promotionReceiptSha256'));
      expect(text, contains('operationalCutoverBoundary'));
      expect(text, contains('backupProofSha256'));
      expect(text, contains('recoveryProofSha256'));
      expect(text, contains('bundletoolUrl must use HTTPS'));
      expect(text, contains('unrestrictedPlantReleaseApproved'));
      expect(text, contains('-LedgerSelectionSelfTest'));
      expect(text, contains('exactFunctionFleetDeploymentPullRequest'));
      expect(text, contains('exactFirestoreRulesSha256'));
      expect(text, contains('exactFirestoreIndexCount'));
      expect(text, contains('exactFirestoreIndexSetSha256'));
      expect(text, contains('--source-index-set firestore.indexes.json'));
      expect(text, contains('release/current-successor-state.json'));
      expect(text, contains('firestoreRulesAndIndexes'));
      expect(
        text,
        contains(
          'SOURCE_RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT',
        ),
      );
      expect(
        text,
        contains(
          'Exact finalized Firestore Rules/index readback differs from approval.',
        ),
      );
      expect(
        text,
        contains(
          'Current source Firestore Rules/index authority differs from source state.',
        ),
      );
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
          '3d3c42e5aac5ba805825da76410c181273ba90b1\n'
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
      expect(text, contains('artifactConstructionBoundary'));
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
        contains(
          'Required-reviewer mode requires the approved public repository.',
        ),
      );
      expect(
        text,
        contains(
          'Exact run lacks approval by the governed environment reviewer.',
        ),
      );
      expect(text, contains('deployment-branch-policies'));
      expect(text, contains(r'actions/runs/'));
      expect(text, contains(r'/approvals'));
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
      expect(text, contains('Invoke-CIAndroidPackageProof.ps1'));
      expect(text, contains("-BuildName '0.0.0-production-preflight'"));
      expect(text, contains('-BuildNumber 1'));
      expect(text, contains('Secret-isolated Android package proof failed.'));
      expect(text, contains('Secret-isolated preflight output remains:'));
      final preflightStart = text.indexOf(
        '- name: Prove Android dependency configuration before reservation',
      );
      final secretPreflightStart = text.indexOf(
        '- name: Prove production environment secrets before reservation',
      );
      final preflightSection = text.substring(
        preflightStart,
        secretPreflightStart,
      );
      expect(preflightSection, isNot(contains(r'${{ secrets.')));
      expect(
        preflightSection,
        isNot(contains('CRM_ANDROID_RELEASE_KEYSTORE_BASE64')),
      );
      expect(
        preflightSection.indexOf('Invoke-CIAndroidPackageProof.ps1'),
        lessThan(
          preflightSection.indexOf(
            'Secret-isolated Android package proof failed.',
          ),
        ),
      );
      expect(
        preflightSection.indexOf(
          'Secret-isolated Android package proof failed.',
        ),
        lessThan(preflightSection.indexOf('flutter clean')),
      );
      expect(
        preflightSection.indexOf('flutter clean'),
        lessThan(preflightSection.indexOf('flutter pub get')),
      );
      expect(
        preflightSection,
        contains('build/app/outputs/flutter-apk/app-release.apk'),
      );
      expect(
        preflightSection,
        contains('build/app/outputs/bundle/release/app-release.aab'),
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

    test('builds 1 to 11 are preserved and build 12 is finalized', () {
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
      final build8 = entries.singleWhere((entry) => entry['buildNumber'] == 8);
      final build9 = entries.singleWhere((entry) => entry['buildNumber'] == 9);
      final build10 = entries.singleWhere(
        (entry) => entry['buildNumber'] == 10,
      );
      final build11 = entries.singleWhere(
        (entry) => entry['buildNumber'] == 11,
      );
      final build12 = entries.singleWhere(
        (entry) => entry['buildNumber'] == 12,
      );

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

      expect(
        build8['status'],
        'remote-consumed-artifact-built-finalized-non-distributable',
      );
      expect(
        build8['baselineCommit'],
        '45ebd9c853798f88fedd2e4d72d6022dc389097f',
      );
      expect(build8['remoteReservationTag'], 'crm3-build-reserved/8');
      expect(build8['remoteBuiltTag'], 'crm3-build-built/8');
      expect(build8['versionApprovalReference'], 'BAF-REF-003-C7');
      expect(
        build8['versionApprovalDocumentSha256'],
        '5060D9CC53FB9F65CCA888F913A45A1C7D4B5629FF93350138DB8C4E605A7335',
      );
      expect(build8['githubRunId'], 30839125687);
      expect(
        build8['remoteReservationCommit'],
        '731a02980d38e4e3a8f61ff2bca74a1e85771478',
      );
      expect(
        build8['remoteBuiltCommit'],
        '731a02980d38e4e3a8f61ff2bca74a1e85771478',
      );
      expect(
        build8['remoteBuiltTagObject'],
        'f9f6f3fbacd33d824bf4b5213b0b28f6d7e29feb',
      );
      expect(
        build8['governedPackageSha256'],
        '75362F9875CC5067012B4A5768720CB4AE0AD2C6A94B38C1F174E0FD1E1CA91F',
      );
      expect(build8['closureFinalizationCompleted'], isTrue);
      expect(build8['dualCustodyCompleted'], isTrue);
      expect(build8['remoteBuiltTagCreated'], isTrue);
      expect(build8['remoteTagPushRecoveryRequired'], isFalse);
      expect(build8['firebaseBackendDeploymentPerformed'], isFalse);
      expect(build8['controlledPilotApproved'], isFalse);
      expect(build8['unrestrictedPlantReleaseApproved'], isFalse);
      expect(build8['distributionPerformed'], isFalse);

      expect(
        build9['status'],
        'remote-consumed-artifact-built-finalized-non-distributable',
      );
      expect(
        build9['baselineCommit'],
        '28cb22064511c1abcb76759cbb302a303427f46f',
      );
      expect(build9['remoteReservationTag'], 'crm3-build-reserved/9');
      expect(build9['remoteBuiltTag'], 'crm3-build-built/9');
      expect(build9['versionApprovalReference'], 'BAF-REF-003-C8');
      expect(
        build9['versionApprovalDocumentSha256'],
        '1AF2210730052C99F8AAA2A1A1D5E8C1D38646F0F7AF07A3444A0094778E3AE9',
      );
      expect(build9['githubRunId'], 31528293704);
      expect(
        build9['remoteReservationTagObject'],
        'feef8824b6d1587789c1f51dc4446b6a4d7c1221',
      );
      expect(
        build9['remoteBuiltTagObject'],
        'e478de7b186112b864199a5bf0184d3c3d9ea584',
      );
      expect(
        build9['governedPackageSha256'],
        '4D1EA1781FBAB0E047A1605644E329712E717B66A594147D55095DF21DF9960E',
      );
      expect(build9['closureFinalizationCompleted'], isTrue);
      expect(build9['dualCustodyCompleted'], isTrue);
      expect(build9['runtimeValidationPassed'], isFalse);
      expect(
        build9['runtimeFailure'],
        'missing-crashlytics-gradle-build-identifier',
      );
      expect(build9['startupRemediationPullRequest'], 197);
      expect(build9['distributionPerformed'], isFalse);

      expect(
        build10['status'],
        'remote-consumed-artifact-built-finalization-blocked-non-distributable',
      );
      expect(
        build10['baselineCommit'],
        '1772fe1cf34c649c6a29d375c77b75e985b6c2f0',
      );
      expect(build10['remoteReservationTag'], 'crm3-build-reserved/10');
      expect(build10['remoteBuiltTag'], 'crm3-build-built/10');
      expect(build10['versionApprovalReference'], 'BAF-REF-003-C9');
      expect(
        build10['versionApprovalDocumentSha256'],
        '5086CFB2CBAE2E8A178B565FA93D9F8D9030620BDE608EB93D85BB48ED8231B0',
      );
      expect(build10['githubRunId'], 31545500587);
      expect(
        build10['remoteReservationTagObject'],
        'fd74fb34eef59f9ad47dc6cef7b2cd2b8beba7b2',
      );
      expect(build10['independentPackageVerificationCompleted'], isTrue);
      expect(build10['closureFinalizationCompleted'], isFalse);
      expect(build10['dualCustodyCompleted'], isFalse);
      expect(build10['remoteBuiltTagCreated'], isFalse);
      expect(build10['distributionPerformed'], isFalse);

      expect(
        build11['status'],
        'remote-consumed-artifact-built-finalized-non-distributable',
      );
      expect(
        build11['baselineCommit'],
        'e6bfa327466ffa99da9519846db7f83401c86c7b',
      );
      expect(build11['remoteReservationTag'], 'crm3-build-reserved/11');
      expect(build11['remoteBuiltTag'], 'crm3-build-built/11');
      expect(build11['versionApprovalReference'], 'BAF-REF-003-C10');
      expect(
        build11['versionApprovalDocumentSha256'],
        '9AC12BEF69FB8DB48ED974F557CB25A93B35010487782DBBA627F34D2E397DEE',
      );
      expect(build11['githubRunId'], 31552161470);
      expect(build11['githubArtifactId'], 9125100777);
      expect(
        build11['remoteReservationTagObject'],
        '2c39c96650fbe3b7b7f0d4c95a63736e736fed67',
      );
      expect(
        build11['remoteBuiltTagObject'],
        'ed33b3f48d9bd10b23c88025eaa567ae235d970c',
      );
      expect(build11['closureFinalizationCompleted'], isTrue);
      expect(build11['dualCustodyCompleted'], isTrue);
      expect(build11['runtimeValidationPassed'], isTrue);
      expect(build11['runtimeDisposition'], 'passed-two-target-in-place');
      expect(build11['distributionPerformed'], isFalse);

      expect(
        build12['status'],
        'remote-consumed-artifact-built-finalized-non-distributable',
      );
      expect(build12['versionName'], '1.0.0-rc.2');
      expect(
        build12['baselineCommit'],
        'b020dc639cd0b69bf09808de9f6a750cde38259c',
      );
      expect(build12['remoteReservationTag'], 'crm3-build-reserved/12');
      expect(build12['remoteBuiltTag'], 'crm3-build-built/12');
      expect(build12['versionApprovalReference'], 'BAF-REF-003-C11');
      expect(build12['githubRunId'], 32088466492);
      expect(build12['githubArtifactId'], 9307950694);
      expect(
        build12['remoteReservationTagObject'],
        'db8e0c347ad7278ef1ac83d4880f29ae5832274a',
      );
      expect(
        build12['remoteBuiltTagObject'],
        'b705e33b68a1deaed0d2b71f88d024b8e8db1515',
      );
      expect(build12['closureFinalizationCompleted'], isTrue);
      expect(build12['dualCustodyCompleted'], isTrue);
      expect(build12['runtimeValidationPassed'], isTrue);
      expect(build12['fullBusinessFlowValidationCompleted'], isFalse);
      expect(build12['controlledPilotApproved'], isFalse);
      expect(build12['distributionPerformed'], isFalse);

      final build12Approval =
          jsonDecode(
                read(
                  'release/approvals/'
                  'build-number-12-successor-approval.json',
                ),
              )
              as Map<String, dynamic>;
      final build12Source =
          build12Approval['requiredSource'] as Map<String, dynamic>;
      final build12Controls =
          build12Approval['controls'] as Map<String, dynamic>;
      expect(build12Approval['approvalReference'], 'BAF-REF-003-C11');
      expect(build12Approval['distributionApproved'], isFalse);
      expect(
        (build12Approval['consumedBuild']
            as Map<String, dynamic>)['buildNumber'],
        11,
      );
      expect(
        (build12Approval['nextBuild'] as Map<String, dynamic>)['buildNumber'],
        12,
      );
      expect(
        build12Source['successorFreezeBaselineCommit'],
        'b020dc639cd0b69bf09808de9f6a750cde38259c',
      );
      expect(
        build12Source['successorFreezeBaselineTree'],
        'a65ff08db541bea2aa72c6930ead60b430028eea',
      );
      expect(build12Source['successorFreezePostMergeGithubRunId'], 32062710341);
      expect(build12Source['successorFreezeCanonicalAuditPassCount'], 144);
      expect(build12Controls['successorFreezeRequired'], isTrue);
      expect(build12Controls['build11AuthorityPreserved'], isTrue);
      expect(build12Controls['inPlaceUpgradeRequired'], isTrue);
      expect(build12Controls['deviceDataClearProhibited'], isTrue);
      expect(build12Controls['pilotDistributionAuthorized'], isFalse);

      final build11Approval =
          jsonDecode(
                read(
                  'release/approvals/'
                  'build-number-11-rollover-approval.json',
                ),
              )
              as Map<String, dynamic>;
      final build11Source =
          build11Approval['requiredSource'] as Map<String, dynamic>;
      final build11Controls =
          build11Approval['controls'] as Map<String, dynamic>;
      expect(build11Approval['approvalReference'], 'BAF-REF-003-C10');
      expect(build11Approval['distributionApproved'], isFalse);
      expect(
        (build11Approval['consumedBuild']
            as Map<String, dynamic>)['buildNumber'],
        10,
      );
      expect(
        (build11Approval['nextBuild'] as Map<String, dynamic>)['buildNumber'],
        11,
      );
      expect(build11Source['environmentAuthorityPullRequest'], 198);
      expect(
        build11Source['environmentAuthorityMergeCommit'],
        'e6bfa327466ffa99da9519846db7f83401c86c7b',
      );
      expect(build11Source['postMergeGithubRunId'], 31544517283);
      expect(build11Controls['environmentAuthorityRequired'], isTrue);
      expect(build11Controls['lr07Build10RearmRequired'], isTrue);
      expect(build11Controls['inPlaceUpgradeRequired'], isTrue);
      expect(build11Controls['deviceDataClearProhibited'], isTrue);

      final build10Approval =
          jsonDecode(
                read(
                  'release/approvals/'
                  'build-number-10-rollover-approval.json',
                ),
              )
              as Map<String, dynamic>;
      final build10Source =
          build10Approval['requiredSource'] as Map<String, dynamic>;
      final build10Controls =
          build10Approval['controls'] as Map<String, dynamic>;
      expect(build10Approval['approvalReference'], 'BAF-REF-003-C9');
      expect(build10Approval['distributionApproved'], isFalse);
      expect(
        (build10Approval['consumedBuild']
            as Map<String, dynamic>)['buildNumber'],
        9,
      );
      expect(
        (build10Approval['nextBuild'] as Map<String, dynamic>)['buildNumber'],
        10,
      );
      expect(build10Source['startupRemediationPullRequest'], 197);
      expect(
        build10Source['startupRemediationMergeCommit'],
        '1772fe1cf34c649c6a29d375c77b75e985b6c2f0',
      );
      expect(build10Source['postMergeGithubRunId'], 31538989781);
      expect(build10Controls['crashlyticsGradlePluginRequired'], isTrue);
      expect(build10Controls['compiledCrashlyticsMappingIdRequired'], isTrue);
      expect(build10Controls['exactReleaseApkColdStartCiRequired'], isTrue);
      expect(build10Controls['lr07Build9RearmRequired'], isTrue);
      expect(build10Controls['inPlaceUpgradeRequired'], isTrue);
      expect(build10Controls['deviceDataClearProhibited'], isTrue);

      final build9Approval =
          jsonDecode(
                read(
                  'release/approvals/'
                  'build-number-9-rollover-approval.json',
                ),
              )
              as Map<String, dynamic>;
      final build9Source =
          build9Approval['requiredSource'] as Map<String, dynamic>;
      final build9Controls = build9Approval['controls'] as Map<String, dynamic>;
      expect(build9Approval['approvalReference'], 'BAF-REF-003-C8');
      expect(build9Approval['distributionApproved'], isFalse);
      expect(
        (build9Approval['consumedBuild']
            as Map<String, dynamic>)['buildNumber'],
        8,
      );
      expect(
        (build9Approval['nextBuild'] as Map<String, dynamic>)['buildNumber'],
        9,
      );
      expect(build9Source['integratedSuccessorPullRequest'], 193);
      expect(
        build9Source['integratedSuccessorMergeCommit'],
        '28cb22064511c1abcb76759cbb302a303427f46f',
      );
      expect(build9Source['postMergeGithubRunId'], 31512254539);
      expect(build9Controls['recoverySourceRequired'], isTrue);
      expect(build9Controls['inPlaceUpgradeRequired'], isTrue);
      expect(build9Controls['deviceDataClearProhibited'], isTrue);

      final build8Approval =
          jsonDecode(
                read(
                  'release/approvals/'
                  'build-number-8-rollover-approval.json',
                ),
              )
              as Map<String, dynamic>;
      final build8Source =
          build8Approval['requiredSource'] as Map<String, dynamic>;
      final build8Controls = build8Approval['controls'] as Map<String, dynamic>;
      expect(build8Approval['approvalReference'], 'BAF-REF-003-C7');
      expect(build8Approval['distributionApproved'], isFalse);
      expect(
        (build8Approval['consumedBuild']
            as Map<String, dynamic>)['buildNumber'],
        7,
      );
      expect(
        (build8Approval['nextBuild'] as Map<String, dynamic>)['buildNumber'],
        8,
      );
      expect(build8Source['integratedSuccessorPullRequest'], 117);
      expect(
        build8Source['integratedSuccessorMergeCommit'],
        '45ebd9c853798f88fedd2e4d72d6022dc389097f',
      );
      expect(build8Source['postMergeGithubRunId'], 30796250694);
      expect(build8Controls['integratedSuccessorRequired'], isTrue);
      expect(
        build8Controls['publicRepositoryRequiredReviewerApproved'],
        isTrue,
      );
      expect(build8Controls['adminBypassProhibited'], isTrue);
      expect(build8Controls['mainOnlyEnvironmentDeploymentRequired'], isTrue);
    });

    test('public required-reviewer control is exact and fail-closed', () {
      final policy =
          jsonDecode(read('release/production-release-policy.json'))
              as Map<String, dynamic>;
      final github = policy['github'] as Map<String, dynamic>;
      final control =
          github['environmentReviewControl'] as Map<String, dynamic>;
      final approval =
          jsonDecode(
                read(
                  'release/approvals/'
                  'public-repository-environment-reviewer-approval-build-12.json',
                ),
              )
              as Map<String, dynamic>;
      final scope = approval['scope'] as Map<String, dynamic>;
      final approvalControls = approval['controls'] as Map<String, dynamic>;
      final liveStateEvidence =
          approval['liveStateEvidence'] as Map<String, dynamic>;
      final requiredReviewer =
          liveStateEvidence['requiredReviewer'] as Map<String, dynamic>;
      final authorizedDispatcher =
          liveStateEvidence['authorizedDispatcher'] as Map<String, dynamic>;
      final deploymentPolicy =
          liveStateEvidence['deploymentBranchPolicy'] as Map<String, dynamic>;
      final singleOperator =
          approval['singleOperatorConstraint'] as Map<String, dynamic>;
      final finalizer = read('tools/release/Finalize-ProductionRelease.ps1');

      expect(control['mode'], 'public-repository-required-reviewer');
      expect(control['repositoryVisibility'], 'public');
      expect(control['requiredReviewerAvailable'], isTrue);
      expect(control['requiredReviewerRulePresentAtApproval'], isTrue);
      expect(control['requiredReviewerLogin'], 'abhishekvatsa');
      expect(control['requiredReviewerId'], 213690022);
      expect(control['preventSelfReview'], isFalse);
      expect(control['adminBypassAllowed'], isFalse);
      expect(control['manualDispatchApprovalReferenceRequired'], isTrue);
      expect(control['approvedRunReviewHistoryRequired'], isTrue);
      expect(approval['approved'], isTrue);
      expect(
        approval['receiptType'],
        'public-repository-required-reviewer-control',
      );
      expect(scope['repositoryVisibility'], 'public');
      expect(scope['buildNumber'], 12);
      expect(scope['versionApprovalReference'], 'BAF-REF-003-C11');
      expect(scope['singleBuildOnly'], isTrue);
      expect(liveStateEvidence['repositoryPrivate'], isFalse);
      expect(liveStateEvidence['canAdminsBypass'], isFalse);
      expect(requiredReviewer['login'], 'abhishekvatsa');
      expect(requiredReviewer['id'], 213690022);
      expect(deploymentPolicy['customBranchPolicies'], isTrue);
      final allowedBranches =
          deploymentPolicy['allowedBranches'] as List<dynamic>;
      expect(allowedBranches, hasLength(1));
      expect((allowedBranches.single as Map<String, dynamic>)['name'], 'main');
      expect(authorizedDispatcher['login'], 'abhishekvatsa');
      expect(authorizedDispatcher['id'], 213690022);
      expect(
        singleOperator['independentSecondPartyReviewerAvailable'],
        isFalse,
      );
      expect(singleOperator['selfReviewPermitted'], isTrue);
      expect(
        singleOperator['explicitEnvironmentApprovalStillRequired'],
        isTrue,
      );
      expect(approvalControls['authorizedDispatcherIdentityRequired'], isTrue);
      expect(
        approvalControls['approvedRunReviewByRequiredReviewerRequired'],
        isTrue,
      );
      expect(approvalControls['adminBypassMustRemainDisabled'], isTrue);
      expect(approvalControls['mainOnlyEnvironmentDeploymentRequired'], isTrue);
      expect(approvalControls['distributionApproved'], isFalse);
      expect(approvalControls['firebaseDeploymentApproved'], isFalse);
      expect(
        finalizer,
        contains(
          'Live GitHub state does not satisfy required-reviewer '
          'signing control.',
        ),
      );
      expect(finalizer, contains('deployment-branch-policies'));
      expect(finalizer, contains(r'$approvedRequiredReviewerReviews.Count'));
      expect(finalizer, contains('environmentApprovalReference'));
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
      expect(policyVerifier, contains(r'$promotionBuildNumber'));
      expect(
        policyVerifier,
        contains(
          'Post-build promotion receipt has no matching governed build authority.',
        ),
      );
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
      expect(
        policyVerifier,
        contains(
          'Dispatch source does not contain the PR 197 startup remediation.',
        ),
      );
      expect(policyVerifier, contains('environmentAuthorityMergeCommit'));
      expect(
        policyVerifier,
        contains('exactFunctionFleetDeploymentReceiptSha256'),
      );
      expect(
        policyVerifier,
        contains('Exact Function fleet deployment receipt is incomplete.'),
      );
      expect(
        policyVerifier,
        contains(
          'Governed finalizer retains divergent '
          'environment/integrated-successor coupling.',
        ),
      );
    });

    test(
      'build 16 preserves builds 14-15 and the historical build 10 failure',
      () {
        final policy =
            jsonDecode(read('release/production-release-policy.json'))
                as Map<String, dynamic>;
        final finalization = policy['finalization'] as Map<String, dynamic>;
        final build15Finalization =
            finalization['priorCompletedBuild'] as Map<String, dynamic>;
        final build15Approval =
            jsonDecode(
                  read(
                    'release/approvals/build-number-15-successor-approval.json',
                  ),
                )
                as Map<String, dynamic>;
        final build14Finalization =
            build15Approval['preservedCompletedBuild'] as Map<String, dynamic>;
        final build13Receipt =
            jsonDecode(
                  read('release/evidence/build-13-finalization-closure.json'),
                )
                as Map<String, dynamic>;
        final build14Receipt =
            jsonDecode(
                  read(build14Finalization['completionReceiptFile'] as String),
                )
                as Map<String, dynamic>;
        final build15Receipt =
            jsonDecode(
                  read(build15Finalization['completionReceiptFile'] as String),
                )
                as Map<String, dynamic>;
        final receipt =
            jsonDecode(
                  read('release/evidence/build-11-finalization-closure.json'),
                )
                as Map<String, dynamic>;
        final build13Source =
            build13Receipt['sourceAuthority'] as Map<String, dynamic>;
        final build13Ci = build13Receipt['workflow'] as Map<String, dynamic>;
        final build13Package =
            build13Receipt['governedPackage'] as Map<String, dynamic>;
        final build13Remote =
            build13Receipt['remoteAuthority'] as Map<String, dynamic>;
        final build13Custody =
            build13Receipt['dualCustody'] as Map<String, dynamic>;
        final build13Runtime =
            build13Receipt['runtimeAdjudication'] as Map<String, dynamic>;
        final build13Boundary =
            build13Receipt['releaseBoundary'] as Map<String, dynamic>;
        final build14Source =
            build14Receipt['sourceAuthority'] as Map<String, dynamic>;
        final build14Ci = build14Receipt['workflow'] as Map<String, dynamic>;
        final build14Artifact =
            build14Receipt['githubArtifact'] as Map<String, dynamic>;
        final build14Package =
            build14Receipt['governedPackage'] as Map<String, dynamic>;
        final build14Remote =
            build14Receipt['remoteAuthority'] as Map<String, dynamic>;
        final build14Custody =
            build14Receipt['dualCustody'] as Map<String, dynamic>;
        final build14Recovery =
            build14Receipt['recoveryIncident'] as Map<String, dynamic>;
        final build14Runtime =
            build14Receipt['runtimeAdjudication'] as Map<String, dynamic>;
        final build14Boundary =
            build14Receipt['releaseBoundary'] as Map<String, dynamic>;
        final build15Source =
            build15Receipt['sourceAuthority'] as Map<String, dynamic>;
        final build15Ci = build15Receipt['workflow'] as Map<String, dynamic>;
        final build15Artifact =
            build15Receipt['githubArtifact'] as Map<String, dynamic>;
        final build15Package =
            build15Receipt['governedPackage'] as Map<String, dynamic>;
        final build15Remote =
            build15Receipt['remoteAuthority'] as Map<String, dynamic>;
        final build15Custody =
            build15Receipt['dualCustody'] as Map<String, dynamic>;
        final build15Runtime =
            build15Receipt['runtimeAdjudication'] as Map<String, dynamic>;
        final build15Boundary =
            build15Receipt['releaseBoundary'] as Map<String, dynamic>;
        final sourceAuthority =
            receipt['sourceAuthority'] as Map<String, dynamic>;
        final workflow = receipt['workflow'] as Map<String, dynamic>;
        final governedPackage =
            receipt['governedPackage'] as Map<String, dynamic>;
        final remoteAuthority =
            receipt['remoteAuthority'] as Map<String, dynamic>;
        final dualCustody = receipt['dualCustody'] as Map<String, dynamic>;
        final closure = receipt['closure'] as Map<String, dynamic>;
        final tagRecovery = receipt['recoveryIncident'] as Map<String, dynamic>;
        final releaseBoundary =
            receipt['releaseBoundary'] as Map<String, dynamic>;
        final runtimeAdjudication =
            receipt['runtimeAdjudication'] as Map<String, dynamic>;
        final backendEvidence =
            jsonDecode(
                  read(
                    'release/evidence/'
                    'build-8-f4-production-backend-readiness.json',
                  ),
                )
                as Map<String, dynamic>;
        final liveReadback =
            backendEvidence['liveReadback'] as Map<String, dynamic>;
        final mutationAdjudication =
            backendEvidence['mutationAdjudication'] as Map<String, dynamic>;
        final programmeBoundary =
            backendEvidence['programmeBoundary'] as Map<String, dynamic>;

        final pendingConstruction =
            finalization['status'] == 'pending-source-authorized';
        expect(
          finalization['status'],
          pendingConstruction
              ? 'pending-source-authorized'
              : 'completed-non-distributable',
        );
        expect(finalization['dualCustodyCompleted'], !pendingConstruction);
        expect(build15Finalization['buildNumber'], 15);
        expect(build15Finalization['dualCustodyCompleted'], isTrue);
        expect(build15Finalization['runtimeValidationPassed'], isFalse);
        expect(finalization['controlledPilotApproved'], isFalse);
        final failedAttempt =
            (finalization['historicalFailedAttempts'] as List)
                .cast<Map<String, dynamic>>()
                .single;
        expect(failedAttempt['buildNumber'], 10);
        expect(failedAttempt['status'], 'blocked-non-distributable');
        expect(failedAttempt['independentVerificationCompleted'], isTrue);
        expect(failedAttempt['dualCustodyCompleted'], isFalse);
        expect(failedAttempt['distributionPerformed'], isFalse);
        expect(
          failedAttempt['evidenceSha256'],
          'E43F28767214895BAC0B212C955DC07094BFD9E7A71F472113F1762BB8365F58',
        );
        expect(build14Finalization['buildNumber'], 14);
        expect(build14Finalization['status'], 'completed-non-distributable');
        expect(build14Finalization['dualCustodyCompleted'], isTrue);
        expect(build14Finalization['runtimeValidationPassed'], isFalse);
        expect(
          build14Finalization['completionReceiptSha256'],
          'E1C714FCEF7F23798E49A797E6F4ADCA7D2A7D57BFFD0F9B7C0B62A50B801DED',
        );
        expect(build13Receipt['schemaVersion'], 1);
        expect(build13Receipt['status'], 'passed-non-distributable');
        expect(
          build13Source['commit'],
          '59358123a7f1d9edf7a579b18d3e2407d8a1e48e',
        );
        expect(build13Ci['runId'], 32545733716);
        expect(
          build13Package['sha256'],
          'C5BACE9A71F9490EDA41AD7BDFF7DF3FD223A8BA54A58AC00A3C0ECEF8DD0AE8',
        );
        expect(build13Package['independentVerificationCompleted'], isTrue);
        expect(
          build13Remote['builtTagObjectSha'],
          'e5db822dededced9815585cd4cc1c8a04a3fd8f0',
        );
        expect(build13Custody['distinctVolumes'], isTrue);
        expect(build13Custody['allFileHashesMatched'], isTrue);
        expect(build13Runtime['status'], 'not-adjudicated-for-exact-build13');
        expect(build13Runtime['physicalTargetCount'], 0);
        expect(build13Runtime['liveBusinessFlowValidationCompleted'], isFalse);
        expect(build13Boundary['controlledPilotApproved'], isFalse);
        expect(build13Boundary['distributionPerformed'], isFalse);
        expect(build13Boundary['fullBusinessFlowValidationPassed'], isFalse);
        expect(build14Receipt['schemaVersion'], 1);
        expect(build14Receipt['status'], 'passed-non-distributable');
        expect(
          build14Source['commit'],
          'f0d51819bfa4c81ad73b5d7f83675fa8b6a07b11',
        );
        expect(
          build14Source['tree'],
          '627a8260231e834978c6f4b7445d76160b45964c',
        );
        expect(build14Source['pullRequestNumber'], 267);
        expect(build14Ci['runId'], 32572743604);
        expect(build14Ci['conclusion'], 'success');
        expect(build14Ci['secretValuesInspected'], isFalse);
        expect(build14Artifact['id'], 9475994815);
        expect(
          build14Package['sha256'],
          '496D990749A0658D73AEE4D908451424B185137F04EDFCA8B1C932195D994F2F',
        );
        expect(build14Package['independentVerificationCompleted'], isTrue);
        expect(
          build14Remote['builtTagObjectSha'],
          '99fdbadd63c59c28906669fa10fac56cc98a6ee5',
        );
        expect(build14Custody['distinctVolumes'], isTrue);
        expect(build14Custody['allFileHashesMatched'], isTrue);
        expect(build14Recovery['occurred'], isFalse);
        expect(build14Recovery['forceUsed'], isFalse);
        expect(
          build14Runtime['status'],
          'not-adjudicated-by-build-finalization',
        );
        expect(build14Runtime['runtimeValidationPassed'], isFalse);
        expect(build14Boundary['controlledPilotApproved'], isFalse);
        expect(build14Boundary['distributionPerformed'], isFalse);
        expect(build15Receipt['schemaVersion'], 1);
        expect(build15Receipt['status'], 'passed-non-distributable');
        expect(
          build15Source['commit'],
          '9fcf65883265947cfd3def7de7bdc13bda7eff16',
        );
        expect(
          build15Source['tree'],
          '125d3547a2048a7b8417774a982d1cc31566e25f',
        );
        expect(build15Source['pullRequestNumber'], 292);
        expect(build15Ci['runId'], 32802565268);
        expect(build15Ci['conclusion'], 'success');
        expect(build15Ci['secretValuesInspected'], isFalse);
        expect(build15Artifact['id'], 9547514373);
        expect(
          build15Package['sha256'],
          '9574B2C42263A9CD60DED9C1F6E17B4509B4E17B9E7673B8D5E900846D27A570',
        );
        expect(
          build15Package['apkSha256'],
          '56B90F5C19C1EA28721595F628882A235F5E313C74E2F2347C7381CC28DA0C5F',
        );
        expect(build15Package['independentVerificationCompleted'], isTrue);
        expect(
          build15Remote['builtTagObjectSha'],
          'c52280a28e11dcdad821d795f900211f5545e2a0',
        );
        expect(build15Custody['distinctVolumes'], isTrue);
        expect(build15Custody['allFileHashesMatched'], isTrue);
        expect(
          build15Runtime['status'],
          'not-adjudicated-by-build-finalization',
        );
        expect(build15Runtime['runtimeValidationPassed'], isFalse);
        expect(build15Boundary['controlledPilotApproved'], isFalse);
        expect(build15Boundary['distributionPerformed'], isFalse);
        expect(receipt['schemaVersion'], 1);
        expect(receipt['status'], 'passed-non-distributable');
        expect(
          sourceAuthority['commit'],
          'ca65d3deead23cccdf07ca24255bc073221d84db',
        );
        expect(sourceAuthority['pullRequestNumber'], 199);
        expect(workflow['runId'], 31552161470);
        expect(workflow['actor'], 'abhishekvatsa');
        expect(workflow['actorId'], 213690022);
        expect(workflow['secretValuesInspected'], isFalse);
        expect(
          governedPackage['sha256'],
          '104D5ADA33244CCC9090C31A72FBF167F4D69699C93EDD75FA3F6AAB6D99D970',
        );
        expect(governedPackage['independentVerificationCompleted'], isTrue);
        expect(
          remoteAuthority['builtTagObjectSha'],
          'ed33b3f48d9bd10b23c88025eaa567ae235d970c',
        );
        expect(dualCustody['distinctVolumes'], isTrue);
        expect(dualCustody['allFileHashesMatched'], isTrue);
        expect(
          closure['closurePackageSha256'],
          '9E3C4F04A120438A817DB316E5142C06A502FE4AB726DCFCB7787966C30CCB43',
        );
        expect(tagRecovery['occurred'], isFalse);
        expect(tagRecovery['forceUsed'], isFalse);
        expect(releaseBoundary['firebaseBackendDeploymentPerformed'], isFalse);
        expect(releaseBoundary['controlledPilotApproved'], isFalse);
        expect(releaseBoundary['unrestrictedPlantReleaseApproved'], isFalse);
        expect(releaseBoundary['distributionPerformed'], isFalse);
        expect(releaseBoundary['runtimeValidationPassed'], isTrue);
        expect(runtimeAdjudication['status'], 'passed-two-target-in-place');
        expect(runtimeAdjudication['physicalTargetCount'], 1);
        expect(runtimeAdjudication['emulatorTargetCount'], 1);
        expect(runtimeAdjudication['bothPreservedAppData'], isTrue);
        expect(runtimeAdjudication['appDataClearPerformed'], isFalse);

        expect(backendEvidence['decision'], 'PASS_BUILD8_F4_BACKEND_READY');
        expect(liveReadback['globalPullContractState'], 'ACTIVE');
        expect(liveReadback['inventoryTotal'], 42);
        expect(liveReadback['inventoryStamped'], 42);
        expect(liveReadback['inventoryMissing'], 0);
        expect(liveReadback['inventoryMalformed'], 0);
        expect(mutationAdjudication['watermarkFieldsCreated'], 41);
        expect(mutationAdjudication['businessFieldsMutated'], isFalse);
        expect(mutationAdjudication['distributionPerformed'], isFalse);
        expect(programmeBoundary['stage2dF4Status'], 'OPEN');
        expect(programmeBoundary['stage2dF4ClosureAuthorized'], isFalse);
        expect(programmeBoundary['pilotHandoutAuthorized'], isFalse);
      },
    );

    test('post-build promotion resolves its retained finalized authority', () {
      final verifier = read('tools/release/Test-ProductionReleasePolicy.ps1');
      expect(
        verifier,
        contains(r'$promotionReceipt.admittedEvidence.governedBuild'),
      );
      expect(
        verifier,
        contains(r'$promotionAuthorityBuild.finalizationReceipt'),
      );
      expect(
        verifier,
        contains(
          'Promoted build finalization receipt hash differs from authority.',
        ),
      );
      expect(
        verifier,
        isNot(
          contains(
            r'$policy.finalization.priorCompletedBuild.buildNumber -eq'
            '\n    \$promotionBuildNumber',
          ),
        ),
      );
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
        contains(RegExp(r'^version:\s+1\.0\.0-rc\.6\+16$', multiLine: true)),
      );
      expect(policy, contains('"releaseId": "crm3-baf-ops-1.0.0-rc.6-b16"'));
      expect(
        policy,
        contains('"remoteReservationTag": "crm3-build-reserved/16"'),
      );
      expect(policy, contains('"approved": true'));
      expect(
        policy,
        contains('"authority": "exact-build11-sealed-small-group-pilot"'),
      );
      expect(policy, contains('"pilotHandoutPerformed": false'));
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
