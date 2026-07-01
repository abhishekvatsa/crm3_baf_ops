import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('70I-B1 backend authority preserves truthful release boundaries', () {
    final authority =
        jsonDecode(read('release/backend-authority.prod.json'))
            as Map<String, dynamic>;

    expect(authority['schemaVersion'], 2);
    expect(
      authority['authorityClass'],
      'verified-production-backend-composite',
    );
    expect(authority['firebaseProjectId'], 'crm3-baf-ops-b8638');
    expect(
      authority['authorityDigest'],
      '171FEFD8D2DE1C2F500FA164C2C9E4617E46A7BD773CD7A620973296444922DE',
    );
    expect(
      authority['releaseId'],
      'prod-composite-20260628T171115Z-rules-0b3868bf-fleet-d57d11bd',
    );

    expect(authority.containsKey('backendGitCommit'), isFalse);
    expect(authority.containsKey('deployedIndexesParityStatus'), isFalse);
    expect(authority.containsKey('deployedIndexesParityEvidence'), isFalse);
    expect(authority.containsKey('intentionalDivergencePolicy'), isFalse);

    final releaseModel = authority['releaseModel'] as Map<String, dynamic>;
    expect(releaseModel['type'], 'COMPOSITE_LIVE_STATE');
    expect(releaseModel['singleHomogeneousDeployment'], isFalse);
    expect(releaseModel['functionFleetStatus'], 'MIXED_DEPLOYMENT_FLEET');
    expect(
      releaseModel['identityProjectionSourceStatus'],
      'SOURCE_DEFINED_PENDING_DEPLOYMENT',
    );

    final repositoryAuthority =
        authority['repositoryAuthority'] as Map<String, dynamic>;
    expect(
      repositoryAuthority['productionReconstructionSourceCommit'],
      '17f433b93b596e7730b58b337a42733a05f297a3',
    );
    expect(
      repositoryAuthority['productionReconstructionSourceTree'],
      '0496b940a20e04ca9789f2ba11b840dca6aeb56c',
    );
    expect(
      repositoryAuthority['identityFunctionCurrentLiveReportedSourceCommit'],
      '4132b83a1bf9693b1b8f33f602091e89143250ce',
    );
    expect(repositoryAuthority['identityFunctionDeployedSourceCommit'], isNull);
    expect(
      repositoryAuthority['mixedFleetDigest'],
      'D57D11BDC6AE304AA90107EE6C4A6196AD55C35EDA2ECDCBC8E53EF998BCF4D1',
    );

    final functions = authority['functions'] as Map<String, dynamic>;
    expect(functions['status'], 'MIXED_DEPLOYMENT_FLEET');
    expect(functions['singleHomogeneousDeployment'], isFalse);
    expect(functions['expectedExports'], 7);
    expect(functions['liveExports'], 7);
    expect(
      functions['fleetDigest'],
      'D57D11BDC6AE304AA90107EE6C4A6196AD55C35EDA2ECDCBC8E53EF998BCF4D1',
    );

    final legacyDisposition =
        authority['legacyAuthorityDisposition'] as Map<String, dynamic>;
    expect(legacyDisposition['priorReleaseId'], 'prod-4132b83-20260620_001612');
    expect(legacyDisposition['status'], 'SUPERSEDED_BY_STRICT_SCHEMA_V2');
    expect(legacyDisposition['doNotUseAsCurrentReleaseGate'], isTrue);

    final sourceAdoption = authority['sourceAdoption'] as Map<String, dynamic>;
    expect(
      sourceAdoption['status'],
      'SOURCE_DEFINED_PENDING_DRAFT_PR_REVIEW_MERGE_AND_DEPLOYMENT',
    );
    expect(sourceAdoption['productionDeploymentPerformed'], isFalse);
    expect(sourceAdoption['iamMutationPerformed'], isFalse);
  });

  test(
    'governed builder supplies all identity fields and labels debug output',
    () {
      final source = read('tools/release/New-VerificationArtifact.ps1');

      for (final field in <String>[
        'APP_VERSION',
        'APP_BUILD_NUMBER',
        'GIT_COMMIT',
        'RELEASE_TAG',
        'RELEASE_CHANNEL',
        'CI_RUN_ID',
        'BUILD_TIMESTAMP_UTC',
        'RELEASE_ID',
        'EXPECTED_BACKEND_RELEASE_ID',
        'SOURCE_ARCHIVE_SHA256',
      ]) {
        expect(source, contains(field), reason: 'missing $field');
      }

      expect(source, contains("artifactClass = 'verification'"));
      expect(
        source,
        contains("distributionAuthority = 'not-approved-for-production'"),
      );
      expect(source, contains("mode = 'debug'"));
      expect(source, contains("'build', 'apk', '--debug'"));
      expect(source, contains('git archive'));
      expect(source, contains('Test-ReleaseManifest.ps1'));
      expect(source, contains('deployedIndexesParityStatus'));
    },
  );

  test('independent verifier recomputes custody and rejects false claims', () {
    final source = read('tools/release/Test-ReleaseManifest.ps1');

    expect(source, contains('Get-FileHash'));
    expect(source, contains('apksigner'));
    expect(source, contains("artifactClass -ne 'verification'"));
    expect(source, contains("signing.mode -ne 'debug'"));
    expect(source, contains('sourceCustody'));
    expect(source, contains('EXPECTED_BACKEND_RELEASE_ID'));
    expect(source, contains('verification-result.json'));
  });

  test('manual CI workflow uses exact commit and uploads evidence', () {
    final source = read('.github/workflows/verification-artifact.yml');

    expect(source, contains('workflow_dispatch:'));
    expect(source, contains('ref: \${{ github.sha }}'));
    expect(source, contains('New-VerificationArtifact.ps1'));
    expect(source, contains("ReleaseChannel 'verification'"));
    expect(source, contains('actions/upload-artifact@v4'));
  });

  test('native-core custody is explicit across builder, verifier, and CI', () {
    final builder = read('tools/release/New-VerificationArtifact.ps1');
    final verifier = read('tools/release/Test-ReleaseManifest.ps1');
    final workflow = read('.github/workflows/verification-artifact.yml');

    expect(builder, contains('IsarCorePath'));
    expect(builder, contains('ExpectedIsarCoreSha256'));
    expect(builder, contains('nativeTestDependencies'));
    expect(builder, contains('CRM_ISAR_CORE_PATH'));
    expect(verifier, contains('nativeTestDependencies.isarCore'));
    expect(verifier, contains('Isar native-core SHA-256 mismatch'));
    expect(workflow, contains('Prepare and prove Linux Isar native core'));
    expect(workflow, contains('CRM_ISAR_CORE_SHA256'));
  });

  test('source custody is canonical, portable, and package-verifiable', () {
    final builder = read('tools/release/New-VerificationArtifact.ps1');
    final verifier = read('tools/release/Test-ReleaseManifest.ps1');

    expect(builder, contains("schemaVersion = 2"));
    expect(builder, contains('Get-ZipEntrySha256'));
    expect(builder, contains("hashBasis = 'git-archive-entry-bytes'"));
    expect(builder, contains("entryPathStyle = 'posix'"));
    expect(builder, contains("authorityFile = \$authorityEntryPath"));
    expect(builder, contains("verify-release-package.ps1"));
    expect(builder, contains("Join-Path \$PSScriptRoot '../..'"));
    expect(builder, contains("build/app/outputs/flutter-apk/app-debug.apk"));
    expect(builder, contains(r'$IsWindows'));

    expect(verifier, contains("schemaVersion -ne 2"));
    expect(verifier, contains('Get-ZipEntrySha256'));
    expect(verifier, contains('Get-ZipEntryText'));
    expect(verifier, contains('Packaged verifier SHA-256 mismatch'));
    expect(verifier, contains('source-entry SHA-256 mismatch'));
    expect(verifier, contains(r'$IsWindows'));
  });
}
