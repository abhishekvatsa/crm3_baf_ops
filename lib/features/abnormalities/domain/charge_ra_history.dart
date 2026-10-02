import '../../../core/validation/charge_number.dart';
import '../data/abnormality_model.dart';

/// One recorded charge-to-charge RA link, not a count of abnormality rows.
/// Several findings can describe the same RA. Performance dates, when present,
/// remain on their original records; neither a date nor a physical coil identity
/// is inferred from the charge numbers.
class ChargeRaTransition {
  ChargeRaTransition({
    required this.sourceChargeNo,
    required this.targetChargeNo,
    required Iterable<ChargeAbnormality> records,
  }) : records = List.unmodifiable(records);

  final int sourceChargeNo;
  final int targetChargeNo;
  final List<ChargeAbnormality> records;
}

class ChargeRaHistory {
  ChargeRaHistory._({
    required Iterable<int> chargeNumbers,
    required List<int>? orderedChargeNumbers,
    required Iterable<ChargeRaTransition> transitions,
    required Iterable<ChargeAbnormality> records,
    required Iterable<String> warnings,
  }) : chargeNumbers = List.unmodifiable(chargeNumbers),
       orderedChargeNumbers = orderedChargeNumbers == null
           ? null
           : List.unmodifiable(orderedChargeNumbers),
       transitions = List.unmodifiable(transitions),
       records = List.unmodifiable(records),
       warnings = List.unmodifiable(warnings);

  /// Members connected by recorded links, sorted for a stable display.
  final List<int> chargeNumbers;

  /// Present only for a single consistent chain. Never a date reconstruction.
  final List<int>? orderedChargeNumbers;
  final List<ChargeRaTransition> transitions;
  final List<ChargeAbnormality> records;
  final List<String> warnings;

  /// Repeated recorded RA links in one unambiguous chain; not verified coil
  /// movement, physical performance, or complete historical coverage.
  bool get hasRepeatedRa =>
      orderedChargeNumbers != null && transitions.length > 1;
}

/// Read-only history from the report's full authorized snapshot. Build this
/// before filtering/paging, so an earlier RA is not lost when only pending
/// findings are visible. Missing rows remain missing evidence, never proof that
/// there was no earlier RA. No Base, reason, timestamp or adjacent-number match
/// creates a relationship.
class ChargeRaHistoryIndex {
  ChargeRaHistoryIndex(Iterable<ChargeAbnormality> records) {
    final byIdentity = <Object, List<ChargeAbnormality>>{};
    final seenObjects = Set<ChargeAbnormality>.identity();
    for (final record in records) {
      if (!seenObjects.add(record)) continue;
      final remoteId = record.firestoreId;
      // Unsaved rows have no shared identity. Equal-looking drafts must not be
      // silently merged; duplicate links are grouped separately below.
      final Object identity = remoteId != null && remoteId.isNotEmpty
          ? ('remote', remoteId)
          : record.id > 0
          ? ('local', record.id)
          : record;
      byIdentity.putIfAbsent(identity, () => []).add(record);
    }
    for (final copies in byIdentity.values) {
      // Do not resurrect an active snapshot when its same identity is deleted.
      if (copies.any((record) => record.isDeleted)) continue;
      final first = copies.first;
      final conflicting = copies.any(
        (record) =>
            record.sourceChargeNo != first.sourceChargeNo ||
            record.reannealedToChargeNo != first.reannealedToChargeNo ||
            record.reannealingStatus != first.reannealingStatus,
      );
      if (conflicting) {
        for (final record in copies) {
          _records.add(record);
          _warn(
            record,
            'Conflicting copies of one finding need reconciliation.',
          );
        }
        continue;
      }
      _records.add(first);
      _addLink(first);
    }
  }

  final _records = <ChargeAbnormality>[];
  final _links = <(int, int), List<ChargeAbnormality>>{};
  final _neighbors = <int, Set<int>>{};
  final _warnings = <int, Set<String>>{};
  final _cache = <int, ChargeRaHistory>{};

  void _warn(ChargeAbnormality record, String warning) {
    for (final charge in [record.sourceChargeNo, record.reannealedToChargeNo]) {
      if (charge != null && isValidChargeNumber(charge)) {
        _warnings.putIfAbsent(charge, () => {}).add(warning);
      }
    }
  }

