import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_json_builder.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_workshop_merge.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/publish_metadata_builder.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/publish_metadata_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'composer semantic fingerprint ignores generatedAt but detects edits',
    () {
      final draft = _draft();
      final first = ModuleComposerJsonBuilder.semanticFingerprint(draft);
      final second = ModuleComposerJsonBuilder.semanticFingerprint(draft);

      expect(second, first);

      draft.title = 'Changed title';
      expect(
        ModuleComposerJsonBuilder.semanticFingerprint(draft),
        isNot(first),
      );
    },
  );

  test('domain builder rejects moving a resumed draft across packages', () {
    final existing =
        TemplateVersion()
          ..firestoreId = 'version-draft-42'
          ..packageFirestoreId = 'pkg-original'
          ..versionNumber = 6
          ..status = TemplateVersionStatus.draft
          ..jobTemplateSnapshotJson = '{}'
          ..moduleSnapshotsJson = '[]'
          ..fieldDefinitionsJson = '[]'
          ..checklistJson = '[]'
          ..createdAt = DateTime(2026, 6, 1)
          ..updatedAt = DateTime(2026, 6, 2);
    final targetPackage = _package()..firestoreId = 'pkg-other';

    expect(
      () => buildTemplateVersionForPublish(
        input: _publishInput(),
        draft: _draft(),
        package: targetPackage,
        nextVersionNumber: 99,
        existingVersion: existing,
        actor: _admin(),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('cannot be moved to another package'),
        ),
      ),
    );
  });

  test('domain builder preserves exact saved payload for publish', () {
    final existing =
        TemplateVersion()
          ..firestoreId = 'version-draft-42'
          ..packageFirestoreId = 'pkg-std'
          ..versionNumber = 6
          ..status = TemplateVersionStatus.draft
          ..jobTemplateSnapshotJson =
              '{"title":"persisted","composer":{"closureReviewConfirmed":true}}'
          ..moduleSnapshotsJson = '[{"moduleCode":"PERSISTED"}]'
          ..fieldDefinitionsJson = '[{"key":"persisted_field"}]'
          ..checklistJson = '[{"id":"persisted_item"}]'
          ..targetRefs = <String>['persisted-target']
          ..deviceTagRefs = <String>['persisted-tag']
          ..procedureRefs = <String>['persisted-procedure']
          ..operationalStatePreconditions = <String>['persisted-precondition']
          ..safetyClass = 'gasRisk'
          ..createdAt = DateTime(2026, 6, 1)
          ..updatedAt = DateTime(2026, 6, 2);

    final result = buildTemplateVersionForPublish(
      input: _publishInput(),
      draft: _draft(),
      package: _package(),
      nextVersionNumber: 99,
      existingVersion: existing,
      preserveExistingPayload: true,
      actor: _admin(),
    );

    expect(result, same(existing));
    expect(result.jobTemplateSnapshotJson, contains('persisted'));
    expect(result.moduleSnapshotsJson, contains('PERSISTED'));
    expect(result.fieldDefinitionsJson, contains('persisted_field'));
    expect(result.checklistJson, contains('persisted_item'));
    expect(result.targetRefs, <String>['persisted-target']);
    expect(result.deviceTagRefs, <String>['persisted-tag']);
    expect(result.procedureRefs, <String>['persisted-procedure']);
    expect(result.operationalStatePreconditions, <String>[
      'persisted-precondition',
    ]);
    expect(result.safetyClass, 'gasRisk');
  });

  testWidgets('publish requires a nonblank reason while save draft does not', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    TemplateVersion? savedDraft;
    TemplateVersion? published;
    String? capturedReason;

    final actions = PublishMetadataDialogActions(
      savePackage: (package, actor) async {
        package.firestoreId ??= 'pkg-fresh';
      },
      saveVersionDraft: (version, actor) async {
        savedDraft = version;
        return version;
      },
      publishVersion: (version, actor, reason) async {
        published = version;
        capturedReason = reason;
        return version;
      },
      nextVersionNumberFor: (package) async => 3,
    );

    await _pumpDialog(
      tester,
      actor: _admin(),
      draft: _draft(),
      packages: [_package()],
      actions: actions,
    );

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('publish-publish')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('publish-save-draft')))
          .onPressed,
      isNotNull,
    );

    await tester.enterText(find.byKey(const Key('publish-reason')), 'x');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('publish-publish')))
          .onPressed,
      isNotNull,
    );

    await tester.enterText(
      find.byKey(const Key('publish-reason')),
      'Adequate publish reason text',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('publish-publish')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('publish-publish')));
    await tester.pumpAndSettle();

    expect(published, isNotNull);
    expect(savedDraft, isNull);
    expect(capturedReason, 'Adequate publish reason text');
    expect(published!.packageFirestoreId, 'pkg-std');
    expect(published!.versionNumber, 3);
    expect(published!.status, TemplateVersionStatus.draft);
  });

  testWidgets('save draft builds composer payload version', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    TemplateVersion? saved;
    final actions = PublishMetadataDialogActions(
      savePackage: (package, actor) async {},
      saveVersionDraft: (version, actor) async {
        saved = version;
        return version;
      },
      publishVersion: (version, actor, reason) async => version,
      nextVersionNumberFor: (package) async => 1,
    );

    await _pumpDialog(
      tester,
      actor: _admin(),
      draft: _draft(),
      packages: [_package()],
      actions: actions,
    );

    await tester.tap(find.byKey(const Key('publish-save-draft')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.jobTemplateSnapshotJson, isNotEmpty);
    expect(saved!.moduleSnapshotsJson, isNotEmpty);
    expect(saved!.fieldDefinitionsJson, isNotEmpty);
    expect(saved!.checklistJson, isNotEmpty);
    expect(saved!.versionNumber, 1);
    expect(saved!.contentHash, isNotEmpty);
  });

  testWidgets('new package draft flow persists package before version', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    TemplatePackage? savedPackage;
    TemplateVersion? savedVersion;
    final actions = PublishMetadataDialogActions(
      savePackage: (package, actor) async {
        savedPackage = package;
        package.firestoreId = 'pkg-new';
      },
      saveVersionDraft: (version, actor) async {
        savedVersion = version;
        return version;
      },
      publishVersion: (version, actor, reason) async => version,
      nextVersionNumberFor: (package) async => 1,
    );

    await _pumpDialog(
      tester,
      actor: _admin(),
      draft: _draft(),
      packages: const <TemplatePackage>[],
      actions: actions,
    );

    await tester.enterText(
      find.byKey(const Key('publish-new-package-code')),
      'BAF.NEW',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('publish-save-draft')));
    await tester.pumpAndSettle();

    expect(savedPackage, isNotNull);
    expect(savedPackage!.packageCode, 'BAF.NEW');
    expect(savedVersion, isNotNull);
    expect(savedVersion!.packageFirestoreId, 'pkg-new');
  });

  testWidgets('resumed draft preserves identity and version number on save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final existing =
        TemplateVersion()
          ..id = 42
          ..firestoreId = 'version-draft-42'
          ..packageFirestoreId = 'pkg-std'
          ..versionNumber = 6
          ..versionLabel = 'Existing draft'
          ..status = TemplateVersionStatus.draft
          ..jobTemplateSnapshotJson = '{}'
          ..moduleSnapshotsJson = '[]'
          ..fieldDefinitionsJson = '[]'
          ..checklistJson = '[]'
          ..createdAt = DateTime(2026, 6, 1)
          ..updatedAt = DateTime(2026, 6, 2)
          ..createdByUid = 'si1'
          ..createdByName = 'SI User';

    TemplateVersion? saved;
    final actions = PublishMetadataDialogActions(
      savePackage: (package, actor) async {},
      saveVersionDraft: (version, actor) async {
        saved = version;
        return version;
      },
      publishVersion: (version, actor, reason) async => version,
      nextVersionNumberFor: (package) async => 99,
    );

    await _pumpDialog(
      tester,
      actor: _admin(),
      draft: _draft(),
      packages: [_package()],
      actions: actions,
      initialPackageFirestoreId: 'pkg-std',
      initialVersion: existing,
    );

    expect(find.text('Existing draft'), findsOneWidget);
    await tester.tap(find.byKey(const Key('publish-save-draft')));
    await tester.pumpAndSettle();

    expect(saved, same(existing));
    expect(saved!.id, 42);
    expect(saved!.firestoreId, 'version-draft-42');
    expect(saved!.versionNumber, 6);
    expect(saved!.createdAt, DateTime(2026, 6, 1));
  });

  testWidgets('resumed draft pending sync can save but cannot publish', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final existing =
        TemplateVersion()
          ..firestoreId = 'version-draft-42'
          ..packageFirestoreId = 'pkg-std'
          ..versionNumber = 6
          ..versionLabel = 'Pending draft'
          ..status = TemplateVersionStatus.draft
          ..jobTemplateSnapshotJson = '{}'
          ..moduleSnapshotsJson = '[]'
          ..fieldDefinitionsJson = '[]'
          ..checklistJson = '[]'
          ..createdAt = DateTime(2026, 6, 1)
          ..updatedAt = DateTime(2026, 6, 2)
          ..isSynced = false;

    final actions = PublishMetadataDialogActions(
      savePackage: (package, actor) async {},
      saveVersionDraft: (version, actor) async => version,
      publishVersion: (version, actor, reason) async => version,
      nextVersionNumberFor: (package) async => 99,
    );

    await _pumpDialog(
      tester,
      actor: _admin(),
      draft: _draft(),
      packages: [_package()],
      actions: actions,
      initialPackageFirestoreId: 'pkg-std',
      initialVersion: existing,
    );

    await tester.enterText(
      find.byKey(const Key('publish-reason')),
      'Adequate publish reason text',
    );
    await tester.pump();

    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('publish-save-draft')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('publish-publish')))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('pending sync'), findsOneWidget);
  });

  testWidgets(
    'resumed draft with unsaved Composer changes can save but cannot publish',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final existing =
          TemplateVersion()
            ..firestoreId = 'version-draft-42'
            ..packageFirestoreId = 'pkg-std'
            ..versionNumber = 6
            ..versionLabel = 'Existing draft'
            ..status = TemplateVersionStatus.draft
            ..jobTemplateSnapshotJson = '{}'
            ..moduleSnapshotsJson = '[]'
            ..fieldDefinitionsJson = '[]'
            ..checklistJson = '[]'
            ..createdAt = DateTime(2026, 6, 1)
            ..updatedAt = DateTime(2026, 6, 2);

      final actions = PublishMetadataDialogActions(
        savePackage: (package, actor) async {},
        saveVersionDraft: (version, actor) async => version,
        publishVersion: (version, actor, reason) async => version,
        nextVersionNumberFor: (package) async => 99,
      );

      await _pumpDialog(
        tester,
        actor: _admin(),
        draft: _draft(),
        packages: [_package()],
        actions: actions,
        initialPackageFirestoreId: 'pkg-std',
        initialVersion: existing,
        hasUnsavedComposerChanges: true,
      );

      await tester.enterText(
        find.byKey(const Key('publish-reason')),
        'Adequate publish reason text',
      );
      await tester.pump();

      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('publish-save-draft')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('publish-publish')))
            .onPressed,
        isNull,
      );
      expect(
        find.textContaining('exact last-saved governed payload'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'non-draft initial version shows a handled error and disables actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final published =
          TemplateVersion()
            ..firestoreId = 'version-published-7'
            ..packageFirestoreId = 'pkg-std'
            ..versionNumber = 7
            ..status = TemplateVersionStatus.published
            ..jobTemplateSnapshotJson = '{}'
            ..moduleSnapshotsJson = '[]'
            ..fieldDefinitionsJson = '[]'
            ..checklistJson = '[]'
            ..createdAt = DateTime(2026, 6, 1)
            ..updatedAt = DateTime(2026, 6, 2);

      final actions = PublishMetadataDialogActions(
        savePackage: (package, actor) async {},
        saveVersionDraft: (version, actor) async => version,
        publishVersion: (version, actor, reason) async => version,
        nextVersionNumberFor: (package) async => 8,
      );

      await _pumpDialog(
        tester,
        actor: _admin(),
        draft: _draft(),
        packages: [_package()],
        actions: actions,
        initialPackageFirestoreId: 'pkg-std',
        initialVersion: published,
      );

      expect(
        find.text('Only draft TemplateVersions can be resumed.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('publish-save-draft')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('publish-publish')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('unresolved merge conflicts block save and publish', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final actions = PublishMetadataDialogActions(
      savePackage: (package, actor) async {},
      saveVersionDraft: (version, actor) async => version,
      publishVersion: (version, actor, reason) async => version,
      nextVersionNumberFor: (package) async => 1,
    );

    await _pumpDialog(
      tester,
      actor: _admin(),
      draft: _draft(unresolvedMerge: true),
      packages: [_package()],
      actions: actions,
    );

    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('publish-save-draft')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('publish-publish')))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('unresolved merge conflicts'), findsWidgets);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required AppUser actor,
  required TemplateComposerDraft draft,
  required List<TemplatePackage> packages,
  required PublishMetadataDialogActions actions,
  String? initialPackageFirestoreId,
  TemplateVersion? initialVersion,
  bool hasUnsavedComposerChanges = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed:
                      () => PublishMetadataDialog.show(
                        context,
                        actor: actor,
                        draft: draft,
                        existingPackages: packages,
                        actions: actions,
                        initialPackageFirestoreId: initialPackageFirestoreId,
                        initialVersion: initialVersion,
                        hasUnsavedComposerChanges: hasUnsavedComposerChanges,
                      ),
                  child: const Text('Open'),
                ),
              ),
            ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

