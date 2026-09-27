// The fakes control only the native query boundary. The repository decoder and
// the actual auth-dependent Riverpod provider remain under test.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/critical_alarm/data/critical_alarm_repository.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/critical_alarm/providers/critical_alarm_providers.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final sync in [false, true]) {
    for (final cancelFirst in [false, true]) {
      test(
        'query cancellation stays handled: sync=$sync, cancelFirst=$cancelFirst',
        () async {
          final firestore = _Firestore(sync: sync);
          addTearDown(firestore.close);
          final activeErrors = <Object>[];
          final subscription = CriticalAlarmRepository(firestore)
              .watchActiveAlarms()
              .listen(
                (_) {},
                onError: (Object error) => activeErrors.add(error),
              );
          await _settle();
          final query = firestore.queries.single;
          query.controller.add(_Snapshot());
          await _settle();

          // An asynchronous platform delivery can still be pending when auth
          // cancels. Also exercise the inverse ordering and synchronous delivery.
          final denied = _denied();
          Future<void>? cancellation;
          if (cancelFirst) cancellation = subscription.cancel();
          query.controller.addError(denied, StackTrace.current);
          cancellation ??= subscription.cancel();
          Object? cancellationError;
          try {
            await cancellation;
          } on Object catch (error) {
            cancellationError = error;
          }
          expect(query.wasCancelled, isTrue);
          expect(cancellationError, isNull);
          expect(activeErrors, sync && !cancelFirst ? [same(denied)] : isEmpty);
        },
      );
    }

    for (final actorError in [false, true]) {
      test(
        'actor revocation handles query error: sync=$sync, actorError=$actorError',
        () async {
          final escapedErrors = <Object>[];
          final finished = Completer<void>();
          var cancelled = false;
          final authorityError = _denied();
          Object? finalProviderError;
          CriticalAlarmLiveSnapshot? signedOutSnapshot;
          runZonedGuarded(() async {
            final actors = StreamController<AppUser?>.broadcast(sync: true);
            final firestore = _Firestore(sync: sync);
            final container = ProviderContainer(
              overrides: [
                currentAppUserProvider.overrideWith((ref) => actors.stream),
                criticalAlarmRepositoryProvider.overrideWithValue(
                  CriticalAlarmRepository(firestore),
                ),
              ],
            );
            try {
              container.listen(currentAppUserProvider, (_, __) {});
              actors.add(_actor());
              await _settle();
              container.listen(activeCriticalAlarmsProvider, (_, __) {});
              await _settle();
              final query = firestore.queries.single;
              query.controller.add(_Snapshot());
              await _settle();

              query.controller.addError(_denied(), StackTrace.current);
              if (actorError) {
                actors.addError(authorityError, StackTrace.current);
              } else {
                actors.add(null);
              }
              // Force the auth-dependent provider to rebuild in this same turn,
              // before the failed query's await continuation can run.
              container.read(activeCriticalAlarmsProvider);
              await _settle();
              cancelled = query.wasCancelled;
              signedOutSnapshot = container
                  .read(activeCriticalAlarmsProvider)
                  .asData
                  ?.value;
              finalProviderError = container
                  .read(activeCriticalAlarmsProvider)
                  .error;
            } finally {
              container.dispose();
              await actors.close();
              await firestore.close();
              await _settle();
              finished.complete();
            }
          }, (error, stack) => escapedErrors.add(error));
          await finished.future;
          expect(cancelled, isTrue);
          if (!actorError) {
            expect(signedOutSnapshot?.isServerVerified, isTrue);
            expect(signedOutSnapshot?.alarms, isEmpty);
          } else {
            expect(finalProviderError, same(authorityError));
          }
          expect(escapedErrors, isEmpty);
        },
      );
    }
  }

  test(
    'an active query error retains its identity and stack for the consumer',
    () async {
      final firestore = _Firestore();
      addTearDown(firestore.close);
      final errors = <Object>[];
      final stacks = <StackTrace>[];
      var completed = false;
      final subscription = CriticalAlarmRepository(firestore)
          .watchActiveAlarms()
          .listen(
            (_) {},
            onError: (Object error, StackTrace stack) {
              errors.add(error);
              stacks.add(stack);
            },
            onDone: () => completed = true,
          );
      addTearDown(subscription.cancel);
      await _settle();
      final denied = _denied();
      final stack = StackTrace.current;
      firestore.queries.single.controller.addError(denied, stack);
      await _settle();
      expect(errors, [same(denied)]);
      expect(stacks, [same(stack)]);
      expect(completed, isTrue);
      expect(firestore.queries.single.wasCancelled, isTrue);
    },
  );

  test('verification state and cancellation belong to each listener', () async {
    final firestore = _Firestore();
    addTearDown(firestore.close);
    final stream = CriticalAlarmRepository(firestore).watchActiveAlarms();
    final first = <CriticalAlarmLiveSnapshot>[];
    final second = <CriticalAlarmLiveSnapshot>[];
    final firstSubscription = stream.listen(first.add);
    addTearDown(firstSubscription.cancel);
    await _settle();
    final firstQuery = firestore.queries.single;
    firstQuery.controller.add(_Snapshot(documents: [_alarm('alarm-first')]));
    await _settle();
    final firstVerifiedAt = first.single.lastVerifiedAt;
    expect(first.single.isServerVerified, isTrue);

    final secondSubscription = stream.listen(second.add);
    addTearDown(secondSubscription.cancel);
    await _settle();
    final secondQuery = firestore.queries.last;
    expect(secondQuery, isNot(same(firstQuery)));
    secondQuery.controller.add(_Snapshot(fromCache: true));
    firstQuery.controller.add(_Snapshot(fromCache: true));
    await _settle();
    expect(second.single.authority, CriticalAlarmFeedAuthority.unavailable);
    expect(second.single.lastVerifiedAt, isNull);
    expect(second.single.alarms, isEmpty);
    expect(first.last.authority, CriticalAlarmFeedAuthority.staleLastKnown);
    expect(first.last.alarms.single.id, 'alarm-first');
    expect(first.last.lastVerifiedAt, firstVerifiedAt);

    await firstSubscription.cancel();
    expect(firstQuery.wasCancelled, isTrue);
    expect(secondQuery.wasCancelled, isFalse);
    secondQuery.controller.add(_Snapshot(documents: [_alarm('alarm-second')]));
    await _settle();
    expect(second.last.isServerVerified, isTrue);
    expect(second.last.alarms.single.id, 'alarm-second');
  });

  test(
    'partial and pending-write snapshots cannot replace verified history',
    () async {
      final firestore = _Firestore();
      addTearDown(firestore.close);
      final snapshots = <CriticalAlarmLiveSnapshot>[];
      final subscription = CriticalAlarmRepository(
        firestore,
      ).watchActiveAlarms().listen(snapshots.add);
      addTearDown(subscription.cancel);
      await _settle();
      final query = firestore.queries.single;
      query.controller.add(_Snapshot(documents: [_alarm('verified')]));
      await _settle();
      final verifiedAt = snapshots.last.lastVerifiedAt;
      query.controller.add(
        _Snapshot(
          documents: [_alarm('new-valid'), _Document('malformed', const {})],
        ),
      );
      await _settle();
      expect(
        snapshots.last.authority,
        CriticalAlarmFeedAuthority.partiallyVerified,
      );
      expect(snapshots.last.alarms.single.id, 'new-valid');
      expect(snapshots.last.malformedDocumentCount, 1);
      expect(snapshots.last.lastVerifiedAt, verifiedAt);
      query.controller.add(_Snapshot(pendingWrites: true));
      await _settle();
      expect(
        snapshots.last.authority,
        CriticalAlarmFeedAuthority.staleLastKnown,
      );
      expect(snapshots.last.alarms.single.id, 'verified');
      expect(snapshots.last.lastVerifiedAt, verifiedAt);
    },
  );
}

