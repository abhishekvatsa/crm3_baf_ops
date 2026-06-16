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
    'Composer lists archived drafts and exposes only synchronized restore',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final actor = _adminActor();
      final package = _package();
      final synchronized = _archivedVersion(
        firestoreId: 'archived-synced',
        versionNumber: 4,
        label: 'Synchronized archived draft',
        isSynced: true,
      );
      final pending = _archivedVersion(
        firestoreId: 'archived-pending',
        versionNumber: 5,
        label: 'Pending archived draft',
        isSynced: false,
      );
      final repository = _FakeTemplateGovernanceRepository(
        packages: <TemplatePackage>[package],
        versionsByPackage: <String, List<TemplateVersion>>{
          package.firestoreId!: <TemplateVersion>[synchronized, pending],
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
              initialJobTemplateJson: '{}',
              initialModuleSnapshotsJson: '[]',
              initialFieldDefinitionsJson: '[]',
              initialChecklistJson: '[]',
              recoveryScopeId: '70f1-thin-ui-test',
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
        find.byTooltip('More composer actions'),
        description: 'Module Composer actions button',
      );

      // Let the overridden current-user stream and static knowledge loader
      // complete without waiting for the entire screen to globally settle.
      await _pumpFrames(tester, count: 6);

      await tester.tap(find.byTooltip('More composer actions'));
      await _pumpUntilVisible(
        tester,
        find.text('Manage Template Drafts'),
        description: 'Manage Template Drafts menu item',
      );

      // The popup item becomes visible before the route transition stops
      // ignoring pointer input. Wait for the menu animation, then tap only
      // the hit-testable production item.
      await tester.pump(const Duration(milliseconds: 500));
      final manageDraftsItem =
          find.text('Manage Template Drafts').hitTestable();
      expect(manageDraftsItem, findsOneWidget);
      await tester.tap(manageDraftsItem);
      await tester.pump();

      await _pumpUntilVisible(
        tester,
        find.text('Governed Template Drafts'),
        description: 'Governed Template Drafts dialog',
      );

      expect(find.text('Archived drafts (2)'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('archived-template-draft-archived-synced'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('archived-template-draft-archived-pending'),
        ),
        findsOneWidget,
      );

      final synchronizedRestore = find.byKey(
        const ValueKey<String>('restore-template-draft-archived-synced'),
      );
      final pendingRestore = find.byKey(
        const ValueKey<String>('restore-template-draft-archived-pending'),
      );

      expect(synchronizedRestore, findsOneWidget);
      expect(pendingRestore, findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(synchronizedRestore).onPressed,
        isNotNull,
      );
      expect(tester.widget<OutlinedButton>(pendingRestore).onPressed, isNull);
      expect(find.text('Restore draft'), findsOneWidget);
      expect(find.text('Awaiting archived state sync'), findsOneWidget);

      // Prove that the enabled action reaches the production reason dialog.
      // Do not submit the restore here; repository lifecycle authority is
      // covered by template_governance_70f_archive_test.dart.
      await tester.ensureVisible(synchronizedRestore);
      await tester.tap(synchronizedRestore);
      await _pumpUntilVisible(
        tester,
        find.text('Restore archived draft?'),
        description: 'Restore reason dialog',
      );

      expect(
        find.byKey(const Key('restore-template-draft-reason')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('confirm-restore-template-draft')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.restoreCalls, 0);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await _pumpFrames(tester, count: 4);
      expect(find.text('Restore archived draft?'), findsNothing);
      expect(repository.restoreCalls, 0);

      // Explicitly dispose the full Composer so no recovery timer, route,
      // text-input client, or provider remains alive during test finalization.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}

class _FakeTemplateGovernanceRepository
    implements TemplateGovernanceRepository {
  _FakeTemplateGovernanceRepository({
    required this.packages,
    required this.versionsByPackage,
  });

  final List<TemplatePackage> packages;
  final Map<String, List<TemplateVersion>> versionsByPackage;
  int restoreCalls = 0;

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
  Future<void> restoreArchivedDraftVersion(
    TemplateVersion record, {
    required AppUser actor,
    required String reason,
  }) async {
    restoreCalls += 1;
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
  for (var index = 0; index < maximumPumps; index += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  throw TestFailure(
    '$description did not become visible after '
    '${maximumPumps * 50} ms of bounded pumping.',
  );
}

Future<void> _pumpFrames(WidgetTester tester, {required int count}) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<BafKnowledgeBundle> _loadStaticKnowledgeBundle() async {
  return BafKnowledgeBundle(
    entries: BafKnowledgeLayer.entries,
    meta: BafKnowledgeMatrixMeta.staticFallback(),
    source: BafKnowledgeSource.staticFallback,
  );
}

TemplatePackage _package() {
  final timestamp = DateTime.utc(2026, 6, 16, 6);
  return TemplatePackage()
    ..firestoreId = 'package-ui'
    ..packageCode = 'PKG-UI'
    ..title = 'Restore UI package'
    ..lifecycleStatus = TemplatePackageLifecycleStatus.active
    ..isSynced = true
    ..createdAt = timestamp
    ..updatedAt = timestamp;
}

TemplateVersion _archivedVersion({
  required String firestoreId,
  required int versionNumber,
  required String label,
  required bool isSynced,
}) {
  final timestamp = DateTime.utc(2026, 6, 16, 6, versionNumber);
  return TemplateVersion()
    ..firestoreId = firestoreId
    ..packageFirestoreId = 'package-ui'
    ..versionNumber = versionNumber
    ..versionLabel = label
    ..status = TemplateVersionStatus.archived
    ..isSynced = isSynced
    ..jobTemplateSnapshotJson = '{}'
    ..moduleSnapshotsJson = '[]'
    ..fieldDefinitionsJson = '[]'
    ..checklistJson = '[]'
    ..createdByUid = 'restore-ui-admin'
    ..createdByName = 'Restore UI Admin'
    ..updatedByUid = 'restore-ui-admin'
    ..updatedByName = 'Restore UI Admin'
    ..createdAt = timestamp
    ..updatedAt = timestamp;
}

AppUser _adminActor() {
  return AppUser(
    uid: 'restore-ui-admin',
    name: 'Restore UI Admin',
    email: 'restore-ui@example.com',
    roles: <AppRole>[AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026, 6, 16),
  );
}
