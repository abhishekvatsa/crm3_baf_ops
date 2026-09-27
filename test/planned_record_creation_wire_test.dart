// Real Isar and repository writers; only Firestore transport is replaced.
// The transport checks Rules' pinned origin and diary audit-state equality.
// ignore_for_file: subtype_of_sealed_class
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart' hide Query;

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  final created = DateTime.utc(2026, 9, 10, 12, 30);
  final actor = AppUser(
    uid: 'si',
    name: 'SI',
    email: 'si@example.invalid',
    roles: [AppRole.si],
    isApproved: true,
    createdAt: created,
  );
  late Isar database;
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('planned_origin_wire_');
    database = await Isar.open(
      [JobExecutionSchema, JobDiaryEntrySchema],
      directory: directory.path,
      inspector: false,
    );
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  Map<String, dynamic> executionSeed(Object wire) =>
      (JobExecution()
            ..firestoreId = 'record'
            ..templateFirestoreId = 'legacy-template'
            ..assetType = AssetType.base
            ..assetNumber = 101
            ..assignedByUid = actor.uid
            ..assignedByName = actor.name
            ..createdAt = created
            ..updatedAt = created)
          .toMap()
        ..['createdAt'] = wire;
  Map<String, dynamic> diarySeed(Object wire) =>
      (JobDiaryEntry()
            ..firestoreId = 'record'
            ..jobExecutionFirestoreId = 'parent-job'
            ..assetNumber = 101
            ..note = 'Original observation'
            ..createdByUid = actor.uid
            ..createdByName = actor.name
            ..updatedByUid = actor.uid
            ..updatedByName = actor.name
            ..createdAt = created
            ..updatedAt = created
            ..retainReviewedServerVersion(0))
          .toMap()
        ..['createdAt'] = wire;

  for (final kind in ['execution', 'diary']) {
    for (final writer in ['direct', 'batch']) {
      for (final encoding in <String, Object>{
        'UTC': created.toIso8601String(),
        'offset': '2026-09-10T18:00:00.000+05:30',
        'historical local': created.toLocal().toIso8601String(),
        'native': Timestamp.fromDate(created),
      }.entries) {
        test(
          '$kind $writer preserves ${encoding.key} after Isar reload',
          () async {
            final original = kind == 'execution'
                ? executionSeed(encoding.value)
                : diarySeed(encoding.value);
            final transport = _Firestore(original, diary: kind == 'diary');
            if (kind == 'execution') {
              final incoming = JobExecution.fromMap(original, 'record');
              await database.writeTxn(
                () => database.jobExecutions.put(incoming),
              );
              final local = (await database.jobExecutions.get(incoming.id))!;
              local.remarks = 'Work recorded';
              final repo = FirestorePlannedRepository(firestore: transport);
              if (writer == 'direct') {
                await repo.saveExecution(local, actor: actor);
              } else {
                local.version++;
                local.updatedAt = DateTime.now();
                await repo.batchUpsertExecutions([local]);
              }
              expect(transport.accepted!['remarks'], 'Work recorded');
              expect(
                transport.accepted!.containsKey('laneSetFinalizedAt'),
                isFalse,
              );
            } else {
              final incoming = JobDiaryEntry.fromMap(original, 'record');
              await database.writeTxn(
                () => database.jobDiaryEntrys.put(incoming),
              );
              final local = (await database.jobDiaryEntrys.get(incoming.id))!;
              local.note = 'Amended observation';
              local.metadataJson =
                  '{"diaryAmendmentReason":"Additional evidence"}';
              final repo = FirestoreJobDiaryRepository(firestore: transport);
              if (writer == 'direct') {
                await repo.saveEntry(local, actor: actor);
              } else {
                local.retainReviewedServerVersion(local.version);
                local.version++;
                local.updatedAt = DateTime.now();
                await repo.batchUpsertEntries([local]);
              }
              expect(transport.accepted!['note'], 'Amended observation');
              expect(transport.audit!['beforeState'], original);
              expect(transport.audit!['afterState'], {
                ...original,
                ...transport.accepted!,
              });
              final commits = transport.commitAttempts;
              await repo.batchUpsertEntries([local]);
              expect(
                transport.commitAttempts,
                commits,
                reason: 'Accepted retry is write-free',
              );
            }
            expect(transport.accepted!['createdAt'], encoding.value);
            expect(transport.accepted!['updatedAt'], endsWith('Z'));
            expect(transport.accepted!['version'], 2);
          },
        );
      }
      test(
        '$kind $writer rejects changed creation instant before writes',
        () async {
          final original = kind == 'execution'
              ? executionSeed(created.toIso8601String())
              : diarySeed(created.toIso8601String());
          final transport = _Firestore(original, diary: kind == 'diary');
          if (kind == 'execution') {
            final local = JobExecution.fromMap(original, 'record')
              ..createdAt = created.subtract(const Duration(seconds: 1));
            final repo = FirestorePlannedRepository(firestore: transport);
            await expectLater(
              writer == 'direct'
                  ? repo.saveExecution(local, actor: actor)
                  : repo.batchUpsertExecutions([local]),
              throwsStateError,
            );
          } else {
            final local = JobDiaryEntry.fromMap(original, 'record')
              ..createdAt = created.subtract(const Duration(seconds: 1));
            local.retainReviewedServerVersion(1);
            final repo = FirestoreJobDiaryRepository(firestore: transport);
            await expectLater(
              writer == 'direct'
                  ? repo.saveEntry(local, actor: actor)
                  : repo.batchUpsertEntries([local]),
              throwsStateError,
            );
          }
          expect(transport.commitAttempts, 0);
        },
      );
    }
  }

  for (final kind in ['execution', 'diary']) {
    test('$kind genuinely new record writes UTC instants', () async {
      final transport = _Firestore(null, diary: kind == 'diary');
      if (kind == 'execution') {
        final local = JobExecution.fromMap(
          executionSeed(created.toIso8601String()),
          'record',
        );
        await database.writeTxn(() => database.jobExecutions.put(local));
        final restored = (await database.jobExecutions.get(local.id))!;
        await FirestorePlannedRepository(
          firestore: transport,
        ).batchUpsertExecutions([restored]);
      } else {
        final local = JobDiaryEntry.fromMap(
          diarySeed(created.toIso8601String()),
          'record',
        );
        await database.writeTxn(() => database.jobDiaryEntrys.put(local));
        final restored = (await database.jobDiaryEntrys.get(local.id))!;
        await FirestoreJobDiaryRepository(
          firestore: transport,
        ).batchUpsertEntries([restored]);
        expect(transport.audit!['beforeState'], isNull);
      }
      expect(transport.accepted!['createdAt'], created.toIso8601String());
      expect(transport.accepted!['updatedAt'], created.toIso8601String());
    });
    test(
      '$kind unchanged update time keeps its historical wire value',
      () async {
        final original = kind == 'execution'
            ? executionSeed(created.toIso8601String())
            : diarySeed(created.toIso8601String());
        original['updatedAt'] = Timestamp.fromDate(created);
        final transport = _Firestore(original, diary: kind == 'diary');
        if (kind == 'execution') {
          final local = JobExecution.fromMap(original, 'record')..version = 2;
          await FirestorePlannedRepository(
            firestore: transport,
          ).batchUpsertExecutions([local]);
        } else {
          final local = JobDiaryEntry.fromMap(original, 'record')..version = 2;
          local.retainReviewedServerVersion(1);
          await FirestoreJobDiaryRepository(
            firestore: transport,
          ).batchUpsertEntries([local]);
        }
        expect(transport.accepted!['updatedAt'], original['updatedAt']);
      },
    );
  }
  test(
    'diary changed server revision refuses amendment without audit writes',
    () async {
      final original = diarySeed(created.toIso8601String());
      final local = JobDiaryEntry.fromMap(original, 'record')..version = 2;
      local.retainReviewedServerVersion(1);
      local.note = 'Offline amendment';
      final transport = _Firestore({...original, 'version': 3}, diary: true);
      await expectLater(
        FirestoreJobDiaryRepository(
          firestore: transport,
        ).batchUpsertEntries([local]),
        throwsStateError,
      );
      expect(transport.commitAttempts, 0);
    },
  );
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.original, {required this.diary});
  Map<String, dynamic>? original;
  final bool diary;
  Map<String, dynamic>? accepted;
  Map<String, dynamic>? audit;
  int commitAttempts = 0;
  void commit(Map<String, dynamic> value, [Map<String, dynamic>? auditValue]) {
    commitAttempts++;
    if (original != null && value['createdAt'] != original!['createdAt']) {
      throw StateError('Rules reject changed creation wire value');
    }
    if (diary) {
      expect(auditValue!['beforeState'], original);
      expect(auditValue['afterState'], {...?original, ...value});
    }
    accepted = Map.of(value);
    audit = auditValue;
    original = {...?original, ...value};
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  WriteBatch batch() => _Batch(this);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final tx = _Transaction(this);
    final result = await handler(tx);
    if (tx.value != null) commit(tx.value!, tx.audit);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.owner, this.path);
  final _Firestore owner;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference(owner, this.path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.owner, this.collectionPath);
  final _Firestore owner;
  final String collectionPath;
  @override
  String get id => 'record';
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(owner.original);
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async =>
      owner.commit(data);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  String get id => 'record';
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Batch implements WriteBatch {
  _Batch(this.owner);
  final _Firestore owner;
  Map<String, dynamic>? value;
  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    value = Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<void> commit() async {
    if (value != null) owner.commit(value!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.owner);
  final _Firestore owner;
  Map<String, dynamic>? value;
  Map<String, dynamic>? audit;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async => _Snapshot(owner.original) as DocumentSnapshot<T>;
  @override
  Transaction set<T>(
    DocumentReference<T> document,
    T data, [
    SetOptions? options,
  ]) {
    if ((document as _Reference).collectionPath == 'audit_logs') {
      audit = Map<String, dynamic>.from(data as Map);
    } else {
      value = Map<String, dynamic>.from(data as Map);
    }
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
