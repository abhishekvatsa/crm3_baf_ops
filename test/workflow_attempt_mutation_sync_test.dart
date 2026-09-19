import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_attempt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_pull_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/test_isar_core.dart';

const _oldCursor = 'last_maintenance_workflow_pull_v2_attempts';
const _mutationCursor = 'last_maintenance_workflow_pull_v2_attempt_updates_v3';
final _start = DateTime.utc(2026, 9, 19, 8);

Map<String, dynamic> _attempt(
  int minute, {
  int? reviewedMinute,
  bool accepted = false,
}) => {
  'complianceRequestId': 'request-$minute',
  'attemptNumber': 1,
  'attemptedByUid': 'receiving-agency',
  'attemptedByName': 'Receiving agency',
  'attemptedAt': Timestamp.fromDate(_start.add(Duration(minutes: minute))),
  if (reviewedMinute != null)
    'updatedAt': Timestamp.fromDate(
      _start.add(Duration(minutes: reviewedMinute)),
    ),
  'note': 'Synthetic preserved response',
  'accepted': accepted,
  if (accepted) ...{
    'acceptedByUid': 'origin-agency',
    'acceptedAt': Timestamp.fromDate(
      _start.add(Duration(minutes: reviewedMinute!)),
    ),
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar isar;
  late _Firestore remote;

  Future<void> open() async {
    isar = await Isar.open(
      [ComplianceAttemptRecordSchema],
      directory: directory.path,
      name: 'attempt_mutation_sync',
      inspector: false,
    );
  }

  Future<WorkflowPullSummary> pull() => WorkflowPullService(
    remote: FirestoreWorkflowReadRepository(remote),
    local: IsarWorkflowRepository(isar),
  ).pull();

  Future<ComplianceAttemptRecord> row(String id) async => (await isar
      .complianceAttemptRecords
      .where()
      .firestoreIdEqualTo(id)
      .findFirst())!;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp(
      'workflow_attempt_review_',
    );
    await open();
    remote = _Firestore();
  });
  tearDown(() async {
    if (isar.isOpen) await isar.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test(
    'upgrade rescans reviews already missed by the attemptedAt checkpoint',
    () async {
      final oldBoundary = _start
          .add(const Duration(minutes: 30))
          .toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_oldCursor, oldBoundary);
      remote.attempts.addAll({
        'old-reviewed': _attempt(1, reviewedMinute: 20, accepted: true),
        'newer-attempt': _attempt(30, reviewedMinute: 30),
        'legacy-without-update': _attempt(2),
      });
      await IsarWorkflowRepository(isar).upsertComplianceAttemptFromRemote(
        complianceAttemptRecordFromFirestoreData(
          documentId: 'old-reviewed',
          data: _attempt(1),
        ),
      );
      final result = await pull();
      expect(result.hasFailures, isFalse);
      expect(result.attempts, 3);
      expect((await row('old-reviewed')).accepted, isTrue);
      expect(
        (await row('old-reviewed')).attemptedAt.toUtc(),
        _start.add(const Duration(minutes: 1)),
      );
      expect(
        (await row('legacy-without-update')).note,
        'Synthetic preserved response',
      );
      expect(
        prefs.getString(_oldCursor),
        oldBoundary,
        reason: 'Historical checkpoint remains intact.',
      );
      expect(prefs.getString(_mutationCursor), oldBoundary);
    },
  );

  test(
    'older acceptance and return converge after newer attempts and native restart',
    () async {
      remote.attempts.addAll({
        'old-accepted': _attempt(1, reviewedMinute: 1),
        'old-returned': _attempt(2, reviewedMinute: 2),
        'newer-attempt': _attempt(30, reviewedMinute: 30),
      });
      expect((await pull()).hasFailures, isFalse);
      await isar.close();
      await open();
      remote.attempts['old-accepted'] = _attempt(
        1,
        reviewedMinute: 40,
        accepted: true,
      );
      remote.attempts['old-returned'] = {
        ..._attempt(2, reviewedMinute: 40),
        'returnedByUid': 'origin-agency',
        'returnedAt': Timestamp.fromDate(
          _start.add(const Duration(minutes: 40)),
        ),
        'returnReason': 'Further evidence required',
      };
      expect((await pull()).hasFailures, isFalse);
      expect((await row('old-accepted')).accepted, isTrue);
      expect(
        (await row('old-returned')).returnReason,
        'Further evidence required',
      );
      expect(
        (await row('old-returned')).attemptedAt.toUtc(),
        _start.add(const Duration(minutes: 2)),
      );
      expect(await isar.complianceAttemptRecords.count(), 3);
      expect((await pull()).hasFailures, isFalse);
      expect(await isar.complianceAttemptRecords.count(), 3);
    },
  );

  test(
    'interrupted rescan holds checkpoint and all equal-time pages recover',
    () async {
      for (var i = 0; i < 501; i++) {
        remote.attempts['attempt-${i.toString().padLeft(3, '0')}'] = _attempt(
          1,
          reviewedMinute: 1,
        );
      }
      remote.failAttemptsPage = 2;
      final failed = await pull();
      final prefs = await SharedPreferences.getInstance();
      expect(failed.failures, contains('attempts'));
      expect(prefs.getString(_mutationCursor), isNull);
      expect(await isar.complianceAttemptRecords.count(), 0);
      await isar.close();
      await open();
      remote.failAttemptsPage = null;
      remote.attemptPages = 0;
      final retried = await pull();
      expect(retried.hasFailures, isFalse);
      expect(retried.attempts, 501);
      expect(await isar.complianceAttemptRecords.count(), 501);
      expect(
        remote.attemptPages,
        6,
        reason: 'Three ordered pages per compatibility leg.',
      );
      expect(
        prefs.getString(_mutationCursor),
        _start.add(const Duration(minutes: 1)).toIso8601String(),
      );
    },
  );
}

