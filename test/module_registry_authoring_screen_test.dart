import 'dart:async';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/module_registry_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_registry_authoring_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      AppUser? mutationActor;

      await tester.pumpWidget(
        _withActor(
          _admin(),
          ModuleRegistryAuthoringScreen(
            draftModules: [_module()],
            loadDraftRevisions: () async => const <ModuleRegistryRevision>[],
            loadPublishedSources:
                () async => const <PublishedRegistryModuleSource>[],
            createDraft: (actor, module, reason) async {
              mutationActor = actor;
              createdModule = module;
              createReason = reason;
            },
            updateDraft: (actor, revision, module, reason) async {},
            publishDraft: (actor, revision, reason) async {},
            retireRevision: (actor, revision, reason) async {},
            retireFamily: (actor, family, reason) async {},
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
      expect(mutationActor?.uid, _admin().uid);
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
      _withActor(
        actor,
        ModuleRegistryAuthoringScreen(
          draftModules: [_module()],
          loadDraftRevisions: () async => [draft],
          loadPublishedSources:
              () async => const <PublishedRegistryModuleSource>[],
          createDraft: (actor, module, reason) async {},
          updateDraft: (actor, revision, module, reason) async {},
          publishDraft: (actor, revision, reason) async {
            publishedRevision = revision;
            publishReason = reason;
          },
          retireRevision: (actor, revision, reason) async {},
          retireFamily: (actor, family, reason) async {},
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
    var registryReads = 0;

    await tester.pumpWidget(
      _withActor(
        _operator(),
        ModuleRegistryAuthoringScreen(
          draftModules: [_module()],
          loadDraftRevisions: () async {
            registryReads++;
            return const <ModuleRegistryRevision>[];
          },
          loadPublishedSources: () async {
            registryReads++;
            return const <PublishedRegistryModuleSource>[];
          },
          createDraft: (actor, module, reason) async {
            createCalled = true;
          },
          updateDraft: (actor, revision, module, reason) async {},
          publishDraft: (actor, revision, reason) async {},
          retireRevision: (actor, revision, reason) async {},
          retireFamily: (actor, family, reason) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Registry authoring access required'), findsOneWidget);
    expect(find.text('Create registry draft'), findsNothing);
    expect(registryReads, 0);
    expect(createCalled, isFalse);
  });

  testWidgets(
    'malformed governance timeline is visible and blocks authoring actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      bool createCalled = false;
      await tester.pumpWidget(
        _withActor(
          _admin(),
          ModuleRegistryAuthoringScreen(
            draftModules: [_module()],
            loadDraftRevisions: () async {
              throw PersistedDataFormatException(
                field: 'updatedAt',
                source: 'module_registry/family-1',
              );
            },
            loadPublishedSources:
                () async => const <PublishedRegistryModuleSource>[],
            createDraft: (actor, module, reason) async {
              createCalled = true;
            },
            updateDraft: (actor, revision, module, reason) async {},
            publishDraft: (actor, revision, reason) async {},
            retireRevision: (actor, revision, reason) async {},
            retireFamily: (actor, family, reason) async {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Governance timeline needs repair'), findsOneWidget);
      expect(find.textContaining('Actions are disabled'), findsOneWidget);
      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create registry draft'),
      );
      expect(createButton.onPressed, isNull);
      expect(createCalled, isFalse);
    },
  );

  testWidgets('live role downgrade closes loaded registry data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final actors = StreamController<AppUser?>();
    addTearDown(actors.close);
    actors.add(_admin());
    var registryReads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => actors.stream),
        ],
        child: MaterialApp(
          home: ModuleRegistryAuthoringScreen(
            draftModules: [_module()],
            loadDraftRevisions: () async {
              registryReads++;
              return const <ModuleRegistryRevision>[];
            },
            loadPublishedSources: () async {
              registryReads++;
              return const <PublishedRegistryModuleSource>[];
            },
            createDraft: (actor, module, reason) async {},
            updateDraft: (actor, revision, module, reason) async {},
            publishDraft: (actor, revision, reason) async {},
            retireRevision: (actor, revision, reason) async {},
            retireFamily: (actor, family, reason) async {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Create registry draft'), findsOneWidget);
    expect(registryReads, 2);

    actors.add(_operator());
    await tester.pumpAndSettle();

    expect(find.text('Registry authoring access required'), findsOneWidget);
    expect(find.text('Create registry draft'), findsNothing);
    expect(registryReads, 2);
  });
}

Widget _withActor(AppUser actor, Widget home) {
  return ProviderScope(
    overrides: [
      currentAppUserProvider.overrideWith(
        (ref) => Stream<AppUser?>.value(actor),
      ),
    ],
    child: MaterialApp(home: home),
  );
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
