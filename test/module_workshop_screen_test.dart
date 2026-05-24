import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_module_catalogue_seed.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/module_registry_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_layer.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_workshop_published_sources.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_workshop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'module workshop shell renders draft and trusted source sections',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleWorkshopScreen(
            draftModules: [_module()],
            seedCatalogueCount: 12,
            knowledgeCatalogueCount: 34,
            publishedSourceCount: 1,
            seedModules: [BafModuleCatalogueSeed.modules.first],
            knowledgeRows: [_cloneableKnowledgeEntry()],
            publishedSources: [_publishedSource()],
            registrySources: [_registrySource()],
          ),
        ),
      );

      expect(find.text('Module Workshop'), findsOneWidget);
      expect(find.text('Draft Modules'), findsOneWidget);
      expect(find.text('Seed Catalogue'), findsOneWidget);
      expect(find.text('Knowledge Catalogue'), findsOneWidget);
      expect(find.text('Published Template Sources'), findsOneWidget);
      expect(find.text('Governed Module Registry'), findsOneWidget);
      expect(find.text('PSL13-CLAMP'), findsOneWidget);
      expect(find.text('PSL13 clamp verification'), findsOneWidget);
      expect(find.text('Open focused editor'), findsOneWidget);
      expect(find.text('Clone as draft module'), findsOneWidget);
      expect(find.text('Clone registry revision'), findsOneWidget);
    },
  );

  testWidgets('select returns the selected draft module index', (tester) async {
    ModuleWorkshopResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await Navigator.of(
                        context,
                      ).push<ModuleWorkshopResult>(
                        MaterialPageRoute(
                          builder:
                              (_) => ModuleWorkshopScreen(
                                draftModules: [_module()],
                                seedCatalogueCount: 0,
                                knowledgeCatalogueCount: 0,
                              ),
                        ),
                      );
                    },
                    child: const Text('Open shell'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open shell'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(result?.action, ModuleWorkshopResultAction.selectDraft);
    expect(result?.moduleIndex, 0);
  });

  testWidgets('seed source clone returns seed source index', (tester) async {
    ModuleWorkshopResult? result;
    final seed = BafModuleCatalogueSeed.modules.first;

    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await Navigator.of(
                        context,
                      ).push<ModuleWorkshopResult>(
                        MaterialPageRoute(
                          builder:
                              (_) => ModuleWorkshopScreen(
                                draftModules: const [],
                                seedModules: [seed],
                                knowledgeRows: const [],
                                publishedSources: const [],
                              ),
                        ),
                      );
                    },
                    child: const Text('Open shell'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open shell'));
    await tester.pumpAndSettle();

    expect(find.text(seed.moduleCode), findsOneWidget);
    await tester.tap(find.text('Clone into draft'));
    await tester.pumpAndSettle();

    expect(result?.action, ModuleWorkshopResultAction.cloneSeed);
    expect(result?.sourceIndex, 0);
  });

  testWidgets('knowledge source clone returns knowledge source index', (
    tester,
  ) async {
    ModuleWorkshopResult? result;
    final entry = _cloneableKnowledgeEntry();

    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await Navigator.of(
                        context,
                      ).push<ModuleWorkshopResult>(
                        MaterialPageRoute(
                          builder:
                              (_) => ModuleWorkshopScreen(
                                draftModules: const [],
                                seedModules: const [],
                                knowledgeRows: [entry],
                                publishedSources: const [],
                              ),
                        ),
                      );
                    },
                    child: const Text('Open shell'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open shell'));
    await tester.pumpAndSettle();

    expect(find.text(entry.moduleCandidateCode), findsOneWidget);
    await tester.tap(find.text('Clone into draft'));
    await tester.pumpAndSettle();

    expect(result?.action, ModuleWorkshopResultAction.cloneKnowledge);
    expect(result?.sourceIndex, 0);
  });

  testWidgets('published source clone returns published source index', (
    tester,
  ) async {
    ModuleWorkshopResult? result;

    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await Navigator.of(
                        context,
                      ).push<ModuleWorkshopResult>(
                        MaterialPageRoute(
                          builder:
                              (_) => ModuleWorkshopScreen(
                                draftModules: const [],
                                seedModules: const [],
                                knowledgeRows: const [],
                                publishedSources: [_publishedSource()],
                              ),
                        ),
                      );
                    },
                    child: const Text('Open shell'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open shell'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clone as draft module'));
    await tester.pumpAndSettle();

    expect(result?.action, ModuleWorkshopResultAction.clonePublishedModule);
    expect(result?.sourceIndex, 0);
  });

  testWidgets('registry source clone returns registry source index', (
    tester,
  ) async {
    ModuleWorkshopResult? result;

    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await Navigator.of(
                        context,
                      ).push<ModuleWorkshopResult>(
                        MaterialPageRoute(
                          builder:
                              (_) => ModuleWorkshopScreen(
                                draftModules: const [],
                                seedModules: const [],
                                knowledgeRows: const [],
                                publishedSources: const [],
                                registrySources: [_registrySource()],
                              ),
                        ),
                      );
                    },
                    child: const Text('Open shell'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open shell'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clone registry revision'));
    await tester.pumpAndSettle();

    expect(result?.action, ModuleWorkshopResultAction.cloneRegistryModule);
    expect(result?.sourceIndex, 0);
  });
}

