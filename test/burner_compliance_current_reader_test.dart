// Probe only the public Firestore transport boundary. The production providers,
// actor checks, current-pointer decoder and referenced-round decoder remain real.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/security/actor_session_cache_trust.dart';
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/providers/burner_condition_round_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/auth/services/auth_service.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'first compliance read bypasses cached pointer and uses fresh server evidence',
    () async {
      final session = _Session();
      addTearDown(session.dispose);
      await session.start();
      final rounds = await session.read();
      expect(rounds['furnace-2']?.roundId, 'server-round');
      expect(session.database.readSources, [Source.server, Source.server]);
    },
  );

  for (final phase in ['pointer', 'round']) {
    for (final metadata in ['cache', 'pending']) {
      test(
        'refuses $phase $metadata evidence even from requested server source',
        () async {
          final session = _Session();
          addTearDown(session.dispose);
          await session.start();
          session.database.untrustedPhase = phase;
          session.database.untrustedMetadata = metadata;
          await expectLater(
            session.read(),
            throwsA(isA<ActorSessionSnapshotTrustException>()),
          );
        },
      );
    }
  }

  for (final code in ['permission-denied', 'unavailable']) {
    test(
      'preserves authoritative $code failure without cache fallback',
      () async {
        final session = _Session();
        addTearDown(session.dispose);
        await session.start();
        final failure = FirebaseException(
          plugin: 'cloud_firestore',
          code: code,
        );
        session.database.serverError = failure;
        await expectLater(session.read(), throwsA(same(failure)));
        expect(session.database.readSources, [Source.server]);
      },
    );
  }

  test(
    'bounds an unavailable authoritative read without accepting cache',
    () async {
      final database = _Database()..pointerGate = Completer<void>();
      await expectLater(
        readCurrentBurnerConditionRoundsFromServer(
          firestore: database,
          query: _query,
          requireSameActor: () {},
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(database.readSources, [Source.server]);
      database.pointerGate!.complete();
    },
  );

  for (final transition in [
    'replacement',
    'revoked',
    'sign-out',
    'replacement-and-return',
  ]) {
    test('refuses in-flight evidence after $transition', () async {
      final session = _Session();
      addTearDown(session.dispose);
      await session.start();
      session.database.roundGate = Completer<void>();
      final pending = session.read();
      final rejected = expectLater(pending, throwsA(isA<StateError>()));
      await session.settle();
      expect(session.database.readSources, [Source.server, Source.server]);
      if (transition == 'sign-out') {
        session.container.read(signOutInProgressProvider.notifier).state = true;
      } else {
        session.actors.add(
          transition == 'revoked'
              ? _actor('ia-1', approved: false)
              : _actor('ia-2'),
        );
      }
      await session.settle();
      if (transition == 'replacement-and-return') {
        session.actors.add(_actor('ia-1'));
        await session.settle();
      }
      session.database.roundGate!.complete();
      await rejected;
    });
  }

  test('refuses unapproved actor before any remote read', () async {
    final session = _Session();
    addTearDown(session.dispose);
    await session.start();
    session.actors.add(_actor('ia-1', approved: false));
    await session.settle();
    await expectLater(session.read(), throwsA(isA<StateError>()));
    expect(session.database.readSources, isEmpty);
  });

  test(
    'same approved actor profile refresh keeps in-flight evidence valid',
    () async {
      final session = _Session();
      addTearDown(session.dispose);
      await session.start();
      session.database.roundGate = Completer<void>();
      final pending = session.read();
      await session.settle();
      session.actors.add(_actor('ia-1'));
      await session.settle();
      session.database.roundGate!.complete();
      expect((await pending)['furnace-2']?.roundId, 'server-round');
    },
  );

  test(
    'current-pointer mismatch is rejected by the original strict decoder',
    () async {
      final session = _Session();
      addTearDown(session.dispose);
      await session.start();
      session.database.mismatchedRound = true;
      await expectLater(
        session.read(),
        throwsA(isA<PersistedDataFormatException>()),
      );
    },
  );
}

final _query = LatestBurnerConditionRoundsQuery(
  actorUid: 'ia-1',
  assetInstanceIds: const ['furnace-2'],
);

AppUser _actor(String uid, {bool approved = true}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [AppRole.seniorInstrumentation],
  isApproved: approved,
  createdAt: DateTime.utc(2026, 9, 1),
);

class _Session {
  final actors = StreamController<AppUser?>();
  final database = _Database();
  late final container = ProviderContainer(
    overrides: [
      currentAppUserProvider.overrideWith((ref) => actors.stream),
      burnerConditionFirestoreProvider.overrideWithValue(database),
    ],
  );

  Future<void> start() async {
    container.listen(currentAppUserProvider, (_, __) {}, fireImmediately: true);
    actors.add(_actor('ia-1'));
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }
  }

  Future<Map<String, dynamic>> read() async =>
      container.read(burnerComplianceCurrentReaderProvider)(_query);

  Future<void> dispose() async {
    container.dispose();
    await actors.close();
  }
}

