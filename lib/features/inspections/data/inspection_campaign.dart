import '../../../core/serialization/persisted_data_reader.dart';

enum InspectionDefinitionStatus { active, retired }

enum InspectionCampaignStatus { open, paused, closed }

enum InspectionValueType { number, boolean, text, choice }

Map<String, dynamic> _object(
  dynamic value, {
  required String field,
  required String source,
}) {
  if (value is! Map) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'required object',
    );
  }
  return Map<String, dynamic>.from(value);
}

List<int> _integers(
  dynamic value, {
  required String field,
  required String source,
}) {
  if (value is! List || value.any((item) => item is! int || item < 1)) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'required positive-integer array',
    );
  }
  return List<int>.unmodifiable(value.cast<int>());
}

Map<String, String> _stringMap(
  dynamic value, {
  required String field,
  required String source,
}) {
  final raw = _object(value, field: field, source: source);
  if (raw.values.any((item) => item is! String)) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'all operating-condition values must be strings',
    );
  }
  return Map<String, String>.unmodifiable(raw.cast<String, String>());
}

class FrozenInspectionDefinition {
  const FrozenInspectionDefinition({
    required this.id,
    required this.version,
    required this.code,
    required this.title,
    required this.description,
    required this.assetTypeKeys,
    required this.assetClassIds,
    required this.componentNodeIds,
    required this.valueType,
    required this.unit,
    required this.choiceValues,
    required this.minimumValue,
    required this.maximumValue,
    required this.preconditions,
    required this.requiresChargeNo,
  });

  final String id;
  final int version;
  final String code;
  final String title;
  final String description;
  final List<String> assetTypeKeys;
  final List<String> assetClassIds;
  final List<String> componentNodeIds;
  final InspectionValueType valueType;
  final String? unit;
  final List<String> choiceValues;
  final double? minimumValue;
  final double? maximumValue;
  final List<String> preconditions;
  final bool requiresChargeNo;

  factory FrozenInspectionDefinition.fromMap(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final schema = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
    );
    if (schema != 1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported inspection schema',
      );
    }
    final valueType = readRequiredPersistedEnum(
      InspectionValueType.values,
      map['valueType'],
      field: 'valueType',
      source: source,
    );
    final unit = readOptionalPersistedString(
      map['unit'],
      field: 'unit',
      source: source,
    );
    final choices = List<String>.unmodifiable(
      readOptionalPersistedStringList(
        map['choiceValues'],
        field: 'choiceValues',
        source: source,
      ),
    );
    final minimum = readOptionalPersistedDouble(
      map['minimumValue'],
      field: 'minimumValue',
      source: source,
    );
    final maximum = readOptionalPersistedDouble(
      map['maximumValue'],
      field: 'maximumValue',
      source: source,
    );
    if ((valueType == InspectionValueType.number) != (unit != null) ||
        (valueType == InspectionValueType.choice) != choices.isNotEmpty ||
        (valueType != InspectionValueType.number &&
            (minimum != null || maximum != null)) ||
        (minimum != null && maximum != null && minimum > maximum)) {
      throw PersistedDataFormatException(
        field: 'valueType',
        source: source,
        detail: 'definition value contract is inconsistent',
      );
    }
    return FrozenInspectionDefinition(
      id: readRequiredPersistedString(
        map['definitionId'],
        field: 'definitionId',
        source: source,
      ),
      version: readRequiredPersistedInt(
        map['definitionVersion'],
        field: 'definitionVersion',
        source: source,
        minimum: 1,
      ),
      code: readRequiredPersistedString(
        map['code'],
        field: 'code',
        source: source,
      ),
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
      assetTypeKeys: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['assetTypeKeys'],
          field: 'assetTypeKeys',
          source: source,
        ),
      ),
      assetClassIds: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['assetClassIds'],
          field: 'assetClassIds',
          source: source,
        ),
      ),
      componentNodeIds: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['componentNodeIds'],
          field: 'componentNodeIds',
          source: source,
        ),
      ),
      valueType: valueType,
      unit: unit,
      choiceValues: choices,
      minimumValue: minimum,
      maximumValue: maximum,
      preconditions: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['preconditions'],
          field: 'preconditions',
          source: source,
        ),
      ),
      requiresChargeNo: readRequiredPersistedBool(
        map['requiresChargeNo'],
        field: 'requiresChargeNo',
        source: source,
      ),
    );
  }
}

class InspectionDefinition {
  const InspectionDefinition({
    required this.id,
    required this.version,
    required this.status,
    required this.frozen,
    required this.updatedAt,
  });

  final String id;
  final int version;
  final InspectionDefinitionStatus status;
  final FrozenInspectionDefinition frozen;
  final DateTime updatedAt;

