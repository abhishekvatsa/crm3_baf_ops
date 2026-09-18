import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fact({Map<String, dynamic> extra = const {}}) => {
  'factId': 'inspection_findings/finding-1',
  'section': 'furnace',
  'sourceType': 'inspectionFinding',
  'sourceCollection': 'inspection_findings',
  'sourceDocumentId': 'finding-1',
  'title': 'Inspection finding',
  'summary': 'awaitingVerification: Furnace 1',
  'status': 'awaitingVerification',
  'assetClassId': 'furnace-class',
  'assetClassName': 'Furnace',
  'assetInstanceId': 'furnace-1',
  'assetNumber': '1',
  'observedAtIso': '2026-08-30T03:00:00.000Z',
  ...extra,
};

void main() {
  group('reading a frozen morning-review source fact', () {
    test('a record written before the qualifier existed still reads', () {
      final fact = MorningReviewSourceFact.fromMap(_fact(), source: 'test');

      expect(fact.evidenceReviewRequired, isFalse);
      expect(fact.evidenceReviewReason, isNull);
      expect(fact.effectiveAdverseObservationCount, isNull);
    });

    test('a record carrying the qualifier reads it', () {
      final fact = MorningReviewSourceFact.fromMap(
        _fact(
          extra: const {
            'evidenceReviewRequired': true,
            'evidenceReviewReason': 'inspection-episode-adverse-basis-corrected',
            'effectiveAdverseObservationCount': 0,
          },
        ),
        source: 'test',
      );

      // The manager must be able to tell this from an ordinary item awaiting
      // verification, which is the whole point of carrying it.
      expect(fact.evidenceReviewRequired, isTrue);
      expect(
        fact.evidenceReviewReason,
        'inspection-episode-adverse-basis-corrected',
      );
      expect(fact.effectiveAdverseObservationCount, 0);
    });

    test('a field nobody named is still refused', () {
      expect(
        () => MorningReviewSourceFact.fromMap(
          _fact(extra: const {'somethingElse': true}),
          source: 'test',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('a malformed qualifier fails closed rather than defaulting', () {
      expect(
        () => MorningReviewSourceFact.fromMap(
          _fact(extra: const {'evidenceReviewRequired': 'yes'}),
          source: 'test',
        ),
        throwsA(isA<Exception>()),
        reason:
            'a present value the producer got wrong is a fault, not a reason '
            'to read it as false',
      );
      expect(
        () => MorningReviewSourceFact.fromMap(
          _fact(extra: const {'effectiveAdverseObservationCount': 'two'}),
          source: 'test',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('a missing required field is still refused', () {
      final map = _fact()..remove('status');

      expect(
        () => MorningReviewSourceFact.fromMap(map, source: 'test'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
