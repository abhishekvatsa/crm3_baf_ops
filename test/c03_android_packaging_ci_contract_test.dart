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
      final job = _jobSection(workflow, 'android-package', 'firestore-rules');

      expect(workflow, contains('pull_request:'));
      expect(workflow, contains('push:'));
      expect(workflow, contains('push:\n    branches: ["main"]'));
      expect(workflow, contains('pull_request:\n    branches: ["**"]'));
      expect(workflow, isNot(contains('push:\n    branches: ["**"]')));
      expect(job, contains('Android release APK + AAB packaging proof'));
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
      expect(script, contains('RandomNumberGenerator]::GetBytes(24)'));
      expect(script, contains("'-genkeypair'"));
      expect(script, contains("'PKCS12'"));
      expect(script, contains("'crm3-ci-package-proof'"));
      expect(script, contains("'apk'"));
      expect(script, contains("'appbundle'"));
      expect(script, contains("'--release'"));
      expect(script, contains("'apksigner'"));
      expect(script, contains("'jarsigner'"));
      expect(script, contains("'manifest', 'application-id'"));
      expect(script, contains("'manifest', 'debuggable'"));
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
      expect(script, contains('Remove-Item -LiteralPath \$temporaryStore'));
      expect(script, isNot(contains(productionCertificate)));
    });
  });
}
