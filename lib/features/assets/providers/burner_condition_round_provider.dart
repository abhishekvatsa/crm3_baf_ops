import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/burner_condition_round.dart';
import '../services/burner_condition_round_idempotency_store.dart';
import '../services/burner_condition_round_service.dart';
import '../../auth/providers/auth_provider.dart';

const burnerConditionRoundReportLimit = 1000;
const burnerConditionRoundHistoryDisclosure =
    'Showing up to $burnerConditionRoundReportLimit rounds in the selected period.';

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
  Query<Map<String, dynamic>> rounds = FirebaseFirestore.instance.collection(
    'burner_condition_rounds',
  );
  final assetInstanceId = query.assetInstanceId?.trim();
  if (assetInstanceId != null && assetInstanceId.isNotEmpty) {
    rounds = rounds.where('assetInstanceId', isEqualTo: assetInstanceId);
  }
  return rounds
      .where(
        'observedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(query.startInclusive),
      )
      .where('observedAt', isLessThan: Timestamp.fromDate(query.endExclusive))
      .orderBy('observedAt', descending: true)
      .limit(burnerConditionRoundReportLimit)
      .snapshots()
      .map(
        (snapshot) => List<BurnerConditionRound>.unmodifiable(
          snapshot.docs.map(
            (document) =>
                BurnerConditionRound.fromMap(document.data(), document.id),
          ),
        ),
      );
});
