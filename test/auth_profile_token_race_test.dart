import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('current app-user token race recovery', () {
    test('same-uid token re-emission cannot reopen the retry budget', () async {
      final budget = CurrentAppUserPermissionRetryBudget();
      final decisions = <bool>[];

      await for (final uid in Stream<String?>.fromIterable(const [
        'approved-user',
        'approved-user',
      ])) {
        budget.observeAuthEvent(uid);
        decisions.add(
          budget.tryClaimPermissionDeniedRetry(
            errorCode: 'permission-denied',
            authenticatedUid: uid,
            expectedUid: 'approved-user',
          ),
        );
      }

      expect(decisions, [isTrue, isFalse]);
    });

    test('sign-out starts a new retry budget for a later session', () {
      final budget = CurrentAppUserPermissionRetryBudget();
      budget.observeAuthEvent('approved-user');
      expect(
        budget.tryClaimPermissionDeniedRetry(
          errorCode: 'permission-denied',
          authenticatedUid: 'approved-user',
          expectedUid: 'approved-user',
        ),
        isTrue,
      );

      budget.observeAuthEvent(null);
      budget.observeAuthEvent('approved-user');
      expect(
        budget.tryClaimPermissionDeniedRetry(
          errorCode: 'permission-denied',
          authenticatedUid: 'approved-user',
          expectedUid: 'approved-user',
        ),
        isTrue,
      );
    });

    test('ineligible errors fail closed without consuming the retry', () {
      final budget = CurrentAppUserPermissionRetryBudget();
      budget.observeAuthEvent('approved-user');

      expect(
        budget.tryClaimPermissionDeniedRetry(
          errorCode: 'unavailable',
          authenticatedUid: 'approved-user',
          expectedUid: 'approved-user',
        ),
        isFalse,
      );
      expect(
        budget.tryClaimPermissionDeniedRetry(
          errorCode: 'permission-denied',
          authenticatedUid: 'different-user',
          expectedUid: 'approved-user',
        ),
        isFalse,
      );
      expect(
        budget.tryClaimPermissionDeniedRetry(
          errorCode: 'permission-denied',
          authenticatedUid: 'approved-user',
          expectedUid: 'approved-user',
        ),
        isTrue,
      );
    });
  });
}
