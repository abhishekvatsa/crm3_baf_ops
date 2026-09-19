import '../../../core/serialization/persisted_data_reader.dart';

class BurnerBlockInstallationCorrection {
  const BurnerBlockInstallationCorrection({
    required this.id,
    required this.eventId,
    required this.expectedCurrentEventId,
    required this.assetInstanceId,
    required this.burnerPosition,
    required this.originalAt,
    required this.effectiveAt,
    required this.correctedAt,
    required this.reason,
    required this.reviewerUid,
    required this.reviewerName,
    this.supersedesId,
  });
  final String id, eventId, assetInstanceId, reason, reviewerUid, reviewerName;
  final String expectedCurrentEventId;
  final String? supersedesId;
  final int burnerPosition;
  final DateTime originalAt, effectiveAt, correctedAt;

  factory BurnerBlockInstallationCorrection.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final source = 'burner_block_lifecycle_corrections/$id';
    String text(String field) =>
        readRequiredPersistedString(map[field], field: field, source: source);
    final version = readRequiredPersistedInt(
      map['version'],
      field: 'version',
      source: source,
      minimum: 1,
    );
    final schema = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    final position = readRequiredPersistedInt(
      map['burnerPosition'],
      field: 'burnerPosition',
      source: source,
      minimum: 1,
    );
    final originalAt = readRequiredPersistedDateTime(
      map['recordedActionPerformedAt'],
      field: 'recordedActionPerformedAt',
      source: source,
    );
    final effectiveAt = readRequiredPersistedDateTime(
      map['correctedActionPerformedAt'],
      field: 'correctedActionPerformedAt',
      source: source,
    );
    final correctedAt = readRequiredPersistedDateTime(
      map['correctedAt'],
      field: 'correctedAt',
      source: source,
    );
    final supersedes = readOptionalPersistedString(
      map['supersedesCorrectionId'],
      field: 'supersedesCorrectionId',
      source: source,
    );
    if (text('correctionId') != id ||
        version != 1 ||
        schema != 1 ||
        position > 8 ||
        supersedes == id ||
        effectiveAt.isAfter(correctedAt)) {
      throw PersistedDataFormatException(
        field: 'correctionId',
        source: source,
        detail: 'invalid correction identity, revision or chronology',
      );
    }
    return BurnerBlockInstallationCorrection(
      id: id,
      eventId: text('correctsEventId'),
      expectedCurrentEventId: text('expectedCurrentEventId'),
      assetInstanceId: text('assetInstanceId'),
      burnerPosition: position,
      originalAt: originalAt.toUtc(),
      effectiveAt: effectiveAt.toUtc(),
      correctedAt: correctedAt.toUtc(),
      reason: text('reason'),
      reviewerUid: text('correctedByUid'),
      reviewerName: text('correctedByName'),
      supersedesId: supersedes,
    );
  }
}

/// Require one complete, unbranched chain. A missing predecessor must not look
/// like an event that has never been corrected.
BurnerBlockInstallationCorrection? effectiveBurnerBlockCorrection(
  List<BurnerBlockInstallationCorrection> rows,
  String eventId,
) {
  if (rows.isEmpty) return null;
  final byId = {for (final row in rows) row.id: row};
  final superseded = <String>{};
  for (final row in rows) {
    final prior = row.supersedesId;
    if (row.eventId != eventId ||
        byId.length != rows.length ||
        (prior != null &&
            (!byId.containsKey(prior) || !superseded.add(prior)))) {
      throw StateError(
        'Installation correction history is incomplete or conflicting.',
      );
    }
  }
  final terminal = rows.where((row) => !superseded.contains(row.id)).toList();
  if (terminal.length != 1) {
    throw StateError(
      'Installation correction history has no unique current revision.',
    );
  }
  final visited = <String>{};
  BurnerBlockInstallationCorrection? cursor = terminal.single;
  while (cursor != null && visited.add(cursor.id)) {
    cursor = cursor.supersedesId == null ? null : byId[cursor.supersedesId];
  }
  if (cursor != null || visited.length != rows.length) {
    throw StateError(
      'Installation correction history contains a cycle or disconnected revisions.',
    );
  }
  return terminal.single;
}
