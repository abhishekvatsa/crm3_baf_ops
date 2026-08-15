import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:crm3_baf_ops/features/reports/models/burner_reliability_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'aggregates lockout, red-hot, outcome, microamp and action evidence',
    () {
      final open = _ticket(
        id: 'open-1',
        furnaceNumber: 2,
        startedAt: DateTime.utc(2026, 8, 10),
        lockout: BurnerLockoutCase(
          positions: const [1, 2],
          commonMode: true,
          cycleStage: BurnerCycleStage.firing,
          flameObservation: BurnerObservation.notSeen,
          sparkObservation: BurnerObservation.notChecked,
          relightAttempts: 0,
          remainsLockedOut: true,
          redHotPositions: const [2],
        ),
      );
      final returnedAction = buildBurnerComponentAction(
        ticketId: 'closed-1',
        furnaceNumber: 2,
        burnerPosition: 1,
        code: BurnerActionCode.uvDetectorCleaning,
        outcome: BurnerResolutionOutcome.returnedToService,
        microampReading: 3.4,
        performedBy: 'I&A One',
        performedAt: DateTime.utc(2026, 8, 12, 10),
      );
      final returned = _ticket(
        id: 'closed-1',
        furnaceNumber: 2,
        startedAt: DateTime.utc(2026, 8, 12, 8),
        lockout: BurnerLockoutCase(
          positions: const [1],
          commonMode: false,
          cycleStage: BurnerCycleStage.ignition,
          flameObservation: BurnerObservation.notSeen,
          sparkObservation: BurnerObservation.seen,
          relightAttempts: 1,
          remainsLockedOut: true,
        ).withResolution(
          BurnerLockoutResolution(
            outcomes: const {1: BurnerResolutionOutcome.returnedToService},
            microampReadings: const {1: 3.4},
          ),
          actions: [returnedAction],
        ),
        actions: [returnedAction],
        resolved: true,
      );
      final followUpAction = buildBurnerComponentAction(
        ticketId: 'closed-2',
        furnaceNumber: 1,
        burnerPosition: 8,
        code: BurnerActionCode.poking,
        outcome: BurnerResolutionOutcome.isolatedForFollowUp,
        performedBy: 'I&A One',
        performedAt: DateTime.utc(2026, 8, 11, 10),
      );
      final followUp = _ticket(
        id: 'closed-2',
        furnaceNumber: 1,
        startedAt: DateTime.utc(2026, 8, 11, 8),
        lockout: BurnerLockoutCase(
          positions: const [8],
          commonMode: false,
          cycleStage: BurnerCycleStage.ignition,
          flameObservation: BurnerObservation.notSeen,
          sparkObservation: BurnerObservation.seen,
          relightAttempts: 2,
          remainsLockedOut: true,
        ).withResolution(
          BurnerLockoutResolution(
            outcomes: const {8: BurnerResolutionOutcome.isolatedForFollowUp},
          ),
          actions: [followUpAction],
        ),
        actions: [followUpAction],
        resolved: true,
      );

      final report = buildBurnerReliabilityReport([open, returned, followUp]);

      expect(report.issueCount, 3);
      expect(report.furnaceCount, 2);
      expect(report.openPositionCount, 2);
      expect(report.redHotObservationCount, 1);
      expect(report.readingCount, 1);
      expect(report.rows.map((row) => row.displayTag), [
        'FR-01-B08',
        'FR-02-B01',
        'FR-02-B02',
      ]);
      final burnerOne = report.rows[1];
      expect(burnerOne.issueCount, 2);
      expect(burnerOne.openCount, 1);
      expect(burnerOne.returnedCount, 1);
      expect(burnerOne.latestMicroampReading, 3.4);
      expect(burnerOne.actionCounts[BurnerActionCode.uvDetectorCleaning], 1);
      expect(report.actionColumns, contains(BurnerActionCode.poking));
    },
  );

  test('classified malformed burner evidence fails the report closed', () {
    final corrupt = _ticket(
      id: 'corrupt',
      furnaceNumber: 3,
      startedAt: DateTime.utc(2026, 8, 13),
      lockout: BurnerLockoutCase(
        positions: const [1],
        commonMode: false,
        cycleStage: BurnerCycleStage.firing,
        flameObservation: BurnerObservation.seen,
        sparkObservation: BurnerObservation.notChecked,
        relightAttempts: 0,
        remainsLockedOut: false,
      ),
    )..metadataJson = '{malformed';

    expect(() => buildBurnerReliabilityReport([corrupt]), throwsStateError);
  });

  test('reopened ticket retains validated historical closure evidence', () {
    final closedAt = DateTime.utc(2026, 8, 14, 10);
    final historicalAction = buildBurnerComponentAction(
      ticketId: 'reopened-1',
      furnaceNumber: 4,
      burnerPosition: 3,
      code: BurnerActionCode.flameAdjustment,
      outcome: BurnerResolutionOutcome.returnedToService,
      microampReading: 2.8,
      performedBy: 'I&A One',
      performedAt: closedAt,
    );
    final reopened = _ticket(
        id: 'reopened-1',
        furnaceNumber: 4,
        startedAt: DateTime.utc(2026, 8, 14, 8),
        lockout: BurnerLockoutCase(
          positions: const [3],
          commonMode: false,
          cycleStage: BurnerCycleStage.firing,
          flameObservation: BurnerObservation.notSeen,
          sparkObservation: BurnerObservation.seen,
          relightAttempts: 1,
          remainsLockedOut: true,
        ),
      )
      ..resolutionHistory = [
        ResolutionHistory(
          resolvedAt: closedAt,
          actionsJson: ComponentAction.encode([historicalAction]),
        ),
      ];

    final report = buildBurnerReliabilityReport([reopened]);

    expect(report.openPositionCount, 1);
    expect(report.rows.single.openCount, 1);
    expect(report.rows.single.returnedCount, 1);
    expect(report.rows.single.latestMicroampReading, 2.8);
    expect(report.rows.single.latestMicroampAt, closedAt);
    expect(
      report.rows.single.actionCounts[BurnerActionCode.flameAdjustment],
      1,
    );
  });

  test('open position metric de-duplicates concurrent reports', () {
    final first = _ticket(
      id: 'open-1',
      furnaceNumber: 5,
      startedAt: DateTime.utc(2026, 8, 14, 8),
      lockout: BurnerLockoutCase(
        positions: const [2],
        commonMode: false,
        cycleStage: BurnerCycleStage.firing,
        flameObservation: BurnerObservation.notSeen,
        sparkObservation: BurnerObservation.notChecked,
        relightAttempts: 0,
        remainsLockedOut: true,
      ),
    );
    final second = _ticket(
      id: 'open-2',
      furnaceNumber: 5,
      startedAt: DateTime.utc(2026, 8, 14, 9),
      lockout: BurnerLockoutCase(
        positions: const [2],
        commonMode: false,
        cycleStage: BurnerCycleStage.firing,
        flameObservation: BurnerObservation.notSeen,
        sparkObservation: BurnerObservation.notChecked,
        relightAttempts: 0,
        remainsLockedOut: true,
      ),
    );

    final report = buildBurnerReliabilityReport([first, second]);

    expect(report.openPositionCount, 1);
    expect(report.rows.single.openCount, 2);
  });

  test(
    'condition rounds add coverage, red-hot and latest reading evidence',
    () {
      final earlierTicket = _ticket(
        id: 'closed-1',
        furnaceNumber: 2,
        startedAt: DateTime.utc(2026, 8, 14),
        lockout: BurnerLockoutCase(
          positions: const [1],
          commonMode: false,
          cycleStage: BurnerCycleStage.firing,
          flameObservation: BurnerObservation.notSeen,
          sparkObservation: BurnerObservation.seen,
          relightAttempts: 1,
          remainsLockedOut: true,
        ),
      );
      final round = _round(
        furnaceNumber: 2,
        observedAt: DateTime.utc(2026, 8, 16, 10),
      );

      final report = buildBurnerReliabilityReport([earlierTicket], [round]);

      expect(report.roundCount, 1);
      expect(report.rows, hasLength(8));
      expect(report.readingCount, 1);
      expect(report.redHotObservationCount, 1);
      final burnerOne = report.rows.firstWhere(
        (row) => row.burnerPosition == 1,
      );
      expect(burnerOne.issueCount, 1);
      expect(burnerOne.roundCount, 1);
      expect(burnerOne.latestMicroampReading, 4.1);
      expect(
        burnerOne.latestFlameObservation,
        BurnerRoundFlameObservation.seen,
      );
    },
  );
}

