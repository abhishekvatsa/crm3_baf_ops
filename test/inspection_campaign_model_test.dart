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
  'schemaVersion': 2,
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
  'physicalPositionLabels': <String>['Gas train'],
  'targetPopulation': <Map<String, dynamic>>[
    campaignTarget(
      assetNumber: 1,
      disposition: 'observed',
      lastObservationId: 'observation-1',
      lastObservedAt: '2026-08-21T05:00:00.000Z',
    ),
    campaignTarget(
      assetNumber: 2,
      disposition: 'deferred',
      dispositionReason: 'Furnace remains in the governed production cycle.',
    ),
    campaignTarget(assetNumber: 3),
  ],
  'targetDispositionCounts': <String, int>{
    'pending': 1,
    'observed': 1,
    'deferred': 1,
    'unavailable': 0,
    'excludedWithReason': 0,
    'requiresReaudit': 0,
  },
  'expectedPopulation': 3,
  'baselineCampaignId': null,
  'observerRoleKeys': <String>['seniorInstrumentation'],
  'observationCount': 2,
  'distinctTargetKeys': <String>[
    'class-furnace:furnace-1|pressure-transmitter|Gas train',
  ],
  'latestObservationAt': '2026-08-21T05:00:00.000Z',
  'createdAt': '2026-08-21T04:00:00.000Z',
};

Map<String, dynamic> campaignTarget({
  required int assetNumber,
  String disposition = 'pending',
  String? dispositionReason,
  String? lastObservationId,
  String? lastObservedAt,
}) => <String, dynamic>{
  'schemaVersion': 1,
  'targetKey':
      'class-furnace:furnace-$assetNumber|pressure-transmitter|Gas train',
  'assetTypeKey': 'furnace',
  'assetClassId': 'class-furnace',
  'assetNumber': assetNumber,
  'assetInstanceId': 'furnace-$assetNumber',
  'assetInstanceVersion': 1,
  'assetInstanceName': 'Furnace ${assetNumber.toString().padLeft(2, '0')}',
  'componentNodeId': 'pressure-transmitter',
  'physicalPosition': 'Gas train',
  'disposition': disposition,
  'dispositionReason': dispositionReason,
  'dispositionAt': '2026-08-21T04:00:00.000Z',
  'dispositionByUid': 'admin-1',
  'dispositionByName': 'Admin 1',
  'addedLater': false,
  'lastObservationId': lastObservationId,
  'lastObservedAt': lastObservedAt,
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
  'targetKey': 'class-furnace:furnace-1|pressure-transmitter|Gas train',
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
  'baselineCampaignId': null,
  'baselineObservationId': null,
  'comparisonOutcome': null,
  'recordedAt': '2026-08-21T05:01:00.000Z',
};

Map<String, dynamic> findingMap() => <String, dynamic>{
  'schemaVersion': 1,
  'findingId': 'finding-1',
  'version': 2,
  'campaignId': 'campaign-1',
  'targetKey': 'class-furnace:furnace-1|pressure-transmitter|Gas train',
  'assetTypeKey': 'furnace',
  'assetNumber': 1,
  'assetClassId': 'class-furnace',
  'assetInstanceId': 'furnace-1',
  'componentNodeId': 'pressure-transmitter',
  'componentName': 'Pressure transmitter',
  'physicalPosition': 'Gas train',
  'status': 'awaitingVerification',
  'firstObservationId': 'observation-1',
  'currentObservationId': 'observation-2',
  'firstObservedAt': '2026-08-21T05:00:00.000Z',
  'latestObservedAt': '2026-08-21T06:00:00.000Z',
  'recurrenceCount': 1,
  'linkedTicketId': 'ticket-1',
  'verificationCount': 0,
  'lastVerificationOutcome': null,
  'updatedAt': '2026-08-21T06:01:00.000Z',
};

