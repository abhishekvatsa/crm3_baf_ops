import 'dart:io';

import 'package:crm3_baf_ops/core/services/local_recovery_session_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an active protected reset blocks session exit until terminal', () {
    final guard =
        LocalRecoverySessionGuard()
          ..beginRecovery()
          ..beginRecovery();

    expect(
      guard.beginSessionEnd,
      throwsA(isA<LocalRecoverySignOutBlockedException>()),
    );

    guard.endRecovery();
    expect(
      guard.beginSessionEnd,
      throwsA(isA<LocalRecoverySignOutBlockedException>()),
    );
    guard.endRecovery();
    expect(guard.beginSessionEnd, returnsNormally);
    guard.endSessionEnd();
  });

  test('a reserved session exit prevents a new reset claim race', () {
    final guard = LocalRecoverySessionGuard()..beginSessionEnd();

    expect(
      guard.beginRecovery,
      throwsA(isA<LocalRecoverySessionEndingException>()),
    );

    guard.endSessionEnd();
    expect(guard.beginRecovery, returnsNormally);
    guard.endRecovery();
  });

  test(
    'auth and recovery wiring acquires the interlock before either race',
    () {
      final auth =
          File(
            'lib/features/auth/providers/auth_provider.dart',
          ).readAsStringSync();
      final coordinator =
          File('lib/core/services/sync_coordinator.dart').readAsStringSync();

      final signOutStart = auth.indexOf('Future<void> signOut()');
      final signOutEnd = auth.indexOf(
        'Future<void> _performSignOut()',
        signOutStart,
      );
      final signOut = auth.substring(signOutStart, signOutEnd);
      expect(signOut.indexOf('.beginSessionEnd()'), greaterThanOrEqualTo(0));
      expect(
        signOut.indexOf('.beginSessionEnd()'),
        lessThan(signOut.indexOf('await _performSignOut()')),
      );
      expect(signOut, contains('.endSessionEnd()'));

      final recoveryStart = coordinator.indexOf(
        'Future<T> runWithSyncPaused<T>',
      );
      final recoveryEnd = coordinator.indexOf(
        'Future<SyncRequestOutcome> _runFullSync',
        recoveryStart,
      );
      final recovery = coordinator.substring(recoveryStart, recoveryEnd);
      expect(recovery.indexOf('.beginRecovery()'), greaterThanOrEqualTo(0));
      expect(
        recovery.indexOf('.beginRecovery()'),
        lessThan(recovery.indexOf('return await operation()')),
      );
      expect(recovery, contains('.endRecovery()'));
    },
  );
}