BafKnowledgeEntry _cloneableKnowledgeEntry() {
  return BafKnowledgeLayer.entries.firstWhere((entry) => entry.isCloneable);
}

PublishedModuleSource _publishedSource() {
  return PublishedModuleSource(
    module:
        _module()
          ..moduleCode = 'PUBLISHED-CLAMP'
          ..title = 'Published clamp verification',
    packageFirestoreId: 'package-1',
    packageCode: 'BAF-PKG',
    packageTitle: 'BAF Published Package',
    versionFirestoreId: 'version-1',
    versionNumber: 2,
    versionLabel: 'Frozen source',
    publishedAt: DateTime.utc(2026, 1, 1),
    contentHash: 'tg2-sha256:test',
  );
}

PublishedRegistryModuleSource _registrySource() {
  final module =
      _module()
        ..moduleCode = 'REGISTRY-CLAMP'
        ..title = 'Registry clamp verification';
  final family = ModuleRegistryFamily(
    registryModuleId: 'baf.module.registry_clamp',
    moduleCode: module.moduleCode,
    canonicalTitle: module.title,
    discipline: module.discipline,
    ownerDisciplines: module.ownerDisciplines,
    assetType: module.assetType,
    functionalSection: module.functionalSection,
    componentGroup: module.componentGroup,
    targetRefs: module.targetRefs,
    deviceTagRefs: module.deviceTagRefs,
    safetyClasses: module.safetyClasses,
    requiredForClosure: module.requiredForClosure,
    latestPublishedRevisionNumber: 1,
  );
  final revision = ModuleRegistryRevision.draftFromModule(
    registryModuleId: family.registryModuleId,
    revisionId: 'registry-rev-1',
    module: module,
    actor: AppUserFake.registryActor,
    lineage: const {'sourceType': 'manual'},
    now: DateTime.utc(2026, 1, 1),
  )..publish(
    actor: AppUserFake.registryActor,
    revisionNumber: 1,
    now: DateTime.utc(2026, 1, 2),
  );
  return PublishedRegistryModuleSource(family: family, revision: revision);
}

class AppUserFake {
  static final registryActor = AppUser(
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
    fields: const [],
    checklistItems: const [],
    sourceReadiness: ComposerReadiness.readyPreset,
    confidence: KnowledgeConfidence.confirmedManual,
    authoringNotes: 'Workshop shell test fixture.',
    metadata: const {'source': 'test'},
  );
}
