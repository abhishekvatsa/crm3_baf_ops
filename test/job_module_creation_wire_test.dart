// Actual Isar and repository writers; the transport enforces the Rules' pinned
// timestamp wire equality instead of accepting representation-only changes.
// ignore_for_file: subtype_of_sealed_class
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart' hide Query;

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  final created = DateTime.utc(2026, 9, 26, 21, 13, 48, 978);
  final actor = AppUser(
    uid: 'worker',
    name: 'Worker',
    email: 'worker@example.invalid',
    roles: [AppRole.contractSupervisor],
    isApproved: true,
    createdAt: created,
  );
  late Directory directory;
  late Isar database;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('module_wire_');
    database = await Isar.open(
      [JobModuleInstanceSchema],
      directory: directory.path,
      inspector: false,
    );
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });
  Map<String, dynamic> original(Object encoding) =>
      (JobModuleInstance()
            ..firestoreId = 'module'
            ..jobExecutionFirestoreId = 'job'
            ..assetType = AssetType.furnace
            ..assetNumber = 1
            ..moduleTitle = 'Inspection'
            ..discipline = JobModuleDiscipline.mechanical
            ..createdAt = created
            ..addedAt = created
            ..updatedAt = created
            ..createdByUid = 'assigner'
            ..addedByUid = 'assigner'
            ..updatedByUid = 'assigner')
          .toMap()
        ..['createdAt'] = encoding
        ..['addedAt'] = encoding;

  Future<JobModuleInstance> reload(Map<String, dynamic> data) async {
    final imported = JobModuleInstance.fromMap(data, 'module');
    await database.writeTxn(() => database.jobModuleInstances.put(imported));
    return (await database.jobModuleInstances.get(imported.id))!;
  }

  Future<void> save(
    String writer,
    _Firestore transport,
    JobModuleInstance local,
  ) async {
    final repo = FirestoreJobModuleRepository(firestore: transport);
    if (writer == 'batch') {
      local.version++;
      local.updatedAt = DateTime.now();
      await repo.batchUpsertModules([local]);
    } else {
      await repo.saveModule(local, actor: actor);
    }
  }

  for (final writer in ['batch', 'direct']) {
    for (final wire in <String, Object>{
      'UTC string': created.toIso8601String(),
      'offset string': '2026-09-27T02:43:48.978+05:30',
      'native Timestamp': Timestamp.fromDate(created),
      'local string': created.toLocal().toIso8601String(),
    }.entries) {
      test(
        '$writer preserves createdAt and addedAt ${wire.key} through actual Isar',
        () async {
          final before = original(wire.value);
          final local = await reload(before);
          expect(local.createdAt.isAtSameMomentAs(created), isTrue);
          local.responsesJson =
              '[{"key":"inspection","value":"Witnessed acceptable"}]';
          local.status = JobModuleStatus.draftSaved;
          local.updatedByUid = actor.uid;
          final transport = _Firestore(before);
          await save(writer, transport, local);
          expect(transport.accepted!['createdAt'], wire.value);
          expect(transport.accepted!['addedAt'], wire.value);
          expect(transport.accepted!['responsesJson'], local.responsesJson);
          expect(transport.accepted!['createdByUid'], 'assigner');
          expect(transport.accepted!['addedByUid'], 'assigner');
          expect(transport.accepted!['version'], 2);
        },
      );
    }
    for (final field in ['createdAt', 'addedAt']) {
      test(
        '$writer refuses genuine $field change before transport commit',
        () async {
          final before = original(created.toIso8601String());
          final local = await reload(before);
          if (field == 'createdAt') {
            local.createdAt = created.subtract(const Duration(seconds: 1));
          } else {
            local.addedAt = created.subtract(const Duration(seconds: 1));
          }
          final transport = _Firestore(before);
          await expectLater(save(writer, transport, local), throwsStateError);
          expect(transport.commitAttempts, 0);
          expect(transport.accepted, isNull);
        },
      );
    }
    test(
      '$writer preserves earlier lifecycle date evidence while saving reopened work',
      () async {
        final before = original(created.toIso8601String())
          ..['submittedAt'] = created.toIso8601String()
          ..['acceptedAt'] = Timestamp.fromDate(created)
          ..['reopenedAt'] = '2026-09-27T02:43:48.978+05:30'
          ..['notApplicableAt'] = created.toIso8601String()
          ..['status'] = 'reopened';
        final local = await reload(before);
        local.responsesJson =
            '[{"key":"inspection","value":"Follow-up checked"}]';
        final transport = _Firestore(before);
        await save(writer, transport, local);
        for (final field in [
          'submittedAt',
          'acceptedAt',
          'reopenedAt',
          'notApplicableAt',
        ]) {
          expect(transport.accepted![field], before[field]);
        }
      },
    );
    test(
      '$writer preserves absent optional origin evidence without adding null fields',
      () async {
        final before = original(created.toIso8601String())..remove('addedAt');
        final local = await reload(before)
          ..responsesJson = '[{"key":"inspection","value":"Done"}]';
        final transport = _Firestore(before);
        await save(writer, transport, local);
        expect(transport.accepted!.containsKey('addedAt'), isFalse);
      },
    );
    test(
      '$writer transmits a real new submission instant for normal Rules evaluation',
      () async {
        final before = original(created.toIso8601String());
        final local = await reload(before);
        final submitted = created.add(const Duration(minutes: 5)).toLocal();
        local.status = JobModuleStatus.submitted;
        local.submittedAt = submitted;
        local.submittedByUid = actor.uid;
        final transport = _Firestore(
          before,
          allowedDateChanges: {'submittedAt'},
        );
        await save(writer, transport, local);
        expect(
          transport.accepted!['submittedAt'],
          submitted.toUtc().toIso8601String(),
        );
        expect(transport.accepted!['submittedByUid'], actor.uid);
      },
    );
  }

  test(
    'field-scoped lifecycle replay sends new instants in UTC without touching origin',
    () async {
      final before = original(Timestamp.fromDate(created));
      final at = created.add(const Duration(minutes: 5)).toLocal();
      final step = <String, dynamic>{
        'submittedAt': at.toIso8601String(),
        'updatedAt': at.toIso8601String(),
        'status': 'submitted',
        'version': 2,
      };
      final transport = _Firestore(before, allowedDateChanges: {'submittedAt'});
      await FirestoreJobModuleRepository(
        firestore: transport,
      ).applyRemoteLifecycleReplayStepForSync('module', step);
      expect(transport.accepted!['submittedAt'], at.toUtc().toIso8601String());
      expect(transport.accepted!['updatedAt'], at.toUtc().toIso8601String());
      expect(transport.accepted!['createdAt'], before['createdAt']);
      expect(step['submittedAt'], at.toIso8601String());
    },
  );
  for (final action in ['submit', 'accept', 'reopen', 'notApplicable']) {
    test(
      'direct $action transition writes a new UTC instant and leaves original wire evidence untouched',
      () async {
        final before = original(Timestamp.fromDate(created))
          ..['status'] = action == 'accept'
              ? 'submitted'
              : action == 'reopen'
              ? 'accepted'
              : 'notStarted'
          ..['isOpenForWork'] = action != 'accept' && action != 'reopen';
        final field = {
          'submit': 'submittedAt',
          'accept': 'acceptedAt',
          'reopen': 'reopenedAt',
          'notApplicable': 'notApplicableAt',
        }[action]!;
        final transport = _Firestore(before, allowedDateChanges: {field});
        final repo = FirestoreJobModuleRepository(firestore: transport);
        switch (action) {
          case 'submit':
            await repo.submitModule('module', actor: actor);
          case 'accept':
            await repo.acceptModule('module', actor: actor);
          case 'reopen':
            await repo.reopenModule(
              'module',
              actor: actor,
              reopenReason: 'Repeat inspection',
            );
          case 'notApplicable':
            await repo.markModuleNotApplicable(
              'module',
              actor: actor,
              reason: 'No applicable work',
            );
        }
        expect(transport.accepted![field], endsWith('Z'));
        expect(transport.accepted!['updatedAt'], transport.accepted![field]);
        expect(transport.accepted!['createdAt'], before['createdAt']);
        expect(transport.accepted!['addedAt'], before['addedAt']);
      },
    );
  }
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.original, {this.allowedDateChanges = const {}});
  final Map<String, dynamic> original;
  final Set<String> allowedDateChanges;
  Map<String, dynamic>? accepted;
  int commitAttempts = 0;
  void commit(Map<String, dynamic> data) {
    commitAttempts++;
    data = {...original, ...data};
    for (final field in [
      'createdAt',
      'addedAt',
      'submittedAt',
      'acceptedAt',
      'reopenedAt',
      'notApplicableAt',
      'deletedAt',
    ]) {
      if (allowedDateChanges.contains(field)) continue;
      if (data.containsKey(field) != original.containsKey(field) ||
          data[field] != original[field]) {
        throw StateError('Rules reject altered $field evidence');
      }
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
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _QuerySnapshot(owner.original);
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) return this;
    return super.noSuchMethod(invocation);
  }
}

class _QuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.value);
  final Map<String, dynamic> value;
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    _Snapshot(value),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.owner);
  final _Firestore owner;
  @override
  String get id => 'module';
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

class _Snapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic> value;
  @override
  String get id => 'module';
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
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
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    value = Map<String, dynamic>.from(data);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
