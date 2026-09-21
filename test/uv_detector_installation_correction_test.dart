import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/assets/data/uv_detector_installation_correction.dart';
import 'package:crm3_baf_ops/features/assets/repositories/uv_detector_correction_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> correction(String id, {String? prior}) => {
  'schemaVersion': 1,
  'version': 1,
  'correctionId': id,
  'correctsEventId': 'event-a',
  'expectedCurrentEventId': 'current-a',
  'expectedCurrentActionPerformedAt': '2026-09-19T10:00:00.000Z',
  'assetInstanceId': 'furnace-a',
  'assetClassId': 'furnace',
  'assetNumber': 1,
  'componentTag': 'UV-1',
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
UvDetectorInstallationCorrection row(String id, {String? prior}) =>
    UvDetectorInstallationCorrection.fromMap(correction(id, prior: prior), id);

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
            'expectedCurrentActionPerformedAt': '2026-09-19T10:00:00.000Z',
          },
        },
      });
      final receipt = WorkflowCommandReceipt(
        commandId: 'request-a',
        resultKey: 'uv-detector-installation-corrected',
        aggregateVersion: 1,
        appliedAt: DateTime.utc(2026, 9, 20, 10),
        result: {
          'correctionId': 'first',
          'correctsEventId': 'event-a',
          'expectedCurrentEventId': 'current-a',
          'expectedCurrentActionPerformedAt': '2026-09-19T10:00:00.000Z',
          'assetInstanceId': 'furnace-a',
          'assetClassId': 'furnace',
          'assetNumber': 1,
          'componentTag': 'UV-1',
          'burnerPosition': 1,
          'supersedesCorrectionId': null,
          'recordedActionPerformedAt': '2026-09-18T10:00:00.000Z',
          'correctedActionPerformedAt': '2026-09-17T10:00:00.000Z',
        },
      );
      UvDetectorInstallationCorrection check(Map<String, dynamic> value) =>
          UvDetectorCorrectionRepository.verifyCorrectionReadback(
            value,
            'first',
            receipt,
            envelope,
          );
      expect(check(data).id, 'first');
      for (final mutation in <Map<String, dynamic>>[
        {'expectedCurrentEventId': 'other-current'},
        {'expectedCurrentEventId': null},
        {'expectedCurrentActionPerformedAt': '2026-09-19T10:01:00.000Z'},
        {'expectedCurrentActionPerformedAt': null},
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
  test(
    'correction schema rejects unknown fields and malformed physical subjects',
    () {
      for (final mutation in <Map<String, dynamic>>[
        {'unregisteredEvidence': true},
        {'assetClassId': null},
        {'assetNumber': '1'},
        {'assetNumber': 27},
        {'componentTag': 1},
        {'burnerPosition': 9},
      ]) {
        expect(
          () => UvDetectorInstallationCorrection.fromMap({
            ...correction('first'),
            ...mutation,
          }, 'first'),
          throwsFormatException,
          reason: mutation.keys.single,
        );
      }
      final nullable = UvDetectorInstallationCorrection.fromMap({
        ...correction('first'),
        'componentTag': null,
      }, 'first');
      expect(nullable.componentTag, isNull);
      expect(nullable.assetClassId, 'furnace');
      expect(nullable.assetNumber, 1);
    },
  );

  test('all correction timestamps reject lossy sub-millisecond evidence', () {
    final instant = DateTime.utc(2026, 9, 19, 10);
    for (final field in const [
      'recordedActionPerformedAt',
      'correctedActionPerformedAt',
      'correctedAt',
      'expectedCurrentActionPerformedAt',
    ]) {
      for (final malformed in [
        '2026-09-19T10:00:00.000001Z',
        '2026-09-19T10:00:00.0000001Z',
        instant.add(const Duration(microseconds: 1)),
        Timestamp(instant.millisecondsSinceEpoch ~/ 1000, 1),
        Timestamp(instant.millisecondsSinceEpoch ~/ 1000, 1001),
      ]) {
        expect(
          () => UvDetectorInstallationCorrection.fromMap({
            ...correction('first'),
            field: malformed,
          }, 'first'),
          throwsFormatException,
          reason: '$field: $malformed',
        );
      }
    }
  });

  test(
    'a successor cannot precede its reviewer history or change physical identity',
    () {
      for (final mutation in <Map<String, dynamic>>[
        {'correctedAt': '2026-09-20T09:59:59.999Z'},
        {'assetClassId': 'different-class'},
        {'assetNumber': 2},
        {'componentTag': 'UV-2'},
        {'assetInstanceId': 'different-furnace'},
        {'recordedActionPerformedAt': '2026-09-18T09:00:00.000Z'},
      ]) {
        final successor = UvDetectorInstallationCorrection.fromMap({
          ...correction('second', prior: 'first'),
          ...mutation,
        }, 'second');
        expect(
          () => effectiveUvDetectorCorrection([
            row('first'),
            successor,
          ], 'event-a'),
          throwsStateError,
          reason: mutation.keys.single,
        );
      }
    },
  );

  test('selects exact successor regardless of query order', () {
    final second = row('second', prior: 'first');
    expect(
      effectiveUvDetectorCorrection([second, row('first')], 'event-a')?.id,
      'second',
    );
  });
  test('missing predecessor cannot be treated as a first correction', () {
    expect(
      () => effectiveUvDetectorCorrection([
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
        () => effectiveUvDetectorCorrection(rows, 'event-a'),
        throwsStateError,
      );
    }
    expect(
      () => effectiveUvDetectorCorrection([row('first')], 'other-event'),
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
          () => UvDetectorInstallationCorrection.fromMap(data, 'first'),
          throwsFormatException,
        );
      }
    },
  );
}
