import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/module_registry_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_registry_authoring_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'registry authoring creates draft from selected composer module',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      ComposerModuleDraft? createdModule;
      String? createReason;

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleRegistryAuthoringScreen(
            actor: _admin(),
            draftModules: [_module()],
            loadDraftRevisions: () async => const <ModuleRegistryRevision>[],
            loadPublishedSources:
                () async => const <PublishedRegistryModuleSource>[],
            createDraft: (module, reason) async {
              createdModule = module;
              createReason = reason;
            },
            updateDraft: (revision, module, reason) async {},
            publishDraft: (revision, reason) async {},
            retireRevision: (revision, reason) async {},
            retireFamily: (family, reason) async {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Registry Authoring'), findsOneWidget);
      expect(find.text('Create registry draft'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Create registry draft'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create registry draft'), findsWidgets);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(createdModule?.moduleCode, 'PSL13-CLAMP');
      expect(createReason, contains('PSL13-CLAMP'));
    },
  );

  testWidgets('registry authoring can publish an existing draft revision', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final actor = _admin();
    final draft = ModuleRegistryRevision.draftFromModule(
      registryModuleId: 'baf.module.psl13_clamp',
      revisionId: 'draft-1',
      module: _module(),
      actor: actor,
      lineage: const {'sourceType': 'test'},
    );
    ModuleRegistryRevision? publishedRevision;
    String? publishReason;

    await tester.pumpWidget(
      MaterialApp(
        home: ModuleRegistryAuthoringScreen(
          actor: actor,
          draftModules: [_module()],
          loadDraftRevisions: () async => [draft],
          loadPublishedSources:
              () async => const <PublishedRegistryModuleSource>[],
          createDraft: (module, reason) async {},
          updateDraft: (revision, module, reason) async {},
          publishDraft: (revision, reason) async {
            publishedRevision = revision;
            publishReason = reason;
          },
          retireRevision: (revision, reason) async {},
          retireFamily: (family, reason) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Publish registry revision'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(publishedRevision?.revisionId, 'draft-1');
    expect(publishReason, contains('Approve'));
  });

  testWidgets('non-governor cannot use registry authoring actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    bool createCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ModuleRegistryAuthoringScreen(
          actor: _operator(),
          draftModules: [_module()],
          loadDraftRevisions: () async => const <ModuleRegistryRevision>[],
          loadPublishedSources:
              () async => const <PublishedRegistryModuleSource>[],
          createDraft: (module, reason) async {
            createCalled = true;
          },
          updateDraft: (revision, module, reason) async {},
          publishDraft: (revision, reason) async {},
          retireRevision: (revision, reason) async {},
          retireFamily: (family, reason) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('cannot author registry modules'),
      findsOneWidget,
    );

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create registry draft'),
    );
    expect(createButton.onPressed, isNull);
    expect(createCalled, isFalse);
  });
}

AppUser _admin() => AppUser(
  uid: 'admin-1',
  name: 'Admin User',
  email: 'admin@example.com',
  roles: const [AppRole.admin],
  isApproved: true,
  createdAt: DateTime(2026),
);

AppUser _operator() => AppUser(
  uid: 'ops-1',
  name: 'Operations User',
  email: 'ops@example.com',
  roles: const [AppRole.operations],
  isApproved: true,
  createdAt: DateTime(2026),
);

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
    authoringNotes: 'Registry authoring test fixture.',
    metadata: const {'source': 'test'},
  );
}
