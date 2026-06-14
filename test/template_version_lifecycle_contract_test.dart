import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('TemplateVersion draft resume lifecycle contract', () {
    test('module-first composer exposes saved draft discovery', () {
      final builders = _read(
        'lib/features/planned_maintenance/presentation/module_composer_screen.builders.dart',
      );
      final actions = _read(
        'lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart',
      );

      expect(builders, contains('Open Saved Template Drafts'));
      expect(actions, contains('Future<void> _openSavedTemplateDrafts()'));
      expect(actions, contains('version.isDraft'));
      expect(actions, contains('TemplateComposerDraft.fromPayloads'));
      expect(actions, contains('_editingTemplateVersion = selected.version'));
    });

    test('resumed draft identity is carried into publish metadata', () {
      final composer = _read(
        'lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart',
      );
      final dialog = _read(
        'lib/features/planned_maintenance/presentation/widgets/publish_metadata_dialog.dart',
      );
      final builder = _read(
        'lib/features/planned_maintenance/domain/publish_metadata_builder.dart',
      );

      expect(composer, contains('initialVersion: _editingTemplateVersion'));
      expect(dialog, contains('final TemplateVersion? initialVersion'));
      expect(dialog, contains('existingVersion: widget.initialVersion'));
      expect(
        dialog,
        contains('preserveExistingPayload: widget.initialVersion != null'),
      );
      expect(
        builder,
        contains('final version = existingVersion ?? TemplateVersion()'),
      );
      expect(builder, contains('preserveExistingPayload = false'));
      expect(builder, contains('existingVersion?.versionNumber ??'));
    });

    test('save and publish return the same persisted draft context', () {
      final dialog = _read(
        'lib/features/planned_maintenance/presentation/widgets/publish_metadata_dialog.dart',
      );
      final composer = _read(
        'lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart',
      );

      expect(dialog, contains('PublishMetadataDialogResult.saved(saved)'));
      expect(
        dialog,
        contains('PublishMetadataDialogResult.published(published)'),
      );
      expect(
        composer,
        contains(
          '_editingTemplateVersion = result.published ? null : result.version',
        ),
      );
    });

    test('composer fingerprints resumed state and blocks dirty publish', () {
      final screen = _read(
        'lib/features/planned_maintenance/presentation/module_composer_screen.dart',
      );
      final actions = _read(
        'lib/features/planned_maintenance/presentation/module_composer_screen.actions.dart',
      );
      final builder = _read(
        'lib/features/planned_maintenance/domain/module_composer_json_builder.dart',
      );
      final dialog = _read(
        'lib/features/planned_maintenance/presentation/widgets/publish_metadata_dialog.dart',
      );

      expect(screen, contains('_editingTemplateDraftFingerprint'));
      expect(builder, contains('semanticFingerprint'));
      expect(builder, contains("job.remove('generatedAt')"));
      expect(actions, contains('hasUnsavedComposerChanges:'));
      expect(dialog, contains('widget.hasUnsavedComposerChanges'));
      expect(
        dialog,
        contains(
          'Save Draft to synchronize the same record before publishing.',
        ),
      );
    });

    test('saved drafts require successful sync before publication', () {
      final dialog = _read(
        'lib/features/planned_maintenance/presentation/widgets/publish_metadata_dialog.dart',
      );
      final provider = _read(
        'lib/features/planned_maintenance/providers/template_governance_provider.dart',
      );

      expect(dialog, contains('!widget.initialVersion!.isSynced'));
      expect(dialog, contains('confirmed by sync'));
      expect(
        provider,
        contains('A saved TemplateVersion draft must sync successfully'),
      );
    });

    test('legacy publisher also resumes and publishes the same draft record', () {
      final builders = _read(
        'lib/features/planned_maintenance/presentation/template_publisher_screen.builders.dart',
      );
      final support = _read(
        'lib/features/planned_maintenance/presentation/template_publisher_screen.support.dart',
      );
      final actions = _read(
        'lib/features/planned_maintenance/presentation/template_publisher_screen.actions.dart',
      );
      final sections = _read(
        'lib/features/planned_maintenance/presentation/template_publisher_sections.dart',
      );

      expect(builders, contains('onResumeDraft'));
      expect(sections, contains("label: const Text('Resume draft')"));
      expect(support, contains('void _resumeDraft('));
      expect(support, contains('_workingDraft = _cloneVersion(source)'));
      expect(actions, isNot(contains('allocateFreshVersionNumber: true')));
      expect(
        actions,
        contains('_workingDraft != null && version.versionNumber > 0'),
      );
    });

    test('resumed drafts cannot be moved across packages', () {
      final dialog = _read(
        'lib/features/planned_maintenance/presentation/widgets/publish_metadata_dialog.dart',
      );

      expect(
        dialog,
        contains(
          'A resumed TemplateVersion draft cannot be moved to another package.',
        ),
      );
    });
  });
}
