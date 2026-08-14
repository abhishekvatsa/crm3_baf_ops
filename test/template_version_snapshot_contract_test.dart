import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/template_version_snapshot_contract.dart';

String _json(Object value) => jsonEncode(value);

TemplateVersionSnapshotBundle _bundle({
  Map<String, dynamic>? job,
  List<Map<String, dynamic>>? modules,
  List<Map<String, dynamic>>? fields,
  List<Map<String, dynamic>>? checklist,
}) {
  final jobPayload = <String, dynamic>{
    'title': 'Snapshot contract fixture',
    'assetType': 'base',
    ...?job,
  };
  return TemplateVersionSnapshotBundle.fromRawJson(
    jobTemplateSnapshotJson: _json(jobPayload),
    moduleSnapshotsJson: _json(modules ?? const <Map<String, dynamic>>[]),
    fieldDefinitionsJson: _json(fields ?? const <Map<String, dynamic>>[]),
    checklistJson: _json(checklist ?? const <Map<String, dynamic>>[]),
  );
}

void main() {
  group('TemplateVersionSnapshotBundle validation', () {
    test('blocks closure-critical publish when closure review is missing', () {
      final bundle = _bundle(
        modules: const [
          {
            'moduleCode': 'HYD-CLAMP-01',
            'moduleTitle': 'Hydraulic clamp verification',
            'discipline': 'shared',
            'requiredForClosure': true,
            'metadata': {
              'ownerDisciplines': ['mechanical', 'instrumentation'],
            },
          },
        ],
        fields: const [
          {
            'key': 'clamp_pressure_observed',
            'label': 'Clamp pressure observed',
            'moduleCode': 'HYD-CLAMP-01',
          },
        ],
      );

      final result = bundle.validate();

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(
          'Closure-critical modules require Admin/SI closure review confirmation in composer metadata before publish.',
        ),
      );
    });

    test(
      'allows closure-critical publish when closure review is confirmed',
      () {
        final bundle = _bundle(
          job: const {
            'composer': {
              'closureReviewConfirmed': true,
              'closureReviewConfirmedByUid': 'admin-uid',
              'closureReviewConfirmedAt': '2026-05-12T10:00:00.000Z',
            },
          },
          modules: const [
            {
              'moduleCode': 'GAS-SSV-01',
              'moduleTitle': 'Gas safety shutoff valve verification',
              'discipline': 'shared',
              'requiredForClosure': true,
              'metadata': {
                'ownerDisciplines': [
                  'mechanical',
                  'instrumentation',
                  'electrical',
                ],
              },
            },
          ],
          fields: const [
            {
              'key': 'ssv_tight_shutoff_verified',
              'label': 'SSV tight shutoff verified',
              'moduleCode': 'GAS-SSV-01',
            },
          ],
        );

        final result = bundle.validate();

        expect(result.errors, isEmpty);
        expect(bundle.closureCriticalModuleCount, 1);
        expect(bundle.closureReviewConfirmed, isTrue);
        expect(bundle.closureReviewConfirmedByUid, 'admin-uid');
        expect(bundle.closureReviewConfirmedAt, DateTime.utc(2026, 5, 12, 10));
      },
    );

    test('malformed present closure review timestamp fails closed', () {
      final bundle = _bundle(
        job: const {
          'composer': {
            'closureReviewConfirmed': true,
            'closureReviewConfirmedAt': 'not-a-timestamp',
          },
        },
        modules: const [
          {
            'moduleCode': 'TIMESTAMP-01',
            'moduleTitle': 'Timestamp validation',
            'discipline': 'operations',
          },
        ],
        fields: const [
          {
            'key': 'timestamp_witness',
            'label': 'Timestamp witness',
            'moduleCode': 'TIMESTAMP-01',
          },
        ],
      );

      final result = bundle.validate();

      expect(result.isValid, isFalse);
      expect(result.errors.single, contains('closureReviewConfirmedAt'));
      expect(
        () => bundle.closureReviewConfirmedAt,
        throwsA(isA<TemplateVersionSnapshotException>()),
      );
    });

    test('absent optional closure review timestamp remains absent', () {
      final bundle = _bundle(
        job: const {
          'composer': {'closureReviewConfirmed': false},
        },
        modules: const [
          {
            'moduleCode': 'TIMESTAMP-02',
            'moduleTitle': 'Optional timestamp validation',
            'discipline': 'operations',
          },
        ],
        fields: const [
          {
            'key': 'optional_timestamp_witness',
            'label': 'Optional timestamp witness',
            'moduleCode': 'TIMESTAMP-02',
          },
        ],
      );

      expect(bundle.validate().errors, isEmpty);
      expect(bundle.closureReviewConfirmedAt, isNull);
    });

    test('malformed present scalar and map values fail closed', () {
      final wrongConfirmed = _bundle(
        job: const {
          'composer': {'closureReviewConfirmed': 'yes'},
        },
        modules: _minimalModules,
        fields: _minimalFields,
      );
      expect(
        wrongConfirmed.validate,
        throwsA(isA<TemplateVersionSnapshotException>()),
      );

      final wrongCount = _bundle(
        job: const {'closureCriticalCount': 1.0},
        modules: _minimalModules,
        fields: _minimalFields,
      );
      expect(
        wrongCount.validate,
        throwsA(isA<TemplateVersionSnapshotException>()),
      );

      final wrongComposer = _bundle(
        job: const {'composer': <Object>[]},
        modules: _minimalModules,
        fields: _minimalFields,
      );
      expect(
        wrongComposer.validate,
        throwsA(isA<TemplateVersionSnapshotException>()),
      );

      final wrongModuleCode = _bundle(
        modules: const [
          {'moduleCode': 7, 'moduleTitle': 'Wrong identity type'},
        ],
        fields: _minimalFields,
      );
      expect(
        wrongModuleCode.validate,
        throwsA(isA<TemplateVersionSnapshotException>()),
      );
    });

    test('malformed present owner lists fail instead of dropping rows', () {
      final bundle = _bundle(
        modules: const [
          {
            'moduleCode': 'OWNER-01',
            'moduleTitle': 'Owner validation',
            'discipline': 'shared',
            'metadata': {
              'ownerDisciplines': ['mechanical', 4],
            },
          },
        ],
        fields: _minimalFields,
      );

      expect(bundle.validate, throwsA(isA<TemplateVersionSnapshotException>()));
    });

    test('required job identity cannot be manufactured by consumers', () {
      final bundle = TemplateVersionSnapshotBundle.fromRawJson(
        jobTemplateSnapshotJson: _json(const <String, dynamic>{}),
        moduleSnapshotsJson: _json(_minimalModules),
        fieldDefinitionsJson: _json(_minimalFields),
        checklistJson: _json(const <Map<String, dynamic>>[]),
      );

      final result = bundle.validate(
        requireClosureReviewForClosureCritical: false,
      );

      expect(result.errors, contains('Job template title is missing.'));
      expect(result.errors, contains('Job template asset type is missing.'));
      expect(
        bundle.requireValidForAssignment,
        throwsA(isA<TemplateVersionSnapshotException>()),
      );
    });

    test('governed custom snapshots require valid hierarchy identity', () {
      const hierarchyReference = AssetHierarchyReference(
        assetClassId: 'annealing-car-class',
        assetClassCode: 'ANNEALING_CAR',
        assetClassName: 'Annealing car',
        nodeId: 'car-body',
        nodeVersion: 3,
        nodeName: 'Car body',
        hierarchyPath: <String>['Car body'],
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'mechanical',
        accountableRoleKeys: <String>['seniorMechanical'],
      );
      final valid = _bundle(
        job: <String, dynamic>{
          'assetType': 'governedCustom',
          'assetHierarchyRefJson': hierarchyReference.encode(),
        },
        modules: _minimalModules,
        fields: _minimalFields,
      );
      final missing = _bundle(
        job: const <String, dynamic>{'assetType': 'governedCustom'},
        modules: _minimalModules,
        fields: _minimalFields,
      );
      final malformed = _bundle(
        job: const <String, dynamic>{
          'assetType': 'governedCustom',
          'assetHierarchyRefJson': '{"schemaVersion":2}',
        },
        modules: _minimalModules,
        fields: _minimalFields,
      );

      expect(valid.validate().errors, isEmpty);
      expect(
        missing.validate().errors,
        contains(
          'Governed custom templates require an assetHierarchyRefJson reference.',
        ),
      );
      expect(
        malformed.validate().errors.single,
        startsWith('Governed asset hierarchy reference is invalid:'),
      );
    });

    test('malformed present hierarchy identity fails standard snapshots', () {
      final bundle = _bundle(
        job: const <String, dynamic>{
          'assetHierarchyRefJson': '{"schemaVersion":2}',
        },
        modules: _minimalModules,
        fields: _minimalFields,
      );

      expect(
        bundle.validate().errors.single,
        startsWith('Asset hierarchy reference is invalid:'),
      );
    });

    test(
      'assignment-consumed optional values reject coercion and unknown enums',
      () {
        final wrongOrder = _bundle(
          modules: const [
            {
              'moduleCode': 'STRICT-01',
              'moduleTitle': 'Strict assignment payload',
              'discipline': 'mechanical',
              'displayOrder': 1.0,
            },
          ],
          fields: const [
            {
              'key': 'strict_field',
              'label': 'Strict field',
              'moduleCode': 'STRICT-01',
            },
          ],
        );
        expect(
          wrongOrder.validate,
          throwsA(isA<TemplateVersionSnapshotException>()),
        );

        final wrongEnum = _bundle(
          modules: const [
            {
              'moduleCode': 'STRICT-02',
              'moduleTitle': 'Strict enum payload',
              'discipline': 'imaginary-lane',
            },
          ],
          fields: const [
            {
              'key': 'strict_enum_field',
              'label': 'Strict enum field',
              'moduleCode': 'STRICT-02',
            },
          ],
        );
        expect(
          wrongEnum.validate,
          throwsA(isA<TemplateVersionSnapshotException>()),
        );

        final wrongList = _bundle(
          job: const {
            'assignedAgencies': ['mechanical', 7],
          },
          modules: _minimalModules,
          fields: _minimalFields,
        );
        expect(
          wrongList.validate,
          throwsA(isA<TemplateVersionSnapshotException>()),
        );
      },
    );

    test('detects field definitions pointing to unknown module codes', () {
      final bundle = _bundle(
        modules: const [
          {
            'moduleCode': 'KNOWN-01',
            'moduleTitle': 'Known module',
            'discipline': 'mechanical',
          },
        ],
        fields: const [
          {
            'key': 'unknown_field',
            'label': 'Unknown field',
            'moduleCode': 'MISSING-01',
          },
        ],
      );

      final result = bundle.validate();

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(
          'Field unknown_field points to unknown moduleCode "MISSING-01".',
        ),
      );
    });

    test('detects duplicate field keys inside the same module', () {
      final bundle = _bundle(
        modules: const [
          {
            'moduleCode': 'DUP-01',
            'moduleTitle': 'Duplicate field module',
            'discipline': 'mechanical',
          },
        ],
        fields: const [
          {'key': 'reading', 'label': 'Reading 1', 'moduleCode': 'DUP-01'},
          {'key': 'reading', 'label': 'Reading 2', 'moduleCode': 'DUP-01'},
        ],
      );

      final result = bundle.validate();

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains('Duplicate field key "reading" inside module DUP-01.'),
      );
    });

    test(
      'assignment validation still permits closure-critical snapshots after publish',
      () {
        final bundle = _bundle(
          modules: const [
            {
              'moduleCode': 'ASSIGN-01',
              'moduleTitle': 'Assignable closure-critical module',
              'discipline': 'mechanical',
              'requiredForClosure': true,
            },
          ],
          fields: const [
            {
              'key': 'assignable_field',
              'label': 'Assignable field',
              'moduleCode': 'ASSIGN-01',
            },
          ],
        );

        expect(bundle.validate().isValid, isFalse);
        expect(() => bundle.requireValidForAssignment(), returnsNormally);
      },
    );
  });
}

const _minimalModules = <Map<String, dynamic>>[
  {
    'moduleCode': 'VALID-01',
    'moduleTitle': 'Valid module',
    'discipline': 'mechanical',
  },
];

const _minimalFields = <Map<String, dynamic>>[
  {'key': 'valid_field', 'label': 'Valid field', 'moduleCode': 'VALID-01'},
];
