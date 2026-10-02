import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/services/app_logger.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's generated native test channel is shipped with its existing
// platform dependency; this does not replace the Crashlytics Dart facade.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sentinel = 'PRIVATE_LOGGER_SENTINEL_73921';
const _channel = MethodChannel('plugins.flutter.io/firebase_crashlytics');
final _privateStack = StackTrace.fromString('''
#0 SafeService.read (package:crm3_baf_ops/core/safe.dart:12:3)
#1 $_sentinel (file:///private/$_sentinel.dart:2:1)
''');

final class _PrivateException implements Exception {
  @override
  String toString() => _sentinel;
}

class _CoreStub extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
    CoreInitializeResponse(
      name: '[DEFAULT]',
      options: CoreFirebaseOptions(
        apiKey: 'synthetic-test-key',
        appId: 'synthetic-test-app',
        messagingSenderId: '123',
        projectId: 'demo-logger-privacy',
      ),
      pluginConstants: {
        'plugins.flutter.io/firebase_crashlytics': {
          'isCrashlyticsCollectionEnabled': false,
        },
      },
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DebugPrintCallback originalPrint;
  late FlutterExceptionHandler originalPresent;
  late List<String> console;
  late List<MethodCall> calls;
  late List<FlutterErrorDetails> presented;
  late Set<String> failingMethods;

  Future<void> capture(FutureOr<void> Function() action) async {
    await runZoned(
      () async {
        await action();
        await pumpEventQueue();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => console.add(line),
      ),
    );
  }

  Future<void> initialize({bool collecting = true}) async {
    await capture(() => AppLogger.init(collectInDebug: collecting));
    expect(AppLogger.isInitialized, isTrue);
    expect(AppLogger.isCollecting, collecting);
    calls.clear();
    console.clear();
  }

  List<Map<dynamic, dynamic>> records() => calls
      .where((call) => call.method == 'Crashlytics#recordError')
      .map((call) => call.arguments as Map<dynamic, dynamic>)
      .toList();

  void expectPrivateSinks() {
    expect(console.join('\n'), isNot(contains(_sentinel)));
    expect(
      calls.map((call) => call.arguments).join('\n'),
      isNot(contains(_sentinel)),
    );
  }

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_CoreStub());
    await Firebase.initializeApp();
  });

  tearDownAll(() => TestFirebaseCoreHostApi.setUp(null));

  setUp(() {
    AppLogger.resetForTesting();
    originalPrint = debugPrint;
    originalPresent = FlutterError.presentError;
    console = [];
    calls = [];
    presented = [];
    failingMethods = {};
    debugPrint = (message, {wrapWidth}) => console.add(message ?? '');
    FlutterError.presentError = (details) {
      presented.add(details);
      debugPrint(details.exceptionAsString());
      debugPrint('${details.stack}');
      debugPrint(details.library);
      debugPrint('${details.context}');
      for (final diagnostic in details.informationCollector?.call() ?? []) {
        debugPrint('$diagnostic');
      }
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          if (failingMethods.contains(call.method)) {
            throw PlatformException(code: 'test-failure', message: _sentinel);
          }
          if (call.method == 'Crashlytics#setCrashlyticsCollectionEnabled') {
            return {
              'isCrashlyticsCollectionEnabled': call.arguments['enabled'],
            };
          }
          return null;
        });
  });

  tearDown(() {
    debugPrint = originalPrint;
    FlutterError.presentError = originalPresent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    AppLogger.resetForTesting();
  });

  test(
    'actual console and Crashlytics sinks redact all exception routes',
    () async {
      await initialize();
      await capture(() async {
        AppLogger.warning(
          _sentinel,
          error: _PrivateException(),
          stackTrace: _privateStack,
          context: const {'detail': _sentinel},
        );
        AppLogger.error(
          _sentinel,
          error: _PrivateException(),
          stackTrace: _privateStack,
        );
        await AppLogger.recordNonFatalError(
          _PrivateException(),
          _privateStack,
          reason: _sentinel,
        );
        await AppLogger.recordFatalError(
          _PrivateException(),
          _privateStack,
          reason: _sentinel,
        );
        expect(
          AppLogger.recordPlatformError(_PrivateException(), _privateStack),
          isTrue,
        );
        AppLogger.recordZoneError(_PrivateException(), _privateStack);
      });
      expectPrivateSinks();
      final sent = records();
      expect(sent, hasLength(6));
      expect(sent.map((record) => record['fatal']), [
        false,
        false,
        false,
        true,
        true,
        true,
      ]);
      for (final record in sent) {
        expect(
          record['exception'],
          'SanitizedCrashException<_PrivateException>',
        );
        expect(
          record['stackTraceElements'],
          contains(
            equals({
              'file': 'package:crm3_baf_ops/core/safe.dart',
              'line': '12',
              'method': 'read',
              'class': 'SafeService',
            }),
          ),
        );
      }
      expect(console.join('\n'), contains('<redacted-frame>'));
    },
  );

  for (final collecting in [false, true]) {
    test(
      'production framework presentation is private with collection=$collecting',
      () async {
        await initialize(collecting: collecting);
        var collectorCalls = 0;
        final details = FlutterErrorDetails(
          exception: _PrivateException(),
          stack: _privateStack,
          library: _sentinel,
          context: ErrorDescription(_sentinel),
          informationCollector: () {
            collectorCalls++;
            return [ErrorDescription(_sentinel)];
          },
        );
        await capture(
          () =>
              AppLogger.recordFlutterError(details, presentDebugDetails: false),
        );
        expectPrivateSinks();
        expect(presented, hasLength(1));
        expect(presented.single, isNot(same(details)));
        expect(presented.single.informationCollector, isNull);
        expect(presented.single.context, isNull);
        expect(collectorCalls, 0);
        expect(
          presented.single.exception.toString(),
          contains('_PrivateException'),
        );
        expect(presented.single.stack.toString(), contains('SafeService.read'));
        expect(records(), hasLength(collecting ? 1 : 0));
        if (collecting) expect(records().single['fatal'], isTrue);
      },
    );
  }

  test(
    'rich framework details remain debug-only and remote data stays private',
    () async {
      await initialize();
      final details = FlutterErrorDetails(
        exception: _PrivateException(),
        stack: _privateStack,
      );
      await capture(() => AppLogger.recordFlutterError(details));
      expect(kDebugMode, isTrue);
      expect(presented.single, same(details));
      expect(console.join('\n'), contains(_sentinel));
      expect(records().toString(), isNot(contains(_sentinel)));
    },
  );

  test(
    'production presentation preserves recoverable framework classification',
    () async {
      await initialize();
      await capture(() {
        AppLogger.recordFlutterError(
          FlutterErrorDetails(
            exception: const HttpException(_sentinel),
            stack: _privateStack,
            library: 'image resource service',
          ),
          presentDebugDetails: false,
        );
        AppLogger.recordFlutterError(
          FlutterErrorDetails(
            exception: _PrivateException(),
            stack: _privateStack,
            silent: true,
          ),
          presentDebugDetails: false,
        );
      });
      expectPrivateSinks();
      expect(records().map((record) => record['fatal']), [false, false]);
      expect(presented.last.silent, isTrue);
    },
  );

  test(
    'initialization SDK failure is private and leaves collection disabled',
    () async {
      failingMethods.add('Crashlytics#setCrashlyticsCollectionEnabled');
      await capture(() => AppLogger.init(collectInDebug: true));
      expectPrivateSinks();
      expect(AppLogger.isInitialized, isFalse);
      expect(AppLogger.isCollecting, isFalse);
      expect(calls, hasLength(1));
      expect(
        console.join('\n'),
        contains('SanitizedCrashException<FirebaseException>'),
      );
    },
  );

  test(
    'initialization rethrow retains original error for caller without printing it',
    () async {
      failingMethods.add('Crashlytics#setCrashlyticsCollectionEnabled');
      await capture(() async {
        await expectLater(
          AppLogger.init(collectInDebug: true, throwOnFailure: true),
          throwsA(
            isA<FirebaseException>().having(
              (error) => error.message,
              'original message',
              _sentinel,
            ),
          ),
        );
      });
      expectPrivateSinks();
      expect(AppLogger.isCollecting, isFalse);
    },
  );

  for (final operation in [
    'setUserContext',
    'clearUserContext',
    'setCustomKey',
  ]) {
    test(
      '$operation SDK failure is private without reentering the logger',
      () async {
        await initialize();
        failingMethods.add(
          operation == 'setCustomKey'
              ? 'Crashlytics#setCustomKey'
              : 'Crashlytics#setUserIdentifier',
        );
        await capture(() async {
          switch (operation) {
            case 'setUserContext':
              await AppLogger.setUserContext(
                uid: _sentinel,
                roles: [_sentinel],
                isApproved: true,
              );
            case 'clearUserContext':
              await AppLogger.clearUserContext();
            case 'setCustomKey':
              await AppLogger.setCustomKey('detail', _sentinel);
          }
        });
        expectPrivateSinks();
        expect(calls, hasLength(1));
        expect(
          console.join('\n'),
          contains('SanitizedCrashException<FirebaseException>'),
        );
      },
    );
  }

  for (final method in ['Crashlytics#recordError', 'Crashlytics#log']) {
    test('$method failure uses a private nonrecursive fallback', () async {
      await initialize();
      failingMethods.add(method);
      await capture(() {
        if (method == 'Crashlytics#recordError') {
          AppLogger.error(
            _sentinel,
            error: _PrivateException(),
            stackTrace: _privateStack,
          );
        } else {
          AppLogger.breadcrumb(_sentinel, context: const {'detail': _sentinel});
        }
      });
      expectPrivateSinks();
      expect(calls, hasLength(1));
      expect(
        console.join('\n'),
        contains(
          'Crashlytics logging failed: SanitizedCrashException<FirebaseException>',
        ),
      );
    });
  }
}
