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

      expect(authority['deployedIndexesParityStatus'], 'proven');
      final evidence =
          authority['deployedIndexesParityEvidence'] as Map<String, dynamic>;
      expect(evidence['decision'], 'PROVEN');
      expect(evidence['sourceCompositeIndexes'], 28);
      expect(evidence['deployedCompositeIndexes'], 28);
      expect(evidence['missing'], 0);
      expect(evidence['extra'], 0);
      expect(evidence['nonReady'], 0);
      expect(evidence['actualFieldOverrides'], 0);
      expect(
        evidence['evidenceSha256'],
        'E21C7E71611FBF84A42DBBD6C6E44CF3FD353AFDDB298A855D03DACA6A254CB8',
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
      expect(text, isNot(contains('SkipQualityGates')));
      expect(text, isNot(contains("CiRunId = 'local'")));
    });

    test('independent verifier reproduces signer and source custody', () {
      final text = read('tools/release/Test-ProductionReleaseManifest.ps1');

      expect(text, contains('schemaVersion -ne 5'));
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

    test('permanent identity and public version are committed', () {
      final gradle = read('android/app/build.gradle.kts');
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      final pubspec = read('pubspec.yaml');
      final policy = read('release/production-release-policy.json');

      expect(gradle, isNot(contains('com.example.crm3_baf_ops')));
      expect(manifest, isNot(contains('android:label="crm3_baf_ops"')));
      expect(
        pubspec,
        contains(RegExp(r'^version:\s+\S+\+\d+', multiLine: true)),
      );
      expect(policy, contains('"approved": false'));
      expect(policy, contains('"unrestrictedPlantReleaseApproved": false'));
    });
  });
}
