import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Module Composer hardening contract', () {
    late String source;

    setUpAll(() {
      source = _readModuleComposerLibrary();
    });

    test('seed cloud knowledge dialog owns its controller', () {
      expect(source, contains('class _SeedCloudKnowledgeBaselineDialog'));
      expect(source, contains('class _SeedCloudKnowledgeBaselineDialogState'));
      expect(
        source,
        contains('final _reasonController = TextEditingController();'),
      );
      expect(source, contains('_reasonController.dispose();'));
      expect(source, contains('textInputAction: TextInputAction.newline'));
      expect(source, contains('ConstrainedBox'));
      expect(source, contains('BoxConstraints(maxWidth: 560)'));
      expect(source, contains('BoxConstraints(maxWidth: 520)'));
      expect(source, contains('SingleChildScrollView'));

      final methodBody = _functionBody(source, '_seedCloudKnowledgeBaseline');
      expect(methodBody, contains('showDialog<String>'));
      expect(methodBody, contains('const _SeedCloudKnowledgeBaselineDialog()'));
      expect(methodBody, isNot(contains('TextEditingController()')));
      expect(methodBody, isNot(contains('.dispose()')));
      expect(methodBody, contains('if (!mounted)'));
    });

    test('safety-critical removal dialog owns its controller', () {
      expect(source, contains('class _SafetyCriticalFieldRemovalDialog'));
      expect(source, contains('class _SafetyCriticalFieldRemovalDialogState'));
      expect(source, contains('final _controller = TextEditingController();'));
      expect(source, contains("_reason.trim().isNotEmpty"));
      expect(source, contains('_controller.dispose();'));
      expect(
        source,
        contains("title: const Text('Safety-critical field removal')"),
      );
      expect(
        source,
        contains("Navigator.pop(context, _controller.text.trim())"),
      );

      final methodBody = _functionBody(source, '_askSafetyJustification');
      expect(methodBody, contains('showDialog<String>'));
      expect(
        methodBody,
        contains('_SafetyCriticalFieldRemovalDialog(field: field)'),
      );
      expect(methodBody, isNot(contains('TextEditingController()')));
      expect(methodBody, isNot(contains('.dispose()')));
    });

    test(
      'dialog return paths check mounted before mutating composer state',
      () {
        final removeFieldBody = _functionBody(source, '_removeField');
        expect(
          removeFieldBody,
          contains('if (!mounted || reason == null || reason.trim().isEmpty)'),
        );

        final editFieldBody = _functionBody(source, '_editField');
        expect(editFieldBody, contains('if (!mounted || edited == null)'));

        final editChecklistBody = _functionBody(source, '_editChecklistItem');
        expect(editChecklistBody, contains('if (!mounted || edited == null)'));
      },
    );

    test(
      'knowledge loading and recovery save paths avoid spurious or stale writes',
      () {
        expect(
          source,
          contains('void _setStateWithoutRecoverySave(VoidCallback fn)'),
        );
        final setStateWithoutRecoveryBody = _functionBody(
          source,
          '_setStateWithoutRecoverySave',
        );
        expect(setStateWithoutRecoveryBody, contains('try {'));
        expect(setStateWithoutRecoveryBody, contains('finally {'));
        expect(
          setStateWithoutRecoveryBody,
          contains('_suppressRecoverySave = wasSuppressing;'),
        );

        final loadKnowledgeRowsBody = _functionBody(
          source,
          '_loadKnowledgeRows',
        );
        expect(
          loadKnowledgeRowsBody,
          contains(
            '_setStateWithoutRecoverySave(() => _isLoadingKnowledge = true)',
          ),
        );
        expect(
          loadKnowledgeRowsBody,
          contains('_setStateWithoutRecoverySave(() {'),
        );

        final saveRecoveryDraftBody = _functionBody(
          source,
          '_saveRecoveryDraft',
        );
        expect(
          saveRecoveryDraftBody,
          contains('final prefs = await SharedPreferences.getInstance();'),
        );
        expect(saveRecoveryDraftBody, contains('if (!mounted)'));
        expect(saveRecoveryDraftBody, contains('return;'));

        final checkForRecoverableDraftBody = _functionBody(
          source,
          '_checkForRecoverableDraft',
        );
        expect(
          checkForRecoverableDraftBody,
          contains('_suppressRecoverySave = true;'),
        );
        expect(checkForRecoverableDraftBody, contains('try {'));
        expect(checkForRecoverableDraftBody, contains('finally {'));
        expect(
          checkForRecoverableDraftBody,
          contains('_suppressRecoverySave = false;'),
        );
      },
    );

    test('focused editor and merge UI handle stale state explicitly', () {
      final openEditorBody = _functionBody(source, '_openFocusedModuleEditor');
      expect(
        openEditorBody,
        contains('Module was removed while the editor was open.'),
      );
      expect(openEditorBody, contains('BafColors.warning'));

      expect(source, contains('() => setState(() => _mergeSelection.clear())'));
      expect(source, isNot(contains('setState(_mergeSelection.clear)')));
    });

    test('json preview truncation uses a named constant', () {
      expect(source, contains('const int _jsonPreviewMaxChars = 2200;'));
      final compactPreviewBody = _functionBody(source, '_compactPreview');
      expect(compactPreviewBody, contains('_jsonPreviewMaxChars'));
      expect(compactPreviewBody, isNot(contains('> 2200')));
      expect(compactPreviewBody, isNot(contains('substring(0, 2200)')));
    });
  });
}

