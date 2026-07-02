import 'package:crm3_baf_ops/core/security/app_check_bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Stage 2D App Check provider planning', () {
    test('disabled source gate remains a no-op on every platform', () {
      final plan = resolveCrm3AppCheckPlan(
        enabled: false,
        debugMode: false,
        web: false,
        platform: TargetPlatform.android,
      );

      expect(plan.enabled, isFalse);
      expect(plan.provider, Crm3AppCheckProviderKind.disabled);
    });

    test('Android uses debug only in debug builds', () {
      final debugPlan = resolveCrm3AppCheckPlan(
        enabled: true,
        debugMode: true,
        web: false,
        platform: TargetPlatform.android,
        debugToken: 'debug-token',
      );
      final releasePlan = resolveCrm3AppCheckPlan(
        enabled: true,
        debugMode: false,
        web: false,
        platform: TargetPlatform.android,
      );

      expect(debugPlan.provider, Crm3AppCheckProviderKind.androidDebug);
      expect(debugPlan.debugToken, 'debug-token');
      expect(
        releasePlan.provider,
        Crm3AppCheckProviderKind.androidPlayIntegrity,
      );
      expect(releasePlan.debugToken, isNull);
    });

    test('Apple uses App Attest with DeviceCheck fallback in release', () {
      final iosPlan = resolveCrm3AppCheckPlan(
        enabled: true,
        debugMode: false,
        web: false,
        platform: TargetPlatform.iOS,
      );
      final macosPlan = resolveCrm3AppCheckPlan(
        enabled: true,
        debugMode: false,
        web: false,
        platform: TargetPlatform.macOS,
      );

      expect(
        iosPlan.provider,
        Crm3AppCheckProviderKind.appleAppAttestWithDeviceCheckFallback,
      );
      expect(macosPlan.provider, iosPlan.provider);
    });

    test('web debug does not require a reCAPTCHA key', () {
      final plan = resolveCrm3AppCheckPlan(
        enabled: true,
        debugMode: true,
        web: true,
        platform: TargetPlatform.android,
      );

      expect(plan.platform, Crm3AppCheckRuntimePlatform.web);
      expect(plan.provider, Crm3AppCheckProviderKind.webDebug);
      expect(plan.webRecaptchaV3SiteKey, isNull);
    });

    test('web release fails closed without a reCAPTCHA v3 site key', () {
      expect(
        () => resolveCrm3AppCheckPlan(
          enabled: true,
          debugMode: false,
          web: true,
          platform: TargetPlatform.android,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('web release records the exact reCAPTCHA v3 site key', () {
      final plan = resolveCrm3AppCheckPlan(
        enabled: true,
        debugMode: false,
        web: true,
        platform: TargetPlatform.android,
        webRecaptchaV3SiteKey: 'site-key',
      );

      expect(plan.provider, Crm3AppCheckProviderKind.webRecaptchaV3);
      expect(plan.webRecaptchaV3SiteKey, 'site-key');
    });

    test('Windows is debug-only and release use fails closed', () {
      final debugPlan = resolveCrm3AppCheckPlan(
        enabled: true,
        debugMode: true,
        web: false,
        platform: TargetPlatform.windows,
      );
      expect(debugPlan.provider, Crm3AppCheckProviderKind.windowsDebug);

      expect(
        () => resolveCrm3AppCheckPlan(
          enabled: true,
          debugMode: false,
          web: false,
          platform: TargetPlatform.windows,
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('unsupported desktop targets fail closed when enabled', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          () => resolveCrm3AppCheckPlan(
            enabled: true,
            debugMode: false,
            web: false,
            platform: platform,
          ),
          throwsA(isA<UnsupportedError>()),
          reason: platform.name,
        );
      }
    });
  });
}
