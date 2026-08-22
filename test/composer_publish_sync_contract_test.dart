import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composer direct draft and publish actions request governance sync', () {
    final source = _readModuleComposerLibrary();

    expect(
      source,
      contains("import '../../../core/services/sync_coordinator.dart';"),
    );
    expect(source, contains('syncCoordinatorProvider'));
    expect(source, contains('template_governance_draft_saved_from_composer'));
    expect(source, contains('saveAndRefreshComposerTemplateVersionDraft('));
    expect(source, contains('runFullSyncWithResult('));
    expect(source, contains('reloadLocal: repository.getVersionByFirestoreId'));
    expect(
      source,
      contains('template_governance_version_published_from_composer'),
    );
    expect(source, contains('publishAndRefreshComposerTemplateVersion('));
    expect(
      source,
      contains('template_governance_draft_archived_from_composer'),
    );
    expect(
      source,
      contains('template_governance_draft_restored_from_composer'),
    );
    expect(
      source,
      contains(r'Published and sync-confirmed for ${package.packageCode}.'),
    );
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
    'lib/features/planned_maintenance/presentation/widgets/publish_metadata_dialog.dart',
  ];
  return paths.map((path) => File(path).readAsStringSync()).join('\\n');
}