Future<void> _settle() async {
  for (var turn = 0; turn < 4; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

FirebaseException _denied() => FirebaseException(
  plugin: 'cloud_firestore',
  code: 'permission-denied',
  message: 'The signed-out actor no longer has query access.',
);

AppUser _actor() => AppUser(
  uid: 'alarm-operator',
  name: 'Alarm operator',
  email: 'alarm-operator@example.invalid',
  roles: [AppRole.operations],
  isApproved: true,
  authorityRevision: 1,
  accessDisposition: 'approved',
  authorityFromCache: false,
  authorityHasPendingWrites: false,
  authorityObservedAt: DateTime.utc(2026, 9, 26),
  createdAt: DateTime.utc(2026, 9, 1),
);

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore({this.sync = false});
  final bool sync;
  final queries = <_QueryLease>[];

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Query(this);

  Stream<QuerySnapshot<Map<String, dynamic>>> watch() {
    final query = _QueryLease(sync: sync);
    queries.add(query);
    return query.controller.stream;
  }

  Future<void> close() async {
    for (final query in queries) {
      await query.controller.close();
    }
  }
}

class _QueryLease {
  _QueryLease({required bool sync}) {
    controller =
        StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
          sync: sync,
          onCancel: () => wasCancelled = true,
        );
  }
  late final StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
  bool wasCancelled = false;
}

class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(this.firestore);
  @override
  final _Firestore firestore;

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
  }) => this;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => firestore.watch();
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot({
    this.fromCache = false,
    this.pendingWrites = false,
    this.documents = const [],
  });
  final bool fromCache;
  final bool pendingWrites;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents;

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => documents;

  @override
  SnapshotMetadata get metadata => _Metadata(fromCache, pendingWrites);
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

_Document _alarm(String id) => _Document(id, {
  'schemaVersion': 1,
  'alarmId': id,
  'alarmTypeKey': 'fire',
  'alarmTypeName': 'Fire',
  'criticalityKey': 'highest',
  'criticalityRank': 1,
  'status': 'raised',
  'version': 1,
  'location': 'BAF shop north bay',
  'assetTypeKey': null,
  'assetNumber': null,
  'details': null,
  'detailsPending': true,
  'raisedByUid': 'alarm-operator',
  'raisedByName': 'Alarm operator',
  'raisedAt': DateTime.utc(2026, 9, 26),
  'detailsProvidedByUid': null,
  'detailsProvidedByName': null,
  'detailsProvidedAt': null,
  'supportBasis': null,
  'supportNote': null,
  'supportConfirmedByUid': null,
  'supportConfirmedByName': null,
  'supportConfirmedAt': null,
  'resolutionSummary': null,
  'resolvedByUid': null,
  'resolvedByName': null,
  'resolvedAt': null,
  'withdrawalReason': null,
  'withdrawnByUid': null,
  'withdrawnByName': null,
  'withdrawnAt': null,
  'createdAt': DateTime.utc(2026, 9, 26),
  'updatedAt': DateTime.utc(2026, 9, 26),
});
