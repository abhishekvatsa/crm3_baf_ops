import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('67E async mounted/context safety sweep', () {
    test('job module detail guards setState after awaited repository mutations', () {
      final source = _read(
        'lib/features/planned_maintenance/presentation/job_module_detail_screen.dart',
      );

      for (final marker in <RegExp>[
        RegExp(r'saveModule\(\s*updated,'),
        RegExp(r'submitModule\(\s*_transitionId\(\),'),
        RegExp(r'acceptModule\(\s*_transitionId\(\),'),
        RegExp(r'markModuleNotApplicable\(\s*_transitionId\(\),'),
        RegExp(r'reopenModule\(\s*_transitionId\(\),'),
      ]) {
        final section = _windowAfterPattern(source, marker, 700);
        expect(
          section,
          contains('if (!mounted) return;'),
          reason:
              'Job-module local state must not be updated after an awaited repository call when the detail screen has unmounted.',
        );
        expect(section, contains('setState('));
      }

      expect(
        source,
        isNot(contains(');\n        setState(() => _module = updated);')),
        reason:
            'A mounted guard must stay between awaited saveModule calls and local setState.',
      );
    });

    test(
      'dialog and clipboard continuations guard mounted state before UI mutation',
      () {
        final templatePublisher = _templatePublisherSource();
        final paste = _bodyStartingAt(
          templatePublisher,
          'Future<void> _pasteFromClipboard',
        );
        expect(paste, contains('await Clipboard.getData'));
        expect(paste, contains('if (!mounted) return;'));
        expect(
          paste.indexOf('if (!mounted) return;'),
          lessThan(paste.indexOf('controller.text = text;')),
          reason:
              'Clipboard paste must not mutate controllers or show snacks after the publisher screen unmounts.',
        );

        final charge = _read(
          'lib/features/abnormalities/presentation/charge_abnormalities_screen.dart',
        );
        final showForm = _bodyStartingAt(
          charge,
          'Future<void> _showAbnormalityForm',
        );
        expect(showForm, contains('if (!mounted || draft == null) return;'));
        final confirmDelete = _bodyStartingAt(
          charge,
          'Future<void> _confirmDelete',
        );
        expect(
          confirmDelete,
          contains('if (!mounted || decision == null) return;'),
        );

        final quality = _bodyStartingAt(
          _read('lib/features/quality/presentation/quality_home_screen.dart'),
          'Future<void> _runCommand',
        );
        _expectBefore(
          quality,
          'if (!mounted || _submitting) return;',
          'setState(() => _submitting = true);',
        );

        final assignment = _read(
          'lib/features/planned_maintenance/presentation/published_template_assignment_screen.dart',
        );
        final submit = _bodyStartingAt(assignment, 'Future<void> _submit');
        expect(submit, contains('final package = await _selectedPackage();'));
        expect(submit, contains('final version = await _selectedVersion();'));
        expect(submit, contains('if (!mounted) return;'));
        expect(
          submit.indexOf('if (!mounted) return;'),
          lessThan(submit.indexOf('if (package == null || version == null)')),
          reason:
              'Published-template assignment must not continue into UI/busy-state work after async selection if unmounted.',
        );
      },
    );

    test(
      'sync follow-up services are captured before awaited write calls in swept UI files',
      () {
        _expectCapturedSyncBeforeAwait(
          path: 'lib/features/maintenance/presentation/maintenance_form.dart',
          methodMarker: 'Future<void> _submit',
          awaitMarker: 'await repository.saveTicket(record);',
          syncReason: 'normal_ticket_created_immediate',
        );
        _expectCapturedSyncBeforeAwait(
          path: 'lib/features/maintenance/presentation/resolve_form.dart',
          methodMarker: 'Future<void> _submit',
          awaitMarker: 'final receipt = await ref',
          syncReason: 'ticket_resolved',
        );
        _expectCapturedSyncBeforeAwait(
          path:
              'lib/features/directives/presentation/create_directive_screen.dart',
          methodMarker: 'Future<void> _submit',
          awaitMarker: 'await repo.saveDirective(',
          syncReason: 'directive_created',
        );
        _expectCapturedSyncBeforeAwait(
          path: 'lib/features/directives/presentation/directives_screen.dart',
          methodMarker: 'Future<void> _acknowledgeDirective',
          awaitMarker: 'await repo.acknowledgeDirective(',
          syncReason: 'directive_acknowledged',
        );
        _expectCapturedSyncBeforeAwait(
          path: 'lib/features/directives/presentation/directives_screen.dart',
          methodMarker: 'Future<void> _closeDirective',
          awaitMarker: 'await repo.closeDirective(',
          syncReason: 'directive_closed',
        );
        _expectCapturedSyncBeforeAwait(
          path:
              'lib/features/abnormalities/presentation/abnormalities_home_screen.dart',
          methodMarker: 'Future<void> _seedDefaults',
          awaitMarker: 'await repository.seedDefaultTypes',
          syncReason: 'abnormality_defaults_seeded',
        );
        _expectCapturedSyncBeforeAwait(
          path:
              'lib/features/abnormalities/presentation/abnormality_types_screen.dart',
          methodMarker: 'Future<void> _seedDefaults',
          awaitMarker: 'await repository.seedDefaultTypes',
          syncReason: 'abnormality_type_seeded',
        );
        _expectCapturedSyncBeforeAwait(
          path:
              'lib/features/abnormalities/presentation/charge_abnormalities_screen.dart',
          methodMarker: 'Future<void> _showAbnormalityForm',
          awaitMarker: 'await repository.getActiveTypes();',
          syncReason: 'charge_abnormality_created',
        );
        _expectCapturedSyncBeforeAwait(
          path:
              'lib/features/planned_maintenance/presentation/template_detail_screen.dart',
          methodMarker: 'Future<void> _confirmDelete',
          awaitMarker: 'await repository.deleteTemplate(',
          syncReason: 'template_deleted',
        );
        _expectCapturedSyncBeforeAwait(
          path:
              'lib/features/planned_maintenance/presentation/complete_job_screen.dart',
          methodMarker: 'Future<void> _submit',
          awaitMarker: 'await repository.completeExecution(',
          syncReason: 'job_completed',
        );

        // Captures must be hoisted above the pre-completion sync await too
        final completeJobBody = _bodyStartingAt(
          _read(
            'lib/features/planned_maintenance/presentation/complete_job_screen.dart',
          ),
          'Future<void> _submit',
        );
        _expectBefore(
          completeJobBody,
          'final repository = ref.read(plannedRepositoryProvider);',
          'await coordinator.runFullSyncWithResult(',
        );
        _expectBefore(
          completeJobBody,
          'final coordinator = ref.read(syncCoordinatorProvider);',
          'await coordinator.runFullSyncWithResult(',
        );
        _expectBefore(
          completeJobBody,
          'syncCoordinator = coordinator;',
          'await coordinator.runFullSyncWithResult(',
        );
        _expectBefore(
          completeJobBody,
          'syncCoordinator = coordinator;',
          'await repository.completeExecution(',
        );
        expect(
          completeJobBody,
          contains('if (syncCoordinator != null) {'),
          reason:
              'Post-completion sync must remain best-effort if pre-sync setup fails.',
        );
        final templatePublisher = _templatePublisherSource();
        _expectCapturedSyncBeforeAwaitInSource(
          source: templatePublisher,
          methodMarker: 'Future<void> _saveDraft',
          awaitMarker: 'await _ensurePackageSaved(repo, actor);',
          syncReason: 'template_governance_draft_saved',
        );
        _expectCapturedSyncBeforeAwaitInSource(
          source: templatePublisher,
          methodMarker: 'Future<void> _publish',
          awaitMarker: 'await _ensurePackageSaved(repo, actor);',
          syncReason: 'template_governance_version_published',
        );
      },
    );

    test(
      'admin data browser captures repositories and sync coordinator before awaited admin mutations',
      () {
        final source = [
          _read('lib/features/admin/presentation/admin_data_browser.dart'),
          _read(
            'lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart',
          ),
          _read(
            'lib/features/admin/presentation/admin_data_browser/admin_directives_browser.dart',
          ),
          _read(
            'lib/features/admin/presentation/admin_data_browser/admin_templates_browser.dart',
          ),
          _read(
            'lib/features/admin/presentation/admin_data_browser/admin_executions_browser.dart',
          ),
        ].join('\n');

        for (final expectation in <_AdminMutationExpectation>[
          const _AdminMutationExpectation(
            sectionMarker:
                'class DirectivesBrowser extends ConsumerStatefulWidget',
            methodMarker: 'Future<void> _showEditDialog',
            repositoryProvider: 'directiveRepositoryProvider',
            awaitMarker: 'await repository.updateDirective(',
            syncReason: 'admin_directive_edited',
          ),
          const _AdminMutationExpectation(
            sectionMarker:
                'class DirectivesBrowser extends ConsumerStatefulWidget',
            methodMarker: 'Future<void> _confirmDelete',
            repositoryProvider: 'directiveRepositoryProvider',
            awaitMarker: 'await repository.deleteDirective(',
            syncReason: 'admin_directive_deleted',
          ),
          const _AdminMutationExpectation(
            sectionMarker:
                'class TemplatesBrowser extends ConsumerStatefulWidget',
            methodMarker: 'Future<void> _confirmDelete',
            repositoryProvider: 'plannedRepositoryProvider',
            awaitMarker: 'await repository.deleteTemplate(',
            syncReason: 'admin_template_deleted',
          ),
        ]) {
          final sectionStart = source.indexOf(expectation.sectionMarker);
          expect(
            sectionStart,
            isNonNegative,
            reason: 'Missing section marker: ${expectation.sectionMarker}',
          );
          final body = _bodyStartingAt(
            source.substring(sectionStart),
            expectation.methodMarker,
          );
          expect(
            body,
            contains(
              'final repository = ref.read(${expectation.repositoryProvider});',
            ),
          );
          _expectBefore(
            body,
            'final repository = ref.read(${expectation.repositoryProvider});',
            expectation.awaitMarker,
          );
          _expectBefore(
            body,
            'final syncCoordinator = ref.read(syncCoordinatorProvider);',
            expectation.awaitMarker,
          );
          expect(body, contains('syncCoordinator.runFullSync'));
          expect(body, contains(expectation.syncReason));
        }

        final ticketSectionStart = source.indexOf(
          'class TicketsBrowser extends ConsumerStatefulWidget',
        );
        final ticketDeleteBody = _bodyStartingAt(
          source.substring(ticketSectionStart),
          'Future<void> _confirmDelete',
        );
        const deleteAwait = 'await deletionReconciler.softDeleteServerFirst(';
        _expectBefore(
          ticketDeleteBody,
          'final deletionReconciler = ref.read(',
          deleteAwait,
        );
        _expectBefore(
          ticketDeleteBody,
          'final syncCoordinator = ref.read(syncCoordinatorProvider);',
          deleteAwait,
        );
        expect(
          ticketDeleteBody,
          contains('await remoteRepository.deleteTicket('),
        );
        expect(ticketDeleteBody, contains('admin_ticket_deleted'));

        final executionSection = source.substring(
          source.indexOf(
            'class ExecutionsBrowser extends ConsumerStatefulWidget',
          ),
        );
        expect(executionSection, contains('PlannedJobDetailScreen('));
        expect(executionSection, isNot(contains('deleteExecution(')));
        expect(executionSection, isNot(contains('admin_execution_deleted')));

        final ticketSection = source.indexOf(
          'class TicketsBrowser extends ConsumerStatefulWidget',
        );
        final ticketCorrectionBody = _bodyStartingAt(
          source.substring(ticketSection),
          'Future<void> _showCorrectionDialog',
        );
        const commandAwait =
            '.read(workflowCommandControllerProvider.notifier)';
        _expectBefore(
          ticketCorrectionBody,
          'final syncCoordinator = ref.read(syncCoordinatorProvider);',
          commandAwait,
        );
        expect(
          ticketCorrectionBody,
          contains('WorkflowCommandType.correctMaintenanceTicket'),
        );
        expect(ticketCorrectionBody, contains('admin_ticket_corrected'));
      },
    );

    test(
      'completion required-field snackbar preserves field label interpolation',
      () {
        final source = _read(
          'lib/features/planned_maintenance/presentation/complete_job_screen.dart',
        );
        expect(source, contains(r'Required field missing: ${field.label}'));
        expect(
          source,
          isNot(contains(r'Required field missing: \${field.label}')),
          reason:
              'The required-field snackbar must interpolate the actual field label.',
        );
      },
    );

    test('admin data browser uses consistent single-line mounted guards', () {
      final source = _read(
        'lib/features/admin/presentation/admin_data_browser.dart',
      );
      expect(
        source,
        isNot(contains('if (!mounted) {')),
        reason:
            'admin_data_browser must use single-line mounted guards for consistency.',
      );
    });

    test(
      'pending approval refresh does not invalidate provider after async work when unmounted',
      () {
        final source = _read(
          'lib/features/auth/presentation/pending_approval_screen.dart',
        );
        final body = _bodyStartingAt(source, 'Future<void> _refreshProfile');

        expect(
          body,
          contains('final authService = ref.read(authServiceProvider);'),
        );
        _expectBefore(
          body,
          'final authService = ref.read(authServiceProvider);',
          'await authService.ensureUserDocument();',
        );
        _expectBefore(
          body,
          'if (!mounted) return;',
          'ref.invalidate(currentAppUserProvider);',
        );
      },
    );

    test(
      'route-pop success feedback captures nullable messenger before popping routes',
      () {
        for (final expectation in <_RoutePopSnackExpectation>[
          const _RoutePopSnackExpectation(
            path:
                'lib/features/planned_maintenance/presentation/assign_job_screen.dart',
            methodMarker: 'Future<void> _submit',
            popMarker: 'Navigator.pop(context);\n      Navigator.pop(context);',
            snackMarker: 'messenger?.showSnackBar',
          ),
          const _RoutePopSnackExpectation(
            path:
                'lib/features/planned_maintenance/presentation/complete_job_screen.dart',
            methodMarker: 'Future<void> _submit',
            popMarker: 'Navigator.pop(context);',
            snackMarker: 'messenger?.showSnackBar',
          ),
          const _RoutePopSnackExpectation(
            path:
                'lib/features/planned_maintenance/presentation/published_template_assignment_screen.dart',
            methodMarker: 'Future<void> _submit',
            popMarker: 'Navigator.pop(context);',
            snackMarker: 'messenger?.showSnackBar',
          ),
          const _RoutePopSnackExpectation(
            path:
                'lib/features/directives/presentation/create_directive_screen.dart',
            methodMarker: 'Future<void> _submit',
            popMarker: 'Navigator.pop(context);',
            snackMarker: 'messenger?.showSnackBar',
          ),
        ]) {
          final body = _bodyStartingAt(
            _read(expectation.path),
            expectation.methodMarker,
          );
          expect(
            body,
            contains('final messenger = ScaffoldMessenger.maybeOf(context);'),
            reason:
                '${expectation.path} must capture the messenger before route pop.',
          );
          _expectBefore(
            body,
            'final messenger = ScaffoldMessenger.maybeOf(context);',
            expectation.popMarker,
          );
          _expectBefore(body, expectation.popMarker, expectation.snackMarker);
        }
      },
    );

    test(
      'legacy template and ticket async surfaces capture sync or nullable messenger safely',
      () {
        _expectWorkflowCommandAssignmentContract();
        _expectCapturedSyncBeforeAwait(
          path:
              'lib/features/planned_maintenance/presentation/create_template_screen.dart',
          methodMarker: 'Future<void> _submit',
          awaitMarker: 'await repository.saveTemplate(',
          syncReason: 'template_created',
        );
        _expectCapturedSyncBeforeAwait(
          path:
              'lib/features/planned_maintenance/presentation/template_designer_screen.dart',
          methodMarker: 'Future<void> _save',
          awaitMarker: 'await repo.saveTemplate(',
          syncReason: 'template_updated',
        );

        final tickets = _bodyStartingAt(
          _read('lib/features/maintenance/presentation/ticket_screen.dart'),
          'Future<void> _refreshTickets',
        );
        _expectBefore(
          tickets,
          'final syncCoordinator = ref.read(syncCoordinatorProvider);',
          'await syncCoordinator.runFullSyncWithResult',
        );
        expect(
          tickets,
          contains('ScaffoldMessenger.maybeOf(context)?.showSnackBar'),
        );

        final publishMetadata = _read(
          'lib/features/planned_maintenance/presentation/widgets/publish_metadata_dialog.dart',
        );
        expect(
          publishMetadata,
          contains('ScaffoldMessenger.maybeOf(context)?.showSnackBar'),
        );
        expect(
          publishMetadata,
          isNot(contains('ScaffoldMessenger.of(context)')),
        );
      },
    );
  });
}

