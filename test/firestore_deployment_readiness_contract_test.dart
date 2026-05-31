import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firestore deployment readiness contract', () {
    test(
      'firebase.json points deployment to the checked-in rules and indexes',
      () {
        final firebase = _readJson(
          _repoFile(
            'firebase.json',
            fallback: 'Other root files/firebase.json',
          ),
        );
        final firestore = Map<String, dynamic>.from(
          firebase['firestore'] as Map,
        );
        final functions = List<Map<String, dynamic>>.from(
          (firebase['functions'] as List).map(
            (entry) => Map<String, dynamic>.from(entry as Map),
          ),
        );

        expect(firestore['rules'], 'firestore.rules');
        expect(firestore['indexes'], 'firestore.indexes.json');
        expect(
          functions.any(
            (entry) =>
                entry['source'] == 'functions' &&
                entry['disallowLegacyRuntimeConfig'] == true,
          ),
          isTrue,
          reason:
              'Firebase deploy config should deploy the checked-in Functions '
              'source and avoid legacy runtime config.',
        );
      },
    );

    test('Firebase project and planned-job callable region stay aligned', () {
      final firebaseOptions =
          File('lib/firebase_options.dart').readAsStringSync();
      final completionService =
          File(
            'lib/features/planned_maintenance/services/planned_job_server_completion_service.dart',
          ).readAsStringSync();
      final functionIndex = File('functions/src/index.ts').readAsStringSync();

      expect(firebaseOptions, contains("projectId: 'crm3-baf-ops-b8638'"));
      expect(
        completionService,
        contains(
          "const plannedJobCompletionCallableName = 'completePlannedJobExecution';",
        ),
      );
      expect(
        completionService,
        contains("const plannedJobCompletionCallableRegion = 'asia-south1';"),
      );
      expect(functionIndex, contains('const CALLABLE_REGION = "asia-south1";'));
      expect(functionIndex, contains('region: CALLABLE_REGION'));
      expect(
        functionIndex,
        contains('export const completePlannedJobExecution'),
      );
      expect(
        functionIndex,
        isNot(contains('completePlannedJobExecutionAsiaSouth1')),
      );
      expect(
        functionIndex,
        isNot(contains('const CALLABLE_REGION = "us-central1"')),
      );
    });

    test('rules retain server-only closure and registry hardening guards', () {
      final rules =
          _repoFile(
            'firestore.rules',
            fallback: 'Other root files/firestore.rules',
          ).readAsStringSync();

      expect(rules, contains('function validJobExecutionComplete()'));
      expect(
        rules,
        contains('client SDKs may no longer complete JobExecution'),
      );
      expect(rules, contains('return false;'));
      expect(rules, contains('match /module_registry/{registryModuleId}'));
      expect(rules, contains('match /revisions/{revisionId}'));
      final exactRegistryVersionAdvance = RegExp(
        r"request\.resource\.data\.get\('version', -1\)\s*==\s*"
        r"resource\.data\.get\('version', -1\)\s*\+\s*1",
      );
      expect(
        exactRegistryVersionAdvance.allMatches(rules).length,
        greaterThanOrEqualTo(2),
        reason:
            'Registry family and revision updates must still advance '
            'exactly by one version using null-safe .get access.',
      );

      final latestPublishedRevisionAdvance = RegExp(
        r"request\.resource\.data\.get\('latestPublishedRevisionNumber', null\)"
        r"\s*==\s*resource\.data\.get\('latestPublishedRevisionNumber', null\)"
        r"\s*\+\s*1",
      );
      expect(
        latestPublishedRevisionAdvance.hasMatch(rules),
        isTrue,
        reason:
            'Registry family publish must still advance '
            'latestPublishedRevisionNumber by exactly one using null-safe '
            '.get access.',
      );
      expect(rules, contains('moduleRegistryFamilyPublishChangedFieldsOnly'));
      expect(rules, contains('moduleRegistryRevisionContentUnchanged'));
    });

    test(
      'critical composite indexes required by runtime and governance exist',
      () {
        final indexes = _readJson(
          _repoFile(
            'firestore.indexes.json',
            fallback: 'Other root files/firestore.indexes.json',
          ),
        );

        expect(
          _hasIndex(indexes, 'job_modules', const [
            'jobExecutionFirestoreId:ASCENDING',
            'isDeleted:ASCENDING',
            'displayOrder:ASCENDING',
            'moduleTitle:ASCENDING',
          ]),
          isTrue,
        );
        expect(
          _hasIndex(indexes, 'job_modules', const [
            'jobExecutionFirestoreId:ASCENDING',
            'isDeleted:ASCENDING',
            'discipline:ASCENDING',
            'displayOrder:ASCENDING',
            'moduleTitle:ASCENDING',
          ]),
          isTrue,
        );
        expect(
          _hasIndex(indexes, 'job_executions', const [
            'isDeleted:ASCENDING',
            'createdAt:DESCENDING',
          ]),
          isTrue,
        );
        expect(
          _hasIndex(indexes, 'template_packages', const [
            'isDeleted:ASCENDING',
            'title:ASCENDING',
          ]),
          isTrue,
        );
        expect(
          _hasIndex(indexes, 'template_versions', const [
            'packageFirestoreId:ASCENDING',
            'isDeleted:ASCENDING',
          ]),
          isTrue,
        );
        expect(
          _hasIndex(indexes, 'template_versions', const [
            'status:ASCENDING',
            'publishedAt:DESCENDING',
          ]),
          isTrue,
        );
      },
    );
  });
}

File _repoFile(String path, {String? fallback}) {
  final primary = File(path);
  if (primary.existsSync()) return primary;
  if (fallback != null) {
    final secondary = File(fallback);
    if (secondary.existsSync()) return secondary;
  }
  return primary;
}

Map<String, dynamic> _readJson(File file) {
  expect(file.existsSync(), isTrue, reason: '${file.path} must exist.');
  final decoded = jsonDecode(file.readAsStringSync());
  expect(decoded, isA<Map>());
  return Map<String, dynamic>.from(decoded as Map);
}

bool _hasIndex(
  Map<String, dynamic> root,
  String collectionGroup,
  List<String> fields,
) {
  final indexes = List<Map<String, dynamic>>.from(
    (root['indexes'] as List).map(
      (entry) => Map<String, dynamic>.from(entry as Map),
    ),
  );

  return indexes.any((index) {
    if (index['collectionGroup'] != collectionGroup) return false;
    final actualFields = List<String>.from(
      (index['fields'] as List).map((entry) {
        final field = Map<String, dynamic>.from(entry as Map);
        final mode = field['order'] ?? field['arrayConfig'] ?? '';
        return '${field['fieldPath']}:$mode';
      }),
    );
    return _sameStrings(actualFields, fields);
  });
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i += 1) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
