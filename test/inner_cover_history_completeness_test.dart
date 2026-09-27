import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/presentation/widgets/inner_cover_history.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final byBase in [false, true]) {
    test(
      'real ${byBase ? 'Base' : 'cover'} history reader keeps rejected and cache evidence',
      () async {
        final query = _Query();
        final repository = AssetHierarchyRepository(
          firestore: _Firestore(query),
          functions: _Functions(),
        );
        final stream = byBase
            ? repository.watchBaseInnerCoverHistory('base-1')
            : repository.watchInnerCoverHistory('cover-1');
        final iterator = StreamIterator(stream);
        addTearDown(() async {
          await iterator.cancel();
          await query.updates.close();
        });
        expect(query.field, byBase ? 'baseAssetInstanceId' : 'innerCoverId');
        expect(query.metadataChanges, isTrue);
        query.updates.add(
          _Snapshot([
            _Document('z', _record('z')),
            _Document('broken', const {}),
            _Document('a', _record('a')),
          ], cache: true),
        );
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.records.map((r) => r.id), ['a', 'z']);
        expect(iterator.current.rejectedDocumentIds, ['broken']);
        expect(iterator.current.isComplete, isFalse);
        expect(iterator.current.isServerConfirmed, isFalse);

        query.updates.add(_Snapshot([_Document('a', _record('a'))]));
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.records.single.id, 'a');
        expect(iterator.current.isComplete, isTrue);
        expect(iterator.current.isServerConfirmed, isTrue);
      },
    );
  }

  for (final state in ['cache', 'rejected', 'pending', 'error']) {
    testWidgets('$state empty history never claims there were no assignments', (
      tester,
    ) async {
      final value = state == 'error'
          ? AsyncError<DecodedSnapshotBatch<InnerCoverLinkage>>(
              StateError('Unavailable'),
              StackTrace.current,
            )
          : AsyncData(
              _batch(
                const [],
                cache: state == 'cache',
                rejected: state == 'rejected',
                pending: state == 'pending',
              ),
            );
      await _pump(tester, value);
      expect(find.textContaining('No Base linkage'), findsNothing);
      expect(find.textContaining('No Inner Cover assignment'), findsNothing);
      expect(
        find.textContaining(
          state == 'error'
              ? 'History unavailable'
              : state == 'rejected'
              ? 'History incomplete'
              : 'not yet server-confirmed',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'complete server-empty history may state no recorded assignments',
    (tester) async {
      await _pump(tester, AsyncData(_batch(const [])));
      expect(
        find.text('No Base linkage has been recorded for this cover.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'valid rows remain through partial data, error and refresh, then recover',
    (tester) async {
      final row = InnerCoverLinkage.fromMap(_record('a', closed: true), 'a');
      await _pump(tester, AsyncData(_batch([row], rejected: true)));
      expect(find.text('Base 101'), findsOneWidget);
      expect(find.textContaining('History incomplete'), findsOneWidget);
      expect(find.text('Removed physically: 25-09-2026 10:00'), findsOneWidget);
      expect(find.text('Removal recorded 26-09-2026 11:00'), findsOneWidget);
      await _pump(
        tester,
        AsyncError(StateError('Permission denied'), StackTrace.current),
      );
      expect(find.text('Base 101'), findsOneWidget);
      expect(
        find.textContaining('Showing the last loaded entries'),
        findsOneWidget,
      );
      await _pump(tester, const AsyncLoading());
      expect(find.text('Base 101'), findsOneWidget);
      expect(find.text('Checking history…'), findsOneWidget);
      await _pump(tester, AsyncData(_batch([row])));
      expect(find.textContaining('History incomplete'), findsNothing);
      expect(find.textContaining('History unavailable'), findsNothing);
      expect(find.text('Base 101'), findsOneWidget);
    },
  );

  testWidgets('retained history never leaks into a different subject', (
    tester,
  ) async {
    await _pump(
      tester,
      AsyncData(_batch([InnerCoverLinkage.fromMap(_record('a'), 'a')])),
    );
    await _pump(tester, const AsyncLoading(), subject: 'another-cover');
    expect(find.text('Base 101'), findsNothing);
  });

  testWidgets(
    'history cards retain labels and physical/recorded times at 320px and large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        AsyncData(
          _batch([InnerCoverLinkage.fromMap(_record('a', closed: true), 'a')]),
        ),
        scale: 1.6,
      );
      expect(find.text('Previous assignment'), findsOneWidget);
      expect(find.text('Removed physically: 25-09-2026 10:00'), findsOneWidget);
      expect(find.text('Removal recorded 26-09-2026 11:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<DecodedSnapshotBatch<InnerCoverLinkage>> history, {
  String subject = 'cover-1',
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: InnerCoverHistory(
                subjectId: subject,
                showBase: true,
                history: history,
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

DecodedSnapshotBatch<InnerCoverLinkage> _batch(
  List<InnerCoverLinkage> rows, {
  bool rejected = false,
  bool cache = false,
  bool pending = false,
}) => DecodedSnapshotBatch(
  records: rows,
  rejectedDocumentIds: rejected ? ['broken'] : [],
  isFromCache: cache,
  hasPendingWrites: pending,
);

Map<String, dynamic> _record(String id, {bool closed = false}) => {
  'schemaVersion': 1,
  'linkageId': id,
  'baseAssetInstanceId': 'base-1',
  'baseAssetNumber': 101,
  'baseAssetName': 'Base 101',
  'innerCoverId': 'cover-1',
  'innerCoverSerialNumber': 'GR-TEST',
  'installedAt': DateTime(2026, 9, 20, 8),
  'installedByUid': 'demo-admin',
  'installedByName': 'Demo Admin',
  'active': !closed,
  'version': closed ? 2 : 1,
  if (closed) ...{
    'removedPhysicalAt': DateTime(2026, 9, 25, 10),
    'removedAt': DateTime(2026, 9, 26, 11),
    'removedByUid': 'demo-admin',
    'removedByName': 'Demo Admin',
    'removalAction': 'DELINK_INNER_COVER',
    'removalReason': 'Inspection required',
  },
};

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.query);
  final _Query query;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => query;
}

class _Functions extends Fake implements FirebaseFunctions {}

// Firestore has no public snapshot/query constructors; this test exercises the real decoder.
// ignore: subtype_of_sealed_class
class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  final updates = StreamController<QuerySnapshot<Map<String, dynamic>>>();
  final observed = <String, Object?>{};
  bool get metadataChanges => observed['metadataChanges'] == true;
  String? get field => observed['field'] as String?;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      observed['field'] = invocation.positionalArguments.single as String;
      return this;
    }
    return super.noSuchMethod(invocation);
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    observed['metadataChanges'] = includeMetadataChanges;
    return updates.stream;
  }
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs, {bool cache = false}) : metadata = _Metadata(cache);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  final SnapshotMetadata metadata;
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.isFromCache);
  @override
  final bool isFromCache;
  @override
  bool get hasPendingWrites => false;
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}