void _expectCapturedSyncBeforeAwait({
  required String path,
  required String methodMarker,
  required String awaitMarker,
  required String syncReason,
}) {
  _expectCapturedSyncBeforeAwaitInSource(
    source: _read(path),
    methodMarker: methodMarker,
    awaitMarker: awaitMarker,
    syncReason: syncReason,
  );
}

void _expectCapturedSyncBeforeAwaitInSource({
  required String source,
  required String methodMarker,
  required String awaitMarker,
  required String syncReason,
}) {
  final body = _bodyStartingAt(source, methodMarker);
  final finalCapture = body.indexOf(
    'final syncCoordinator = ref.read(syncCoordinatorProvider);',
  );
  final assignmentCapture = body.indexOf(
    'syncCoordinator = ref.read(syncCoordinatorProvider);',
  );
  final localCoordinatorCapture = body.indexOf(
    'final coordinator = ref.read(syncCoordinatorProvider);',
  );
  final awaitIndex = body.indexOf(awaitMarker);

  expect(awaitIndex, isNonNegative, reason: 'Expected to find: $awaitMarker');
  expect(
    finalCapture >= 0 || assignmentCapture >= 0 || localCoordinatorCapture >= 0,
    isTrue,
    reason: 'Expected syncCoordinator to be captured before: $awaitMarker',
  );
  final captureIndex =
      finalCapture >= 0
          ? finalCapture
          : assignmentCapture >= 0
          ? assignmentCapture
          : localCoordinatorCapture;
  expect(captureIndex, lessThan(awaitIndex));
  expect(
    body,
    matches(RegExp(r'(syncCoordinator|coordinator)\s*\.runFullSync')),
  );
  expect(body, contains(syncReason));
}

