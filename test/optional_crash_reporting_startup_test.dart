import 'package:crm3_baf_ops/core/services/crash_reporting_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reporting failure retains local handlers and permits startup to continue',
    () async {
      final steps = <String>[];
      await initializeOptionalCrashReporting(
        installHandlers: () => steps.add('localHandlers'),
        initialize: () async {
          steps.add('reporting');
          throw StateError(
            'private plant evidence must not enter health metadata',
          );
        },
      );
      steps.add('localDatabase');
      expect(steps, ['localHandlers', 'reporting', 'localDatabase']);
      expect(crashReportingStartupHealth.toMap(), {
        'status': 'unavailable',
        'errorType': 'StateError',
      });
    },
  );

  test(
    'successful initialization replaces a previous degraded health result',
    () async {
      await initializeOptionalCrashReporting(
        installHandlers: () {},
        initialize: () async => throw StateError('temporary'),
      );
      await initializeOptionalCrashReporting(
        installHandlers: () {},
        initialize: () async {},
      );
      expect(crashReportingStartupHealth.toMap(), {'status': 'ready'});
    },
  );

  test('optional handler setup failure is also contained', () async {
    var initializeCalls = 0;
    await initializeOptionalCrashReporting(
      installHandlers: () => throw StateError('platform unavailable'),
      initialize: () async => initializeCalls++,
    );
    expect(initializeCalls, 0);
    expect(
      crashReportingStartupHealth.status,
      CrashReportingStartupStatus.unavailable,
    );
  });
}
