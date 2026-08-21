import '../../../core/serialization/persisted_data_reader.dart';

enum FrequentIssueDefinitionStatus { active, retired }

class FrequentIssueDefinition {
  const FrequentIssueDefinition({
    required this.id,
    required this.version,
    required this.status,
    required this.code,
    required this.title,
    required this.description,
    required this.applicableAssetTypeKeys,
    required this.applicableAssetClassIds,
    required this.applicableComponentNodeIds,
    required this.suggestedSeverityKey,
    required this.suggestedMaintenanceTypeKey,
    required this.defaultRouteKey,
    required this.requiredEvidenceFields,
    required this.aliases,
    this.codeOwnedWorkflowProfile,
    required this.createdAt,
    required this.createdByUid,
    required this.createdByName,
    required this.updatedAt,
    required this.updatedByUid,
    required this.updatedByName,
  });

  final String id;
  final int version;
  final FrequentIssueDefinitionStatus status;
  final String code;
  final String title;
  final String description;
  final List<String> applicableAssetTypeKeys;
  final List<String> applicableAssetClassIds;
  final List<String> applicableComponentNodeIds;
  final String suggestedSeverityKey;
  final String suggestedMaintenanceTypeKey;
  final String defaultRouteKey;
  final List<String> requiredEvidenceFields;
  final List<String> aliases;
  final String? codeOwnedWorkflowProfile;
  final DateTime createdAt;
  final String createdByUid;
  final String createdByName;
  final DateTime updatedAt;
  final String updatedByUid;
  final String updatedByName;

  bool get isActive => status == FrequentIssueDefinitionStatus.active;
  bool get isCodeOwned => codeOwnedWorkflowProfile != null;
  bool get isCritical => suggestedSeverityKey == 'critical';

  bool appliesTo({
    required String assetTypeKey,
    required String assetClassId,
    String? componentNodeId,
  }) {
    final assetApplies =
        applicableAssetTypeKeys.contains(assetTypeKey) ||
        applicableAssetClassIds.contains(assetClassId);
    final componentApplies =
        applicableComponentNodeIds.isEmpty ||
        (componentNodeId != null &&
            applicableComponentNodeIds.contains(componentNodeId));
    return isActive && assetApplies && componentApplies;
  }

  factory FrequentIssueDefinition.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'frequent_issue_definitions/$documentId';
    final id = readRequiredPersistedString(
      map['definitionId'],
      field: 'definitionId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'definitionId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    if (readRequiredPersistedInt(
          map['schemaVersion'],
          field: 'schemaVersion',
          source: source,
        ) !=
        1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported frequent-issue schema',
      );
    }
    for (final field in const <String>[
      'applicableAssetTypeKeys',
      'applicableAssetClassIds',
      'applicableComponentNodeIds',
      'requiredEvidenceFields',
      'aliases',
    ]) {
      if (!map.containsKey(field)) {
        throw PersistedDataFormatException(
          field: field,
          source: source,
          detail: 'required catalogue list is absent',
        );
      }
    }
    final assetTypes = readOptionalPersistedStringList(
      map['applicableAssetTypeKeys'],
      field: 'applicableAssetTypeKeys',
      source: source,
    );
    final classIds = readOptionalPersistedStringList(
      map['applicableAssetClassIds'],
      field: 'applicableAssetClassIds',
      source: source,
    );
    final componentIds = readOptionalPersistedStringList(
      map['applicableComponentNodeIds'],
      field: 'applicableComponentNodeIds',
      source: source,
    );
    final evidence = readOptionalPersistedStringList(
      map['requiredEvidenceFields'],
      field: 'requiredEvidenceFields',
      source: source,
    );
    if (assetTypes.isEmpty && classIds.isEmpty) {
      throw PersistedDataFormatException(
        field: 'applicableAssetTypeKeys',
        source: source,
        detail: 'at least one asset type or class is required',
      );
    }
    if (assetTypes.any(
          (value) =>
              !const <String>{
                'base',
                'furnace',
                'forceCooler',
                'innerCover',
                'governedCustom',
              }.contains(value),
        ) ||
        evidence.any(
          (value) =>
              !const <String>{
                'chargeNo',
                'photo',
                'observation',
                'measurement',
                'alarmText',
                'operatingContext',
              }.contains(value),
        )) {
      throw PersistedDataFormatException(
        field: 'applicableAssetTypeKeys',
        source: source,
        detail: 'catalogue contains an unsupported contract value',
      );
    }
    final severity = readRequiredPersistedString(
      map['suggestedSeverityKey'],
      field: 'suggestedSeverityKey',
      source: source,
    );
    final maintenanceType = readRequiredPersistedString(
      map['suggestedMaintenanceTypeKey'],
      field: 'suggestedMaintenanceTypeKey',
      source: source,
    );
    final route = readRequiredPersistedString(
      map['defaultRouteKey'],
      field: 'defaultRouteKey',
      source: source,
    );
    if (!const {'normal', 'critical'}.contains(severity) ||
        !const {
          'scheduled',
          'breakdown',
          'performance',
          'inspection',
          'overhaul',
        }.contains(maintenanceType) ||
        !const {
          'operations',
          'electrical',
          'mechanical',
          'instrumentation',
          'refractory',
          'emd',
          'shiftInCharge',
          'others',
        }.contains(route)) {
      throw PersistedDataFormatException(
        field: 'defaultRouteKey',
        source: source,
        detail: 'catalogue recommendation is unsupported',
      );
    }
    final code = readRequiredPersistedString(
      map['normalizedCode'],
      field: 'normalizedCode',
      source: source,
    );
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]+$').hasMatch(code)) {
      throw PersistedDataFormatException(
        field: 'normalizedCode',
        source: source,
        detail: 'invalid normalized code',
      );
    }
    return FrequentIssueDefinition(
      id: id,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      status: readRequiredPersistedEnum(
        FrequentIssueDefinitionStatus.values,
        map['status'],
        field: 'status',
        source: source,
      ),
      code: code,
      title: readRequiredPersistedString(
        map['title'],
        field: 'title',
        source: source,
      ),
      description: readRequiredPersistedString(
        map['description'],
        field: 'description',
        source: source,
      ),
      applicableAssetTypeKeys: List.unmodifiable(assetTypes),
      applicableAssetClassIds: List.unmodifiable(classIds),
      applicableComponentNodeIds: List.unmodifiable(componentIds),
      suggestedSeverityKey: severity,
      suggestedMaintenanceTypeKey: maintenanceType,
      defaultRouteKey: route,
      requiredEvidenceFields: List.unmodifiable(evidence),
      aliases: List.unmodifiable(
        readOptionalPersistedStringList(
          map['aliases'],
          field: 'aliases',
          source: source,
        ),
      ),
      codeOwnedWorkflowProfile: readOptionalPersistedString(
        map['codeOwnedWorkflowProfile'],
        field: 'codeOwnedWorkflowProfile',
        source: source,
      ),
      createdAt: readRequiredPersistedDateTime(
        map['createdAt'],
        field: 'createdAt',
        source: source,
      ),
      createdByUid: readRequiredPersistedString(
        map['createdByUid'],
        field: 'createdByUid',
        source: source,
      ),
      createdByName: readRequiredPersistedString(
        map['createdByName'],
        field: 'createdByName',
        source: source,
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
    );
  }
}
