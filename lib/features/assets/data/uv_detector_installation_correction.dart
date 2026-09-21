import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../../core/serialization/persisted_data_reader.dart';

class UvDetectorInstallationCorrection {
  const UvDetectorInstallationCorrection({
    required this.id,
    required this.eventId,
    required this.expectedCurrentEventId,
    required this.expectedCurrentActionPerformedAt,
    required this.assetInstanceId,
    required this.assetClassId,
    required this.assetNumber,
    required this.componentTag,
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
  final String assetClassId;
  final int assetNumber;
  final String? componentTag;
  final String? supersedesId;
  final int burnerPosition;
  final DateTime originalAt, effectiveAt, correctedAt;
  final DateTime expectedCurrentActionPerformedAt;

  factory UvDetectorInstallationCorrection.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final source = 'uv_detector_lifecycle_corrections/$id';
    readBoundedPersistedExtensionBag(
      map,
      knownFields: const {
        'schemaVersion',
        'version',
        'correctionId',
        'correctsEventId',
        'expectedCurrentEventId',
        'expectedCurrentActionPerformedAt',
        'supersedesCorrectionId',
        'assetInstanceId',
        'assetClassId',
        'assetNumber',
        'componentTag',
        'burnerPosition',
        'recordedActionPerformedAt',
        'correctedActionPerformedAt',
        'correctedAt',
        'reason',
        'correctedByUid',
        'correctedByName',
      },
      allowedFields: const <String, PersistedExtensionValueKind>{},
      field: 'extensions',
      source: source,
    );
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
    final assetNumber = readRequiredPersistedInt(
      map['assetNumber'],
      field: 'assetNumber',
      source: source,
      minimum: 1,
    );
    final originalAt = _readCorrectionInstant(
      map['recordedActionPerformedAt'],
      field: 'recordedActionPerformedAt',
      source: source,
    );
    final effectiveAt = _readCorrectionInstant(
      map['correctedActionPerformedAt'],
      field: 'correctedActionPerformedAt',
      source: source,
    );
    final correctedAt = _readCorrectionInstant(
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
        assetNumber > 26 ||
        supersedes == id ||
        effectiveAt.isAfter(correctedAt)) {
      throw PersistedDataFormatException(
        field: 'correctionId',
        source: source,
        detail: 'invalid correction identity, revision or chronology',
      );
    }
    return UvDetectorInstallationCorrection(
      id: id,
      eventId: text('correctsEventId'),
      expectedCurrentEventId: text('expectedCurrentEventId'),
      expectedCurrentActionPerformedAt: _readCorrectionInstant(
        map['expectedCurrentActionPerformedAt'],
        field: 'expectedCurrentActionPerformedAt',
        source: source,
      ).toUtc(),
      assetInstanceId: text('assetInstanceId'),
      assetClassId: text('assetClassId'),
      assetNumber: assetNumber,
      componentTag: readOptionalPersistedString(
        map['componentTag'],
        field: 'componentTag',
        source: source,
      ),
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
UvDetectorInstallationCorrection? effectiveUvDetectorCorrection(
  List<UvDetectorInstallationCorrection> rows,
  String eventId,
) {
  if (rows.isEmpty) return null;
  final byId = {for (final row in rows) row.id: row};
  final superseded = <String>{};
  for (final row in rows) {
    final prior = row.supersedesId;
    if (row.eventId != eventId ||
        row.assetInstanceId != rows.first.assetInstanceId ||
        row.assetClassId != rows.first.assetClassId ||
        row.assetNumber != rows.first.assetNumber ||
        row.componentTag != rows.first.componentTag ||
        row.burnerPosition != rows.first.burnerPosition ||
        !row.originalAt.isAtSameMomentAs(rows.first.originalAt) ||
        byId.length != rows.length ||
        (prior != null &&
            (!byId.containsKey(prior) ||
                !superseded.add(prior) ||
                byId[prior]!.correctedAt.isAfter(row.correctedAt)))) {
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
  UvDetectorInstallationCorrection? cursor = terminal.single;
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

DateTime _readCorrectionInstant(
  Object? raw, {
  required String field,
  required String source,
}) {
  final value = readRequiredPersistedDateTime(
    raw,
    field: field,
    source: source,
  ).toUtc();
  if (value.microsecond != 0 ||
      (raw is Timestamp && raw.nanoseconds % 1000000 != 0) ||
      (raw is String && raw != value.toIso8601String())) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'requires an exact whole-millisecond correction timestamp',
    );
  }
  return value;
}
