import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_correction_promoter.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/runtime_module_lineage.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'malformed correction snapshot cannot produce a promotion candidate',
    () {
      final result = KnowledgeCorrectionPromoter.harvestFromTemplateSnapshot(
        jobTemplateSnapshotJson: '{not-json',
        sourceTemplateVersionId: 'version-1',
        sourceTemplatePackageCode: 'package-1',
        sourceTemplateVersionNumber: 1,
        harvestedAt: DateTime.utc(2026, 8, 12),
      );

      expect(result, isEmpty);
    },
  );

  test('malformed lineage JSON remains display-only unknown state', () {
    final module =
        JobModuleInstance()
          ..moduleTitle = 'Legacy module'
          ..metadataJson = '{not-json'
          ..moduleSnapshotJson = '{also-not-json';

    final lineage = RuntimeModuleLineageInfo.fromModule(module);

    expect(lineage.isGovernedPublishedSource, isFalse);
    expect(lineage.source, RuntimeModuleLineageSource.legacyOrManual);
  });
}
