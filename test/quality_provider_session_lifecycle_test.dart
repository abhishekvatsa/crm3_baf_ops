// The fake implements only the public query boundary; both production Quality
// providers and their actual decoders/window combiners remain under test.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/auth/services/auth_service.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Quality replaces both feeds after sign-out and another approved actor',
    () async {
      final session = _QualitySession();
      addTearDown(session.dispose);
      await session.start(_actor('operations-a'));
      session.firestore.emitServerSnapshots();
      await session.settle();
      session.expectReady();
      final original = session.firestore.active.toList();
      expect(original, isNotEmpty);

      // Signing out closes live access even while the old profile has not yet
      // emitted null. Credential cleanup must not require a screen refresh.
      session.container.read(signOutInProgressProvider.notifier).state = true;
      await session.settle();
      expect(session.firestore.active, isEmpty);
      expect(original.every((query) => query.wasCancelled), isTrue);

      session.actors.add(null);
      await session.settle();
      session.container.read(signOutInProgressProvider.notifier).state = false;
      await session.settle();
      expect(session.firestore.active, isEmpty);

      session.actors.add(_actor('pending-b', approved: false));
      await session.settle();
      expect(
        session.firestore.active,
        isEmpty,
        reason: 'A pending account cannot reopen the Quality feeds.',
      );

      session.actors.add(_actor('si-b', role: AppRole.si));
      await session.settle();
      expect(
        session.firestore.activeCollections,
        containsAll(['quality_warnings', 'quality_monitoring_requests']),
      );
      expect(session.firestore.active.any(original.contains), isFalse);

      // A late delivery from the old transport cannot poison the new session.
      for (final query in original) {
        query.controller.addError(_denied('retired account'));
      }
      session.firestore.emitServerSnapshots();
      await session.settle();
      session.expectReady();
    },
  );

  test(
    'Quality replaces live feeds on direct approved-account replacement',
    () async {
      final session = _QualitySession();
      addTearDown(session.dispose);
      await session.start(_actor('operations-a'));
      session.firestore.emitServerSnapshots();
      await session.settle();
      session.expectReady();
      final original = session.firestore.active.toList();

      session.actors.add(_actor('si-b', role: AppRole.si));
      await session.settle();
      expect(original.every((query) => query.wasCancelled), isTrue);
      expect(
        session.firestore.activeCollections,
        containsAll(['quality_warnings', 'quality_monitoring_requests']),
      );
      expect(session.firestore.active.any(original.contains), isFalse);

      session.firestore.emitServerSnapshots();
      await session.settle();
      session.expectReady();
    },
  );

  test(
    'active permission errors remain errors until a new approved session',
    () async {
      final session = _QualitySession();
      addTearDown(session.dispose);
      await session.start(_actor('operations-a'));
      session.firestore.emitServerSnapshots();
      await session.settle();
      session.expectReady();

      final warningQueries = session.firestore.active
          .where((query) => query.collection == 'quality_warnings')
          .toList();
      final monitoringQueries = session.firestore.active
          .where((query) => query.collection == 'quality_monitoring_requests')
          .toList();
      expect(warningQueries, isNotEmpty);
      expect(monitoringQueries, isNotEmpty);
      final warningError = _denied('active warning read');
      final monitoringError = _denied('active monitoring read');
      warningQueries.first.controller.addError(warningError);
      for (final query in monitoringQueries) {
        query.controller.addError(monitoringError);
      }
      await session.settle();
      expect(
        session.container.read(qualityWarningsProvider).error,
        same(warningError),
      );
      expect(
        session.container.read(qualityMonitoringRequestsProvider).error,
        same(monitoringError),
      );

      // Another healthy warning window cannot certify the failed population.
      for (final query in warningQueries.skip(1)) {
        query.controller.add(_EmptyServerSnapshot());
      }
      await session.settle();
      expect(session.container.read(qualityWarningsProvider).hasError, isTrue);
      expect(
        session.container.read(qualityMonitoringRequestsProvider).hasError,
        isTrue,
      );

      session.actors.add(null);
      await session.settle();
      session.actors.add(_actor('si-b', role: AppRole.si));
      await session.settle();
      session.firestore.emitServerSnapshots();
      await session.settle();
      session.expectReady();
    },
  );
}

