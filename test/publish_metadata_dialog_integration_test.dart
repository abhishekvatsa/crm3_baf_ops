import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_layer.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_composer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'composer exposes prepare publish path only for template governors',
    (tester) async {
      await _pumpComposer(tester, _user(AppRole.admin));

      expect(find.byTooltip('More composer actions'), findsOneWidget);
      expect(find.byTooltip('Prepare Publish'), findsNothing);
      expect(find.text('Save to Publisher'), findsNothing);

      await tester.tap(find.byTooltip('More composer actions'));
      await tester.pumpAndSettle();

      expect(find.text('Open Saved Template Drafts'), findsOneWidget);
      expect(find.text('Prepare Publish'), findsOneWidget);
      expect(find.text('Save to Publisher'), findsOneWidget);
    },
  );

  testWidgets(
    'home-launched standalone composer hides publisher handoff and keeps cloud seed action',
    (tester) async {
      await _pumpComposer(
        tester,
        _user(AppRole.admin),
        showSaveToPublisher: false,
        canSeedCloudKnowledge: true,
      );

      expect(find.byTooltip('More composer actions'), findsOneWidget);
      expect(find.text('Save to Publisher'), findsNothing);

      final seedCloudAction = find.text('Seed cloud baseline');
      await tester.scrollUntilVisible(
        seedCloudAction,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(seedCloudAction, findsOneWidget);

      await tester.tap(find.byTooltip('More composer actions'));
      await tester.pumpAndSettle();

      expect(find.text('Open Saved Template Drafts'), findsOneWidget);
      expect(find.text('Prepare Publish'), findsOneWidget);
      expect(find.text('Save to Publisher'), findsNothing);
    },
  );

  testWidgets('composer app bar stays compact on phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 891));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await _pumpComposer(tester, _user(AppRole.admin));

    expect(find.byTooltip('More composer actions'), findsOneWidget);
    expect(find.byTooltip('Open Module Workshop'), findsNothing);
    expect(find.byTooltip('Open Registry Authoring'), findsNothing);
    expect(find.byTooltip('Prepare Publish'), findsNothing);
    expect(find.text('Save to Publisher'), findsNothing);

    await tester.tap(find.byTooltip('More composer actions'));
    await tester.pumpAndSettle();

    expect(find.text('Open Saved Template Drafts'), findsOneWidget);
    expect(find.text('Open Module Workshop'), findsOneWidget);
    expect(find.text('Open Registry Authoring'), findsOneWidget);
    expect(find.text('Prepare Publish'), findsOneWidget);
    expect(find.text('Save to Publisher'), findsOneWidget);
    expect(find.text('Preview JSON'), findsOneWidget);
  });

  testWidgets('composer hides prepare publish path for non-governors', (
    tester,
  ) async {
    await _pumpComposer(tester, _user(AppRole.operations));

    expect(find.byTooltip('More composer actions'), findsOneWidget);
    expect(find.text('Prepare Publish'), findsNothing);
    expect(find.text('Save to Publisher'), findsNothing);

    await tester.tap(find.byTooltip('More composer actions'));
    await tester.pumpAndSettle();

    expect(find.text('Prepare Publish'), findsNothing);
    expect(find.text('Save to Publisher'), findsOneWidget);
  });
}

Future<void> _pumpComposer(
  WidgetTester tester,
  AppUser actor, {
  bool showSaveToPublisher = true,
  bool canSeedCloudKnowledge = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(actor)),
      ],
      child: MaterialApp(
        home: ModuleComposerScreen(
          initialJobTemplateJson: '{}',
          initialModuleSnapshotsJson: '[]',
          initialFieldDefinitionsJson: '[]',
          initialChecklistJson: '[]',
          recoveryScopeId: 'publish-metadata-integration-test',
          actorUid: 'test-actor',
          actorName: 'Test Actor',
          canSeedCloudKnowledge: canSeedCloudKnowledge,
          showSaveToPublisher: showSaveToPublisher,
          knowledgeBundleLoader: _loadStaticKnowledgeBundle,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<BafKnowledgeBundle> _loadStaticKnowledgeBundle() async {
  return BafKnowledgeBundle(
    entries: BafKnowledgeLayer.entries,
    meta: BafKnowledgeMatrixMeta.staticFallback(),
    source: BafKnowledgeSource.staticFallback,
  );
}

AppUser _user(AppRole role) {
  return AppUser(
    uid: 'user-${role.name}',
    name: 'User ${role.name}',
    email: '${role.name}@example.com',
    roles: [role],
    isApproved: true,
    createdAt: DateTime(2026),
  );
}
