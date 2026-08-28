// FILE: lib/features/planned_maintenance/domain/baf_knowledge_repository.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart' hide Query;

import '../../../core/persistence/app_database.dart';
import '../../../core/serialization/persisted_json_equality.dart';
import '../../../core/services/global_pull_protocol.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../data/baf_knowledge_model.dart';
import 'baf_knowledge_layer.dart';
import 'module_composer_models.dart';

/// Source used by the Module Composer knowledge layer.
///
/// RC4 keeps the actual 5D shape:
/// Firestore authority -> Isar offline cache -> embedded static fallback.
/// Composer draft recovery remains SharedPreferences in the UI layer, because
/// that is short-lived screen state rather than governed plant knowledge.
enum BafKnowledgeSource { cloud, isarCache, staticFallback }

class BafKnowledgeMatrixMeta {
  final String matrixVersion;
  final String sourceLabel;
  final String source;
  final DateTime? cloudUpdatedAt;
  final DateTime? localCachedAt;
  final int knowledgeRowCount;
  final int tagRowCount;
  final bool isStaticFallback;
  final bool cloudUnavailable;
  final String maintenanceManualRef;
  final String safetyOperationsManualRef;
  final String note;

  const BafKnowledgeMatrixMeta({
    required this.matrixVersion,
    required this.sourceLabel,
    required this.source,
    required this.knowledgeRowCount,
    required this.tagRowCount,
    this.cloudUpdatedAt,
    this.localCachedAt,
    this.isStaticFallback = false,
    this.cloudUnavailable = false,
    this.maintenanceManualRef = BafKnowledgeLayer.maintenanceManualRef,
    this.safetyOperationsManualRef =
        BafKnowledgeLayer.safetyOperationsManualRef,
    this.note = '',
  });

  factory BafKnowledgeMatrixMeta.staticFallback({
    bool cloudUnavailable = false,
  }) {
    return BafKnowledgeMatrixMeta(
      matrixVersion: BafKnowledgeLayer.matrixVersion,
      sourceLabel: BafKnowledgeLayer.sourceLabel,
      source: 'staticFallback',
      knowledgeRowCount: BafKnowledgeLayer.knowledgeRowCount,
      tagRowCount: BafKnowledgeLayer.tagRowCount,
      isStaticFallback: true,
      cloudUnavailable: cloudUnavailable,
      note:
          cloudUnavailable
              ? 'Cloud/local knowledge source unavailable; using embedded safety baseline.'
              : 'Using embedded safety baseline.',
    );
  }

  factory BafKnowledgeMatrixMeta.fromStore(
    BafKnowledgeMatrixMetaStore store, {
    String? sourceOverride,
    int? rowCountOverride,
    int? tagCountOverride,
  }) {
    return BafKnowledgeMatrixMeta(
      matrixVersion: store.matrixVersion,
      sourceLabel: store.sourceLabel,
      source: sourceOverride ?? store.source,
      cloudUpdatedAt: store.cloudUpdatedAt,
      localCachedAt: store.localCachedAt,
      knowledgeRowCount: rowCountOverride ?? store.knowledgeRowCount,
      tagRowCount: tagCountOverride ?? store.tagRowCount,
      isStaticFallback: store.source == 'staticFallback',
      maintenanceManualRef: store.maintenanceManualRef,
      safetyOperationsManualRef: store.safetyOperationsManualRef,
      note: store.note,
    );
  }