// The SDK boundary models ordering, missing-field exclusion and pagination.
// Decoding, both remote query legs, pull checkpoints and native writes are real.
class _Firestore extends Fake implements FirebaseFirestore {
  final attempts = <String, Map<String, dynamic>>{};
  int attemptPages = 0;
  int? failAttemptsPage;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Query(this, path);
}

// ignore: subtype_of_sealed_class
class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(
    this.database,
    this.path, {
    this.field,
    this.lowerBound,
    this.pageSize,
    this.cursor,
  });
  final _Firestore database;
  @override
  final String path;
  final String? field;
  final Timestamp? lowerBound;
  final int? pageSize;
  final _Document? cursor;

  _Query copy({
    String? field,
    Timestamp? lowerBound,
    int? pageSize,
    _Document? cursor,
  }) => _Query(
    database,
    path,
    field: field ?? this.field,
    lowerBound: lowerBound ?? this.lowerBound,
    pageSize: pageSize ?? this.pageSize,
    cursor: cursor ?? this.cursor,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #where:
        return copy(
          field: invocation.positionalArguments.single as String,
          lowerBound:
              invocation.namedArguments[#isGreaterThanOrEqualTo] as Timestamp,
        );
      case #orderBy:
        final key = invocation.positionalArguments.single;
        return key is String ? copy(field: key) : this;
      case #limit:
        return copy(pageSize: invocation.positionalArguments.single as int);
      case #startAfterDocument:
        return copy(cursor: invocation.positionalArguments.single as _Document);
      case #get:
        return _get();
      default:
        return super.noSuchMethod(invocation);
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _get() async {
    if (path != 'compliance_attempts') return _Snapshot([]);
    database.attemptPages++;
    if (database.attemptPages == database.failAttemptsPage) {
      throw StateError('Interrupted page fetch');
    }
    int compare(_Document left, _Document right) {
      final time = (left.row[field] as Timestamp).compareTo(
        right.row[field] as Timestamp,
      );
      return time == 0 ? left.id.compareTo(right.id) : time;
    }

    final rows = [
      for (final entry in database.attempts.entries)
        if (entry.value[field] != null &&
            (lowerBound == null ||
                (entry.value[field] as Timestamp).compareTo(lowerBound!) >= 0))
          _Document(entry.key, Map.of(entry.value)),
    ]..sort(compare);
    return _Snapshot(
      rows
          .where((row) => cursor == null || compare(row, cursor!) > 0)
          .take(pageSize!)
          .toList(),
    );
  }
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.id, this.row);
  @override
  final String id;
  final Map<String, dynamic> row;
  @override
  Map<String, dynamic> data() => row;
}