void _expectBefore(String source, String before, String after) {
  final beforeIndex = source.indexOf(before);
  final afterIndex = source.indexOf(after);

  expect(beforeIndex, isNonNegative, reason: 'Expected to find: $before');
  expect(afterIndex, isNonNegative, reason: 'Expected to find: $after');
  expect(
    beforeIndex,
    lessThan(afterIndex),
    reason: 'Expected `$before` to appear before `$after`.',
  );
}

String _read(String path) => File(path).readAsStringSync();

String _templatePublisherSource() =>
    _templatePublisherLibraryFiles.map(_read).join('\n');

const _templatePublisherLibraryFiles = <String>[
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
];

String _windowAfterPattern(String source, RegExp marker, int length) {
  final match = marker.firstMatch(source);
  expect(match, isNotNull, reason: 'Missing marker pattern: $marker');
  final start = match!.start;
  final end = (start + length).clamp(0, source.length);
  return source.substring(start, end);
}

void _expectWorkflowCommandAssignmentContract() {
  final body = _bodyStartingAt(
    _read(
      'lib/features/planned_maintenance/presentation/assign_job_screen.dart',
    ),
    'Future<void> _submit',
  );
  const commandAwait = '.read(workflowCommandControllerProvider.notifier)';
  const syncCapture =
      'final syncCoordinator = ref.read(syncCoordinatorProvider);';

  expect(body, contains(commandAwait));
  expect(body, contains('.execute('));
  expect(body, contains('WorkflowCommandType.createLegacyWorkflowJob'));
  expect(body, isNot(contains('repository.saveExecution(')));
  _expectBefore(body, syncCapture, commandAwait);
  expect(
    body,
    allOf(
      contains('syncCoordinator.runFullSync('),
      contains("reason: 'workflow_job_assigned'"),
      contains('force: true'),
    ),
  );
}

