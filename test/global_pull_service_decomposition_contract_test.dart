import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('69A global pull service decomposition contract', () {
    test('global pull service remains the single coordinator-facing shell', () {
      final shell = _read(_shellFile);
      final allPullSource = _readAll(_globalPullFiles);

      expect(shell, contains('class GlobalPullService'));
      expect(shell, contains('bool _isPulling = false;'));
      expect(shell, contains('bool _hadRecordProcessingError = false;'));
      expect(shell, contains('DateTime? _maxFetchedRemoteUpdatedAt;'));
      expect(shell, contains('int lastInserted = 0;'));
      expect(shell, contains('int lastUpdated = 0;'));
      expect(shell, contains('int lastSkipped = 0;'));
      expect(shell, contains('int lastDeleted = 0;'));
      expect(shell, contains('int lastConflicted = 0;'));
      expect(
        shell,
        matches(
          RegExp(r'final\s+Set<String>\s+lastConflictKeys\s*=\s*<String>\{\};'),
        ),
      );
      expect(shell, contains('static const int _pageSize = 500;'));
      expect(
        shell,
        contains(
          'static const Duration _pullTokenSafetyMargin = Duration(minutes: 5);',
        ),
      );

      for (final partFile in _globalPullPartFiles) {
        expect(
          shell,
          contains("part '$partFile';"),
          reason:
              'global_pull_service.dart must include $partFile as a same-library part.',
        );
      }

      expect(
        _declarationCount(allPullSource, 'pullAndReconcile'),
        1,
        reason:
            'pullAndReconcile must have exactly one implementation, on GlobalPullService.',
      );
      expect(
        _declarationCount(allPullSource, '_nextGlobalPullToken'),
        1,
        reason: 'watermark calculation must have exactly one implementation.',
      );
      expect(
        _declarationCount(allPullSource, '_recordTombstoneApplyResult'),
        1,
        reason: 'tombstone apply-result accounting must stay centralized.',
      );
    });

    test('part files remain import-free same-library implementation slices', () {
      for (final entry in _partExtensionNames.entries) {
        final partFile = entry.key;
        final extensionName = entry.value;
        final path = 'lib/core/services/$partFile';
        final source = _read(path);

        expect(
          source.trimLeft(),
          startsWith("part of 'global_pull_service.dart';"),
          reason: '$path must remain a Dart part of global_pull_service.dart.',
        );
        expect(
          RegExp(r'^import\s+', multiLine: true).hasMatch(source),
          isFalse,
          reason:
              '$path must not declare imports; imports belong in global_pull_service.dart.',
        );
        expect(
          source,
          contains('extension $extensionName on GlobalPullService'),
          reason:
              '$path should expose moved implementation through its expected private extension.',
        );
        expect(
          RegExp(r'^class\s+', multiLine: true).hasMatch(source),
          isFalse,
          reason:
              '$path must not introduce new classes in the move-only slice.',
        );
        expect(
          RegExp(r'^mixin\s+', multiLine: true).hasMatch(source),
          isFalse,
          reason: '$path must not introduce mixins in the move-only slice.',
        );
        expect(
          source,
          isNot(contains('// FILE:')),
          reason: '$path must not introduce file-banner noise.',
        );
      }
    });

    test('part-file extraction has no malformed fragments', () {
      final allPullSource = _readAll(_globalPullFiles);
      final partSource = _readAll(
        _globalPullPartFiles.map((file) => 'lib/core/services/$file').toList(),
      );

      expect(
        RegExp(r'^\)\s*async\s*\{', multiLine: true).hasMatch(allPullSource),
        isFalse,
        reason:
            'No part file may contain an orphaned method tail such as ") async {".',
      );
      expect(
        RegExp(r'^\)\s*\{', multiLine: true).hasMatch(allPullSource),
        isFalse,
        reason:
            'No part file may contain an orphaned method tail such as ") {".',
      );
      expect(
        RegExp(
          r'^\s*pullAndReconcile\s*\(',
          multiLine: true,
        ).hasMatch(partSource),
        isFalse,
        reason:
            'pullAndReconcile must not be reintroduced in a part-file extension.',
      );
    });

    test('contract block extractor skips named-parameter braces', () {
      const source = '''
void sample(String id, {String? reason}) {
  final bodyValue = reason ?? id;
}
''';

      final block = _blockStartingAt(source, 'void sample(');
      expect(block, contains('final bodyValue'));
    });

    test('critical helper bodies were not truncated during extraction', () {
      final watermark = _read(
        'lib/core/services/global_pull_service.watermark.dart',
      );
      final conflicts = _read(
        'lib/core/services/global_pull_service.conflicts.dart',
      );

      final tokenBlock = _blockStartingAt(
        watermark,
        'DateTime? _nextGlobalPullToken({DateTime? previousToken})',
      );
      expect(tokenBlock, contains('_maxFetchedRemoteUpdatedAt'));
      expect(tokenBlock, contains('GlobalPullService._pullTokenSafetyMargin'));
      expect(tokenBlock, contains('candidate.isBefore(previousToken)'));

      final auditBlock = _blockStartingAt(conflicts, 'void _logConflictAudit(');
      expect(auditBlock, contains('AuditEvent('));
      expect(auditBlock, contains('_auditRepo.log('));
      expect(auditBlock, contains('AuditSeverity.high'));
    });

    test('moved pull methods have exactly one owner file', () {
      final allPullSource = _readAll(_globalPullFiles);

      for (final entry in _expectedMethodOwners.entries) {
        final methodName = entry.key;
        final ownerFile = entry.value;
        final ownerSource = _read(ownerFile);

        expect(
          _declarationCount(allPullSource, methodName),
          1,
          reason: '$methodName must have exactly one declaration.',
        );
        expect(
          _containsDeclaration(ownerSource, methodName),
          isTrue,
          reason: '$methodName must live in $ownerFile.',
        );
      }
    });

    test('global pull order remains frozen', () {
      final shell = _read(_shellFile);
      final pullBlock = _blockStartingAt(
        shell,
        'Future<void> pullAndReconcile()',
      );

      _expectOrder(pullBlock, const [
        'if (_isPulling)',
        '_isPulling = true;',
        'lastInserted = 0;',
        'lastUpdated = 0;',
        'lastSkipped = 0;',
        'lastDeleted = 0;',
        'lastConflicted = 0;',
        'lastConflictKeys.clear();',
        '_hadRecordProcessingError = false;',
        '_maxFetchedRemoteUpdatedAt = null;',
        "prefs.getString('last_global_pull')",
        'await _pullKnowledgeBase(lastSync);',
        'await _pullMaintenance(lastSync);',
        'await _pullPlanned(lastSync);',
        'await _pullDirectives(lastSync);',
        'await _pullAbnormalities(lastSync);',
        'if (_hadRecordProcessingError)',
        '_nextGlobalPullToken(previousToken: lastSync)',
        'await prefs.setString(',
        "'last_global_pull'",
        '_isPulling = false;',
      ]);
    });

    test(
      'planned, template-governance, and abnormality sub-orders stay frozen',
      () {
        final planned = _read(
          'lib/core/services/global_pull_service.planned.dart',
        );
        final plannedBlock = _blockStartingAt(
          planned,
          'Future<void> _pullPlanned(DateTime? lastSync)',
        );
        _expectOrder(plannedBlock, const [
          'await _pullTemplateGovernance(lastSync);',
          'await _pullTemplates(lastSync);',
          'await _pullExecutions(lastSync);',
          'await _pullJobDiaryEntries(lastSync);',
          'await _pullJobModules(lastSync);',
        ]);

        final templateGovernance = _read(
          'lib/core/services/global_pull_service.template_governance.dart',
        );
        final templateGovernanceBlock = _blockStartingAt(
          templateGovernance,
          'Future<void> _pullTemplateGovernance(DateTime? lastSync)',
        );
        _expectOrder(templateGovernanceBlock, const [
          'await _pullTemplatePackages(lastSync);',
          'await _pullTemplateVersions(lastSync);',
          'await _pullTemplatePublishAudits(lastSync);',
        ]);

        final abnormalities = _read(
          'lib/core/services/global_pull_service.abnormalities.dart',
        );
        final abnormalitiesBlock = _blockStartingAt(
          abnormalities,
          'Future<void> _pullAbnormalities(DateTime? lastSync)',
        );
        _expectOrder(abnormalitiesBlock, const [
          'await _pullAbnormalityTypes(lastSync);',
          'await _pullChargeAbnormalities(lastSync);',
        ]);
      },
    );

    test('tombstone and conflict helpers stay centralized', () {
      final conflicts = _read(
        'lib/core/services/global_pull_service.conflicts.dart',
      );
      final nonConflictParts = _readAll(
        _globalPullPartFiles
            .where((file) => file != 'global_pull_service.conflicts.dart')
            .map((file) => 'lib/core/services/$file')
            .toList(),
      );

      for (final helper in _sharedConflictHelpers) {
        expect(
          conflicts,
          contains(helper),
          reason: '$helper belongs in the conflicts part.',
        );
      }
      expect(
        nonConflictParts,
        isNot(contains('void _recordTombstoneApplyResult(')),
      );
      expect(nonConflictParts, isNot(contains('void _logPullConflict(')));
      expect(nonConflictParts, isNot(contains('void _logConflictAudit(')));
    });

    test('watermark helpers stay centralized', () {
      final watermark = _read(
        'lib/core/services/global_pull_service.watermark.dart',
      );
      final nonWatermarkParts = _readAll(
        _globalPullPartFiles
            .where((file) => file != 'global_pull_service.watermark.dart')
            .map((file) => 'lib/core/services/$file')
            .toList(),
      );

      for (final helper in _watermarkHelpers) {
        expect(
          watermark,
          contains(helper),
          reason: '$helper belongs in the watermark part.',
        );
      }
      expect(
        nonWatermarkParts,
        isNot(contains('DateTime? _nextGlobalPullToken(')),
      );
      expect(
        nonWatermarkParts,
        isNot(contains('void _observeFetchedRemoteRecords(')),
      );
      expect(
        nonWatermarkParts,
        isNot(contains('void _observeFetchedRemoteUpdatedAt(')),
      );
      expect(nonWatermarkParts, isNot(contains('DateTime? _readUpdatedAt(')));
    });

    test('shell imports and pull files remain data-layer only', () {
      final allPullSource = _readAll(_globalPullFiles);
      final shell = _read(_shellFile);

      for (final forbidden in _forbiddenUiFragments) {
        expect(
          allPullSource,
          isNot(contains(forbidden)),
          reason: 'Global pull must remain a data/domain service layer.',
        );
      }

      expect(
        shell,
        contains('final pullServiceProvider = Provider<GlobalPullService>'),
      );
      expect(
        allPullSource,
        isNot(contains('writeTxn')),
        reason:
            'The move-only pull split must not introduce direct Isar write transactions.',
      );
    });

    test('global pull token and failure logging contracts remain anchored', () {
      final shell = _read(_shellFile);

      expect(_occurrenceCount(shell, "'last_global_pull'"), 2);
      _expectOrder(shell, const [
        "prefs.getString('last_global_pull')",
        '_nextGlobalPullToken(previousToken: lastSync)',
        'await prefs.setString(',
        "'last_global_pull'",
      ]);

      expect(shell, contains("reason: 'global_delta_sync_failed'"));
      expect(
        shell,
        contains(
          "context: const {'app_area': 'sync', 'sync_phase': 'global_pull'}",
        ),
      );
    });

    test('static constants are qualified from extension slices', () {
      final partSource = _stripCommentsAndStrings(
        _readAll(
          _globalPullPartFiles
              .map((file) => 'lib/core/services/$file')
              .toList(),
        ),
      );

      final withoutQualifiedStaticAccess = partSource
          .replaceAll('GlobalPullService._pageSize', '')
          .replaceAll('GlobalPullService._pullTokenSafetyMargin', '');

      expect(withoutQualifiedStaticAccess, isNot(contains('_pageSize')));
      expect(
        withoutQualifiedStaticAccess,
        isNot(contains('_pullTokenSafetyMargin')),
      );
      expect(partSource, contains('GlobalPullService._pageSize'));
      expect(partSource, contains('GlobalPullService._pullTokenSafetyMargin'));
    });

    test('part files do not rely on analyzer-noisy this qualifiers', () {
      final partSource = _readAll(
        _globalPullPartFiles.map((file) => 'lib/core/services/$file').toList(),
      );

      expect(
        RegExp(r'\bthis\.').hasMatch(partSource),
        isFalse,
        reason:
            'The same-library part split must stay analyzer-clean; explicit this. qualifiers trigger unnecessary_this across extension slices.',
      );
    });

    test('entity methods live in semantically named part files', () {
      final maintenance = _read(
        'lib/core/services/global_pull_service.maintenance.dart',
      );
      final templateGovernance = _read(
        'lib/core/services/global_pull_service.template_governance.dart',
      );
      final planned = _read(
        'lib/core/services/global_pull_service.planned.dart',
      );
      final jobDiary = _read(
        'lib/core/services/global_pull_service.job_diary.dart',
      );
      final jobModules = _read(
        'lib/core/services/global_pull_service.job_modules.dart',
      );
      final directives = _read(
        'lib/core/services/global_pull_service.directives.dart',
      );
      final abnormalities = _read(
        'lib/core/services/global_pull_service.abnormalities.dart',
      );
      final knowledgeBase = _read(
        'lib/core/services/global_pull_service.knowledge_base.dart',
      );

      expect(maintenance, contains('Future<void> _pullMaintenance('));
      expect(
        templateGovernance,
        contains('Future<void> _pullTemplateGovernance('),
      );
      expect(planned, contains('Future<void> _pullPlanned('));
      expect(planned, contains('Future<void> _pullTemplates('));
      expect(planned, contains('Future<void> _pullExecutions('));
      expect(jobDiary, contains('Future<void> _pullJobDiaryEntries('));
      expect(jobModules, contains('Future<void> _pullJobModules('));
      expect(directives, contains('Future<void> _pullDirectives('));
      expect(abnormalities, contains('Future<void> _pullAbnormalities('));
      expect(abnormalities, contains('Future<void> _pullAbnormalityTypes('));
      expect(abnormalities, contains('Future<void> _pullChargeAbnormalities('));
      expect(knowledgeBase, contains('Future<void> _pullKnowledgeBase('));

      expect(jobModules, isNot(contains('Future<void> _pullJobDiaryEntries(')));
      expect(directives, isNot(contains('Future<void> _pullAbnormalities(')));
      expect(abnormalities, isNot(contains('Future<void> _pullDirectives(')));
    });

    test('provider and public pull API remain anchored in the shell', () {
      final shell = _read(_shellFile);
      final partSource = _readAll(
        _globalPullPartFiles.map((file) => 'lib/core/services/$file').toList(),
      );

      expect(
        shell,
        contains('final pullServiceProvider = Provider<GlobalPullService>'),
      );
      expect(shell, contains('Future<void> pullAndReconcile()'));
      expect(partSource, isNot(contains('pullServiceProvider')));
      expect(partSource, isNot(contains('Future<void> pullAndReconcile()')));
    });

    test(
      'first global pull slice does not introduce deferred adapter architecture',
      () {
        final allPullSource = _readAll(_globalPullFiles);
        final partSource = _readAll(
          _globalPullPartFiles
              .map((file) => 'lib/core/services/$file')
              .toList(),
        );

        expect(allPullSource, isNot(contains('class GlobalPullRunContext')));
        expect(allPullSource, isNot(contains('mixin PullEntityMixin')));
        expect(allPullSource, isNot(contains('class MaintenancePuller')));
        expect(allPullSource, isNot(contains('class JobModulePuller')));
        expect(allPullSource, isNot(contains('class PullParticipant')));
        expect(partSource, isNot(contains('SyncService')));
        expect(partSource, isNot(contains('SyncCoordinator')));
      },
    );
  });
}

