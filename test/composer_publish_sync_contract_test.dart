import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composer direct draft and publish actions request governance sync', () {
    final source =
        File(
          'lib/features/planned_maintenance/presentation/module_composer_screen.dart',
        ).readAsStringSync();

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
