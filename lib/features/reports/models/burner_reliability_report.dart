import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/domain/burner_lockout_case.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import '../../assets/data/burner_condition_round.dart';

class BurnerReliabilityReport {
  const BurnerReliabilityReport({
    required this.issueCount,
    required this.roundCount,
    required this.rows,
    required this.actionColumns,
  });

  final int issueCount;
  final int roundCount;
  final List<BurnerReliabilityRow> rows;
  final List<BurnerActionCode> actionColumns;

  int get openPositionCount => rows.where((row) => row.openCount > 0).length;
  int get redHotObservationCount =>
      rows.fold(0, (sum, row) => sum + row.redHotCount);
  int get readingCount =>
      rows.where((row) => row.latestMicroampReading != null).length;
  int get furnaceCount => rows.map((row) => row.furnaceNumber).toSet().length;
}

class BurnerReliabilityRow {
  const BurnerReliabilityRow({
    required this.furnaceNumber,
    required this.burnerPosition,
    required this.latest,
    required this.issueCount,
    required this.roundCount,
    required this.openCount,
    required this.redHotCount,
    required this.returnedCount,
    required this.followUpCount,
    required this.latestMicroampReading,
    required this.latestMicroampAt,
    required this.latestRoundAt,
    required this.latestFlameObservation,
    required this.actionCounts,
  });

  final int furnaceNumber;
  final int burnerPosition;
  final DateTime latest;
  final int issueCount;
  final int roundCount;
  final int openCount;
  final int redHotCount;
  final int returnedCount;
  final int followUpCount;
  final double? latestMicroampReading;
  final DateTime? latestMicroampAt;
  final DateTime? latestRoundAt;
  final BurnerRoundFlameObservation? latestFlameObservation;
  final Map<BurnerActionCode, int> actionCounts;

  String get displayTag => burnerTag(furnaceNumber, burnerPosition);
}

BurnerReliabilityReport buildBurnerReliabilityReport(
  List<MaintenanceRecord> tickets, [
  List<BurnerConditionRound> rounds = const <BurnerConditionRound>[],
]) {
  final rows = <String, _MutableBurnerReliabilityRow>{};
  final actionTotals = <BurnerActionCode, int>{};
  var issueCount = 0;
  for (final ticket in tickets) {
    if (ticket.classification != burnerLockoutClassification) continue;
    final read = ticket.burnerLockoutReadResult;
    if (!read.isValid || read.value == null) {
      throw StateError(
        'Burner reliability source ${ticket.firestoreId ?? ticket.id} has '
        'malformed lockout evidence.',
      );
    }
    final lockout = read.value!;
    issueCount++;
    for (final position in lockout.positions) {
      final key = '${ticket.assetNumber}:$position';
      final row = rows.putIfAbsent(
        key,
        () => _MutableBurnerReliabilityRow(
          furnaceNumber: ticket.assetNumber,
          burnerPosition: position,
          latest: ticket.startDate,
        ),
      );
      row.issueCount++;
      if (!ticket.isResolved) row.openCount++;
      if (lockout.redHotPositions.contains(position)) row.redHotCount++;
      if (ticket.startDate.isAfter(row.latest)) row.latest = ticket.startDate;
    }
    final historyRead = ticket.resolutionHistoryReadResult;
    if (!historyRead.isValid) {
      throw StateError(
        'Burner reliability source ${ticket.firestoreId ?? ticket.id} has '
        'malformed resolution history.',
      );
    }
    for (var index = 0; index < historyRead.entries.length; index++) {
      final history = historyRead.entries[index];
      final historyActions = ComponentAction.decode(
        history.actionsJson,
        source:
            'burner reliability ${ticket.firestoreId ?? ticket.id} '
            'resolutionHistory[$index]',
      );
      final resolution = burnerResolutionFromActions(
        lockout: lockout,
        actions: historyActions,
      );
      _applyClosureEvidence(
        ticket: ticket,
        rows: rows,
        actionTotals: actionTotals,
        resolution: resolution,
        actions: historyActions,
        observedAt: history.resolvedAt!,
      );
    }
    final actionRead = ticket.actionsReadResult;
    if (!actionRead.isValid) {
      throw StateError(
        'Burner reliability source ${ticket.firestoreId ?? ticket.id} has '
        'malformed action evidence.',
      );
    }
    final hasCurrentClosure =
        lockout.resolutionOutcomes.isNotEmpty ||
        actionRead.entries.any(_hasBurnerActionEvidence);
    if (hasCurrentClosure) {
      try {
        validatePersistedBurnerResolutionEvidence(
          lockout: lockout,
          actions: actionRead.entries,
        );
      } on FormatException catch (error) {
        throw StateError(error.message);
      }
      _applyClosureEvidence(
        ticket: ticket,
        rows: rows,
        actionTotals: actionTotals,
        resolution: BurnerLockoutResolution(
          outcomes: lockout.resolutionOutcomes,
          microampReadings: lockout.resolutionMicroampReadings,
        ),
        actions: actionRead.entries,
        observedAt: ticket.endDate ?? ticket.updatedAt,
      );
    }
  }
  for (final round in rounds) {
    for (final observation in round.observations) {
      final key = '${round.assetNumber}:${observation.position}';
      final row = rows.putIfAbsent(
        key,
        () => _MutableBurnerReliabilityRow(
          furnaceNumber: round.assetNumber,
          burnerPosition: observation.position,
          latest: round.observedAt,
        ),
      );
      row.roundCount++;
      if (observation.redHotObserved) row.redHotCount++;
      if (round.observedAt.isAfter(row.latest)) row.latest = round.observedAt;
      if (row.latestRoundAt == null ||
          !round.observedAt.isBefore(row.latestRoundAt!)) {
        row.latestRoundAt = round.observedAt;
        row.latestFlameObservation = observation.flameObservation;
      }
      final reading = observation.microampReading;
      if (reading != null &&
          (row.latestMicroampAt == null ||
              round.observedAt.isAfter(row.latestMicroampAt!))) {
        row.latestMicroampReading = reading;
        row.latestMicroampAt = round.observedAt;
      }
    }
  }
  final sortedRows =
      rows.values.toList()..sort((left, right) {
        final furnace = left.furnaceNumber.compareTo(right.furnaceNumber);
        return furnace != 0
            ? furnace
            : left.burnerPosition.compareTo(right.burnerPosition);
      });
  final actionColumns =
      actionTotals.entries.toList()..sort((left, right) {
        final count = right.value.compareTo(left.value);
        return count != 0 ? count : left.key.name.compareTo(right.key.name);
      });
  return BurnerReliabilityReport(
    issueCount: issueCount,
    roundCount: rounds.length,
    rows: List<BurnerReliabilityRow>.unmodifiable(
      sortedRows.map((row) => row.freeze()),
    ),
    actionColumns: List<BurnerActionCode>.unmodifiable(
      actionColumns.take(5).map((entry) => entry.key),
    ),
  );
}