const _shellFile = 'lib/core/services/global_pull_service.dart';

const _partExtensionNames = <String, String>{
  'global_pull_service.watermark.dart': '_GlobalPullWatermark',
  'global_pull_service.conflicts.dart': '_GlobalPullConflicts',
  'global_pull_service.maintenance.dart': '_GlobalPullMaintenance',
  'global_pull_service.template_governance.dart':
      '_GlobalPullTemplateGovernance',
  'global_pull_service.planned.dart': '_GlobalPullPlanned',
  'global_pull_service.job_diary.dart': '_GlobalPullJobDiary',
  'global_pull_service.job_modules.dart': '_GlobalPullJobModules',
  'global_pull_service.directives.dart': '_GlobalPullDirectives',
  'global_pull_service.abnormalities.dart': '_GlobalPullAbnormalities',
  'global_pull_service.knowledge_base.dart': '_GlobalPullKnowledgeBase',
};

const _globalPullPartFiles = <String>[
  'global_pull_service.watermark.dart',
  'global_pull_service.conflicts.dart',
  'global_pull_service.maintenance.dart',
  'global_pull_service.template_governance.dart',
  'global_pull_service.planned.dart',
  'global_pull_service.job_diary.dart',
  'global_pull_service.job_modules.dart',
  'global_pull_service.directives.dart',
  'global_pull_service.abnormalities.dart',
  'global_pull_service.knowledge_base.dart',
];

