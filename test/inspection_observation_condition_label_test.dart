import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:flutter_test/flutter_test.dart';

FrozenInspectionDefinition _definition({
  required InspectionValueType valueType,
  double? minimumValue,
  double? maximumValue,
}) => FrozenInspectionDefinition(
  id: 'definition-1',
  version: 1,
  code: 'SHELL_TEMP',
  title: 'Shell temperature',
  description: 'Shell temperature at the crown.',
  assetTypeKeys: const <String>['furnace'],
  assetClassIds: const <String>['furnace-class'],
  componentNodeIds: const <String>['shell'],
  valueType: valueType,
  unit: valueType == InspectionValueType.number ? 'degC' : null,
  choiceValues: valueType == InspectionValueType.choice
      ? const <String>['clean', 'sooted']
      : const <String>[],
  minimumValue: minimumValue,
  maximumValue: maximumValue,
  preconditions: const <String>[],
  requiresChargeNo: false,
);

InspectionObservation _observation({
  required FrozenInspectionDefinition definition,
  double? numericValue,
  bool? booleanValue,
  String? choiceValue,
  String? textValue,
  required bool outOfRange,
}) => InspectionObservation(
  id: 'observation-1',
  campaignId: 'campaign-1',
  definition: definition,
  assetTypeKey: 'furnace',
  assetNumber: 1,
  assetClassId: 'furnace-class',
  assetInstanceId: 'furnace-1',
  hostAssetClassId: null,
  hostAssetInstanceId: null,
  hostAssetInstanceVersion: null,
  hostAssetNumber: null,
  hostAssetInstanceName: null,
  subjectSerialNumber: null,
  linkageId: null,
  linkageVersion: null,
  linkedAt: null,
  componentNodeId: 'shell',
  componentNodeVersion: 1,
  componentName: 'Shell',
  hierarchyPath: const <String>['Furnace', 'Shell'],
  physicalPosition: null,
  targetKey: 'target-1',
  observedAt: DateTime.utc(2026, 9, 1),
  observerUid: 'operator-1',
  observerName: 'Operator One',
  numericValue: numericValue,
  booleanValue: booleanValue,
  textValue: textValue,
  choiceValue: choiceValue,
  unit: definition.unit,
  outOfRange: outOfRange,
  operatingConditions: const <String, String>{},
  chargeNo: null,
  note: null,
  evidenceUrls: const <String>[],
  supersedesObservationId: null,
  baselineCampaignId: null,
  baselineObservationId: null,
  comparisonOutcome: null,
  recordedAt: DateTime.utc(2026, 9, 1),
);

void main() {
  group('describing what an inspection observation establishes', () {
    test('a numeric reading outside its limit is an exception', () {
      final observation = _observation(
        definition: _definition(
          valueType: InspectionValueType.number,
          maximumValue: 400,
        ),
        numericValue: 460,
        outOfRange: true,
      );

      expect(observation.wasAssessedAgainstLimits, isTrue);
      expect(observation.conditionLabel, 'Exception recorded');
    });

    test('a numeric reading inside its limit conforms', () {
      final observation = _observation(
        definition: _definition(
          valueType: InspectionValueType.number,
          maximumValue: 400,
        ),
        numericValue: 380,
        outOfRange: false,
      );

      expect(observation.wasAssessedAgainstLimits, isTrue);
      expect(observation.conditionLabel, 'Within defined condition');
    });

    test('a boolean observation is not a conformity decision', () {
      // Nothing was compared. Which boolean value would be adverse has not
      // been decided, so reporting this as conforming asserts something the
      // plant never established.
      final observation = _observation(
        definition: _definition(valueType: InspectionValueType.boolean),
        booleanValue: true,
        outOfRange: false,
      );

      expect(observation.wasAssessedAgainstLimits, isFalse);
      expect(
        observation.conditionLabel,
        'Recorded; no defined condition to assess it against',
      );
    });

    test('a choice observation is not a conformity decision', () {
      final observation = _observation(
        definition: _definition(valueType: InspectionValueType.choice),
        choiceValue: 'sooted',
        outOfRange: false,
      );

      expect(
        observation.conditionLabel,
        'Recorded; no defined condition to assess it against',
      );
    });

    test('a numeric reading with no limit set was not assessed either', () {
      final observation = _observation(
        definition: _definition(valueType: InspectionValueType.number),
        numericValue: 380,
        outOfRange: false,
      );

      expect(observation.wasAssessedAgainstLimits, isFalse);
      expect(
        observation.conditionLabel,
        'Recorded; no defined condition to assess it against',
      );
    });

    test('a single-sided limit is still an assessment', () {
      final observation = _observation(
        definition: _definition(
          valueType: InspectionValueType.number,
          minimumValue: 10,
        ),
        numericValue: 380,
        outOfRange: false,
      );

      expect(observation.wasAssessedAgainstLimits, isTrue);
      expect(observation.conditionLabel, 'Within defined condition');
    });
  });
}