Map<String, dynamic> innerCoverCampaignMap() {
  final definition =
      frozenDefinition()
        ..['assetTypeKeys'] = <String>['innerCover']
        ..['assetClassIds'] = <String>['class-inner-cover']
        ..['componentNodeIds'] = <String>['inner-cover-shell'];
  final target = <String, dynamic>{
    'schemaVersion': 1,
    'targetKey':
        'class-inner-cover:inner-cover-n4|inner-cover-shell|Shell|link:link-n4-base-205',
    'assetTypeKey': 'innerCover',
    'assetClassId': 'class-inner-cover',
    'assetNumber': 205,
    'assetInstanceId': 'inner-cover-n4',
    'assetInstanceVersion': 7,
    'assetInstanceName': 'Inner Cover N4',
    'hostAssetClassId': 'class-base',
    'hostAssetInstanceId': 'base-205',
    'hostAssetInstanceVersion': 3,
    'hostAssetNumber': 205,
    'hostAssetInstanceName': 'Base 205',
    'subjectSerialNumber': 'N4',
    'linkageId': 'link-n4-base-205',
    'linkageVersion': 1,
    'linkedAt': '2026-08-21T04:00:00.000Z',
    'componentNodeId': 'inner-cover-shell',
    'physicalPosition': 'Shell',
    'disposition': 'pending',
    'dispositionReason': null,
    'dispositionAt': '2026-08-21T04:00:00.000Z',
    'dispositionByUid': 'admin-1',
    'dispositionByName': 'Admin 1',
    'addedLater': false,
    'lastObservationId': null,
    'lastObservedAt': null,
  };
  return <String, dynamic>{
    'schemaVersion': 2,
    'campaignId': 'campaign-inner-cover',
    'version': 1,
    'status': 'open',
    'definition': definition,
    'definitionId': 'definition-1',
    'definitionVersion': 2,
    'definitionCode': 'FURNACE_PT_SETTING',
    'definitionTitle': 'Furnace pressure-transmitter setting',
    'purpose': 'Inspect installed Inner Covers by their current Base position.',
    'assetTypeKey': 'innerCover',
    'assetClassId': 'class-inner-cover',
    'populationMode': 'installedInnerCoversByBase',
    'hostAssetClassId': 'class-base',
    'targetAssetNumbers': <int>[205],
    'physicalPositionLabels': <String>['Shell'],
    'targetPopulation': <Map<String, dynamic>>[target],
    'targetDispositionCounts': <String, int>{
      'pending': 1,
      'observed': 0,
      'deferred': 0,
      'unavailable': 0,
      'excludedWithReason': 0,
      'requiresReaudit': 0,
    },
    'expectedPopulation': 1,
    'baselineCampaignId': null,
    'observerRoleKeys': <String>['seniorMechanical'],
    'observationCount': 0,
    'distinctTargetKeys': <String>[],
    'latestObservationAt': null,
    'createdAt': '2026-08-21T04:00:00.000Z',
  };
}

