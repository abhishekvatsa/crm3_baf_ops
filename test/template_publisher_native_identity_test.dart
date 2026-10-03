import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/template_publication_readiness.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/template_version_assignment_builder.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/template_publisher_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Isar database;
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'publisher_native_identity_',
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
    await database.writeTxn(() async {
      for (final key in ['parent', 'successor']) {
        await database.templatePackages.put(_package(key));
        await database.templateVersions.put(_draft(key));
      }
    });
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    final tempRoot = Directory.systemTemp.resolveSymbolicLinksSync();
    final target = directory.resolveSymbolicLinksSync();
    if (!target.startsWith(
      '$tempRoot${Platform.pathSeparator}publisher_native_identity_',
    )) {
      throw StateError(
        'Refusing cleanup outside this test temporary directory.',
      );
    }
    await directory.delete(recursive: true);
  });

  testWidgets(
    'two real publisher forks retain both native publications and original drafts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _NativeRepository(database);
      final originalDrafts = database.templateVersions.where().findAllSync();
      final originals = {
        for (final row in originalDrafts)
          row.firestoreId!: (id: row.id, map: row.toMap()),
      };
      Map<String, dynamic>? firstPublication;
      int? firstNativeId;
      for (final key in ['parent', 'successor']) {
        final package = database.templatePackages
            .filter()
            .firestoreIdEqualTo('package-$key')
            .findFirstSync()!;
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(key),
            overrides: [
              currentAppUserProvider.overrideWith(
                (ref) => Stream.value(_actor),
              ),
              templateGovernanceRepositoryProvider.overrideWithValue(
                repository,
              ),
              templatePackagesProvider.overrideWith(
                (ref) => Stream.value([package]),
              ),
              syncCoordinatorProvider.overrideWithValue(
                _TransportAcknowledgement(),
              ),
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
        final resume = find.byKey(
          ValueKey('resume-template-version-draft-$key'),
        );
        await _wait(tester, () => resume.evaluate().isNotEmpty);
        await tester.ensureVisible(resume);
        await tester.pumpAndSettle();
        await tester.tap(resume);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Publish New Version'));
        final confirm = find.byKey(
          const ValueKey('confirm-template-closure-review'),
        );
        await _wait(tester, () => confirm.evaluate().isNotEmpty);
        await tester.tap(confirm);
        await _wait(
          tester,
          () =>
              database.templatePublishAudits.where().countSync() ==
              (key == 'parent' ? 1 : 2),
        );
        await _wait(
          tester,
          () => find
              .text('Published and synchronized ${key.toUpperCase()} v2.')
              .evaluate()
              .isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (key == 'parent') {
          final first = database.templateVersions
              .filter()
              .firestoreIdEqualTo('published-parent')
              .findFirstSync()!;
          firstPublication = first.toMap();
          firstNativeId = first.id;
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      final versions = database.templateVersions.where().findAllSync();
      expect(
        versions,
        hasLength(4),
        reason:
            'Two publications must not overwrite one another or either original draft.',
      );
      final publications = versions.where((row) => row.isPublished).toList();
      expect(publications, hasLength(2));
      expect(publications.map((row) => row.id).toSet(), hasLength(2));
      expect(publications.map((row) => row.firestoreId).toSet(), hasLength(2));
      final retainedFirst = versions.singleWhere(
        (row) => row.firestoreId == 'published-parent',
      );
      expect(retainedFirst.id, firstNativeId);
      expect(retainedFirst.toMap(), firstPublication);
      for (final key in ['parent', 'successor']) {
        final original = originals['draft-$key']!;
        final retained = versions.singleWhere(
          (row) => row.firestoreId == 'draft-$key',
        );
        expect(retained.id, original.id);
        expect(retained.toMap(), original.map);
        final package = database.templatePackages
            .filter()
            .firestoreIdEqualTo('package-$key')
            .findFirstSync()!;
        final active = activeTemplateVersionForPackage(
          package: package,
          versions: versions,
        );
        expect(active, isNotNull);
        expect(active!.firestoreId, 'published-$key');
        expect(active.sourceVersionFirestoreId, 'draft-$key');
        expect(active.id, isNot(original.id));
        expect(active.isPublished, isTrue);
        expect(
          previewTemplateVersionAssignment(
            package: package,
            version: active,
          ).modules,
          hasLength(1),
        );
        final audit = database.templatePublishAudits
            .filter()
            .versionFirestoreIdEqualTo(active.firestoreId)
            .findFirstSync()!;
        expect(audit.afterHash, active.contentHash);
        expect(audit.performedByUid, _actor.uid);
      }
    },
  );
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
  }
  fail(
    'Native publisher did not reach the required visible or persisted state.',
  );
}

final _actor = AppUser(
  uid: 'si',
  name: 'SI',
  email: 'si@example.invalid',
  roles: [AppRole.si],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

TemplatePackage _package(String key) => TemplatePackage()
  ..firestoreId = 'package-$key'
  ..packageCode = key.toUpperCase()
  ..title = '$key reviewed work'
  ..assetType = 'furnace'
  ..disciplineScope = 'mechanical'
  ..latestVersionNumber = 0
  ..createdAt = DateTime.utc(2026)
  ..updatedAt = DateTime.utc(2026)
  ..isSynced = true;

TemplateVersion _draft(String key) => TemplateVersion()
  ..firestoreId = 'draft-$key'
  ..packageFirestoreId = 'package-$key'
  ..versionNumber = 1
  ..version = 1
  ..isSynced = true
  ..createdByUid = _actor.uid
  ..createdByName = _actor.name
  ..updatedByUid = _actor.uid
  ..updatedByName = _actor.name
  ..createdAt = DateTime.utc(2026)
  ..updatedAt = DateTime.utc(2026, 9, 1)
  ..jobTemplateSnapshotJson = jsonEncode({
    'jobName': '$key reviewed work',
    'assetType': 'furnace',
    'composer': {
      'closureReviewConfirmed': true,
      'closureReviewConfirmedByUid': _actor.uid,
      'closureReviewConfirmedByName': _actor.name,
      'closureReviewConfirmedAt': '2026-09-01T00:00:00.000Z',
    },
  })
  ..moduleSnapshotsJson =
      '[{"moduleCode":"M","moduleTitle":"Inspection","discipline":"mechanical","requiredForClosure":true}]'
  ..fieldDefinitionsJson =
      '[{"key":"inspection","label":"Inspection findings","moduleCode":"M","type":"text","isRequired":true}]'
  ..checklistJson = '[]'
  ..refreshContentHash();

// Only transport identity/acknowledgement is simulated. The actual screen,
// native save, publication transaction, package pointer and audit writes run.
class _NativeRepository extends IsarTemplateGovernanceRepository {
  _NativeRepository(this.database)
    : super(auditFirestoreIdFactory: () => 'audit-${++_auditNumber}');
  final Isar database;
  static int _auditNumber = 0;
  @override
  Future<void> saveVersion(
    TemplateVersion record, {
    required AppUser actor,
  }) async {
    record.firestoreId ??=
        'published-${record.packageFirestoreId!.substring('package-'.length)}';
    await super.saveVersion(record, actor: actor);
    record.isSynced = true;
    await database.writeTxn(() => database.templateVersions.put(record));
  }
}

class _TransportAcknowledgement implements SyncCoordinator {
  @override
  Future<SyncRequestOutcome> runFullSyncWithResult({
    String reason = 'unknown',
    bool force = false,
  }) async => SyncRequestOutcome.succeeded;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
