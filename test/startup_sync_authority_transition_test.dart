import 'dart:async';

import 'package:crm3_baf_ops/core/providers/sync_providers.dart';
import 'package:crm3_baf_ops/core/services/auto_sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'cached approval waits and same-account verified arrival starts sync',
    (tester) async {
      final owner = await _Owner.mount(tester, _actor(cached: true));
      expect(owner.sync.runs, isEmpty);
      expect(owner.container.read(syncOnceProvider), isFalse);
      await owner.emit(tester, _actor());
      expect(owner.sync.runs, hasLength(1));
      owner.sync.runs.single.complete(SyncRequestOutcome.succeeded);
      await tester.pump();
      expect(owner.container.read(syncOnceProvider), isTrue);
      await owner.emit(tester, _actor());
      expect(owner.sync.runs, hasLength(1));
    },
  );

  testWidgets(
    'revocation blocks a late success and verified reapproval retries',
    (tester) async {
      final owner = await _Owner.mount(tester, _actor());
      expect(owner.sync.runs, hasLength(1));
      await owner.emit(tester, _actor(approved: false));
      owner.sync.runs.first.complete(SyncRequestOutcome.succeeded);
      await tester.pump();
      expect(owner.container.read(syncOnceProvider), isFalse);
      expect(owner.sync.runs, hasLength(1));
      await owner.emit(tester, _actor());
      expect(owner.sync.runs, hasLength(2));
      owner.sync.runs.last.complete(SyncRequestOutcome.succeeded);
      await tester.pump();
      expect(owner.container.read(syncOnceProvider), isTrue);
    },
  );

  testWidgets('replacement account cannot inherit an in-flight success', (
    tester,
  ) async {
    final owner = await _Owner.mount(tester, _actor());
    owner.auth.user = _User('replacement');
    await owner.emit(tester, _actor(uid: 'replacement'));
    expect(owner.sync.runs, hasLength(2));
    owner.sync.runs.first.complete(SyncRequestOutcome.succeeded);
    await tester.pump();
    expect(owner.container.read(syncOnceProvider), isFalse);
    owner.sync.runs.last.complete(SyncRequestOutcome.succeeded);
    await tester.pump();
    expect(owner.container.read(syncOnceProvider), isTrue);
  });

  testWidgets(
    'mismatched profile never dispatches until the authenticated actor matches',
    (tester) async {
      final owner = await _Owner.mount(tester, _actor(uid: 'stale'));
      expect(owner.sync.runs, isEmpty);
      await owner.emit(tester, _actor());
      expect(owner.sync.runs, hasLength(1));
      owner.sync.runs.single.complete(SyncRequestOutcome.partial);
      await tester.pump();
      expect(owner.container.read(syncOnceProvider), isFalse);
    },
  );

  testWidgets('disposal prevents a late startup result writing syncOnce', (
    tester,
  ) async {
    final owner = await _Owner.mount(tester, _actor());
    await tester.pumpWidget(const SizedBox.shrink());
    owner.sync.runs.single.complete(SyncRequestOutcome.succeeded);
    await tester.pump();
    expect(owner.container.read(syncOnceProvider), isFalse);
    expect(tester.takeException(), isNull);
  });
}

AppUser _actor({
  String uid = 'actor',
  bool cached = false,
  bool approved = true,
}) => AppUser(
  uid: uid,
  name: 'Actor',
  email: 'actor@example.invalid',
  roles: [AppRole.si],
  isApproved: approved,
  authorityRevision: 1,
  authorityFromCache: cached,
  authorityObservedAt: DateTime.utc(2026, 9, 27),
  createdAt: DateTime.utc(2026),
);

class _Owner {
  final profiles = StreamController<AppUser?>();
  final authEvents = StreamController<User?>();
  final auth = _Auth();
  final sync = _Sync();
  late final ProviderContainer container;

  static Future<_Owner> mount(WidgetTester tester, AppUser initial) async {
    final owner = _Owner();
    owner.container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(owner.auth),
        authStateProvider.overrideWith((ref) => owner.authEvents.stream),
        currentAppUserProvider.overrideWith((ref) => owner.profiles.stream),
        autoSyncServiceProvider.overrideWithValue(_AutoSync()),
        syncCoordinatorProvider.overrideWithValue(owner.sync),
      ],
    );
    addTearDown(() async {
      owner.container.dispose();
      await owner.profiles.close();
      await owner.authEvents.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: owner.container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              // AuthGate already watches auth before mounting the startup
              // gate. Keep the test host faithful to that subscription order.
              final authentication = ref.watch(authStateProvider);
              final actor = ref.watch(currentAppUserProvider).valueOrNull;
              return actor == null || authentication.isLoading
                  ? const SizedBox.shrink()
                  : startupSyncGateForTesting(appUser: actor);
            },
          ),
        ),
      ),
    );
    await owner.emit(tester, initial);
    return owner;
  }

  Future<void> emit(WidgetTester tester, AppUser actor) async {
    authEvents.add(auth.currentUser);
    profiles.add(actor);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

class _Auth extends Fake implements FirebaseAuth {
  User? user = _User('actor');
  @override
  User? get currentUser => user;
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _AutoSync extends Fake implements AutoSyncService {
  @override
  void detach() {}
}

class _Sync extends Fake implements SyncCoordinator {
  final runs = <Completer<SyncRequestOutcome>>[];
  @override
  Future<SyncRequestOutcome> runFullSyncWithResult({
    String reason = 'unknown',
    bool force = false,
  }) {
    expect(reason, 'auth_gate');
    expect(force, isTrue);
    final pending = Completer<SyncRequestOutcome>();
    runs.add(pending);
    return pending.future;
  }
}
