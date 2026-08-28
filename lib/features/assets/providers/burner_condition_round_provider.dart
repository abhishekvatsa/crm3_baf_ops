import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/security/actor_session_cache_trust.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/burner_condition_round.dart';
import '../services/burner_condition_round_idempotency_store.dart';
import '../services/burner_condition_round_service.dart';

const burnerConditionRoundReportLimit = 1000;
const burnerConditionRoundHistoryDisclosure =
    'Showing up to $burnerConditionRoundReportLimit rounds in the selected period.';

@immutable
final class LatestBurnerConditionRoundsQuery {
  factory LatestBurnerConditionRoundsQuery({
    required String actorUid,
    required Iterable<String> assetInstanceIds,
  }) {
    final normalizedIds = assetInstanceIds
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort();
    return LatestBurnerConditionRoundsQuery._(
      actorUid: actorUid.trim(),
      assetInstanceIds: List<String>.unmodifiable(normalizedIds),
    );
  }

  const LatestBurnerConditionRoundsQuery._({
    required this.actorUid,
    required this.assetInstanceIds,
  });

  final String actorUid;
  final List<String> assetInstanceIds;

  String get cacheKey => <String>[
    'current-burner-condition-rounds',
    actorUid,
    ...assetInstanceIds,
  ].join('|');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatestBurnerConditionRoundsQuery &&
          actorUid == other.actorUid &&
          listEquals(assetInstanceIds, other.assetInstanceIds);

  @override
  int get hashCode => Object.hash(actorUid, Object.hashAll(assetInstanceIds));
}

final latestBurnerConditionRoundsProvider = StreamProvider.autoDispose.family<
  Map<String, BurnerConditionRound>,
  LatestBurnerConditionRoundsQuery
>((ref, query) {
  final actorAsync = ref.watch(currentAppUserProvider);
  if (actorAsync.isLoading) {
    throw StateError('Burner-condition access is still being verified.');
  }
  if (actorAsync.hasError) {
    throw StateError('Burner-condition access could not be verified.');
  }
  final actor = actorAsync.value;
  if (actor == null ||
      !actor.isApproved ||
      actor.uid != query.actorUid ||
      query.actorUid.isEmpty) {
    throw StateError('Approved burner-condition access is required.');
  }
  if (query.assetInstanceIds.isEmpty) {
    return Stream<Map<String, BurnerConditionRound>>.value(
      const <String, BurnerConditionRound>{},
    );
  }
  final cacheTrust = ref.watch(burnerConditionRoundCacheTrustProvider)
    ..observeActor(query.actorUid);
  final firestore = FirebaseFirestore.instance;
  final snapshots = firestore
      .collection('burner_condition_current')
      .snapshots(includeMetadataChanges: true);
  return admitActorSessionSnapshots(
    snapshots,
    trust: cacheTrust,
    actorUid: query.actorUid,
    queryKey: query.cacheKey,
    isFromCache: (snapshot) => snapshot.metadata.isFromCache,
    hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
  ).asyncMap(
    (snapshot) => _resolveCurrentBurnerConditionRounds(
      firestore: firestore,
      pointerSnapshot: snapshot,
      assetInstanceIds: query.assetInstanceIds,
    ),
  );
});

Future<Map<String, BurnerConditionRound>> _resolveCurrentBurnerConditionRounds({
  required FirebaseFirestore firestore,
  required QuerySnapshot<Map<String, dynamic>> pointerSnapshot,
  required List<String> assetInstanceIds,
}) async {
  final requestedIds = assetInstanceIds.toSet();
  final pointers = <String, BurnerConditionCurrentPointer>{};
  for (final document in pointerSnapshot.docs) {
    if (!requestedIds.contains(document.id)) continue;
    pointers[document.id] = BurnerConditionCurrentPointer.fromMap(
      document.data(),
      document.id,
    );
  }

  final roundsCollection = firestore.collection('burner_condition_rounds');
  final resolvedEntries = await Future.wait(
    assetInstanceIds.map((assetInstanceId) async {
      final pointer = pointers[assetInstanceId];
      if (pointer != null) {
        final document = await roundsCollection
            .doc(pointer.roundId)
            .get(const GetOptions(source: Source.server));
        final data = document.data();
        if (!document.exists || data == null) {
          throw PersistedDataFormatException(
            field: 'roundId',
            source: 'burner_condition_current/$assetInstanceId',
            detail: 'referenced round is missing',
          );
        }
        final round = BurnerConditionRound.fromMap(data, document.id);
        return MapEntry(assetInstanceId, pointer.requireMatchingRound(round));
      }

      final legacySnapshot = await roundsCollection
          .where('assetInstanceId', isEqualTo: assetInstanceId)
          .orderBy('observedAt', descending: true)
          .limit(2)
          .get(const GetOptions(source: Source.server));
      if (legacySnapshot.docs.isEmpty) {
        return MapEntry<String, BurnerConditionRound?>(assetInstanceId, null);
      }
      final round = BurnerConditionRound.fromMap(
        legacySnapshot.docs.first.data(),
        legacySnapshot.docs.first.id,
      );
      if (round.assetInstanceId != assetInstanceId) {
        throw PersistedDataFormatException(
          field: 'assetInstanceId',
          source: 'burner_condition_rounds/${round.roundId}',
          detail: 'does not match the requested governed asset',
        );
      }
      if (legacySnapshot.docs.length > 1) {
        final runnerUp = BurnerConditionRound.fromMap(
          legacySnapshot.docs[1].data(),
          legacySnapshot.docs[1].id,
        );
        if (runnerUp.observedAt.isAtSameMomentAs(round.observedAt)) {
          throw PersistedDataFormatException(
            field: 'observedAt',
            source: 'burner_condition_rounds/$assetInstanceId',
            detail:
                'legacy current round is ambiguous and needs reconciliation',
          );
        }
      }
      return MapEntry<String, BurnerConditionRound?>(assetInstanceId, round);
    }),
  );
  return Map<String, BurnerConditionRound>.unmodifiable(
    <String, BurnerConditionRound>{
      for (final entry in resolvedEntries)
        if (entry.value != null) entry.key: entry.value!,
    },
  );
}

