import '../../../core/serialization/persisted_data_reader.dart';

enum AssetOperationalCondition {
  available,
  down,
  unfit;

  String get label => switch (this) {
    available => 'Available',
    down => 'Down',
    unfit => 'Unfit',
  };
}

enum AssetConditionCause {
  breakdown,
  safety,
  quality,
  utilities,
  process,
  inspection,
  compliance,
  other;

  String get label => switch (this) {
    breakdown => 'Breakdown',
    safety => 'Safety',
    quality => 'Quality',
    utilities => 'Utilities',
    process => 'Process',
    inspection => 'Inspection',
    compliance => 'Compliance',
    other => 'Other',
  };
}

class AssetOperationalConditionRecord {
  final String assetInstanceId;
  final String assetClassId;
  final String assetClassCode;
  final String assetClassName;
  final int assetNumber;
  final String assetName;
  final AssetOperationalCondition condition;
  final bool active;
  final List<AssetConditionCause> causes;
  final String reason;
  final List<String> linkedIssueIds;
  final DateTime? declaredAt;
  final String? declaredByUid;
  final String? declaredByName;
  final DateTime? restoredAt;
  final String? restoredByUid;
  final String? restoredByName;
  final AssetOperationalCondition previousCondition;
  final int version;
  final DateTime updatedAt;
  final String updatedByUid;
  final String updatedByName;
  final String lastMutationId;

  const AssetOperationalConditionRecord({
    required this.assetInstanceId,
    required this.assetClassId,
    required this.assetClassCode,
    required this.assetClassName,
    required this.assetNumber,
    required this.assetName,
    required this.condition,
    required this.active,
    required this.causes,
    required this.reason,
    required this.linkedIssueIds,
    required this.declaredAt,
    required this.declaredByUid,
    required this.declaredByName,
    required this.restoredAt,
    required this.restoredByUid,
    required this.restoredByName,
    required this.previousCondition,
    required this.version,
    required this.updatedAt,
    required this.updatedByUid,
    required this.updatedByName,
    required this.lastMutationId,
  });

