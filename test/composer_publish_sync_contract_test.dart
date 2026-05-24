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
    expect(
      source,
      contains('void _triggerTemplateGovernanceSync(String reason)'),
    );
    expect(source, contains('template_governance_draft_saved_from_composer'));
    expect(
      source,
      contains('template_governance_version_published_from_composer'),
    );
    expect(source, contains('runFullSync(reason: reason, force: true)'));
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
