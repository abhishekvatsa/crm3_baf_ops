import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/domain/burner_lockout_case.dart';

class BurnerReliabilityReport {
  const BurnerReliabilityReport({
    required this.issueCount,
    required this.rows,
    required this.actionColumns,
  });

  final int issueCount;
  final List<BurnerReliabilityRow> rows;
  final List<BurnerActionCode> actionColumns;

  int get openReportCount => rows.fold(0, (sum, row) => sum + row.openCount);
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
    required this.openCount,
    required this.redHotCount,
    required this.returnedCount,
    required this.followUpCount,
    required this.latestMicroampReading,
    required this.latestMicroampAt,
    required this.actionCounts,
  });

  final int furnaceNumber;
  final int burnerPosition;
  final DateTime latest;
  final int issueCount;
  final int openCount;
  final int redHotCount;
  final int returnedCount;
  final int followUpCount;
  final double? latestMicroampReading;
  final DateTime? latestMicroampAt;
  final Map<BurnerActionCode, int> actionCounts;

  String get displayTag => burnerTag(furnaceNumber, burnerPosition);
}

BurnerReliabilityReport buildBurnerReliabilityReport(
  List<MaintenanceRecord> tickets,
) {
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
      final outcome = lockout.resolutionOutcomes[position];
      if (outcome == BurnerResolutionOutcome.returnedToService) {
        row.returnedCount++;
      } else if (outcome == BurnerResolutionOutcome.remainsLockedOut ||
          outcome == BurnerResolutionOutcome.isolatedForFollowUp) {
        row.followUpCount++;
      }
      final microampReading = lockout.resolutionMicroampReadings[position];
      final readingAt = ticket.endDate ?? ticket.updatedAt;
      if (microampReading != null &&
          (row.latestMicroampAt == null ||
              readingAt.isAfter(row.latestMicroampAt!))) {
        row.latestMicroampReading = microampReading;
        row.latestMicroampAt = readingAt;
      }
    }
    final actionRead = ticket.actionsReadResult;
    if (!actionRead.isValid) {
      throw StateError(
        'Burner reliability source ${ticket.firestoreId ?? ticket.id} has '
        'malformed action evidence.',
      );
    }
    for (final action in actionRead.entries) {
      final position = action.extensions['burnerPosition'];
      final codeName = action.extensions['burnerActionCode'];
      if (position is! int || codeName is! String) continue;
      final matches = BurnerActionCode.values.where(
        (value) => value.name == codeName,
      );
      if (matches.isEmpty) continue;
      final code = matches.first;
      final row = rows['${ticket.assetNumber}:$position'];
      if (row == null) continue;
      row.actionCounts.update(code, (count) => count + 1, ifAbsent: () => 1);
      actionTotals.update(code, (count) => count + 1, ifAbsent: () => 1);
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
    rows: List<BurnerReliabilityRow>.unmodifiable(
      sortedRows.map((row) => row.freeze()),
    ),
    actionColumns: List<BurnerActionCode>.unmodifiable(
      actionColumns.take(5).map((entry) => entry.key),
    ),
  );
}

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
  int openCount = 0;
  int redHotCount = 0;
  int returnedCount = 0;
  int followUpCount = 0;
  double? latestMicroampReading;
  DateTime? latestMicroampAt;
  final Map<BurnerActionCode, int> actionCounts = <BurnerActionCode, int>{};

  BurnerReliabilityRow freeze() => BurnerReliabilityRow(
    furnaceNumber: furnaceNumber,
    burnerPosition: burnerPosition,
    latest: latest,
    issueCount: issueCount,
    openCount: openCount,
    redHotCount: redHotCount,
    returnedCount: returnedCount,
    followUpCount: followUpCount,
    latestMicroampReading: latestMicroampReading,
    latestMicroampAt: latestMicroampAt,
    actionCounts: Map<BurnerActionCode, int>.unmodifiable(actionCounts),
  );
}