  bool get isActive => status == InspectionDefinitionStatus.active;

  factory InspectionDefinition.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'inspection_definitions/$documentId';
    final version = readRequiredPersistedInt(
      map['version'],
      field: 'version',
      source: source,
      minimum: 1,
    );
    final frozen = FrozenInspectionDefinition.fromMap({
      'schemaVersion': map['schemaVersion'],
      'definitionId': map['definitionId'],
      'definitionVersion': version,
      'code': map['code'],
      'title': map['title'],
      'description': map['description'],
      'assetTypeKeys': map['assetTypeKeys'],
      'assetClassIds': map['assetClassIds'],
      'componentNodeIds': map['componentNodeIds'],
      'valueType': map['valueType'],
      'unit': map['unit'],
      'choiceValues': map['choiceValues'],
      'minimumValue': map['minimumValue'],
      'maximumValue': map['maximumValue'],
      'preconditions': map['preconditions'],
      'requiresChargeNo': map['requiresChargeNo'],
    }, source: source);
    if (frozen.id != documentId) {
      throw PersistedDataFormatException(
        field: 'definitionId',
        source: source,
        detail: 'must match document ID',
      );
    }
    return InspectionDefinition(
      id: documentId,
      version: version,
      status: readRequiredPersistedEnum(
        InspectionDefinitionStatus.values,
        map['status'],
        field: 'status',
        source: source,
      ),
      frozen: frozen,
      updatedAt: readRequiredPersistedDateTime(
        map['updatedAt'],
        field: 'updatedAt',
        source: source,
      ),
    );
  }
}

class InspectionCampaign {
  const InspectionCampaign({
    required this.id,
    required this.version,
    required this.status,
    required this.definition,
    required this.purpose,
    required this.assetTypeKey,
    required this.assetClassId,
    required this.targetAssetNumbers,
    required this.expectedPopulation,
    required this.observerRoleKeys,
    required this.observationCount,
    required this.distinctTargetKeys,
    required this.latestObservationAt,
    required this.createdAt,
  });

  final String id;
  final int version;
  final InspectionCampaignStatus status;
  final FrozenInspectionDefinition definition;
  final String purpose;
  final String assetTypeKey;
  final String? assetClassId;
  final List<int> targetAssetNumbers;
  final int? expectedPopulation;
  final List<String> observerRoleKeys;
  final int observationCount;
  final List<String> distinctTargetKeys;
  final DateTime? latestObservationAt;
  final DateTime createdAt;

  int get distinctTargetCount => distinctTargetKeys.length;
  int? get remainingPopulation =>
      expectedPopulation == null
          ? null
          : (expectedPopulation! - distinctTargetCount).clamp(
            0,
            expectedPopulation!,
          );
  double? get coverageFraction =>
      expectedPopulation == null
          ? null
          : (distinctTargetCount / expectedPopulation!).clamp(0, 1);

  factory InspectionCampaign.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'inspection_campaigns/$documentId';
    final id = readRequiredPersistedString(
      map['campaignId'],
      field: 'campaignId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'campaignId',
        source: source,
        detail: 'must match document ID',
      );
    }
    final definition = FrozenInspectionDefinition.fromMap(
      _object(map['definition'], field: 'definition', source: source),
      source: '$source/definition',
    );
    if (definition.id !=
            readRequiredPersistedString(
              map['definitionId'],
              field: 'definitionId',
              source: source,
            ) ||
        definition.version !=
            readRequiredPersistedInt(
              map['definitionVersion'],
              field: 'definitionVersion',
              source: source,
              minimum: 1,
            )) {
      throw PersistedDataFormatException(
        field: 'definition',
        source: source,
        detail: 'frozen identity must match campaign projection fields',
      );
    }
    final campaign = InspectionCampaign(
      id: id,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      status: readRequiredPersistedEnum(
        InspectionCampaignStatus.values,
        map['status'],
        field: 'status',
        source: source,
      ),
      definition: definition,
      purpose: readRequiredPersistedString(
        map['purpose'],
        field: 'purpose',
        source: source,
      ),
      assetTypeKey: readRequiredPersistedString(
        map['assetTypeKey'],
        field: 'assetTypeKey',
        source: source,
      ),
      assetClassId: readOptionalPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      targetAssetNumbers: _integers(
        map['targetAssetNumbers'],
        field: 'targetAssetNumbers',
        source: source,
      ),
      expectedPopulation: readOptionalPersistedInt(
        map['expectedPopulation'],
        field: 'expectedPopulation',
        source: source,
        minimum: 1,
      ),
      observerRoleKeys: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['observerRoleKeys'],
          field: 'observerRoleKeys',
          source: source,
        ),
      ),
      observationCount: readRequiredPersistedInt(
        map['observationCount'],
        field: 'observationCount',
        source: source,
        minimum: 0,
      ),
      distinctTargetKeys: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['distinctTargetKeys'],
          field: 'distinctTargetKeys',
          source: source,
        ),
      ),
      latestObservationAt: readOptionalPersistedDateTime(
        map['latestObservationAt'],
        field: 'latestObservationAt',
        source: source,
      ),
      createdAt: readRequiredPersistedDateTime(
        map['createdAt'],
        field: 'createdAt',
        source: source,
      ),
    );
    if ((!campaign.definition.assetTypeKeys.contains(campaign.assetTypeKey) &&
            (campaign.assetClassId == null ||
                !campaign.definition.assetClassIds.contains(
                  campaign.assetClassId,
                ))) ||
        (campaign.expectedPopulation != null &&
            campaign.targetAssetNumbers.length >
                campaign.expectedPopulation!) ||
        campaign.observationCount < campaign.distinctTargetKeys.length ||
        campaign.targetAssetNumbers.toSet().length !=
            campaign.targetAssetNumbers.length ||
        campaign.distinctTargetKeys.toSet().length !=
            campaign.distinctTargetKeys.length) {
      throw PersistedDataFormatException(
        field: 'campaignProjection',
        source: source,
        detail: 'scope or coverage counters are inconsistent',
      );
    }
    return campaign;
  }
}

