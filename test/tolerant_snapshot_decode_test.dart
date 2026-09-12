import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every live Firestore stream decoded its documents inside an unguarded
/// `map`. The decoders are strict, so one damaged document threw for the whole
/// snapshot, the stream ended in error, and every screen fed by it went blank.
/// An asset register with a single bad row stopped operators selecting any
/// asset at all, and the ticket form then refused a selection they could still
/// see on screen.
///
/// The governed pull path already quarantines a bad record and carries on.
/// These tests hold live reads to the same disposition.
void main() {
  setUp(resetQuarantinedSnapshotDocumentCount);

  ({String id, Map<String, dynamic> data}) doc(String id, String name) =>
      (id: id, data: <String, dynamic>{'name': name});

  String decodeName(Map<String, dynamic> data, String id) {
    final name = data['name'];
    if (name is! String || name.isEmpty) {
      throw FormatException('$id has no usable name');
    }
    return name;
  }

  group('a malformed document', () {
    test('does not take the rest of the collection with it', () {
      final quarantined = <String>[];

      final records = decodeDocuments(
        <({String id, Map<String, dynamic> data})>[
          doc('base-205', 'BASE 205'),
          (id: 'broken', data: <String, dynamic>{'name': 42}),
          doc('furnace-6', 'FURNACE 6'),
        ],
        decodeName,
        source: 'AssetInstanceRecord',
        onQuarantined: (id, _) => quarantined.add(id),
      );

      // The whole point: the good rows still arrive.
      expect(records, <String>['BASE 205', 'FURNACE 6']);
      expect(quarantined, <String>['broken']);
    });

    test('is counted so support can see the list is incomplete', () {
      decodeDocuments(
        <({String id, Map<String, dynamic> data})>[
          (id: 'broken-1', data: <String, dynamic>{}),
          doc('ok', 'BASE 205'),
          (id: 'broken-2', data: <String, dynamic>{'name': ''}),
        ],
        decodeName,
        source: 'AssetInstanceRecord',
        onQuarantined: (_, _) {},
      );

      // Without a count, a quarantined row is indistinguishable from a row
      // that was never there.
      expect(quarantinedSnapshotDocumentCount, 2);
    });

    test('is reported rather than silently dropped', () {
      final reported = <String, Object>{};

      decodeDocuments(
        <({String id, Map<String, dynamic> data})>[
          (id: 'broken', data: <String, dynamic>{'name': null}),
        ],
        decodeName,
        source: 'AbnormalityType',
        onQuarantined: (id, error) => reported[id] = error,
      );

      expect(reported.keys, <String>['broken']);
      expect(reported['broken'], isA<FormatException>());
    });

    test('is never repaired or substituted', () {
      final records = decodeDocuments(
        <({String id, Map<String, dynamic> data})>[
          (id: 'broken', data: <String, dynamic>{'name': 42}),
        ],
        decodeName,
        source: 'AssetInstanceRecord',
        onQuarantined: (_, _) {},
      );

      // A placeholder row would be worse than an absent one: it would look
      // like a real asset an operator could raise an issue against.
      expect(records, isEmpty);
    });
  });

  group('an intact collection', () {
    test('decodes every document and quarantines nothing', () {
      final records = decodeDocuments(
        <({String id, Map<String, dynamic> data})>[
          doc('a', 'BASE 205'),
          doc('b', 'FURNACE 6'),
        ],
        decodeName,
        source: 'AssetInstanceRecord',
      );

      expect(records, <String>['BASE 205', 'FURNACE 6']);
      expect(quarantinedSnapshotDocumentCount, 0);
    });

    test('returns a growable list, because callers sort it', () {
      // The callers do `..sort(...)` on the result. An unmodifiable list would
      // make that a runtime failure at every site.
      final records = decodeDocuments(
        <({String id, Map<String, dynamic> data})>[
          doc('b', 'FURNACE 6'),
          doc('a', 'BASE 205'),
        ],
        decodeName,
        source: 'AssetInstanceRecord',
      );

      expect(() => records.sort(), returnsNormally);
      expect(records, <String>['BASE 205', 'FURNACE 6']);
    });

    test('an empty collection is not an error', () {
      expect(
        decodeDocuments(
          const <({String id, Map<String, dynamic> data})>[],
          decodeName,
          source: 'AssetInstanceRecord',
        ),
        isEmpty,
      );
    });
  });
}
