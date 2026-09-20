import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as storage;
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar db;
  final actor = AppUser(
    uid: 'owner',
    name: 'Owner',
    email: 'owner@test.local',
    roles: [AppRole.seniorMechanical],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('diary_review_');
    db = await Isar.open(
      [JobDiaryEntrySchema, AuditEventSchema],
      directory: directory.path,
      name: 'diary_review',
      inspector: false,
    );
    storage.isar = db;
  });
  tearDown(() async {
    await db.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });
  JobDiaryEntry seed() => JobDiaryEntry()
    ..firestoreId = 'diary-1'
    ..jobExecutionFirestoreId = 'job-1'
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..note = 'Original observed leak'
    ..createdByUid = actor.uid
    ..createdByName = actor.name
    ..updatedByUid = actor.uid
    ..updatedByName = actor.name
    ..createdAt = DateTime.utc(2026, 9, 1)
    ..updatedAt = DateTime.utc(2026, 9, 1)
    ..isSynced = true;
  JobDiaryEntry copy(JobDiaryEntry row) =>
      JobDiaryEntry.fromMap(row.toMap(), row.firestoreId!)
        ..id = row.id
        ..isSynced = row.isSynced;

  test(
    'two offline amendments keep original server basis and exact local evidence',
    () async {
      final original = seed();
      await db.writeTxn(() => db.jobDiaryEntrys.put(original));
      final repository = IsarJobDiaryRepository();
      final first = copy(original)..note = 'Leak persists after inspection';
      await repository.saveEntry(first, actor: actor);
      final second = copy((await db.jobDiaryEntrys.get(original.id))!)
        ..note = 'Leak isolated; repair still required';
      await repository.saveEntry(second, actor: actor);
      final retained = (await db.jobDiaryEntrys.get(original.id))!;
      expect(retained.version, 3);
      expect(retained.reviewedServerVersion, 1);
      expect(retained.toMap()['reviewedServerVersion'], 1);
      final audits = await db.auditEvents.where().findAll();
      expect(audits, hasLength(2));
      expect(
        jsonDecode(audits.first.beforeJson!)['note'],
        'Original observed leak',
      );
      expect(jsonDecode(audits.last.afterJson!)['note'], second.note);
    },
  );
  test('legacy dirty revision without a server basis is preserved', () async {
    final original = seed()
      ..isSynced = false
      ..version = 3;
    await db.writeTxn(() => db.jobDiaryEntrys.put(original));
    await expectLater(
      IsarJobDiaryRepository().saveEntry(
        copy(original)..note = 'New text',
        actor: actor,
      ),
      throwsStateError,
    );
    expect((await db.jobDiaryEntrys.get(original.id))!.note, original.note);
    expect(await db.auditEvents.count(), 0);
  });
  test(
    'a blank observation is not silently replaced with progress note',
    () async {
      final row = seed()
        ..id = Isar.autoIncrement
        ..note = '  ';
      await expectLater(
        IsarJobDiaryRepository().saveEntry(row, actor: actor),
        throwsStateError,
      );
      expect(await db.jobDiaryEntrys.count(), 0);
    },
  );
}