class InspectionObservation {
  const InspectionObservation({
    required this.id,
    required this.campaignId,
    required this.definition,
    required this.assetTypeKey,
    required this.assetNumber,
    required this.assetClassId,
    required this.assetInstanceId,
    required this.componentNodeId,
    required this.componentNodeVersion,
    required this.componentName,
    required this.hierarchyPath,
    required this.physicalPosition,
    required this.targetKey,
    required this.observedAt,
    required this.observerUid,
    required this.observerName,
    required this.numericValue,
    required this.booleanValue,
    required this.textValue,
    required this.choiceValue,
    required this.unit,
    required this.outOfRange,
    required this.operatingConditions,
    required this.chargeNo,
    required this.note,
    required this.evidenceUrls,
    required this.supersedesObservationId,
    required this.recordedAt,
  });

  final String id;
  final String campaignId;
  final FrozenInspectionDefinition definition;
  final String assetTypeKey;
  final int assetNumber;
  final String? assetClassId;
  final String? assetInstanceId;
  final String? componentNodeId;
  final int? componentNodeVersion;
  final String? componentName;
  final List<String> hierarchyPath;
  final String? physicalPosition;
  final String targetKey;
  final DateTime observedAt;
  final String observerUid;
  final String observerName;
  final double? numericValue;
  final bool? booleanValue;
  final String? textValue;
  final String? choiceValue;
  final String? unit;
  final bool outOfRange;
  final Map<String, String> operatingConditions;
  final int? chargeNo;
  final String? note;
  final List<String> evidenceUrls;
  final String? supersedesObservationId;
  final DateTime recordedAt;

  String get displayValue => switch (definition.valueType) {
    InspectionValueType.number => '${numericValue ?? '-'} ${unit ?? ''}'.trim(),
    InspectionValueType.boolean => booleanValue == true ? 'Yes' : 'No',
    InspectionValueType.text => textValue ?? '-',
    InspectionValueType.choice => choiceValue ?? '-',
  };

