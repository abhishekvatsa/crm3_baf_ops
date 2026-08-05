import 'dart:convert';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/job_module_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _moduleMap({
  Object? fieldDefinitionsJson = '[]',
  Object? responsesJson = '[]',
  Object? legacyResponses,
  bool includeCanonicalResponses = true,
}) {
  final map = <String, dynamic>{
    'moduleTitle': 'Pressure inspection',
    'assetType': AssetType.base.name,
    'assetNumber': 1,
    'status': JobModuleStatus.draftSaved.name,
    'discipline': JobModuleDiscipline.mechanical.name,
    'safetyClass': JobModuleSafetyClass.normal.name,
    'fieldDefinitionsJson': fieldDefinitionsJson,
    'createdAt': '2026-08-05T08:00:00.000Z',
    'updatedAt': '2026-08-05T08:00:00.000Z',
    'version': 1,
  };
  if (includeCanonicalResponses) map['responsesJson'] = responsesJson;
  if (legacyResponses != null) map['responses'] = legacyResponses;
  return map;
}

Map<String, dynamic> _executionMap({
  Object? responsesJson = '[]',
  Object? legacyResponses,
  bool includeCanonicalResponses = true,
}) {
  final map = <String, dynamic>{
    'templateFirestoreId': 'template-1',
    'templateName': 'Pressure inspection',
    'assetType': AssetType.base.name,
    'assetNumber': 1,
    'assignedAgencies': ['mechanical'],
    'createdAt': '2026-08-05T08:00:00.000Z',
    'updatedAt': '2026-08-05T08:00:00.000Z',
    'version': 1,
  };
  if (includeCanonicalResponses) map['responsesJson'] = responsesJson;
  if (legacyResponses != null) map['responses'] = legacyResponses;
  return map;
}

