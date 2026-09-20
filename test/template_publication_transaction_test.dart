import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Isar database;
  late Directory directory;
  late IsarTemplateGovernanceRepository repo;
  final actor = AppUser(
    uid: 'admin',
    name: 'Admin',
    email: 'admin@test.invalid',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'publication_transaction_',
    );
    database = await Isar.open(
      [
        TemplatePackageSchema,
        TemplateVersionSchema,
        TemplatePublishAuditSchema,
      ],
      directory: directory.path,
      inspector: false,
    );
    app.isar = database;
    repo = IsarTemplateGovernanceRepository(
      auditFirestoreIdFactory: () => 'audit-publication',
    );
    final package = TemplatePackage()
      ..firestoreId = 'package'
      ..packageCode = 'PKG'
      ..title = 'Test'
      ..latestVersionNumber = 0
      ..createdAt = DateTime.utc(2026)
      ..updatedAt = DateTime.utc(2026);
    final draft = TemplateVersion()
      ..firestoreId = 'draft'
      ..packageFirestoreId = 'package'
      ..versionNumber = 1
      ..version = 1
      ..isSynced = true
      ..createdAt = DateTime.utc(2026)
      ..updatedAt = DateTime.utc(2026)
      ..jobTemplateSnapshotJson = '{"jobName":"Checks","assetType":"base"}'
      ..moduleSnapshotsJson =
          '[{"moduleCode":"M","moduleTitle":"Check","requiredForClosure":false}]'
      ..fieldDefinitionsJson =
          '[{"key":"reading","moduleCode":"M","type":"number","label":"Reading"}]'
      ..checklistJson = '[]';
    await database.writeTxn(() async {
      await database.templatePackages.put(package);
      await database.templateVersions.put(draft);
    });
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });
  for (final transition in [
    'newer draft',
    'already published',
    'same revision different content',
    'renumbered',
  ]) {
    test(
      'stale publication refuses $transition without changing caller or newer row',
      () async {
        final reviewed = (await repo.getVersionByFirestoreId('draft'))!;
        final current = (await repo.getVersionByFirestoreId('draft'))!;
        if (transition == 'already published') {
          current.status = TemplateVersionStatus.published;
        }
        if (transition == 'newer draft') current.version++;
        if (transition == 'renumbered') current.versionNumber++;
        current.changeSummary = 'Retained successor work';
        current.jobTemplateSnapshotJson =
            '{"jobName":"Newer checks","assetType":"base"}';
        await database.writeTxn(() => database.templateVersions.put(current));
        await expectLater(
          repo.publishVersion(reviewed, actor: actor),
          throwsStateError,
        );
        expect(reviewed.isDraft, isTrue);
        expect(reviewed.publishedAt, isNull);
        expect(
          (await repo.getVersionByFirestoreId('draft'))!.changeSummary,
          'Retained successor work',
        );
        expect(await database.templatePublishAudits.count(), 0);
        expect(
          (await database.templatePackages.where().findFirst())!
              .activeVersionFirestoreId,
          isNull,
        );
      },
    );
  }
  test('publication commits version, pointer and audit together', () async {
    final reviewed = (await repo.getVersionByFirestoreId('draft'))!;
    await repo.publishVersion(
      reviewed,
      actor: actor,
      reason: 'Reviewed checks',
    );
    expect(reviewed.isPublished, isTrue);
    expect((await repo.getVersionByFirestoreId('draft'))!.isPublished, isTrue);
    expect(await database.templatePublishAudits.count(), 1);
    expect(
      (await database.templatePackages.where().findFirst())!
          .activeVersionFirestoreId,
      'draft',
    );
  });
  test(
    'older saved identity cannot be renumbered into current publication',
    () async {
      final package = (await database.templatePackages.where().findFirst())!
        ..latestVersionNumber = 2;
      await database.writeTxn(() => database.templatePackages.put(package));
      final reviewed = (await repo.getVersionByFirestoreId('draft'))!;
      await expectLater(
        repo.publishVersion(reviewed, actor: actor),
        throwsStateError,
      );
      expect((await repo.getVersionByFirestoreId('draft'))!.versionNumber, 1);
      expect(await database.templatePublishAudits.count(), 0);
    },
  );
}