const _globalPullFiles = <String>[
  _shellFile,
  'lib/core/services/global_pull_service.watermark.dart',
  'lib/core/services/global_pull_service.conflicts.dart',
  'lib/core/services/global_pull_service.maintenance.dart',
  'lib/core/services/global_pull_service.template_governance.dart',
  'lib/core/services/global_pull_service.planned.dart',
  'lib/core/services/global_pull_service.job_diary.dart',
  'lib/core/services/global_pull_service.job_modules.dart',
  'lib/core/services/global_pull_service.directives.dart',
  'lib/core/services/global_pull_service.abnormalities.dart',
  'lib/core/services/global_pull_service.knowledge_base.dart',
];

const _expectedMethodOwners = <String, String>{
  'pullAndReconcile': _shellFile,
  '_nextGlobalPullToken':
      'lib/core/services/global_pull_service.watermark.dart',
  '_observeFetchedRemoteRecords':
      'lib/core/services/global_pull_service.watermark.dart',
  '_observeFetchedRemoteUpdatedAt':
      'lib/core/services/global_pull_service.watermark.dart',
  '_readUpdatedAt': 'lib/core/services/global_pull_service.watermark.dart',
  '_conflictKey': 'lib/core/services/global_pull_service.conflicts.dart',
  '_isRemoteNewer': 'lib/core/services/global_pull_service.conflicts.dart',
  '_jsonSafeValue': 'lib/core/services/global_pull_service.conflicts.dart',
  '_safeAuditMap': 'lib/core/services/global_pull_service.conflicts.dart',
  '_auditEntityId': 'lib/core/services/global_pull_service.conflicts.dart',
  '_logConflictAudit': 'lib/core/services/global_pull_service.conflicts.dart',
  '_logPullConflict': 'lib/core/services/global_pull_service.conflicts.dart',
  '_recordTombstoneApplyResult':
      'lib/core/services/global_pull_service.conflicts.dart',
  '_pullMaintenance': 'lib/core/services/global_pull_service.maintenance.dart',
  '_pullTemplateGovernance':
      'lib/core/services/global_pull_service.template_governance.dart',
  '_pullTemplatePackages':
      'lib/core/services/global_pull_service.template_governance.dart',
  '_pullTemplateVersions':
      'lib/core/services/global_pull_service.template_governance.dart',
  '_pullTemplatePublishAudits':
      'lib/core/services/global_pull_service.template_governance.dart',
  '_pullPlanned': 'lib/core/services/global_pull_service.planned.dart',
  '_pullTemplates': 'lib/core/services/global_pull_service.planned.dart',
  '_pullExecutions': 'lib/core/services/global_pull_service.planned.dart',
  '_pullJobDiaryEntries':
      'lib/core/services/global_pull_service.job_diary.dart',
  '_pullJobModules': 'lib/core/services/global_pull_service.job_modules.dart',
  '_pullDirectives': 'lib/core/services/global_pull_service.directives.dart',
  '_pullAbnormalities':
      'lib/core/services/global_pull_service.abnormalities.dart',
  '_pullAbnormalityTypes':
      'lib/core/services/global_pull_service.abnormalities.dart',
  '_pullChargeAbnormalities':
      'lib/core/services/global_pull_service.abnormalities.dart',
  '_pullKnowledgeBase':
      'lib/core/services/global_pull_service.knowledge_base.dart',
};