void main() {
  group('A-05 persisted response integrity', () {
    test('canonicalizes aliases and retains unknown response extensions', () {
      final raw = jsonEncode([
        {
          'fieldId': 'pressure',
          'label': 'Pressure',
          'type': 'numericWithUnit',
          'answer': 2.1,
          'futureExtension': {'retained': true},
        },
      ]);
      final module = JobModuleInstance.fromMap(
        _moduleMap(responsesJson: raw),
        'module-1',
      );

      expect(module.responsesReadResult.isValid, isTrue);
      expect(module.responses.single.key, 'pressure');
      expect(module.responses.single.fieldType, FieldType.number);
      expect(module.responses.single.value, 2.1);

      module.responses = module.responsesReadResult.entries;
      final rewritten = jsonDecode(module.responsesJson) as List<dynamic>;
      expect(rewritten.single.containsKey('fieldId'), isFalse);
      expect(rewritten.single.containsKey('answer'), isFalse);
      expect(rewritten.single.containsKey('label'), isFalse);
      expect(rewritten.single.containsKey('type'), isFalse);
      expect(rewritten.single['futureExtension'], {'retained': true});
      expect(rewritten.single['key'], 'pressure');
      expect(rewritten.single['value'], 2.1);
    });

    test(
      'preserves malformed canonical responses and never uses legacy fallback',
      () {
        const malformed = '[{"key":"pressure"}]';
        final module = JobModuleInstance.fromMap(
          _moduleMap(
            responsesJson: malformed,
            legacyResponses: const [
              {'key': 'legacy', 'value': 'must-not-win'},
            ],
          ),
          'module-1',
        );

        expect(module.responsesJson, malformed);
        expect(module.responsesReadResult.isValid, isFalse);
        expect(() => module.responses, throwsA(isA<FormatException>()));
        expect(module.toMap()['responsesJson'], malformed);
      },
    );

    test('rejects incomplete legacy rows instead of dropping them', () {
      expect(
        () => JobModuleInstance.fromMap(
          _moduleMap(
            includeCanonicalResponses: false,
            legacyResponses: const [
              {'key': 'pressure', 'value': 2.1},
              'corrupt-row',
            ],
          ),
          'module-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test(
      'missing legacy response field initializes an explicit empty payload',
      () {
        final module = JobModuleInstance.fromMap(
          _moduleMap(includeCanonicalResponses: false),
          'module-1',
        );
        final execution = JobExecution.fromMap(
          _executionMap(includeCanonicalResponses: false),
          'execution-1',
        );

        expect(module.responsesJson, '[]');
        expect(module.responsesReadResult.isValid, isTrue);
        expect(execution.responsesJson, '[]');
        expect(execution.responsesReadResult.isValid, isTrue);
      },
    );

    test('preserves malformed execution responses as a repair state', () {
      const malformed = '[{"value":"orphan"}]';
      final execution = JobExecution.fromMap(
        _executionMap(responsesJson: malformed),
        'execution-1',
      );

      expect(execution.responsesJson, malformed);
      expect(execution.responsesReadResult.isValid, isFalse);
      expect(() => execution.responses, throwsA(isA<FormatException>()));
      expect(execution.toMap()['responsesJson'], malformed);
    });

    test('wrong canonical payload types fail at the remote map boundary', () {
      expect(
        () => JobExecution.fromMap(
          _executionMap(responsesJson: <dynamic>[]),
          'execution-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => JobModuleInstance.fromMap(
          _moduleMap(responsesJson: <dynamic>[]),
          'module-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => JobExecution.fromMap(
          _executionMap(responsesJson: null),
          'execution-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    testWidgets('module card shows repair states instead of zero counts', (
      tester,
    ) async {
      final module = JobModuleInstance.fromMap(
        _moduleMap(
          fieldDefinitionsJson: '[{"type":"text"}]',
          responsesJson: '[{"key":"pressure"}]',
        ),
        'module-1',
      );

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: JobModuleCard(module: module))),
      );

      expect(find.text('Fields need repair'), findsOneWidget);
      expect(find.text('Responses need repair'), findsOneWidget);
      expect(
        find.textContaining('Saved module evidence needs repair'),
        findsOneWidget,
      );
      expect(find.textContaining('0 structured responses'), findsNothing);
    });
  });

  group('A-05 persisted field-definition integrity', () {
    test('accepts governed aliases and supported production field types', () {
      final module = JobModuleInstance.fromMap(
        _moduleMap(
          fieldDefinitionsJson: jsonEncode([
            {
              'fieldId': 'pressure',
              'label': 'Pressure',
              'type': 'numericWithUnit',
              'required': true,
              'futureExtension': ['retained'],
            },
          ]),
        ),
        'module-1',
      );

      expect(module.fieldDefinitionsReadResult.isValid, isTrue);
      expect(
        module.fieldDefinitionsReadResult.entries.single['futureExtension'],
        ['retained'],
      );
    });

    test('preserves malformed definitions and exposes repair state', () {
      const malformed = '[{"type":"text","required":true}]';
      final module = JobModuleInstance.fromMap(
        _moduleMap(fieldDefinitionsJson: malformed),
        'module-1',
      );

      expect(module.fieldDefinitionsJson, malformed);
      expect(module.fieldDefinitionsReadResult.isValid, isFalse);
      expect(module.toMap()['fieldDefinitionsJson'], malformed);
    });

    test('wrong canonical definition type fails at remote map boundary', () {
      expect(
        () => JobModuleInstance.fromMap(
          _moduleMap(fieldDefinitionsJson: <dynamic>[]),
          'module-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => JobModuleInstance.fromMap(
          _moduleMap(fieldDefinitionsJson: null),
          'module-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    for (final raw in <String>[
      '[{"key":"pressure","type":"telepathy"}]',
      '[{"key":"pressure","required":"yes"}]',
      '[{"key":"pressure"},{"fieldId":"PRESSURE"}]',
      '["not-an-object"]',
    ]) {
      test('rejects malformed definition payload $raw', () {
        final result = PersistedFieldDefinitionPayload.tryDecode(raw);
        expect(result.isValid, isFalse);
        expect(result.entries, isEmpty);
      });
    }
  });

  group('A-05 canonical action-field presence', () {
    test('only an absent pre-feature action field initializes empty', () {
      final module = JobModuleInstance.fromMap(_moduleMap(), 'module-1');
      final execution = JobExecution.fromMap(_executionMap(), 'execution-1');

      expect(module.actionsJson, '[]');
      expect(execution.actionsJson, '[]');

      final nullModule = _moduleMap()..['actionsJson'] = null;
      final nullExecution = _executionMap()..['actionsJson'] = null;
      expect(
        () => JobModuleInstance.fromMap(nullModule, 'module-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => JobExecution.fromMap(nullExecution, 'execution-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });
  });
}
