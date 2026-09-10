import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The synchronization path treats a missing remote record as convergence:
///
/// ```dart
/// if (remote == null) {
///   if (record.isDeleted) {
///     convergedRecords.add(record);
///     lastSuccessCount++;
/// ```
///
/// So when the identity read dropped a document it could not decode, a pending
/// local deletion was counted converged and marked synchronized while the
/// remote document still existed - the server was never asked to delete it.
///
/// The behaviour that matters is that an undecodable record reaches the caller
/// as a failure, not as a shorter list. These tests exercise that difference
/// on the real decoder.
void main() {
  ({String id, Map<String, dynamic> data}) doc(
    String id,
    Map<String, dynamic> data,
  ) => (id: id, data: data);

  final malformed = doc('remote-abnormality-1', <String, dynamic>{});

  setUp(resetQuarantinedSnapshotDocumentCount);

  test('the decoder refuses a malformed abnormality rather than guessing', () {
    // If this ever stops throwing, neither strategy below means anything.
    expect(
      () => ChargeAbnormality.fromMap(malformed.data, malformed.id),
      throwsA(isA<Object>()),
    );
  });

  test('strict decoding surfaces the failure instead of a shorter list', () {
    // This is what the identity readers do now. The caller cannot mistake the
    // record for absent, because it never receives a list at all.
    expect(
      () => <({String id, Map<String, dynamic> data})>[
        malformed,
      ].map((d) => ChargeAbnormality.fromMap(d.data, d.id)).toList(),
      throwsA(isA<Object>()),
    );
  });

  test('tolerant decoding would have returned it as absent', () {
    // The same input, decoded the way it briefly was: no error, and a list
    // that cannot say it is short. Indistinguishable from "the remote record
    // does not exist".
    final records = decodeDocuments(
      <({String id, Map<String, dynamic> data})>[malformed],
      ChargeAbnormality.fromMap,
      source: 'ChargeAbnormality',
      onQuarantined: (_, _) {},
    );

    expect(records, isEmpty);
    expect(quarantinedSnapshotDocumentCount, 1);
  });

  test('the identity reader forces decoding before it returns', () {
    // Dart's map() is lazy. A strict decoder that is never iterated would
    // defer the failure past the decision it exists to stop, so the read must
    // force it - here by addAll.
    final source =
        File(
          'lib/features/abnormalities/providers/abnormality_provider.remote.dart',
        ).readAsStringSync();
    final reader = source.substring(
      source.indexOf('getAbnormalitiesByFirestoreIds'),
    );
    final body = reader.substring(0, reader.indexOf('\n  }'));

    expect(body, contains('results.addAll('));
    expect(body, contains('ChargeAbnormality.fromMap(doc.data(), doc.id)'));
    expect(body, isNot(contains('decodeSnapshotDocuments')));
  });

  test('the convergence branch still depends on absence', () {
    // If this stops being true, the reasoning above needs revisiting rather
    // than the tests being deleted.
    final consumer =
        File(
          'lib/core/services/sync_service.directives_abnormalities.dart',
        ).readAsStringSync();

    expect(consumer, contains('if (remote == null) {'));
    expect(consumer, contains('convergedRecords.add(record)'));
  });
}
