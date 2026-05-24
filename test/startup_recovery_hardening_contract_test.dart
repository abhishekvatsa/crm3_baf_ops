import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readMain() => File('lib/main.dart').readAsStringSync();

String _blockStartingAt(String source, String marker) {
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: 'Missing marker: $marker');
  final open = _bodyBraceIndex(source, start);
  expect(open, isNonNegative, reason: 'Missing opening brace for: $marker');

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

  fail('Could not close block for marker: $marker');
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

void main() {
  group('67B.9 main.dart startup recovery hardening', () {
    test(
      'rebuild confirmation dialog owns controller and disables destructive action until REBUILD',
      () {
        final source = _readMain();
        final confirmMethod = _blockStartingAt(
          source,
          'Future<void> _confirmAndRebuildLocalDatabase()',
        );
        final dialogClass = _blockStartingAt(
          source,
          'class _RebuildLocalDatabaseConfirmDialogState',
        );

        expect(confirmMethod, contains('showDialog<bool>'));
        expect(confirmMethod, contains('barrierDismissible: false'));
        expect(confirmMethod, contains('_RebuildLocalDatabaseConfirmDialog'));
        expect(
          confirmMethod,
          contains(
            'builder: (_) => const _RebuildLocalDatabaseConfirmDialog(),',
          ),
        );
        expect(
          confirmMethod,
          isNot(contains('final controller = TextEditingController')),
        );
        expect(confirmMethod, isNot(contains('controller.dispose()')));
        expect(confirmMethod, contains('if (!mounted || confirmed != true)'));

        expect(
          dialogClass,
          contains('late final TextEditingController _controller;'),
        );
        expect(
          dialogClass,
          contains('_controller.addListener(_handleChanged);'),
        );
        expect(
          dialogClass,
          contains('_controller.removeListener(_handleChanged);'),
        );
        expect(
          dialogClass,
          contains("final canSubmit = confirmation == 'REBUILD';"),
        );
        expect(dialogClass, contains('onPressed: canSubmit'));
      },
    );

    test(
      'startup recovery actions cannot overlap backup, retry and rebuild flows',
      () {
        final source = _readMain();
        final retryMethod = _blockStartingAt(
          source,
          'Future<void> _retryLocalDatabaseOpen()',
        );
        final backupMethod = _blockStartingAt(
          source,
          'Future<void> _backupLocalDatabaseForRecovery()',
        );
        final rebuildMethod = _blockStartingAt(
          source,
          'Future<void> _rebuildLocalDatabaseAfterRecoveryBackup',
        );
        final localErrorScreen = _blockStartingAt(
          source,
          'class _LocalDatabaseStartupErrorScreen',
        );

        expect(retryMethod, contains('_isBackingUpLocalDatabase'));
        expect(retryMethod, contains('_isRebuildingLocalDatabase'));
        expect(retryMethod, contains('finally'));
        expect(
          retryMethod,
          contains('setState(() => _isRetryingLocalDatabaseOpen = false)'),
        );
        expect(backupMethod, contains('_isRetryingLocalDatabaseOpen'));
        expect(backupMethod, contains('_isRebuildingLocalDatabase'));
        expect(backupMethod, contains('finally'));
        expect(
          backupMethod,
          contains('setState(() => _isBackingUpLocalDatabase = false)'),
        );
        expect(rebuildMethod, contains('_isBackingUpLocalDatabase'));
        expect(rebuildMethod, contains('_isRetryingLocalDatabaseOpen'));
        expect(rebuildMethod, contains('finally'));
        expect(
          rebuildMethod,
          contains('setState(() => _isRebuildingLocalDatabase = false)'),
        );

        expect(localErrorScreen, contains('!isRetrying'));
        expect(localErrorScreen, contains('!isBackingUp'));
        expect(localErrorScreen, contains('!isRebuilding'));
      },
    );

    test('startup diagnostics snackbar uses mounted-safe maybeOf helper', () {
      final source = _readMain();
      final helper = _blockStartingAt(source, 'void _showStartupSnack');

      expect(helper, contains('if (!context.mounted)'));
      expect(
        helper,
        contains('final messenger = ScaffoldMessenger.maybeOf(context);'),
      );
      expect(source, isNot(contains('ScaffoldMessenger.of(context)')));
      expect(source, contains('_showStartupSnack('));
    });

    test(
      'main.dart does not reintroduce single-line if-return lifecycle guards',
      () {
        final source = _readMain();
        final oneLineReturn = RegExp(
          r'^\s*if \([^\n{}]+\) return[^;]*;',
          multiLine: true,
        );

        expect(
          oneLineReturn.firstMatch(source)?.group(0),
          isNull,
          reason: 'Use braced if blocks in startup/lifecycle code.',
        );
        expect(
          RegExp(r'if \(!mounted\) \{\s*\n\s*\n\s*return;').firstMatch(source),
          isNull,
          reason: 'Avoid merge-artifact blank lines inside mounted guards.',
        );
      },
    );
  });
}
