import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/actor_session_cache_trust.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/burner_condition_round.dart';
import '../services/burner_condition_round_idempotency_store.dart';
import '../services/burner_condition_round_service.dart';

const burnerConditionRoundReportLimit = 1000;
const burnerConditionRoundHistoryDisclosure =
    'Showing up to $burnerConditionRoundReportLimit rounds in the selected period.';

final latestBurnerConditionRoundsProvider = StreamProvider.autoDispose
    .family<Map<String, BurnerConditionRound>, String>((ref, actorUid) {
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
          actor.uid != actorUid ||
          actorUid.trim().isEmpty) {
        throw StateError('Approved burner-condition access is required.');
      }
      final cacheTrust = ref.watch(burnerConditionRoundCacheTrustProvider)
        ..observeActor(actorUid);
      final snapshots = FirebaseFirestore.instance
          .collection('burner_condition_rounds')
          .orderBy('observedAt', descending: true)
          .limit(burnerConditionRoundReportLimit)
          .snapshots(includeMetadataChanges: true);
      return admitActorSessionSnapshots(
        snapshots,
        trust: cacheTrust,
        actorUid: actorUid,
        queryKey: 'latest-burner-condition-rounds',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map((snapshot) {
        final latest = <String, BurnerConditionRound>{};
        for (final document in snapshot.docs) {
          final round = BurnerConditionRound.fromMap(
            document.data(),
            document.id,
          );
          latest.putIfAbsent(round.assetInstanceId, () => round);
        }
        return Map<String, BurnerConditionRound>.unmodifiable(latest);
      });
    });

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
