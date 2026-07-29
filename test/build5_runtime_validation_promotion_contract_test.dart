import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

List<String> _strings(dynamic value) {
  return (value as List<dynamic>).cast<String>();
}

void main() {
  test('Build 5 runtime promotion is exact, bounded and non-pilot', () {
    final promotion = _readJson(
      'release/approvals/build-5-runtime-validation-promotion.json',
    );

    expect(promotion['schemaVersion'], 1);
    expect(
      promotion['approvalClass'],
      'CONTROLLED_INTERNAL_RUNTIME_VALIDATION_ONLY',
    );
    final amendment = _object(promotion['amendment']);
    expect(
      amendment['priorPromotionSha256'],
      '5F9C28921E66FADBE6B4224ABFB230999E8678C2475531FCAE738ACC4DC9362B',
    );
    expect(amendment['artifactOrTargetExpansion'], isFalse);
    expect(amendment['pilotOrExternalDistributionExpansion'], isFalse);
    final explicitOauthAmendment = _object(promotion['explicitOauthAmendment']);
    expect(
      explicitOauthAmendment['priorRecoveryPromotionSha256'],
      'A68A70EB01A5A5C7FA7528F5DFE908EE5415A79050A62A0038E873B564910AF2',
    );
    expect(explicitOauthAmendment['appDataClearAuthorized'], isFalse);
    expect(explicitOauthAmendment['reinstallAuthorized'], isFalse);
    expect(explicitOauthAmendment['artifactOrTargetExpansion'], isFalse);
    expect(
      explicitOauthAmendment['pilotOrExternalDistributionExpansion'],
      isFalse,
    );
    final diagnosticAmendment = _object(
      promotion['postOauthDiagnosticAmendment'],
    );
    expect(
      diagnosticAmendment['priorPromotionSha256'],
      '083C844DC10BC8345326F3F784EC5A646D3E23E200935E2FB90DBBE0D3DEF39C',
    );
    expect(diagnosticAmendment['identityValueRetentionAuthorized'], isFalse);
    expect(diagnosticAmendment['otherUserReadAuthorized'], isFalse);
    expect(diagnosticAmendment['firestoreWriteAuthorized'], isFalse);
    expect(diagnosticAmendment['authMutationAuthorized'], isFalse);
    expect(diagnosticAmendment['rulesOrAppCheckMutationAuthorized'], isFalse);
    final raceAmendment = _object(
      promotion['profileTokenRaceRemediationAmendment'],
    );
    expect(
      raceAmendment['priorPromotionSha256'],
      'C3661F230803057E8D242C9659EC5B26A1165B1EBEC4F21303BD6088F707D62F',
    );
    expect(
      raceAmendment['diagnosticReceiptSha256'],
      '5EF5139DE70CAD7CA548898482C3ED047DE1220FAD7D06A6701C1466B0FD6B27',
    );
    expect(
      raceAmendment['postAuthRelaunchUiSha256'],
      '6A7A41F5084050B1E06556347D0D4C5C86A5F3CB7DAD23137FF0B5E5AC8181F3',
    );
    expect(raceAmendment['existingBuild5ArtifactContainsRemediation'], isFalse);
    expect(raceAmendment['futurePilotArtifactMustContainRemediation'], isTrue);
    expect(raceAmendment['rebuildOrResignAuthorized'], isFalse);
    expect(raceAmendment['firestoreOrAuthMutationAuthorized'], isFalse);
    expect(raceAmendment['rulesOrAppCheckMutationAuthorized'], isFalse);

    final artifact = _object(promotion['artifactAuthority']);
    expect(artifact['applicationId'], 'in.co.sail.bsl.crm3.bafops');
    expect(artifact['versionName'], '1.0.0-rc.1');
    expect(artifact['versionCode'], 5);
    expect(
      _object(artifact['apk'])['sha256'],
      '1A39F9F375D785817862AA86BF3810FB5D99545E1E8BFFB7BA4F3CA69253774C',
    );
    expect(_object(artifact['apk'])['debuggable'], isFalse);
    expect(
      _object(artifact['signer'])['certificateSha256'],
      '6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C',
    );

    final channel = _object(promotion['channel']);
    expect(channel['planningMode'], 'internal-release-signed-apk');
    expect(channel['transport'], 'DIRECT_ADB_FROM_GOVERNED_LOCAL_CUSTODY');
    expect(channel['maxTargetCount'], 1);
    expect(channel['firebaseAppDistributionUploadAuthorized'], isFalse);
    expect(channel['playConsoleUploadAuthorized'], isFalse);
    expect(channel['webOrPublicLinkAuthorized'], isFalse);

    final target = _object(channel['target']);
    expect(target['kind'], 'ANDROID_VIRTUAL_DEVICE');
    expect(target['avdName'], 'Pixel_9');
    expect(target['adbSerial'], 'emulator-5554');
    expect(target['minimumApiLevel'], 36);

    final priorPackage = _object(
      _object(promotion['deviceProvenance'])['expectedPriorPackage'],
    );
    expect(priorPackage['versionCode'], 1);
    expect(priorPackage['debuggable'], isTrue);
    expect(
      priorPackage['certificateSha256'],
      'B0B0EF9B348F5D474356AEB79182483B98829012FC25EB3EDCD517D11563C6D5',
    );

    final boundary = _object(promotion['programmeBoundary']);
    expect(boundary['pilotHandoutAuthorized'], isFalse);
    expect(boundary['stage2dF4Authorized'], isFalse);
    expect(boundary['unrestrictedDistributionAuthorized'], isFalse);

    final remoteBoundary = _object(promotion['expectedRemoteMutationBoundary']);
    expect(remoteBoundary['firebaseAuthenticationSessionCreated'], isTrue);
    expect(remoteBoundary['ownUserProfileHydrationPermitted'], isTrue);
    expect(remoteBoundary['ownUserFcmTokenClearOnSignOutPermitted'], isTrue);
    expect(remoteBoundary['readOnlyOwnUserDiagnosticPermitted'], isTrue);
    expect(remoteBoundary['otherFirestoreBusinessWritesAuthorized'], isFalse);
    expect(remoteBoundary['authMutationAuthorized'], isFalse);
    expect(remoteBoundary['firebaseConfigurationMutationAuthorized'], isFalse);
    expect(remoteBoundary['backendDeploymentAuthorized'], isFalse);

    final prohibited = _strings(promotion['prohibitedOperations']).join('\n');
    expect(prohibited, contains('pilot handout'));
    expect(prohibited, contains('physical device or a second emulator'));
    expect(prohibited, contains('Firebase App Distribution'));
    expect(prohibited, contains('rebuilding, resigning or modifying'));
  });

  test(
    'runtime harness fails closed around source, APK and target identity',
    () {
      final script =
          File(
            'tools/release/Invoke-Build5RuntimeValidation.ps1',
          ).readAsStringSync();

      for (final required in <String>[
        "'FinalizeInstall',",
        "'PrepareSignIn',",
        "'DiagnoseProfile',",
        'Get-FileHash -LiteralPath \$Path -Algorithm SHA256',
        "build-tools\\36.0.0\\aapt.exe",
        "build-tools\\36.0.0\\apksigner.bat",
        "'internal-release-signed-apk'",
        "'DIRECT_ADB_FROM_GOVERNED_LOCAL_CUSTODY'",
        "'fetch', '--quiet', 'origin', 'main'",
        'Install requires an exact clean main equal to origin/main.',
        'Existing package removal requires AllowDebugReplacement.',
        'Existing package is not the exact approved debuggable versionCode 1.',
        'Existing debug package signer SHA-256 is not approved.',
        'FinalizeInstall requires an exact clean main equal to origin/main.',
        'FinalizeInstall refuses to replace an existing install receipt.',
        'INTERRUPTED_AFTER_INSTALL_NOTIFICATION_PROMPT',
        'APPROVED_HOME_RESTORED_SESSION',
        'Allow CRM-III BAF Ops to send you notifications?',
        'permission_deny_button',
        'PrepareSignIn requires an exact clean main equal to origin/main.',
        'PrepareSignIn refuses to replace an existing sign-out receipt.',
        "//node[@content-desc='Sign Out']",
        'PASS_RESTORED_SESSION_CLEARED_READY_FOR_FRESH_GOOGLE_SIGN_IN',
        'DiagnoseProfile requires an exact clean main equal to origin/main.',
        'DiagnoseProfile refuses to replace an existing diagnostic receipt.',
        'PASS_PRIVACY_MINIMIZED_READ_ONLY_PROFILE_DIAGNOSTIC',
        'otherUserDocumentsRead',
        'remoteWritesPerformed',
        'Verify requires explicit restored-session sign-out evidence.',
        'Verify requires the governed profile diagnostic receipt.',
        'Profile diagnostic receipt SHA-256',
        'Verify requires the post-auth relaunch UI evidence.',
        'Post-auth relaunch UI SHA-256',
        'firstAttemptOwnProfileReadPermissionDenied',
        'futurePilotArtifactMustContainSourceRemediation',
        'Verify refuses to replace an existing runtime receipt.',
        'Sign-out evidence promotion SHA-256',
        'Assert-ExactInstalledRelease',
        "'install', '--no-streaming', \$apkFile",
        'Installed Build 5 package is unexpectedly debuggable.',
        "'uiautomator', 'dump'",
        'Sign in with Google',
        'Core modules',
        'PASS_EXACT_BUILD5_CONTROLLED_INTERNAL_INSTALL',
        'PASS_EXACT_PRODUCTION_SIGNED_GOOGLE_SIGN_IN_AND_APPROVED_USER_GATE',
      ]) {
        expect(script, contains(required), reason: required);
      }

      for (final forbidden in <String>[
        'firebase deploy',
        'gcloud ',
        'appdistribution:distribute',
        'play.google.com',
        'adb install-multiple',
      ]) {
        expect(
          script.toLowerCase(),
          isNot(contains(forbidden.toLowerCase())),
          reason: forbidden,
        );
      }
    },
  );

  test(
    'profile diagnostic retains schema evidence without identity values',
    () {
      final source =
          File('tools/release/diagnoseBuild5Profile.js').readAsStringSync();

      for (final required in <String>[
        'firebaseauth.users.get',
        '/accounts:lookup',
        '/documents/users/',
        'localIdSha256',
        'accountEmailRetained: false',
        'localIdRetained: false',
        'otherUserDocumentsRead: 0',
        'remoteWritesPerformed: 0',
        'firestore.googleapis.com',
        'UNENFORCED',
      ]) {
        expect(source, contains(required), reason: 'missing $required');
      }

      for (final forbidden in <String>[
        'accountEmail:',
        'localId:',
        'displayName:',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: 'found $forbidden');
      }
    },
  );
}
