// FILE: lib/core/services/app_logger.dart

import 'dart:async' show Future, unawaited;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'crash_report_sanitizer.dart';

/// Sanitized Crashlytics/logging facade for CRM-III BAF Ops.
///
/// This is intentionally conservative for plant-floor evidence safety:
/// - no email/name/module-response/ticket-description logging;
/// - no raw exception object, message, stack or arbitrary text value upload;
/// - only coarse app/sync/startup/auth state is attached as custom keys;
/// - debug builds keep console output but do not upload Crashlytics events;
/// - web is a no-op because Firebase Crashlytics does not support Flutter web.
class AppLogger {
  AppLogger._();

  static bool _initialized = false;
  static bool _collecting = false;

  static bool get isInitialized => _initialized;

  static bool get isCollecting => _collecting;

  @visibleForTesting
  static void resetForTesting() {
    assert(() {
      _initialized = false;
      _collecting = false;
      return true;
    }());
  }

  /// Configure Crashlytics collection after Firebase.initializeApp().
  ///
  /// Defaults are production-safe: collect only in release mobile builds.
  /// Profile collection can be explicitly enabled for QA builds.
  static Future<void> init({
    bool collectInDebug = false,
    bool collectInProfile = false,
    bool collectInRelease = true,
    bool throwOnFailure = false,
  }) async {
    if (_initialized) return;

    if (kIsWeb) {
      _collecting = false;
      _initialized = true;
      debugPrint('Crashlytics disabled on Flutter web.');
      return;
    }

    final shouldCollect =
        (kDebugMode && collectInDebug) ||
        (kProfileMode && collectInProfile) ||
        (kReleaseMode && collectInRelease);

    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        shouldCollect,
      );
      _collecting = shouldCollect;
      _initialized = true;
      await setCustomKeys({
        'app': 'crm3_baf_ops',
        'build_mode': kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug',
        'platform': defaultTargetPlatform.name,
        'crashlytics_collecting': shouldCollect,
      });
      breadcrumb('Crash reporting configured.');
    } catch (error, stackTrace) {
      _collecting = false;
      _initialized = false;
      _printFailure('AppLogger.init failed', error, stackTrace);
      if (throwOnFailure) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  /// Attach a privacy-safe user context. Do not pass email/name here.
  static Future<void> setUserContext({
    required String uid,
    required Iterable<String> roles,
    required bool isApproved,
  }) async {
    if (!_collecting) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(
        CrashReportSanitizer.userIdentifier(uid),
      );
      await setCustomKeys({
        'user_approved': isApproved,
        'user_roles': roles.join(','),
      });
    } catch (error, stackTrace) {
      _printFailure('AppLogger.setUserContext failed', error, stackTrace);
    }
  }

  static Future<void> clearUserContext() async {
    if (!_collecting) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
      await setCustomKeys(const {'user_approved': false, 'user_roles': ''});
    } catch (error, stackTrace) {
      _printFailure('AppLogger.clearUserContext failed', error, stackTrace);
    }
  }

  static Future<void> setCustomKey(String key, Object? value) async {
    await setCustomKeys({key: value});
  }

  static Future<void> setCustomKeys(Map<String, Object?> keys) async {
    if (!_collecting || keys.isEmpty) return;

    for (final entry in keys.entries) {
      final key = _safeKey(entry.key);
      final value = _safeCrashlyticsValue(entry.value);
      try {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      } catch (error, stackTrace) {
        _printFailure('AppLogger.setCustomKey failed', error, stackTrace);
      }
    }
  }

  static void breadcrumb(String message, {Map<String, Object?>? context}) {
    final safeMessage = _composeMessage(message, context);
    if (!_collecting) return;

    _safeFireAndForget(() {
      return FirebaseCrashlytics.instance.log(safeMessage);
    });
  }

  static void info(String message, {Map<String, Object?>? context}) {
    final safeMessage = _composeMessage(message, context);
    debugPrint('ℹ️ $safeMessage');
    breadcrumb('INFO $safeMessage');
  }

  /// Records a non-fatal warning. Use this for operationally important failures
  /// where the app remains usable, such as sync partial failures.
  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    final safeMessage = _composeMessage(message, context);
    final safeError = error == null
        ? const SanitizedCrashException('ReportedWarning')
        : CrashReportSanitizer.error(error);
    final suppliedStack = stackTrace == null
        ? null
        : CrashReportSanitizer.stackTrace(stackTrace);
    debugPrint('⚠️ $safeMessage${error == null ? '' : ' → $safeError'}');
    if (suppliedStack != null) debugPrint('$suppliedStack');

    if (!_collecting) return;
    final safeStack =
        suppliedStack ?? CrashReportSanitizer.stackTrace(StackTrace.current);

    _safeFireAndForget(() {
      return FirebaseCrashlytics.instance.recordError(
        safeError,
        safeStack,
        reason: safeMessage,
        information: _contextToInformation(context),
        fatal: false,
      );
    });
  }

  static void error(
    String message, {
    required Object error,
    StackTrace? stackTrace,
    bool fatal = false,
    Map<String, Object?>? context,
  }) {
    final safeMessage = _composeMessage(message, context);
    final safeError = CrashReportSanitizer.error(error);
    final suppliedStack = stackTrace == null
        ? null
        : CrashReportSanitizer.stackTrace(stackTrace);
    debugPrint('❌ $safeMessage → $safeError');
    if (suppliedStack != null) debugPrint('$suppliedStack');

    if (!_collecting) return;
    final safeStack =
        suppliedStack ?? CrashReportSanitizer.stackTrace(StackTrace.current);

    _safeFireAndForget(() {
      return FirebaseCrashlytics.instance.recordError(
        safeError,
        safeStack,
        reason: safeMessage,
        information: _contextToInformation(context),
        fatal: fatal,
      );
    });
  }

  static Future<void> recordNonFatalError(
    Object error,
    StackTrace stackTrace, {
    required String reason,
    Map<String, Object?> context = const {},
  }) async {
    warning(reason, error: error, stackTrace: stackTrace, context: context);
  }

  static Future<void> recordFatalError(
    Object error,
    StackTrace stackTrace, {
    required String reason,
    Map<String, Object?> context = const {},
  }) async {
    AppLogger.error(
      reason,
      error: error,
      stackTrace: stackTrace,
      fatal: true,
      context: context,
    );
  }

  /// Rich framework diagnostics are local to debug builds. Setting
  /// [presentDebugDetails] to false also exercises production presentation in
  /// development; setting it to true can never enable raw release output.
  static void recordFlutterError(
    FlutterErrorDetails details, {
    bool presentDebugDetails = true,
  }) {
    final safeError = CrashReportSanitizer.error(details.exception);
    final safeStack = CrashReportSanitizer.stackTrace(details.stack);
    FlutterError.presentError(
      kDebugMode && presentDebugDetails
          ? details
          : FlutterErrorDetails(
              exception: safeError,
              stack: safeStack,
              library: 'application',
              silent: details.silent,
            ),
    );

    if (!_collecting) return;

    _safeFireAndForget(() {
      final fatal = flutterFrameworkErrorIsFatal(details);
      return FirebaseCrashlytics.instance.recordError(
        safeError,
        safeStack,
        reason: _composeMessage('flutter_framework_uncaught', {
          'library': details.library,
          'flutter_error_recoverable': !fatal,
        }),
        fatal: fatal,
      );
    });
  }

  static bool recordPlatformError(Object error, StackTrace stackTrace) {
    AppLogger.error(
      'platform_dispatcher_uncaught',
      error: error,
      stackTrace: stackTrace,
      fatal: true,
      context: const {'app_error_boundary': 'platform_dispatcher'},
    );
    return true;
  }

  static void recordZoneError(Object error, StackTrace stackTrace) {
    AppLogger.error(
      'root_zone_uncaught',
      error: error,
      stackTrace: stackTrace,
      fatal: true,
      context: const {'app_error_boundary': 'root_zone'},
    );
  }

  static void _safeFireAndForget(Future<void> Function() operation) {
    try {
      unawaited(
        Future<void>(() async {
          try {
            await operation();
          } catch (error, stackTrace) {
            _debugLoggingFailure(error, stackTrace);
          }
        }),
      );
    } catch (error, stackTrace) {
      _debugLoggingFailure(error, stackTrace);
    }
  }

  static void _debugLoggingFailure(Object error, StackTrace stackTrace) {
    // Do not call AppLogger from here. This is the last-resort escape hatch
    // that prevents Crashlytics/logging failures from recursively re-entering
    // the root-zone error handlers.
    _printFailure('Crashlytics logging failed', error, stackTrace);
  }

  static void _printFailure(String event, Object error, StackTrace stackTrace) {
    debugPrint('⚠️ $event: ${CrashReportSanitizer.error(error)}');
    debugPrint('${CrashReportSanitizer.stackTrace(stackTrace)}');
  }

  static String _safeKey(String key) {
    final cleaned = key
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final fallback = cleaned.isEmpty ? 'unknown_key' : cleaned;
    return fallback.length <= 64 ? fallback : fallback.substring(0, 64);
  }

  static Object _safeCrashlyticsValue(Object? value) {
    return CrashReportSanitizer.contextValue(value);
  }

  static String _composeMessage(String message, Map<String, Object?>? context) {
    final safeMessage = CrashReportSanitizer.eventId(message);
    if (context == null || context.isEmpty) return safeMessage;

    final safeContext = context.entries
        .map(
          (entry) =>
              '${_safeKey(entry.key)}=${_safeCrashlyticsValue(entry.value)}',
        )
        .join(' ');
    return '$safeMessage [$safeContext]';
  }

  static List<Object> _contextToInformation(Map<String, Object?>? context) {
    if (context == null || context.isEmpty) return const [];
    return context.entries
        .map(
          (entry) =>
              '${_safeKey(entry.key)}: ${_safeCrashlyticsValue(entry.value)}',
        )
        .toList(growable: false);
  }
}

@visibleForTesting
bool flutterFrameworkErrorIsFatal(FlutterErrorDetails details) {
  if (details.silent) return false;
  if (details.library != 'image resource service') return true;
  return !const <String>{
    'HandshakeException',
    'HttpException',
    'NetworkImageLoadException',
    'SocketException',
  }.contains(details.exception.runtimeType.toString());
}
