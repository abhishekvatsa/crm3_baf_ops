import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R1.14 Firestore expression-budget contract', () {
    late String rules;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
    });

    test('authorization reads require a canonical security capsule', () {
      final authority = _blockStartingAt(
        rules,
        'function validApprovedUserAuthority(data)',
      );
      expect(authority, contains("data.keys().hasAll(['isApproved', 'roles'])"));
      expect(authority, contains("data.get('isApproved', false) == true"));
      expect(authority, contains("validUserRoleList(data.get('roles', null))"));
      expect(authority, isNot(contains('validUserDocumentShape')));
      expect(
        _blockStartingAt(rules, 'function validPendingUserCreate(userId)'),
        contains('validUserDocumentShape(request.resource.data)'),
      );
      expect(
        _blockStartingAt(rules, 'function validSelfUserUpdate(userId)'),
        contains('validUserDocumentShape(request.resource.data)'),
      );
    });

    test('job execution completion is rejected before expensive work validation', () {
      final update = _blockStartingAt(
        rules,
        'function validJobExecutionUpdate(docId)',
      );
      expect(update, contains("request.resource.data.get('isCompleted', false) !="));
      expect(update, contains('? false'));
      expect(update, contains('isJobExecutionAssigner()'));
    });

    test('maintenance has one update allow and a transition router', () {
      final matchBlock = _blockStartingAt(rules, 'match /maintenance_records/{docId}');
      expect(
        RegExp(r'allow update:').allMatches(matchBlock).length,
        1,
        reason: 'overlapping update allows consumed the emulator expression budget',
      );
      expect(matchBlock, contains('allow update: if validMaintenanceUpdate();'));

      final router = _blockStartingAt(rules, 'function validMaintenanceUpdate()');
      expect(router, contains('targetDeleted != sourceDeleted'));
      expect(router, contains('validMaintenanceSoftDeleteUpdate()'));
      expect(router, contains('targetResolved != sourceResolved'));
      expect(router, contains('validMaintenanceCloseUpdate()'));
      expect(router, contains('validMaintenanceReopenUpdate()'));
      expect(router, contains('validMaintenanceAdminEditUpdate()'));
    });

    test('template lifecycle evaluates only the selected status transition', () {
      final router = _blockStartingAt(
        rules,
        'function validTemplateVersionUpdateDelta()',
      );
      expect(router, contains("sourceStatus == 'draft'"));
      expect(router, contains("targetStatus == 'published'"));
      expect(router, contains('validDraftTemplateVersionArchiveDelta()'));
      expect(router, contains('validRetiredTemplateVersionArchiveDelta()'));
      expect(router, contains('validTemplateVersionRestoreDelta()'));
      expect(
        _blockStartingAt(rules, 'function validTemplateVersionUpdate(docId)'),
        isNot(contains('||')),
      );
    });

    test('job-module updates validate one user snapshot and one lifecycle branch', () {
      final entry = _blockStartingAt(rules, 'function validJobModuleUpdate(docId)');
      expect(entry, contains('validApprovedUserAuthority(userDoc().data)'));
      expect(entry, contains("userDoc().data.get('roles', [])"));

      final router = _blockStartingAt(
        rules,
        'function validJobModuleUpdatePayload(docId, changedKeys, roles)',
      );
      expect(router, contains("targetStatus == 'submitted'"));
      expect(router, contains("targetStatus == 'accepted'"));
      expect(router, contains("targetStatus == 'reopened'"));
      expect(router, contains("targetStatus == 'notApplicable'"));
      expect(router, contains('isOpenModuleStatus(targetStatus)'));
      expect(router, isNot(contains('||')));
    });

    test('directives snapshot roles and route one transition branch', () {
      expect(rules, contains('function directiveRolesCanTarget(roles, role)'));
      expect(rules, contains('function validDirectiveUpdateForRoles(roles)'));
      expect(rules, isNot(contains('function canDirectiveCreatorTarget(role)')));
      expect(rules, isNot(contains('function hasRequesterDirectiveTargetRole(role)')));

      final update = _blockStartingAt(
        rules,
        'function validDirectiveUpdate()',
      );
      expect(update, contains("userDoc().data.get('roles', [])"));
      expect(update, contains('validDirectiveUpdateForRoles'));
    });

    test('module registry uses status routers and one family read per publish', () {
      final family = _blockStartingAt(
        rules,
        'function validModuleRegistryFamilyGovernedUpdate(docId)',
      );
      expect(family, contains("request.resource.data.get('status', null) == 'active'"));
      expect(family, contains('validModuleRegistryFamilyPublishDelta(docId)'));
      expect(family, contains('validModuleRegistryFamilyRetireDelta()'));
      expect(family, isNot(contains('||')));

      final revision = _blockStartingAt(
        rules,
        'function validModuleRegistryRevisionUpdateDelta(',
      );
      expect(revision, contains("sourceStatus == 'draft'"));
      expect(revision, contains('validModuleRegistryRevisionPublishDelta('));
      expect(revision, contains('validModuleRegistryRevisionRetireDelta()'));

      final familyRead = _blockStartingAt(
        rules,
        'function moduleRegistryRevisionPublishMatchesFamily(',
      );
      expect(RegExp(r'getAfter\(').allMatches(familyRead).length, 1);
    });
  });
}

String _blockStartingAt(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  expect(markerIndex, isNot(-1), reason: 'Missing marker: $marker');

  final openBrace = source.indexOf('{', markerIndex + marker.length);
  expect(openBrace, isNot(-1), reason: 'Missing opening brace after $marker');

  var depth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaped = false;

  for (var i = openBrace; i < source.length; i++) {
    final char = source[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == '\\') {
      escaped = true;
      continue;
    }
    if (!inDoubleQuote && char == "'") {
      inSingleQuote = !inSingleQuote;
      continue;
    }
    if (!inSingleQuote && char == '"') {
      inDoubleQuote = !inDoubleQuote;
      continue;
    }
    if (inSingleQuote || inDoubleQuote) continue;

    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(markerIndex, i + 1);
    }
  }

  fail('Could not find closing brace for $marker');
}
