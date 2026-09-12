import 'dart:async';
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'saved draft replacement stays guarded until its original author returns',
    (tester) async {
      final harness = await _mount(tester);
      await _openReplacement(tester);
      harness.actors.addError(StateError('account refresh failed'));
      await tester.pumpAndSettle();
      expect(find.text('Open saved draft'), findsNothing);
      expect(find.text('Account verification required'), findsOneWidget);
      expect(harness.prefs.getString(harness.key), harness.bytes);
      harness.actors.add(_actor('other-author'));
      await tester.pumpAndSettle();
      expect(find.text('Open saved draft'), findsNothing);
      expect(harness.prefs.getString(harness.key), harness.bytes);
      await _restoreOriginalActor(tester, harness);
      expect(_title(tester), 'Original author working draft');
      expect(find.text('Open saved draft'), findsOneWidget);
      await tester.tap(find.text('Open saved draft'));
      await tester.pumpAndSettle();
      expect(_title(tester), 'Saved governed draft');
      expect(harness.prefs.containsKey(harness.key), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final changeAccount in [false, true]) {
    testWidgets(
      'account ${changeAccount ? 'switch' : 'failure'} during recovery lookup retains exact bytes and working draft',
      (tester) async {
        final gate = Completer<SharedPreferences>();
        var clearReads = 0;
        final harness = await _mount(
          tester,
          loadRecovery: () {
            clearReads++;
            return gate.future;
          },
        );
        await _openReplacement(tester);
        await tester.tap(find.text('Open saved draft'));
        await tester.pumpAndSettle();
        expect(clearReads, 1);
        if (changeAccount) {
          harness.actors.add(_actor('other-author'));
        } else {
          harness.actors.addError(StateError('account refresh failed'));
        }
        await tester.pumpAndSettle();
        gate.complete(harness.prefs);
        await tester.pumpAndSettle();
        expect(harness.prefs.getString(harness.key), harness.bytes);
        await _restoreOriginalActor(tester, harness);
        expect(_title(tester), 'Original author working draft');
        expect(harness.prefs.getString(harness.key), harness.bytes);
        expect(clearReads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<_Harness> _mount(
  WidgetTester tester, {
  Future<SharedPreferences> Function()? loadRecovery,
}) async {
  await tester.binding.setSurfaceSize(const Size(600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final actors = StreamController<AppUser?>();
  addTearDown(actors.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => actors.stream),
        templateGovernanceRepositoryProvider.overrideWithValue(
          _DraftRepository(),
        ),
        if (loadRecovery != null)
          moduleComposerRecoveryPreferencesProvider.overrideWithValue(
            loadRecovery,
          ),
      ],
      child: MaterialApp(
        home: ModuleComposerScreen(
          initialJobTemplateJson: '{}',
          initialModuleSnapshotsJson: '[]',
          initialFieldDefinitionsJson: '[]',
          initialChecklistJson: '[]',
          knowledgeBundleLoader: () async => BafKnowledgeBundle(
            entries: BafKnowledgeLayer.entries,
            meta: BafKnowledgeMatrixMeta.staticFallback(),
            source: BafKnowledgeSource.staticFallback,
          ),
        ),
      ),
    ),
  );
  actors.add(_actor('original-author'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('module-composer-template-title')),
    'Original author working draft',
  );
  await tester.tap(find.byTooltip('Add blank module'));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  final prefs = await SharedPreferences.getInstance();
  final key = prefs.getKeys().singleWhere(
    (key) => key.startsWith('RECOVERY::'),
  );
  return _Harness(actors, prefs, key, prefs.getString(key)!);
}

Future<void> _openReplacement(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More composer actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Manage Template Drafts'));
  await tester.pumpAndSettle();
  final resume = find.byKey(const Key('resume-template-draft-saved-draft'));
  await tester.ensureVisible(resume);
  await tester.tap(resume);
  await tester.pumpAndSettle();
  expect(find.text('Replace current composer draft?'), findsOneWidget);
}

Future<void> _restoreOriginalActor(
  WidgetTester tester,
  _Harness harness,
) async {
  harness.actors.add(_actor('original-author'));
  await tester.pumpAndSettle();
  // Reverification also offers the independently retained recovery snapshot.
  if (find.text('Recover unsaved composer draft?').evaluate().isNotEmpty) {
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
  }
}

String _title(WidgetTester tester) => tester
    .widget<TextFormField>(
      find.byKey(const Key('module-composer-template-title')),
    )
    .controller!
    .text;

class _Harness {
  _Harness(this.actors, this.prefs, this.key, this.bytes);
  final StreamController<AppUser?> actors;
  final SharedPreferences prefs;
  final String key, bytes;
}

class _DraftRepository extends Fake implements TemplateGovernanceRepository {
  @override
  Future<List<TemplatePackage>> getAllPackages() async => [
    TemplatePackage()
      ..firestoreId = 'package'
      ..packageCode = 'SAVED'
      ..title = 'Saved package'
      ..lifecycleStatus = TemplatePackageLifecycleStatus.active
      ..createdAt = DateTime.utc(2026)
      ..updatedAt = DateTime.utc(2026),
  ];

  @override
  Future<List<TemplateVersion>> getVersionsForPackage(String id) async => [
    TemplateVersion()
      ..firestoreId = 'saved-draft'
      ..packageFirestoreId = 'package'
      ..versionNumber = 1
      ..status = TemplateVersionStatus.draft
      ..jobTemplateSnapshotJson = jsonEncode({
        'title': 'Saved governed draft',
        'assetType': AssetType.base.name,
      })
      ..moduleSnapshotsJson = jsonEncode([
        {
          'moduleCode': 'BASE',
          'moduleTitle': 'Base inspection',
          'assetType': AssetType.base.name,
          'discipline': 'mechanical',
          'useMode': 'scheduledPM',
          'requiredForClosure': false,
        },
      ])
      ..fieldDefinitionsJson = '[]'
      ..checklistJson = '[]'
      ..createdByUid = 'original-author'
      ..createdByName = 'Original author'
      ..updatedByUid = 'original-author'
      ..updatedByName = 'Original author'
      ..createdAt = DateTime.utc(2026)
      ..updatedAt = DateTime.utc(2026),
  ];
}

AppUser _actor(String uid) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.com',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