  factory BafKnowledgeMatrixMeta.fromMap(
    Map<String, dynamic> map, {
    required DateTime localCachedAt,
  }) {
    return BafKnowledgeMatrixMeta.fromStore(
      BafKnowledgeMatrixMetaStore.fromCloudMap(
        map,
        localCachedAt: localCachedAt,
      ),
      sourceOverride: 'cloud',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'matrixVersion': matrixVersion,
    'sourceLabel': sourceLabel,
    'source': source,
    'cloudUpdatedAt': cloudUpdatedAt?.toIso8601String(),
    'localCachedAt': localCachedAt?.toIso8601String(),
    'knowledgeRowCount': knowledgeRowCount,
    'tagRowCount': tagRowCount,
    'isStaticFallback': isStaticFallback,
    'cloudUnavailable': cloudUnavailable,
    'maintenanceManualRef': maintenanceManualRef,
    'safetyOperationsManualRef': safetyOperationsManualRef,
    'note': note,
  };
}

class BafKnowledgeBundle {
  final List<BafKnowledgeEntry> entries;
  final BafKnowledgeMatrixMeta meta;
  final BafKnowledgeSource source;

  const BafKnowledgeBundle({
    required this.entries,
    required this.meta,
    required this.source,
  });
}

class BafKnowledgePullResult {
  final int inserted;
  final int updated;
  final int skipped;
  final DateTime? maxFetchedUpdatedAt;

  const BafKnowledgePullResult({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.maxFetchedUpdatedAt,
  });

  int get changed => inserted + updated;
}

class BafKnowledgeRepository {
  BafKnowledgeRepository({FirebaseFirestore? firestore, Isar? localIsar})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _isar = localIsar ?? (kIsWeb ? null : isar);

  static const String collectionPath = 'knowledge_base';
  static const String metaPath = 'knowledge_base_meta/current';
  static const int changeReasonMinLength = 1;
  static const int _knowledgePullPageSize = 250;

  final FirebaseFirestore _firestore;
  final Isar? _isar;

  IsarCollection<BafKnowledgeRow>? get _rows =>
      _isar?.collection<BafKnowledgeRow>();
  IsarCollection<BafKnowledgeMatrixMetaStore>? get _meta =>
      _isar?.collection<BafKnowledgeMatrixMetaStore>();

  Future<BafKnowledgeBundle> load({bool preferCloud = true}) async {
    if (kIsWeb || _isar == null) {
      return _loadWeb(preferCloud: preferCloud);
    }

    if (preferCloud) {
      try {
        await pullCloudToLocal();
      } on FirebaseException {
        // Offline/permission/cloud-empty; continue with Isar/static fallback.
      }
    }

    var local = await _loadFromIsar();
    if (local.entries.isNotEmpty) return local;

    await seedStaticFallbackIntoLocal();
    local = await _loadFromIsar();
    if (local.entries.isNotEmpty) return local;

    return BafKnowledgeBundle(
      entries: BafKnowledgeLayer.entries,
      meta: BafKnowledgeMatrixMeta.staticFallback(
        cloudUnavailable: preferCloud,
      ),
      source: BafKnowledgeSource.staticFallback,
    );
  }

  Stream<List<BafKnowledgeEntry>> watchKnowledgeRows() {
    if (kIsWeb || _isar == null) {
      return _firestore
          .collection(collectionPath)
          .where('lifecycleStatus', isEqualTo: 'active')
          .snapshots()
          .map((snap) => _entriesFromCloudDocs(snap.docs));
    }

    return _rows!.where().watch(fireImmediately: true).asyncMap((rows) async {
      final activeRows =
          rows
              .where((row) => !row.isDeleted && row.lifecycleStatus == 'active')
              .toList()
            ..sort((a, b) => a.rowCode.compareTo(b.rowCode));
      if (activeRows.isEmpty) {
        await seedStaticFallbackIntoLocal();
        final seeded = await _rows!.where().findAll();
        return _entriesFromRows(seeded);
      }
      return _entriesFromRows(activeRows);
    });
  }

