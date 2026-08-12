import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_registry_content_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry content hash is stable for equivalent module content', () {
    final first = moduleRegistrySnapshotFromDraft(_module());
    final second = moduleRegistrySnapshotFromDraft(_module());

    expect(first.contentHash, second.contentHash);
    expect(first.contentHash, startsWith('mrg1-sha256:'));
  });

  test('registry content hash changes when module content changes', () {
    final first = moduleRegistrySnapshotFromDraft(_module());
    final changed = _module()..title = 'Changed clamp verification';
    final second = moduleRegistrySnapshotFromDraft(changed);

    expect(first.contentHash, isNot(second.contentHash));
  });

  test('strict registry content hash rejects malformed JSON payloads', () {
    expect(
      () => stableModuleRegistryContentHashStrict(
        moduleSnapshotJson: '{malformed',
        fieldDefinitionsJson: '[]',
        checklistJson: '[]',
      ),
      throwsFormatException,
    );

    const malformedBundle = ModuleRegistrySnapshotBundle(
      moduleSnapshotJson: '{malformed',
      fieldDefinitionsJson: '[]',
      checklistJson: '[]',
    );
    expect(() => malformedBundle.moduleSnapshot, throwsFormatException);
  });

  test('strict registry payload validation rejects hash mismatch', () {
    final snapshot = moduleRegistrySnapshotFromDraft(_module());

    expect(
      () => validateModuleRegistrySnapshotPayload(
        moduleSnapshotJson: snapshot.moduleSnapshotJson,
        fieldDefinitionsJson: snapshot.fieldDefinitionsJson,
        checklistJson: snapshot.checklistJson,
        expectedContentHash: 'mrg1-sha256:not-the-current-hash',
      ),
      throwsFormatException,
    );
  });
}

ComposerModuleDraft _module() {
  return ComposerModuleDraft(
    localId: 'psl13-clamp',
    moduleCode: 'PSL13-CLAMP',
    title: 'PSL13 clamp verification',
    description: 'Verify clamp low-pressure switch and joint ownership.',
    assetType: AssetType.base,
    discipline: JobModuleDiscipline.shared,
    ownerDisciplines: const ['mechanical', 'instrumentation'],
    primaryOwner: 'mechanical',
    requiresJointReview: true,
    useMode: JobModuleUseMode.scheduledPM,
    functionalSection: 'Hydraulic clamp',
    componentGroup: 'PSL13',
    subsystem: 'Clamp pressure',
    safetyClasses: const ['hydraulic', 'interlock'],
    targetRefs: const ['PSL13'],
    deviceTagRefs: const ['PSL13-LP-SW'],
    procedureRefs: const ['BAF-PSL13'],
    partRefs: const [],
    operationalStatePreconditions: const ['LOTO verified'],
    requiredForClosure: true,
    frequency: MaintenanceFrequency.everyCharge,
    fields: [
      ComposerFieldDraft(
        key: 'switch_state',
        label: 'Switch state',
        type: ComposerFieldType.passFail,
        isRequired: true,
        order: 1,
      ),
    ],
    checklistItems: [
      ComposerChecklistItemDraft(
        id: 'PSL13-CLAMP-item-1',
        title: 'Verify switch changes state',
        isRequired: true,
        order: 1,
        linkedFieldKey: 'switch_state',
      ),
    ],
    sourceReadiness: ComposerReadiness.readyPreset,
    confidence: KnowledgeConfidence.confirmedManual,
    authoringNotes: 'Registry hash test fixture.',
    metadata: const {'source': 'test'},
  );
}
