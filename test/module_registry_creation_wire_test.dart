// Real registry repository and domain readers; only Firestore is replaced.
// Registry models are remote-only, so no Isar path applies to these writers.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/module_registry_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_composer_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/module_registry_concurrency.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/module_registry_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final created = DateTime.utc(2026, 9, 10, 12, 30);
  final actor = AppUser(
    uid: 'si',
    name: 'SI',
    email: 'si@example.invalid',
    roles: [AppRole.si],
    isApproved: true,
    createdAt: created,
  );
  ComposerModuleDraft module() => ComposerModuleDraft.manual()
    ..moduleCode = 'WIRE-REGISTRY'
    ..title = 'Registry origin test'
    ..description = 'Recorded work instructions'
    ..functionalSection = 'Seal'
    ..componentGroup = 'Furnace';
  final familyId = moduleRegistryIdForModule(module());
  final familyPath = 'module_registry/$familyId';
  final revisionPath = '$familyPath/revisions/revision';

  _Firestore fixture(Object wire, {bool published = false}) {
    final family = ModuleRegistryFamily.fromModule(
      module: module(),
      actor: actor,
      now: created,
    );
    final revision = ModuleRegistryRevision.draftFromModule(
      registryModuleId: familyId,
      revisionId: 'revision',
      module: module(),
      actor: actor,
      lineage: const {'sourceType': 'test'},
      now: created,
    );
    if (published) {
      revision.publish(actor: actor, revisionNumber: 1, now: created);
    }
    return _Firestore({
      familyPath: family.toMap()..['createdAt'] = wire,
      revisionPath: revision.toMap()..['createdAt'] = wire,
    });
  }

  ModuleRegistryRevision readRevision(_Firestore store) =>
      ModuleRegistryRevision.fromMap(
        store.records[revisionPath]!,
        'revision',
        registryModuleId: familyId,
      );
  ModuleRegistryFamily readFamily(_Firestore store) =>
      ModuleRegistryFamily.fromMap(store.records[familyPath]!, familyId);

  for (final encoding in <String, Object>{
    'UTC string': created.toIso8601String(),
    'offset string': '2026-09-10T18:00:00.000+05:30',
    'native Timestamp': Timestamp.fromDate(created),
  }.entries) {
    test(
      '${encoding.key} survives actual draft, publish and both retirement writers',
      () async {
        final store = fixture(encoding.value);
        final repo = ModuleRegistryRepository(firestore: store);
        final edited = module()..title = 'Updated instructions';
        await repo.updateDraftRevision(
          revision: readRevision(store),
          module: edited,
          actor: actor,
          sourceType: 'test',
        );
        expect(store.records[revisionPath]!['createdAt'], encoding.value);
        expect(
          readRevision(store).toComposerModuleDraft().title,
          'Updated instructions',
        );
        final reviewed = readRevision(store);
        await repo.publishDraftRevision(
          registryModuleId: familyId,
          revisionId: 'revision',
          actor: actor,
          reason: 'Reviewed instructions',
          reviewedVersion: reviewed.version,
          reviewedContentHash: reviewed.contentHash,
        );
        expect(store.records[familyPath]!['createdAt'], encoding.value);
        expect(store.records[revisionPath]!['createdAt'], encoding.value);
        // Historical publication evidence can also be stored as a Timestamp.
        final publishedAt = Timestamp.fromDate(
          readRevision(store).publishedAt!,
        );
        store.records[revisionPath]!['publishedAt'] = publishedAt;
        await repo.retirePublishedRevision(
          revision: readRevision(store),
          actor: actor,
          reason: 'Superseded',
        );
        expect(store.records[revisionPath]!['createdAt'], encoding.value);
        expect(store.records[revisionPath]!['publishedAt'], publishedAt);
        expect(readRevision(store).isRetired, isTrue);
        await repo.retireFamily(
          family: readFamily(store),
          actor: actor,
          reason: 'Retired family',
        );
        expect(store.records[familyPath]!['createdAt'], encoding.value);
        expect(readFamily(store).isActive, isFalse);
        expect(
          store.records.keys.where(
            (path) => path.startsWith('module_registry_audits/'),
          ),
          hasLength(4),
        );
      },
    );
  }
  for (final action in [
    'draft edit',
    'revision retirement',
    'family retirement',
  ]) {
    test(
      '$action refuses a genuinely different supplied origin with no writes',
      () async {
        final store = fixture(
          created.toIso8601String(),
          published: action == 'revision retirement',
        );
        final repo = ModuleRegistryRepository(firestore: store);
        final revision = readRevision(store)
          ..createdAt = created.subtract(const Duration(seconds: 1));
        final family = readFamily(store)
          ..createdAt = created.subtract(const Duration(seconds: 1));
        await expectLater(switch (action) {
          'draft edit' => repo.updateDraftRevision(
            revision: revision,
            module: module(),
            actor: actor,
            sourceType: 'test',
          ),
          'revision retirement' => repo.retirePublishedRevision(
            revision: revision,
            actor: actor,
            reason: 'Retire',
          ),
          _ => repo.retireFamily(
            family: family,
            actor: actor,
            reason: 'Retire',
          ),
        }, throwsStateError);
        expect(store.commitAttempts, 0);
      },
    );
  }
  test('new registry family and draft have explicit UTC timestamps', () async {
    final store = _Firestore({});
    final draft = await ModuleRegistryRepository(
      firestore: store,
    ).createDraftFromModule(module: module(), actor: actor, sourceType: 'test');
    for (final path in [
      familyPath,
      '$familyPath/revisions/${draft.revisionId}',
    ]) {
      expect(store.records[path]!['createdAt'], endsWith('Z'));
      expect(store.records[path]!['updatedAt'], endsWith('Z'));
    }
  });
  test('stale draft review still refuses with no transaction writes', () async {
    final store = fixture(created.toIso8601String());
    final stale = readRevision(store);
    store.records[revisionPath]!['version'] = stale.version + 1;
    await expectLater(
      ModuleRegistryRepository(firestore: store).updateDraftRevision(
        revision: stale,
        module: module(),
        actor: actor,
        sourceType: 'test',
      ),
      throwsA(isA<ModuleRegistryStaleDraftException>()),
    );
    expect(store.commitAttempts, 0);
  });
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.records);
  final Map<String, Map<String, dynamic>> records;
  int nextId = 0;
  int commitAttempts = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final tx = _Transaction(this);
    final result = await handler(tx);
    if (tx.writes.isNotEmpty) {
      commitAttempts++;
      for (final item in tx.writes.entries) {
        final before = records[item.key];
        if (before != null && before['createdAt'] != item.value['createdAt']) {
          throw StateError('Rules refuse changed immutable creation value');
        }
        if (before?['publishedAt'] != null &&
            before!['publishedAt'] != item.value['publishedAt']) {
          throw StateError('Rules refuse changed publication evidence');
        }
      }
      for (final item in tx.writes.entries) {
        records[item.key] = {...?records[item.key], ...item.value};
      }
    }
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
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _Reference(
    owner,
    '${this.path}/${path ?? 'generated-${owner.nextId++}'}',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.owner, this.path);
  final _Firestore owner;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(owner, '${this.path}/$path');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(id, owner.records[path]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.owner);
  final _Firestore owner;
  final writes = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async =>
      _Snapshot(reference.id, owner.records[reference.path])
          as DocumentSnapshot<T>;
  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    writes[reference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> reference,
    Map<Object, Object?> data,
  ) {
    writes[reference.path] = Map<String, dynamic>.from(data);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
