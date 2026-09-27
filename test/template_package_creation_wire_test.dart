// Only the Firestore transport is replaced; Isar and both repository writers
// are real. The transport checks the immutable origin equality used by Rules.
// ignore_for_file: subtype_of_sealed_class
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
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
    directory = await Directory.systemTemp.createTemp('package_wire_');
    database = await Isar.open(
      [TemplatePackageSchema, TemplateVersionSchema],
      directory: directory.path,
      inspector: false,
    );
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });
  Map<String, dynamic> seed(Object wire) =>
      (TemplatePackage()
            ..firestoreId = 'package'
            ..packageCode = 'PKG'
            ..title = 'Original package'
            ..createdAt = created
            ..updatedAt = created
            ..createdByUid = actor.uid
            ..updatedByUid = actor.uid)
          .toMap()
        ..['createdAt'] = wire;

  for (final writer in ['batch draft', 'direct draft']) {
    test('$writer refuses a genuinely altered creation instant', () async {
      final original =
          (TemplateVersion()
                ..firestoreId = 'package'
                ..packageFirestoreId = 'parent-package'
                ..createdAt = created
                ..updatedAt = created
                ..createdByUid = actor.uid
                ..updatedByUid = actor.uid)
              .toMap();
      final changed = TemplateVersion.fromMap(original, 'package')
        ..createdAt = created.subtract(const Duration(seconds: 1));
      final transport = _Firestore(original);
      final repo = FirestoreTemplateGovernanceRepository(firestore: transport);
      await expectLater(
        writer == 'batch draft'
            ? repo.batchUpsertVersions([changed])
            : repo.saveVersion(changed, actor: actor),
        throwsStateError,
      );
      expect(transport.commitAttempts, 0);
      expect(transport.accepted, isNull);
    });
    for (final encoding in <Object>[
      created.toIso8601String(),
      Timestamp.fromDate(created),
    ]) {
      test('$writer retains original creation encoding $encoding', () async {
        final original =
            (TemplateVersion()
                  ..firestoreId = 'package'
                  ..packageFirestoreId = 'parent-package'
                  ..createdAt = created
                  ..updatedAt = created
                  ..createdByUid = actor.uid
                  ..updatedByUid = actor.uid)
                .toMap()
              ..['createdAt'] = encoding;
        final imported = TemplateVersion.fromMap(original, 'package');
        await database.writeTxn(() => database.templateVersions.put(imported));
        final local = (await database.templateVersions.get(imported.id))!;
        local.changeSummary = 'Reviewed edit';
        final transport = _Firestore(original);
        final repo = FirestoreTemplateGovernanceRepository(
          firestore: transport,
        );
        if (writer == 'batch draft') {
          local.version++;
          local.updatedAt = DateTime.now();
          await repo.batchUpsertVersions([local]);
        } else {
          await repo.saveVersion(local, actor: actor);
        }
        expect(transport.accepted!['createdAt'], encoding);
        expect(transport.accepted!['changeSummary'], 'Reviewed edit');
      });
    }
  }

  for (final writer in ['batch', 'direct']) {
    for (final encoding in <String, Object>{
      'UTC string': created.toIso8601String(),
      'offset string': '2026-09-10T18:00:00.000+05:30',
      'local string': created.toLocal().toIso8601String(),
      'native Timestamp': Timestamp.fromDate(created),
    }.entries) {
      test(
        '$writer preserves ${encoding.key} after real Isar reload',
        () async {
          final original = seed(encoding.value);
          final imported = TemplatePackage.fromMap(original, 'package');
          await database.writeTxn(
            () => database.templatePackages.put(imported),
          );
          final local = (await database.templatePackages.get(imported.id))!;
          expect(local.createdAt.isAtSameMomentAs(created), isTrue);
          local.title = 'Updated package';
          final transport = _Firestore(original);
          final repo = FirestoreTemplateGovernanceRepository(
            firestore: transport,
          );
          if (writer == 'batch') {
            local.version++;
            local.updatedAt = DateTime.now();
            await repo.batchUpsertPackages([local]);
          } else {
            await repo.savePackage(local, actor: actor);
          }
          expect(transport.accepted!['createdAt'], encoding.value);
          expect(transport.accepted!['title'], 'Updated package');
          expect(transport.accepted!['version'], 2);
          expect(transport.accepted!['createdByUid'], actor.uid);
        },
      );
    }
    test(
      '$writer rejects an actual origin instant change before commit',
      () async {
        final original = seed(created.toIso8601String());
        final changed = TemplatePackage.fromMap(original, 'package')
          ..createdAt = created.subtract(const Duration(seconds: 1));
        final transport = _Firestore(original);
        final repo = FirestoreTemplateGovernanceRepository(
          firestore: transport,
        );
        await expectLater(
          writer == 'batch'
              ? repo.batchUpsertPackages([changed])
              : repo.savePackage(changed, actor: actor),
          throwsStateError,
        );
        expect(transport.commitAttempts, 0);
        expect(transport.accepted, isNull);
      },
    );
    test(
      '$writer permits a genuinely new package without inherited origin',
      () async {
        final fresh = TemplatePackage.fromMap(
          seed(created.toIso8601String()),
          'package',
        );
        final transport = _Firestore(null);
        final repo = FirestoreTemplateGovernanceRepository(
          firestore: transport,
        );
        if (writer == 'batch') {
          await repo.batchUpsertPackages([fresh]);
        } else {
          await repo.savePackage(fresh, actor: actor);
        }
        expect(transport.accepted!['createdAt'], created.toIso8601String());
      },
    );
  }
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.original);
  final Map<String, dynamic>? original;
  Map<String, dynamic>? accepted;
  int commitAttempts = 0;
  void commit(Map<String, dynamic> data) {
    commitAttempts++;
    if (original != null && data['createdAt'] != original!['createdAt']) {
      throw StateError('Rules refuse changed immutable creation encoding');
    }
    accepted = Map.of(data);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this);
  @override
  WriteBatch batch() => _Batch(this);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final result = await handler(transaction);
    if (transaction.value != null) commit(transaction.value!);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.owner);
  final _Firestore owner;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference(owner);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.owner);
  final _Firestore owner;
  @override
  String get id => 'package';
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
  String get id => 'package';
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
    value = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
