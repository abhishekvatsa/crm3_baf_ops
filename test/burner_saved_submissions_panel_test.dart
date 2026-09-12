import 'dart:convert';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/assets/presentation/burner_saved_submissions_panel.dart';
import 'package:crm3_baf_ops/features/assets/services/burner_condition_round_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/test_support/in_memory_durable_submission_store.dart';

void main() {
  testWidgets(
    'reopened panel displays original observations and retries the original saved submission',
    (tester) async {
      final store = InMemoryDurableSubmissionStore();
      final row = await store.prepare(
        DurableSubmissionDraft(
          submissionId: 'saved-round',
          actorUid: 'operator-a',
          requestId: 'saved-round',
          aggregateId: 'furnace-a',
          resourceKey: 'burnerEvidence:furnace-a',
          protocol: 'assetHierarchy.v2',
          envelopeJson: jsonEncode({
            'protocolVersion': 2,
            'originActorUid': 'operator-a',
            'request': {
              'requestId': 'saved-round',
              'operation': 'RECORD_BURNER_CONDITION_ROUND',
              'assetClassId': 'furnace',
              'assetInstanceId': 'furnace-a',
              'expectedAssetVersion': 4,
              'observations': [
                {
                  'position': 1,
                  'flameObservation': 'seen',
                  'redHotObserved': true,
                  'microampReading': 3.7,
                  'remarks': 'Original burner evidence',
                },
              ],
              'roundNote': 'Original note',
            },
          }),
          displayMetadataJson: jsonEncode({'furnaceName': 'Furnace A'}),
        ),
      );
      final service = _SavedService([row]);
      DurableSubmission? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BurnerSavedSubmissionsPanel(
                service: service,
                actorUid: 'operator-a',
                refreshKey: 0,
                onLoaded: (_) {},
                onCheck: (saved) async => received = saved,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Note: Original note'), findsOneWidget);
      expect(find.textContaining('Original burner evidence'), findsOneWidget);
      expect(find.textContaining('3.7'), findsOneWidget);
      await tester.tap(find.text('Check saved round'));
      await tester.pumpAndSettle();
      expect(received?.submissionId, row.submissionId);
      expect(received?.envelopeJson, row.envelopeJson);
    },
  );

  testWidgets(
    'legacy hash-only evidence is visibly held and cannot be dispatched',
    (tester) async {
      // UI fixture only; native byte custody is proved by the controller test.
      final legacy = DurableSubmission(
        submissionId: 'legacy-burner',
        actorUid: null,
        requestId: 'unknown',
        aggregateId: 'unknown',
        resourceKey: 'legacyBurner:old',
        protocol: 'legacy.reviewOnly',
        envelopeJson: '{}',
        displayMetadataJson: null,
        state: DurableSubmissionState.needsReview,
        attemptCount: 0,
        createdAt: DateTime.utc(2026, 9, 12),
        updatedAt: DateTime.utc(2026, 9, 12),
        claimToken: null,
        claimExpiresAt: null,
        nextRetryAt: null,
        receiptJson: null,
        receiptSha256: null,
        lastErrorCode: null,
        lastErrorMessage: null,
        legacySourceKey: 'old-prefs',
        legacySourceBase64: base64Encode(utf8.encode('{old bytes')),
      );
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BurnerSavedSubmissionsPanel(
              service: _SavedService([legacy]),
              actorUid: 'operator-a',
              refreshKey: 0,
              onLoaded: (_) {},
              onCheck: (_) async => sends++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Older Burner/UV retry details need support review',
        ),
        findsOneWidget,
      );
      expect(find.text('Check saved round'), findsNothing);
      expect(sends, 0);
    },
  );
}

class _SavedService extends BurnerConditionRoundService {
  _SavedService(this.rows);
  final List<DurableSubmission> rows;
  @override
  Future<List<DurableSubmission>> pending() async => rows;
}
