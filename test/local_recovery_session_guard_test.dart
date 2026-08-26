import 'dart:io';

import 'package:crm3_baf_ops/core/services/local_recovery_session_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active startup journal blocks session exit until examined', () async {
    final guard = LocalRecoverySessionGuard(
      startupRecoveryProbe: () async => true,
    );

    await expectLater(
      guard.beginSessionEnd(),
      throwsA(isA<LocalRecoverySignOutBlockedException>()),
    );

    guard.completeRecoveryCheck();
    await guard.beginSessionEnd();
    guard.endSessionEnd();
  });

  test('absence of a startup journal permits ordinary session exit', () async {
    final guard = LocalRecoverySessionGuard(
      startupRecoveryProbe: () async => false,
    );

    await guard.beginSessionEnd();
    guard.endSessionEnd();
  });

  test('unreadable startup journal state fails closed', () async {
    final guard = LocalRecoverySessionGuard(
      startupRecoveryProbe: () async => throw StateError('storage unreadable'),
    );

    await expectLater(
      guard.beginSessionEnd(),
      throwsA(isA<LocalRecoverySignOutBlockedException>()),
    );
  });

  test(
    'an active protected reset blocks session exit until terminal',
    () async {
      final guard =
          LocalRecoverySessionGuard()
            ..beginRecovery()
            ..beginRecovery();

      await expectLater(
        guard.beginSessionEnd(),
        throwsA(isA<LocalRecoverySignOutBlockedException>()),
      );

      guard.endRecovery();
      await expectLater(
        guard.beginSessionEnd(),
        throwsA(isA<LocalRecoverySignOutBlockedException>()),
      );
      guard.endRecovery();
      await guard.beginSessionEnd();
      guard.endSessionEnd();
    },
  );

  test('a reserved session exit prevents a new reset claim race', () async {
    final guard = LocalRecoverySessionGuard();
    await guard.beginSessionEnd();

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
      expect(
        signOut.indexOf('await _recoverySessionGuard.beginSessionEnd()'),
        greaterThanOrEqualTo(0),
      );
      expect(
        signOut.indexOf('.beginSessionEnd()'),
        lessThan(signOut.indexOf('await _performSignOut()')),
      );
      expect(signOut, contains('.endSessionEnd()'));

      final guardSource =
          File(
            'lib/core/services/local_recovery_session_guard.dart',
          ).readAsStringSync();
      final recoveryIoSource =
          File(
            'lib/core/services/isar_production_recovery_io.dart',
          ).readAsStringSync();
      expect(guardSource, contains('startupRecoveryProbe:'));
      expect(guardSource, contains('hasActiveCrashDurableIsarRecoveryJournal'));
      expect(
        recoveryIoSource,
        contains('markCrashDurableIsarRecoveryJournalTerminal'),
      );
      expect(recoveryIoSource, contains("File('\${source.path}.terminal')"));
      expect(
        recoveryIoSource,
        contains('await _syncRecoveryDirectory(paths.journalDirectory)'),
      );
      expect(
        recoveryIoSource,
        contains('terminalEvidenceNeedsDirectorySync'),
      );
      expect(
        recoveryIoSource,
        contains('await _syncRecoveryDirectory(directory)'),
      );
      expect(
        recoveryIoSource,
        contains(
          'Active recovery-journal identity does not match the current session.',
        ),
      );

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
