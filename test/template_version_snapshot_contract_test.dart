import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/template_version_snapshot_contract.dart';

String _json(Object value) => jsonEncode(value);

TemplateVersionSnapshotBundle _bundle({
  Map<String, dynamic>? job,
  List<Map<String, dynamic>>? modules,
  List<Map<String, dynamic>>? fields,
  List<Map<String, dynamic>>? checklist,
}) {
  return TemplateVersionSnapshotBundle.fromRawJson(
    jobTemplateSnapshotJson: _json(job ?? const <String, dynamic>{}),
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

    test('allows closure-critical publish when closure review is confirmed', () {
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
    });

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
        contains('Field unknown_field points to unknown moduleCode "MISSING-01".'),
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
          {
            'key': 'reading',
            'label': 'Reading 1',
            'moduleCode': 'DUP-01',
          },
          {
            'key': 'reading',
            'label': 'Reading 2',
            'moduleCode': 'DUP-01',
          },
        ],
      );

      final result = bundle.validate();

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains('Duplicate field key "reading" inside module DUP-01.'),
      );
    });

    test('assignment validation still permits closure-critical snapshots after publish', () {
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
    });
  });
}
