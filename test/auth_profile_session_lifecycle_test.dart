// Real provider, stream switching, retry budget and profile decoder; only the
// Firebase transport boundary is controlled so auth/token ordering is explicit.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/domain/current_actor_access.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/auth/services/auth_service.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'malformed current profile fails closed and detaches without token retry',
    () async {
      final session = _Session();
      addTearDown(session.close);
      await session.start();
      final lease = session.store.active.single;
      lease.controller.add(_Snapshot('A'));
      await session.flush();
      expect(CurrentActorAccess.resolve(session.profile).isReady, isTrue);

      lease.controller.add(
        _Snapshot('A', overrides: {'authorityRevision': 'not-an-integer'}),
      );
      await session.flush();
      expect(session.profile.hasError, isTrue);
      expect(session.profile.error, isA<FormatException>());
      final access = CurrentActorAccess.resolve(session.profile);
      expect(access.isReady, isFalse);
      expect(access.actor, isNull);
      expect(session.auth.user!.refreshes, 0);
      expect(lease.cancelled, isTrue);
      expect(session.store.active, isEmpty);
      lease.controller.add(_Snapshot('A'));
      await session.flush();
      expect(session.profile.hasError, isTrue);
      expect(CurrentActorAccess.resolve(session.profile).isReady, isFalse);
    },
  );

  test(
    'unsupported accessDisposition requires an explicit fresh profile recheck',
    () async {
      final session = _Session();
      addTearDown(session.close);
      await session.start();
      final old = session.store.active.single;
      old.controller.add(_Snapshot('A'));
      await session.flush();
      expect(CurrentActorAccess.resolve(session.profile).isReady, isTrue);

      old.controller.add(
        _Snapshot('A', overrides: {'accessDisposition': 'unsupported-value'}),
      );
      await session.flush();
      expect(
        session.profile.error,
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('access disposition'),
        ),
      );
      expect(CurrentActorAccess.resolve(session.profile).actor, isNull);
      expect(old.cancelled, isTrue);
      expect(session.auth.user!.refreshes, 0);

      // Correcting an obsolete callback cannot restore the old authority.
      old.controller.add(
        _Snapshot('A', overrides: {'accessDisposition': 'approved'}),
      );
      await session.flush();
      expect(session.profile.hasError, isTrue);
      expect(CurrentActorAccess.resolve(session.profile).isReady, isFalse);

      // This is the same explicit provider invalidation used by the gate's
      // Check access again action, after the server profile is corrected.
      session.container.invalidate(currentAppUserProvider);
      await session.flush();
      final fresh = session.store.active.single;
      expect(fresh, isNot(same(old)));
      expect(CurrentActorAccess.resolve(session.profile).isReady, isFalse);
      fresh.controller.add(
        _Snapshot('A', overrides: {'accessDisposition': 'approved'}),
      );
      await session.flush();
      expect(session.profile.hasError, isFalse);
      expect(session.profile.requireValue!.accessDisposition, 'approved');
      expect(
        session.profile.requireValue!.hasServerAuthorityObservation,
        isTrue,
      );
      expect(CurrentActorAccess.resolve(session.profile).isReady, isTrue);
      expect(session.auth.user!.refreshes, 0);
    },
  );

  test(
    'token refresh completing after sign-out cannot reopen old profile',
    () async {
      final session = _Session();
      addTearDown(session.close);
      final refresh = Completer<String?>();
      final oldUser = session.auth.user!..refreshCompletion = refresh;
      addTearDown(() {
        if (!refresh.isCompleted) refresh.complete('test-only');
      });
      await session.start();
      final old = session.store.active.single;
      old.controller.addError(_denied());
      await session.flush();
      expect(oldUser.refreshes, 1);
      expect(refresh.isCompleted, isFalse);
      expect(old.cancelled, isTrue);

      session.container.read(signOutInProgressProvider.notifier).state = true;
      session.auth.user = null;
      await session.flush();
      expect(session.profile.requireValue, isNull);
      refresh.complete('test-only');
      await session.flush();
      expect(session.store.leases, hasLength(1));
      expect(session.store.active, isEmpty);
      expect(session.profile.hasError, isFalse);
      expect(session.profile.requireValue, isNull);

      session.auth.user = _User('B');
      session.container.read(signOutInProgressProvider.notifier).state = false;
      await session.flush();
      expect(session.store.active.single.uid, 'B');
      session.store.active.single.controller.add(_Snapshot('B'));
      await session.flush();
      expect(session.profile.requireValue!.uid, 'B');
    },
  );

  test(
    'sign-out detaches profile before auth cleanup and new session restarts',
    () async {
      final session = _Session();
      addTearDown(session.close);
      await session.start();
      final old = session.store.active.single;
      old.controller.add(_Snapshot('A'));
      await session.flush();
      expect(session.profile.requireValue!.uid, 'A');

      session.container.read(signOutInProgressProvider.notifier).state = true;
      await session.flush();
      expect(session.auth.currentUser!.uid, 'A');
      expect(session.profile.requireValue, isNull);
      await session.flush();
      expect(old.cancelled, isTrue);
      expect(session.store.active, isEmpty);
      old.controller.addError(_denied());

      session.auth.user = _User('B');
      session.container.read(signOutInProgressProvider.notifier).state = false;
      await session.flush();
      expect(session.store.active.single.uid, 'B');
      session.store.active.single.controller.add(_Snapshot('B'));
      await session.flush();
      expect(session.profile.requireValue!.uid, 'B');
      expect(
        session.profile.requireValue!.hasServerAuthorityObservation,
        isTrue,
      );
    },
  );

  for (final nextUid in <String?>[null, 'B']) {
    test(
      'obsolete profile denial before token event clears authority ($nextUid)',
      () async {
        final session = _Session();
        addTearDown(session.close);
        await session.start();
        session.store.active.single.controller.add(_Snapshot('A'));
        await session.flush();
        final oldUser = session.auth.user!;
        // Firebase currentUser changes before idTokenChanges delivers its event.
        session.auth.user = nextUid == null ? null : _User(nextUid);
        session.store.active.single.controller.addError(_denied());
        await session.flush();
        expect(session.profile.hasError, isFalse);
        expect(session.profile.requireValue, isNull);
        expect(oldUser.refreshes, 0);
      },
    );
  }

  test(
    'same-current-actor denial retries once then remains a visible error',
    () async {
      final session = _Session();
      addTearDown(session.close);
      await session.start();
      session.store.active.single.controller.addError(_denied());
      await session.flush();
      expect(session.auth.user!.refreshes, 1);
      expect(session.store.active, hasLength(1));
      final deniedAgain = _denied();
      session.store.active.single.controller.addError(deniedAgain);
      await session.flush();
      expect(session.auth.user!.refreshes, 1);
      expect(session.profile.hasError, isTrue);
      expect(session.profile.error, same(deniedAgain));
    },
  );
}

