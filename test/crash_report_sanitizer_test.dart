import 'package:crm3_baf_ops/core/services/crash_report_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

final class _SecretBearingException implements Exception {
  @override
  String toString() {
    return 'operator=person@example.com token=abc12345678901234567890123456789 '
        'url=https://example.invalid/private';
  }
}

void main() {
  group('S-08 crash report sanitizer', () {
    test('exception transport retains type but never the original message', () {
      final original = _SecretBearingException();
      final sanitized = CrashReportSanitizer.error(original);
      final transported = sanitized.toString();

      expect(transported, contains('_SecretBearingException'));
      expect(transported, isNot(contains('person@example.com')));
      expect(transported, isNot(contains('abc12345678901234567890123456789')));
      expect(transported, isNot(contains('example.invalid')));
      expect(transported, isNot(contains(original.toString())));
    });

    test('stack transport retains only package and Dart source frames', () {
      final original = StackTrace.fromString('''
#0 SafeService.execute (package:crm3_baf_ops/core/safe.dart:12:3)
#1 SecretService.read (file:///C:/Users/operator/private.dart:22:4)
#2 token=abc12345678901234567890123456789
#3 person@example.com https://example.invalid/private
<asynchronous suspension>
''');

      final transported = CrashReportSanitizer.stackTrace(original).toString();

      expect(
        transported,
        contains(
          '#0 SafeService.execute '
          '(package:crm3_baf_ops/core/safe.dart:12:3)',
        ),
      );
      expect(transported, contains('<redacted-frame>'));
      expect(transported, contains('<asynchronous suspension>'));
      expect(transported, isNot(contains('C:/Users')));
      expect(transported, isNot(contains('operator')));
      expect(transported, isNot(contains('person@example.com')));
      expect(transported, isNot(contains('abc12345678901234567890123456789')));
      expect(transported, isNot(contains('example.invalid')));
    });

    test('arbitrary text and user identifiers become opaque fingerprints', () {
      const secret = 'person@example.com bearer-secret-token';

      final event = CrashReportSanitizer.eventId(secret);
      final context = CrashReportSanitizer.contextValue(secret);
      final uid = CrashReportSanitizer.userIdentifier(secret);

      expect(event, startsWith('event_'));
      expect(context, isA<String>());
      expect(uid, startsWith('uid_'));
      expect(event, isNot(contains(secret)));
      expect('$context', isNot(contains(secret)));
      expect(uid, isNot(contains(secret)));
      expect(event, CrashReportSanitizer.eventId(secret));
      expect(context, CrashReportSanitizer.contextValue(secret));
      expect(uid, CrashReportSanitizer.userIdentifier(secret));
    });

    test('numeric and boolean telemetry remains directly queryable', () {
      expect(CrashReportSanitizer.contextValue(true), isTrue);
      expect(CrashReportSanitizer.contextValue(42), 42);
      expect(CrashReportSanitizer.contextValue(1.5), 1.5);
      expect(CrashReportSanitizer.contextValue(null), '');
    });

    test('stack output is bounded and missing stacks fail closed', () {
      final oversized = StackTrace.fromString(
        List<String>.generate(
          100,
          (index) =>
              '#$index Frame$index '
              '(package:crm3_baf_ops/core/frame.dart:$index:1)',
        ).join('\n'),
      );

      final lines = CrashReportSanitizer.stackTrace(
        oversized,
      ).toString().trim().split('\n');
      expect(lines, hasLength(64));
      expect(
        CrashReportSanitizer.stackTrace(null).toString(),
        contains('<stack-unavailable>'),
      );
    });
  });
}
