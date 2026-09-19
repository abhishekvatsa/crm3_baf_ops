import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_block_installation_correction.dart';
import 'package:crm3_baf_ops/features/assets/repositories/burner_block_correction_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> correction(String id, {String? prior}) => {
  'schemaVersion': 1,
  'version': 1,
  'correctionId': id,
  'correctsEventId': 'event-a',
  'expectedCurrentEventId': 'current-a',
  'assetInstanceId': 'furnace-a',
  'burnerPosition': 1,
  'recordedActionPerformedAt': '2026-09-18T10:00:00.000Z',
  'correctedActionPerformedAt': Timestamp.fromDate(
    DateTime.utc(2026, 9, 17, 10),
  ),
  'correctedAt': '2026-09-20T10:00:00.000Z',
  'reason': 'Correct physical time.',
  'correctedByUid': 'admin-a',
  'correctedByName': 'Admin A',
  'supersedesCorrectionId': prior,
};
BurnerBlockInstallationCorrection row(String id, {String? prior}) =>
    BurnerBlockInstallationCorrection.fromMap(correction(id, prior: prior), id);

void main() {
  test(
    'actual server readback verifier binds recorded correction to original command and receipt',
    () {
      final data = correction('first');
      final envelope = jsonEncode({
        'originActorUid': 'admin-a',
        'command': {
          'payload': {
            'reason': 'Correct physical time.',
            'expectedCurrentEventId': 'current-a',
          },
        },
      });
      final receipt = WorkflowCommandReceipt(
        commandId: 'request-a',
        resultKey: 'burner-block-installation-corrected',
        aggregateVersion: 1,
        appliedAt: DateTime.utc(2026, 9, 20, 10),
        result: {
          'correctionId': 'first',
          'correctsEventId': 'event-a',
          'expectedCurrentEventId': 'current-a',
          'assetInstanceId': 'furnace-a',
          'burnerPosition': 1,
          'supersedesCorrectionId': null,
          'recordedActionPerformedAt': '2026-09-18T10:00:00.000Z',
          'correctedActionPerformedAt': '2026-09-17T10:00:00.000Z',
        },
      );
      BurnerBlockInstallationCorrection check(Map<String, dynamic> value) =>
          BurnerBlockCorrectionRepository.verifyCorrectionReadback(
            value,
            'first',
            receipt,
            envelope,
          );
      expect(check(data).id, 'first');
      for (final mutation in <Map<String, dynamic>>[
        {'expectedCurrentEventId': 'other-current'},
        {'expectedCurrentEventId': null},
        {'reason': 'Changed explanation'},
        {'correctedByUid': 'admin-b'},
        {'correctsEventId': 'other-event'},
        {'burnerPosition': 2},
        {'supersedesCorrectionId': 'invented-prior'},
        {'recordedActionPerformedAt': '2026-09-16T10:00:00.000Z'},
        {'correctedActionPerformedAt': '2026-09-16T10:00:00.000Z'},
        {'correctedAt': '2026-09-21T10:00:00.000Z'},
      ]) {
        expect(
          () => check({...data, ...mutation}),
          throwsA(anything),
          reason: mutation.keys.single,
        );
      }
    },
  );

  test('retains original time and decodes a Firestore effective timestamp', () {
    final value = row('first');
    expect(value.originalAt, DateTime.utc(2026, 9, 18, 10));
    expect(value.effectiveAt, DateTime.utc(2026, 9, 17, 10));
  });
  test('selects exact successor regardless of query order', () {
    final second = row('second', prior: 'first');
    expect(
      effectiveBurnerBlockCorrection([second, row('first')], 'event-a')?.id,
      'second',
    );
  });
  test('missing predecessor cannot be treated as a first correction', () {
    expect(
      () => effectiveBurnerBlockCorrection([
        row('second', prior: 'missing'),
      ], 'event-a'),
      throwsStateError,
    );
  });
  test('branches, cycles and unrelated subjects fail closed', () {
    for (final rows in [
      [
        row('first'),
        row('second', prior: 'first'),
        row('third', prior: 'first'),
      ],
      [row('first', prior: 'second'), row('second', prior: 'first')],
      [row('first'), row('disconnected')],
    ]) {
      expect(
        () => effectiveBurnerBlockCorrection(rows, 'event-a'),
        throwsStateError,
      );
    }
    expect(
      () => effectiveBurnerBlockCorrection([row('first')], 'other-event'),
      throwsStateError,
    );
  });
  test(
    'unknown version, missing reviewer, identity mismatch and future correction are refused',
    () {
      for (final data in [
        {...correction('first'), 'version': 2},
        {...correction('first'), 'correctedByUid': null},
        {...correction('first'), 'correctionId': 'other'},
        {
          ...correction('first'),
          'correctedActionPerformedAt': '2027-01-01T00:00:00.000Z',
        },
      ]) {
        expect(
          () => BurnerBlockInstallationCorrection.fromMap(data, 'first'),
          throwsFormatException,
        );
      }
    },
  );
}
