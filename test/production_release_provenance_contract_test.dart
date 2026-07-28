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
      expect(text, contains('isDebuggable = false'));
      expect(text, isNot(contains('signingConfigs.getByName("debug")')));
    });

    test('failed build 1 is preserved and build 2 is separately approved', () {
      final ledger =
          jsonDecode(read('release/build-number-ledger.json'))
              as Map<String, dynamic>;
      final entries =
          (ledger['entries'] as List<dynamic>).cast<Map<String, dynamic>>();
      final consumed = entries.singleWhere(
        (entry) => entry['buildNumber'] == 1,
      );
      final replacement = entries.singleWhere(
        (entry) => entry['buildNumber'] == 2,
      );

      expect(consumed['status'], 'remote-consumed-build-failed');
      expect(consumed['githubRunId'], 30387521656);
      expect(consumed['artifactConstructed'], isFalse);
      expect(consumed['artifactUploaded'], isFalse);
      expect(consumed['remoteBuiltTagCreated'], isFalse);
      expect(consumed['failedOrWithdrawnBuildConsumesNumber'], isTrue);

      expect(
        replacement['status'],
        'source-reserved-awaiting-remote-consumption',
      );
      expect(replacement['remoteReservationTag'], 'crm3-build-reserved/2');
      expect(replacement['remoteBuiltTag'], 'crm3-build-built/2');

      final approval =
          jsonDecode(
                read(
                  'release/approvals/'
                  'build-number-2-rollover-approval.json',
                ),
              )
              as Map<String, dynamic>;
      expect(approval['approved'], isTrue);
      expect(approval['distributionApproved'], isFalse);
      expect(
        (approval['consumedBuild'] as Map<String, dynamic>)['githubRunId'],
        30387521656,
      );
      expect((approval['nextBuild'] as Map<String, dynamic>)['buildNumber'], 2);
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
        contains(RegExp(r'^version:\s+1\.0\.0-rc\.1\+2$', multiLine: true)),
      );
      expect(policy, contains('"releaseId": "crm3-baf-ops-1.0.0-rc.1-b2"'));
      expect(
        policy,
        contains('"remoteReservationTag": "crm3-build-reserved/2"'),
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
