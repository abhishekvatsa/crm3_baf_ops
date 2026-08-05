import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('67D lifecycle/static guardrails', () {
    test(
      'guarded production and contract files exist with no stale duplicate tests',
      () {
        for (final path in _guardedFiles) {
          expect(
            File(path).existsSync(),
            isTrue,
            reason: 'Expected $path to exist.',
          );
        }

        expect(
          File('test/issue67C_hybrid_contract_test.dart').existsSync(),
          isFalse,
          reason: 'Do not keep duplicate temporary 67C contract-test files.',
        );
      },
    );

    test('hardened snackbar surfaces keep mounted-safe maybeOf helpers', () {
      for (final guard in _snackbarGuards) {
        final source = _read(guard.path);
        final body = _blockStartingAt(source, guard.marker);

        expect(
          source,
          isNot(contains('ScaffoldMessenger.of(')),
          reason:
              '${guard.path} should keep centralized maybeOf snack helpers, not raw ScaffoldMessenger.of.',
        );
        expect(body, contains('ScaffoldMessenger.maybeOf'));
        expect(
          body,
          contains(guard.mountedGuard),
          reason:
              '${guard.path} must guard context/state before showing snackbars.',
        );
      }
    });

    test('recently hardened dialog files keep typed showDialog results', () {
      final untypedCalls = <String>[];

      for (final path in _recentlyHardenedDialogFiles) {
        final source = _read(path);
        final matches = RegExp(r'showDialog(?!<)\s*\(').allMatches(source);
        for (final match in matches) {
          untypedCalls.add('$path:${_lineFor(source, match.start)}');
        }
      }

      expect(
        untypedCalls,
        isEmpty,
        reason:
            'showDialog calls in recently hardened files must remain typed so callers do not rely on dynamic dialog results.',
      );
    });

    test(
      'parent-owned dialog controller patterns are not reintroduced across lib',
      () {
        final violations = <String>[];
        final bannedFragments = <String>[
          'controller ?? TextEditingController',
          'final controller = TextEditingController',
          'final reasonController = TextEditingController',
          'final remarksController = TextEditingController',
          'final notesController = TextEditingController',
          'Intentionally no immediate controller.dispose',
          'Intentionally no immediate reasonController.dispose',
        ];
        final localNonPrivateController = RegExp(
          r'\b(?:final|var)\s+(?!_)[A-Za-z0-9]*Controller\s*=\s*TextEditingController\s*\(',
        );

        for (final file in _libDartFiles()) {
          final path = _displayPath(file);
          final source = file.readAsStringSync();

          for (final fragment in bannedFragments) {
            final index = source.indexOf(fragment);
            if (index >= 0) {
              violations.add(
                '$path:${_lineFor(source, index)} contains $fragment',
              );
            }
          }

          for (final match in localNonPrivateController.allMatches(source)) {
            violations.add(
              '$path:${_lineFor(source, match.start)} creates a non-private local TextEditingController',
            );
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Dialog/input controllers should be owned by State classes or private fields and disposed by the owner, not created as caller-owned locals around dialogs.',
        );
      },
    );

    test('ref.listen is not used inside Widget build methods', () {
      final violations = <String>[];

      for (final file in _libDartFiles()) {
        final path = _displayPath(file);
        final source = file.readAsStringSync();
        for (final match in RegExp(
          r'\bWidget\s+build\s*\(',
        ).allMatches(source)) {
          final body = _functionBodyStartingAtIndex(source, match.start);
          if (body.contains('ref.listen(') || body.contains('ref.listen<')) {
            violations.add('$path:${_lineFor(source, match.start)}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Riverpod listeners inside build can be registered repeatedly. Use initState/listenManual or a provider-level listener instead.',
      );
    });

    test('Dart test filenames stay lower_snake_case and patch-artifact free', () {
      final violations = <String>[];
      final validTestName = RegExp(r'^[a-z0-9_]+_test\.dart$');
      final patchArtifactName = RegExp(
        r'(^|_)(copy|draft|fixed|hotfix|new|old|temp|tmp)(_|\.|$)',
      );

      for (final file in _testDartFiles()) {
        final name = _basename(file.path);
        final path = _displayPath(file);
        if (!validTestName.hasMatch(name)) {
          violations.add('$path is not lower_snake_case *_test.dart');
        }
        if (patchArtifactName.hasMatch(name)) {
          violations.add('$path looks like a patch/hotfix artefact name');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Contract tests are architectural memory; filenames must stay stable and reviewable.',
      );
    });

    test(
      'main.dart startup recovery keeps destructive rebuild and recovery-state guardrails',
      () {
        final source = _read('lib/main.dart');

        _expectContains(source, 'void _showStartupSnack(');
        _expectContains(
          source,
          'final messenger = ScaffoldMessenger.maybeOf(context);',
        );
        _expectContains(source, 'barrierDismissible: false');
        _expectContains(
          source,
          'builder: (_) => const _RebuildLocalDatabaseConfirmDialog()',
        );
        _expectContains(
          source,
          'class _RebuildLocalDatabaseConfirmDialog extends StatefulWidget',
        );
        _expectContains(source, 'const _RebuildLocalDatabaseConfirmDialog();');
        _expectContains(
          source,
          'late final TextEditingController _controller;',
        );
        _expectContains(source, '_controller.addListener(_handleChanged);');
        _expectContains(source, '_controller.removeListener(_handleChanged);');
        _expectContains(
          source,
          "final confirmation = _controller.text.trim().toUpperCase();",
        );
        _expectContains(source, "final canSubmit = confirmation == 'REBUILD';");
        _expectContains(
          source,
          'onPressed: canSubmit ? () => Navigator.of(context).pop(true) : null',
        );
        _expectContains(
          source,
          'finally { if (mounted) { setState(() => _isRetryingLocalDatabaseOpen = false); } }',
        );
        _expectContains(
          source,
          'finally { if (mounted) { setState(() => _isBackingUpLocalDatabase = false); } }',
        );
        _expectContains(
          source,
          'finally { if (mounted) { setState(() => _isRebuildingLocalDatabase = false); } }',
        );
      },
    );

    test(
      'sync and closed-ticket surfaces keep listener/busy-state lifecycle guardrails',
      () {
        final sync = _read('lib/core/widgets/sync_status_indicator.dart');
        final closedTickets = _read(
          'lib/features/maintenance/presentation/closed_tickets_screen.dart',
        );

        _expectContains(
          sync,
          'class SyncStatusIndicator extends ConsumerStatefulWidget',
        );
        _expectContains(sync, 'bool _isHealthPanelOpen = false;');
        _expectNotContains(sync, 'bool _isSyncHealthPanelOpen');
        _expectContains(
          sync,
          "label: runHealth.hasPendingFollowUp ? 'Sync queued' : 'Syncing'",
        );
        _expectContains(
          sync,
          'class _ResolveSyncRejectionDialog extends StatefulWidget',
        );
        _expectContains(
          sync,
          'late final TextEditingController _notesController;',
        );
        _expectContains(
          sync,
          '_notesController.addListener(_handleNotesChanged);',
        );
        _expectContains(
          sync,
          '_notesController.removeListener(_handleNotesChanged);',
        );
        _expectContains(
          sync,
          'final canSubmit = _notesController.text.trim().isNotEmpty;',
        );

        _expectContains(
          closedTickets,
          'late final ProviderSubscription<int> _refreshSubscription;',
        );
        _expectContains(closedTickets, 'ref.listenManual<int>');
        _expectContains(closedTickets, '_refreshSubscription.close();');
        _expectNotContains(
          closedTickets,
          'ref.listen<int>(refreshClosedTicketsProvider',
        );
        _expectContains(
          closedTickets,
          'final Set<String> _reopeningTicketKeys = <String>{};',
        );
        _expectContains(closedTickets, 'ValueKey(ticketKey)');
        _expectContains(
          closedTickets,
          'class _ReopenTicketDialog extends StatefulWidget',
        );
        _expectContains(
          closedTickets,
          'late final TextEditingController _remarksController;',
        );
      },
    );

    test(
      'knowledge governance and registry authoring keep governed dialog/action contracts',
      () {
        final registry = _read(
          'lib/features/planned_maintenance/presentation/module_registry_authoring_screen.dart',
        );
        final governance = _read(
          'lib/features/planned_maintenance/presentation/knowledge_governance_screen.dart',
        );
        final promoter = _read(
          'lib/features/planned_maintenance/presentation/widgets/knowledge_correction_promoter_panel.dart',
        );
        final templateDetail = _read(
          'lib/features/planned_maintenance/presentation/template_detail_screen.dart',
        );

        _expectContains(
          registry,
          'Future<bool> _runAction(Future<void> Function(AppUser actor) action)',
        );
        _expectContains(registry, 'final actor = _liveGovernanceActor;');
        _expectContains(registry, 'await action(actor);');
        _expectContains(registry, 'final success = await _runAction');
        _expectContains(registry, 'if (!mounted || !success) { return; }');
        _expectContains(
          registry,
          'class _RegistryReasonDialog extends StatefulWidget',
        );
        _expectContains(
          registry,
          'final canSubmit = value.length >= widget.minLength;',
        );

        _expectNotContains(governance, 'DefaultTabController');
        _expectContains(governance, 'late final TabController _tab;');
        _expectContains(
          governance,
          'class _KnowledgeBundlePasteDialog extends StatefulWidget',
        );
        _expectContains(
          governance,
          '_controller.addListener(_handleBodyChanged);',
        );
        _expectContains(
          governance,
          '_controller.removeListener(_handleBodyChanged);',
        );
        _expectContains(
          governance,
          'final canParse = _controller.text.trim().isNotEmpty;',
        );
        _expectContains(governance, 'DraggableScrollableSheet');

        _expectContains(
          promoter,
          'class KnowledgeCorrectionPromoterPanel extends ConsumerStatefulWidget',
        );
        _expectContains(
          promoter,
          'final Set<String> _promotingKeys = <String>{};',
        );
        _expectContains(
          promoter,
          'class _PromotionReasonDialog extends StatefulWidget',
        );
        _expectContains(promoter, 'Navigator.pop(context, reason)');

        _expectContains(templateDetail, 'showDialog<_TemplateDeleteDecision>');
        _expectContains(
          templateDetail,
          'class _TemplateDeleteDialog extends StatefulWidget',
        );
      },
    );

    test(
      'admin, abnormality, directive, and knowledge-row editors keep 67C guardrails',
      () {
        final admin = _read(
          'lib/features/admin/presentation/admin_data_browser.dart',
        );
        final adminTickets = _read(
          'lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart',
        );
        final adminDirectives = _read(
          'lib/features/admin/presentation/admin_data_browser/admin_directives_browser.dart',
        );
        final adminTemplates = _read(
          'lib/features/admin/presentation/admin_data_browser/admin_templates_browser.dart',
        );
        final adminExecutions = _read(
          'lib/features/admin/presentation/admin_data_browser/admin_executions_browser.dart',
        );
        final adminAbnormalities = _read(
          'lib/features/admin/presentation/admin_data_browser/admin_abnormalities_tab.dart',
        );
        final adminDirectiveDialog = _read(
          'lib/features/admin/presentation/admin_data_browser/admin_edit_directive_dialog.dart',
        );
        final adminShared = _read(
          'lib/features/admin/presentation/admin_data_browser/admin_data_browser_shared.dart',
        );
        final adminDeleteDialog = _read(
          'lib/features/admin/presentation/admin_data_browser/admin_delete_reason_dialog.dart',
        );
        final abnormality = _read(
          'lib/features/abnormalities/presentation/abnormality_types_screen.dart',
        );
        final directives = _read(
          'lib/features/directives/presentation/directives_screen.dart',
        );
        final rowEditor = _read(
          'lib/features/planned_maintenance/presentation/widgets/knowledge_row_editor.dart',
        );

        _expectContains(
          adminShared,
          'void showAdminDataSnack(BuildContext context, String message, {Color? color})',
        );
        _expectContains(
          adminShared,
          'final messenger = ScaffoldMessenger.maybeOf(context);',
        );
        _expectNotContains(admin, 'String? _cleanOptionalText(');
        _expectContains(adminTickets, 'showDialog<AdminDeleteDecision>');
        _expectContains(adminDirectives, 'showDialog<AdminDeleteDecision>');
        _expectContains(adminTemplates, 'showDialog<AdminDeleteDecision>');
        _expectContains(adminExecutions, 'showDialog<AdminDeleteDecision>');
        _expectContains(
          adminTickets,
          'class _AdminEditTicketDialog extends StatefulWidget',
        );
        _expectContains(
          adminDirectiveDialog,
          'class AdminEditDirectiveDialog extends StatefulWidget',
        );
        _expectContains(adminDirectives, 'showDialog<OperationalDirective>');
        _expectContains(
          adminDeleteDialog,
          'class AdminDeleteReasonDialog extends StatefulWidget',
        );

        _expectContains(
          adminAbnormalities,
          'class AbnormalitiesAdminTab extends StatelessWidget',
        );
        _expectContains(
          adminAbnormalities,
          'class _AdminAbnormalityActionCard extends StatelessWidget',
        );

        _expectContains(
          abnormality,
          'class _AbnormalityTypeFormDialog extends ConsumerStatefulWidget',
        );
        _expectContains(abnormality, 'bool _isSaving = false;');
        _expectContainsAny(abnormality, <String>[
          'if (_isSaving) { return; }',
          'if (_isSaving) return;',
        ]);
        _expectContains(
          abnormality,
          'showDialog<_AbnormalityTypeDeleteDecision>',
        );
        _expectContains(
          abnormality,
          'class _AbnormalityTypeDeleteDialog extends StatefulWidget',
        );
        _expectContains(
          abnormality,
          'void _showAbnormalityTypeSnack(String message, {Color? color})',
        );
        _expectNotContains(abnormality, 'ScaffoldMessenger.of(context)');

        _expectContains(
          directives,
          'class _CloseDirectiveDialog extends StatefulWidget',
        );
        _expectContains(directives, 'bool _isAcknowledging = false;');
        _expectContains(directives, 'bool _isClosing = false;');

        _expectContains(
          rowEditor,
          "key: ValueKey('readonly_knowledge_field_\$label')",
        );
        _expectContains(rowEditor, "initialValue: textValue ?? ''");
        _expectContains(rowEditor, 'final errorText =');
        _expectContains(rowEditor, 'reason.isEmpty || canSubmit');
        _expectContains(rowEditor, 'errorText: errorText');
        _expectContains(
          rowEditor,
          'if (!mounted || reason == null || reason.trim().isEmpty) { return; }',
        );
        _expectContains(rowEditor, 'Navigator.pop<bool>(context, true)');
      },
    );
  });
}

const _guardedFiles = <String>[
  'lib/main.dart',
  'lib/core/widgets/sync_status_indicator.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.builders.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.actions.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.validation.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.support.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.helpers.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_sections.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_json_panel.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_widgets.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_models.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.builders.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.support.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.helpers.dart',
  'lib/features/planned_maintenance/presentation/module_composer_widgets.dart',
  'lib/features/planned_maintenance/presentation/module_composer_dialogs.dart',
  'lib/features/planned_maintenance/presentation/module_registry_authoring_screen.dart',
  'lib/features/planned_maintenance/presentation/knowledge_governance_screen.dart',
  'lib/features/planned_maintenance/presentation/widgets/knowledge_correction_promoter_panel.dart',
  'lib/features/planned_maintenance/presentation/template_detail_screen.dart',
  'lib/features/maintenance/presentation/closed_tickets_screen.dart',
  'lib/features/directives/presentation/directives_screen.dart',
  'lib/features/admin/presentation/admin_data_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_directives_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_edit_directive_dialog.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_templates_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_executions_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_abnormalities_tab.dart',
  'lib/features/abnormalities/presentation/abnormality_types_screen.dart',
  'lib/features/planned_maintenance/presentation/widgets/knowledge_row_editor.dart',
  'test/startup_recovery_hardening_contract_test.dart',
  'test/sync_status_indicator_hardening_contract_test.dart',
  'test/module_composer_hardening_contract_test.dart',
  'test/module_registry_authoring_hardening_contract_test.dart',
  'test/field_hardening_contract_test.dart',
  'test/master_data_field_hardening_contract_test.dart',
];

const _snackbarGuards = <_SnackGuard>[
  _SnackGuard(
    path: 'lib/main.dart',
    marker: 'void _showStartupSnack(',
    mountedGuard: 'if (!context.mounted)',
  ),
  _SnackGuard(
    path: 'lib/core/widgets/sync_status_indicator.dart',
    marker: 'void _showSyncSnack(',
    mountedGuard: 'if (!context.mounted)',
  ),
  _SnackGuard(
    path:
        'lib/features/planned_maintenance/presentation/module_registry_authoring_screen.dart',
    marker: 'void _showSnack(',
    mountedGuard: 'if (!mounted)',
  ),
  _SnackGuard(
    path:
        'lib/features/planned_maintenance/presentation/knowledge_governance_screen.dart',
    marker: 'void _showKnowledgeSnack(',
    mountedGuard: 'if (!context.mounted)',
  ),
  _SnackGuard(
    path:
        'lib/features/planned_maintenance/presentation/widgets/knowledge_correction_promoter_panel.dart',
    marker: 'void _showPromotionSnack(',
    mountedGuard: 'if (!context.mounted)',
  ),
  _SnackGuard(
    path:
        'lib/features/planned_maintenance/presentation/template_detail_screen.dart',
    marker: 'void _showTemplateDetailSnack(',
    mountedGuard: 'if (!context.mounted)',
  ),
  _SnackGuard(
    path: 'lib/features/maintenance/presentation/closed_tickets_screen.dart',
    marker: 'void _showSnack(',
    mountedGuard: 'if (!mounted)',
  ),
  _SnackGuard(
    path: 'lib/features/directives/presentation/directives_screen.dart',
    marker: 'void _showDirectiveSnack(',
    mountedGuard: 'if (!mounted)',
  ),
  _SnackGuard(
    path:
        'lib/features/admin/presentation/admin_data_browser/admin_data_browser_shared.dart',
    marker: 'void showAdminDataSnack(',
    mountedGuard: 'if (!context.mounted)',
  ),
  _SnackGuard(
    path:
        'lib/features/abnormalities/presentation/abnormality_types_screen.dart',
    marker: 'void _showAbnormalityTypeSnack(',
    mountedGuard: 'if (!mounted)',
  ),
];

const _recentlyHardenedDialogFiles = <String>[
  'lib/main.dart',
  'lib/core/widgets/sync_status_indicator.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.builders.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.actions.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.validation.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.support.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_screen.helpers.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_sections.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_json_panel.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_widgets.dart',
  'lib/features/planned_maintenance/presentation/template_publisher_models.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.builders.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.support.dart',
  'lib/features/planned_maintenance/presentation/module_composer_screen.helpers.dart',
  'lib/features/planned_maintenance/presentation/module_composer_widgets.dart',
  'lib/features/planned_maintenance/presentation/module_composer_dialogs.dart',
  'lib/features/planned_maintenance/presentation/module_registry_authoring_screen.dart',
  'lib/features/planned_maintenance/presentation/knowledge_governance_screen.dart',
  'lib/features/planned_maintenance/presentation/widgets/knowledge_correction_promoter_panel.dart',
  'lib/features/planned_maintenance/presentation/template_detail_screen.dart',
  'lib/features/maintenance/presentation/closed_tickets_screen.dart',
  'lib/features/directives/presentation/directives_screen.dart',
  'lib/features/admin/presentation/admin_data_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_directives_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_edit_directive_dialog.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_templates_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_executions_browser.dart',
  'lib/features/admin/presentation/admin_data_browser/admin_abnormalities_tab.dart',
  'lib/features/abnormalities/presentation/abnormality_types_screen.dart',
  'lib/features/planned_maintenance/presentation/widgets/knowledge_row_editor.dart',
];

class _SnackGuard {
  const _SnackGuard({
    required this.path,
    required this.marker,
    required this.mountedGuard,
  });

  final String path;
  final String marker;
  final String mountedGuard;
}

String _read(String path) => File(path).readAsStringSync();

String _normalise(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

void _expectContains(String source, String pattern) {
  expect(_normalise(source), contains(_normalise(pattern)));
}

void _expectNotContains(String source, String pattern) {
  expect(_normalise(source), isNot(contains(_normalise(pattern))));
}

void _expectContainsAny(String source, List<String> patterns) {
  final normalisedSource = _normalise(source);
  final found = patterns.any(
    (pattern) => normalisedSource.contains(_normalise(pattern)),
  );
  expect(
    found,
    isTrue,
    reason: 'Expected source to contain one of: ${patterns.join(' | ')}',
  );
}

List<File> _libDartFiles() {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => _displayPath(a).compareTo(_displayPath(b)));
  return files;
}

List<File> _testDartFiles() {
  final files =
      Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => _displayPath(a).compareTo(_displayPath(b)));
  return files;
}

String _displayPath(File file) => file.path.replaceAll('\\', '/');

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

int _lineFor(String source, int index) {
  return source.substring(0, index).split('\n').length;
}

String _blockStartingAt(String source, String marker) {
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: 'Missing marker: $marker');
  return _blockStartingAtIndex(source, start);
}

String _functionBodyStartingAtIndex(String source, int start) {
  final open = _bodyBraceIndex(source, start);
  final arrow = source.indexOf('=>', start);
  if (arrow >= 0 && (open < 0 || arrow < open)) {
    final end = source.indexOf(';', arrow + 2);
    expect(
      end,
      isNonNegative,
      reason: 'Missing expression terminator at index $start',
    );
    return source.substring(arrow, end + 1);
  }
  return _blockStartingAtIndex(source, start);
}

String _blockStartingAtIndex(String source, int start) {
  final open = _bodyBraceIndex(source, start);
  expect(open, isNonNegative, reason: 'Missing opening brace at index $start');

  var depth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inTripleSingleQuote = false;
  var inTripleDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;
  var escaped = false;

  for (var i = open; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    final next2 = i + 2 < source.length ? source[i + 2] : '';

    if (inLineComment) {
      if (char == '\n') {
        inLineComment = false;
      }
      continue;
    }
    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inTripleSingleQuote) {
      if (char == "'" && next == "'" && next2 == "'") {
        inTripleSingleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inTripleDoubleQuote) {
      if (char == '"' && next == '"' && next2 == '"') {
        inTripleDoubleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inSingleQuote || inDoubleQuote) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (inSingleQuote && char == "'") {
        inSingleQuote = false;
      }
      if (inDoubleQuote && char == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char == '/' && next == '/') {
      inLineComment = true;
      i++;
      continue;
    }
    if (char == '/' && next == '*') {
      inBlockComment = true;
      i++;
      continue;
    }
    if (char == "'" && next == "'" && next2 == "'") {
      inTripleSingleQuote = true;
      i += 2;
      continue;
    }
    if (char == '"' && next == '"' && next2 == '"') {
      inTripleDoubleQuote = true;
      i += 2;
      continue;
    }
    if (char == "'") {
      inSingleQuote = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuote = true;
      continue;
    }
    if (char == '{') {
      depth++;
    }
    if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(open, i + 1);
      }
    }
  }

  fail('Could not close block at index $start');
}

int _bodyBraceIndex(String source, int start) {
  var parenDepth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inTripleSingleQuote = false;
  var inTripleDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;
  var escaped = false;

  for (var i = start; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    final next2 = i + 2 < source.length ? source[i + 2] : '';

    if (inLineComment) {
      if (char == '\n') {
        inLineComment = false;
      }
      continue;
    }
    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inTripleSingleQuote) {
      if (char == "'" && next == "'" && next2 == "'") {
        inTripleSingleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inTripleDoubleQuote) {
      if (char == '"' && next == '"' && next2 == '"') {
        inTripleDoubleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inSingleQuote || inDoubleQuote) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (inSingleQuote && char == "'") {
        inSingleQuote = false;
      }
      if (inDoubleQuote && char == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char == '/' && next == '/') {
      inLineComment = true;
      i++;
      continue;
    }
    if (char == '/' && next == '*') {
      inBlockComment = true;
      i++;
      continue;
    }
    if (char == "'" && next == "'" && next2 == "'") {
      inTripleSingleQuote = true;
      i += 2;
      continue;
    }
    if (char == '"' && next == '"' && next2 == '"') {
      inTripleDoubleQuote = true;
      i += 2;
      continue;
    }
    if (char == "'") {
      inSingleQuote = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuote = true;
      continue;
    }

    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')' && parenDepth > 0) {
      parenDepth--;
      continue;
    }
    if (char == '{' && parenDepth == 0) {
      return i;
    }
  }

  return -1;
}
