import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A rejected row remains visible as missing evidence, never as an empty source.
class PlantEvidenceBatch<T> {
  const PlantEvidenceBatch({
    required this.rows,
    required this.rejected,
    required this.fromServer,
    required this.observedAt,
  });
  final List<T> rows;
  final Map<String, String> rejected;
  final bool fromServer;
  final DateTime observedAt;
  bool get complete => fromServer && rejected.isEmpty;
}

PlantEvidenceBatch<T> decodePlantEvidence<T>({
  required Map<String, Map<String, dynamic>> documents,
  required T Function(Map<String, dynamic>, String) decode,
  required bool fromServer,
  Map<String, Map<String, dynamic>> previous = const {},
}) {
  final rows = <T>[];
  final rejected = <String, String>{};
  for (final id in previous.keys.where((id) => !documents.containsKey(id))) {
    rejected[id] =
        'Previously observed evidence is now missing; review is required.';
    rows.add(decode(previous[id]!, id));
  }
  for (final entry in documents.entries) {
    try {
      final before = previous[entry.key];
      if (before?['version'] is int &&
          entry.value['version'] is int &&
          (entry.value['version'] as int) < (before!['version'] as int)) {
        throw StateError('The recorded revision moved backwards.');
      }
      if (before != null &&
          before['version'] is int &&
          before['version'] == entry.value['version'] &&
          !_sameEvidence(_businessEvidence(before), _businessEvidence(entry.value))) {
        throw StateError('Conflicting content at the same recorded revision.');
      }
      rows.add(decode(entry.value, entry.key));
    } catch (error) {
      rejected[entry.key] = error.toString();
      final known = previous[entry.key];
      if (known != null) rows.add(decode(known, entry.key));
    }
  }
  return PlantEvidenceBatch(
    rows: List.unmodifiable(rows),
    rejected: Map.unmodifiable(rejected),
    fromServer: fromServer,
    observedAt: DateTime.now().toUtc(),
  );
}

Map<String, dynamic> _businessEvidence(Map<String, dynamic> document) => {
  for (final entry in document.entries)
    if (entry.key != '_globalPullServerUpdatedAt') entry.key: entry.value,
};

Stream<PlantEvidenceBatch<T>> watchPlantEvidence<T>(
  FirebaseFirestore firestore,
  String collection,
  T Function(Map<String, dynamic>, String) decode,
) {
  var previous = <String, Map<String, dynamic>>{};
  PlantEvidenceBatch<T>? last;
  return firestore
      .collection(collection)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        final documents = {for (final doc in snapshot.docs) doc.id: doc.data()};
        final batch = decodePlantEvidence(
          documents: documents,
          decode: decode,
          fromServer:
              !snapshot.metadata.isFromCache &&
              !snapshot.metadata.hasPendingWrites,
          previous: previous,
        );
        // Retain the first verified revision to keep a contradiction visible across
        // repeated metadata snapshots, until a legitimate newer revision arrives.
        if (batch.fromServer) {
          for (final entry in documents.entries) {
            if (!batch.rejected.containsKey(entry.key)) {
              previous[entry.key] = entry.value;
            }
          }
        }
        last = batch;
        return batch;
      })
      .transform(
        StreamTransformer<
          PlantEvidenceBatch<T>,
          PlantEvidenceBatch<T>
        >.fromHandlers(
          handleError: (error, stack, sink) {
            // Keep the last readable restrictions while explicitly withdrawing
            // current-server qualification and mutation authority for this feed.
            sink.add(
              PlantEvidenceBatch<T>(
                rows: last?.rows ?? <T>[],
                rejected: {
                  ...?last?.rejected,
                  collection:
                      'Live evidence is unavailable; reconnect and review.',
                },
                fromServer: false,
                observedAt: last?.observedAt ?? DateTime.now().toUtc(),
              ),
            );
          },
        ),
      );
}

bool _sameEvidence(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) =>
              right.containsKey(key) && _sameEvidence(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    return left.length == right.length &&
        List.generate(
          left.length,
          (i) => i,
        ).every((i) => _sameEvidence(left[i], right[i]));
  }
  return left == right;
}