void _applyClosureEvidence({
  required MaintenanceRecord ticket,
  required Map<String, _MutableBurnerReliabilityRow> rows,
  required Map<BurnerActionCode, int> actionTotals,
  required BurnerLockoutResolution resolution,
  required Iterable<ComponentAction> actions,
  required DateTime observedAt,
}) {
  for (final entry in resolution.outcomes.entries) {
    final row = rows['${ticket.assetNumber}:${entry.key}'];
    if (row == null) {
      throw StateError(
        'Burner closure evidence references an unknown position.',
      );
    }
    if (entry.value == BurnerResolutionOutcome.returnedToService) {
      row.returnedCount++;
    } else if (entry.value == BurnerResolutionOutcome.remainsLockedOut ||
        entry.value == BurnerResolutionOutcome.isolatedForFollowUp) {
      row.followUpCount++;
    }
    final reading = resolution.microampReadings[entry.key];
    if (reading != null &&
        (row.latestMicroampAt == null ||
            observedAt.isAfter(row.latestMicroampAt!))) {
      row.latestMicroampReading = reading;
      row.latestMicroampAt = observedAt;
    }
  }
  for (final action in actions) {
    if (!_hasBurnerActionEvidence(action)) continue;
    final position = action.burnerPosition;
    final codeName = action.burnerActionCode;
    final code = BurnerActionCode.values.firstWhere(
      (value) => value.name == codeName,
    );
    final row = rows['${ticket.assetNumber}:$position'];
    if (row == null) {
      throw StateError(
        'Burner action evidence references an unknown position.',
      );
    }
    row.actionCounts.update(code, (count) => count + 1, ifAbsent: () => 1);
    actionTotals.update(code, (count) => count + 1, ifAbsent: () => 1);
  }
}

bool _hasBurnerActionEvidence(ComponentAction action) =>
    action.burnerPosition != null ||
    action.burnerActionCode != null ||
    action.burnerOutcome != null ||
    action.burnerMicroampReading != null;

class _MutableBurnerReliabilityRow {
  _MutableBurnerReliabilityRow({
    required this.furnaceNumber,
    required this.burnerPosition,
    required this.latest,
  });

  final int furnaceNumber;
  final int burnerPosition;
  DateTime latest;
  int issueCount = 0;
  int roundCount = 0;
  int openCount = 0;
  int redHotCount = 0;
  int returnedCount = 0;
  int followUpCount = 0;
  double? latestMicroampReading;
  DateTime? latestMicroampAt;
  DateTime? latestRoundAt;
  BurnerRoundFlameObservation? latestFlameObservation;
  final Map<BurnerActionCode, int> actionCounts = <BurnerActionCode, int>{};

  BurnerReliabilityRow freeze() => BurnerReliabilityRow(
    furnaceNumber: furnaceNumber,
    burnerPosition: burnerPosition,
    latest: latest,
    issueCount: issueCount,
    roundCount: roundCount,
    openCount: openCount,
    redHotCount: redHotCount,
    returnedCount: returnedCount,
    followUpCount: followUpCount,
    latestMicroampReading: latestMicroampReading,
    latestMicroampAt: latestMicroampAt,
    latestRoundAt: latestRoundAt,
    latestFlameObservation: latestFlameObservation,
    actionCounts: Map<BurnerActionCode, int>.unmodifiable(actionCounts),
  );
}