String _bodyStartingAt(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  expect(markerIndex, isNonNegative, reason: 'Missing marker: $marker');

  final bodyStart = _bodyBraceIndex(source, markerIndex);
  var depth = 0;
  var inSingle = false;
  var inDouble = false;
  var inTripleSingle = false;
  var inTripleDouble = false;
  var inLineComment = false;
  var inBlockComment = false;
  var escaped = false;

  for (var index = bodyStart; index < source.length; index++) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';
    final next2 = index + 2 < source.length ? source[index + 2] : '';

    if (inLineComment) {
      if (char == '\n') inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        index++;
      }
      continue;
    }

    if (!inSingle && !inDouble && !inTripleSingle && !inTripleDouble) {
      if (char == '/' && next == '/') {
        inLineComment = true;
        index++;
        continue;
      }
      if (char == '/' && next == '*') {
        inBlockComment = true;
        index++;
        continue;
      }
      if (char == "'" && next == "'" && next2 == "'") {
        inTripleSingle = true;
        index += 2;
        continue;
      }
      if (char == '"' && next == '"' && next2 == '"') {
        inTripleDouble = true;
        index += 2;
        continue;
      }
      if (char == "'") {
        inSingle = true;
        continue;
      }
      if (char == '"') {
        inDouble = true;
        continue;
      }
    } else if (inTripleSingle) {
      if (char == "'" && next == "'" && next2 == "'") {
        inTripleSingle = false;
        index += 2;
      }
      continue;
    } else if (inTripleDouble) {
      if (char == '"' && next == '"' && next2 == '"') {
        inTripleDouble = false;
        index += 2;
      }
      continue;
    } else if (inSingle) {
      if (!escaped && char == "'") inSingle = false;
      escaped = !escaped && char == r'\';
      if (char != r'\') escaped = false;
      continue;
    } else if (inDouble) {
      if (!escaped && char == '"') inDouble = false;
      escaped = !escaped && char == r'\';
      if (char != r'\') escaped = false;
      continue;
    }

    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(bodyStart, index + 1);
      }
    }
  }

  throw StateError('Could not parse body for marker: $marker');
}