  /// Governance-facing stream of every local knowledge row, including retired
  /// and archived rows. This intentionally watches Isar first on mobile so
  /// Knowledge Governance remains offline-first; Firestore pulls refresh Isar,
  /// and the stream reflects the local write automatically.
  Stream<List<BafKnowledgeRow>> watchAllKnowledgeRows({
    bool includeDeleted = false,
  }) {
    if (kIsWeb || _isar == null) {
      return _firestore.collection(collectionPath).snapshots().map((snap) {
        final rows =
            snap.docs
                .map((doc) => BafKnowledgeRow.fromCloudMap(doc.data(), doc.id))
                .where((row) => includeDeleted || !row.isDeleted)
                .toList()
              ..sort((a, b) => a.rowCode.compareTo(b.rowCode));
        return rows;
      });
    }

    return _rows!.where().watch(fireImmediately: true).map((rows) {
      return rows.where((row) => includeDeleted || !row.isDeleted).toList()
        ..sort((a, b) => a.rowCode.compareTo(b.rowCode));
    });
  }

  /// Snapshot helper used by import/conflict/governance flows.
  Future<List<BafKnowledgeRow>> getAllLocalRows({
    bool includeDeleted = false,
  }) async {
    if (kIsWeb || _isar == null) {
      final snap = await _firestore.collection(collectionPath).get();
      return snap.docs
          .map((doc) => BafKnowledgeRow.fromCloudMap(doc.data(), doc.id))
          .where((row) => includeDeleted || !row.isDeleted)
          .toList()
        ..sort((a, b) => a.rowCode.compareTo(b.rowCode));
    }
    final rows = await _rows!.where().findAll();
    return rows.where((row) => includeDeleted || !row.isDeleted).toList()
      ..sort((a, b) => a.rowCode.compareTo(b.rowCode));
  }

  Stream<BafKnowledgeMatrixMeta> watchMatrixMeta() {
    if (kIsWeb || _isar == null) {
      return _firestore.doc(metaPath).snapshots().map((doc) {
        final data = doc.data();
        if (data == null) return BafKnowledgeMatrixMeta.staticFallback();
        return BafKnowledgeMatrixMeta.fromMap(<String, dynamic>{
          ...data,
          'source': 'cloud',
        }, localCachedAt: DateTime.now());
      });
    }

    return _meta!.where().watch(fireImmediately: true).asyncMap((items) async {
      if (items.isEmpty) {
        await seedStaticFallbackIntoLocal();
        final seeded = await _meta!.where().findAll();
        if (seeded.isNotEmpty) {
          return BafKnowledgeMatrixMeta.fromStore(seeded.first);
        }
        return BafKnowledgeMatrixMeta.staticFallback();
      }
      final current = items.firstWhere(
        (item) => item.metaKey == 'current',
        orElse: () => items.first,
      );
      final rowCount = await _activeLocalRowsCount();
      final tagCount = await _activeLocalTagRowsCount();
      return BafKnowledgeMatrixMeta.fromStore(
        current,
        rowCountOverride: rowCount,
        tagCountOverride: tagCount,
      );
    });
  }

