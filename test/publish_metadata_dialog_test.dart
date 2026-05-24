import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_workshop_merge.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/publish_metadata_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'publish is disabled until reason is long enough while save draft works',
    (tester) async {
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
        },
        publishVersion: (version, actor, reason) async {
          published = version;
          capturedReason = reason;
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

      await tester.enterText(
        find.byKey(const Key('publish-reason')),
        'too short',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('publish-publish')))
            .onPressed,
        isNull,
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
    },
  );

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
      },
      publishVersion: (version, actor, reason) async {},
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
      },
      publishVersion: (version, actor, reason) async {},
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

  testWidgets('unresolved merge conflicts block save and publish', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final actions = PublishMetadataDialogActions(
      savePackage: (package, actor) async {},
      saveVersionDraft: (version, actor) async {},
      publishVersion: (version, actor, reason) async {},
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