void main() {
  test('separates observed coverage from total population accounting', () {
    final campaign = InspectionCampaign.fromMap(campaignMap(), 'campaign-1');

    expect(campaign.distinctTargetCount, 1);
    expect(campaign.accountedTargetCount, 2);
    expect(campaign.remainingPopulation, 1);
    expect(campaign.coverageFraction, closeTo(1 / 3, 0.0001));
    expect(campaign.canClose, isFalse);
    expect(campaign.observationCount, 2);
  });

  test(
    'legacy campaign defaults to the governed asset-instance population',
    () {
      final campaign = InspectionCampaign.fromMap(campaignMap(), 'campaign-1');

      expect(
        campaign.populationMode,
        InspectionCampaignPopulationMode.assetInstances,
      );
      expect(campaign.hostAssetClassId, isNull);
    },
  );

  test('installed Inner Cover campaign retains Base and serial identity', () {
    final campaign = InspectionCampaign.fromMap(
      innerCoverCampaignMap(),
      'campaign-inner-cover',
    );

    expect(
      campaign.populationMode,
      InspectionCampaignPopulationMode.installedInnerCoversByBase,
    );
    expect(campaign.hostAssetClassId, 'class-base');
    expect(campaign.targets.single.assetInstanceId, 'inner-cover-n4');
    expect(campaign.targets.single.linkageId, 'link-n4-base-205');
    expect(campaign.targets.single.rowLabel, 'Base 205 (N4)');
  });

  test('partial installed Inner Cover context fails closed', () {
    final malformed = innerCoverCampaignMap();
    final target = (malformed['targetPopulation'] as List).single as Map;
    target.remove('linkageId');

    expect(
      () => InspectionCampaign.fromMap(malformed, 'campaign-inner-cover'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('campaign target population fails closed on duplicate identity', () {
    final malformed = campaignMap();
    malformed['targetPopulation'] = <Map<String, dynamic>>[
      campaignTarget(assetNumber: 1),
      campaignTarget(assetNumber: 1),
      campaignTarget(assetNumber: 3),
    ];

    expect(
      () => InspectionCampaign.fromMap(malformed, 'campaign-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('partial or inconsistent disposition counters fail closed', () {
    final partial = campaignMap();
    partial['targetDispositionCounts'] = <String, int>{
      'pending': 1,
      'observed': 1,
    };
    final inconsistent = campaignMap();
    inconsistent['targetDispositionCounts'] = <String, int>{
      'pending': 2,
      'observed': 1,
      'deferred': 0,
      'unavailable': 0,
      'excludedWithReason': 0,
      'requiresReaudit': 0,
    };

    for (final malformed in [partial, inconsistent]) {
      expect(
        () => InspectionCampaign.fromMap(malformed, 'campaign-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    }
  });

  test('frozen definition identity mismatch fails closed', () {
    final malformed = campaignMap()..['definitionVersion'] = 3;

    expect(
      () => InspectionCampaign.fromMap(malformed, 'campaign-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('exact class scope overrides the broader legacy type scope', () {
    final classOnly = campaignMap();
    (classOnly['definition'] as Map<String, dynamic>)['assetTypeKeys'] =
        <String>[];
    expect(
      InspectionCampaign.fromMap(classOnly, 'campaign-1').assetClassId,
      'class-furnace',
    );

    final wrongClass = campaignMap()..['assetClassId'] = 'class-other-furnace';
    final targets =
        wrongClass['targetPopulation'] as List<Map<String, dynamic>>;
    for (final target in targets) {
      final number = target['assetNumber'] as int;
      target
        ..['assetClassId'] = 'class-other-furnace'
        ..['targetKey'] =
            'class-other-furnace:furnace-$number|pressure-transmitter|Gas train';
    }
    wrongClass['distinctTargetKeys'] = <String>[
      'class-other-furnace:furnace-1|pressure-transmitter|Gas train',
    ];

    expect(
      () => InspectionCampaign.fromMap(wrongClass, 'campaign-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('campaign and observation target keys remain content-bound', () {
    final campaign = campaignMap();
    final target =
        (campaign['targetPopulation'] as List<Map<String, dynamic>>).first;
    target['targetKey'] =
        'class-furnace:furnace-1|pressure-transmitter|Other position';
    final observation =
        observationMap()
          ..['targetKey'] =
              'class-furnace:furnace-1|pressure-transmitter|Other position';

    expect(
      () => InspectionCampaign.fromMap(campaign, 'campaign-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => InspectionObservation.fromMap(observation, 'observation-1'),
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

  test('Inner Cover observation and finding use the Base-facing row label', () {
    final observationData =
        observationMap()
          ..['definition'] = (innerCoverCampaignMap()['definition'] as Map)
          ..['assetTypeKey'] = 'innerCover'
          ..['assetNumber'] = 205
          ..['assetClassId'] = 'class-inner-cover'
          ..['assetInstanceId'] = 'inner-cover-n4'
          ..['hostAssetClassId'] = 'class-base'
          ..['hostAssetInstanceId'] = 'base-205'
          ..['hostAssetInstanceVersion'] = 3
          ..['hostAssetNumber'] = 205
          ..['hostAssetInstanceName'] = 'Base 205'
          ..['subjectSerialNumber'] = 'N4'
          ..['linkageId'] = 'link-n4-base-205'
          ..['linkageVersion'] = 1
          ..['linkedAt'] = '2026-08-21T04:00:00.000Z'
          ..['componentNodeId'] = 'inner-cover-shell'
          ..['componentName'] = 'Inner Cover shell'
          ..['physicalPosition'] = 'Shell'
          ..['targetKey'] =
              'class-inner-cover:inner-cover-n4|inner-cover-shell|Shell|link:link-n4-base-205';
    final findingData =
        findingMap()
          ..['assetTypeKey'] = 'innerCover'
          ..['assetNumber'] = 205
          ..['assetClassId'] = 'class-inner-cover'
          ..['assetInstanceId'] = 'inner-cover-n4'
          ..['hostAssetNumber'] = 205
          ..['subjectSerialNumber'] = 'N4';

    final observation = InspectionObservation.fromMap(
      observationData,
      'observation-1',
    );
    final finding = InspectionFinding.fromMap(findingData, 'finding-1');

    expect(observation.rowLabel, 'Base 205 (N4)');
    expect(finding.rowLabel, 'Base 205 (N4)');
  });
  test('durable finding exposes closure state and corrective issue', () {
    final finding = InspectionFinding.fromMap(findingMap(), 'finding-1');

    expect(finding.blocksCampaignClosure, isTrue);
    expect(finding.linkedTicketId, 'ticket-1');
    expect(finding.status, InspectionFindingStatus.awaitingVerification);
  });
}