BurnerConditionRound _round({
  required int furnaceNumber,
  required DateTime observedAt,
}) => BurnerConditionRound(
  roundId: 'round-1',
  assetClassId: 'furnace-class',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetInstanceId: 'furnace-$furnaceNumber',
  assetInstanceVersion: 1,
  assetNumber: furnaceNumber,
  assetName: 'Furnace $furnaceNumber',
  observations: List<BurnerConditionObservation>.generate(
    8,
    (index) => BurnerConditionObservation(
      position: index + 1,
      flameObservation: BurnerRoundFlameObservation.seen,
      redHotObserved: index == 2,
      microampReading: index == 0 ? 4.1 : null,
    ),
  ),
  redHotPositions: const [3],
  microampPositions: const [1],
  observedAt: observedAt,
  recordedByUid: 'ops-1',
  recordedByName: 'Operations One',
  fingerprint: 'burnerround1-sha256:${'a' * 64}',
  directiveId: 'burner_round_red_hot_round-1',
);

MaintenanceRecord _ticket({
  required String id,
  required int furnaceNumber,
  required DateTime startedAt,
  required BurnerLockoutCase lockout,
  List<ComponentAction> actions = const [],
  bool resolved = false,
}) {
  final record =
      MaintenanceRecord()
        ..firestoreId = id
        ..assetType = AssetType.furnace
        ..assetNumber = furnaceNumber
        ..maintenanceType = MaintenanceType.breakdown
        ..classification = burnerLockoutClassification
        ..description = 'Structured furnace burner lockout evidence.'
        ..routedTo = RoutedTo.instrumentation
        ..status = resolved ? TicketStatus.resolved : TicketStatus.open
        ..isResolved = resolved
        ..component = 'Burner system'
        ..subsystem = 'Burner system'
        ..startDate = startedAt
        ..endDate = resolved ? startedAt.add(const Duration(hours: 2)) : null
        ..createdAt = startedAt
        ..updatedAt = startedAt.add(const Duration(hours: 2))
        ..resolutionHistoryJson = '[]'
        ..burnerLockoutCase = lockout
        ..actions = actions;
  return record;
}
