import 'dart:io';

import 'package:crm3_baf_ops/core/services/app_logger.dart';
import 'package:crm3_baf_ops/core/services/global_pull_cursor_store.dart';
import 'package:crm3_baf_ops/core/services/global_pull_protocol.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runtime crash classification', () {
    test('network image failures remain nonfatal', () {
      const details = FlutterErrorDetails(
        exception: HttpException('remote avatar unavailable'),
        library: 'image resource service',
      );

      expect(flutterFrameworkErrorIsFatal(details), isFalse);
      expect(
        flutterFrameworkErrorIsFatal(
          FlutterErrorDetails(exception: StateError('broken state')),
        ),
        isTrue,
      );
    });

    test('silent Flutter diagnostics remain nonfatal', () {
      expect(
        flutterFrameworkErrorIsFatal(
          FlutterErrorDetails(
            exception: StateError('silent framework diagnostic'),
            silent: true,
          ),
        ),
        isFalse,
      );
    });

    test('cursor and protocol failures stop automatic retry loops', () {
      expect(
        syncFailureLikelyPermanent(
          const GlobalPullCursorException(
            'Knowledge row could not be decoded.',
            reasonCode: 'domain-record-processing-failed',
          ),
        ),
        isTrue,
      );
      expect(
        syncFailureLikelyPermanent(
          const GlobalPullProtocolException(
            'Authority receipt is incompatible.',
            reasonCode: 'authority-protocol-version-invalid',
          ),
        ),
        isTrue,
      );
      expect(syncFailureLikelyPermanent(StateError('temporary')), isFalse);
    });

    test('sync diagnostics expose only governed reason and domain keys', () {
      final context = syncFailureDiagnosticContext(
        const GlobalPullCursorException(
          'Sensitive message must not become telemetry.',
          reasonCode: 'domain-record-processing-failed',
        ),
        pullDomain: GlobalPullDomain.knowledgeBase,
      );

      expect(context['sync_pull_domain_knowledge_base'], isTrue);
      expect(
        context['sync_cursor_reason_domain-record-processing-failed'],
        isTrue,
      );
      expect(context.toString(), isNot(contains('Sensitive message')));
    });

    test('global pull retries one authenticated call after token refresh', () {
      final source = File(
        'lib/core/services/global_pull_protocol.dart',
      ).readAsStringSync();
      final firstCall = source.indexOf('result = await callable.call();');
      final refresh = source.indexOf('await currentUser.getIdToken(true);');
      final retry = source.indexOf(
        'result = await callable.call();',
        firstCall + 1,
      );

      expect(firstCall, greaterThanOrEqualTo(0));
      expect(refresh, greaterThan(firstCall));
      expect(retry, greaterThan(refresh));
      expect(source, contains("error.code != 'unauthenticated'"));
    });
  });
}
