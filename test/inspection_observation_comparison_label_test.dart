import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/domain/inspection_observation_comparison_label.dart';
import 'package:flutter_test/flutter_test.dart';

FrozenInspectionDefinition _definition({
  InspectionValueType type = InspectionValueType.number,
  double? min,
  double? max,
  List<InspectionReadingField> fields = const [],
}) => FrozenInspectionDefinition(
  schemaVersion: fields.isEmpty ? 1 : 2,
  readingFields: fields,
  id: 'definition',
  version: 1,
  code: 'READING',
  title: 'Reading',
  description: 'Recorded evidence',
  assetTypeKeys: const ['furnace'],
  assetClassIds: const ['furnaces'],
  componentNodeIds: const [],
  valueType: fields.isEmpty ? type : null,
  unit: fields.isEmpty && type == InspectionValueType.number ? 'bar' : null,
  choiceValues: type == InspectionValueType.choice
      ? const ['Present']
      : const [],
  minimumValue: min,
  maximumValue: max,
  preconditions: const [],
  requiresChargeNo: false,
);

void main() {
  const numeric = InspectionReadingField(
    id: 'pressure',
    label: 'Pressure',
    valueType: InspectionValueType.number,
    unit: 'bar',
  );
  const bounded = InspectionReadingField(
    id: 'pressure',
    label: 'Pressure',
    valueType: InspectionValueType.number,
    unit: 'bar',
    maximumValue: 5,
  );
  const boolean = InspectionReadingField(
    id: 'verified',
    label: 'Verified',
    valueType: InspectionValueType.boolean,
  );
  const date = InspectionReadingField(
    id: 'date',
    label: 'Date',
    valueType: InspectionValueType.date,
  );
  for (final (name, definition) in [
    ('legacy minimum', _definition(min: 0)),
    ('legacy maximum', _definition(max: 5)),
    ('legacy two limits', _definition(min: 0, max: 5)),
    ('multiple numeric', _definition(fields: [bounded])),
    ('mixed evidence', _definition(fields: [boolean, bounded, date])),
  ]) {
    test('$name unchanged describes limits rather than identical evidence', () {
      expect(
        inspectionObservationComparisonLabel(
          InspectionComparisonOutcome.unchanged,
          definition,
        ),
        'Limit status unchanged from baseline',
      );
    });
  }
  for (final (name, definition) in [
    ('legacy number', _definition()),
    ('multiple number', _definition(fields: [numeric])),
    (
      'number with qualitative evidence',
      _definition(fields: [numeric, boolean]),
    ),
  ]) {
    test('$name without bounds makes no numeric comparison claim', () {
      expect(
        inspectionObservationComparisonLabel(
          InspectionComparisonOutcome.unchanged,
          definition,
        ),
        'No numeric limits to compare',
      );
    });
  }
  for (final (name, definition) in [
    ('legacy boolean', _definition(type: InspectionValueType.boolean)),
    ('legacy text', _definition(type: InspectionValueType.text)),
    ('legacy choice', _definition(type: InspectionValueType.choice)),
    ('boolean and date', _definition(fields: [boolean, date])),
  ]) {
    test('$name unchanged retains the evidence comparison label', () {
      expect(
        inspectionObservationComparisonLabel(
          InspectionComparisonOutcome.unchanged,
          definition,
        ),
        'Unchanged from baseline',
      );
    });
  }
  for (final (outcome, label) in [
    (InspectionComparisonOutcome.improved, 'Improved from baseline'),
    (InspectionComparisonOutcome.deteriorated, 'Deteriorated from baseline'),
    (InspectionComparisonOutcome.resolved, 'Resolved from baseline'),
    (InspectionComparisonOutcome.recurred, 'Recurred from baseline'),
    (InspectionComparisonOutcome.notComparable, 'Not comparable to baseline'),
  ]) {
    test('$outcome retains its existing meaning', () {
      expect(
        inspectionObservationComparisonLabel(outcome, _definition(max: 5)),
        label,
      );
    });
  }
}