  void _addLink(ChargeAbnormality record) {
    final source = record.sourceChargeNo;
    final target = record.reannealedToChargeNo;
    if (!isValidChargeNumber(source) ||
        (target != null && !isValidChargeNumber(target))) {
      _warn(
        record,
        'A finding has an invalid charge number; its link is unverified.',
      );
      return;
    }
    if (record.reannealingStatus != ReannealingStatus.completed) {
      if (target != null) {
        _warn(
          record,
          'Charge $source has a destination without completed RA status.',
        );
      }
      return;
    }
    if (target == null) {
      _warn(
        record,
        'Charge $source has completed RA without a recorded new charge.',
      );
      return;
    }
    if (target == source) {
      _warn(
        record,
        'Charge $source links to itself; its RA sequence is unverified.',
      );
      return;
    }
    if (target < source) {
      _warn(
        record,
        'Recorded link $source → $target runs against charge-number order; reconcile the sequence.',
      );
    }
    _links.putIfAbsent((source, target), () => []).add(record);
    _neighbors.putIfAbsent(source, () => {}).add(target);
    _neighbors.putIfAbsent(target, () => {}).add(source);
  }

  ChargeRaHistory forRecord(ChargeAbnormality record) {
    if (isValidChargeNumber(record.sourceChargeNo)) {
      return forCharge(record.sourceChargeNo);
    }
    return ChargeRaHistory._(
      chargeNumbers: const [],
      orderedChargeNumbers: null,
      transitions: const [],
      records: record.isDeleted ? const [] : [record],
      warnings: const [
        'This finding has an invalid source charge; its history is unverified.',
      ],
    );
  }

  ChargeRaHistory forCharge(int chargeNumber) {
    final cached = _cache[chargeNumber];
    if (cached != null) return cached;
    if (!isValidChargeNumber(chargeNumber)) {
      return ChargeRaHistory._(
        chargeNumbers: const [],
        orderedChargeNumbers: null,
        transitions: const [],
        records: const [],
        warnings: const ['A five-digit charge number is required.'],
      );
    }
    final members = <int>{chargeNumber};
    final pending = <int>[chargeNumber];
    while (pending.isNotEmpty) {
      for (final next in _neighbors[pending.removeLast()] ?? const <int>{}) {
        if (members.add(next)) pending.add(next);
      }
    }
    final charges = members.toList()..sort();
    final transitions =
        [
          for (final entry in _links.entries)
            if (members.contains(entry.key.$1))
              ChargeRaTransition(
                sourceChargeNo: entry.key.$1,
                targetChargeNo: entry.key.$2,
                records: entry.value,
              ),
        ]..sort((a, b) {
          final source = a.sourceChargeNo.compareTo(b.sourceChargeNo);
          return source != 0
              ? source
              : a.targetChargeNo.compareTo(b.targetChargeNo);
        });
    final warnings = <String>{
      for (final charge in charges) ...?_warnings[charge],
    };
    final incoming = <int, Set<int>>{};
    final outgoing = <int, Set<int>>{};
    for (final link in transitions) {
      incoming
          .putIfAbsent(link.targetChargeNo, () => {})
          .add(link.sourceChargeNo);
      outgoing
          .putIfAbsent(link.sourceChargeNo, () => {})
          .add(link.targetChargeNo);
    }
    for (final charge in charges) {
      if ((outgoing[charge]?.length ?? 0) > 1) {
        warnings.add(
          'Charge $charge links to multiple new charges; no single RA sequence is assumed.',
        );
      }
      if ((incoming[charge]?.length ?? 0) > 1) {
        warnings.add(
          'Charge $charge has multiple previous charges; no single RA sequence is assumed.',
        );
      }
    }
    // Kahn traversal detects cycles without recursive calls or date heuristics.
    final remaining = {
      for (final charge in charges) charge: incoming[charge]?.length ?? 0,
    };
    final ready = [
      for (final charge in charges)
        if (remaining[charge] == 0) charge,
    ];
    var visited = 0;
    while (ready.isNotEmpty) {
      final current = ready.removeLast();
      visited++;
      for (final next in outgoing[current] ?? const <int>{}) {
        remaining[next] = remaining[next]! - 1;
        if (remaining[next] == 0) ready.add(next);
      }
    }
    if (visited != charges.length) {
      warnings.add(
        'Recorded links contain a cycle; the RA sequence needs reconciliation.',
      );
    }
    List<int>? ordered;
    if (warnings.isEmpty) {
      ordered = <int>[];
      var current = charges.firstWhere(
        (charge) => !incoming.containsKey(charge),
      );
      while (true) {
        ordered.add(current);
        final next = outgoing[current];
        if (next == null || next.isEmpty) break;
        current = next.single;
      }
    }
    // Charge-stage order remains useful when older rows were entered later and
    // RA dates are absent. A reverse-number link is retained and warned above,
    // not silently changed to fit the plant's lower-number-is-older convention.
    final historyRecords = [
      for (final charge in ordered ?? charges)
        for (final record in _records)
          if (record.sourceChargeNo == charge) record,
    ];
    final history = ChargeRaHistory._(
      chargeNumbers: charges,
      orderedChargeNumbers: ordered,
      transitions: transitions,
      records: historyRecords,
      warnings: warnings,
    );
    for (final charge in charges) {
      _cache[charge] = history;
    }
    return history;
  }
}
