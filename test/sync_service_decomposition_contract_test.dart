import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('68F sync service decomposition contract', () {
    test('sync service remains the single coordinator-facing shell', () {
      final shell = _read(_shellFile);
      final allSyncSource = _readAll(_syncServiceFiles);

      expect(shell, contains('class SyncService'));
      expect(shell, contains('bool _isSyncing = false;'));
      expect(shell, contains('int lastSuccessCount = 0;'));
      expect(shell, contains('int lastFailureCount = 0;'));
      expect(shell, contains('int lastConflictCount = 0;'));
      expect(shell, contains('int lastFailureDetailOverflowCount = 0;'));
      expect(shell, contains('static const int _maxFailureDetails = 12;'));
      expect(
        shell,
        matches(
          RegExp(r'final\s+Set<String>\s+lastConflictKeys\s*=\s*<String>\{\};'),
        ),
      );
      expect(
        shell,
        matches(
          RegExp(
            r'final\s+List<SyncFailureDetail>\s+lastFailureDetails\s*=\s*<SyncFailureDetail>\[\];',
          ),
        ),
      );

      for (final partFile in _syncServicePartFiles) {
        expect(
          shell,
          contains("part '$partFile';"),
          reason:
              'sync_service.dart must include $partFile as a same-library part.',
        );
      }

      expect(
        _declarationCount(allSyncSource, 'syncAll'),
        1,
        reason: 'syncAll must have exactly one implementation, on SyncService.',
      );
      expect(
        _declarationCount(allSyncSource, '_retry'),
        1,
        reason: '_retry must stay centralized in push infrastructure.',
      );
      expect(
        _declarationCount(allSyncSource, 'countPendingLocalWrites'),
        1,
        reason: 'pending-count aggregation must stay on SyncService.',
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
          startsWith("part of 'sync_service.dart';"),
          reason: '$path must remain a Dart part of sync_service.dart.',
        );
        expect(
          RegExp(r'^import\s+', multiLine: true).hasMatch(source),
          isFalse,
          reason:
              '$path must not declare imports; imports belong in sync_service.dart.',
        );
        expect(
          source,
          contains('extension $extensionName on SyncService'),
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
      }
    });

    test('part-file extraction has no malformed fragments or banner noise', () {
      final allSyncSource = _readAll(_syncServiceFiles);
      final partSource = _readAll(
        _syncServicePartFiles.map((file) => 'lib/core/services/$file').toList(),
      );

      expect(
        RegExp(r'^// FILE:', multiLine: true).hasMatch(allSyncSource),
        isFalse,
        reason: '68F sync files must not introduce // FILE banner noise.',
      );
      expect(
        RegExp(r'^///', multiLine: true).hasMatch(allSyncSource),
        isFalse,
        reason: '68F sync files must not introduce one-off doc-comment noise.',
      );
      expect(
        RegExp(r'^\)\s*async\s*\{', multiLine: true).hasMatch(allSyncSource),
        isFalse,
        reason:
            'No part file may contain an orphaned method tail such as ") async {".',
      );
      expect(
        RegExp(r'^\s*syncAll\s*\(', multiLine: true).hasMatch(partSource),
        isFalse,
        reason: 'syncAll must not be reintroduced in a part-file extension.',
      );
    });

    test('moved sync methods have exactly one owner file', () {
      final allSyncSource = _readAll(_syncServiceFiles);

      for (final entry in _expectedMethodOwners.entries) {
        final methodName = entry.key;
        final ownerFile = entry.value;
        final ownerSource = _read(ownerFile);

        expect(
          _declarationCount(allSyncSource, methodName),
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

    test('retry and shared push helpers stay centralized', () {
      final shell = _read(_shellFile);
      final push = _read(
        'lib/core/services/sync_service.push_infrastructure.dart',
      );
      final nonPushParts = _readAll(
        _syncServicePartFiles
            .where((file) => file != 'sync_service.push_infrastructure.dart')
            .map((file) => 'lib/core/services/$file')
            .toList(),
      );

      expect(shell, isNot(contains('Future<void> _retry(')));
      expect(push, contains('Future<void> _retry('));
      expect(nonPushParts, isNot(contains('Future<void> _retry(')));

      for (final helper in _sharedPushInfrastructureHelpers) {
        expect(
          push,
          contains(helper),
          reason:
              '$helper belongs in shared push infrastructure, not a domain part.',
        );
      }
    });

    test('part files do not rely on analyzer-noisy this qualifiers', () {
      final partSource = _readAll(
        _syncServicePartFiles.map((file) => 'lib/core/services/$file').toList(),
      );
      final shell = _read(_shellFile);

      expect(
        RegExp(r'\bthis\.').hasMatch(partSource),
        isFalse,
        reason:
            'The same-library part split must stay analyzer-clean; explicit this. qualifiers trigger unnecessary_this across extension slices.',
      );
      expect(
        RegExp(r'\bthis\._').hasMatch(shell),
        isFalse,
        reason:
            'The shell may use constructor initializing formals, but sync method calls should not use analyzer-noisy this._ qualifiers.',
      );
    });

    test('syncAll preserves the full baseline push sequence', () {
      final shell = _read(_shellFile);
      final syncAllBlock = _blockStartingAt(shell, 'Future<void> syncAll()');

      _expectOrder(syncAllBlock, const [
        'if (_isSyncing)',
        '_isSyncing = true;',
        'lastSuccessCount = 0;',
        'lastFailureCount = 0;',
        'lastConflictCount = 0;',
        'lastFailureDetailOverflowCount = 0;',
        'lastConflictKeys.clear();',
        'lastFailureDetails.clear();',
        'await _syncTickets();',
        'await _syncTemplates();',
        'await _syncTemplateGovernance();',
        'await _syncKnowledgeBase();',
        'await _syncExecutions(skipCompletedClosures: true);',
        'await _syncJobDiaryEntries();',
        'await _syncJobModules();',
        'await _syncCompletedExecutionClosures();',
        'await _syncDirectives();',
        'await _syncAbnormalityTypes();',
        'await _syncChargeAbnormalities();',
        'await _auditRepo.syncPendingAuditEvents();',
        '_isSyncing = false;',
        'lastSyncTime = DateTime.now();',
      ]);
    });

    test('planned job closure order remains protected in syncAll', () {
      final shell = _read(_shellFile);
      final syncAllBlock = _blockStartingAt(shell, 'Future<void> syncAll()');

      _expectOrder(syncAllBlock, const [
        'await _syncExecutions(skipCompletedClosures: true);',
        'await _syncJobDiaryEntries();',
        'await _syncJobModules();',
        'await _syncCompletedExecutionClosures();',
      ]);

      expect(syncAllBlock, contains('ORDER DEPENDENCY'));
      expect(syncAllBlock, contains('Cloud Function'));
      expect(syncAllBlock, contains('canonical remote module state'));
    });

    test('entity methods live in semantically named part files', () {
      final ticketsTemplates = _read(
        'lib/core/services/sync_service.tickets_templates.dart',
      );
      final templateGovernance = _read(
        'lib/core/services/sync_service.template_governance.dart',
      );
      final executions = _read(
        'lib/core/services/sync_service.executions.dart',
      );
      final jobDiary = _read('lib/core/services/sync_service.job_diary.dart');
      final jobModules = _read(
        'lib/core/services/sync_service.job_modules.dart',
      );
      final directivesAbnormalities = _read(
        'lib/core/services/sync_service.directives_abnormalities.dart',
      );
      final knowledgeBase = _read(
        'lib/core/services/sync_service.knowledge_base.dart',
      );

      expect(ticketsTemplates, contains('Future<void> _syncTickets()'));
      expect(ticketsTemplates, contains('Future<void> _syncTemplates()'));
      expect(
        templateGovernance,
        contains('Future<void> _syncTemplateGovernance()'),
      );
      expect(executions, contains('Future<void> _syncExecutions('));
      expect(
        executions,
        contains('Future<void> _syncCompletedExecutionClosures()'),
      );
      expect(jobDiary, contains('Future<void> _syncJobDiaryEntries()'));
      expect(jobModules, contains('Future<void> _syncJobModules()'));
      expect(
        directivesAbnormalities,
        contains('Future<void> _syncDirectives()'),
      );
      expect(
        directivesAbnormalities,
        contains('Future<void> _syncAbnormalityTypes()'),
      );
      expect(
        directivesAbnormalities,
        contains('Future<void> _syncChargeAbnormalities()'),
      );
      expect(knowledgeBase, contains('Future<void> _syncKnowledgeBase()'));
      expect(
        knowledgeBase,
        contains(
          'Future<bool> _isKnowledgeBaseBatchHeldByPermanentRejection()',
        ),
      );

      expect(
        jobModules,
        isNot(contains('Future<void> _syncJobDiaryEntries()')),
      );
      expect(
        directivesAbnormalities,
        isNot(contains('Future<void> _syncKnowledgeBase()')),
      );
    });

    test('providers and public sync API remain anchored in the shell', () {
      final shell = _read(_shellFile);
      final partSource = _readAll(
        _syncServicePartFiles.map((file) => 'lib/core/services/$file').toList(),
      );

      expect(
        shell,
        contains('final syncServiceProvider = Provider<SyncService>'),
      );
      expect(
        shell,
        contains(
          'final syncPendingCountsProvider = FutureProvider.autoDispose<SyncPendingCounts>',
        ),
      );
      expect(partSource, isNot(contains('syncServiceProvider')));
      expect(partSource, isNot(contains('syncPendingCountsProvider')));
    });

    test(
      'first sync slice does not introduce deferred entity-syncer architecture',
      () {
        final allSyncSource = _readAll(_syncServiceFiles);
        final partSource = _readAll(
          _syncServicePartFiles
              .map((file) => 'lib/core/services/$file')
              .toList(),
        );

        expect(allSyncSource, isNot(contains('class SyncRunContext')));
        expect(allSyncSource, isNot(contains('mixin SyncEntityMixin')));
        expect(allSyncSource, isNot(contains('class TicketSyncer')));
        expect(allSyncSource, isNot(contains('class ExecutionSyncer')));
        expect(allSyncSource, isNot(contains('class JobModuleSyncer')));
        expect(partSource, isNot(contains('SyncCoordinator')));
        expect(partSource, isNot(contains('GlobalPullService')));
      },
    );
  });
}

const _shellFile = 'lib/core/services/sync_service.dart';

const _partExtensionNames = <String, String>{
  'sync_service.push_infrastructure.dart': '_SyncServicePushInfrastructure',
  'sync_service.template_governance.dart': '_SyncServiceTemplateGovernance',
  'sync_service.tickets_templates.dart': '_SyncServiceTicketsTemplates',
  'sync_service.executions.dart': '_SyncServiceExecutions',
  'sync_service.job_diary.dart': '_SyncServiceJobDiary',
  'sync_service.job_modules.dart': '_SyncServiceJobModules',
  'sync_service.directives_abnormalities.dart':
      '_SyncServiceDirectivesAbnormalities',
  'sync_service.knowledge_base.dart': '_SyncServiceKnowledgeBase',
};

const _syncServicePartFiles = <String>[
  'sync_service.push_infrastructure.dart',
  'sync_service.template_governance.dart',
  'sync_service.tickets_templates.dart',
  'sync_service.executions.dart',
  'sync_service.job_diary.dart',
  'sync_service.job_modules.dart',
  'sync_service.directives_abnormalities.dart',
  'sync_service.knowledge_base.dart',
];

const _syncServiceFiles = <String>[
  _shellFile,
  'lib/core/services/sync_service.push_infrastructure.dart',
  'lib/core/services/sync_service.template_governance.dart',
  'lib/core/services/sync_service.tickets_templates.dart',
  'lib/core/services/sync_service.executions.dart',
  'lib/core/services/sync_service.job_diary.dart',
  'lib/core/services/sync_service.job_modules.dart',
  'lib/core/services/sync_service.directives_abnormalities.dart',
  'lib/core/services/sync_service.knowledge_base.dart',
];

const _expectedMethodOwners = <String, String>{
  'syncAll': _shellFile,
  'countPendingLocalWrites': _shellFile,
  '_retry': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_sortDeletesFirst':
      'lib/core/services/sync_service.push_infrastructure.dart',
  '_checkClockDrift': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_isRemoteNewer': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_syncPushSnapshot':
      'lib/core/services/sync_service.push_infrastructure.dart',
  '_syncPushSnapshots':
      'lib/core/services/sync_service.push_infrastructure.dart',
  '_recordPushFailureDetail':
      'lib/core/services/sync_service.push_infrastructure.dart',
  '_upsertSyncRejection':
      'lib/core/services/sync_service.push_infrastructure.dart',
  '_recordPushFailuresForBatch':
      'lib/core/services/sync_service.push_infrastructure.dart',
  '_recordsEligibleForAutomaticPush':
      'lib/core/services/sync_service.push_infrastructure.dart',
  '_recordAutomaticRetryHeld':
      'lib/core/services/sync_service.push_infrastructure.dart',
  '_syncFirestoreId': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_syncEntityId': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_recordPushConflict':
      'lib/core/services/sync_service.push_infrastructure.dart',
  '_cleanText': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_sameStringList': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_sameInstant': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_uid': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_date': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_shortText': 'lib/core/services/sync_service.push_infrastructure.dart',
  '_syncTemplateGovernance':
      'lib/core/services/sync_service.template_governance.dart',
  '_syncTemplatePackages':
      'lib/core/services/sync_service.template_governance.dart',
  '_syncTemplateVersions':
      'lib/core/services/sync_service.template_governance.dart',
  '_syncTemplatePublishAudits':
      'lib/core/services/sync_service.template_governance.dart',
  '_syncTickets': 'lib/core/services/sync_service.tickets_templates.dart',
  '_syncTemplates': 'lib/core/services/sync_service.tickets_templates.dart',
  '_syncExecutions': 'lib/core/services/sync_service.executions.dart',
  '_syncCompletedExecutionClosures':
      'lib/core/services/sync_service.executions.dart',
  '_syncCompletedExecutionThroughServer':
      'lib/core/services/sync_service.executions.dart',
  '_shouldRebaseRejectedExecutionTombstone':
      'lib/core/services/sync_service.executions.dart',
  '_describeExecutionForSync': 'lib/core/services/sync_service.executions.dart',
  '_executionPinnedFieldDiff': 'lib/core/services/sync_service.executions.dart',
  '_executionCompletionFieldDiff':
      'lib/core/services/sync_service.executions.dart',
  '_syncJobDiaryEntries': 'lib/core/services/sync_service.job_diary.dart',
  '_syncJobModules': 'lib/core/services/sync_service.job_modules.dart',
  '_shouldRebaseRejectedTerminalJobModule':
      'lib/core/services/sync_service.job_modules.dart',
  '_describeJobModuleForSync':
      'lib/core/services/sync_service.job_modules.dart',
  '_jobModulePinnedFieldDiff':
      'lib/core/services/sync_service.job_modules.dart',
  '_jobModulePayloadDiff': 'lib/core/services/sync_service.job_modules.dart',
  '_jobModuleLifecycleDiff': 'lib/core/services/sync_service.job_modules.dart',
  '_syncDirectives':
      'lib/core/services/sync_service.directives_abnormalities.dart',
  '_syncAbnormalityTypes':
      'lib/core/services/sync_service.directives_abnormalities.dart',
  '_syncChargeAbnormalities':
      'lib/core/services/sync_service.directives_abnormalities.dart',
  '_isKnowledgeBaseBatchHeldByPermanentRejection':
      'lib/core/services/sync_service.knowledge_base.dart',
  '_syncKnowledgeBase': 'lib/core/services/sync_service.knowledge_base.dart',
};

const _sharedPushInfrastructureHelpers = <String>[
  '_sortDeletesFirst',
  '_checkClockDrift',
  '_isRemoteNewer',
  '_syncPushSnapshot',
  '_syncPushSnapshots',
  '_recordPushFailureDetail',
  '_recordPushFailuresForBatch',
  '_recordsEligibleForAutomaticPush',
  '_recordAutomaticRetryHeld',
  '_syncFirestoreId',
  '_syncEntityId',
  '_recordPushConflict',
  '_cleanText',
  '_sameStringList',
  '_sameInstant',
  '_uid',
  '_date',
  '_shortText',
];

String _read(String path) => File(path).readAsStringSync();

String _readAll(List<String> paths) => paths.map(_read).join('\n\n');

int _declarationCount(String source, String methodName) =>
    _declarationRegExp(methodName).allMatches(source).length;

bool _containsDeclaration(String source, String methodName) =>
    _declarationRegExp(methodName).hasMatch(source);

RegExp _declarationRegExp(String methodName) => RegExp(
  r'^\s*'
  r'(?:Future(?:<[^=\n]+>)?|List<[^=\n]+>|Set<[^=\n]+>|Map<[^=\n]+>|'
  r'SyncPushSnapshot|void|bool|String\?|String|DateTime\?|int)'
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

  final openBrace = source.indexOf('{', markerIndex);
  expect(openBrace, isNot(-1), reason: 'Missing opening brace after $marker');

  var depth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inTripleSingleQuote = false;
  var inTripleDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;

  for (var i = openBrace; i < source.length; i++) {
    final char = source.codeUnitAt(i);
    final next = i + 1 < source.length ? source.codeUnitAt(i + 1) : -1;
    final next2 = i + 2 < source.length ? source.codeUnitAt(i + 2) : -1;
    final prev = i > 0 ? source.codeUnitAt(i - 1) : -1;

    if (inLineComment) {
      if (char == 0x0A || char == 0x0D) {
        inLineComment = false;
      }
      continue;
    }
    if (inBlockComment) {
      if (char == 0x2A && next == 0x2F) {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inTripleSingleQuote) {
      if (char == 0x27 && next == 0x27 && next2 == 0x27) {
        inTripleSingleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inTripleDoubleQuote) {
      if (char == 0x22 && next == 0x22 && next2 == 0x22) {
        inTripleDoubleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inSingleQuote) {
      if (char == 0x27 && prev != 0x5C) {
        inSingleQuote = false;
      }
      continue;
    }
    if (inDoubleQuote) {
      if (char == 0x22 && prev != 0x5C) {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char == 0x2F && next == 0x2F) {
      inLineComment = true;
      i++;
      continue;
    }
    if (char == 0x2F && next == 0x2A) {
      inBlockComment = true;
      i++;
      continue;
    }
    if (char == 0x27 && next == 0x27 && next2 == 0x27) {
      inTripleSingleQuote = true;
      i += 2;
      continue;
    }
    if (char == 0x22 && next == 0x22 && next2 == 0x22) {
      inTripleDoubleQuote = true;
      i += 2;
      continue;
    }
    if (char == 0x27) {
      inSingleQuote = true;
      continue;
    }
    if (char == 0x22) {
      inDoubleQuote = true;
      continue;
    }

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
