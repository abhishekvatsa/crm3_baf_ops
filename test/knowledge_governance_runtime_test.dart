// Firestore transport doubles exercise the real controller and Isar repository.
// ignore_for_file: subtype_of_sealed_class

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_knowledge_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_layer.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_governance_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_revision_settlement.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/knowledge_governance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart' hide Query;

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late _Cloud cloud;
  late Isar db;
  late Directory directory;
  late BafKnowledgeRepository repository;
  late KnowledgeGovernanceController controller;
  final actor = AppUser(
    uid: 'admin',
    name: 'Administrator',
    email: 'admin@test.invalid',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('knowledge_governance_');
    db = await Isar.open(
      [
        BafKnowledgeRowSchema,
        BafKnowledgeMatrixMetaStoreSchema,
        AuditEventSchema,
      ],
      directory: directory.path,
      name: 'knowledge_governance',
      inspector: false,
    );
    cloud = _Cloud();
    repository = BafKnowledgeRepository(firestore: cloud, localIsar: db);
    controller = KnowledgeGovernanceController(
      firestore: cloud,
      knowledgeRepository: repository,
    );
  });
  tearDown(() async {
    await db.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  test(
    'browser snapshot reads current withdrawal instead of cached active guidance',
    () async {
      final row = _row();
      cloud.rows[row.rowCode] = {
        ...row.toCloudMap(),
        'lifecycleStatus': 'retired',
      };
      cloud.cachedRows = {row.rowCode: row.toCloudMap()};
      final bundle = await BafKnowledgeRepository.cloudOnly(
        firestore: cloud,
      ).load();
      expect(bundle.entries, isEmpty);
      expect(bundle.meta.isStaticFallback, isFalse);
      expect(bundle.source, BafKnowledgeSource.cloud);
    },
  );

  test(
    'browser snapshot and live stream exclude an active tombstone',
    () async {
      final row = _row();
      cloud.rows[row.rowCode] = {...row.toCloudMap(), 'isDeleted': true};
      final web = BafKnowledgeRepository.cloudOnly(firestore: cloud);
      expect((await web.load()).entries, isEmpty);
      expect(await web.watchKnowledgeRows().first, isEmpty);
    },
  );

  test(
    'metadata outage cannot replace a successfully read withdrawal with embedded rows',
    () async {
      final row = _row();
      cloud.rows[row.rowCode] = {
        ...row.toCloudMap(),
        'lifecycleStatus': 'retired',
      };
      cloud.failMetaRead = true;
      final bundle = await BafKnowledgeRepository.cloudOnly(
        firestore: cloud,
      ).load();
      expect(bundle.entries, isEmpty);
      expect(bundle.meta.isStaticFallback, isFalse);
      expect(bundle.meta.matrixVersion, 'unverified');
    },
  );

  test(
    'new browser with no catalogue retains explicitly unverified embedded reference',
    () async {
      final bundle = await BafKnowledgeRepository.cloudOnly(
        firestore: cloud,
      ).load();
      expect(bundle.entries, isNotEmpty);
      expect(bundle.meta.isStaticFallback, isTrue);
      expect(bundle.meta.note, contains('unverified'));
    },
  );

  test(
    'controller commits the revision and audit together and verifies native adoption',
    () async {
      final draft = _draft();
      final result = await controller.createRow(draft: draft, actor: actor);
      expect(result.adoption, KnowledgeRevisionAdoption.adopted);
      expect(cloud.commits, hasLength(1));
      expect(
        cloud.commits.single.keys,
        unorderedEquals([
          'knowledge_base/${draft.rowCode}',
          'audit_logs/knowledge_revision_${draft.rowCode}_1',
        ]),
      );
      expect(
        (await repository.getAllLocalRows()).single.taskText,
        draft.taskText,
      );
      final audit =
          cloud.documents['audit_logs/knowledge_revision_${draft.rowCode}_1']!;
      expect(
        jsonDecode(audit['afterJson'] as String)['taskText'],
        draft.taskText,
      );
      expect(audit['performedByUid'], actor.uid);
    },
  );

  test(
    'controller update retains original content in the atomic audit',
    () async {
      final before = _row();
      cloud.rows[before.rowCode] = before.toCloudMap();
      await repository.pullCloudToLocal();
      final reviewed = (await repository.getAllLocalRows()).single;
      final result = await controller.updateRow(
        before: reviewed,
        draft: _draft(),
        actor: actor,
      );
      expect(result.versionAfter, 2);
      expect(result.adoption, KnowledgeRevisionAdoption.adopted);
      final audit =
          cloud.documents['audit_logs/knowledge_revision_${before.rowCode}_2']!;
      expect(
        jsonDecode(audit['beforeJson'] as String)['taskText'],
        before.taskText,
      );
      expect(
        jsonDecode(audit['afterJson'] as String)['taskText'],
        _draft().taskText,
      );
      expect(cloud.commits.single, hasLength(2));
    },
  );

  test(
    'malformed active cloud row fails visibly rather than becoming embedded guidance',
    () async {
      final row = _row();
      cloud.rows[row.rowCode] = {...row.toCloudMap(), 'taskText': 42};
      final web = BafKnowledgeRepository.cloudOnly(firestore: cloud);
      await expectLater(web.load(), throwsA(isA<FormatException>()));
      await expectLater(
        web.watchKnowledgeRows().first,
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('withdrawn browser catalogue can be deliberately reinstated', () async {
    final row = _row();
    cloud.rows[row.rowCode] = {
      ...row.toCloudMap(),
      'lifecycleStatus': 'retired',
    };
    final web = BafKnowledgeRepository.cloudOnly(firestore: cloud);
    expect((await web.load()).entries, isEmpty);
    cloud.rows[row.rowCode] = {...row.toCloudMap(), 'version': 2};
    expect((await web.load()).entries.single.id, row.rowCode);
  });

  test(
    'audit admission failure prevents the governed revision from committing',
    () async {
      cloud.rejectAudit = true;
      await expectLater(
        controller.createRow(draft: _draft(), actor: actor),
        throwsStateError,
      );
      expect(cloud.rows, isEmpty);
      expect(cloud.documents, isEmpty);
      expect(await repository.getAllLocalRows(), isEmpty);
    },
  );

  test(
    'accepted revision with failed readback remains saved with pending adoption',
    () async {
      cloud.afterCommit = () async => cloud.failRowRead = true;
      final result = await controller.createRow(draft: _draft(), actor: actor);
      expect(result.adoption, KnowledgeRevisionAdoption.pending);
      expect(cloud.rows, hasLength(1));
      expect(
        cloud.documents.keys.where((key) => key.startsWith('audit_logs/')),
        hasLength(1),
      );
    },
  );

  test(
    'successful general pull cannot claim adoption when newer dirty work is retained',
    () async {
      final draft = _draft();
      cloud.afterCommit = () async {
        final dirty = _row()
          ..version = 2
          ..isSynced = false
          ..taskText = 'Later unsent draft';
        await db.writeTxn(() => db.bafKnowledgeRows.put(dirty));
        final other = _row()..rowCode = 'OTHER-ROW';
        cloud.rows[other.rowCode] = other.toCloudMap();
      };
      final result = await controller.createRow(draft: draft, actor: actor);
      expect(result.adoption, KnowledgeRevisionAdoption.pending);
      final rows = await repository.getAllLocalRows();
      expect(rows, hasLength(2));
      expect(
        rows.singleWhere((row) => row.rowCode == draft.rowCode).taskText,
        'Later unsent draft',
      );
      expect(
        rows.singleWhere((row) => row.rowCode == draft.rowCode).isSynced,
        isFalse,
      );
    },
  );

  test(
    'same-version contradictory server readback is not the accepted content',
    () async {
      cloud.afterCommit = () async {
        cloud.rows[_draft().rowCode]!['taskText'] =
            'Contradictory same-version content';
      };
      final result = await controller.createRow(draft: _draft(), actor: actor);
      expect(result.adoption, KnowledgeRevisionAdoption.pending);
    },
  );

  test(
    'delayed response after later cloud revision preserves accepted revision identity',
    () async {
      cloud.afterCommit = () async {
        cloud.rows[_draft().rowCode]!['version'] = 2;
        cloud.rows[_draft().rowCode]!['taskText'] =
            'Later accepted instruction';
      };
      final result = await controller.createRow(draft: _draft(), actor: actor);
      expect(result.versionAfter, 1);
      expect(result.adoption, KnowledgeRevisionAdoption.pending);
      expect(cloud.commits, hasLength(1));
    },
  );
}

BafKnowledgeRow _row() => BafKnowledgeRow.fromEntry(
  BafKnowledgeLayer.entries.first,
  actorUid: 'admin',
  actorName: 'Administrator',
  now: DateTime.utc(2026, 9, 1),
  changeSummary: 'Previously reviewed instruction',
);
KnowledgeRowDraft _draft() => KnowledgeRowDraft.fromRow(_row())
  ..taskText = 'New accepted governed instruction'
  ..changeSummary = 'Reviewed new instruction';

class _Cloud extends Fake implements FirebaseFirestore {
  final rows = <String, Map<String, dynamic>>{};
  final documents = <String, Map<String, dynamic>>{};
  final commits = <Map<String, Map<String, dynamic>>>[];
  Map<String, Map<String, dynamic>>? cachedRows;
  bool failMetaRead = false;
  bool failRowRead = false;
  bool rejectAudit = false;
  Future<void> Function()? afterCommit;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _Document(this, path);
  Map<String, dynamic>? read(String path) => path.startsWith('knowledge_base/')
      ? rows[path.split('/').last]
      : documents[path];
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final result = await handler(transaction);
    if (rejectAudit &&
        transaction.pending.keys.any((key) => key.startsWith('audit_logs/'))) {
      throw StateError('Audit admission rejected');
    }
    for (final entry in transaction.pending.entries) {
      documents[entry.key] = entry.value;
      if (entry.key.startsWith('knowledge_base/')) {
        rows[entry.key.split('/').last] = entry.value;
      }
    }
    commits.add(transaction.pending);
    await afterCommit?.call();
    return result;
  }
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.cloud);
  final _Cloud cloud;
  final pending = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async =>
      _Snapshot(ref.path.split('/').last, cloud.read(ref.path))
          as DocumentSnapshot<T>;
  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    pending[ref.path] = {
      if (options?.merge == true) ...?cloud.read(ref.path),
      for (final entry in (data as Map<String, dynamic>).entries)
        entry.key: entry.value is FieldValue
            ? DateTime.utc(2026, 9, 20)
            : entry.value,
    };
    return this;
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.cloud, this.path, {this.activeOnly = false});
  final _Cloud cloud;
  @override
  final String path;
  final bool activeOnly;
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Collection(
    cloud,
    path,
    activeOnly: field == 'lifecycleStatus' && isEqualTo == 'active',
  );
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Query<Map<String, dynamic>> limit(int limit) => this;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(cloud, '${this.path}/$path');
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final rows = options?.source == Source.server
        ? cloud.rows
        : cloud.cachedRows ?? cloud.rows;
    return _QuerySnapshot(
      rows.entries
          .where(
            (entry) =>
                !activeOnly || entry.value['lifecycleStatus'] == 'active',
          )
          .map((entry) => _QueryRow(entry.key, entry.value))
          .toList(),
    );
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.fromFuture(get(const GetOptions(source: Source.server)));
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.cloud, this.path);
  final _Cloud cloud;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    if ((cloud.failMetaRead && path.startsWith('knowledge_base_meta/')) ||
        (cloud.failRowRead && path.startsWith('knowledge_base/'))) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return _Snapshot(path.split('/').last, cloud.read(path));
  }
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

class _QueryRow extends _Snapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryRow(super.id, super.value);
  @override
  Map<String, dynamic> data() => value!;
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}