PublishMetadataInput _publishInput() {
  return const PublishMetadataInput(
    packageCode: 'BAF.STD',
    packageTitle: 'BAF Standard',
    packageDescription: 'Fixture package',
    assetType: AssetType.base,
    assetNumberScope: '',
    disciplineScope: <String>{'mechanical'},
    versionLabel: 'Resumed draft',
    releaseNotes: 'Fixture release notes',
    changeSummary: 'Fixture change summary',
    minAppVersion: '',
    publishReason: 'Adequate publish reason',
  );
}

AppUser _admin() {
  return AppUser(
    uid: 'si1',
    name: 'SI User',
    email: 'si1@test.local',
    roles: const [AppRole.admin],
    isApproved: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

TemplatePackage _package() {
  return TemplatePackage()
    ..firestoreId = 'pkg-std'
    ..packageCode = 'BAF.STD'
    ..title = 'BAF Standard'
    ..disciplineScope = 'mechanical'
    ..assetType = AssetType.base.name
    ..createdAt = DateTime(2026, 1, 1)
    ..updatedAt = DateTime(2026, 1, 1);
}

TemplateComposerDraft _draft({bool unresolvedMerge = false}) {
  return TemplateComposerDraft(
    title: 'Test draft',
    assetType: AssetType.base,
    modules: [_module(unresolvedMerge: unresolvedMerge)],
    closureReviewConfirmed: true,
  );
}

ComposerModuleDraft _module({bool unresolvedMerge = false}) {
  return ComposerModuleDraft(
    localId: 'local-M-A',
    moduleCode: 'M-A',
    title: 'Module A',
    description: 'Fixture',
    assetType: AssetType.base,
    discipline: JobModuleDiscipline.mechanical,
    ownerDisciplines: const ['mechanical'],
    primaryOwner: 'mechanical',
    requiresJointReview: false,
    useMode: JobModuleUseMode.scheduledPM,
    functionalSection: 'Test',
    componentGroup: 'Test',
    subsystem: 'Test',
    safetyClasses: const ['normal'],
    targetRefs: const <String>[],
    deviceTagRefs: const <String>[],
    procedureRefs: const <String>[],
    partRefs: const <String>[],
    operationalStatePreconditions: const <String>[],
    requiredForClosure: false,
    frequency: MaintenanceFrequency.everyCharge,
    fields: <ComposerFieldDraft>[
      ComposerFieldDraft(
        key: 'ok',
        label: 'OK',
        type: ComposerFieldType.yesNo,
        isRequired: true,
        order: 1,
      ),
    ],
    checklistItems: const <ComposerChecklistItemDraft>[],
    sourceReadiness: ComposerReadiness.readyPreset,
    confidence: KnowledgeConfidence.confirmedManual,
    authoringNotes: 'Test fixture.',
    metadata:
        unresolvedMerge
            ? <String, dynamic>{
              mergeConflictWorkspaceMetadataKey: <String, dynamic>{
                'status': 'unresolved',
                'conflicts': <Map<String, dynamic>>[
                  <String, dynamic>{'summary': 'Resolve fixture conflict.'},
                ],
              },
            }
            : const <String, dynamic>{'source': 'test'},
  );
}