  factory AssetOperationalConditionRecord.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'asset_operational_conditions/$documentId';
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    if (schemaVersion != 1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported asset-condition schema $schemaVersion',
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
    final condition = readRequiredPersistedEnum(
      AssetOperationalCondition.values,
      map['condition'],
      field: 'condition',
      source: source,
    );
    final active = readRequiredPersistedBool(
      map['active'],
      field: 'active',
      source: source,
    );
    if (active != (condition != AssetOperationalCondition.available)) {
      throw PersistedDataFormatException(
        field: 'active',
        source: source,
        detail: 'must agree with the operational condition',
      );
    }
    if (!map.containsKey('causeKeys') || map['causeKeys'] == null) {
      throw PersistedDataFormatException(
        field: 'causeKeys',
        source: source,
        detail: 'required array is missing',
      );
    }
    final rawCauses = readOptionalPersistedStringList(
      map['causeKeys'],
      field: 'causeKeys',
      source: source,
    );
    final causes = rawCauses
        .map(
          (value) => readRequiredPersistedEnum(
            AssetConditionCause.values,
            value,
            field: 'causeKeys',
            source: source,
          ),
        )
        .toList(growable: false);
    if (causes.length > 8 ||
        causes.toSet().length != causes.length ||
        (active && causes.isEmpty) ||
        (!active && causes.isNotEmpty)) {
      throw PersistedDataFormatException(
        field: 'causeKeys',
        source: source,
        detail: 'must be unique, present only for an active condition',
      );
    }
    if (!map.containsKey('linkedIssueIds') || map['linkedIssueIds'] == null) {
      throw PersistedDataFormatException(
        field: 'linkedIssueIds',
        source: source,
        detail: 'required array is missing',
      );
    }
    final linkedIssueIds = readOptionalPersistedStringList(
      map['linkedIssueIds'],
      field: 'linkedIssueIds',
      source: source,
    );
    if (linkedIssueIds.length > 20 ||
        linkedIssueIds.toSet().length != linkedIssueIds.length ||
        (!active && linkedIssueIds.isNotEmpty)) {
      throw PersistedDataFormatException(
        field: 'linkedIssueIds',
        source: source,
        detail: 'must be unique and present only for an active condition',
      );
    }
    final declaredAt = readOptionalPersistedDateTime(
      map['declaredAt'],
      field: 'declaredAt',
      source: source,
    );
    final declaredByUid = readOptionalPersistedString(
      map['declaredByUid'],
      field: 'declaredByUid',
      source: source,
    );
    final declaredByName = readOptionalPersistedString(
      map['declaredByName'],
      field: 'declaredByName',
      source: source,
    );
    if (declaredAt == null || declaredByUid == null || declaredByName == null) {
      throw PersistedDataFormatException(
        field: 'declaredAt',
        source: source,
        detail: 'condition history requires complete declaration authority',
      );
    }
    final restoredAt = readOptionalPersistedDateTime(
      map['restoredAt'],
      field: 'restoredAt',
      source: source,
    );
    final restoredByUid = readOptionalPersistedString(
      map['restoredByUid'],
      field: 'restoredByUid',
      source: source,
    );
    final restoredByName = readOptionalPersistedString(
      map['restoredByName'],
      field: 'restoredByName',
      source: source,
    );
    final restorationFields = <Object?>[
      restoredAt,
      restoredByUid,
      restoredByName,
    ];
    if (active
        ? restorationFields.any((value) => value != null)
        : restorationFields.any((value) => value == null)) {
      throw PersistedDataFormatException(
        field: 'restoredAt',
        source: source,
        detail:
            'restoration authority must be absent while active and complete after restoration',
      );
    }
    final reason = readRequiredPersistedString(
      map['reason'],
      field: 'reason',
      source: source,
    );
    if (reason.length < 8 || reason.length > 1000) {
      throw PersistedDataFormatException(
        field: 'reason',
        source: source,
        detail: 'must contain 8-1,000 characters',
      );
    }
    final previousCondition = readRequiredPersistedEnum(
      AssetOperationalCondition.values,
      map['previousCondition'],
      field: 'previousCondition',
      source: source,
    );
    if (!active && previousCondition == AssetOperationalCondition.available) {
      throw PersistedDataFormatException(
        field: 'previousCondition',
        source: source,
        detail: 'a restoration must follow down or unfit',
      );
    }
    return AssetOperationalConditionRecord(
      assetInstanceId: assetInstanceId,
      assetClassId: readRequiredPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      assetClassCode: readRequiredPersistedString(
        map['assetClassCode'],
        field: 'assetClassCode',
        source: source,
      ),
      assetClassName: readRequiredPersistedString(
        map['assetClassName'],
        field: 'assetClassName',
        source: source,
      ),
      assetNumber: readRequiredPersistedInt(
        map['assetNumber'],
        field: 'assetNumber',
        source: source,
        minimum: 1,
      ),
      assetName: readRequiredPersistedString(
        map['assetName'],
        field: 'assetName',
        source: source,
      ),
      condition: condition,
      active: active,
      causes: List<AssetConditionCause>.unmodifiable(causes),
      reason: reason,
      linkedIssueIds: List<String>.unmodifiable(linkedIssueIds),
      declaredAt: declaredAt,
      declaredByUid: declaredByUid,
      declaredByName: declaredByName,
      restoredAt: restoredAt,
      restoredByUid: restoredByUid,
      restoredByName: restoredByName,
      previousCondition: previousCondition,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      updatedAt: readRequiredPersistedDateTime(
        map['updatedAt'],
        field: 'updatedAt',
        source: source,
      ),
      updatedByUid: readRequiredPersistedString(
        map['updatedByUid'],
        field: 'updatedByUid',
        source: source,
      ),
      updatedByName: readRequiredPersistedString(
        map['updatedByName'],
        field: 'updatedByName',
        source: source,
      ),
      lastMutationId: readRequiredPersistedString(
        map['lastMutationId'],
        field: 'lastMutationId',
        source: source,
      ),
    );
  }
}
