import 'dart:io';

import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('current app-user token race recovery', () {
    test('retries only the first same-uid permission denial', () {
      expect(
        shouldRetryCurrentAppUserPermissionDenied(
          errorCode: 'permission-denied',
          authenticatedUid: 'approved-user',
          expectedUid: 'approved-user',
          alreadyRetried: false,
        ),
        isTrue,
      );

      for (final input in <
        ({String errorCode, String? authenticatedUid, bool alreadyRetried})
      >[
        (
          errorCode: 'unavailable',
          authenticatedUid: 'approved-user',
          alreadyRetried: false,
        ),
        (
          errorCode: 'permission-denied',
          authenticatedUid: 'different-user',
          alreadyRetried: false,
        ),
        (
          errorCode: 'permission-denied',
          authenticatedUid: null,
          alreadyRetried: false,
        ),
        (
          errorCode: 'permission-denied',
          authenticatedUid: 'approved-user',
          alreadyRetried: true,
        ),
      ]) {
        expect(
          shouldRetryCurrentAppUserPermissionDenied(
            errorCode: input.errorCode,
            authenticatedUid: input.authenticatedUid,
            expectedUid: 'approved-user',
            alreadyRetried: input.alreadyRetried,
          ),
          isFalse,
        );
      }
    });

    test('profile subscription is id-token gated and fail-closed', () {
      final source =
          File(
            'lib/features/auth/providers/auth_provider.dart',
          ).readAsStringSync();

      expect(source, contains('auth.idTokenChanges().asyncExpand'));
      expect(source, contains('await user.getIdToken(true);'));
      expect(source, contains("errorCode == 'permission-denied'"));
      expect(source, contains('authenticatedUid == expectedUid'));
      expect(source, contains('alreadyRetried: retriedAfterTokenRefresh'));
      expect(source, contains('rethrow;'));
    });
  });
}