FirebaseException _denied(String message) => FirebaseException(
  plugin: 'cloud_firestore',
  code: 'permission-denied',
  message: message,
);

AppUser _actor(
  String uid, {
  bool approved = true,
  AppRole role = AppRole.operations,
}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [role],
  isApproved: approved,
  authorityRevision: 1,
  accessDisposition: approved ? 'approved' : 'pending',
  authorityFromCache: false,
  authorityHasPendingWrites: false,
  authorityObservedAt: DateTime.utc(2026, 9, 26),
  createdAt: DateTime.utc(2026, 9, 1),
);

class _QualitySession {
  final actors = StreamController<AppUser?>();
  final firestore = _RecordingFirestore();
  late final ProviderContainer container = ProviderContainer(
    overrides: [
      currentAppUserProvider.overrideWith((ref) => actors.stream),
      qualityFirestoreProvider.overrideWithValue(firestore),
    ],
  );

  Future<void> start(AppUser actor) async {
    // Keep the authority stream alive independently of the consumers, as the
    // application's root auth gate does. Do not override either feed provider.
    container.listen(currentAppUserProvider, (_, __) {}, fireImmediately: true);
    actors.add(actor);
    await settle();
    container.listen(
      qualityWarningsProvider,
      (_, __) {},
      fireImmediately: true,
    );
    container.listen(
      qualityMonitoringRequestsProvider,
      (_, __) {},
      fireImmediately: true,
    );
    await settle();
    expect(
      firestore.activeCollections,
      containsAll(['quality_warnings', 'quality_monitoring_requests']),
    );
  }

  Future<void> settle() async {
    for (var turn = 0; turn < 4; turn++) {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }
  }

  void expectReady() {
    final warnings = container.read(qualityWarningsProvider);
    final monitoring = container.read(qualityMonitoringRequestsProvider);
    expect(warnings.isLoading, isFalse);
    expect(warnings.hasError, isFalse);
    expect(warnings.requireValue, isEmpty);
    expect(monitoring.isLoading, isFalse);
    expect(monitoring.hasError, isFalse);
    expect(monitoring.requireValue, isEmpty);
  }

  Future<void> dispose() async {
    container.dispose();
    await actors.close();
    await firestore.close();
  }
}

class _RecordingFirestore extends Fake implements FirebaseFirestore {
  final queries = <_QueryLease>[];

  Iterable<_QueryLease> get active =>
      queries.where((query) => query.controller.hasListener);

  Set<String> get activeCollections =>
      active.map((query) => query.collection).toSet();

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _RecordingQuery(this, collectionPath);

  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String collection) {
    final lease = _QueryLease(collection);
    queries.add(lease);
    return lease.controller.stream;
  }

  void emitServerSnapshots() {
    for (final query in active.toList()) {
      query.controller.add(_EmptyServerSnapshot());
    }
  }

  Future<void> close() async {
    for (final query in queries) {
      await query.controller.close();
    }
  }
}

class _QueryLease {
  _QueryLease(this.collection) {
    controller =
        StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
          onCancel: () => wasCancelled = true,
        );
  }

  final String collection;
  late final StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
  bool wasCancelled = false;
}

class _RecordingQuery extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _RecordingQuery(this.owner, this.collectionPath);
  final _RecordingFirestore owner;
  final String collectionPath;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _RecordingQuery(owner, collectionPath);

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => _RecordingQuery(owner, collectionPath);

  @override
  Query<Map<String, dynamic>> limit(int limit) => this;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => owner.watch(collectionPath);
}

class _EmptyServerSnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => const [];

  @override
  SnapshotMetadata get metadata => _ServerMetadata();

  @override
  int get size => 0;
}

class _ServerMetadata extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;

  @override
  bool get hasPendingWrites => false;
}
