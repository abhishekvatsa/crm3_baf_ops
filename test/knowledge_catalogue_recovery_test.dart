// Test-only transport doubles; production uses the SDK implementations.
// ignore_for_file: subtype_of_sealed_class

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart' hide Query;
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_knowledge_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_layer.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_governance_export.dart';
import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar db;
  late _Cloud cloud;
  late BafKnowledgeRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('knowledge_recovery_');
    db = await Isar.open(
      [
        BafKnowledgeRowSchema,
        BafKnowledgeMatrixMetaStoreSchema,
        AuditEventSchema,
      ],
      directory: directory.path,
      name: 'knowledge_recovery',
      inspector: false,
    );
    cloud = _Cloud();
    repository = BafKnowledgeRepository(firestore: cloud, localIsar: db);
  });
  tearDown(() async {
    await db.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });
  Future<void> put(BafKnowledgeRow row) =>
      db.writeTxn(() => db.bafKnowledgeRows.put(row));

  test(
    'governed version one replaces a newer synthetic seed; removed seed does not survive',
    () async {
      await repository.seedStaticFallbackIntoLocal();
      final seed = (await db.bafKnowledgeRows.where().findAll()).first;
      expect(isEmbeddedKnowledgeSeed(seed), isTrue);
      final governed = {
        ...seed.toCloudMap(),
        'createdByUid': 'admin',
        'updatedByUid': 'admin',
        'createdAt': DateTime.utc(2020),
        'updatedAt': DateTime.utc(2020),
        'taskText': 'Governed replacement instruction',
        'changeSummary': 'Reviewed cloud instruction',
      };
      cloud.rows[seed.rowCode] = governed;
      await repository.pullCloudToLocal();
      final rows = await db.bafKnowledgeRows.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.taskText, 'Governed replacement instruction');
      expect(rows.single.version, 1);
      expect(isEmbeddedKnowledgeSeed(rows.single), isFalse);
      final meta = await repository.watchMatrixMeta().first;
      expect(meta.isStaticFallback, isFalse);
      expect(meta.matrixVersion, 'unverified');
    },
  );

  test(
    'accepting reviewed cloud archives the losing dirty draft atomically',
    () async {
      final local = _row()
        ..isSynced = false
        ..taskText = 'Local evidence must survive';
      await put(local);
      cloud.rows[local.rowCode] = {
        ...local.toCloudMap(),
        'version': 2,
        'taskText': 'Reviewed authoritative instruction',
      };
      await repository.acceptReviewedCloud(
        reviewedLocal: local,
        reviewedCloudVersion: 2,
        actorUid: 'admin',
        actorName: 'Administrator',
      );
      final adopted = (await db.bafKnowledgeRows.where().findAll()).single;
      expect(adopted.taskText, 'Reviewed authoritative instruction');
      expect(adopted.isSynced, isTrue);
      final audit = (await db.auditEvents.where().findAll()).single;
      expect(
        jsonDecode(audit.beforeJson!)['taskText'],
        'Local evidence must survive',
      );
      expect(jsonDecode(audit.afterJson!)['version'], 2);
      expect(audit.isSynced, isFalse);
    },
  );

  test('a second local edit after review cannot be discarded', () async {
    final reviewed = _row()..isSynced = false;
    await put(reviewed);
    cloud.rows[reviewed.rowCode] = {...reviewed.toCloudMap(), 'version': 2};
    final changed = _row()
      ..id = reviewed.id
      ..isSynced = false
      ..taskText = 'Later local edit';
    await put(changed);
    await expectLater(
      repository.acceptReviewedCloud(
        reviewedLocal: reviewed,
        reviewedCloudVersion: 2,
        actorUid: 'admin',
        actorName: 'Administrator',
      ),
      throwsStateError,
    );
    expect(
      (await db.bafKnowledgeRows.where().findAll()).single.taskText,
      'Later local edit',
    );
    expect(await db.auditEvents.count(), 0);
  });

  test(
    'a cloud revision arriving after review cannot be adopted silently',
    () async {
      final local = _row()..isSynced = false;
      await put(local);
      cloud.rows[local.rowCode] = {...local.toCloudMap(), 'version': 3};
      await expectLater(
        repository.acceptReviewedCloud(
          reviewedLocal: local,
          reviewedCloudVersion: 2,
          actorUid: 'admin',
          actorName: 'Administrator',
        ),
        throwsStateError,
      );
      expect(
        (await db.bafKnowledgeRows.where().findAll()).single.isSynced,
        isFalse,
      );
      expect(await db.auditEvents.count(), 0);
    },
  );

  test(
    'dirty draft survives full pull and missing metadata is not a baseline edition',
    () async {
      final local = _row()..isSynced = false;
      await put(local);
      expect(
        (await repository.watchMatrixMeta().first).isStaticFallback,
        isFalse,
      );
      cloud.rows[local.rowCode] = {
        ...local.toCloudMap(),
        'version': 2,
        'taskText': 'Cloud revision',
      };
      await repository.pullCloudToLocal();
      final row = (await db.bafKnowledgeRows.where().findAll()).single;
      expect(row.isSynced, isFalse);
      expect(row.taskText, local.taskText);
    },
  );

  test(
    'CSV preserves commas and typed presets and binds the reviewed source',
    () {
      final row = _row();
      row.procedureRefs = ['Manual section 1, table 4'];
      final csv = KnowledgeGovernanceExport.export(
        [row],
        format: KnowledgeBundleFormat.csv,
        matrixVersion: 'test',
      );
      final result = KnowledgeGovernanceExport.parse(
        body: csv.body,
        format: KnowledgeBundleFormat.csv,
        existingRowsByCode: {row.rowCode: row},
      );
      expect(
        result.rowsRejected,
        0,
        reason: result.rejected.map((r) => r.messages).join(),
      );
      final accepted = result.accepted.single;
      expect(accepted.draft!.procedureRefs, ['Manual section 1, table 4']);
      expect(
        accepted.draft!.suggestedFieldPresets,
        row.toEntryMap()['suggestedFieldPresets'],
      );
      expect(accepted.sourceVersion, row.version);
      expect(jsonDecode(accepted.sourceEntryJson!), row.toEntryMap());
    },
  );

  test(
    'duplicate imported row codes cannot become sequential unintended revisions',
    () {
      final row = _row();
      final bundle = KnowledgeGovernanceExport.export(
        [row, row],
        format: KnowledgeBundleFormat.json,
        matrixVersion: 'test',
      );
      final result = KnowledgeGovernanceExport.parse(
        body: bundle.body,
        format: KnowledgeBundleFormat.json,
      );
      expect(result.rowsAccepted, 0);
      expect(result.rowsRejected, 2);
    },
  );
}

BafKnowledgeRow _row() => BafKnowledgeRow.fromEntry(
  BafKnowledgeLayer.entries.first,
  actorUid: 'admin',
  actorName: 'Administrator',
  now: DateTime.utc(2026, 9, 1),
  changeSummary: 'Reviewed governed instruction for the plant',
  isSynced: true,
);

class _Cloud extends Fake implements FirebaseFirestore {
  final rows = <String, Map<String, dynamic>>{};
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this);
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _Document(path.split('/').last, null);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.cloud);
  final _Cloud cloud;
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Query<Map<String, dynamic>> limit(int value) => this;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(path!, cloud.rows[path]);
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    expect(options?.source, Source.server);
    return _QuerySnapshot(
      cloud.rows.entries.map((e) => _QueryRow(e.key, e.value)).toList(),
    );
  }
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.key, this.value);
  final String key;
  final Map<String, dynamic>? value;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    expect(options?.source, Source.server);
    return _Snapshot(key, value);
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
