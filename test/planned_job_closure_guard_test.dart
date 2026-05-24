import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/planned_job_closure_guard.dart';

JobModuleInstance _module({
  required String id,
  required bool requiredForClosure,
  required JobModuleStatus status,
  List<Map<String, dynamic>> fields = const <Map<String, dynamic>>[],
  List<FieldResponse> responses = const <FieldResponse>[],
  bool requiresFollowUp = false,
  String? pendingIssue,
  bool isDeleted = false,
}) {
  final now = DateTime.utc(2026, 5, 13, 1, 2, 3);
  return JobModuleInstance()
    ..firestoreId = id
    ..moduleTitle = 'Module $id'
    ..assetType = AssetType.base
    ..assetNumber = 1
    ..requiredForClosure = requiredForClosure
    ..status = status
    ..discipline = JobModuleDiscipline.mechanical
    ..safetyClass = JobModuleSafetyClass.normal
    ..fieldDefinitionsJson = jsonEncode(fields)
    ..responses = responses
    ..requiresFollowUp = requiresFollowUp
    ..pendingIssue = pendingIssue
    ..createdAt = now
    ..updatedAt = now
    ..isDeleted = isDeleted;
}

FieldResponse _response(String key, dynamic value) {
  return FieldResponse(
    key: key,
    fieldLabel: key,
    fieldType: FieldType.text,
    value: value,
  );
}

void main() {
  group('PlannedJobClosureGuard', () {
    test('allows completion when no active required-for-closure modules exist', () {
      final modules = [
        _module(
          id: 'optional-open',
          requiredForClosure: false,
          status: JobModuleStatus.notStarted,
        ),
        _module(
          id: 'deleted-required',
          requiredForClosure: true,
          status: JobModuleStatus.notStarted,
          isDeleted: true,
        ),
      ];

      expect(PlannedJobClosureGuard.collectIssues(modules), isEmpty);
      expect(() => PlannedJobClosureGuard.assertReady(modules), returnsNormally);
    });

    test('blocks open required modules', () {
      final issues = PlannedJobClosureGuard.collectIssues([
        _module(
          id: 'required-open',
          requiredForClosure: true,
          status: JobModuleStatus.inProgress,
        ),
      ]);

      expect(issues, hasLength(1));
      expect(issues.single.type, PlannedJobClosureIssueType.openRequiredModule);
      expect(issues.single.moduleFirestoreIds, contains('required-open'));
      expect(
        () => PlannedJobClosureGuard.assertReady([
          _module(
            id: 'required-open',
            requiredForClosure: true,
            status: JobModuleStatus.inProgress,
          ),
        ]),
        throwsA(isA<StateError>()),
      );
    });

    test('blocks submitted required modules until supervisor acceptance', () {
      final issues = PlannedJobClosureGuard.collectIssues([
        _module(
          id: 'submitted-required',
          requiredForClosure: true,
          status: JobModuleStatus.submitted,
        ),
      ]);

      expect(issues, hasLength(1));
      expect(issues.single.type, PlannedJobClosureIssueType.waitingAcceptance);
    });

    test('blocks accepted required module missing required evidence', () {
      final issues = PlannedJobClosureGuard.collectIssues([
        _module(
          id: 'accepted-missing-evidence',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
          fields: const [
            {
              'key': 'pressure_observed',
              'label': 'Pressure observed',
              'required': true,
              'type': 'number',
            },
          ],
        ),
      ]);

      expect(issues, hasLength(1));
      expect(
        issues.single.type,
        PlannedJobClosureIssueType.missingRequiredEvidence,
      );
    });

    test('allows accepted required module with required evidence', () {
      final modules = [
        _module(
          id: 'accepted-with-evidence',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
          fields: const [
            {
              'key': 'pressure_observed',
              'label': 'Pressure observed',
              'required': true,
              'type': 'number',
            },
          ],
          responses: [_response('pressure_observed', 125)],
        ),
      ];

      expect(PlannedJobClosureGuard.collectIssues(modules), isEmpty);
      expect(PlannedJobClosureGuard.isReady(modules), isTrue);
    });

    test('blocks required module with pending issue or follow-up', () {
      final issues = PlannedJobClosureGuard.collectIssues([
        _module(
          id: 'accepted-follow-up',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
          responses: [_response('observation', 'done')],
          requiresFollowUp: true,
        ),
      ]);

      expect(issues, hasLength(1));
      expect(
        issues.single.type,
        PlannedJobClosureIssueType.pendingIssueOrFollowUp,
      );
    });

    test('allows required not-applicable module without evidence', () {
      final modules = [
        _module(
          id: 'na-required',
          requiredForClosure: true,
          status: JobModuleStatus.notApplicable,
          fields: const [
            {
              'key': 'reading',
              'label': 'Reading',
              'required': true,
              'type': 'number',
            },
          ],
        ),
      ];

      expect(PlannedJobClosureGuard.collectIssues(modules), isEmpty);
    });
  });
}
