import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../../core/serialization/persisted_data_reader.dart';

final operationalEventAmendmentIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

DateTime readOperationalAmendmentInstant(
  Object? raw, {
  required String field,
  String source = 'operational event amendment',
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
      detail: 'requires an exact whole-millisecond timestamp',
    );
  }
  return value;
}

class OperationalEventIntervalAmendment {
  const OperationalEventIntervalAmendment({
    required this.amendmentId,
    required this.originalResolvedAt,
    required this.correctedResolvedAt,
    required this.amendedAt,
    required this.amendedByUid,
    required this.amendedByName,
    required this.reason,
    required this.supersedesAmendmentId,
  });
  final String amendmentId, amendedByUid, amendedByName, reason;
  final String? supersedesAmendmentId;
  final DateTime originalResolvedAt, correctedResolvedAt, amendedAt;

  factory OperationalEventIntervalAmendment.fromMap(
    Map<String, dynamic> map,
    String source,
  ) {
    const fields = {
      'amendmentId',
      'originalResolvedAt',
      'correctedResolvedAt',
      'amendedAt',
      'amendedByUid',
      'amendedByName',
      'reason',
      'supersedesAmendmentId',
    };
    readBoundedPersistedExtensionBag(
      map,
      knownFields: fields,
      allowedFields: const <String, PersistedExtensionValueKind>{},
      field: 'extensions',
      source: source,
    );
    if (map.length != fields.length) {
      throw PersistedDataFormatException(
        field: 'amendment',
        source: source,
        detail: 'requires complete amendment evidence',
      );
    }
    String text(String field) =>
        readRequiredPersistedString(map[field], field: field, source: source);
    final id = text('amendmentId');
    final prior = readOptionalPersistedString(
      map['supersedesAmendmentId'],
      field: 'supersedesAmendmentId',
      source: source,
      emptyAsNull: false,
    );
    final uid = text('amendedByUid');
    final name = text('amendedByName');
    final reason = text('reason');
    final original = readOperationalAmendmentInstant(
      map['originalResolvedAt'],
      field: 'originalResolvedAt',
      source: source,
    );
    final corrected = readOperationalAmendmentInstant(
      map['correctedResolvedAt'],
      field: 'correctedResolvedAt',
      source: source,
    );
    final amended = readOperationalAmendmentInstant(
      map['amendedAt'],
      field: 'amendedAt',
      source: source,
    );
    if (!operationalEventAmendmentIdPattern.hasMatch(id) ||
        (prior != null &&
            (!operationalEventAmendmentIdPattern.hasMatch(prior) ||
                prior == id)) ||
        uid.length > 128 ||
        name.length > 200 ||
        reason.length > 1000 ||
        original.isAfter(amended) ||
        corrected.isAfter(amended)) {
      throw PersistedDataFormatException(
        field: 'amendment',
        source: source,
        detail: 'invalid amendment identity, attribution or chronology',
      );
    }
    return OperationalEventIntervalAmendment(
      amendmentId: id,
      originalResolvedAt: original,
      correctedResolvedAt: corrected,
      amendedAt: amended,
      amendedByUid: uid,
      amendedByName: name,
      reason: reason,
      supersedesAmendmentId: prior,
    );
  }
}