const _sharedConflictHelpers = <String>[
  '_conflictKey',
  '_isRemoteNewer',
  '_jsonSafeValue',
  '_safeAuditMap',
  '_auditEntityId',
  '_logConflictAudit',
  '_logPullConflict',
  '_recordTombstoneApplyResult',
];

const _watermarkHelpers = <String>[
  '_nextGlobalPullToken',
  '_observeFetchedRemoteRecords',
  '_observeFetchedRemoteUpdatedAt',
  '_readUpdatedAt',
];

const _forbiddenUiFragments = <String>[
  "package:flutter/material.dart",
  'BuildContext',
  'Widget',
  'ScaffoldMessenger',
  'BafColors',
  'BafSpacing',
  'BafDesign',
];

String _read(String path) => File(path).readAsStringSync();

String _readAll(List<String> paths) => paths.map(_read).join('\n\n');

int _occurrenceCount(String source, String needle) =>
    needle.isEmpty ? 0 : source.split(needle).length - 1;

int _declarationCount(String source, String methodName) =>
    _declarationRegExp(methodName).allMatches(source).length;

bool _containsDeclaration(String source, String methodName) =>
    _declarationRegExp(methodName).hasMatch(source);

RegExp _declarationRegExp(String methodName) => RegExp(
  r'^\s*'
  r'(?:Future(?:<[^\n]+>)?|Map<[^\n]+>|Object\?|DateTime\?|void|bool|String|int)'
  r'\s+'
  '${RegExp.escape(methodName)}'
  r'(?:<[^>]+>)?\s*\(',
  multiLine: true,
);