int _bodyBraceIndex(String source, int markerIndex) {
  var parenDepth = 0;
  var inSingle = false;
  var inDouble = false;
  var inTripleSingle = false;
  var inTripleDouble = false;
  var inLineComment = false;
  var inBlockComment = false;
  var escaped = false;

  for (var index = markerIndex; index < source.length; index++) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';
    final next2 = index + 2 < source.length ? source[index + 2] : '';

    if (inLineComment) {
      if (char == '\n') inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        index++;
      }
      continue;
    }

    if (!inSingle && !inDouble && !inTripleSingle && !inTripleDouble) {
      if (char == '/' && next == '/') {
        inLineComment = true;
        index++;
        continue;
      }
      if (char == '/' && next == '*') {
        inBlockComment = true;
        index++;
        continue;
      }
      if (char == "'" && next == "'" && next2 == "'") {
        inTripleSingle = true;
        index += 2;
        continue;
      }
      if (char == '"' && next == '"' && next2 == '"') {
        inTripleDouble = true;
        index += 2;
        continue;
      }
      if (char == "'") {
        inSingle = true;
        continue;
      }
      if (char == '"') {
        inDouble = true;
        continue;
      }
      if (char == '(') {
        parenDepth++;
        continue;
      }
      if (char == ')') {
        parenDepth--;
        continue;
      }
      if (char == '{' && parenDepth == 0) return index;
    } else if (inTripleSingle) {
      if (char == "'" && next == "'" && next2 == "'") {
        inTripleSingle = false;
        index += 2;
      }
      continue;
    } else if (inTripleDouble) {
      if (char == '"' && next == '"' && next2 == '"') {
        inTripleDouble = false;
        index += 2;
      }
      continue;
    } else if (inSingle) {
      if (!escaped && char == "'") inSingle = false;
      escaped = !escaped && char == r'\';
      if (char != r'\') escaped = false;
      continue;
    } else if (inDouble) {
      if (!escaped && char == '"') inDouble = false;
      escaped = !escaped && char == r'\';
      if (char != r'\') escaped = false;
      continue;
    }
  }

  throw StateError('Could not find body brace after marker index $markerIndex');
}

class _RoutePopSnackExpectation {
  final String path;
  final String methodMarker;
  final String popMarker;
  final String snackMarker;

  const _RoutePopSnackExpectation({
    required this.path,
    required this.methodMarker,
    required this.popMarker,
    required this.snackMarker,
  });
}

class _AdminMutationExpectation {
  final String sectionMarker;
  final String methodMarker;
  final String repositoryProvider;
  final String awaitMarker;
  final String syncReason;

  const _AdminMutationExpectation({
    required this.sectionMarker,
    required this.methodMarker,
    required this.repositoryProvider,
    required this.awaitMarker,
    required this.syncReason,
  });
}
