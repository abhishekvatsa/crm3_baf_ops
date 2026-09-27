// The adapter fake records the actual Firestore query boundary.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/abnormalities/services/abnormality_cause_evidence_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maintenance choices read the exact charge from the server', () async {
    final store = _Store({
      'issue-one': {'description': 'Seal inspection'},
      'deleted': {'description': 'Removed', 'isDeleted': true},
    });
    final choices = await AbnormalityCauseEvidenceReader(
      firestore: store,
    ).load(sourceChargeNo: 12345, maintenance: true);
    expect(store.collectionPath, 'maintenance_records');
    expect(store.field, 'chargeNoAtEvent');
    expect(store.charge, 12345);
    expect(store.options?.source, Source.server);
    expect(choices.map((choice) => choice.id), ['issue-one']);
    expect(choices.single.label, 'Seal inspection');
  });

  test(
    'process choices preserve identity and exclude result or self links',
    () async {
      final store = _Store({
        'process': {
          'category': 'other',
          'assessment': {'observationKind': 'processEquipment'},
          'observedReason': 'Pressure interruption',
        },
        'legacy': {'category': 'equipment'},
        'result': {
          'category': 'equipment',
          'assessment': {'observationKind': 'resultFinding'},
        },
        'wrong-category': {
          'category': 'resultQuality',
          'assessment': {'observationKind': 'processEquipment'},
        },
        'self': {'category': 'process'},
        'deleted': {'category': 'process', 'isDeleted': true},
      });
      final choices = await AbnormalityCauseEvidenceReader(
        firestore: store,
      ).load(sourceChargeNo: 12345, maintenance: false, abnormalityId: 'self');
      expect(store.collectionPath, 'charge_abnormalities');
      expect(store.field, 'sourceChargeNo');
      expect(store.charge, 12345);
      expect(store.options?.source, Source.server);
      expect(choices.map((choice) => choice.id), ['process', 'legacy']);
      expect(choices.map((choice) => choice.label), [
        'Pressure interruption',
        'Recorded observation',
      ]);
    },
  );

  test(
    'failed server read remains a failure rather than empty choices',
    () async {
      final store = _Store({})..failure = StateError('server unavailable');
      await expectLater(
        AbnormalityCauseEvidenceReader(
          firestore: store,
        ).load(sourceChargeNo: 12345, maintenance: true),
        throwsStateError,
      );
    },
  );
}

class _Store extends Fake implements FirebaseFirestore {
  _Store(this.rows);
  final Map<String, Map<String, dynamic>> rows;
  String? collectionPath;
  Object? field;
  Object? charge;
  GetOptions? options;
  Object? failure;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    collectionPath = path;
    return _Query(this);
  }
}

class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(this.store);
  final _Store store;

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
  }) {
    store.field = field;
    store.charge = isEqualTo;
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    store.options = options;
    if (store.failure case final failure?) throw failure;
    return _Snapshot(store.rows);
  }
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.rows);
  final Map<String, Map<String, dynamic>> rows;
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs =>
      rows.entries.map((entry) => _Document(entry.key, entry.value)).toList();
}

class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.id, this.row);
  @override
  final String id;
  final Map<String, dynamic> row;
  @override
  Map<String, dynamic> data() => row;
}
