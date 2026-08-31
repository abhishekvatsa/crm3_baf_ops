import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/services/morning_review_command_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final contract = Map<String, dynamic>.from(
    jsonDecode(
          File(
            'test/fixtures/morning_review_command_contract_v1.json',
          ).readAsStringSync(),
        )
        as Map,
  );
  final operationFields = Map<String, dynamic>.from(
    contract['operations']! as Map,
  );
  const requestId = '11111111-1111-4111-8111-111111111111';
  const sessionId = '2026-08-31';
  const actionId = '22222222-2222-4222-8222-222222222222';
  const concernId = '33333333-3333-4333-8333-333333333333';
  const entry = MorningReviewEntryInput(
    section: MorningReviewSection.furnace,
    kind: MorningReviewEntryKind.update,
    text: 'Furnace 12 inspection remains in today\'s plan.',
    assetClassId: 'furnace-class',
    assetClassName: 'Furnace',
    assetInstanceId: 'furnace-12',
    assetNumber: '12',
    sourceReferences: ['maintenance_records/ticket-1'],
  );
  final action = MorningReviewActionInput(
    section: MorningReviewSection.furnace,
    text: 'Inspect Furnace 12 before the next charging plan.',
    assigneeUid: null,
    assigneeRole: 'seniorMechanical',
    assetClassId: 'furnace-class',
    assetClassName: 'Furnace',
    assetInstanceId: 'furnace-12',
    assetNumber: '12',
    dueAt: DateTime.utc(2026, 8, 31, 12, 30),
  );
  const concern = MorningReviewStandingConcernInput(
    title: 'Sheath purge valves',
    detail: 'Confirm open condition on every operating Base.',
    criticality: MorningReviewConcernCriticality.safety,
  );

  test('every mobile envelope matches the shared server key set', () {
    final extras = <MorningReviewCommand, Map<String, dynamic>>{
      MorningReviewCommand.start: const {},
      MorningReviewCommand.join: const {},
      MorningReviewCommand.addEntry: {'entryDraft': entry.toMap()},
      MorningReviewCommand.createAction: {'actionDraft': action.toMap()},
      MorningReviewCommand.acceptAction: const {
        'actionId': actionId,
        'expectedVersion': 1,
      },
      MorningReviewCommand.completeAction: const {
        'actionId': actionId,
        'expectedVersion': 1,
        'reason': 'Inspection completed.',
      },
      MorningReviewCommand.takeOver: const {
        'expectedVersion': 2,
        'reason': 'Facilitator handover.',
      },
      MorningReviewCommand.finalize: const {
        'expectedVersion': 3,
        'summary': 'Review complete.',
      },
      MorningReviewCommand.recordNotHeld: const {'reason': 'Plant shutdown.'},
      MorningReviewCommand.createStandingConcern: {
        'concernDraft': concern.toMap(),
      },
      MorningReviewCommand.resolveStandingConcern: const {
        'concernId': concernId,
        'expectedVersion': 1,
        'reason': 'Verified and closed.',
      },
      MorningReviewCommand.checkStandingConcern: const {
        'concernId': concernId,
        'checkState': 'complied',
        'reason': 'Verified today.',
      },
      MorningReviewCommand.addAddendum: {
        'entryDraft':
            const MorningReviewEntryInput(
              section: MorningReviewSection.plantWide,
              kind: MorningReviewEntryKind.addendum,
              text: 'Post-meeting clarification.',
            ).toMap(),
        'reason': 'Clarification requested by the facilitator.',
      },
    };
    final noSession = <MorningReviewCommand>{
      MorningReviewCommand.start,
      MorningReviewCommand.recordNotHeld,
    };

    expect(extras.keys.toSet(), MorningReviewCommand.values.toSet());
    expect(operationFields.keys.toSet(), {
      for (final operation in MorningReviewCommand.values) operation.wireName,
    });
    for (final operation in MorningReviewCommand.values) {
      final request = buildMorningReviewCommandRequest(
        operation: operation,
        requestId: requestId,
        sessionId: noSession.contains(operation) ? null : sessionId,
        extra: extras[operation]!,
      );
      final actual = request.keys.toList()..sort();
      expect(
        actual,
        List<String>.from(operationFields[operation.wireName]! as List),
        reason: operation.wireName,
      );
    }
  });

  test('nested mobile drafts match the shared server key sets', () {
    List<String> sortedKeys(Map<String, dynamic> value) =>
        value.keys.toList()..sort();

    expect(
      sortedKeys(entry.toMap()),
      List<String>.from(contract['entryDraftFields']! as List),
    );
    expect(
      sortedKeys(action.toMap()),
      List<String>.from(contract['actionDraftFields']! as List),
    );
    expect(
      sortedKeys(concern.toMap()),
      List<String>.from(contract['concernDraftFields']! as List),
    );
  });

  test('extra data cannot replace governed envelope identity', () {
    expect(
      () => buildMorningReviewCommandRequest(
        operation: MorningReviewCommand.start,
        requestId: requestId,
        extra: const {'operation': 'DELETE_EVERYTHING'},
      ),
      throwsArgumentError,
    );
  });

  test('only ambiguous callable outcomes retain replay identity', () {
    for (final code in const [
      'aborted',
      'deadline-exceeded',
      'internal',
      'unavailable',
      'unknown',
    ]) {
      expect(isUncertainMorningReviewCommandCode(code), isTrue, reason: code);
    }
    for (final code in const [
      'already-exists',
      'failed-precondition',
      'invalid-argument',
      'permission-denied',
      'unauthenticated',
    ]) {
      expect(isUncertainMorningReviewCommandCode(code), isFalse, reason: code);
    }
  });
}
