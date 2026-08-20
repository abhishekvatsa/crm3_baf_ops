import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('A-04 exact schema inventory is complete and source-enforced', () {
    final result = Process.runSync(_dartExecutable(), const <String>[
      'run',
      'tools/v4/a04_persisted_schema_inventory.dart',
    ], workingDirectory: Directory.current.path);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final output = '${result.stdout}';
    final jsonStart = output.indexOf('{');
    expect(jsonStart, greaterThanOrEqualTo(0), reason: output);
    final report =
        jsonDecode(output.substring(jsonStart)) as Map<String, dynamic>;
    expect(report['result'], 'PASS');
    expect(report['fieldCount'], 53);
    expect(report['jsonStringFieldCount'], 47);
    expect(report['dynamicValueFieldCount'], 6);
    expect(report['extensionBagCount'], 3);
    expect(report['registeredExtensionFieldCount'], 0);
    expect(report['inheritedDecoderSurfaceCount'], 65);
    expect(report['failures'], isEmpty);
  });

  test('legacy nested payloads canonicalize without losing typed values', () {
    final action = ComponentAction.fromMap(<String, dynamic>{
      'asset': 'base-201',
      'component': 'seal',
      'actionType': 'inspection',
      'isAutoResolved': false,
      'createdAt': '2026-08-17T10:00:00.000Z',
      'severity': 'medium',
      'version': 1,
    });
    final response = FieldResponse.fromMap(<String, dynamic>{
      'fieldId': 'pressure',
      'type': 'number',
      'answer': 2.1,
    });
    final field = TemplateField.fromMap(<String, dynamic>{
      'fieldId': 'pressure',
      'type': 'number',
      'validation': <String, dynamic>{'minimum': 0},
    });

    expect(action.toMap()['schemaVersion'], 1);
    expect(response.toMap()['schemaVersion'], 1);
    expect(field.toMap()['schemaVersion'], 1);
    expect(response.value, 2.1);
    expect(field.validation, containsPair('minimum', 0));
  });

  test(
    'legacy burner extension keys migrate to first-class typed evidence',
    () {
      final action = ComponentAction.fromMap(<String, dynamic>{
        'asset': 'Furnace 1',
        'component': 'Burner 2',
        'actionType': 'repair',
        'isAutoResolved': false,
        'createdAt': '2026-08-17T10:00:00.000Z',
        'severity': 'high',
        'version': 1,
        'attendanceSessionId': 'burner_ticket-1_2',
        'burnerPosition': 2,
        'burnerActionCode': 'feedbackReset',
        'burnerOutcome': 'returnedToService',
        'burnerMicroampReading': 2.8,
      });

      expect(action.extensions, isEmpty);
      expect(action.burnerPosition, 2);
      expect(action.burnerMicroampReading, 2.8);
      expect(action.toMap(), containsPair('burnerActionCode', 'feedbackReset'));
    },
  );

  test('unknown extension keys and unsupported versions fail closed', () {
    expect(
      () => ComponentAction.fromMap(<String, dynamic>{
        'asset': 'base-201',
        'component': 'seal',
        'actionType': 'inspection',
        'isAutoResolved': false,
        'createdAt': '2026-08-17T10:00:00.000Z',
        'severity': 'medium',
        'version': 1,
        'futureAuthority': true,
      }),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => FieldResponse.fromMap(<String, dynamic>{
        'schemaVersion': 2,
        'key': 'pressure',
        'fieldType': 'number',
        'value': 2.1,
      }),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => TemplateField.fromMap(<String, dynamic>{
        'key': 'pressure',
        'type': 'number',
        'futurePermission': 'admin',
      }),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('bounded JSON rejects malformed present values', () {
    expect(
      () => readBoundedPersistedJsonValue(
        double.infinity,
        field: 'response.value',
      ),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => readBoundedPersistedJsonValue(<String, dynamic>{
        'nested': Object(),
      }, field: 'response.value'),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => ComponentAction.fromMap(<String, dynamic>{
        'asset': 'base-201',
        'component': 'seal',
        'actionType': 'inspection',
        'isAutoResolved': false,
        'createdAt': '2026-08-17T10:00:00.000Z',
        'severity': 'medium',
        'version': 1,
        'metadataJson': '[]',
      }),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => ComponentAction.fromMap(<String, dynamic>{
        'asset': 'base-201',
        'component': 'seal',
        'actionType': 'inspection',
        'action': 'replacement',
        'isAutoResolved': false,
        'createdAt': '2026-08-17T10:00:00.000Z',
        'severity': 'medium',
        'version': 1,
      }),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => ComponentAction.fromMap(<String, dynamic>{
        'asset': 'base-201',
        'component': 'seal',
        'actionType': 'inspection',
        'isAutoResolved': false,
        'createdAt': '2026-08-17T10:00:00.000Z',
        'severity': 'medium',
        'version': 1,
        'metadataJson': '',
      }),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => FieldResponse(
        key: 'pressure',
        fieldLabel: 'Pressure',
        fieldType: FieldType.number,
        value: double.nan,
      ),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => TemplateField(
        key: 'pressure',
        type: FieldType.number,
        validationJson: '[]',
      ),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => ComponentAction(
        asset: 'base-201',
        component: 'seal',
        actionType: ActionType.inspection,
        metadataJson: '[]',
      ),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => ComponentAction(
        asset: 'Furnace 1',
        component: 'Burner 2',
        actionType: ActionType.repair,
        burnerPosition: 2,
      ),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}

String _dartExecutable() {
  final suffix = Platform.isWindows ? 'dart.exe' : 'dart';
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  if (configuredRoot != null && configuredRoot.trim().isNotEmpty) {
    final root = configuredRoot.trim();
    return '$root${Platform.pathSeparator}bin${Platform.pathSeparator}cache'
        '${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin'
        '${Platform.pathSeparator}$suffix';
  }
  final normalized = Platform.resolvedExecutable.replaceAll('\\', '/');
  const marker = '/bin/cache/';
  final markerIndex = normalized.indexOf(marker);
  if (markerIndex >= 0) {
    final flutterRoot = normalized.substring(0, markerIndex);
    return '$flutterRoot/bin/cache/dart-sdk/bin/$suffix';
  }
  return 'dart';
}
