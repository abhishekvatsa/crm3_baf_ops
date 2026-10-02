import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/domain/charge_ra_history.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('three recorded RA links expose the connected four-charge history', () {
    final first = _record('first', 50100, target: 50200);
    final second = _record('second', 50200, target: 50300);
    final third = _record('third', 50300, target: 50400);
    final pending = _record(
      'pending',
      50400,
      status: ReannealingStatus.required,
    );
    final index = ChargeRaHistoryIndex([third, pending, first, second]);
    final history = index.forRecord(second);

    expect(history.orderedChargeNumbers, [50100, 50200, 50300, 50400]);
    expect(history.transitions, hasLength(3));
    expect(history.hasRepeatedRa, isTrue);
    expect(history.records, [first, second, third, pending]);
    expect(history.warnings, isEmpty);
    expect(identical(index.forCharge(50100), index.forCharge(50400)), isTrue);
  });

  test(
    'missing RA dates stay unknown; logged date cannot reorder charge stages',
    () {
      final first = _record('late-entry', 50100, target: 50200)
        ..loggedAt = DateTime.utc(2026, 9, 30);
      final second = _record('early-entry', 50200, target: 50300)
        ..loggedAt = DateTime.utc(2026, 9, 20);
      final history = ChargeRaHistoryIndex([second, first]).forCharge(50200);

      expect(history.orderedChargeNumbers, [50100, 50200, 50300]);
      expect(history.records, [first, second]);
      expect(first.raPerformedAt, isNull);
      expect(second.raPerformedAt, isNull);
      expect(first.loggedAt, DateTime.utc(2026, 9, 30));
    },
  );

  test(
    'reverse-number edge is retained as evidence, never silently reversed',
    () {
      final record = _record('reverse', 50300, target: 50200);
      final history = ChargeRaHistoryIndex([record]).forCharge(50200);

      expect(history.chargeNumbers, [50200, 50300]);
      expect(history.orderedChargeNumbers, isNull);
      expect(history.transitions.single.sourceChargeNo, 50300);
      expect(history.transitions.single.targetChargeNo, 50200);
      expect(history.warnings.single, contains('against charge-number order'));
      expect(history.hasRepeatedRa, isFalse);
    },
  );

  test('two findings on one RA pair are one link, not repeated RA', () {
    final colour = _record('colour', 50100, target: 50200);
    final process = _record('process', 50100, target: 50200)
      ..category = AbnormalityCategory.process;
    final history = ChargeRaHistoryIndex([colour, process]).forCharge(50200);

    expect(history.transitions, hasLength(1));
    expect(history.transitions.single.records, [colour, process]);
    expect(history.records, [colour, process]);
    expect(history.hasRepeatedRa, isFalse);
  });

  test(
    'duplicate snapshots and repeated object references do not inflate history',
    () {
      final first = _record('same', 50100, target: 50200);
      final duplicate = _record('same', 50100, target: 50200);
      final history = ChargeRaHistoryIndex([
        first,
        duplicate,
        first,
      ]).forCharge(50100);

      expect(history.records, [first]);
      expect(history.transitions.single.records, [first]);
    },
  );

  test(
    'distinct unsaved drafts are not merged by their default local identity',
    () {
      final first = _record(null, 50100, target: 50200);
      final second = _record(null, 50200, target: 50300);
      final history = ChargeRaHistoryIndex([first, second]).forCharge(50100);

      expect(history.orderedChargeNumbers, [50100, 50200, 50300]);
      expect(history.records, [first, second]);
    },
  );

  test(
    'positive local identity deduplicates snapshots without a remote ID',
    () {
      final first = _record(null, 50100, target: 50200)..id = 41;
      final copy = _record(null, 50100, target: 50200)..id = 41;
      expect(ChargeRaHistoryIndex([first, copy]).forCharge(50100).records, [
        first,
      ]);
    },
  );

  test(
    'conflicting copies of one record do not fabricate either connection',
    () {
      final first = _record('same', 50100, target: 50200);
      final conflicting = _record('same', 50100, target: 50300);
      final index = ChargeRaHistoryIndex([first, conflicting]);
      final history = index.forCharge(50100);

      expect(history.transitions, isEmpty);
      expect(history.records, [first, conflicting]);
      expect(history.orderedChargeNumbers, isNull);
      expect(history.warnings.single, contains('Conflicting copies'));
      expect(index.forCharge(50200).chargeNumbers, [50200]);
      expect(index.forCharge(50300).chargeNumbers, [50300]);
    },
  );

  test('branching charge is surfaced without choosing one destination', () {
    final history = ChargeRaHistoryIndex([
      _record('a', 50100, target: 50200),
      _record('b', 50100, target: 50300),
    ]).forCharge(50100);

    expect(history.orderedChargeNumbers, isNull);
    expect(history.transitions, hasLength(2));
    expect(history.warnings.single, contains('multiple new charges'));
    expect(history.hasRepeatedRa, isFalse);
  });

  test('merging charge is surfaced without inventing a single origin', () {
    final history = ChargeRaHistoryIndex([
      _record('a', 50100, target: 50300),
      _record('b', 50200, target: 50300),
    ]).forCharge(50300);

    expect(history.orderedChargeNumbers, isNull);
    expect(history.transitions, hasLength(2));
    expect(history.warnings.single, contains('multiple previous charges'));
  });

  test(
    'cycle terminates and remains unresolved even with a lower numbered root',
    () {
      final history = ChargeRaHistoryIndex([
        _record('a', 50100, target: 50200),
        _record('b', 50200, target: 50300),
        _record('c', 50300, target: 50200),
      ]).forCharge(50100);

      expect(history.chargeNumbers, [50100, 50200, 50300]);
      expect(history.orderedChargeNumbers, isNull);
      expect(
        history.warnings.any((warning) => warning.contains('cycle')),
        isTrue,
      );
    },
  );

  test('self-link is unverified and not counted as RA', () {
    final history = ChargeRaHistoryIndex([
      _record('self', 50100, target: 50100),
    ]).forCharge(50100);

    expect(history.transitions, isEmpty);
    expect(history.orderedChargeNumbers, isNull);
    expect(history.warnings.single, contains('links to itself'));
  });

  test(
    'deleted bridge never connects two otherwise separate charge histories',
    () {
      final deleted = _record('deleted', 50200, target: 50300)
        ..isDeleted = true;
      final index = ChargeRaHistoryIndex([
        _record('first', 50100, target: 50200),
        deleted,
        _record('last', 50300, target: 50400),
      ]);

      expect(index.forCharge(50100).chargeNumbers, [50100, 50200]);
      expect(index.forCharge(50400).chargeNumbers, [50300, 50400]);
      expect(index.forCharge(50200).records, isNot(contains(deleted)));
    },
  );

  test(
    'deleted copy suppresses same-identity active snapshot instead of resurrection',
    () {
      final active = _record('same', 50100, target: 50200);
      final deleted = _record('same', 50100, target: 50200)..isDeleted = true;
      final history = ChargeRaHistoryIndex([active, deleted]).forCharge(50100);

      expect(history.records, isEmpty);
      expect(history.transitions, isEmpty);
      expect(history.chargeNumbers, [50100]);
    },
  );

  test(
    'same Base, reason, timestamp and adjacent charge numbers do not imply a link',
    () {
      final first = _record('first', 50100, target: 50200);
      final unrelated = _record('unrelated', 50201, target: 50300);
      final index = ChargeRaHistoryIndex([first, unrelated]);

      expect(index.forCharge(50100).chargeNumbers, [50100, 50200]);
      expect(index.forCharge(50201).records, [unrelated]);
      expect(index.forCharge(50100).hasRepeatedRa, isFalse);
    },
  );

  test(
    'all findings on established member charges remain visible regardless of category',
    () {
      final completed = _record('completed', 50100, target: 50200);
      final required = _record(
        'required',
        50200,
        status: ReannealingStatus.required,
      );
      final pending = _record(
        'pending',
        50200,
        status: ReannealingStatus.pendingDecision,
      );
      final notRa = _record(
        'equipment',
        50200,
        status: ReannealingStatus.notRequired,
      )..category = AbnormalityCategory.equipment;
      final history = ChargeRaHistoryIndex([
        notRa,
        pending,
        completed,
        required,
      ]).forCharge(50100);

      expect(
        history.records,
        containsAll([completed, required, pending, notRa]),
      );
      expect(history.transitions, hasLength(1));
      expect(history.warnings, isEmpty);
    },
  );

  test(
    'completed record missing new charge warns without a guessed destination',
    () {
      final history = ChargeRaHistoryIndex([
        _record('missing', 50100, status: ReannealingStatus.completed),
        _record('nearby', 50101, status: ReannealingStatus.required),
      ]).forCharge(50100);

      expect(history.chargeNumbers, [50100]);
      expect(history.transitions, isEmpty);
      expect(
        history.warnings.single,
        contains('without a recorded new charge'),
      );
    },
  );

  test(
    'noncompleted destination is not promoted to completed by this read model',
    () {
      final invalid = _record(
        'invalid',
        50100,
        target: 50200,
        status: ReannealingStatus.required,
      );
      final history = ChargeRaHistoryIndex([invalid]).forCharge(50100);

      expect(history.transitions, isEmpty);
      expect(history.warnings.single, contains('without completed RA status'));
      expect(invalid.reannealingStatus, ReannealingStatus.required);
      expect(invalid.reannealedToChargeNo, 50200);
    },
  );

  test(
    'invalid charge widths cannot create links or be normalized into valid charges',
    () {
      final invalidSource = _record('short', 5100, target: 50200);
      final invalidTarget = _record('long', 50100, target: 100200);
      final index = ChargeRaHistoryIndex([invalidSource, invalidTarget]);

      expect(index.forRecord(invalidSource).transitions, isEmpty);
      expect(
        index.forRecord(invalidSource).warnings.single,
        contains('invalid source charge'),
      );
      expect(index.forCharge(50100).transitions, isEmpty);
      expect(
        index.forCharge(50100).warnings.single,
        contains('invalid charge number'),
      );
      expect(index.forCharge(5100).chargeNumbers, isEmpty);
      expect(invalidSource.sourceChargeNo, 5100);
    },
  );

  test('empty history is not a fabricated earlier charge or RA', () {
    final history = ChargeRaHistoryIndex(const []).forCharge(50100);
    expect(history.chargeNumbers, [50100]);
    expect(history.orderedChargeNumbers, [50100]);
    expect(history.records, isEmpty);
    expect(history.transitions, isEmpty);
    expect(history.hasRepeatedRa, isFalse);
  });

  test(
    'recorded performance evidence is preserved without filling missing dates',
    () {
      final performed = DateTime.utc(2026, 9, 29, 8);
      final first = _record('dated', 50100, target: 50200)
        ..assessment = AbnormalityAssessment(
          observationKind: AbnormalityObservationKind.resultFinding,
          raPerformedAt: performed,
        );
      final second = _record('undated', 50200, target: 50300);
      final evidenceBefore = first.affectedAssetsJson;
      final secondEvidenceBefore = second.affectedAssetsJson;
      final history = ChargeRaHistoryIndex([second, first]).forCharge(50300);

      expect(history.records.first.raPerformedAt, performed);
      expect(history.records.last.raPerformedAt, isNull);
      expect(first.affectedAssetsJson, evidenceBefore);
      expect(second.affectedAssetsJson, secondEvidenceBefore);
    },
  );

  test(
    'returned collections cannot be structurally modified by report consumers',
    () {
      final history = ChargeRaHistoryIndex([
        _record('one', 50100, target: 50200),
      ]).forCharge(50100);

      expect(() => history.chargeNumbers.add(50300), throwsUnsupportedError);
      expect(
        () => history.orderedChargeNumbers!.clear(),
        throwsUnsupportedError,
      );
      expect(() => history.records.clear(), throwsUnsupportedError);
      expect(() => history.transitions.clear(), throwsUnsupportedError);
      expect(
        () => history.transitions.single.records.clear(),
        throwsUnsupportedError,
      );
      expect(() => history.warnings.clear(), throwsUnsupportedError);
    },
  );
}

ChargeAbnormality _record(
  String? id,
  int source, {
  int? target,
  ReannealingStatus? status,
}) => ChargeAbnormality()
  ..firestoreId = id
  ..sourceChargeNo = source
  ..reannealedToChargeNo = target
  ..reannealingStatus = status ?? ReannealingStatus.completed
  ..abnormalityTypeId = 'type'
  ..abnormalityTypeCode = 'RA_COIL_COLOUR'
  ..abnormalityTypeTitle = 'Colour finding'
  ..category = AbnormalityCategory.resultQuality
  ..severity = AbnormalitySeverity.high
  ..observedReason = 'Synthetic repeated finding'
  ..affectedAssets = [
    const AffectedAssetRef(assetType: AssetType.base, assetNumber: 220),
  ]
  ..loggedAt = DateTime.utc(2026, 9, 30, 10)
  ..updatedAt = DateTime.utc(2026, 9, 30, 10);
