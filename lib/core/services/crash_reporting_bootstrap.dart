// FILE: lib/core/services/crash_reporting_bootstrap.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'app_logger.dart';

/// Installs global error handlers for Flutter framework, platform-dispatcher,
/// and root-zone failures.
///
/// This deliberately does NOT override global debugPrint. Existing debug logs
/// may contain plant-floor details, so breadcrumbs should be added through
/// AppLogger.info/warning/error at reviewed call sites only.
void installGlobalCrashReportingHandlers() {
  FlutterError.onError = AppLogger.recordFlutterError;
  PlatformDispatcher.instance.onError = AppLogger.recordPlatformError;
}

void runCrashReportingZoned(Future<void> Function() body) {
  runZonedGuarded<Future<void>>(
    body,
    AppLogger.recordZoneError,
  );
}