  Future<BafKnowledgePullResult> pullCloudToLocal([
    DateTime? since,
    DateTime? through,
  ]) async {
    if (kIsWeb || _isar == null) return const BafKnowledgePullResult();

    if (since != null && through == null) {
      throw const GlobalPullProtocolException(
        'The knowledge-base delta pull has no server upper bound.',
        reasonCode: 'knowledge-server-anchor-missing',
      );
    }
    final collection = _firestore.collection(collectionPath);
    final Query<Map<String, dynamic>> baseQuery =
        through == null
            ? collection
                .orderBy(FieldPath.documentId)
                .limit(_knowledgePullPageSize)
            : globalPullServerWindowQuery(
              collection,
              afterInclusive: since,
              throughInclusive: through,
            ).limit(_knowledgePullPageSize);

    late final QuerySnapshot<Map<String, dynamic>> firstPage;
    late final DocumentSnapshot<Map<String, dynamic>> metaDoc;
    await Future.wait<void>(<Future<void>>[
      baseQuery.get().then((value) => firstPage = value),
      _firestore.doc(metaPath).get().then((value) => metaDoc = value),
    ]);

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var page = firstPage;
    while (true) {
      if (page.docs.isEmpty) break;
      if (through != null) {
        for (final document in page.docs) {
          globalPullServerTimestampFromDocument(document);
        }
      }
      docs.addAll(page.docs);
      if (page.docs.length < _knowledgePullPageSize) break;
      page = await baseQuery.startAfterDocument(page.docs.last).get();
    }
    final metaData = metaDoc.data();
    final metaStore =
        metaData == null
            ? null
            : BafKnowledgeMatrixMetaStore.fromCloudMap(<String, dynamic>{
              ...metaData,
              'source': 'cloud',
            }, localCachedAt: DateTime.now());

    if (docs.isEmpty) return const BafKnowledgePullResult(skipped: 1);

    final remotes = [
      for (final doc in docs) BafKnowledgeRow.fromCloudMap(doc.data(), doc.id),
    ];
    final maxFetchedUpdatedAt = _maxUpdatedAt(remotes);

    var inserted = 0;
    var updated = 0;
    var skipped = 0;

    await _isar.writeTxn(() async {
      for (final remote in remotes) {
        final current =
            await _rows!.where().rowCodeEqualTo(remote.rowCode).findFirst();

        if (current == null) {
          inserted++;
          await _rows!.put(remote);
          continue;
        }

        final remoteWins =
            remote.version > current.version ||
            (remote.version == current.version &&
                remote.updatedAt.isAfter(current.updatedAt));
        if (!remoteWins) {
          skipped++;
          continue;
        }

        // Offline-first safety: never let a pull overwrite a dirty local
        // knowledge row. A higher remote version is a conflict/review case,
        // not permission to discard unsynced Admin/SI knowledge edits.
        if (!current.isSynced) {
          skipped++;
          continue;
        }

        remote.id = current.id;
        updated++;
        await _rows!.put(remote);
      }

      if (metaStore != null) {
        final currentMeta = await _currentMetaStore();
        if (currentMeta != null) metaStore.id = currentMeta.id;
        await _meta!.put(metaStore);
      }
    });

    return BafKnowledgePullResult(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
      maxFetchedUpdatedAt: maxFetchedUpdatedAt,
    );
  }

  DateTime? _maxUpdatedAt(Iterable<BafKnowledgeRow> rows) {
    DateTime? max;
    for (final row in rows) {
      final updatedAt = row.updatedAt;
      if (max == null || updatedAt.isAfter(max)) {
        max = updatedAt;
      }
    }
    return max;
  }

  Future<void> seedStaticFallbackIntoLocal() async {
    if (kIsWeb || _isar == null) return;
    final existing = await _rows!.where().findAll();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final rows =
        BafKnowledgeLayer.entries
            .map(
              (entry) => BafKnowledgeRow.fromEntry(
                entry,
                actorUid: 'staticFallback',
                actorName: 'Embedded safety baseline',
                now: now,
                changeSummary: 'Embedded BAF Knowledge Matrix safety baseline.',
                isSynced: true,
              ),
            )
            .toList();
    final meta = BafKnowledgeMatrixMetaStore.staticFallback();

    await _isar.writeTxn(() async {
      await _rows!.putAll(rows);
      await _meta!.put(meta);
    });
  }

