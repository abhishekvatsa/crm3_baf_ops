import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const bool crm3AppCheckEnabled = bool.fromEnvironment(
  'CRM3_APP_CHECK_ENABLED',
  defaultValue: false,
);

const String crm3AppCheckWebRecaptchaV3SiteKey = String.fromEnvironment(
  'CRM3_APP_CHECK_WEB_RECAPTCHA_V3_SITE_KEY',
);

const String crm3AppCheckDebugToken = String.fromEnvironment(
  'CRM3_APP_CHECK_DEBUG_TOKEN',
);

enum Crm3AppCheckRuntimePlatform { web, android, apple, windows, unsupported }

enum Crm3AppCheckProviderKind {
  disabled,
  webDebug,
  webRecaptchaV3,
  androidDebug,
  androidPlayIntegrity,
  appleDebug,
  appleAppAttestWithDeviceCheckFallback,
  windowsDebug,
}

class Crm3AppCheckPlan {
  final bool enabled;
  final Crm3AppCheckRuntimePlatform platform;
  final Crm3AppCheckProviderKind provider;
  final String? webRecaptchaV3SiteKey;
  final String? debugToken;

  const Crm3AppCheckPlan({
    required this.enabled,
    required this.platform,
    required this.provider,
    this.webRecaptchaV3SiteKey,
    this.debugToken,
  });
}

Crm3AppCheckPlan resolveCrm3AppCheckPlan({
  required bool enabled,
  required bool debugMode,
  required bool web,
  required TargetPlatform platform,
  String webRecaptchaV3SiteKey = '',
  String debugToken = '',
}) {
  final cleanedDebugToken = _clean(debugToken);

  if (!enabled) {
    return const Crm3AppCheckPlan(
      enabled: false,
      platform: Crm3AppCheckRuntimePlatform.unsupported,
      provider: Crm3AppCheckProviderKind.disabled,
    );
  }

  if (web) {
    if (debugMode) {
      return Crm3AppCheckPlan(
        enabled: true,
        platform: Crm3AppCheckRuntimePlatform.web,
        provider: Crm3AppCheckProviderKind.webDebug,
        debugToken: cleanedDebugToken,
      );
    }

    final siteKey = _clean(webRecaptchaV3SiteKey);
    if (siteKey == null) {
      throw StateError(
        'CRM3_APP_CHECK_WEB_RECAPTCHA_V3_SITE_KEY is required when '
        'CRM3_APP_CHECK_ENABLED=true for a non-debug web build.',
      );
    }

    return Crm3AppCheckPlan(
      enabled: true,
      platform: Crm3AppCheckRuntimePlatform.web,
      provider: Crm3AppCheckProviderKind.webRecaptchaV3,
      webRecaptchaV3SiteKey: siteKey,
    );
  }

  switch (platform) {
    case TargetPlatform.android:
      return Crm3AppCheckPlan(
        enabled: true,
        platform: Crm3AppCheckRuntimePlatform.android,
        provider:
            debugMode
                ? Crm3AppCheckProviderKind.androidDebug
                : Crm3AppCheckProviderKind.androidPlayIntegrity,
        debugToken: debugMode ? cleanedDebugToken : null,
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return Crm3AppCheckPlan(
        enabled: true,
        platform: Crm3AppCheckRuntimePlatform.apple,
        provider:
            debugMode
                ? Crm3AppCheckProviderKind.appleDebug
                : Crm3AppCheckProviderKind
                    .appleAppAttestWithDeviceCheckFallback,
        debugToken: debugMode ? cleanedDebugToken : null,
      );
    case TargetPlatform.windows:
      if (!debugMode) {
        throw UnsupportedError(
          'Firebase App Check 0.4.5 supports only the debug provider on '
          'Windows. CRM3 release builds must not use a debug provider. '
          'Do not enable callable enforcement for Windows clients until a '
          'governed custom attestation path exists.',
        );
      }
      return Crm3AppCheckPlan(
        enabled: true,
        platform: Crm3AppCheckRuntimePlatform.windows,
        provider: Crm3AppCheckProviderKind.windowsDebug,
        debugToken: cleanedDebugToken,
      );
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      throw UnsupportedError(
        'Firebase App Check is not configured for ${platform.name}.',
      );
  }
}

Future<Crm3AppCheckPlan> activateCrm3AppCheck({
  FirebaseAppCheck? appCheck,
  bool enabled = crm3AppCheckEnabled,
  bool debugMode = kDebugMode,
  bool web = kIsWeb,
  TargetPlatform? platformOverride,
  String webRecaptchaV3SiteKey = crm3AppCheckWebRecaptchaV3SiteKey,
  String debugToken = crm3AppCheckDebugToken,
}) async {
  final plan = resolveCrm3AppCheckPlan(
    enabled: enabled,
    debugMode: debugMode,
    web: web,
    platform: platformOverride ?? defaultTargetPlatform,
    webRecaptchaV3SiteKey: webRecaptchaV3SiteKey,
    debugToken: debugToken,
  );

  if (!plan.enabled) {
    return plan;
  }

  final client = appCheck ?? FirebaseAppCheck.instance;

  switch (plan.provider) {
    case Crm3AppCheckProviderKind.webDebug:
      await client.activate(
        providerWeb: WebDebugProvider(debugToken: plan.debugToken),
      );
      break;
    case Crm3AppCheckProviderKind.webRecaptchaV3:
      await client.activate(
        providerWeb: ReCaptchaV3Provider(plan.webRecaptchaV3SiteKey!),
      );
      break;
    case Crm3AppCheckProviderKind.androidDebug:
      await client.activate(
        providerAndroid: AndroidDebugProvider(debugToken: plan.debugToken),
      );
      break;
    case Crm3AppCheckProviderKind.androidPlayIntegrity:
      await client.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
      );
      break;
    case Crm3AppCheckProviderKind.appleDebug:
      await client.activate(
        providerApple: AppleDebugProvider(debugToken: plan.debugToken),
      );
      break;
    case Crm3AppCheckProviderKind.appleAppAttestWithDeviceCheckFallback:
      await client.activate(
        providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      break;
    case Crm3AppCheckProviderKind.windowsDebug:
      await client.activate(
        providerWindows: WindowsDebugProvider(debugToken: plan.debugToken),
      );
      break;
    case Crm3AppCheckProviderKind.disabled:
      break;
  }

  return plan;
}

String? _clean(String value) {
  final cleaned = value.trim();
  return cleaned.isEmpty ? null : cleaned;
}