class _Database extends Fake implements FirebaseFirestore {
  final readSources = <Source?>[];
  Completer<void>? pointerGate, roundGate;
  Object? serverError;
  String? untrustedPhase, untrustedMetadata;
  bool mismatchedRound = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.database, this.path);
  final _Database database;
  @override
  final String path;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.fromIterable([
    _QuerySnapshot([
      _DocumentSnapshot('furnace-2', _pointer('cached-round')),
    ], cached: true),
    _QuerySnapshot([_DocumentSnapshot('furnace-2', _pointer('server-round'))]),
  ]);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    expect(path, 'burner_condition_current');
    database.readSources.add(options?.source);
    await database.pointerGate?.future;
    if (database.serverError != null) throw database.serverError!;
    return _QuerySnapshot(
      [_DocumentSnapshot('furnace-2', _pointer('server-round'))],
      cached:
          database.untrustedPhase == 'pointer' &&
          database.untrustedMetadata == 'cache',
      pending:
          database.untrustedPhase == 'pointer' &&
          database.untrustedMetadata == 'pending',
    );
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(this.path, 'burner_condition_rounds');
    return _Document(database, path!);
  }
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.database, this.id);
  final _Database database;
  @override
  final String id;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    database.readSources.add(options?.source);
    await database.roundGate?.future;
    return _DocumentSnapshot(
      id,
      {
        ..._round(id),
        if (database.mismatchedRound) 'assetInstanceId': 'another-furnace',
      },
      cached:
          database.untrustedPhase == 'round' &&
          database.untrustedMetadata == 'cache',
      pending:
          database.untrustedPhase == 'round' &&
          database.untrustedMetadata == 'pending',
    );
  }
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs, {this.cached = false, this.pending = false});
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool cached, pending;
  @override
  SnapshotMetadata get metadata => _Metadata(cached, pending);
}

class _DocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _DocumentSnapshot(
    this.id,
    this.value, {
    this.cached = false,
    this.pending = false,
  });
  @override
  final String id;
  final Map<String, dynamic> value;
  final bool cached, pending;
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
  @override
  SnapshotMetadata get metadata => _Metadata(cached, pending);
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

final _observedAt = DateTime.utc(2026, 9, 27);
Map<String, dynamic> _pointer(String roundId) => {
  'schemaVersion': 1,
  'assetInstanceId': 'furnace-2',
  'roundId': roundId,
  'observedAt': _observedAt,
  'updatedAt': _observedAt,
};

Map<String, dynamic> _round(String id) => {
  'schemaVersion': 1,
  'roundId': id,
  'operation': 'RECORD_BURNER_CONDITION_ROUND',
  'assetClassId': 'furnace-class',
  'assetClassCode': 'FURNACE',
  'assetClassName': 'Furnace',
  'assetInstanceId': 'furnace-2',
  'assetInstanceVersion': 1,
  'assetNumber': 2,
  'assetName': 'Furnace 2',
  'observations': List.generate(
    8,
    (index) => {
      'position': index + 1,
      'flameObservation': 'seen',
      'redHotObserved': index == 0,
      'microampReading': index == 1 ? 6.4 : null,
      'remarks': null,
    },
  ),
  'redHotPositions': [1],
  'microampPositions': [2],
  'roundNote': null,
  'observedAt': _observedAt,
  'recordedByUid': 'ops-1',
  'recordedByName': 'Operations',
  'directiveId': 'burner_round_red_hot_$id',
  'fingerprint': 'burnerround1-sha256:${'a' * 64}',
};