FirebaseException _denied() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

class _Session {
  final auth = _Auth();
  final store = _Store();
  late final container = ProviderContainer(
    overrides: [
      firebaseAuthProvider.overrideWithValue(auth),
      authFirestoreProvider.overrideWithValue(store),
    ],
  );
  late ProviderSubscription<AsyncValue<AppUser?>> subscription;
  AsyncValue<AppUser?> get profile => container.read(currentAppUserProvider);

  Future<void> start() async {
    subscription = container.listen(currentAppUserProvider, (_, _) {});
    await flush();
  }

  Future<void> flush() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }
  }

  Future<void> close() async {
    subscription.close();
    container.dispose();
    await auth.tokens.close();
    for (final lease in store.leases) {
      await lease.controller.close();
    }
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _User? user = _User('A');
  final tokens = StreamController<User?>.broadcast();
  @override
  User? get currentUser => user;
  @override
  Stream<User?> idTokenChanges() async* {
    yield user;
    yield* tokens.stream;
  }
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  int refreshes = 0;
  Completer<String?>? refreshCompletion;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    expect(forceRefresh, isTrue);
    refreshes++;
    final pending = refreshCompletion;
    if (pending != null) return pending.future;
    return 'test-only';
  }
}

class _Store extends Fake implements FirebaseFirestore {
  final leases = <_Lease>[];
  Iterable<_Lease> get active => leases.where((lease) => !lease.cancelled);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users');
    return _Collection(this);
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store);
  final _Store store;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, path!);
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.uid);
  final _Store store;
  final String uid;
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    expect(includeMetadataChanges, isTrue);
    final lease = _Lease(uid);
    store.leases.add(lease);
    return lease.controller.stream;
  }
}

class _Lease {
  _Lease(this.uid) {
    controller =
        StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(
          onCancel: () => cancelled = true,
        );
  }
  final String uid;
  bool cancelled = false;
  late final StreamController<DocumentSnapshot<Map<String, dynamic>>>
  controller;
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.id, {this.overrides = const {}});
  final Map<String, dynamic> overrides;
  @override
  final String id;
  @override
  bool get exists => true;
  @override
  SnapshotMetadata get metadata => _Metadata();
  @override
  Map<String, dynamic> data() => {
    ...AppUser(
      uid: id,
      name: 'Test $id',
      email: '$id@example.invalid',
      roles: [AppRole.si],
      isApproved: true,
      createdAt: DateTime.utc(2026, 9, 20),
    ).toFirestore(),
    ...overrides,
  };
}

class _Metadata extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
}
