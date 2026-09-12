// FILE: lib/core/services/crash_reporting_bootstrap.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'crash_report_sanitizer.dart';

enum CrashReportingStartupStatus { notAttempted, ready, unavailable }

class CrashReportingStartupHealth {
  const CrashReportingStartupHealth(this.status, {this.errorType});

  final CrashReportingStartupStatus status;
  final String? errorType;

  Map<String, Object?> toMap() => {
    'status': status.name,
    if (errorType != null) 'errorType': errorType,
  };
}

CrashReportingStartupHealth _startupHealth = const CrashReportingStartupHealth(
  CrashReportingStartupStatus.notAttempted,
);

CrashReportingStartupHealth get crashReportingStartupHealth => _startupHealth;

/// Only optional reporting belongs inside this boundary. Firebase, authority,
/// App Check and local database integrity retain their required startup gates.
Future<void> initializeOptionalCrashReporting({
  required Future<void> Function() initialize,
  void Function() installHandlers = installGlobalCrashReportingHandlers,
}) async {
  try {
    // AppLogger's handlers also report locally when collection is unavailable.
    installHandlers();
    await initialize();
    _startupHealth = const CrashReportingStartupHealth(
      CrashReportingStartupStatus.ready,
    );
  } catch (error) {
    _startupHealth = CrashReportingStartupHealth(
      CrashReportingStartupStatus.unavailable,
      errorType: CrashReportSanitizer.error(error).errorType,
    );
    debugPrint(
      'Optional crash reporting is unavailable (${_startupHealth.errorType}).',
    );
  }
}

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
  runZonedGuarded<Future<void>>(body, AppLogger.recordZoneError);
}