  factory InspectionObservation.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'inspection_observations/$documentId';
    final id = readRequiredPersistedString(
      map['observationId'],
      field: 'observationId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'observationId',
        source: source,
        detail: 'must match document ID',
      );
    }
    final definition = FrozenInspectionDefinition.fromMap(
      _object(map['definition'], field: 'definition', source: source),
      source: '$source/definition',
    );
    if (definition.id !=
            readRequiredPersistedString(
              map['definitionId'],
              field: 'definitionId',
              source: source,
            ) ||
        definition.version !=
            readRequiredPersistedInt(
              map['definitionVersion'],
              field: 'definitionVersion',
              source: source,
              minimum: 1,
            ) ||
        definition.valueType.name !=
            readRequiredPersistedString(
              map['valueType'],
              field: 'valueType',
              source: source,
            )) {
      throw PersistedDataFormatException(
        field: 'definition',
        source: source,
        detail: 'frozen identity must match observation projection fields',
      );
    }
    final observation = InspectionObservation(
      id: id,
      campaignId: readRequiredPersistedString(
        map['campaignId'],
        field: 'campaignId',
        source: source,
      ),
      definition: definition,
      assetTypeKey: readRequiredPersistedString(
        map['assetTypeKey'],
        field: 'assetTypeKey',
        source: source,
      ),
      assetNumber: readRequiredPersistedInt(
        map['assetNumber'],
        field: 'assetNumber',
        source: source,
        minimum: 1,
      ),
      assetClassId: readOptionalPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      assetInstanceId: readOptionalPersistedString(
        map['assetInstanceId'],
        field: 'assetInstanceId',
        source: source,
      ),
      componentNodeId: readOptionalPersistedString(
        map['componentNodeId'],
        field: 'componentNodeId',
        source: source,
      ),
      componentNodeVersion: readOptionalPersistedInt(
        map['componentNodeVersion'],
        field: 'componentNodeVersion',
        source: source,
        minimum: 1,
      ),
      componentName: readOptionalPersistedString(
        map['componentName'],
        field: 'componentName',
        source: source,
      ),
      hierarchyPath: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['hierarchyPath'],
          field: 'hierarchyPath',
          source: source,
        ),
      ),
      physicalPosition: readOptionalPersistedString(
        map['physicalPosition'],
        field: 'physicalPosition',
        source: source,
      ),
      targetKey: readRequiredPersistedString(
        map['targetKey'],
        field: 'targetKey',
        source: source,
      ),
      observedAt: readRequiredPersistedDateTime(
        map['observedAt'],
        field: 'observedAt',
        source: source,
      ),
      observerUid: readRequiredPersistedString(
        map['observerUid'],
        field: 'observerUid',
        source: source,
      ),
      observerName: readRequiredPersistedString(
        map['observerName'],
        field: 'observerName',
        source: source,
      ),
      numericValue: readOptionalPersistedDouble(
        map['numericValue'],
        field: 'numericValue',
        source: source,
      ),
      booleanValue: readOptionalPersistedBool(
        map['booleanValue'],
        field: 'booleanValue',
        source: source,
      ),
      textValue: readOptionalPersistedString(
        map['textValue'],
        field: 'textValue',
        source: source,
      ),
      choiceValue: readOptionalPersistedString(
        map['choiceValue'],
        field: 'choiceValue',
        source: source,
      ),
      unit: readOptionalPersistedString(
        map['unit'],
        field: 'unit',
        source: source,
      ),
      outOfRange: readRequiredPersistedBool(
        map['outOfRange'],
        field: 'outOfRange',
        source: source,
      ),
      operatingConditions: _stringMap(
        map['operatingConditions'],
        field: 'operatingConditions',
        source: source,
      ),
      chargeNo: readOptionalPersistedInt(
        map['chargeNo'],
        field: 'chargeNo',
        source: source,
        minimum: 10000,
      ),
      note: readOptionalPersistedString(
        map['note'],
        field: 'note',
        source: source,
      ),
      evidenceUrls: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['evidenceUrls'],
          field: 'evidenceUrls',
          source: source,
        ),
      ),
      supersedesObservationId: readOptionalPersistedString(
        map['supersedesObservationId'],
        field: 'supersedesObservationId',
        source: source,
      ),
      recordedAt: readRequiredPersistedDateTime(
        map['recordedAt'],
        field: 'recordedAt',
        source: source,
      ),
    );
    final hasAssetClass = observation.assetClassId != null;
    final hasAssetInstance = observation.assetInstanceId != null;
    final componentParts = [
      observation.componentNodeId,
      observation.componentNodeVersion,
      observation.componentName,
    ];
    final componentPartCount =
        componentParts.where((item) => item != null).length;
    final valuePartCount =
        [
          observation.numericValue,
          observation.booleanValue,
          observation.textValue,
          observation.choiceValue,
        ].where((item) => item != null).length;
    final valueMatches = switch (definition.valueType) {
      InspectionValueType.number =>
        observation.numericValue != null && observation.unit == definition.unit,
      InspectionValueType.boolean => observation.booleanValue != null,
      InspectionValueType.text => observation.textValue != null,
      InspectionValueType.choice =>
        observation.choiceValue != null &&
            definition.choiceValues.contains(observation.choiceValue),
    };
    if (hasAssetClass != hasAssetInstance ||
        (componentPartCount != 0 && componentPartCount != 3) ||
        (definition.componentNodeIds.isNotEmpty &&
            !definition.componentNodeIds.contains(
              observation.componentNodeId,
            )) ||
        valuePartCount != 1 ||
        !valueMatches ||
        (observation.chargeNo != null && observation.chargeNo! > 99999)) {
      throw PersistedDataFormatException(
        field: 'observationProjection',
        source: source,
        detail: 'identity, charge or typed value fields are inconsistent',
      );
    }
    return observation;
  }
}
