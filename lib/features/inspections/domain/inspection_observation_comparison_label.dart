import '../data/inspection_campaign.dart';

/// Describes the server comparison using its frozen reading contract.
/// An unchanged numeric limit result does not establish identical readings.
/// This is for observation comparisons, not manually verified finding outcomes.
String inspectionObservationComparisonLabel(
  InspectionComparisonOutcome outcome,
  FrozenInspectionDefinition definition,
) {
  if (outcome == InspectionComparisonOutcome.unchanged) {
    final numericFields = definition.isMultiReading
        ? definition.readingFields.where(
            (field) => field.valueType == InspectionValueType.number,
          )
        : const <InspectionReadingField>[];
    final hasNumeric = definition.isMultiReading
        ? numericFields.isNotEmpty
        : definition.valueType == InspectionValueType.number;
    final hasLimits = definition.isMultiReading
        ? numericFields.any(
            (field) => field.minimumValue != null || field.maximumValue != null,
          )
        : hasNumeric &&
              (definition.minimumValue != null ||
                  definition.maximumValue != null);
    if (hasLimits) return 'Limit status unchanged from baseline';
    if (hasNumeric) return 'No numeric limits to compare';
  }
  return switch (outcome) {
    InspectionComparisonOutcome.improved => 'Improved from baseline',
    InspectionComparisonOutcome.unchanged => 'Unchanged from baseline',
    InspectionComparisonOutcome.deteriorated => 'Deteriorated from baseline',
    InspectionComparisonOutcome.resolved => 'Resolved from baseline',
    InspectionComparisonOutcome.recurred => 'Recurred from baseline',
    InspectionComparisonOutcome.notComparable => 'Not comparable to baseline',
  };
}
