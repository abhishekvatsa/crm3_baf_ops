import 'dart:async';

import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/core/services/sync_session_guard_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/abnormalities/services/charge_abnormality_command_service.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/auth/services/auth_service.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart'
    show AppRole;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  test('once aborted, a guard cannot resume when its check becomes valid', () {
    var current = true;
    final guard = SyncRunGuard(() {
      if (!current) throw const SyncRunAborted('account-changed');
    });
    guard.checkCurrent();
    current = false;
    expect(guard.checkCurrent, throwsA(isA<SyncRunAborted>()));
    current = true;
    expect(guard.checkCurrent, throwsA(isA<SyncRunAborted>()));
  });

  test('storage and authentication failures escape domain isolation', () {
    for (final error in <Object>[
      const SyncRunAborted('owner-ended'),
      IsarError('Database closed'),
      FirebaseAuthException(code: 'unauthenticated'),
      const WorkflowException(
        WorkflowErrorCode.unauthenticated,
        'Sign in again',
      ),
      const ChargeAbnormalityMutationException(
        code: 'unauthenticated',
        message: 'Sign in again',
      ),
      const ChargeAbnormalityMutationException(
        code: 'data-loss',
        message: 'Unsafe response',
      ),
      FirebaseException(plugin: 'cloud_firestore', code: 'data-loss'),
    ]) {
      expect(() => rethrowIfSyncRunMustAbort(error), throwsA(anything));
    }
    for (final error in <Object>[
      StateError('malformed row'),
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    ]) {
      expect(() => rethrowIfSyncRunMustAbort(error), returnsNormally);
    }
  });

  test(
    'production guard accepts stable verified authority and normal observations',
    () async {
      final owner = await _AuthorityOwner.create();
      addTearDown(owner.dispose);
      final guard = owner.factory();
      guard.checkCurrent();
      owner.profiles.add(_actor());
      await owner.settle();
      expect(guard.checkCurrent, returnsNormally);
    },
  );

  for (final scenario in [
    'sign-out',
    'revoke',
    'revision',
    'role',
    'cache',
    'loading-error',
  ]) {
    test(
      'production guard remembers $scenario even after authority returns',
      () async {
        final owner = await _AuthorityOwner.create();
        addTearDown(owner.dispose);
        final guard = owner.factory();
        guard.checkCurrent();
        switch (scenario) {
          case 'sign-out':
            owner.container.read(signOutInProgressProvider.notifier).state =
                true;
            owner.container.read(signOutInProgressProvider.notifier).state =
                false;
          case 'revoke':
            owner.profiles.add(_actor(approved: false));
          case 'revision':
            owner.profiles.add(_actor(revision: 2));
          case 'role':
            owner.profiles.add(_actor(role: AppRole.operations));
          case 'cache':
            owner.profiles.add(_actor(fromCache: true));
          case 'loading-error':
            owner.profiles.addError(StateError('profile unavailable'));
        }
        await owner.settle();
        owner.profiles.add(_actor());
        await owner.settle();
        expect(guard.checkCurrent, throwsA(isA<SyncRunAborted>()));
        expect(owner.factory().checkCurrent, returnsNormally);
      },
    );
  }

  test(
    'production guard rejects mismatched and absent authenticated account',
    () async {
      final owner = await _AuthorityOwner.create();
      addTearDown(owner.dispose);
      final guard = owner.factory();
      owner.auth.user = _User('other-account');
      expect(guard.checkCurrent, throwsA(isA<SyncRunAborted>()));
      expect(owner.factory().checkCurrent, throwsA(isA<SyncRunAborted>()));
      owner.auth.user = null;
      expect(owner.factory().checkCurrent, throwsA(isA<SyncRunAborted>()));
    },
  );

  test(
    'new runs reject unconfirmed authentication despite retained profile and SDK user',
    () async {
      final owner = await _AuthorityOwner.create();
      addTearDown(owner.dispose);
      final previousRun = owner.factory();
      previousRun.checkCurrent();
      owner.sessions.addError(
        StateError('authentication observation unavailable'),
      );
      await owner.settle();
      expect(owner.auth.currentUser, isNotNull);
      expect(
        owner.container.read(currentAppUserProvider).valueOrNull,
        isNotNull,
      );
      expect(owner.factory().checkCurrent, throwsA(isA<SyncRunAborted>()));
      owner.sessions.add(owner.auth.currentUser);
      await owner.settle();
      expect(previousRun.checkCurrent, throwsA(isA<SyncRunAborted>()));
      expect(owner.factory().checkCurrent, returnsNormally);
      owner.sessions.add(null);
      await owner.settle();
      expect(owner.factory().checkCurrent, throwsA(isA<SyncRunAborted>()));
    },
  );
}

AppUser _actor({
  bool approved = true,
  int revision = 1,
  AppRole role = AppRole.si,
  bool fromCache = false,
}) => AppUser(
  uid: 'sync-actor',
  name: 'Sync actor',
  email: 'sync@example.invalid',
  roles: [role],
  isApproved: approved,
  authorityRevision: revision,
  authorityFromCache: fromCache,
  authorityObservedAt: DateTime.utc(2026, 9, 27),
  createdAt: DateTime.utc(2026, 1, 1),
);

class _AuthorityOwner {
  final profiles = StreamController<AppUser?>();
  final sessions = StreamController<User?>();
  final auth = _Auth();
  late final ProviderContainer container;
  late final SyncRunGuard Function() factory;

  static Future<_AuthorityOwner> create() async {
    final owner = _AuthorityOwner();
    owner.container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(owner.auth),
        currentAppUserProvider.overrideWith((ref) => owner.profiles.stream),
        authStateProvider.overrideWith((ref) => owner.sessions.stream),
      ],
    );
    owner.factory = owner.container.read(syncRunGuardFactoryProvider);
    owner.profiles.add(_actor());
    owner.sessions.add(owner.auth.currentUser);
    await owner.settle();
    return owner;
  }

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await container.pump();
  }

  Future<void> dispose() async {
    container.dispose();
    await profiles.close();
    await sessions.close();
  }
}

class _Auth extends Fake implements FirebaseAuth {
  User? user = _User('sync-actor');
  @override
  User? get currentUser => user;
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}
