import 'dart:convert';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
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
        actions: <ComponentAction>[
          _action(1, BurnerActionCode.uvDetectorCleaning),
          _action(
            4,
            BurnerActionCode.poking,
            outcome: BurnerResolutionOutcome.isolatedForFollowUp,
          ),
          _action(
            8,
            BurnerActionCode.airLineCleaning,
            outcome: BurnerResolutionOutcome.remainsLockedOut,
          ),
        ],
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
      expect(decoded.resolutionActionCodes[1], <BurnerActionCode>[
        BurnerActionCode.uvDetectorCleaning,
      ]);
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

    test('historical action evidence reconstructs exact burner outcomes', () {
      final intake = BurnerLockoutCase(
        positions: const <int>[2, 5],
        commonMode: true,
        cycleStage: BurnerCycleStage.ignition,
        flameObservation: BurnerObservation.notSeen,
        sparkObservation: BurnerObservation.seen,
        relightAttempts: 1,
        remainsLockedOut: true,
      );
      final actions = <ComponentAction>[
        _action(2, BurnerActionCode.flameAdjustment),
        _action(
          5,
          BurnerActionCode.safetyShutoffValveRelayWork,
          outcome: BurnerResolutionOutcome.isolatedForFollowUp,
        ),
      ];

      final resolved = intake.withResolutionFromActions(actions);

      expect(resolved.attendedPositions, <int>[2, 5]);
      expect(
        resolved.resolutionOutcomes[5],
        BurnerResolutionOutcome.isolatedForFollowUp,
      );
      expect(
        () => validatePersistedBurnerResolutionEvidence(
          lockout: resolved,
          actions: actions,
        ),
        returnsNormally,
      );
    });

    test('persisted projection must match structured action evidence', () {
      final fields =
          BurnerLockoutCase(
            positions: const <int>[2],
            commonMode: false,
            cycleStage: BurnerCycleStage.ignition,
            flameObservation: BurnerObservation.notSeen,
            sparkObservation: BurnerObservation.seen,
            relightAttempts: 1,
            remainsLockedOut: true,
          ).toSynchronizedFields();
      fields['burnerAttendedPositions'] = <int>[2];
      fields['burnerResolutionEvidence'] = <String, dynamic>{
        '2': <String, dynamic>{
          'outcome': BurnerResolutionOutcome.returnedToService.name,
          'actionCodes': <String>[BurnerActionCode.feedbackReset.name],
        },
      };

      expect(
        () => BurnerLockoutCase.fromSynchronizedFields(
          fields,
          source: 'reset-only projection',
        ),
        throwsFormatException,
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

ComponentAction _action(
  int position,
  BurnerActionCode code, {
  BurnerResolutionOutcome outcome = BurnerResolutionOutcome.returnedToService,
}) => buildBurnerComponentAction(
  ticketId: 'ticket-1',
  furnaceNumber: 1,
  burnerPosition: position,
  code: code,
  outcome: outcome,
  performedBy: 'I&A',
  performedAt: DateTime.utc(2026, 8, 15),
);
