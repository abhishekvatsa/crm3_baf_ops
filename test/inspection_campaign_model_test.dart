import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';

Map<String, dynamic> frozenDefinition() => <String, dynamic>{
  'schemaVersion': 1,
  'definitionId': 'definition-1',
  'definitionVersion': 2,
  'code': 'FURNACE_PT_SETTING',
  'title': 'Furnace pressure-transmitter setting',
  'description': 'Verify the governed Furnace pressure setting.',
  'assetTypeKeys': <String>['furnace'],
  'assetClassIds': <String>['class-furnace'],
  'componentNodeIds': <String>['pressure-transmitter'],
  'valueType': 'number',
  'unit': 'bar',
  'choiceValues': <String>[],
  'minimumValue': 2,
  'maximumValue': 4,
  'preconditions': <String>['Furnace isolated'],
  'requiresChargeNo': false,
};

Map<String, dynamic> campaignMap() => <String, dynamic>{
  'schemaVersion': 1,
  'campaignId': 'campaign-1',
  'version': 3,
  'status': 'open',
  'definition': frozenDefinition(),
  'definitionId': 'definition-1',
  'definitionVersion': 2,
  'definitionCode': 'FURNACE_PT_SETTING',
  'definitionTitle': 'Furnace pressure-transmitter setting',
  'purpose': 'Verify settings across the reachable Furnace population.',
  'assetTypeKey': 'furnace',
  'assetClassId': 'class-furnace',
  'targetAssetNumbers': <int>[1, 2, 3],
  'expectedPopulation': 26,
  'observerRoleKeys': <String>['seniorInstrumentation'],
  'observationCount': 2,
  'distinctTargetKeys': <String>['furnace:1|pressure-transmitter|Gas train'],
  'latestObservationAt': '2026-08-21T05:00:00.000Z',
  'createdAt': '2026-08-21T04:00:00.000Z',
};

Map<String, dynamic> observationMap() => <String, dynamic>{
  'schemaVersion': 1,
  'observationId': 'observation-1',
  'campaignId': 'campaign-1',
  'campaignVersionAtObservation': 2,
  'definition': frozenDefinition(),
  'definitionId': 'definition-1',
  'definitionVersion': 2,
  'definitionCode': 'FURNACE_PT_SETTING',
  'assetTypeKey': 'furnace',
  'assetNumber': 1,
  'assetClassId': 'class-furnace',
  'assetInstanceId': 'furnace-1',
  'componentNodeId': 'pressure-transmitter',
  'componentNodeVersion': 4,
  'componentName': 'Pressure transmitter',
  'hierarchyPath': <String>[
    'Furnace',
    'Combustion system',
    'Pressure transmitter',
  ],
  'physicalPosition': 'Gas train',
  'targetKey': 'furnace:1|pressure-transmitter|Gas train',
  'observedAt': '2026-08-21T05:00:00.000Z',
  'observerUid': 'instrument-1',
  'observerName': 'Instrument 1',
  'value': <String, dynamic>{
    'valueType': 'number',
    'numericValue': 1.8,
    'booleanValue': null,
    'textValue': null,
    'choiceValue': null,
  },
  'valueType': 'number',
  'numericValue': 1.8,
  'booleanValue': null,
  'textValue': null,
  'choiceValue': null,
  'unit': 'bar',
  'minimumValue': 2,
  'maximumValue': 4,
  'outOfRange': true,
  'operatingConditions': <String, String>{'furnaceState': 'isolated'},
  'chargeNo': 12345,
  'note': 'Reading witnessed at the governed test point.',
  'evidenceUrls': <String>[],
  'supersedesObservationId': null,
  'recordedAt': '2026-08-21T05:01:00.000Z',
};

void main() {
  test('decodes partial coverage without treating it as failure', () {
    final campaign = InspectionCampaign.fromMap(campaignMap(), 'campaign-1');

    expect(campaign.distinctTargetCount, 1);
    expect(campaign.remainingPopulation, 25);
    expect(campaign.coverageFraction, closeTo(1 / 26, 0.0001));
    expect(campaign.observationCount, 2);
  });

  test('frozen definition identity mismatch fails closed', () {
    final malformed = campaignMap()..['definitionVersion'] = 3;

    expect(
      () => InspectionCampaign.fromMap(malformed, 'campaign-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('observation requires paired asset and component identities', () {
    final missingAssetInstance = observationMap()..['assetInstanceId'] = null;
    final missingComponentVersion =
        observationMap()..['componentNodeVersion'] = null;

    for (final malformed in [missingAssetInstance, missingComponentVersion]) {
      expect(
        () => InspectionObservation.fromMap(malformed, 'observation-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test(
    'typed reading and exact charge projection fail closed when malformed',
    () {
      final sixDigitCharge = observationMap()..['chargeNo'] = 123456;
      final mixedValue = observationMap()..['booleanValue'] = true;

      for (final malformed in [sixDigitCharge, mixedValue]) {
        expect(
          () => InspectionObservation.fromMap(malformed, 'observation-1'),
          throwsA(isA<PersistedDataFormatException>()),
        );
      }
    },
  );

  test('valid out-of-range observation remains legible', () {
    final observation = InspectionObservation.fromMap(
      observationMap(),
      'observation-1',
    );

    expect(observation.outOfRange, isTrue);
    expect(observation.displayValue, '1.8 bar');
    expect(observation.chargeNo, 12345);
    expect(observation.componentName, 'Pressure transmitter');
  });
}