typedef BurnerConditionRoundQuery =
    ({
      String actorUid,
      DateTime startInclusive,
      DateTime endExclusive,
      String? assetInstanceId,
    });

final burnerConditionRoundServiceProvider =
    Provider<BurnerConditionRoundService>((ref) {
      return BurnerConditionRoundService(
        idempotencyStore: ref.watch(
          burnerConditionRoundIdempotencyStoreProvider,
        ),
      );
    });

final burnerConditionRoundCacheTrustProvider = Provider<ActorSessionCacheTrust>(
  (ref) {
    final trust = ActorSessionCacheTrust();

    void observeAuthority(AsyncValue<AppUser?> authority) {
      if (authority.isLoading || authority.hasError) {
        trust.observeActor(null);
        return;
      }
      final actor = authority.value;
      trust.observeActor(actor != null && actor.isApproved ? actor.uid : null);
    }

    observeAuthority(ref.read(currentAppUserProvider));
    ref.listen<AsyncValue<AppUser?>>(currentAppUserProvider, (_, next) {
      observeAuthority(next);
    });
    return trust;
  },
);

final burnerConditionRoundsProvider = StreamProvider.autoDispose.family<
  List<BurnerConditionRound>,
  BurnerConditionRoundQuery
>((ref, query) {
  final actorAsync = ref.watch(currentAppUserProvider);
  if (actorAsync.isLoading) {
    throw StateError('Burner-report access is still being verified.');
  }
  if (actorAsync.hasError) {
    throw StateError('Burner-report access could not be verified.');
  }
  final actor = actorAsync.value;
  if (actor == null ||
      !actor.canViewReports ||
      actor.uid != query.actorUid ||
      query.actorUid.trim().isEmpty) {
    throw StateError('Approved burner-report access is required.');
  }
  final cacheTrust = ref.watch(burnerConditionRoundCacheTrustProvider)
    ..observeActor(query.actorUid);
  Query<Map<String, dynamic>> rounds = FirebaseFirestore.instance.collection(
    'burner_condition_rounds',
  );
  final assetInstanceId = query.assetInstanceId?.trim();
  if (assetInstanceId != null && assetInstanceId.isNotEmpty) {
    rounds = rounds.where('assetInstanceId', isEqualTo: assetInstanceId);
  }
  final snapshots = rounds
      .where(
        'observedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(query.startInclusive),
      )
      .where('observedAt', isLessThan: Timestamp.fromDate(query.endExclusive))
      .orderBy('observedAt', descending: true)
      .limit(burnerConditionRoundReportLimit)
      .snapshots(includeMetadataChanges: true);
  return admitActorSessionSnapshots(
    snapshots,
    trust: cacheTrust,
    actorUid: query.actorUid,
    queryKey: burnerConditionRoundQueryKey(query),
    isFromCache: (snapshot) => snapshot.metadata.isFromCache,
    hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
  ).map(
    (snapshot) => List<BurnerConditionRound>.unmodifiable(
      snapshot.docs.map(
        (document) =>
            BurnerConditionRound.fromMap(document.data(), document.id),
      ),
    ),
  );
});

String burnerConditionRoundQueryKey(BurnerConditionRoundQuery query) {
  final assetInstanceId = query.assetInstanceId?.trim();
  return <String>[
    'burner-rounds',
    query.startInclusive.toUtc().toIso8601String(),
    query.endExclusive.toUtc().toIso8601String(),
    assetInstanceId == null || assetInstanceId.isEmpty ? '*' : assetInstanceId,
  ].join('|');
}