void _expectOrder(String source, List<String> fragments) {
  var cursor = -1;
  for (final fragment in fragments) {
    final index = source.indexOf(fragment, cursor + 1);
    expect(
      index,
      greaterThan(cursor),
      reason: 'Expected after previous fragment: $fragment',
    );
    cursor = index;
  }
}

String _blockStartingAt(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  expect(markerIndex, isNot(-1), reason: 'Missing marker: $marker');

  final stripped = _stripCommentsAndStrings(source);
  final parameterStart = stripped.indexOf('(', markerIndex);
  expect(
    parameterStart,
    isNot(-1),
    reason: 'Missing parameter list after marker: $marker',
  );

  var parameterDepth = 0;
  var parameterEnd = -1;
  for (var i = parameterStart; i < stripped.length; i++) {
    final char = stripped.codeUnitAt(i);
    if (char == 0x28) {
      parameterDepth++;
    } else if (char == 0x29) {
      parameterDepth--;
      if (parameterDepth == 0) {
        parameterEnd = i;
        break;
      }
    }
  }

  expect(
    parameterEnd,
    isNot(-1),
    reason: 'Could not find closing parameter parenthesis for marker: $marker',
  );

  final openBrace = stripped.indexOf('{', parameterEnd + 1);
  expect(
    openBrace,
    isNot(-1),
    reason: 'Missing method-body opening brace after $marker',
  );

  var depth = 0;
  for (var i = openBrace; i < stripped.length; i++) {
    final char = stripped.codeUnitAt(i);
    if (char == 0x7B) {
      depth++;
    } else if (char == 0x7D) {
      depth--;
      if (depth == 0) {
        return source.substring(markerIndex, i + 1);
      }
    }
  }

  fail('Could not find closing brace for marker: $marker');
}

