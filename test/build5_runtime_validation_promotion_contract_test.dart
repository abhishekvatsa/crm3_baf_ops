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
    expect(remoteBoundary['otherFirestoreBusinessWritesAuthorized'], isFalse);
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
        'Verify requires explicit restored-session sign-out evidence.',
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
}
