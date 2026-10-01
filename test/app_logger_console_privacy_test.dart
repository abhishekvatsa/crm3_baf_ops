import 'package:crm3_baf_ops/core/services/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _sentinel = 'PRIVATE_CONSOLE_SENTINEL_73921';
final _privateStack = StackTrace.fromString('''
#0 SafeService.read (package:crm3_baf_ops/core/safe.dart:12:3)
#1 $_sentinel (file:///private/$_sentinel.dart:2:1)
''');

final class _PrivateException implements Exception {
  @override
  String toString() => _sentinel;
}

void main() {
  // These tests deliberately use the uninitialized logger and only its existing
  // public API, so they can also demonstrate the defect on the original source.
  late DebugPrintCallback originalPrint;
  late List<String> console;

  setUp(() {
    originalPrint = debugPrint;
    console = [];
    debugPrint = (message, {wrapWidth}) => console.add(message ?? '');
  });
  tearDown(() => debugPrint = originalPrint);

  final routes = <String, void Function()>{
    'warning': () => AppLogger.warning(
      _sentinel,
      error: _PrivateException(),
      stackTrace: _privateStack,
      context: const {'detail': _sentinel},
    ),
    'error': () => AppLogger.error(
      _sentinel,
      error: _PrivateException(),
      stackTrace: _privateStack,
    ),
    'platform': () =>
        AppLogger.recordPlatformError(_PrivateException(), _privateStack),
    'zone': () => AppLogger.recordZoneError(_PrivateException(), _privateStack),
  };

  for (final route in routes.entries) {
    test('${route.key} console stays private before collection starts', () {
      expect(AppLogger.isCollecting, isFalse);
      route.value();
      final text = console.join('\n');
      expect(text, isNot(contains(_sentinel)));
      expect(text, contains('SanitizedCrashException<_PrivateException>'));
      expect(text, contains('SafeService.read'));
      expect(text, contains('<redacted-frame>'));
    });
  }
}