String _stripCommentsAndStrings(String source) {
  final buffer = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inTripleSingleQuote = false;
  var inTripleDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;

  for (var i = 0; i < source.length; i++) {
    final char = source.codeUnitAt(i);
    final next = i + 1 < source.length ? source.codeUnitAt(i + 1) : -1;
    final next2 = i + 2 < source.length ? source.codeUnitAt(i + 2) : -1;
    final prev = i > 0 ? source.codeUnitAt(i - 1) : -1;

    if (inLineComment) {
      if (char == 0x0A || char == 0x0D) {
        inLineComment = false;
        buffer.writeCharCode(char);
      } else {
        buffer.write(' ');
      }
      continue;
    }
    if (inBlockComment) {
      if (char == 0x2A && next == 0x2F) {
        inBlockComment = false;
        buffer.write('  ');
        i++;
      } else {
        buffer.write(
          char == 0x0A || char == 0x0D ? String.fromCharCode(char) : ' ',
        );
      }
      continue;
    }
    if (inTripleSingleQuote) {
      if (char == 0x27 && next == 0x27 && next2 == 0x27) {
        inTripleSingleQuote = false;
        buffer.write('   ');
        i += 2;
      } else {
        buffer.write(
          char == 0x0A || char == 0x0D ? String.fromCharCode(char) : ' ',
        );
      }
      continue;
    }
    if (inTripleDoubleQuote) {
      if (char == 0x22 && next == 0x22 && next2 == 0x22) {
        inTripleDoubleQuote = false;
        buffer.write('   ');
        i += 2;
      } else {
        buffer.write(
          char == 0x0A || char == 0x0D ? String.fromCharCode(char) : ' ',
        );
      }
      continue;
    }
    if (inSingleQuote) {
      if (char == 0x27 && prev != 0x5C) {
        inSingleQuote = false;
      }
      buffer.write(' ');
      continue;
    }
    if (inDoubleQuote) {
      if (char == 0x22 && prev != 0x5C) {
        inDoubleQuote = false;
      }
      buffer.write(' ');
      continue;
    }

    if (char == 0x2F && next == 0x2F) {
      inLineComment = true;
      buffer.write('  ');
      i++;
      continue;
    }
    if (char == 0x2F && next == 0x2A) {
      inBlockComment = true;
      buffer.write('  ');
      i++;
      continue;
    }
    if (char == 0x27 && next == 0x27 && next2 == 0x27) {
      inTripleSingleQuote = true;
      buffer.write('   ');
      i += 2;
      continue;
    }
    if (char == 0x22 && next == 0x22 && next2 == 0x22) {
      inTripleDoubleQuote = true;
      buffer.write('   ');
      i += 2;
      continue;
    }
    if (char == 0x27) {
      inSingleQuote = true;
      buffer.write(' ');
      continue;
    }
    if (char == 0x22) {
      inDoubleQuote = true;
      buffer.write(' ');
      continue;
    }

    buffer.writeCharCode(char);
  }

  return buffer.toString();
}
