import 'dart:convert';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_layer.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_composer_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'resuming a governed draft refreshes the visible Composer title',
    (tester) async {
      // Keep the Composer on its portrait/list layout. At >=980 logical
      // pixels the production screen deliberately switches to its wide
      // three-rail layout, whose compact left-rail merge toolbar is an
      // unrelated responsive issue and not part of this title contract.
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final actor = _adminActor();
      final package = _package();
      final savedDraft = _savedDraft();
      final repository = _FakeTemplateGovernanceRepository(
        packages: <TemplatePackage>[package],
        versionsByPackage: <String, List<TemplateVersion>>{
          package.firestoreId!: <TemplateVersion>[savedDraft],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(actor),
            ),
            templateGovernanceRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: ModuleComposerScreen(
              initialJobTemplateJson: jsonEncode(<String, dynamic>{
                'title': 'BAF governed template',
                'assetType': AssetType.base.name,
              }),
              initialModuleSnapshotsJson: '[]',
              initialFieldDefinitionsJson: '[]',
              initialChecklistJson: '[]',
              recoveryScopeId: '70f3-title-rehydration-test',
              actorUid: actor.uid,
              actorName: actor.name,
              showSaveToPublisher: false,
              knowledgeBundleLoader: _loadStaticKnowledgeBundle,
            ),
          ),
        ),
      );

      await _pumpUntilVisible(
        tester,
        find.byKey(const Key('module-composer-template-title')),
        description: 'Composer title field',
      );

      expect(_visibleTitle(tester), 'BAF governed template');

      await tester.tap(find.byTooltip('More composer actions'));
      await _pumpUntilVisible(
        tester,
        find.text('Manage Template Drafts'),
        description: 'Manage Template Drafts menu item',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Manage Template Drafts').hitTestable());
      await tester.pump();

      final resumeButton = find.byKey(
        const Key('resume-template-draft-saved-title-draft'),
      );
      await _pumpUntilVisible(
        tester,
        resumeButton,
        description: 'Saved draft resume button',
      );
      await tester.ensureVisible(resumeButton);
      await tester.pump();
      await tester.tap(resumeButton.hitTestable());

      await _pumpUntil(
        tester,
        () => _visibleTitle(tester) == 'Sample Template Package',
        description: 'rehydrated saved title',
      );

      expect(_visibleTitle(tester), 'Sample Template Package');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}

String _visibleTitle(WidgetTester tester) {
  final field = tester.widget<TextFormField>(
    find.byKey(const Key('module-composer-template-title')),
  );
  return field.controller!.text;
}

class _FakeTemplateGovernanceRepository
    implements TemplateGovernanceRepository {
  _FakeTemplateGovernanceRepository({
    required this.packages,
    required this.versionsByPackage,
  });

  final List<TemplatePackage> packages;
  final Map<String, List<TemplateVersion>> versionsByPackage;

  @override
  Future<List<TemplatePackage>> getAllPackages() async {
    return List<TemplatePackage>.unmodifiable(packages);
  }

  @override
  Future<List<TemplateVersion>> getVersionsForPackage(
    String packageFirestoreId,
  ) async {
    return List<TemplateVersion>.unmodifiable(
      versionsByPackage[packageFirestoreId] ?? const <TemplateVersion>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected TemplateGovernanceRepository call: '
      '${invocation.memberName}',
    );
  }
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  required String description,
  int maximumPumps = 80,
}) async {
  await _pumpUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    description: description,
    maximumPumps: maximumPumps,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  int maximumPumps = 80,
}) async {
  for (var index = 0; index < maximumPumps; index += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) {
      return;
    }
  }
  throw TestFailure(
    '$description did not complete after ${maximumPumps * 50} ms.',
  );
}

Future<BafKnowledgeBundle> _loadStaticKnowledgeBundle() async {
  return BafKnowledgeBundle(
    entries: BafKnowledgeLayer.entries,
    meta: BafKnowledgeMatrixMeta.staticFallback(),
    source: BafKnowledgeSource.staticFallback,
  );
}

TemplatePackage _package() {
  final timestamp = DateTime.utc(2026, 6, 16, 21);
  return TemplatePackage()
    ..firestoreId = 'title-package'
    ..packageCode = 'BAF-70F-RESTORE-20260616'
    ..title = '70F Restore Persistence Test 2026-06-16'
    ..lifecycleStatus = TemplatePackageLifecycleStatus.active
    ..isSynced = true
    ..createdAt = timestamp
    ..updatedAt = timestamp;
}

TemplateVersion _savedDraft() {
  final timestamp = DateTime.utc(2026, 6, 16, 21, 30);
  return TemplateVersion()
    ..firestoreId = 'saved-title-draft'
    ..packageFirestoreId = 'title-package'
    ..versionNumber = 1
    ..versionLabel = 'restore-persistence-v1'
    ..status = TemplateVersionStatus.draft
    ..isSynced = true
    ..jobTemplateSnapshotJson = jsonEncode(<String, dynamic>{
      'title': 'Sample Template Package',
      'templateName': 'Sample Template Package',
      'assetType': AssetType.base.name,
      'composer': <String, dynamic>{
        'draftLocalId': 'saved-title-draft',
        'closureReviewConfirmed': true,
      },
    })
    ..moduleSnapshotsJson = jsonEncode(<Map<String, dynamic>>[
      <String, dynamic>{
        'moduleCode': 'B-CLAMP-EC-01',
        'moduleTitle': 'Base Clamps',
        'assetType': AssetType.base.name,
        'discipline': 'mechanical',
        'useMode': 'scheduledPM',
        'requiredForClosure': true,
      },
    ])
    ..fieldDefinitionsJson = '[]'
    ..checklistJson = '[]'
    ..createdByUid = 'title-admin'
    ..createdByName = 'Title Admin'
    ..updatedByUid = 'title-admin'
    ..updatedByName = 'Title Admin'
    ..createdAt = timestamp
    ..updatedAt = timestamp;
}

AppUser _adminActor() {
  return AppUser(
    uid: 'title-admin',
    name: 'Title Admin',
    email: 'title-admin@example.com',
    roles: <AppRole>[AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026, 6, 16),
  );
}
