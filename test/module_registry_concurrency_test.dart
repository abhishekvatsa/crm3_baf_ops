import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/data/module_registry_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_registry_concurrency.dart';

void main() {
  test('accepts the exact registry draft version and content hash', () {
    final current = _revision(version: 3, hash: 'hash-3');

    expect(
      () => requireCurrentRegistryDraftMatchesExpectation(
        current: current,
        expected: const ModuleRegistryDraftExpectation(
          version: 3,
          contentHash: 'hash-3',
        ),
      ),
      returnsNormally,
    );
  });

  test('rejects stale registry draft editors', () {
    final current = _revision(version: 4, hash: 'hash-4');

    expect(
      () => requireCurrentRegistryDraftMatchesExpectation(
        current: current,
        expected: const ModuleRegistryDraftExpectation(
          version: 3,
          contentHash: 'hash-3',
        ),
      ),
      throwsA(isA<ModuleRegistryStaleDraftException>()),
    );
  });
}

ModuleRegistryRevision _revision({required int version, required String hash}) {
  return ModuleRegistryRevision(
    registryModuleId: 'baf.module.test',
    revisionId: 'draft-1',
    revisionNumber: 0,
    revisionStatus: ModuleRegistryRevisionStatus.draft,
    moduleSnapshotJson: '{}',
    fieldDefinitionsJson: '[]',
    checklistJson: '[]',
    contentHash: hash,
    lineageJson: '{}',
    version: version,
  );
}
