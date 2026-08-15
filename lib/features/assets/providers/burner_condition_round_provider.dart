import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/burner_condition_round.dart';
import '../services/burner_condition_round_service.dart';

const burnerConditionRoundReportLimit = 1000;
const burnerConditionRoundHistoryDisclosure =
    'Showing up to $burnerConditionRoundReportLimit rounds in the selected period.';

typedef BurnerConditionRoundPeriod =
    ({DateTime startInclusive, DateTime endExclusive});

final burnerConditionRoundServiceProvider =
    Provider<BurnerConditionRoundService>((ref) {
      return BurnerConditionRoundService();
    });

final burnerConditionRoundsProvider = StreamProvider.family<
  List<BurnerConditionRound>,
  BurnerConditionRoundPeriod
>((ref, period) {
  return FirebaseFirestore.instance
      .collection('burner_condition_rounds')
      .where(
        'observedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(period.startInclusive),
      )
      .where('observedAt', isLessThan: Timestamp.fromDate(period.endExclusive))
      .orderBy('observedAt', descending: true)
      .limit(burnerConditionRoundReportLimit)
      .snapshots()
      .map(
        (snapshot) => List<BurnerConditionRound>.unmodifiable(
          snapshot.docs.map(
            (document) => BurnerConditionRound.fromMap(
              document.data(),
              document.id,
            ),
          ),
        ),
      );
});