  Future<void> seedCloudBaseline({
    required String actorUid,
    required String actorName,
    required String changeSummary,
  }) async {
    final reason = changeSummary.trim();
    if (reason.length < changeReasonMinLength) {
      throw StateError('Knowledge baseline seed requires a change reason.');
    }
    if (actorUid.trim().isEmpty) {
      throw StateError(
        'Cannot seed cloud knowledge without an authenticated actor.',
      );
    }

    final batch = _firestore.batch();
    final serverNow = FieldValue.serverTimestamp();

    for (final entry in BafKnowledgeLayer.entries) {
      final ref = _firestore.collection(collectionPath).doc(entry.id);
      batch.set(ref, <String, dynamic>{
        ..._entryToCloudMap(entry),
        'rowCode': entry.id,
        'lifecycleStatus': 'active',
        'schemaVersion': 1,
        'version': 1,
        'createdByUid': actorUid,
        'createdByName': actorName,
        'createdAt': serverNow,
        'updatedByUid': actorUid,
        'updatedByName': actorName,
        'updatedAt': serverNow,
        'changeSummary': reason,
        'matrixVersion': BafKnowledgeLayer.matrixVersion,
        'isDeleted': false,
      });
    }

    batch.set(_firestore.doc(metaPath), <String, dynamic>{
      'matrixVersion': BafKnowledgeLayer.matrixVersion,
      'sourceLabel': BafKnowledgeLayer.sourceLabel,
      'maintenanceManualRef': BafKnowledgeLayer.maintenanceManualRef,
      'safetyOperationsManualRef': BafKnowledgeLayer.safetyOperationsManualRef,
      'knowledgeRowCount': BafKnowledgeLayer.knowledgeRowCount,
      'tagRowCount': BafKnowledgeLayer.tagRowCount,
      'source': 'cloud',
      'updatedByUid': actorUid,
      'updatedByName': actorName,
      'updatedAt': serverNow,
      'changeSummary': reason,
      'schemaVersion': 1,
      'version': 1,
      'isDeleted': false,
    });

    batch.set(_firestore.collection('audit_logs').doc(), <String, dynamic>{
      'type': 'knowledge_base_seed',
      'action': 'seed_baseline',
      'performedByUid': actorUid,
      'performedByName': actorName,
      'performedAt': serverNow,
      'details': reason,
      'matrixVersion': BafKnowledgeLayer.matrixVersion,
      'rowCount': BafKnowledgeLayer.knowledgeRowCount,
      'version': 1,
      'isDeleted': false,
    });

    await batch.commit();
    await pullCloudToLocal();
  }

  Future<List<BafKnowledgeRow>> getUnsyncedRows() async {
    if (kIsWeb || _isar == null) return <BafKnowledgeRow>[];
    final rows = await _rows!.where().findAll();
    return rows.where((row) => !row.isSynced && !row.isDeleted).toList();
  }

  Future<int> syncUnsyncedToCloud() async {
    final records = await getUnsyncedRows();
    if (records.isEmpty) return 0;
    var pushed = 0;
    for (final row in records) {
      final snapshot = SyncPushSnapshot(
        id: row.id,
        version: row.version,
        updatedAt: row.updatedAt,
      );
      final receipt = await _pushLocalRow(row);
      pushed++;
      await _applyKnowledgePushReceiptIfUnchanged(snapshot, receipt);
    }
    return pushed;
  }

  Future<void> _applyKnowledgePushReceiptIfUnchanged(
    SyncPushSnapshot snapshot,
    BafKnowledgeRow receipt,
  ) async {
    if (_isar == null || _rows == null) return;

    await _isar.writeTxn(() async {
      final current = await _rows!.get(snapshot.id);
      if (current == null) return;

      if (!snapshot.matches(
        currentVersion: current.version,
        currentUpdatedAt: current.updatedAt,
      )) {
        return;
      }

      receipt
        ..id = current.id
        ..isSynced = true;
      await _rows!.put(receipt);
    });
  }

  Future<BafKnowledgeBundle> _loadWeb({required bool preferCloud}) async {
    if (preferCloud) {
      try {
        final cloud = await _loadFromCloudOnly();
        if (cloud.entries.isNotEmpty) return cloud;
      } on FirebaseException {
        // Continue to static fallback.
      }
    }
    return BafKnowledgeBundle(
      entries: BafKnowledgeLayer.entries,
      meta: BafKnowledgeMatrixMeta.staticFallback(
        cloudUnavailable: preferCloud,
      ),
      source: BafKnowledgeSource.staticFallback,
    );
  }

