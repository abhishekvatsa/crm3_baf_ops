import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Decodes a live query snapshot without letting one bad document take the
/// whole stream down.
///
/// Every live Firestore stream in the app decoded its documents like this:
///
/// ```dart
/// snapshot.docs.map((doc) => Record.fromMap(doc.data(), doc.id))
/// ```
///
/// The decoders are strict by design: a missing or malformed persisted field
/// raises rather than guessing. Inside an unguarded `map` that means a single
/// damaged document anywhere in the collection throws for the entire snapshot,
/// the stream ends in error, and every screen fed by it shows nothing. An
/// asset register with one bad row stops every operator selecting any asset;
/// one bad abnormality type empties the whole list.
///
/// The governed pull path already treats this correctly - it quarantines the
/// offending record, counts it, and carries on with the rest. Live reads had
/// no equivalent. This restores the same disposition: the malformed document
/// is skipped and reported, and the records that decode cleanly are still
/// delivered.
///
/// Skipping is deliberately not silent. A quarantined document is real
/// evidence that something upstream is wrong, and hiding it would trade a
/// loud failure for a quiet one. It is reported here and counted for
/// diagnostics; it is never repaired, guessed at or substituted.
List<T> decodeSnapshotDocuments<T>(
  QuerySnapshot<Map<String, dynamic>> snapshot,
  T Function(Map<String, dynamic> data, String documentId) decode, {
  required String source,
  void Function(String documentId, Object error)? onQuarantined,
}) {
  return decodeDocuments(
    snapshot.docs.map(
      (doc) => (id: doc.id, data: doc.data()),
    ),
    decode,
    source: source,
    onQuarantined: onQuarantined,
  );
}

/// The decision itself, free of Firestore types so it can be exercised
/// directly. [decodeSnapshotDocuments] is the adapter over a live snapshot.
List<T> decodeDocuments<T>(
  Iterable<({String id, Map<String, dynamic> data})> documents,
  T Function(Map<String, dynamic> data, String documentId) decode, {
  required String source,
  void Function(String documentId, Object error)? onQuarantined,
}) {
  final records = <T>[];
  for (final document in documents) {
    try {
      records.add(decode(document.data, document.id));
    } catch (error) {
      quarantinedSnapshotDocumentCount += 1;
      if (onQuarantined != null) {
        onQuarantined(document.id, error);
      } else {
        debugPrint(
          'Quarantined malformed $source document ${document.id}: $error. '
          'The remaining documents are still delivered.',
        );
      }
    }
  }
  // Growable on purpose: callers sort and post-process the result, and an
  // unmodifiable list would turn this into a runtime failure at every one of
  // those sites. Callers that publish the list wrap it themselves.
  return records;
}

/// How many documents this process has quarantined since start.
///
/// Support needs to know that a screen is showing an incomplete list. Without
/// it, a quarantined row is indistinguishable from a row that was never there.
int quarantinedSnapshotDocumentCount = 0;

@visibleForTesting
void resetQuarantinedSnapshotDocumentCount() {
  quarantinedSnapshotDocumentCount = 0;
}
