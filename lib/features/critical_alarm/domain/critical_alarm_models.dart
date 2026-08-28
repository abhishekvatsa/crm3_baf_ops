import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance_workflow/domain/workflow_policy_generated.dart';

enum CriticalAlarmStatus {
  raised,
  supportConfirmed,
  resolved,
  withdrawnInError,
}

enum CriticalAlarmContactStatus { active, retired }

enum CriticalAlarmDefinitionStatus { active, retired }

enum CriticalAlarmContactKind { mobile, landline, plantExtension }

enum CriticalAlarmSupportBasis {
  supportDispatched,
  supportAlreadyPresent,
  raiserContactedDirectly,
}

class CriticalAlarmDefinition {
  const CriticalAlarmDefinition({
    required this.key,
    required this.name,
    required this.criticalityKey,
    required this.criticalityRank,
    this.version = 0,
    this.status = CriticalAlarmDefinitionStatus.active,
    this.updatedAt,
    this.updatedByName,
  });

  final String key;
  final String name;
  final String criticalityKey;
  final int criticalityRank;
  final int version;
  final CriticalAlarmDefinitionStatus status;
  final DateTime? updatedAt;
  final String? updatedByName;

  bool get isActive => status == CriticalAlarmDefinitionStatus.active;
  bool get isBootstrapDefault => version == 0;

  String get criticalityLabel =>
      criticalityKey == 'highest' ? 'Highest' : 'Critical';

  static final Map<String, CriticalAlarmDefinition> byKey = Map.unmodifiable(
    WorkflowPolicyGenerated.criticalAlarmDefinitions.map(
      (key, value) => MapEntry(
        key,
        CriticalAlarmDefinition(
          key: value.key,
          name: value.name,
          criticalityKey: value.criticalityKey,
          criticalityRank: value.criticalityRank,
        ),
      ),
    ),
  );

  // The generated map retains the governed catalogue order. Keep that order
  // in selection controls so equal-ranked hazards remain deliberately distinct.
  static final List<CriticalAlarmDefinition> values = List.unmodifiable(
    byKey.values,
  );

  factory CriticalAlarmDefinition.snapshot({
    required String key,
    required String name,
    required String criticalityKey,
    required int criticalityRank,
  }) {
    _validateCriticality(
      key: criticalityKey,
      rank: criticalityRank,
      source: 'critical-alarm snapshot/$key',
    );
    return CriticalAlarmDefinition(
      key: key,
      name: name,
      criticalityKey: criticalityKey,
      criticalityRank: criticalityRank,
    );
  }

