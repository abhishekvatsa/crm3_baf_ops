import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourcePath =
      'lib/features/planned_maintenance/presentation/module_registry_authoring_screen.dart';

  late String source;
  late String compact;

  setUpAll(() {
    source = File(sourcePath).readAsStringSync();
    compact = source.replaceAll(RegExp(r'\s+'), ' ');
  });

  test('67B.3 registry action wrapper reports success/failure explicitly', () {
    expect(
      source,
      contains(
        'Future<bool> _runAction(Future<void> Function(AppUser actor) action)',
      ),
    );
    expect(compact, contains('final actor = _liveGovernanceActor;'));
    expect(compact, contains('if (actor == null)'));
    expect(compact, contains('return false;'));
    expect(compact, contains('await action(actor);'));
    expect(compact, contains('_hasLiveGovernanceActor(actor.uid)'));
    expect(compact, contains('await _load(expectedActorUid: actor.uid);'));
    expect(compact, contains('return true;'));
    expect(compact, contains('catch (e)'));
    expect(compact, contains('_showSnack(e.toString(), BafColors.danger);'));
    expect(compact, contains('finally'));
    expect(compact, contains('setState(() => _busy = false);'));
  });

  test('67B.3 registry success messages are guarded by action success', () {
    final successAssignments =
        RegExp(
          r'final\s+success\s*=\s*await\s+_runAction',
        ).allMatches(source).length;

    expect(successAssignments, greaterThanOrEqualTo(5));

    final successGuards =
        RegExp(
          r'if\s*\(\s*!mounted\s*\|\|\s*!success\s*\)',
        ).allMatches(source).length;

    expect(successGuards, greaterThanOrEqualTo(5));

    expect(
      compact,
      contains(
        'final success = await _runAction( (actor) => widget.createDraft(actor, module, reason), ); '
        'if (!mounted || !success)',
      ),
    );
    expect(
      compact,
      contains(
        'final success = await _runAction( (actor) => widget.updateDraft(actor, revision, module, reason), ); '
        'if (!mounted || !success)',
      ),
    );
    expect(
      compact,
      contains(
        'final success = await _runAction( (actor) => widget.publishDraft(actor, revision, reason), ); '
        'if (!mounted || !success)',
      ),
    );
    expect(
      compact,
      contains(
        'final success = await _runAction( (actor) => widget.retireRevision(actor, source.revision, reason), ); '
        'if (!mounted || !success)',
      ),
    );
    expect(
      compact,
      contains(
        'final success = await _runAction( (actor) => widget.retireFamily(actor, family, reason), ); '
        'if (!mounted || !success)',
      ),
    );
  });

  test('67B.3 reason capture is typed and dialog-owned', () {
    expect(source, contains('Future<String?> _promptReason'));
    expect(source, contains('return showDialog<String>'));
    expect(
      source,
      contains('class _RegistryReasonDialog extends StatefulWidget'),
    );
    expect(source, contains('late final TextEditingController _controller;'));
    expect(source, contains('_controller = TextEditingController'));
    expect(source, contains('_controller.addListener(_handleReasonChanged);'));
    expect(
      source,
      contains('_controller.removeListener(_handleReasonChanged);'),
    );
    expect(source, contains('_controller.dispose();'));
  });

  test('67B.3 reason dialog validates inline before confirming', () {
    expect(
      source,
      contains('final canSubmit = value.length >= widget.minLength;'),
    );
    expect(
      source,
      contains('helperText: \'Minimum \${widget.minLength} characters.\''),
    );
    expect(source, contains('Enter at least \${widget.minLength} characters.'));
    expect(
      compact,
      contains(
        'onPressed: canSubmit ? () => Navigator.pop(context, value) : null',
      ),
    );
    expect(source, isNot(contains('Reason must be at least')));
  });

  test('67B.3 reload and snackbar paths are guarded', () {
    expect(
      compact,
      contains(
        'onPressed: _busy || _loading ? null : () => _load(expectedActorUid: actor.uid)',
      ),
    );
    expect(source, contains('void _showSnack(String message, Color color)'));
    expect(
      compact,
      contains('if (!mounted) { return; } ScaffoldMessenger.maybeOf'),
    );
    expect(source, contains('ScaffoldMessenger.maybeOf'));
  });
}
