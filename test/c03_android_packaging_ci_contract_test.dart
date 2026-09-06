import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _jobSection(String workflow, String job, String nextJob) {
  final start = workflow.indexOf('\n  $job:');
  final end = workflow.indexOf('\n  $nextJob:', start + 1);
  expect(start, greaterThanOrEqualTo(0), reason: job);
  expect(end, greaterThan(start), reason: nextJob);
  return workflow.substring(start, end);
}

void main() {
  group('C-03 Android PR packaging proof', () {
    test('release gate builds APK and AAB with no production authority', () {
      final workflow = _read('.github/workflows/release-gate.yml');
      final job = _jobSection(workflow, 'android-package', 'android-emulator');

      expect(workflow, contains('pull_request:'));
      expect(workflow, contains('push:'));
      expect(workflow, contains('push:\n    branches: ["main"]'));
      expect(workflow, contains('pull_request:\n    branches: ["**"]'));
      expect(workflow, isNot(contains('push:\n    branches: ["**"]')));
      expect(
        job,
        contains('Android release package + cold-start proof (non-production)'),
      );
      expect(
        job,
        contains('actions/setup-java@b6effb05e454b25005698d916606bdc6ffcbf961'),
      );
      expect(
        job,
        contains(
          'subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2',
        ),
      );
      expect(job, contains('Invoke-CIAndroidPackageProof.ps1'));
      expect(job, contains('Test-CIAndroidReleaseStartup.ps1'));
      expect(job, contains('Cold-start the exact release APK'));
      expect(
        job,
        contains(
          'ReactiveCircus/android-emulator-runner@a421e43855164a8197daf9d8d40fe71c6996bb0d',
        ),
      );
      expect(job, isNot(contains(r'${{ secrets.')));
      expect(job, isNot(contains('\n    environment:')));
      expect(job, isNot(contains('upload-artifact')));
    });

    test('proof is ephemeral, fail-closed and independently verifies output', () {
      final script = _read('tools/release/Invoke-CIAndroidPackageProof.ps1');
      final policy =
          jsonDecode(_read('release/production-release-policy.json'))
              as Map<String, dynamic>;
      final signing = policy['signing'] as Map<String, dynamic>;
      final productionCertificate = signing['certificateSha256'] as String;

      expect(
        script,
        contains('CI packaging proof refuses pre-existing signing input'),
      );
      expect(
        script,
        contains('CI packaging proof refuses a pre-existing Firebase override'),
      );
      expect(script, contains('RandomNumberGenerator]::Create()'));
      expect(script, contains(r'$generator.GetBytes($bytes)'));
      expect(script, contains(r"New-Object byte[] 24"));
      expect(script, contains("'-genkeypair'"));
      expect(script, contains("'PKCS12'"));
      expect(script, contains("'crm3-ci-package-proof'"));
      expect(script, contains("'apk'"));
      expect(script, contains("'appbundle'"));
      expect(script, contains("'--release'"));
      expect(script, contains("'--dart-define=CRM3_CI_PACKAGE_PROOF=true'"));
      expect(script, contains("\$env:CRM3_CI_PACKAGE_PROOF = 'true'"));
      expect(script, contains('android/app/src/release/google-services.json'));
      expect(script, contains('crm3-ci-package-proof-isolated'));
      expect(script, contains('crm3-ci-package-proof-no-api-access'));
      expect(
        RegExp(r'AIza[0-9A-Za-z_-]{35}').hasMatch(script),
        isFalse,
        reason: 'The CI Firebase fixture must not look like a real API key.',
      );
      expect(script, contains("'google_app_id'"));
      expect(script, contains("'gcm_defaultSenderId'"));
      expect(script, contains("'project_id'"));
      expect(script, contains("'google_api_key'"));
      expect(script, contains('isolatedFirebaseIdentity=true'));
      expect(script, contains('productionFirebaseIdentityEmbedded=false'));
      expect(script, contains('firebaseProductionTrafficDisabled=true'));
      expect(script, contains('crashlyticsMappingUploadEnabled=false'));
      expect(script, contains('firebaseAutomaticCollectionEnabled=false'));
      expect(script, contains("'apksigner'"));
      expect(script, contains("'jarsigner'"));
      expect(script, contains("'manifest', 'application-id'"));
      expect(script, contains("'manifest', 'debuggable'"));
      expect(
        script,
        contains("'com.google.firebase.crashlytics.mapping_file_id'"),
      );
      expect(
        script,
        contains('Release APK is missing Crashlytics mapping identity.'),
      );
      expect(script, contains(r'$crashlyticsMappingIdOutput.Count -ne 1'));
      expect(script, contains('crashlyticsMappingIdPresent=true'));
      expect(script, contains('policy.signing.certificateSha256'));
      expect(
        script,
        contains(
          'Ephemeral CI signer unexpectedly matches the production certificate.',
        ),
      );
      expect(script, contains('APK signer does not match'));
      expect(script, contains('AAB signer does not match'));
      expect(script, contains('productionCertificateUsed=false'));
      expect(script, contains('productionSecretsReferenced=false'));
      expect(script, contains('artifactUploadPerformed=false'));
      expect(script, contains('verify_android_16kb_alignment.py'));
      expect(script, contains('PASS_ANDROID_16KB_NATIVE_ALIGNMENT'));
      expect(script, contains('PASS_ANDROID_COMPILED_BACKUP_POLICY'));
      expect(script, contains('native16KbCompatibilityVerified=true'));
      expect(script, contains('androidBackupAndDeviceTransferExcluded=true'));
      expect(script, contains('Remove-Item -LiteralPath \$temporaryStore'));
      expect(
        script,
        contains('Remove-Item -LiteralPath \$ciFirebaseConfigPath'),
      );
      expect(script, isNot(contains(productionCertificate)));

      final gradle = _read('android/app/build.gradle.kts');
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final mainSource = _read('lib/main.dart');
      expect(gradle, contains('mappingFileUploadEnabled = !ciPackageProof'));
      expect(
        gradle,
        contains('manifestPlaceholders["crm3FirebaseDataCollectionEnabled"]'),
      );
      expect(
        gradle,
        contains('manifestPlaceholders["crm3FirebaseInitProviderEnabled"]'),
      );
      expect(manifest, contains('firebase_data_collection_default_enabled'));
      expect(manifest, contains('firebase_crashlytics_collection_enabled'));
      expect(manifest, contains('firebase_messaging_auto_init_enabled'));
      expect(manifest, contains('firebase_analytics_collection_enabled'));
      expect(
        manifest,
        contains('com.google.firebase.provider.FirebaseInitProvider'),
      );
      expect(manifest, contains(r'${crm3FirebaseInitProviderEnabled}'));
      expect(script, contains('firebaseNativeInitProviderEnabled=false'));
      expect(
        mainSource,
        contains("bool.fromEnvironment('CRM3_CI_PACKAGE_PROOF')"),
      );
      expect(mainSource, contains('if (_ciPackageProof) {'));
      expect(mainSource, contains('runApp(const _CiPackageProofApp())'));
      expect(
        mainSource.indexOf('if (_ciPackageProof) {'),
        lessThan(mainSource.indexOf('runCrashReportingZoned')),
      );
    });

    test('device-bound operational state is excluded from Android backup', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final legacyRules = _read(
        'android/app/src/main/res/xml/backup_rules.xml',
      );
      final modernRules = _read(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      const domains = <String>[
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
        'device_root',
        'device_file',
        'device_database',
        'device_sharedpref',
      ];

      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(legacyRules, contains('<full-backup-content>'));
      expect(modernRules, contains('<cloud-backup>'));
      expect(modernRules, contains('<device-transfer>'));

      final cloudRules = modernRules.split('<device-transfer>').first;
      final transferRules = modernRules.split('<device-transfer>').last;
      for (final domain in domains) {
        final exclusion = '<exclude domain="$domain" path="." />';
        expect(legacyRules, contains(exclusion), reason: domain);
        expect(cloudRules, contains(exclusion), reason: 'cloud:$domain');
        expect(transferRules, contains(exclusion), reason: 'transfer:$domain');
      }
    });

    test('all Android artifact paths enforce 16 KB native compatibility', () {
      final verifier = _read('tools/release/verify_android_16kb_alignment.py');
      final ciProof = _read('tools/release/Invoke-CIAndroidPackageProof.ps1');
      final production = _read('tools/release/New-ProductionArtifact.ps1');
      final localReleaseGate = _read('release_gate.ps1');
      final backupVerifier = _read(
        'tools/release/Test-AndroidCompiledBackupPolicy.ps1',
      );

      expect(verifier, contains('PAGE_SIZE = 16 * 1024'));
      expect(verifier, contains('PT_LOAD = 1'));
      expect(verifier, contains('info.compress_type != zipfile.ZIP_STORED'));
      expect(verifier, contains('data_offset % PAGE_SIZE != 0'));
      expect(verifier, contains('value < PAGE_SIZE'));
      expect(verifier, contains('archive.testzip()'));
      expect(ciProof, contains('verify_android_16kb_alignment.py'));
      expect(
        ciProof,
        contains('Release APK failed Android 16 KB native verification.'),
      );
      expect(production, contains('Verify Android 16 KB native compatibility'));
      expect(production, contains('android-16kb-native-alignment.json'));
      expect(localReleaseGate, contains('verify_android_16kb_alignment.py'));
      expect(ciProof, contains('Test-AndroidCompiledBackupPolicy.ps1'));
      expect(production, contains('Verify compiled Android backup policy'));
      expect(production, contains('Test-AndroidCompiledBackupPolicy.ps1'));
      expect(
        localReleaseGate,
        contains('Test-AndroidCompiledBackupPolicy.ps1'),
      );
      expect(production, contains('android16KbNativeCompatibility'));
      expect(production, contains('androidBackupAndDeviceTransferExclusion'));
      expect(backupVerifier, contains('PASS_ANDROID_COMPILED_BACKUP_POLICY'));
      expect(backupVerifier, contains("'fullBackupContent'"));
      expect(backupVerifier, contains("'dataExtractionRules'"));
      expect(backupVerifier, contains("'/data-extraction-rules/cloud-backup'"));
      expect(
        backupVerifier,
        contains("'/data-extraction-rules/device-transfer'"),
      );

      final manifestVerifier = _read(
        'tools/release/Test-ProductionReleaseManifest.ps1',
      );
      expect(manifestVerifier, contains("'android16KbNativeCompatibility'"));
      expect(
        manifestVerifier,
        contains("'androidBackupAndDeviceTransferExclusion'"),
      );
    });

    test(
      'cold-start proof fails closed on process death or crash evidence',
      () {
        final script = _read('tools/release/Test-CIAndroidReleaseStartup.ps1');
        final decision = _read(
          'docs/v4_2_r1/BUILD9_CRASHLYTICS_STARTUP_REMEDIATION.md',
        );

        expect(script, contains('ANDROID_SDK_ROOT'));
        expect(script, contains('Android Debug Bridge is unavailable.'));
        expect(script, contains('-not (\$devices -match'));
        expect(script, contains("'install', '-r', \$resolvedApk"));
        expect(
          script,
          isNot(contains("'android.permission.POST_NOTIFICATIONS'")),
        );
        expect(script, contains("'am',"));
        expect(script, contains("'start',"));
        expect(script, contains("'-W',"));
        expect(script, contains('shell pidof \$ApplicationId'));
        expect(script, contains(r'$pidExitCode -ne 0'));
        expect(script, contains("'activity', 'exit-info'"));
        expect(script, contains("'logcat', '-b', 'crash'"));
        expect(script, contains("-not (\$launchOutput -match '^Status:"));
        expect(script, contains('reason=4 \\(APP CRASH\\(EXCEPTION\\)\\)'));
        expect(
          script,
          contains('Release process is not alive after cold launch.'),
        );
        expect(script, contains('PASS_C03_ANDROID_RELEASE_COLD_START_PROOF'));
        expect(script, contains("'apkanalyzer.bat'"));
        expect(
          script,
          contains('com.google.firebase.provider.FirebaseInitProvider'),
        );
        expect(
          script,
          contains('CI proof APK must disable FirebaseInitProvider'),
        );
        expect(script, contains('firebaseNativeInitProviderEnabled=false'));
        expect(script, contains('firebaseDartInitializationAttempted=false'));
        expect(
          script,
          isNot(contains('firebaseInitializationAttempted=false')),
        );
        expect(script, isNot(contains('pm clear')));
        expect(script, isNot(contains('uninstall')));
        expect(
          decision,
          contains('SOURCE REMEDIATED / BUILD 9 NON-DISTRIBUTABLE'),
        );
        expect(decision, contains('reason=4 (APP CRASH(EXCEPTION))'));
        expect(decision, contains('No cache or app data was cleared'));
        expect(
          decision,
          contains('separately authorized, production-signed successor'),
        );
      },
    );
  });
}