String _readModuleComposerLibrary() {
  const paths = <String>[
    'lib/features/planned_maintenance/presentation/module_composer_screen.dart',
    'lib/features/planned_maintenance/presentation/module_composer_screen.builders.dart',
    'lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart',
    'lib/features/planned_maintenance/presentation/module_composer_screen.support.dart',
    'lib/features/planned_maintenance/presentation/module_composer_screen.helpers.dart',
    'lib/features/planned_maintenance/presentation/module_composer_widgets.dart',
    'lib/features/planned_maintenance/presentation/module_composer_dialogs.dart',
  ];
  return paths.map((path) => File(path).readAsStringSync()).join('\\n');
}

String _functionBody(String source, String functionName) {
  final declaration = RegExp(
    r'(?:^|\n)\s*(?:Future<[^>]+>|Future<void>|Future<String\?>|String|void|Widget|bool|int|double|List<[^>]+>)\s+' +
        RegExp.escape(functionName) +
        r'\s*\([^)]*\)\s*(?:async\s*)?\{',
    multiLine: true,
    dotAll: true,
  );

  final matches = declaration.allMatches(source).toList();
  if (matches.isEmpty) {
    fail('Could not find function declaration for $functionName');
  }

  final match = matches.last;
  final bodyStart = source.indexOf('{', match.end - 1);
  if (bodyStart < 0) {
    fail('Could not find body for $functionName');
  }

  var depth = 0;
  var inSingleQuotedString = false;
  var inDoubleQuotedString = false;
  var inLineComment = false;
  var inBlockComment = false;
  var escaping = false;

  for (var index = bodyStart; index < source.length; index += 1) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (inLineComment) {
      if (char == '\n') {
        inLineComment = false;
      }
      continue;
    }

    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        index += 1;
      }
      continue;
    }

    if (inSingleQuotedString || inDoubleQuotedString) {
      if (escaping) {
        escaping = false;
        continue;
      }
      if (char == '\\') {
        escaping = true;
        continue;
      }
      if (inSingleQuotedString && char == "'") {
        inSingleQuotedString = false;
        continue;
      }
      if (inDoubleQuotedString && char == '"') {
        inDoubleQuotedString = false;
        continue;
      }
      continue;
    }

    if (char == '/' && next == '/') {
      inLineComment = true;
      index += 1;
      continue;
    }

    if (char == '/' && next == '*') {
      inBlockComment = true;
      index += 1;
      continue;
    }

    if (char == "'") {
      inSingleQuotedString = true;
      continue;
    }

    if (char == '"') {
      inDoubleQuotedString = true;
      continue;
    }

    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(bodyStart, index + 1);
      }
    }
  }

  fail('Could not parse function body for $functionName');
}