  Future<BafKnowledgeBundle> _loadFromCloudOnly() async {
    final rowsSnap =
        await _firestore
            .collection(collectionPath)
            .where('lifecycleStatus', isEqualTo: 'active')
            .get();
    final entries = _entriesFromCloudDocs(rowsSnap.docs);
    final meta =
        await fetchCloudMeta() ??
        BafKnowledgeMatrixMeta(
          matrixVersion: 'cloud-unversioned',
          sourceLabel: 'Cloud Knowledge Base',
          source: 'cloud',
          knowledgeRowCount: entries.length,
          tagRowCount:
              entries.where((entry) => entry.deviceTags.isNotEmpty).length,
          note: 'Cloud rows loaded but metadata document was not found.',
        );
    return BafKnowledgeBundle(
      entries: entries,
      meta: meta,
      source: BafKnowledgeSource.cloud,
    );
  }

  Future<BafKnowledgeMatrixMeta?> fetchCloudMeta() async {
    final doc = await _firestore.doc(metaPath).get();
    final data = doc.data();
    if (data == null) return null;
    return BafKnowledgeMatrixMeta.fromMap(<String, dynamic>{
      ...data,
      'source': 'cloud',
    }, localCachedAt: DateTime.now());
  }

  Future<BafKnowledgeBundle> _loadFromIsar() async {
    if (_isar == null) {
      return BafKnowledgeBundle(
        entries: const <BafKnowledgeEntry>[],
        meta: BafKnowledgeMatrixMeta.staticFallback(),
        source: BafKnowledgeSource.isarCache,
      );
    }
    final rows = await _rows!.where().findAll();
    final entries = _entriesFromRows(rows);
    final metaStore = await _currentMetaStore();
    final meta =
        metaStore == null
            ? BafKnowledgeMatrixMeta.staticFallback()
            : BafKnowledgeMatrixMeta.fromStore(
              metaStore,
              sourceOverride: 'isarCache',
              rowCountOverride: entries.length,
              tagCountOverride:
                  entries.where((entry) => entry.deviceTags.isNotEmpty).length,
            );
    return BafKnowledgeBundle(
      entries: entries,
      meta: meta,
      source: BafKnowledgeSource.isarCache,
    );
  }

  List<BafKnowledgeEntry> _entriesFromRows(List<BafKnowledgeRow> rows) {
    final activeRows =
        rows
            .where((row) => !row.isDeleted && row.lifecycleStatus == 'active')
            .toList()
          ..sort((a, b) => a.rowCode.compareTo(b.rowCode));
    return [
      for (var i = 0; i < activeRows.length; i++) activeRows[i].toEntry(i),
    ];
  }

  List<BafKnowledgeEntry> _entriesFromCloudDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final entries = <BafKnowledgeEntry>[];
    for (var i = 0; i < docs.length; i++) {
      final doc = docs[i];
      entries.add(BafKnowledgeRow.fromCloudMap(doc.data(), doc.id).toEntry(i));
    }
    entries.sort(
      (a, b) => a.moduleCandidateCode.compareTo(b.moduleCandidateCode),
    );
    return entries;
  }

  Future<BafKnowledgeMatrixMetaStore?> _currentMetaStore() async {
    if (_meta == null) return null;
    final items = await _meta!.where().findAll();
    for (final item in items) {
      if (item.metaKey == 'current') return item;
    }
    return items.isEmpty ? null : items.first;
  }

  Future<int> _activeLocalRowsCount() async {
    final rows = await _rows!.where().findAll();
    return rows
        .where((row) => !row.isDeleted && row.lifecycleStatus == 'active')
        .length;
  }

  Future<int> _activeLocalTagRowsCount() async {
    final rows = await _rows!.where().findAll();
    return rows
        .where(
          (row) =>
              !row.isDeleted &&
              row.lifecycleStatus == 'active' &&
              row.deviceTags.isNotEmpty,
        )
        .length;
  }

