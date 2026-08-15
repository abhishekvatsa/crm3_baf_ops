import 'dart:convert';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('burner lockout contract', () {
    test('round-trips all eight-position intake and resolution evidence', () {
      final intake = BurnerLockoutCase(
        positions: const <int>[1, 4, 8],
        commonMode: true,
        cycleStage: BurnerCycleStage.ignition,
        hmiAlarm: 'Flame failure',
        flameObservation: BurnerObservation.notSeen,
        sparkObservation: BurnerObservation.seen,
        relightAttempts: 2,
        remainsLockedOut: true,
        redHotPositions: const <int>[4],
      );
      final resolved = intake.withResolution(
        BurnerLockoutResolution(
          outcomes: const <int, BurnerResolutionOutcome>{
            1: BurnerResolutionOutcome.returnedToService,
            4: BurnerResolutionOutcome.isolatedForFollowUp,
            8: BurnerResolutionOutcome.remainsLockedOut,
          },
        ),
      );

      final decoded = BurnerLockoutCase.fromSynchronizedFields(
        resolved.toSynchronizedFields(),
        source: 'test',
      );

      expect(decoded.positions, <int>[1, 4, 8]);
      expect(decoded.redHotPositions, <int>[4]);
      expect(decoded.isResolutionComplete, isTrue);
      expect(
        decoded.resolutionOutcomes[4],
        BurnerResolutionOutcome.isolatedForFollowUp,
      );
      expect(burnerTag(3, 8), 'FR-03-B08');
    });

    test('partial synchronized fields fail closed', () {
      expect(
        () =>
            BurnerLockoutCase.readOptionalSynchronizedFields(<String, dynamic>{
              'burnerLockoutSchemaVersion': 1,
              'burnerPositions': <int>[1],
            }, source: 'partial'),
        throwsFormatException,
      );
    });

    test('duplicate burner positions fail closed instead of normalizing', () {
      final fields =
          BurnerLockoutCase(
            positions: const <int>[1, 2],
            commonMode: true,
            cycleStage: BurnerCycleStage.ignition,
            flameObservation: BurnerObservation.notSeen,
            sparkObservation: BurnerObservation.seen,
            relightAttempts: 1,
            remainsLockedOut: true,
          ).toSynchronizedFields();
      fields['burnerPositions'] = <int>[1, 1];

      expect(
        () => BurnerLockoutCase.fromSynchronizedFields(
          fields,
          source: 'duplicate',
        ),
        throwsFormatException,
      );
    });

    test('classified local records require a complete burner envelope', () {
      final record =
          MaintenanceRecord()
            ..firestoreId = 'ticket-1'
            ..classification = burnerLockoutClassification
            ..metadataJson = '{malformed';

      expect(() => record.burnerLockoutCase, throwsFormatException);
      expect(record.burnerLockoutReadResult.isValid, isFalse);
    });

    test('red-hot and outcome positions cannot escape selected burners', () {
      expect(
        () => BurnerLockoutCase(
          positions: const <int>[1],
          commonMode: false,
          cycleStage: BurnerCycleStage.firing,
          flameObservation: BurnerObservation.seen,
          sparkObservation: BurnerObservation.notChecked,
          relightAttempts: 0,
          remainsLockedOut: false,
          redHotPositions: const <int>[2],
        ),
        throwsFormatException,
      );
    });

    test('return to service rejects reset-only evidence', () {
      final intake = BurnerLockoutCase(
        positions: const <int>[2],
        commonMode: false,
        cycleStage: BurnerCycleStage.ignition,
        flameObservation: BurnerObservation.notSeen,
        sparkObservation: BurnerObservation.seen,
        relightAttempts: 1,
        remainsLockedOut: true,
      );
      final resolution = BurnerLockoutResolution(
        outcomes: const <int, BurnerResolutionOutcome>{
          2: BurnerResolutionOutcome.returnedToService,
        },
      );
      final reset = buildBurnerComponentAction(
        ticketId: 'ticket-1',
        furnaceNumber: 1,
        burnerPosition: 2,
        code: BurnerActionCode.feedbackReset,
        outcome: BurnerResolutionOutcome.returnedToService,
        performedBy: 'I&A',
        performedAt: DateTime.utc(2026, 8, 15),
      );

      expect(
        () => validateBurnerResolutionEvidence(
          lockout: intake,
          resolution: resolution,
          actions: [reset],
        ),
        throwsStateError,
      );

      final cleaning = buildBurnerComponentAction(
        ticketId: 'ticket-1',
        furnaceNumber: 1,
        burnerPosition: 2,
        code: BurnerActionCode.uvDetectorCleaning,
        outcome: BurnerResolutionOutcome.returnedToService,
        performedBy: 'I&A',
        performedAt: DateTime.utc(2026, 8, 15),
      );
      expect(
        () => validateBurnerResolutionEvidence(
          lockout: intake,
          resolution: resolution,
          actions: [reset, cleaning],
        ),
        returnsNormally,
      );
    });

    test('local metadata merge preserves quality intent', () {
      final intake = BurnerLockoutCase(
        positions: const <int>[3],
        commonMode: false,
        cycleStage: BurnerCycleStage.unknown,
        flameObservation: BurnerObservation.notChecked,
        sparkObservation: BurnerObservation.notChecked,
        relightAttempts: 0,
        remainsLockedOut: true,
      );
      final encoded = mergeBurnerLockoutIntoMaintenanceMetadata(
        jsonEncode(<String, dynamic>{
          'qualityIntent': <String, dynamic>{
            'schemaVersion': 1,
            'assessment': 'notSuspected',
            'warningReason': null,
          },
        }),
        intake,
      );
      final root = jsonDecode(encoded) as Map<String, dynamic>;

      expect(root['qualityIntent'], isA<Map>());
      expect(BurnerLockoutCase.tryDecodeLocal(encoded)?.positions, <int>[3]);
    });
  });
}
