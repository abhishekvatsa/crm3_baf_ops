import '../../../core/serialization/persisted_data_reader.dart';

class RemoteOperationalDirectiveTimestamps {
  const RemoteOperationalDirectiveTimestamps({
    required this.createdAt,
    required this.updatedAt,
    required this.issuedAt,
    required this.acknowledgedAt,
    required this.closedAt,
    required this.deletedAt,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? issuedAt;
  final DateTime? acknowledgedAt;
  final DateTime? closedAt;
  final DateTime? deletedAt;
}

RemoteOperationalDirectiveTimestamps readRemoteOperationalDirectiveTimestamps(
  Map<String, dynamic> map, {
  required String source,
}) {
  return RemoteOperationalDirectiveTimestamps(
    createdAt: readRequiredPersistedDateTime(
      map['createdAt'],
      field: 'createdAt',
      source: source,
    ),
    updatedAt: readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    ),
    issuedAt: readOptionalPersistedDateTime(
      map['issuedAt'],
      field: 'issuedAt',
      source: source,
    ),
    acknowledgedAt: readOptionalPersistedDateTime(
      map['acknowledgedAt'],
      field: 'acknowledgedAt',
      source: source,
    ),
    closedAt: readOptionalPersistedDateTime(
      map['closedAt'],
      field: 'closedAt',
      source: source,
    ),
    deletedAt: readOptionalPersistedDateTime(
      map['deletedAt'],
      field: 'deletedAt',
      source: source,
    ),
  );
}
