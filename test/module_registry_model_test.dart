import 'dart:convert';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/module_registry_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry draft revision round trips to composer module', () {
    final actor = _actor();
    final source = _module();
    final revision = ModuleRegistryRevision.draftFromModule(
      registryModuleId: moduleRegistryIdForModule(source),
      revisionId: 'draft-1',
      module: source,
      actor: actor,
      lineage: const {'sourceType': 'manual'},
      now: DateTime.utc(2026, 1, 1),
    );

    expect(revision.revisionStatus, ModuleRegistryRevisionStatus.draft);
    expect(revision.revisionNumber, 0);
    expect(revision.contentHash, startsWith('mrg1-sha256:'));

    final restored = revision.toComposerModuleDraft();
    expect(restored.moduleCode, source.moduleCode);
    expect(restored.title, source.title);
    expect(restored.fields.single.key, 'switch_state');
    expect(restored.checklistItems.single.linkedFieldKey, 'switch_state');
  });

  test('clone registry module into draft records registry lineage', () {
    final actor = _actor();
    final source = _module();
    final family = ModuleRegistryFamily.fromModule(
      module: source,
      actor: actor,
      now: DateTime.utc(2026, 1, 1),
    );
    final revision = ModuleRegistryRevision.draftFromModule(
      registryModuleId: family.registryModuleId,
      revisionId: 'rev-1',
      module: source,
      actor: actor,
      lineage: const {'sourceType': 'manual'},
      now: DateTime.utc(2026, 1, 1),
    )..publish(actor: actor, revisionNumber: 1, now: DateTime.utc(2026, 1, 2));

    final clone = cloneRegistryModuleIntoDraft(
      source: PublishedRegistryModuleSource(family: family, revision: revision),
      existingModules: const <ComposerModuleDraft>[],
      now: DateTime.utc(2026, 1, 3),
    );

    expect(clone.moduleCode, 'PSL13-CLAMP-COPY');
    expect(clone.metadata['source'], 'publishedRegistryRevision');
    expect(clone.metadata['sourceRegistryModuleId'], family.registryModuleId);
    expect(clone.metadata['sourceRegistryRevisionNumber'], 1);
    expect(clone.authoringNotes, contains('governed registry'));
  });

  test('registry revision rehydrates alias-linked fields and checklist', () {
    final actor = _actor();
    final source = _module();
    final revision =
        ModuleRegistryRevision.draftFromModule(
            registryModuleId: moduleRegistryIdForModule(source),
            revisionId: 'draft-alias',
            module: source,
            actor: actor,
            lineage: const {'sourceType': 'manual'},
            now: DateTime.utc(2026, 1, 1),
          )
          ..moduleSnapshotJson = jsonEncode({
            'moduleId': 'ALIAS-MODULE',
            'moduleTitle': 'Alias module',
            'discipline': JobModuleDiscipline.shared.name,
          })
          ..fieldDefinitionsJson = jsonEncode([
            {
              'templateModuleId': 'ALIAS-MODULE',
              'key': 'alias_field',
              'label': 'Alias field',
              'type': ComposerFieldType.text.name,
              'order': 1,
            },
          ])
          ..checklistJson = jsonEncode([
            {
              'parentModuleCode': 'ALIAS-MODULE',
              'id': 'alias_check',
              'title': 'Alias check',
              'order': 1,
            },
          ]);

    final restored = revision.toComposerModuleDraft();

    expect(restored.moduleCode, 'ALIAS-MODULE');
    expect(restored.fields.single.key, 'alias_field');
    expect(restored.checklistItems.single.id, 'alias_check');
  });

  test(
    'registry publish rejects malformed or mismatched snapshot payloads',
    () {
      final actor = _actor();
      final source = _module();
      final revision = ModuleRegistryRevision.draftFromModule(
        registryModuleId: moduleRegistryIdForModule(source),
        revisionId: 'draft-invalid-json',
        module: source,
        actor: actor,
        lineage: const {'sourceType': 'manual'},
        now: DateTime.utc(2026, 1, 1),
      )..fieldDefinitionsJson = '[malformed';

      expect(
        () => revision.publish(
          actor: actor,
          revisionNumber: 1,
          now: DateTime.utc(2026, 1, 2),
        ),
        throwsStateError,
      );

      final mismatched = ModuleRegistryRevision.draftFromModule(
        registryModuleId: moduleRegistryIdForModule(source),
        revisionId: 'draft-hash-mismatch',
        module: source,
        actor: actor,
        lineage: const {'sourceType': 'manual'},
        now: DateTime.utc(2026, 1, 1),
      )..contentHash = 'mrg1-sha256:not-the-current-hash';

      expect(
        () => mismatched.publish(
          actor: actor,
          revisionNumber: 1,
          now: DateTime.utc(2026, 1, 2),
        ),
        throwsStateError,
      );
    },
  );
  test('registry family round trips latest published hash pointers', () {
    final family =
        ModuleRegistryFamily.fromModule(
            module: _module(),
            actor: _actor(),
            now: DateTime.utc(2026, 1, 1),
          )
          ..latestPublishedRevisionNumber = 3
          ..latestPublishedRevisionId = 'revision-3'
          ..latestPublishedContentHash =
              'mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    final restored = ModuleRegistryFamily.fromMap(
      family.toMap(),
      family.registryModuleId,
    );

    expect(restored.latestPublishedRevisionNumber, 3);
    expect(restored.latestPublishedRevisionId, 'revision-3');
    expect(
      restored.latestPublishedContentHash,
      'mrg1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
  });
}

AppUser _actor() {
  return AppUser(
    uid: 'si1',
    name: 'SI User',
    email: 'si@test.local',
    roles: const [AppRole.si],
    isApproved: true,
    createdAt: DateTime.utc(2026, 1, 1),
  );
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
    authoringNotes: 'Registry model test fixture.',
    metadata: const {'source': 'test'},
  );
}
