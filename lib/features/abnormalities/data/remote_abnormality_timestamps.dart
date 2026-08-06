import '../../../core/serialization/persisted_data_reader.dart';

class RemoteAbnormalityTypeTimestamps {
  const RemoteAbnormalityTypeTimestamps({
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

RemoteAbnormalityTypeTimestamps readRemoteAbnormalityTypeTimestamps(
  Map<String, dynamic> map, {
  required String source,
}) {
  return RemoteAbnormalityTypeTimestamps(
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
    deletedAt: readOptionalPersistedDateTime(
      map['deletedAt'],
      field: 'deletedAt',
      source: source,
    ),
  );
}

class RemoteChargeAbnormalityTimestamps {
  const RemoteChargeAbnormalityTimestamps({
    required this.loggedAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final DateTime loggedAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

RemoteChargeAbnormalityTimestamps readRemoteChargeAbnormalityTimestamps(
  Map<String, dynamic> map, {
  required String source,
}) {
  return RemoteChargeAbnormalityTimestamps(
    loggedAt: readRequiredPersistedDateTime(
      map['loggedAt'],
      field: 'loggedAt',
      source: source,
    ),
    updatedAt: readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    ),
    deletedAt: readOptionalPersistedDateTime(
      map['deletedAt'],
      field: 'deletedAt',
      source: source,
    ),
  );
}
