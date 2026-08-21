import '../../../core/serialization/persisted_data_reader.dart';

enum AssetAvailabilityState { clear, temporarilyBlocked }

class AssetAvailabilityRecord {
  const AssetAvailabilityRecord({
    required this.assetType,
    required this.assetClassId,
    required this.assetInstanceId,
    required this.assetNumber,
    required this.state,
    required this.activeConstraintId,
    required this.reasonType,
    required this.linkedCaseId,
    required this.linkedTicketId,
    required this.since,
    required this.updatedAt,
    required this.version,
  });

  final String assetType;
  final String assetClassId;
  final String assetInstanceId;
  final int assetNumber;
  final AssetAvailabilityState state;
  final String? activeConstraintId;
  final String? reasonType;
  final String? linkedCaseId;
  final String? linkedTicketId;
  final DateTime? since;
  final DateTime updatedAt;
  final int version;

  bool get isTemporarilyBlocked =>
      state == AssetAvailabilityState.temporarilyBlocked;

  factory AssetAvailabilityRecord.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'asset_availability_current/$documentId';
    if (readRequiredPersistedInt(
          map['schemaVersion'],
          field: 'schemaVersion',
          source: source,
        ) !=
        1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported schema version',
      );
    }
    final assetInstanceId = readRequiredPersistedString(
      map['assetInstanceId'],
      field: 'assetInstanceId',
      source: source,
    );
    if (assetInstanceId != documentId) {
      throw PersistedDataFormatException(
        field: 'assetInstanceId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final state = readRequiredPersistedEnum(
      AssetAvailabilityState.values,
      map['availabilityState'],
      field: 'availabilityState',
      source: source,
    );
    final activeConstraintId = readOptionalPersistedString(
      map['activeConstraintId'],
      field: 'activeConstraintId',
      source: source,
    );
    final reasonType = readOptionalPersistedString(
      map['reasonType'],
      field: 'reasonType',
      source: source,
    );
    final linkedCaseId = readOptionalPersistedString(
      map['linkedCaseId'],
      field: 'linkedCaseId',
      source: source,
    );
    final linkedTicketId = readOptionalPersistedString(
      map['linkedTicketId'],
      field: 'linkedTicketId',
      source: source,
    );
    final since = readOptionalPersistedDateTime(
      map['since'],
      field: 'since',
      source: source,
    );
    final hasCompleteBlockedShape =
        activeConstraintId != null &&
        reasonType == 'furnaceStuckup' &&
        linkedCaseId != null &&
        linkedTicketId != null &&
        since != null;
    final hasClearShape =
        activeConstraintId == null &&
        reasonType == null &&
        linkedCaseId == null &&
        linkedTicketId == null &&
        since == null;
    if ((state == AssetAvailabilityState.temporarilyBlocked &&
            !hasCompleteBlockedShape) ||
        (state == AssetAvailabilityState.clear && !hasClearShape)) {
      throw PersistedDataFormatException(
        field: 'availabilityState',
        source: source,
        detail: 'state and constraint fields must form a complete projection',
      );
    }
    return AssetAvailabilityRecord(
      assetType: readRequiredPersistedString(
        map['assetType'],
        field: 'assetType',
        source: source,
      ),
      assetClassId: readRequiredPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      assetInstanceId: assetInstanceId,
      assetNumber: readRequiredPersistedInt(
        map['assetNumber'],
        field: 'assetNumber',
        source: source,
        minimum: 1,
      ),
      state: state,
      activeConstraintId: activeConstraintId,
      reasonType: reasonType,
      linkedCaseId: linkedCaseId,
      linkedTicketId: linkedTicketId,
      since: since,
      updatedAt: readRequiredPersistedDateTime(
        map['updatedAt'],
        field: 'updatedAt',
        source: source,
      ),
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
    );
  }
}
