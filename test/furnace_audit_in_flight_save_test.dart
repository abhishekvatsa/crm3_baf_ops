import 'package:crm3_baf_ops/features/assets/data/burner_block_condition_projection.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/assets/domain/furnace_audit_draft.dart';
import 'package:flutter_test/flutter_test.dart';

BurnerBlockConditionProjection _projection(String sourceKey) =>
    BurnerBlockConditionProjection(
      sourceKey: sourceKey,
      latestEvidenceAt: DateTime.utc(2026, 8, 28, 9),
      redHotPositions: const <int>{},
      replacementsByPosition: const {},
      uvConditionsByPosition: <int, BurnerUvCondition>{
        for (var position = 1; position <= 8; position++)
          position: BurnerUvCondition.serviceable,
      },
      uvReplacementsByPosition: const {},
    );

FurnaceAuditDraft _draft({String sourceKey = 'round-1'}) =>
    FurnaceAuditDraft.fromSources(
      round: null,
      conditionProjection: _projection(sourceKey),
    );

void main() {
  test('successor edits rebase on acceptance and use the accepted round', () {
    final draft = _draft();
    draft.setRedHot(1, true);
    draft.markEdited();
    final submitted = draft.captureSubmission();
    draft.setRedHot(2, true);
    draft.markEdited();
    expect(submitted.values['burners.2.redHotObserved'], false);
    draft.acceptSubmission(submitted, 'round-2', DateTime.utc(2026, 9, 1));
    final fresh = _draft(sourceKey: 'round-2');
    fresh.setRedHot(1, true);
    fresh.hotAirAtDraftSealObserved = true;
    draft.updateBasis(
      fresh,
      roundId: 'round-2',
      observedAt: DateTime.utc(2026, 9, 1),
    );
    expect(draft.composedAgainstRoundId, 'round-2');
    expect(draft.awaitingAcceptedBasis, false);
    expect(draft.redHotPositions, {1, 2});
    expect(draft.hotAirAtDraftSealObserved, true);
    expect(draft.observedFields, {'burners.2.redHotObserved'});
    expect(draft.dirty, true);
  });

  test(
    'a later update retains independent edits but requires review for conflicts',
    () {
      final draft = _draft();
      draft.uvByPosition[1] = BurnerUvCondition.missing;
      draft.markEdited();
      final independent = _draft(sourceKey: 'round-2');
      independent.setRedHot(3, true);
      draft.updateBasis(independent);
      expect(draft.redHotPositions, {3});
      expect(draft.uvByPosition[1], BurnerUvCondition.missing);
      expect(draft.requiresReview, false);
      final conflicting = _draft(sourceKey: 'round-3');
      conflicting.uvByPosition[1] = BurnerUvCondition.melted;
      draft.updateBasis(conflicting);
      expect(draft.requiresReview, true);
      expect(draft.conflicts, {'uv.1.condition'});
      expect(draft.composedAgainstRoundId, 'round-2');
      draft.reviewCurrent(keepLocalEdits: true);
      expect(draft.composedAgainstRoundId, 'round-3');
      expect(draft.uvByPosition[1], BurnerUvCondition.missing);
      expect(draft.observedFields, {'uv.1.condition'});
    },
  );

  test(
    'confirming a category does not renew untouched flame or signal fields',
    () {
      final draft = _draft();
      expect(draft.isKnown('burners.1.redHotObserved'), false);
      draft.confirmFields([
        for (var n = 1; n <= 8; n++) 'burners.$n.redHotObserved',
      ]);
      draft.markEdited();
      expect(draft.observedFields.length, 8);
      expect(
        draft.observedFields,
        isNot(contains('burners.1.microampReading')),
      );
      expect(draft.isKnown('burners.1.redHotObserved'), true);
    },
  );

  group('a furnace audit draft saved while it is being edited', () {
    test('an observation recorded during the save stays pending', () {
      final draft = _draft();
      draft.markEdited(); // the operator marks position 1 red hot
      final submittedRevision = draft.revision;

      // The save is in flight. The controls are still live, so position 2 is
      // marked too before the answer comes back.
      draft.markEdited();

      expect(draft.settleSave(submittedRevision), isFalse);
      expect(
        draft.dirty,
        isTrue,
        reason:
            'the second observation was not in the envelope that was sent, so '
            'it is still waiting to be recorded',
      );
    });

    test(
      'a draft that stays pending is not replaced by the saved snapshot',
      () {
        final draft = _draft();
        draft.markEdited();
        final submittedRevision = draft.revision;
        draft.markEdited();
        draft.settleSave(submittedRevision);

        // The save produced a new round, so the next snapshot of this furnace
        // arrives under a different source key. Adopting it here would discard
        // the observation the operator has just recorded.
        expect(draft.shouldAdoptSnapshot('round-2'), isFalse);
      },
    );

    test('an undisturbed save settles and its snapshot is adopted', () {
      final draft = _draft();
      draft.markEdited();

      expect(draft.settleSave(draft.revision), isTrue);
      expect(draft.dirty, isFalse);
      expect(draft.shouldAdoptSnapshot('round-2'), isTrue);
    });

    test('a settled draft keeps its own snapshot rather than rebuilding', () {
      final draft = _draft();
      draft.markEdited();
      draft.settleSave(draft.revision);

      expect(draft.shouldAdoptSnapshot('round-1'), isFalse);
    });

    test('an untouched draft is replaced when the evidence moves on', () {
      expect(_draft().shouldAdoptSnapshot('round-2'), isTrue);
    });

    test('a draft names the round it was composed against', () {
      // The source key leads with the round, which is what lets a submission
      // say what its eight positions were witnessed against.
      expect(
        FurnaceAuditDraft.fromSources(
          round: null,
          conditionProjection: _projection('round-7|red:1:2026-09-01'),
        ).composedAgainstRoundId,
        'round-7',
      );
      expect(
        FurnaceAuditDraft.fromSources(
          round: null,
          conditionProjection: _projection('none|red:1:2026-09-01'),
        ).composedAgainstRoundId,
        isNull,
      );
    });
  });
}
