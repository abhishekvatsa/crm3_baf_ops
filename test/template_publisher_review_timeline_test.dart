import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/template_publisher_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';

void main() {
  for (final action in ['confirm', 'cancel', 'revokeAfterPackage']) {
    final confirm = action != 'cancel';
    final revokeAfterPackage = action == 'revokeAfterPackage';
    testWidgets(
      'actual resumed publisher $action preserves review and authority',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = _Repository();
        final actors = StreamController<AppUser?>();
        addTearDown(actors.close);
        final packageWrite = Completer<void>();
        if (revokeAfterPackage) {
          repo.onSavePackage = () => packageWrite.future;
        }
        final original = repo.source.toMap();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith((ref) => actors.stream),
              templateGovernanceRepositoryProvider.overrideWithValue(repo),
              syncCoordinatorProvider.overrideWithValue(_Coordinator()),
              maintenanceClassDefinitionsProvider.overrideWith(
                (ref) => Stream.value(
                  const DecodedSnapshotBatch<MaintenanceClassDefinition>(
                    records: [],
                    rejectedDocumentIds: [],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: TemplatePublisherScreen()),
          ),
        );
        actors.add(actor);
        await tester.pumpAndSettle();
        final resume = find.byKey(
          const Key('resume-template-version-reviewed-draft'),
        );
        await tester.ensureVisible(resume);
        await tester.pumpAndSettle();
        await tester.tap(resume);
        await tester.pumpAndSettle();
        final title = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Package title',
        );
        await tester.enterText(title, 'Reviewed work amended title');
        await tester.tap(find.text('Publish New Version'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          repo.readErrors,
          isEmpty,
          reason: 'producer must not persist copied review before creation',
        );
        expect(find.text('Review closure requirements'), findsOneWidget);
        expect(repo.saved, isEmpty);
        expect(repo.packageWrites, 0);
        await tester.tap(
          confirm
              ? find.byKey(const ValueKey('confirm-template-closure-review'))
              : find.text('Cancel'),
        );
        if (revokeAfterPackage) {
          await tester.pump(const Duration(milliseconds: 500));
          expect(repo.packageWrites, 1);
          actors.add(
            AppUser(
              uid: actor.uid,
              name: actor.name,
              email: actor.email,
              roles: const [],
              isApproved: true,
              createdAt: actor.createdAt,
            ),
          );
          await tester.pump();
          packageWrite.complete();
        }
        await tester.pumpAndSettle();
        expect(repo.source.toMap(), original);
        if (revokeAfterPackage) {
          expect(repo.saved, isEmpty);
          expect(repo.published, isEmpty);
        } else if (confirm) {
          expect(repo.saved, hasLength(1));
          final saved = repo.saved.single;
          expect(saved.sourceVersionFirestoreId, 'reviewed-draft');
          expect(saved.closureReviewConfirmedByUid, actor.uid);
          expect(
            saved.closureReviewConfirmedAt!.isBefore(saved.createdAt),
            isFalse,
          );
          expect(
            saved.closureReviewConfirmedAt,
            isNot(repo.source.closureReviewConfirmedAt),
          );
          expect(
            TemplateVersion.fromMap(
              saved.toMap(),
              saved.firestoreId!,
            ).closureReviewConfirmed,
            isTrue,
          );
          expect(repo.published, hasLength(1));
        } else {
          expect(repo.saved, isEmpty);
          expect(repo.published, isEmpty);
          expect(repo.packageWrites, 0);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final actor = AppUser(
  uid: 'si',
  name: 'SI',
  email: 'si@example.invalid',
  roles: [AppRole.si],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

class _Coordinator implements SyncCoordinator {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements TemplateGovernanceRepository {
  final package = TemplatePackage()
    ..firestoreId = 'package'
    ..packageCode = 'DEV'
    ..title = 'Reviewed work'
    ..assetType = 'furnace'
    ..disciplineScope = 'mechanical'
    ..latestVersionNumber = 0
    ..createdAt = DateTime.utc(2026)
    ..updatedAt = DateTime.utc(2026)
    ..isSynced = true;
  late final source = TemplateVersion()
    ..firestoreId = 'reviewed-draft'
    ..packageFirestoreId = 'package'
    ..versionNumber = 1
    ..version = 1
    ..isSynced = true
    ..createdByUid = actor.uid
    ..createdByName = actor.name
    ..updatedByUid = actor.uid
    ..updatedByName = actor.name
    ..createdAt = DateTime.utc(2026)
    ..updatedAt = DateTime.utc(2026, 9, 1)
    ..jobTemplateSnapshotJson = jsonEncode({
      'jobName': 'Reviewed work',
      'assetType': 'furnace',
      'composer': {
        'closureReviewConfirmed': true,
        'closureReviewConfirmedByUid': actor.uid,
        'closureReviewConfirmedByName': actor.name,
        'closureReviewConfirmedAt': '2026-09-01T00:00:00.000Z',
      },
    })
    ..moduleSnapshotsJson =
        '[{"moduleCode":"M","moduleTitle":"Inspection","discipline":"mechanical","requiredForClosure":true}]'
    ..fieldDefinitionsJson =
        '[{"key":"inspection","label":"Inspection findings","moduleCode":"M","type":"text","isRequired":true}]'
    ..checklistJson = '[]'
    ..refreshContentHash();
  final saved = <TemplateVersion>[];
  final published = <TemplateVersion>[];
  final readErrors = <Object>[];
  int packageWrites = 0;
  Future<void> Function()? onSavePackage;
  @override
  Future<void> savePackage(
    TemplatePackage value, {
    required AppUser actor,
  }) async {
    packageWrites++;
    await onSavePackage?.call();
  }

  @override
  Stream<List<TemplatePackage>> watchPackages({int? limit}) =>
      Stream.value([package]);
  @override
  Stream<List<TemplateVersion>> watchVersionsForPackage(String id) =>
      Stream.value([source]);
  @override
  Future<List<TemplateVersion>> getVersionsForPackage(String id) async => [
    source,
  ];
  @override
  Future<void> saveVersion(
    TemplateVersion version, {
    required AppUser actor,
  }) async {
    version.firestoreId ??= 'successor';
    version
      ..updatedAt = DateTime.now()
      ..createdByUid ??= actor.uid
      ..createdByName ??= actor.name
      ..updatedByUid = actor.uid
      ..updatedByName = actor.name;
    version.refreshContentHash();
    try {
      TemplateVersion.fromMap(version.toMap(), version.firestoreId!);
    } catch (error) {
      readErrors.add(error);
      rethrow;
    }
    version.isSynced = true;
    saved.add(version);
  }

  @override
  Future<TemplateVersion?> getVersionByFirestoreId(String id) async =>
      saved.where((v) => v.firestoreId == id).firstOrNull;
  @override
  Future<void> publishVersion(
    TemplateVersion version, {
    required AppUser actor,
    String? reason,
  }) async {
    published.add(version);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
