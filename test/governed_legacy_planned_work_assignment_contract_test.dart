import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('governed legacy planned-work assignment contract', () {
    test('legacy assignment UI has no free-number authority', () {
      final source =
          File(
            'lib/features/planned_maintenance/presentation/assign_job_screen.dart',
          ).readAsStringSync();

      expect(source, contains('GovernedPlannedWorkAssetSelector('));
      expect(source, contains("'assignmentSchemaVersion': 2"));
      expect(source, contains("'expectedTemplateVersion':"));
      expect(source, contains("'assetClassId': selectedAsset.assetClassId"));
      expect(source, contains("'assetInstanceId': selectedAsset.id"));
      expect(source, isNot(contains('_assetNumberController')));
      expect(source, isNot(contains("'assetTypeKey':")));
      expect(source, isNot(contains("'assetNumber':")));
      expect(source, isNot(contains("'assignedAgencies':")));
    });

    test('server derives template and asset facts transactionally', () {
      final source =
          File(
            'functions/src/maintenanceWorkflow/jobCreationHandler.ts',
          ).readAsStringSync();

      expect(
        source,
        contains(r'await tx.get(`job_templates/${templateFirestoreId}`)'),
      );
      expect(
        source,
        contains(r'await tx.get(`asset_instances/${selectedInstanceId}`)'),
      );
      expect(
        source,
        contains(r'`base_inner_cover_assignments/${baseAssetInstanceId}`'),
      );
      expect(source, contains('legacy-assignment-server-owned-field'));
      expect(
        source,
        contains('source: "server_governed_legacy_template_assignment"'),
      );
      expect(source, contains('assignmentAssetIdentity:'));
      expect(source, contains('assignmentInnerCoverPosition:'));
    });

    test('both published and legacy screens share one governed selector', () {
      final published =
          File(
            'lib/features/planned_maintenance/presentation/published_template_assignment_screen.dart',
          ).readAsStringSync();
      final legacy =
          File(
            'lib/features/planned_maintenance/presentation/assign_job_screen.dart',
          ).readAsStringSync();
      final selector =
          File(
            'lib/features/planned_maintenance/presentation/governed_planned_work_asset_selector.dart',
          ).readAsStringSync();

      expect(published, contains('GovernedPlannedWorkAssetSelector('));
      expect(legacy, contains('GovernedPlannedWorkAssetSelector('));
      expect(selector, contains("'Base carrying Inner Cover'"));
      expect(selector, contains('eligibleAssets.firstWhere'));
    });
  });
}