  factory CriticalAlarmDefinition.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final source = 'critical_alarm_definitions/$documentId';
    _requireExactFields(data, const {
      'schemaVersion',
      'definitionId',
      'version',
      'status',
      'name',
      'criticalityKey',
      'criticalityRank',
      'createdAt',
      'createdByUid',
      'createdByName',
      'updatedAt',
      'updatedByUid',
      'updatedByName',
    }, source);
    if (readRequiredPersistedInt(
          data['schemaVersion'],
          field: 'schemaVersion',
          source: source,
        ) !=
        1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported critical-alarm definition schema',
      );
    }
    final key = _boundedStoredText(
      data['definitionId'],
      field: 'definitionId',
      source: source,
      minimum: 1,
      maximum: 160,
    );
    if (key != documentId) {
      throw PersistedDataFormatException(
        field: 'definitionId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final criticalityKey = _boundedStoredText(
      data['criticalityKey'],
      field: 'criticalityKey',
      source: source,
      minimum: 1,
      maximum: 20,
    );
    final criticalityRank = _boundedInt(
      data['criticalityRank'],
      field: 'criticalityRank',
      source: source,
      minimum: 1,
      maximum: 2,
    );
    _validateCriticality(
      key: criticalityKey,
      rank: criticalityRank,
      source: source,
    );
    final createdAt = readRequiredPersistedDateTime(
      data['createdAt'],
      field: 'createdAt',
      source: source,
    );
    _boundedStoredText(
      data['createdByUid'],
      field: 'createdByUid',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    _boundedStoredText(
      data['createdByName'],
      field: 'createdByName',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final updatedAt = readRequiredPersistedDateTime(
      data['updatedAt'],
      field: 'updatedAt',
      source: source,
    );
    _boundedStoredText(
      data['updatedByUid'],
      field: 'updatedByUid',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final updatedByName = _boundedStoredText(
      data['updatedByName'],
      field: 'updatedByName',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    if (updatedAt.isBefore(createdAt)) {
      throw PersistedDataFormatException(
        field: 'updatedAt',
        source: source,
        detail: 'must not precede createdAt',
      );
    }
    return CriticalAlarmDefinition(
      key: key,
      name: _boundedStoredText(
        data['name'],
        field: 'name',
        source: source,
        minimum: 2,
        maximum: 120,
      ),
      criticalityKey: criticalityKey,
      criticalityRank: criticalityRank,
      version: readRequiredPersistedInt(
        data['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      status: readRequiredPersistedEnum(
        CriticalAlarmDefinitionStatus.values,
        data['status'],
        field: 'status',
        source: source,
      ),
      updatedAt: updatedAt,
      updatedByName: updatedByName,
    );
  }

  static List<CriticalAlarmDefinition> mergeOverrides(
    Iterable<CriticalAlarmDefinition> overrides,
  ) {
    final merged = <String, CriticalAlarmDefinition>{...byKey};
    for (final definition in overrides) {
      merged[definition.key] = definition;
    }
    final rows =
        merged.values.toList()..sort((left, right) {
          final rank = left.criticalityRank.compareTo(right.criticalityRank);
          if (rank != 0) return rank;
          final name = left.name.toLowerCase().compareTo(
            right.name.toLowerCase(),
          );
          return name != 0 ? name : left.key.compareTo(right.key);
        });
    return List.unmodifiable(rows);
  }

  static void _validateCriticality({
    required String key,
    required int rank,
    required String source,
  }) {
    if (!((key == 'highest' && rank == 1) ||
        (key == 'critical' && rank == 2))) {
      throw PersistedDataFormatException(
        field: 'criticalityKey',
        source: source,
        detail: 'must be Highest/rank 1 or Critical/rank 2',
      );
    }
  }
}

void _requireExactFields(
  Map<String, dynamic> data,
  Set<String> expected,
  String source,
) {
  final actual = data.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw PersistedDataFormatException(
      field: 'document',
      source: source,
      detail: 'field set does not match the critical-safety contract',
    );
  }
}

int _boundedInt(
  dynamic value, {
  required String field,
  required String source,
  required int minimum,
  required int maximum,
}) {
  final parsed = readRequiredPersistedInt(
    value,
    field: field,
    source: source,
    minimum: minimum,
  );
  if (parsed > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must not exceed $maximum',
    );
  }
  return parsed;
}

String _boundedStoredText(
  dynamic value, {
  required String field,
  required String source,
  required int minimum,
  required int maximum,
}) {
  final parsed = readRequiredPersistedString(
    value,
    field: field,
    source: source,
  );
  if (value is! String ||
      value != parsed ||
      parsed.length < minimum ||
      parsed.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must be canonical text containing $minimum-$maximum characters',
    );
  }
  return parsed;
}

String? _boundedOptionalStoredText(
  dynamic value, {
  required String field,
  required String source,
  required int minimum,
  required int maximum,
}) {
  if (value == null) return null;
  return _boundedStoredText(
    value,
    field: field,
    source: source,
    minimum: minimum,
    maximum: maximum,
  );
}

class CriticalAlarm {
  const CriticalAlarm({
    required this.id,
    required this.definition,
    required this.status,
    required this.version,
    required this.location,
    required this.assetTypeKey,
    required this.assetNumber,
    required this.details,
    required this.detailsPending,
    required this.raisedByUid,
    required this.raisedByName,
    required this.raisedAt,
    required this.detailsProvidedByName,
    required this.detailsProvidedAt,
    required this.supportBasis,
    required this.supportNote,
    required this.supportConfirmedByName,
    required this.supportConfirmedAt,
    required this.resolutionSummary,
    required this.resolvedByName,
    required this.resolvedAt,
    required this.withdrawalReason,
    required this.withdrawnByName,
    required this.withdrawnAt,
    required this.updatedAt,
  });

  final String id;
  final CriticalAlarmDefinition definition;
  final CriticalAlarmStatus status;
  final int version;
  final String location;
  final String? assetTypeKey;
  final int? assetNumber;
  final String? details;
  final bool detailsPending;
  final String raisedByUid;
  final String raisedByName;
  final DateTime raisedAt;
  final String? detailsProvidedByName;
  final DateTime? detailsProvidedAt;
  final CriticalAlarmSupportBasis? supportBasis;
  final String? supportNote;
  final String? supportConfirmedByName;
  final DateTime? supportConfirmedAt;
  final String? resolutionSummary;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final String? withdrawalReason;
  final String? withdrawnByName;
  final DateTime? withdrawnAt;
  final DateTime updatedAt;

  bool get isActive =>
      status == CriticalAlarmStatus.raised ||
      status == CriticalAlarmStatus.supportConfirmed;
  bool get isRinging => status == CriticalAlarmStatus.raised;
  bool get isHighest => definition.criticalityKey == 'highest';

  factory CriticalAlarm.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final source = 'critical_alarms/$documentId';
    _requireExactFields(data, const {
      'schemaVersion',
      'alarmId',
      'alarmTypeKey',
      'alarmTypeName',
      'criticalityKey',
      'criticalityRank',
      'status',
      'version',
      'location',
      'assetTypeKey',
      'assetNumber',
      'details',
      'detailsPending',
      'raisedByUid',
      'raisedByName',
      'raisedAt',
      'detailsProvidedByUid',
      'detailsProvidedByName',
      'detailsProvidedAt',
      'supportBasis',
      'supportNote',
      'supportConfirmedByUid',
      'supportConfirmedByName',
      'supportConfirmedAt',
      'resolutionSummary',
      'resolvedByUid',
      'resolvedByName',
      'resolvedAt',
      'withdrawalReason',
      'withdrawnByUid',
      'withdrawnByName',
      'withdrawnAt',
      'createdAt',
      'updatedAt',
    }, source);
    if (readRequiredPersistedInt(
          data['schemaVersion'],
          field: 'schemaVersion',
          source: source,
        ) !=
        1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported critical-alarm schema',
      );
    }
    final id = _boundedStoredText(
      data['alarmId'],
      field: 'alarmId',
      source: source,
      minimum: 1,
      maximum: 160,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'alarmId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final typeKey = _boundedStoredText(
      data['alarmTypeKey'],
      field: 'alarmTypeKey',
      source: source,
      minimum: 1,
      maximum: 160,
    );
    final definition = CriticalAlarmDefinition.snapshot(
      key: typeKey,
      name: _boundedStoredText(
        data['alarmTypeName'],
        field: 'alarmTypeName',
        source: source,
        minimum: 2,
        maximum: 120,
      ),
      criticalityKey: _boundedStoredText(
        data['criticalityKey'],
        field: 'criticalityKey',
        source: source,
        minimum: 1,
        maximum: 20,
      ),
      criticalityRank: _boundedInt(
        data['criticalityRank'],
        field: 'criticalityRank',
        source: source,
        minimum: 1,
        maximum: 2,
      ),
    );
    final assetTypeKey = _boundedOptionalStoredText(
      data['assetTypeKey'],
      field: 'assetTypeKey',
      source: source,
      minimum: 1,
      maximum: 80,
    );
    final assetNumber = readOptionalPersistedInt(
      data['assetNumber'],
      field: 'assetNumber',
      source: source,
      minimum: 1,
    );
    if ((assetTypeKey == null) != (assetNumber == null)) {
      throw PersistedDataFormatException(
        field: 'assetNumber',
        source: source,
        detail: 'asset type and number must be present together',
      );
    }
    final status = readRequiredPersistedEnum(
      CriticalAlarmStatus.values,
      data['status'],
      field: 'status',
      source: source,
    );
    final details = _boundedOptionalStoredText(
      data['details'],
      field: 'details',
      source: source,
      minimum: 5,
      maximum: 2000,
    );
    final detailsPending = readRequiredPersistedBool(
      data['detailsPending'],
      field: 'detailsPending',
      source: source,
    );
    final detailsProvidedByUid = _boundedOptionalStoredText(
      data['detailsProvidedByUid'],
      field: 'detailsProvidedByUid',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final detailsProvidedByName = _boundedOptionalStoredText(
      data['detailsProvidedByName'],
      field: 'detailsProvidedByName',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final detailsProvidedAt = readOptionalPersistedDateTime(
      data['detailsProvidedAt'],
      field: 'detailsProvidedAt',
      source: source,
    );
    final detailsEvidenceAbsent =
        detailsProvidedByUid == null &&
        detailsProvidedByName == null &&
        detailsProvidedAt == null;
    final detailsEvidenceComplete =
        detailsProvidedByUid != null &&
        detailsProvidedByName != null &&
        detailsProvidedAt != null;
    if ((details == null && (!detailsPending || !detailsEvidenceAbsent)) ||
        (details != null && (detailsPending || !detailsEvidenceComplete))) {
      throw PersistedDataFormatException(
        field: 'detailsPending',
        source: source,
        detail: 'must match complete detail-provision evidence',
      );
    }
    final supportBasis = readOptionalPersistedEnum(
      CriticalAlarmSupportBasis.values,
      data['supportBasis'],
      field: 'supportBasis',
      source: source,
    );
    final supportNote = _boundedOptionalStoredText(
      data['supportNote'],
      field: 'supportNote',
      source: source,
      minimum: 5,
      maximum: 1000,
    );
    final supportConfirmedByUid = _boundedOptionalStoredText(
      data['supportConfirmedByUid'],
      field: 'supportConfirmedByUid',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final supportConfirmedByName = _boundedOptionalStoredText(
      data['supportConfirmedByName'],
      field: 'supportConfirmedByName',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final supportAt = readOptionalPersistedDateTime(
      data['supportConfirmedAt'],
      field: 'supportConfirmedAt',
      source: source,
    );
    final supportEvidenceAbsent =
        supportBasis == null &&
        supportNote == null &&
        supportConfirmedByUid == null &&
        supportConfirmedByName == null &&
        supportAt == null;
    final supportEvidenceComplete =
        supportBasis != null &&
        supportNote != null &&
        supportConfirmedByUid != null &&
        supportConfirmedByName != null &&
        supportAt != null;
    final resolutionSummary = _boundedOptionalStoredText(
      data['resolutionSummary'],
      field: 'resolutionSummary',
      source: source,
      minimum: 5,
      maximum: 2000,
    );
    final resolvedByUid = _boundedOptionalStoredText(
      data['resolvedByUid'],
      field: 'resolvedByUid',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final resolvedByName = _boundedOptionalStoredText(
      data['resolvedByName'],
      field: 'resolvedByName',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final resolvedAt = readOptionalPersistedDateTime(
      data['resolvedAt'],
      field: 'resolvedAt',
      source: source,
    );
    final resolutionEvidenceAbsent =
        resolutionSummary == null &&
        resolvedByUid == null &&
        resolvedByName == null &&
        resolvedAt == null;
    final resolutionEvidenceComplete =
        resolutionSummary != null &&
        resolvedByUid != null &&
        resolvedByName != null &&
        resolvedAt != null;
    final withdrawalReason = _boundedOptionalStoredText(
      data['withdrawalReason'],
      field: 'withdrawalReason',
      source: source,
      minimum: 5,
      maximum: 1000,
    );
    final withdrawnByUid = _boundedOptionalStoredText(
      data['withdrawnByUid'],
      field: 'withdrawnByUid',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final withdrawnByName = _boundedOptionalStoredText(
      data['withdrawnByName'],
      field: 'withdrawnByName',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final withdrawnAt = readOptionalPersistedDateTime(
      data['withdrawnAt'],
      field: 'withdrawnAt',
      source: source,
    );
    final withdrawalEvidenceAbsent =
        withdrawalReason == null &&
        withdrawnByUid == null &&
        withdrawnByName == null &&
        withdrawnAt == null;
    final withdrawalEvidenceComplete =
        withdrawalReason != null &&
        withdrawnByUid != null &&
        withdrawnByName != null &&
        withdrawnAt != null;
    final lifecycleValid = switch (status) {
      CriticalAlarmStatus.raised =>
        supportEvidenceAbsent &&
            resolutionEvidenceAbsent &&
            withdrawalEvidenceAbsent,
      CriticalAlarmStatus.supportConfirmed =>
        supportEvidenceComplete &&
            resolutionEvidenceAbsent &&
            withdrawalEvidenceAbsent,
      CriticalAlarmStatus.resolved =>
        supportEvidenceComplete &&
            resolutionEvidenceComplete &&
            withdrawalEvidenceAbsent,
      CriticalAlarmStatus.withdrawnInError =>
        (supportEvidenceAbsent || supportEvidenceComplete) &&
            resolutionEvidenceAbsent &&
            withdrawalEvidenceComplete,
    };
    if (!lifecycleValid) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'does not match complete lifecycle evidence',
      );
    }
    final raisedAt = readRequiredPersistedDateTime(
      data['raisedAt'],
      field: 'raisedAt',
      source: source,
    );
    final createdAt = readRequiredPersistedDateTime(
      data['createdAt'],
      field: 'createdAt',
      source: source,
    );
    final updatedAt = readRequiredPersistedDateTime(
      data['updatedAt'],
      field: 'updatedAt',
      source: source,
    );
    final chronologyValid =
        raisedAt.isAtSameMomentAs(createdAt) &&
        !updatedAt.isBefore(createdAt) &&
        (detailsProvidedAt == null ||
            (!detailsProvidedAt.isBefore(raisedAt) &&
                !detailsProvidedAt.isAfter(updatedAt))) &&
        (supportAt == null ||
            (!supportAt.isBefore(raisedAt) && !supportAt.isAfter(updatedAt))) &&
        (resolvedAt == null ||
            (supportAt != null &&
                !resolvedAt.isBefore(supportAt) &&
                !resolvedAt.isAfter(updatedAt))) &&
        (withdrawnAt == null ||
            (!withdrawnAt.isBefore(supportAt ?? raisedAt) &&
                !withdrawnAt.isAfter(updatedAt)));
    if (!chronologyValid) {
      throw PersistedDataFormatException(
        field: 'updatedAt',
        source: source,
        detail: 'does not preserve the critical-alarm lifecycle chronology',
      );
    }
    return CriticalAlarm(
      id: id,
      definition: definition,
      status: status,
      version: readRequiredPersistedInt(
        data['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      location: _boundedStoredText(
        data['location'],
        field: 'location',
        source: source,
        minimum: 2,
        maximum: 160,
      ),
      assetTypeKey: assetTypeKey,
      assetNumber: assetNumber,
      details: details,
      detailsPending: detailsPending,
      raisedByUid: _boundedStoredText(
        data['raisedByUid'],
        field: 'raisedByUid',
        source: source,
        minimum: 1,
        maximum: 256,
      ),
      raisedByName: _boundedStoredText(
        data['raisedByName'],
        field: 'raisedByName',
        source: source,
        minimum: 1,
        maximum: 256,
      ),
      raisedAt: raisedAt,
      detailsProvidedByName: detailsProvidedByName,
      detailsProvidedAt: detailsProvidedAt,
      supportBasis: supportBasis,
      supportNote: supportNote,
      supportConfirmedByName: supportConfirmedByName,
      supportConfirmedAt: supportAt,
      resolutionSummary: resolutionSummary,
      resolvedByName: resolvedByName,
      resolvedAt: resolvedAt,
      withdrawalReason: withdrawalReason,
      withdrawnByName: withdrawnByName,
      withdrawnAt: withdrawnAt,
      updatedAt: updatedAt,
    );
  }
}

class CriticalAlarmContact {
  const CriticalAlarmContact({
    required this.id,
    required this.version,
    required this.status,
    required this.label,
    required this.kind,
    required this.dialValue,
    required this.alarmTypeKeys,
    required this.priority,
    required this.notes,
    required this.updatedAt,
    required this.updatedByName,
  });

  final String id;
  final int version;
  final CriticalAlarmContactStatus status;
  final String label;
  final CriticalAlarmContactKind kind;
  final String dialValue;
  final List<String> alarmTypeKeys;
  final int priority;
  final String? notes;
  final DateTime updatedAt;
  final String updatedByName;

  bool get isActive => status == CriticalAlarmContactStatus.active;

  factory CriticalAlarmContact.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final source = 'critical_alarm_contacts/$documentId';
    _requireExactFields(data, const {
      'schemaVersion',
      'contactId',
      'version',
      'status',
      'label',
      'contactKind',
      'dialValue',
      'alarmTypeKeys',
      'priority',
      'notes',
      'createdAt',
      'createdByUid',
      'createdByName',
      'updatedAt',
      'updatedByUid',
      'updatedByName',
    }, source);
    if (readRequiredPersistedInt(
          data['schemaVersion'],
          field: 'schemaVersion',
          source: source,
        ) !=
        1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported critical-alarm contact schema',
      );
    }
    final id = _boundedStoredText(
      data['contactId'],
      field: 'contactId',
      source: source,
      minimum: 1,
      maximum: 160,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'contactId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final alarmTypeKeys = readOptionalPersistedStringList(
      data['alarmTypeKeys'],
      field: 'alarmTypeKeys',
      source: source,
    );
    final rawAlarmTypeKeys = data['alarmTypeKeys'];
    if (rawAlarmTypeKeys is! List ||
        rawAlarmTypeKeys.length != alarmTypeKeys.length ||
        List.generate(
          alarmTypeKeys.length,
          (index) => rawAlarmTypeKeys[index] == alarmTypeKeys[index],
        ).contains(false) ||
        alarmTypeKeys.isEmpty ||
        alarmTypeKeys.length > 20 ||
        alarmTypeKeys.toSet().length != alarmTypeKeys.length ||
        alarmTypeKeys.any(
          (key) => key.trim() != key || key.isEmpty || key.length > 160,
        )) {
      throw PersistedDataFormatException(
        field: 'alarmTypeKeys',
        source: source,
        detail: 'must contain unique governed alarm types',
      );
    }
    final kind = readRequiredPersistedEnum(
      CriticalAlarmContactKind.values,
      data['contactKind'],
      field: 'contactKind',
      source: source,
    );
    final dialValue = _boundedStoredText(
      data['dialValue'],
      field: 'dialValue',
      source: source,
      minimum: 2,
      maximum: 16,
    );
    final dialPattern =
        kind == CriticalAlarmContactKind.plantExtension
            ? RegExp(r'^\d{2,8}$')
            : RegExp(r'^\+?\d{5,15}$');
    if (!dialPattern.hasMatch(dialValue)) {
      throw PersistedDataFormatException(
        field: 'dialValue',
        source: source,
        detail: 'does not match the selected contact kind',
      );
    }
    final createdAt = readRequiredPersistedDateTime(
      data['createdAt'],
      field: 'createdAt',
      source: source,
    );
    _boundedStoredText(
      data['createdByUid'],
      field: 'createdByUid',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    _boundedStoredText(
      data['createdByName'],
      field: 'createdByName',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final updatedAt = readRequiredPersistedDateTime(
      data['updatedAt'],
      field: 'updatedAt',
      source: source,
    );
    _boundedStoredText(
      data['updatedByUid'],
      field: 'updatedByUid',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    final updatedByName = _boundedStoredText(
      data['updatedByName'],
      field: 'updatedByName',
      source: source,
      minimum: 1,
      maximum: 256,
    );
    if (updatedAt.isBefore(createdAt)) {
      throw PersistedDataFormatException(
        field: 'updatedAt',
        source: source,
        detail: 'must not precede createdAt',
      );
    }
    return CriticalAlarmContact(
      id: id,
      version: readRequiredPersistedInt(
        data['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      status: readRequiredPersistedEnum(
        CriticalAlarmContactStatus.values,
        data['status'],
        field: 'status',
        source: source,
      ),
      label: _boundedStoredText(
        data['label'],
        field: 'label',
        source: source,
        minimum: 2,
        maximum: 120,
      ),
      kind: kind,
      dialValue: dialValue,
      alarmTypeKeys: List.unmodifiable(alarmTypeKeys),
      priority: _boundedInt(
        data['priority'],
        field: 'priority',
        source: source,
        minimum: 1,
        maximum: 99,
      ),
      notes: _boundedOptionalStoredText(
        data['notes'],
        field: 'notes',
        source: source,
        minimum: 1,
        maximum: 500,
      ),
      updatedAt: updatedAt,
      updatedByName: updatedByName,
    );
  }
}
