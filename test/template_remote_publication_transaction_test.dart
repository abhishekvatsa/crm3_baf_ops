// Only Firestore transport is substituted. Actual repository validation,
// detached candidate, transaction writes and post-commit adoption run unchanged.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/template_closure_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 9, 25);
  final actor = AppUser(
    uid: 'si',
    name: 'SI',
    email: 'si@example.invalid',
    roles: [AppRole.si],
    isApproved: true,
    createdAt: at,
  );
  TemplateVersion draft() => TemplateVersion()
    ..firestoreId = 'draft'
    ..packageFirestoreId = 'package'
    ..isSynced = true
    ..version = 1
    ..versionNumber = 1
    ..createdAt = at
    ..updatedAt = at
    ..createdByUid = actor.uid
    ..createdByName = actor.name
    ..updatedByUid = actor.uid
    ..updatedByName = actor.name
    ..jobTemplateSnapshotJson = '{"jobName":"Checks","assetType":"base"}'
    ..moduleSnapshotsJson =
        '[{"moduleCode":"M","moduleTitle":"Check","requiredForClosure":false}]'
    ..fieldDefinitionsJson =
        '[{"key":"reading","moduleCode":"M","type":"number","label":"Reading"}]'
    ..checklistJson = '[]';

  test(
    'remote publication commits published candidate, pointer and matching audit',
    () async {
      final reviewed = draft()..refreshContentHash();
      final transport = _Firestore({
        'template_versions/draft': reviewed.toMap(),
        'template_packages/package': {'latestVersionNumber': 0},
      });
      await FirestoreTemplateGovernanceRepository(
        firestore: transport,
      ).publishVersion(reviewed, actor: actor, reason: 'Reviewed');
      final version = transport.writes['template_versions/draft']!;
      expect(version['status'], 'published');
      expect(version['publishedByUid'], actor.uid);
      expect(version['publishedAt'], isNotNull);
      expect(version['version'], 2);
      expect(
        transport
            .writes['template_packages/package']!['activeVersionFirestoreId'],
        'draft',
      );
      final audit = transport.writes.entries
          .singleWhere((e) => e.key.startsWith('template_publish_audits/'))
          .value;
      expect(audit['action'], 'published');
      expect(audit['afterHash'], version['contentHash']);
      expect(audit['performedByUid'], version['publishedByUid']);
      expect(reviewed.isPublished, isTrue);
      expect(reviewed.publishedAt?.toIso8601String(), version['publishedAt']);
    },
  );

  for (final rejected in ['newer draft', 'transport rejection']) {
    test(
      '$rejected leaves the reviewed caller as an unchanged draft',
      () async {
        final reviewed = draft()..refreshContentHash();
        final before = reviewed.toMap();
        final transport = _Firestore({
          'template_versions/draft': {
            ...before,
            if (rejected == 'newer draft') 'version': 2,
          },
          'template_packages/package': {'latestVersionNumber': 0},
        }, rejectCommit: rejected == 'transport rejection');
        await expectLater(
          FirestoreTemplateGovernanceRepository(
            firestore: transport,
          ).publishVersion(reviewed, actor: actor),
          throwsStateError,
        );
        expect(reviewed.toMap(), before);
        expect(transport.writes, isEmpty);
      },
    );
  }

  test(
    'publication retains native creation timestamp from the saved draft',
    () async {
      final reviewed = draft()..refreshContentHash();
      final origin = Timestamp.fromDate(reviewed.createdAt);
      final transport = _Firestore({
        'template_versions/draft': {...reviewed.toMap(), 'createdAt': origin},
        'template_packages/package': {'latestVersionNumber': 0},
      });
      await FirestoreTemplateGovernanceRepository(
        firestore: transport,
      ).publishVersion(reviewed, actor: actor, reason: 'Reviewed');
      expect(transport.writes['template_versions/draft']!['createdAt'], origin);
      expect(
        transport.writes['template_versions/draft']!['status'],
        'published',
      );
    },
  );

  test(
    'remote save refuses invalid inherited review before writes and preserves creation before fresh review',
    () async {
      final candidate = draft()
        ..firestoreId = 'timeline-draft'
        ..createdAt = at.add(const Duration(days: 1))
        ..jobTemplateSnapshotJson = jsonEncode({
          'jobName': 'Checks',
          'assetType': 'base',
          'composer': {
            'closureReviewConfirmed': true,
            'closureReviewConfirmedByUid': actor.uid,
            'closureReviewConfirmedByName': actor.name,
            'closureReviewConfirmedAt': at.toIso8601String(),
          },
        });
      final transport = _Firestore({});
      final repo = FirestoreTemplateGovernanceRepository(firestore: transport);
      await expectLater(
        repo.saveVersion(candidate, actor: actor),
        throwsFormatException,
      );
      expect(transport.writes, isEmpty);
      final created = candidate.createdAt;
      clearTemplateClosureReview(candidate);
      confirmTemplateClosureReview(
        candidate,
        actorUid: actor.uid,
        actorName: actor.name,
        confirmedAt: created.add(const Duration(seconds: 1)),
      );
      await repo.saveVersion(candidate, actor: actor);
      final read = TemplateVersion.fromMap(
        transport.writes['template_versions/timeline-draft']!,
        'timeline-draft',
      );
      expect(read.createdAt, created);
      expect(
        read.closureReviewConfirmedAt,
        created.add(const Duration(seconds: 1)),
      );
      expect(read.closureReviewConfirmedByUid, actor.uid);
    },
  );
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.documents, {this.rejectCommit = false});
  final Map<String, Map<String, dynamic>> documents;
  final bool rejectCommit;
  Map<String, Map<String, dynamic>> writes = {};
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(documents);
    final result = await handler(transaction);
    if (rejectCommit) throw StateError('Transport rejected transaction');
    writes = transaction.writes;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.path);
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference('${this.path}/$path');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot<T> implements DocumentSnapshot<T> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  final Map<String, Map<String, dynamic>> writes = {};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async => _Snapshot(reference.id, documents[reference.path] as T?);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
