import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inspection_campaign_model_test.dart' as legacy;

void main() {
  final corpus =
      jsonDecode(
            File(
              'test/fixtures/inspection_reading_contract_v2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final row in corpus['fieldCases'] as List) {
    test('shared field contract: ${row['name']}', () {
      if (row['valid'] == true) {
        final fields = readInspectionReadingFields(row['fields']);
        expect(fields.map((field) => field.toMap()).toList(), row['fields']);
      } else {
        expect(
          () => readInspectionReadingFields(row['fields']),
          throwsA(isA<FormatException>()),
        );
      }
    });
  }
  for (final row in corpus['observationCases'] as List) {
    test('shared observation envelope: ${row['name']}', () {
      final fields = readInspectionReadingFields(row['fields']);
      if (row['valid'] == true) {
        final values = readInspectionReadingEnvelope(fields, row['value']);
        expect(
          values.map((value) => value.toMap()).toList(),
          row['value']['readings'],
        );
        expect(inspectionReadingsOutOfRange(fields, values), row['outOfRange']);
      } else {
        expect(
          () => readInspectionReadingEnvelope(fields, row['value']),
          throwsA(isA<FormatException>()),
        );
      }
    });
  }
  for (final row in corpus['displayDates'] as List) {
    test('calendar date round trip: ${row['stored']}', () {
      expect(formatInspectionDate(row['stored'] as String), row['display']);
      expect(parseInspectionDateInput(row['display'] as String), row['stored']);
    });
  }

  test('date input is exact and never rolls impossible dates forward', () {
    for (final value in [
      '1-02-2026',
      '01/02/2026',
      '31-04-2026',
      '29-02-1900',
      '01-01-0000',
      ' 01-01-2026',
      '01-01-2026 ',
    ]) {
      expect(parseInspectionDateInput(value), isNull, reason: value);
    }
    expect(parseInspectionDateInput('29-02-2000'), '2000-02-29');
    expect(parseInspectionDateInput('31-12-9999'), '9999-12-31');
  });

  test(
    'legacy observations refuse a v2 schema or mixed canonical envelope',
    () {
      final original = legacy.observationMap();
      expect(
        () => InspectionObservation.fromMap({
          ...original,
          'schemaVersion': 2,
        }, 'observation-1'),
        throwsFormatException,
      );
      expect(
        () => InspectionObservation.fromMap({
          ...original,
          'value': {'schemaVersion': 2, 'readings': []},
        }, 'observation-1'),
        throwsFormatException,
      );
      expect(
        () => InspectionObservation.fromMap({
          ...original,
          'readings': [],
        }, 'observation-1'),
        throwsFormatException,
      );
      final historical = {...original}..remove('schemaVersion');
      expect(
        InspectionObservation.fromMap(historical, 'observation-1').numericValue,
        1.8,
      );
    },
  );

  final fields = (corpus['fieldCases'] as List).first['fields'];
  Map<String, dynamic> frozenV2() {
    final map = legacy.frozenDefinition()..['schemaVersion'] = 2;
    for (final key in [
      'valueType',
      'unit',
      'choiceValues',
      'minimumValue',
      'maximumValue',
    ]) {
      map.remove(key);
    }
    map['readingFields'] = fields;
    return map;
  }

  test('legacy model and immutable input remain unchanged; date is not v1', () {
    final map = legacy.frozenDefinition();
    final original = jsonEncode(map);
    final parsed = FrozenInspectionDefinition.fromMap(map, source: 'legacy');
    expect(parsed.schemaVersion, 1);
    expect(parsed.isMultiReading, isFalse);
    expect(parsed.valueType, InspectionValueType.number);
    expect(parsed.readingFields, isEmpty);
    expect(jsonEncode(map), original);
    map['valueType'] = 'date';
    map['unit'] = null;
    expect(
      () => FrozenInspectionDefinition.fromMap(map, source: 'legacy'),
      throwsA(isA<FormatException>()),
    );
  });

  test('v2 frozen contract retains identities and has no legacy type', () {
    final parsed = FrozenInspectionDefinition.fromMap(frozenV2(), source: 'v2');
    expect(parsed.isMultiReading, isTrue);
    expect(parsed.valueType, isNull);
    expect(parsed.readingFields.map((field) => field.id), [
      'completed',
      'completion_date',
    ]);
    final malformed = frozenV2()..['valueType'] = 'boolean';
    expect(
      () => FrozenInspectionDefinition.fromMap(malformed, source: 'v2'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'v2 persisted observation reads only canonical envelope and all labels',
    () {
      final map = legacy.observationMap()
        ..['schemaVersion'] = 2
        ..['definition'] = frozenV2()
        ..['outOfRange'] = false;
      for (final key in [
        'valueType',
        'numericValue',
        'booleanValue',
        'textValue',
        'choiceValue',
        'unit',
        'minimumValue',
        'maximumValue',
      ]) {
        map.remove(key);
      }
      map['value'] = (corpus['observationCases'] as List).first['value'];
      final parsed = InspectionObservation.fromMap(map, 'observation-1');
      expect(parsed.readings.length, 2);
      expect(
        parsed.displayValue,
        'Completed?: No\nCompletion date: 03-10-2026',
      );
      expect(
        parsed.conditionLabel,
        'Recorded; no defined condition to assess it against',
      );
      for (final key in ['readings', 'numericValue', 'valueType', 'unit']) {
        expect(
          () => InspectionObservation.fromMap({
            ...map,
            key: null,
          }, 'observation-1'),
          throwsA(isA<FormatException>()),
        );
      }
      expect(
        () => InspectionObservation.fromMap({
          ...map,
          'outOfRange': true,
        }, 'observation-1'),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'mixed readings describe assessed numeric limits without certifying other fields',
    () {
      final numeric = const InspectionReadingField(
        id: 'pressure',
        label: 'Pressure',
        valueType: InspectionValueType.number,
        unit: 'bar',
        minimumValue: 2,
        maximumValue: 4,
      ).toMap();
      final definition = frozenV2()
        ..['readingFields'] = [numeric, fields.first];
      final map = legacy.observationMap()
        ..['schemaVersion'] = 2
        ..['definition'] = definition
        ..['outOfRange'] = false;
      for (final key in [
        'valueType',
        'numericValue',
        'booleanValue',
        'textValue',
        'choiceValue',
        'unit',
        'minimumValue',
        'maximumValue',
      ]) {
        map.remove(key);
      }
      map['value'] = {
        'schemaVersion': 2,
        'readings': [
          {'fieldId': 'pressure', 'valueType': 'number', 'value': 3},
          {'fieldId': 'completed', 'valueType': 'boolean', 'value': false},
        ],
      };
      final parsed = InspectionObservation.fromMap(map, 'observation-1');
      expect(parsed.wasAssessedAgainstLimits, isFalse);
      expect(
        parsed.conditionLabel,
        'Numeric readings within limits; other readings recorded',
      );
    },
  );
}