  Future<BafKnowledgeRow> _pushLocalRow(BafKnowledgeRow row) async {
    final isCreate = row.version <= 1 && row.createdByUid == row.updatedByUid;
    final map = row.toCloudMap();
    map['updatedAt'] = FieldValue.serverTimestamp();
    if (isCreate) map['createdAt'] = FieldValue.serverTimestamp();
    final reference = _firestore.collection(collectionPath).doc(row.rowCode);
    DocumentSnapshot<Map<String, dynamic>>? observed;
    try {
      await reference.set(map, SetOptions(merge: !isCreate));
    } catch (_) {
      observed = await reference.get();
      if (!observed.exists ||
          !_knowledgePushReceiptMatches(row, observed.data()!)) {
        rethrow;
      }
    }

    observed ??= await reference.get();
    if (!observed.exists ||
        !_knowledgePushReceiptMatches(row, observed.data()!)) {
      throw StateError(
        'Knowledge row ${row.rowCode} did not match exact post-write readback.',
      );
    }
    return BafKnowledgeRow.fromCloudMap(observed.data()!, observed.id);
  }

  bool _knowledgePushReceiptMatches(
    BafKnowledgeRow local,
    Map<String, dynamic> remoteData,
  ) {
    final remote = BafKnowledgeRow.fromCloudMap(remoteData, local.rowCode);
    final localPayload =
        local.toCloudMap()
          ..remove('createdAt')
          ..remove('updatedAt');
    final remotePayload =
        remote.toCloudMap()
          ..remove('createdAt')
          ..remove('updatedAt');
    return persistedJsonEquivalent(
      jsonEncode(localPayload),
      jsonEncode(remotePayload),
    );
  }

  Map<String, dynamic> _entryToCloudMap(BafKnowledgeEntry entry) {
    return <String, dynamic>{
      ...entry.raw,
      'rowCode': entry.id,
      'moduleCandidateCode': entry.moduleCandidateCode,
      'sourceManual': entry.sourceManual,
      'sourcePage': entry.sourcePage,
      'sourceType': entry.sourceType,
      'assetFamily': entry.assetFamilyKey,
      'functionalSection': entry.functionalSection,
      'componentGroup': entry.componentGroup,
      'taskType': entry.taskType,
      'taskText': entry.taskText,
      'frequency': entry.frequency.name,
      'discipline': entry.discipline.name,
      'ownerDisciplines': entry.ownerDisciplines,
      'safetyClass': entry.safetyClasses,
      'safetyClasses': entry.safetyClasses,
      'procedureRefs': entry.procedureRefs,
      'partRefs': entry.partRefs,
      'deviceTags': entry.deviceTags,
      'targetRefs': entry.targetRefs,
      'suggestedFields':
          entry.suggestedFields.map((field) => field.label).toList(),
      'suggestedFieldPresets':
          entry.suggestedFields.map((field) => field.toMap()).toList(),
      'requiredForClosure':
          entry.requiredForClosureSuggestion == null
              ? 'consult'
              : entry.requiredForClosureSuggestion == true
              ? 'yes'
              : 'no',
      'resolverImpact': entry.resolverImpact,
      'composerReadiness': entry.composerReadiness.name,
      'confidence': entry.confidence.name,
      'consultQuestion': entry.consultQuestion,
    };
  }
}

final bafKnowledgeRepositoryProvider = Provider<BafKnowledgeRepository>((ref) {
  return BafKnowledgeRepository();
});

final bafKnowledgeRowsProvider = StreamProvider<List<BafKnowledgeEntry>>((ref) {
  return ref.watch(bafKnowledgeRepositoryProvider).watchKnowledgeRows();
});

final bafKnowledgeMetaProvider = StreamProvider<BafKnowledgeMatrixMeta>((ref) {
  return ref.watch(bafKnowledgeRepositoryProvider).watchMatrixMeta();
});
