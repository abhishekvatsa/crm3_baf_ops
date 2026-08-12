import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_composer_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/template_designer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _templateMap({
  Object? fields,
  Object? fieldsJson,
  bool includeFields = false,
  bool includeFieldsJson = false,
}) {
  final map = <String, dynamic>{
    'firestoreId': 'template-1',
    'jobName': 'Integrity template',
    'applicableAssetType': AssetType.base.name,
    'assignedAgencies': <String>['mechanical'],
    'isActive': true,
    'isDeprecated': false,
    'isDeleted': false,
    'version': 1,
    'createdAt': '2026-08-05T08:00:00.000Z',
    'updatedAt': '2026-08-05T08:00:00.000Z',
  };
  if (includeFields) map['fields'] = fields;
  if (includeFieldsJson) map['fieldsJson'] = fieldsJson;
  return map;
}

void main() {
  group('A-05 JobTemplate field integrity', () {
    test('canonical structured fields retain aliases and extensions', () {
      final template = JobTemplate.fromMap(
        _templateMap(
          includeFields: true,
          fields: <Map<String, dynamic>>[
            <String, dynamic>{
              'fieldId': 'pressure',
              'title': 'Pressure',
              'fieldType': 'numericWithUnit',
              'required': true,
              'validation': <String, dynamic>{'minimum': 0},
              'futureAuthority': <String, dynamic>{'retained': true},
            },
          ],
          includeFieldsJson: true,
          fieldsJson: '{malformed legacy fallback',
        ),
        'template-1',
      );

      final field = template.parsedFields.single;
      expect(field.key, 'pressure');
      expect(field.label, 'Pressure');
      expect(field.type, FieldType.number);
      expect(field.isRequired, isTrue);
      expect(field.validation, <String, dynamic>{'minimum': 0});
      expect(field.extensions['futureAuthority'], <String, dynamic>{
        'retained': true,
      });

      final persisted = template.toMap()['fields'] as List<dynamic>;
      expect(
        (persisted.single as Map<String, dynamic>)['futureAuthority'],
        <String, dynamic>{'retained': true},
      );
    });

    test(
      'malformed canonical fields never fall through to valid legacy JSON',
      () {
        expect(
          () => JobTemplate.fromMap(
            _templateMap(
              includeFields: true,
              fields: <Map<String, dynamic>>[
                <String, dynamic>{'type': 'text'},
              ],
              includeFieldsJson: true,
              fieldsJson: '[{"key":"legacy","type":"text"}]',
            ),
            'template-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );

    test(
      'legacy fieldsJson remains supported only when canonical fields are absent',
      () {
        final template = JobTemplate.fromMap(
          _templateMap(
            includeFieldsJson: true,
            fieldsJson: '[{"fieldKey":"legacy","type":"text"}]',
          ),
          'template-1',
        );

        expect(template.parsedFields.single.key, 'legacy');
        expect(jsonDecode(template.fieldsJson), isA<List<dynamic>>());
      },
    );

    test('malformed local fields remain preserved and expose repair state', () {
      final template =
          JobTemplate()
            ..jobName = 'Local template'
            ..applicableAssetType = AssetType.base
            ..fieldsJson = '[{"type":"text"}]'
            ..createdAt = DateTime.utc(2026, 8, 5)
            ..updatedAt = DateTime.utc(2026, 8, 5);

      expect(template.fieldsReadResult.isValid, isFalse);
      expect(template.fieldsJson, '[{"type":"text"}]');
      expect(
        () => template.parsedFields,
        throwsA(isA<PersistedDataFormatException>()),
      );
    });
  });

  group('A-05 Module Composer payload integrity', () {
    test('empty authoring draft is distinct from assignable snapshots', () {
      final authoringDraft = TemplateComposerDraft.fromAuthoringPayloads(
        jobTemplateSnapshotJson: jsonEncode(<String, dynamic>{
          'title': 'New governed template',
          'assetType': AssetType.base.name,
        }),
        moduleSnapshotsJson: '[]',
        fieldDefinitionsJson: '[]',
        checklistJson: '[]',
      );

      expect(authoringDraft.title, 'New governed template');
      expect(authoringDraft.modules, isEmpty);
      expect(
        () => TemplateComposerDraft.fromPayloads(
          jobTemplateSnapshotJson: jsonEncode(<String, dynamic>{
            'title': 'New governed template',
            'assetType': AssetType.base.name,
          }),
          moduleSnapshotsJson: '[]',
          fieldDefinitionsJson: '[]',
          checklistJson: '[]',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('each malformed payload root fails closed', () {
      final cases = <List<String>>[
        <String>['[]', '[]', '[]', '[]'],
        <String>['{}', '{}', '[]', '[]'],
        <String>['{}', '["not-an-object"]', '[]', '[]'],
        <String>['{}', '[]', '{"not":"a-list"}', '[]'],
        <String>['{}', '[]', '[]', '{malformed'],
      ];

      for (final payloads in cases) {
        expect(
          () => TemplateComposerDraft.fromPayloads(
            jobTemplateSnapshotJson: payloads[0],
            moduleSnapshotsJson: payloads[1],
            fieldDefinitionsJson: payloads[2],
            checklistJson: payloads[3],
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
      }
    });

    testWidgets(
      'malformed initial composer payload shows a blocking repair state',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith(
                (ref) => Stream<AppUser?>.value(_adminActor()),
              ),
            ],
            child: const MaterialApp(
              home: ModuleComposerScreen(
                initialJobTemplateJson: '{}',
                initialModuleSnapshotsJson: '["not-an-object"]',
                initialFieldDefinitionsJson: '[]',
                initialChecklistJson: '[]',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Saved composer payload needs repair'),
          findsOneWidget,
        );
        expect(find.text('Save to Publisher'), findsNothing);
      },
    );

    testWidgets('malformed local template blocks the field designer', (
      tester,
    ) async {
      final template =
          JobTemplate()
            ..jobName = 'Local template'
            ..applicableAssetType = AssetType.base
            ..fieldsJson = '[{"type":"text"}]'
            ..createdAt = DateTime.utc(2026, 8, 5)
            ..updatedAt = DateTime.utc(2026, 8, 5);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: TemplateDesignerScreen(template: template)),
        ),
      );

      expect(find.text('Saved template fields need repair'), findsOneWidget);
      expect(find.text('Add Field'), findsNothing);
    });

    test('saved-version decode precedes recovery-draft deletion', () {
      final source =
          File(
            'lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart',
          ).readAsStringSync();
      final decodeIndex = source.indexOf(
        'selectedDraft = TemplateComposerDraft.fromAuthoringPayloads',
      );
      final clearIndex = source.indexOf('await _clearRecoveryDraft()');

      expect(decodeIndex, greaterThanOrEqualTo(0));
      expect(clearIndex, greaterThan(decodeIndex));
    });
  });
}

AppUser _adminActor() {
  return AppUser(
    uid: 'composer-integrity-admin',
    name: 'Composer Integrity Admin',
    email: 'composer.integrity@example.com',
    roles: const <AppRole>[AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026, 8, 5),
  );
}
