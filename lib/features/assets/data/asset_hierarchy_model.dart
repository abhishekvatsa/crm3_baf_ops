import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';

enum AssetHierarchyStatus { active, retired }

enum AssetHierarchyReferenceScope {
  definition,
  physicalAsset,
  installedComponent,
}

enum InnerCoverPositionState { linked, noneLinked }

class InnerCoverEventReference {
  final String baseAssetInstanceId;
  final int baseAssetNumber;
  final InnerCoverPositionState positionState;
  final String? innerCoverId;
  final String? innerCoverSerialNumber;
  final String? linkageId;
  final int? assignmentVersion;
  final DateTime? linkedAt;
  final DateTime eventAt;
  final DateTime confirmedAt;
  final String confirmedByUid;
  final String confirmedByName;

  const InnerCoverEventReference({
    required this.baseAssetInstanceId,
    required this.baseAssetNumber,
    required this.positionState,
    this.innerCoverId,
    this.innerCoverSerialNumber,
    this.linkageId,
    this.assignmentVersion,
    this.linkedAt,
    required this.eventAt,
    required this.confirmedAt,
    required this.confirmedByUid,
    required this.confirmedByName,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'baseAssetInstanceId': baseAssetInstanceId,
    'baseAssetNumber': baseAssetNumber,
    'positionState': positionState.name,
    'innerCoverId': innerCoverId,
    'innerCoverSerialNumber': innerCoverSerialNumber,
    'linkageId': linkageId,
    'assignmentVersion': assignmentVersion,
    'linkedAt': linkedAt?.toUtc().toIso8601String(),
    'eventAt': eventAt.toUtc().toIso8601String(),
    'confirmedAt': confirmedAt.toUtc().toIso8601String(),
    'confirmedByUid': confirmedByUid,
    'confirmedByName': confirmedByName,
  };

  factory InnerCoverEventReference.fromMap(
    Map<String, dynamic> map, {
    String? source,
  }) {
    final positionState = readRequiredPersistedEnum(
      InnerCoverPositionState.values,
      map['positionState'],
      field: 'innerCoverAssociation.positionState',
      source: source,
    );
    final innerCoverId = readOptionalPersistedString(
      map['innerCoverId'],
      field: 'innerCoverAssociation.innerCoverId',
      source: source,
    );
    final serial = readOptionalPersistedString(
      map['innerCoverSerialNumber'],
      field: 'innerCoverAssociation.innerCoverSerialNumber',
      source: source,
    );
    final linkageId = readOptionalPersistedString(
      map['linkageId'],
      field: 'innerCoverAssociation.linkageId',
      source: source,
    );
    final assignmentVersion = readOptionalPersistedInt(
      map['assignmentVersion'],
      field: 'innerCoverAssociation.assignmentVersion',
      source: source,
      minimum: 1,
    );
    final linkedAt = readOptionalPersistedDateTime(
      map['linkedAt'],
      field: 'innerCoverAssociation.linkedAt',
      source: source,
    );
    final completeLink =
        innerCoverId != null &&
        serial != null &&
        linkageId != null &&
        assignmentVersion != null &&
        linkedAt != null;
    final absentLink =
        innerCoverId == null &&
        serial == null &&
        linkageId == null &&
        assignmentVersion == null &&
        linkedAt == null;
    if ((positionState == InnerCoverPositionState.linked && !completeLink) ||
        (positionState == InnerCoverPositionState.noneLinked && !absentLink)) {
      throw PersistedDataFormatException(
        field: 'innerCoverAssociation.positionState',
        source: source,
        detail:
            'linked identity must be complete, or wholly absent when none is linked',
      );
    }
    final reference = InnerCoverEventReference(
      baseAssetInstanceId: readRequiredPersistedString(
        map['baseAssetInstanceId'],
        field: 'innerCoverAssociation.baseAssetInstanceId',
        source: source,
      ),
      baseAssetNumber: readRequiredPersistedInt(
        map['baseAssetNumber'],
        field: 'innerCoverAssociation.baseAssetNumber',
        source: source,
        minimum: 1,
      ),
      positionState: positionState,
      innerCoverId: innerCoverId,
      innerCoverSerialNumber: serial,
      linkageId: linkageId,
      assignmentVersion: assignmentVersion,
      linkedAt: linkedAt,
      eventAt: readRequiredPersistedDateTime(
        map['eventAt'],
        field: 'innerCoverAssociation.eventAt',
        source: source,
      ),
      confirmedAt: readRequiredPersistedDateTime(
        map['confirmedAt'],
        field: 'innerCoverAssociation.confirmedAt',
        source: source,
      ),
      confirmedByUid: readRequiredPersistedString(
        map['confirmedByUid'],
        field: 'innerCoverAssociation.confirmedByUid',
        source: source,
      ),
      confirmedByName: readRequiredPersistedString(
        map['confirmedByName'],
        field: 'innerCoverAssociation.confirmedByName',
        source: source,
      ),
    );
    if (reference.linkedAt?.isAfter(reference.confirmedAt) == true) {
      throw PersistedDataFormatException(
        field: 'innerCoverAssociation.linkedAt',
        source: source,
        detail: 'cannot be after confirmation',
      );
    }
    if (reference.eventAt.isAfter(reference.confirmedAt)) {
      throw PersistedDataFormatException(
        field: 'innerCoverAssociation.eventAt',
        source: source,
        detail: 'cannot be after confirmation',
      );
    }
    return reference;
  }
}

enum AssetOwnershipStatus {
  unassigned,
  provisional,
  confirmed;

  String get label => switch (this) {
    unassigned => 'Ownership not assigned',
    provisional => 'Provisional ownership',
    confirmed => 'Confirmed ownership',
  };
}

enum AssetHierarchyNodeType {
  grouping,
  assembly,
  component,
  subcomponent;

  String get label => switch (this) {
    grouping => 'Grouping',
    assembly => 'Assembly',
    component => 'Component',
    subcomponent => 'Subcomponent',
  };
}

enum ElectricalContactArrangement {
  notStated,
  notApplicable,
  normallyOpen,
  normallyClosed,
  changeover;

  String get label => switch (this) {
    notStated => 'Not stated',
    notApplicable => 'Not applicable',
    normallyOpen => 'Normally open (NO)',
    normallyClosed => 'Normally closed (NC)',
    changeover => 'Changeover (NO/NC)',
  };
}

String? cleanHierarchyText(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}

String normalizeAssetComponentTag(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');

class AssetHierarchyReference {
  final AssetHierarchyReferenceScope scope;
  final String assetClassId;
  final String assetClassCode;
  final String assetClassName;
  final String nodeId;
  final int nodeVersion;
  final String nodeName;
  final String? assetInstanceId;
  final int? assetInstanceVersion;
  final int? assetNumber;
  final String? assetInstanceName;
  final String? componentInstanceId;
  final int? componentInstanceVersion;
  final String? componentTag;
  final List<String> hierarchyPath;
  final AssetOwnershipStatus ownershipStatus;
  final String? ownerDiscipline;
  final List<String> accountableRoleKeys;
  final InnerCoverEventReference? innerCoverAssociation;

  const AssetHierarchyReference({
    this.scope = AssetHierarchyReferenceScope.definition,
    required this.assetClassId,
    required this.assetClassCode,
    required this.assetClassName,
    required this.nodeId,
    required this.nodeVersion,
    required this.nodeName,
    this.assetInstanceId,
    this.assetInstanceVersion,
    this.assetNumber,
    this.assetInstanceName,
    this.componentInstanceId,
    this.componentInstanceVersion,
    this.componentTag,
    required this.hierarchyPath,
    required this.ownershipStatus,
    this.ownerDiscipline,
    this.accountableRoleKeys = const <String>[],
    this.innerCoverAssociation,
  });

  Map<String, dynamic> toMap() {
    if (scope == AssetHierarchyReferenceScope.installedComponent &&
        ownershipStatus != AssetOwnershipStatus.confirmed) {
      throw StateError(
        'Installed component references require confirmed ownership.',
      );
    }
    if (scope == AssetHierarchyReferenceScope.physicalAsset &&
        (assetInstanceId == null ||
            assetInstanceVersion == null ||
            assetNumber == null ||
            assetInstanceName == null ||
            componentInstanceId != null ||
            componentInstanceVersion != null)) {
      throw StateError(
        'Physical asset references require exact asset identity only.',
      );
    }
    if (innerCoverAssociation != null &&
        (scope == AssetHierarchyReferenceScope.definition ||
            innerCoverAssociation!.baseAssetInstanceId != assetInstanceId ||
            innerCoverAssociation!.baseAssetNumber != assetNumber)) {
      throw StateError(
        'Inner Cover position must identify this physical Base.',
      );
    }
    return <String, dynamic>{
      'schemaVersion':
          scope == AssetHierarchyReferenceScope.physicalAsset ||
                  innerCoverAssociation != null
              ? 3
              : 2,
      'scope': scope.name,
      'assetClassId': assetClassId,
      'assetClassCode': assetClassCode,
      'assetClassName': assetClassName,
      'nodeId': nodeId,
      'nodeVersion': nodeVersion,
      'nodeName': nodeName,
      'assetInstanceId': assetInstanceId,
      'assetInstanceVersion': assetInstanceVersion,
      'assetNumber': assetNumber,
      'assetInstanceName': assetInstanceName,
      'componentInstanceId': componentInstanceId,
      'componentInstanceVersion': componentInstanceVersion,
      'componentTag': componentTag,
      'hierarchyPath': hierarchyPath,
      'ownershipStatus': ownershipStatus.name,
      'ownerDiscipline': ownerDiscipline,
      'accountableRoleKeys': accountableRoleKeys,
      'innerCoverAssociation': innerCoverAssociation?.toMap(),
    };
  }

  String encode() => jsonEncode(toMap());

  factory AssetHierarchyReference.fromMap(
    Map<String, dynamic> map, {
    String? source,
  }) {
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    if (schemaVersion != 1 && schemaVersion != 2 && schemaVersion != 3) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported asset hierarchy reference schema $schemaVersion',
      );
    }
    final scope =
        schemaVersion == 1
            ? AssetHierarchyReferenceScope.definition
            : readRequiredPersistedEnum(
              AssetHierarchyReferenceScope.values,
              map['scope'],
              field: 'scope',
              source: source,
            );
    if (scope == AssetHierarchyReferenceScope.physicalAsset &&
        schemaVersion < 3) {
      throw PersistedDataFormatException(
        field: 'scope',
        source: source,
        detail: 'physical asset references require schema 3',
      );
    }
    final assetInstanceId = readOptionalPersistedString(
      map['assetInstanceId'],
      field: 'assetInstanceId',
      source: source,
    );
    final assetInstanceVersion = readOptionalPersistedInt(
      map['assetInstanceVersion'],
      field: 'assetInstanceVersion',
      source: source,
      minimum: 1,
    );
    final assetNumber = readOptionalPersistedInt(
      map['assetNumber'],
      field: 'assetNumber',
      source: source,
      minimum: 1,
    );
    final assetInstanceName = readOptionalPersistedString(
      map['assetInstanceName'],
      field: 'assetInstanceName',
      source: source,
    );
    final componentInstanceId = readOptionalPersistedString(
      map['componentInstanceId'],
      field: 'componentInstanceId',
      source: source,
    );
    final componentInstanceVersion = readOptionalPersistedInt(
      map['componentInstanceVersion'],
      field: 'componentInstanceVersion',
      source: source,
      minimum: 1,
    );
    final rawInnerCoverAssociation = map['innerCoverAssociation'];
    final InnerCoverEventReference? innerCoverAssociation;
    if (rawInnerCoverAssociation == null) {
      innerCoverAssociation = null;
    } else if (schemaVersion == 3 && rawInnerCoverAssociation is Map) {
      innerCoverAssociation = InnerCoverEventReference.fromMap(
        Map<String, dynamic>.from(rawInnerCoverAssociation),
        source: source,
      );
    } else {
      throw PersistedDataFormatException(
        field: 'innerCoverAssociation',
        source: source,
        detail: 'requires a schema-3 object',
      );
    }
    if (scope == AssetHierarchyReferenceScope.installedComponent &&
        (assetInstanceId == null ||
            assetInstanceVersion == null ||
            assetNumber == null ||
            assetInstanceName == null ||
            componentInstanceId == null ||
            componentInstanceVersion == null)) {
      throw PersistedDataFormatException(
        field: 'scope',
        source: source,
        detail:
            'installed component references require complete instance identity',
      );
    }
    if (scope == AssetHierarchyReferenceScope.physicalAsset &&
        (assetInstanceId == null ||
            assetInstanceVersion == null ||
            assetNumber == null ||
            assetInstanceName == null ||
            componentInstanceId != null ||
            componentInstanceVersion != null)) {
      throw PersistedDataFormatException(
        field: 'scope',
        source: source,
        detail: 'physical asset references require exact asset identity only',
      );
    }
    final reference = AssetHierarchyReference(
      scope: scope,
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
      nodeId: readRequiredPersistedString(
        map['nodeId'],
        field: 'nodeId',
        source: source,
      ),
      nodeVersion: readRequiredPersistedInt(
        map['nodeVersion'],
        field: 'nodeVersion',
        source: source,
        minimum: 1,
      ),
      nodeName: readRequiredPersistedString(
        map['nodeName'],
        field: 'nodeName',
        source: source,
      ),
      assetInstanceId: assetInstanceId,
      assetInstanceVersion: assetInstanceVersion,
      assetNumber: assetNumber,
      assetInstanceName: assetInstanceName,
      componentInstanceId: componentInstanceId,
      componentInstanceVersion: componentInstanceVersion,
      componentTag: readOptionalPersistedString(
        map['componentTag'],
        field: 'componentTag',
        source: source,
      ),
      hierarchyPath: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['hierarchyPath'],
          field: 'hierarchyPath',
          source: source,
        ),
      ),
      ownershipStatus: readRequiredPersistedEnum(
        AssetOwnershipStatus.values,
        map['ownershipStatus'],
        field: 'ownershipStatus',
        source: source,
      ),
      ownerDiscipline: readOptionalPersistedString(
        map['ownerDiscipline'],
        field: 'ownerDiscipline',
        source: source,
      ),
      accountableRoleKeys: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['accountableRoleKeys'],
          field: 'accountableRoleKeys',
          source: source,
        ),
      ),
      innerCoverAssociation: innerCoverAssociation,
    );
    requireValidPersistedAssetOwnership(
      reference.ownershipStatus,
      reference.ownerDiscipline,
      reference.accountableRoleKeys,
      source: source,
    );
    if (reference.scope == AssetHierarchyReferenceScope.installedComponent &&
        reference.ownershipStatus != AssetOwnershipStatus.confirmed) {
      throw PersistedDataFormatException(
        field: 'ownershipStatus',
        source: source,
        detail: 'installed component references require confirmed ownership',
      );
    }
    if (reference.innerCoverAssociation != null &&
        (reference.scope == AssetHierarchyReferenceScope.definition ||
            reference.innerCoverAssociation!.baseAssetInstanceId !=
                reference.assetInstanceId ||
            reference.innerCoverAssociation!.baseAssetNumber !=
                reference.assetNumber)) {
      throw PersistedDataFormatException(
        field: 'innerCoverAssociation',
        source: source,
        detail: 'must identify the same physical Base as the reference',
      );
    }
    return reference;
  }

  factory AssetHierarchyReference.decode(String value, {String? source}) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw PersistedDataFormatException(
        field: 'assetHierarchyRefJson',
        source: source,
        detail: 'expected a JSON object',
      );
    }
    return AssetHierarchyReference.fromMap(
      Map<String, dynamic>.from(decoded),
      source: source,
    );
  }
}

String? readOptionalAssetHierarchyReferenceJson(
  dynamic value, {
  required String field,
  String? source,
}) {
  final encoded = readOptionalPersistedString(
    value,
    field: field,
    source: source,
    emptyAsNull: false,
  );
  if (encoded != null) {
    AssetHierarchyReference.decode(encoded, source: source);
  }
  return encoded;
}

class AssetClassDraft {
  final String code;
  final String name;
  final String majorArea;
  final String? shortDescription;
  final String? longDescription;
  final String? legacyAssetTypeKey;

  const AssetClassDraft({
    required this.code,
    required this.name,
    required this.majorArea,
    this.shortDescription,
    this.longDescription,
    this.legacyAssetTypeKey,
  });

  AssetClassDraft normalized() => AssetClassDraft(
    code: code.trim().toUpperCase(),
    name: name.trim(),
    majorArea: majorArea.trim(),
    shortDescription: cleanHierarchyText(shortDescription),
    longDescription: cleanHierarchyText(longDescription),
    legacyAssetTypeKey: cleanHierarchyText(legacyAssetTypeKey),
  );

  List<String> validate() {
    final value = normalized();
    final errors = <String>[];
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{1,39}$').hasMatch(value.code)) {
      errors.add(
        'Class code must be 2-40 letters, numbers, hyphens or underscores.',
      );
    }
    if (value.name.isEmpty || value.name.length > 160) {
      errors.add('Class name must contain 1-160 characters.');
    }
    if (value.majorArea.isEmpty || value.majorArea.length > 160) {
      errors.add('Major area must contain 1-160 characters.');
    }
    if ((value.shortDescription?.length ?? 0) > 500) {
      errors.add('Short description cannot exceed 500 characters.');
    }
    if ((value.longDescription?.length ?? 0) > 4000) {
      errors.add('Long description cannot exceed 4,000 characters.');
    }
    if (value.legacyAssetTypeKey != null &&
        !const {
          'base',
          'furnace',
          'forceCooler',
          'innerCover',
        }.contains(value.legacyAssetTypeKey)) {
      errors.add('Current app asset type is not recognized.');
    }
    return errors;
  }
}

class AssetClassRecord {
  final String id;
  final String code;
  final String name;
  final String majorArea;
  final String? shortDescription;
  final String? longDescription;
  final String? legacyAssetTypeKey;
  final AssetHierarchyStatus status;
  final int version;
  final DateTime createdAt;
  final String createdByUid;
  final String? createdByName;
  final DateTime updatedAt;
  final String updatedByUid;
  final String? updatedByName;
  final String lastMutationId;

  const AssetClassRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.majorArea,
    this.shortDescription,
    this.longDescription,
    this.legacyAssetTypeKey,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.createdByUid,
    this.createdByName,
    required this.updatedAt,
    required this.updatedByUid,
    this.updatedByName,
    required this.lastMutationId,
  });

  bool get isActive => status == AssetHierarchyStatus.active;

  AssetClassDraft get draft => AssetClassDraft(
    code: code,
    name: name,
    majorArea: majorArea,
    shortDescription: shortDescription,
    longDescription: longDescription,
    legacyAssetTypeKey: legacyAssetTypeKey,
  );

  factory AssetClassRecord.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'asset_classes/$documentId';
    final id = readRequiredPersistedString(
      map['assetClassId'],
      field: 'assetClassId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'assetClassId',
        source: source,
        detail: 'must match the document ID',
      );
    }
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
        detail: 'unsupported hierarchy schema $schemaVersion',
      );
    }
    return AssetClassRecord(
      id: id,
      code: readRequiredPersistedString(
        map['code'],
        field: 'code',
        source: source,
      ),
      name: readRequiredPersistedString(
        map['name'],
        field: 'name',
        source: source,
      ),
      majorArea: readRequiredPersistedString(
        map['majorArea'],
        field: 'majorArea',
        source: source,
      ),
      shortDescription: readOptionalPersistedString(
        map['shortDescription'],
        field: 'shortDescription',
        source: source,
      ),
      longDescription: readOptionalPersistedString(
        map['longDescription'],
        field: 'longDescription',
        source: source,
      ),
      legacyAssetTypeKey: readOptionalPersistedString(
        map['legacyAssetTypeKey'],
        field: 'legacyAssetTypeKey',
        source: source,
      ),
      status: readRequiredPersistedEnum(
        AssetHierarchyStatus.values,
        map['status'],
        field: 'status',
        source: source,
      ),
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
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
      createdByName: readOptionalPersistedString(
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
      updatedByName: readOptionalPersistedString(
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

  Map<String, dynamic> auditSnapshot() => <String, dynamic>{
    'assetClassId': id,
    'code': code,
    'name': name,
    'majorArea': majorArea,
    'shortDescription': shortDescription,
    'longDescription': longDescription,
    'legacyAssetTypeKey': legacyAssetTypeKey,
    'status': status.name,
    'version': version,
  };
}

class AssetHierarchyNodeDraft {
  final String? parentNodeId;
  final AssetHierarchyNodeType nodeType;
  final String name;
  final String? componentTag;
  final String? shortDescription;
  final String? longDescription;
  final String? discipline;
  final String? operatingType;
  final String? normalState;
  final String? failState;
  final ElectricalContactArrangement contactArrangement;
  final String? manufacturer;
  final String? model;
  final String? applicability;
  final String? sourceReference;
  final AssetOwnershipStatus ownershipStatus;
  final String? ownerDiscipline;
  final List<String> accountableRoleKeys;
  final int sortOrder;

  const AssetHierarchyNodeDraft({
    this.parentNodeId,
    required this.nodeType,
    required this.name,
    this.componentTag,
    this.shortDescription,
    this.longDescription,
    this.discipline,
    this.operatingType,
    this.normalState,
    this.failState,
    this.contactArrangement = ElectricalContactArrangement.notStated,
    this.manufacturer,
    this.model,
    this.applicability,
    this.sourceReference,
    this.ownershipStatus = AssetOwnershipStatus.unassigned,
    this.ownerDiscipline,
    this.accountableRoleKeys = const <String>[],
    this.sortOrder = 0,
  });

  AssetHierarchyNodeDraft normalized() => AssetHierarchyNodeDraft(
    parentNodeId: cleanHierarchyText(parentNodeId),
    nodeType: nodeType,
    name: name.trim(),
    componentTag: cleanHierarchyText(componentTag),
    shortDescription: cleanHierarchyText(shortDescription),
    longDescription: cleanHierarchyText(longDescription),
    discipline: cleanHierarchyText(discipline),
    operatingType: cleanHierarchyText(operatingType),
    normalState: cleanHierarchyText(normalState),
    failState: cleanHierarchyText(failState),
    contactArrangement: contactArrangement,
    manufacturer: cleanHierarchyText(manufacturer),
    model: cleanHierarchyText(model),
    applicability: cleanHierarchyText(applicability),
    sourceReference: cleanHierarchyText(sourceReference),
    ownershipStatus: ownershipStatus,
    ownerDiscipline: cleanHierarchyText(ownerDiscipline),
    accountableRoleKeys:
        accountableRoleKeys
            .map((role) => role.trim())
            .where((role) => role.isNotEmpty)
            .toSet()
            .toList()
          ..sort(),
    sortOrder: sortOrder,
  );

  List<String> validate() {
    final value = normalized();
    final errors = <String>[];
    if (value.name.isEmpty || value.name.length > 200) {
      errors.add('Node name must contain 1-200 characters.');
    }
    void optionalLimit(String label, String? text, int maximum) {
      if ((text?.length ?? 0) > maximum) {
        errors.add('$label cannot exceed $maximum characters.');
      }
    }

    optionalLimit('Component tag', value.componentTag, 160);
    optionalLimit('Short description', value.shortDescription, 500);
    optionalLimit('Long description', value.longDescription, 4000);
    optionalLimit('Discipline', value.discipline, 120);
    optionalLimit('Operating type', value.operatingType, 160);
    optionalLimit('Normal state', value.normalState, 160);
    optionalLimit('Fail state', value.failState, 160);
    optionalLimit('Manufacturer', value.manufacturer, 160);
    optionalLimit('Model', value.model, 160);
    optionalLimit('Applicability', value.applicability, 500);
    optionalLimit('Source reference', value.sourceReference, 500);
    optionalLimit('Owner discipline', value.ownerDiscipline, 120);
    validateAssetOwnership(
      errors,
      value.ownershipStatus,
      value.ownerDiscipline,
      value.accountableRoleKeys,
    );
    if (value.sortOrder < 0 || value.sortOrder > 999999) {
      errors.add('Sort order must be between 0 and 999,999.');
    }
    return errors;
  }
}

void validateAssetOwnership(
  List<String> errors,
  AssetOwnershipStatus status,
  String? discipline,
  List<String> roles,
) {
  if (roles.length > 10 || roles.any((role) => role.length > 80)) {
    errors.add('Use at most 10 valid accountable roles.');
  }
  switch (status) {
    case AssetOwnershipStatus.unassigned:
      if (discipline != null || roles.isNotEmpty) {
        errors.add(
          'Unassigned ownership cannot carry an owner discipline or accountable roles.',
        );
      }
    case AssetOwnershipStatus.provisional:
      if (discipline == null && roles.isEmpty) {
        errors.add(
          'Provisional ownership requires an owner discipline or accountable role.',
        );
      }
    case AssetOwnershipStatus.confirmed:
      if (discipline == null || roles.isEmpty) {
        errors.add(
          'Confirmed ownership requires an owner discipline and at least one accountable role.',
        );
      }
  }
}

void requireValidPersistedAssetOwnership(
  AssetOwnershipStatus status,
  String? discipline,
  List<String> roles, {
  String? source,
}) {
  final errors = <String>[];
  validateAssetOwnership(errors, status, discipline, roles);
  if (errors.isNotEmpty) {
    throw PersistedDataFormatException(
      field: 'ownershipStatus',
      source: source,
      detail: errors.join(' '),
    );
  }
}

class AssetHierarchyNode {
  final String id;
  final String assetClassId;
  final String? parentNodeId;
  final AssetHierarchyNodeType nodeType;
  final String name;
  final String? componentTag;
  final String? shortDescription;
  final String? longDescription;
  final String? discipline;
  final String? operatingType;
  final String? normalState;
  final String? failState;
  final ElectricalContactArrangement contactArrangement;
  final String? manufacturer;
  final String? model;
  final String? applicability;
  final String? sourceReference;
  final AssetOwnershipStatus ownershipStatus;
  final String? ownerDiscipline;
  final List<String> accountableRoleKeys;
  final int sortOrder;
  final List<String> ancestorNodeIds;
  final List<String> hierarchyPath;
  final int activeChildCount;
  final AssetHierarchyStatus status;
  final int version;
  final DateTime createdAt;
  final String createdByUid;
  final String? createdByName;
  final DateTime updatedAt;
  final String updatedByUid;
  final String? updatedByName;
  final String lastMutationId;

  const AssetHierarchyNode({
    required this.id,
    required this.assetClassId,
    this.parentNodeId,
    required this.nodeType,
    required this.name,
    this.componentTag,
    this.shortDescription,
    this.longDescription,
    this.discipline,
    this.operatingType,
    this.normalState,
    this.failState,
    required this.contactArrangement,
    this.manufacturer,
    this.model,
    this.applicability,
    this.sourceReference,
    required this.ownershipStatus,
    this.ownerDiscipline,
    this.accountableRoleKeys = const <String>[],
    required this.sortOrder,
    required this.ancestorNodeIds,
    required this.hierarchyPath,
    required this.activeChildCount,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.createdByUid,
    this.createdByName,
    required this.updatedAt,
    required this.updatedByUid,
    this.updatedByName,
    required this.lastMutationId,
  });

  bool get isActive => status == AssetHierarchyStatus.active;

  AssetHierarchyNodeDraft get draft => AssetHierarchyNodeDraft(
    parentNodeId: parentNodeId,
    nodeType: nodeType,
    name: name,
    componentTag: componentTag,
    shortDescription: shortDescription,
    longDescription: longDescription,
    discipline: discipline,
    operatingType: operatingType,
    normalState: normalState,
    failState: failState,
    contactArrangement: contactArrangement,
    manufacturer: manufacturer,
    model: model,
    applicability: applicability,
    sourceReference: sourceReference,
    ownershipStatus: ownershipStatus,
    ownerDiscipline: ownerDiscipline,
    accountableRoleKeys: accountableRoleKeys,
    sortOrder: sortOrder,
  );

  factory AssetHierarchyNode.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'asset_hierarchy_nodes/$documentId';
    final id = readRequiredPersistedString(
      map['nodeId'],
      field: 'nodeId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'nodeId',
        source: source,
        detail: 'must match the document ID',
      );
    }
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
        detail: 'unsupported hierarchy schema $schemaVersion',
      );
    }
    final record = AssetHierarchyNode(
      id: id,
      assetClassId: readRequiredPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      parentNodeId: readOptionalPersistedString(
        map['parentNodeId'],
        field: 'parentNodeId',
        source: source,
      ),
      nodeType: readRequiredPersistedEnum(
        AssetHierarchyNodeType.values,
        map['nodeType'],
        field: 'nodeType',
        source: source,
      ),
      name: readRequiredPersistedString(
        map['name'],
        field: 'name',
        source: source,
      ),
      componentTag: readOptionalPersistedString(
        map['componentTag'],
        field: 'componentTag',
        source: source,
      ),
      shortDescription: readOptionalPersistedString(
        map['shortDescription'],
        field: 'shortDescription',
        source: source,
      ),
      longDescription: readOptionalPersistedString(
        map['longDescription'],
        field: 'longDescription',
        source: source,
      ),
      discipline: readOptionalPersistedString(
        map['discipline'],
        field: 'discipline',
        source: source,
      ),
      operatingType: readOptionalPersistedString(
        map['operatingType'],
        field: 'operatingType',
        source: source,
      ),
      normalState: readOptionalPersistedString(
        map['normalState'],
        field: 'normalState',
        source: source,
      ),
      failState: readOptionalPersistedString(
        map['failState'],
        field: 'failState',
        source: source,
      ),
      contactArrangement: readRequiredPersistedEnum(
        ElectricalContactArrangement.values,
        map['contactArrangement'],
        field: 'contactArrangement',
        source: source,
      ),
      manufacturer: readOptionalPersistedString(
        map['manufacturer'],
        field: 'manufacturer',
        source: source,
      ),
      model: readOptionalPersistedString(
        map['model'],
        field: 'model',
        source: source,
      ),
      applicability: readOptionalPersistedString(
        map['applicability'],
        field: 'applicability',
        source: source,
      ),
      sourceReference: readOptionalPersistedString(
        map['sourceReference'],
        field: 'sourceReference',
        source: source,
      ),
      ownershipStatus: readRequiredPersistedEnum(
        AssetOwnershipStatus.values,
        map['ownershipStatus'],
        field: 'ownershipStatus',
        source: source,
      ),
      ownerDiscipline: readOptionalPersistedString(
        map['ownerDiscipline'],
        field: 'ownerDiscipline',
        source: source,
      ),
      accountableRoleKeys: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['accountableRoleKeys'],
          field: 'accountableRoleKeys',
          source: source,
        ),
      ),
      sortOrder: readRequiredPersistedInt(
        map['sortOrder'],
        field: 'sortOrder',
        source: source,
        minimum: 0,
      ),
      ancestorNodeIds: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['ancestorNodeIds'],
          field: 'ancestorNodeIds',
          source: source,
        ),
      ),
      hierarchyPath: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['hierarchyPath'],
          field: 'hierarchyPath',
          source: source,
        ),
      ),
      activeChildCount: readRequiredPersistedInt(
        map['activeChildCount'],
        field: 'activeChildCount',
        source: source,
        minimum: 0,
      ),
      status: readRequiredPersistedEnum(
        AssetHierarchyStatus.values,
        map['status'],
        field: 'status',
        source: source,
      ),
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
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
      createdByName: readOptionalPersistedString(
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
      updatedByName: readOptionalPersistedString(
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
    requireValidPersistedAssetOwnership(
      record.ownershipStatus,
      record.ownerDiscipline,
      record.accountableRoleKeys,
      source: source,
    );
    return record;
  }

  Map<String, dynamic> auditSnapshot() => <String, dynamic>{
    'nodeId': id,
    'assetClassId': assetClassId,
    'parentNodeId': parentNodeId,
    'nodeType': nodeType.name,
    'name': name,
    'componentTag': componentTag,
    'shortDescription': shortDescription,
    'longDescription': longDescription,
    'discipline': discipline,
    'operatingType': operatingType,
    'normalState': normalState,
    'failState': failState,
    'contactArrangement': contactArrangement.name,
    'manufacturer': manufacturer,
    'model': model,
    'applicability': applicability,
    'sourceReference': sourceReference,
    'ownershipStatus': ownershipStatus.name,
    'ownerDiscipline': ownerDiscipline,
    'accountableRoleKeys': accountableRoleKeys,
    'sortOrder': sortOrder,
    'ancestorNodeIds': ancestorNodeIds,
    'hierarchyPath': hierarchyPath,
    'activeChildCount': activeChildCount,
    'status': status.name,
    'version': version,
  };
}

class AssetHierarchyTree {
  final List<AssetHierarchyNode> roots;
  final Map<String?, List<AssetHierarchyNode>> childrenByParent;
  final List<String> integrityErrors;

  const AssetHierarchyTree({
    required this.roots,
    required this.childrenByParent,
    required this.integrityErrors,
  });

  factory AssetHierarchyTree.build(List<AssetHierarchyNode> nodes) {
    final byId = <String, AssetHierarchyNode>{};
    final children = <String?, List<AssetHierarchyNode>>{};
    final errors = <String>[];
    for (final node in nodes) {
      if (byId.containsKey(node.id)) {
        errors.add('Duplicate node ID ${node.id}.');
      }
      byId[node.id] = node;
      children
          .putIfAbsent(node.parentNodeId, () => <AssetHierarchyNode>[])
          .add(node);
    }
    for (final node in nodes) {
      final parentId = node.parentNodeId;
      if (parentId != null && !byId.containsKey(parentId)) {
        errors.add('${node.name} references missing parent $parentId.');
      }
      final seen = <String>{node.id};
      var cursor = parentId;
      var depth = 0;
      while (cursor != null) {
        if (!seen.add(cursor)) {
          errors.add('Cycle detected at ${node.name}.');
          break;
        }
        cursor = byId[cursor]?.parentNodeId;
        depth++;
        if (depth > 8) {
          errors.add('${node.name} exceeds the maximum hierarchy depth of 8.');
          break;
        }
      }
    }
    int compare(AssetHierarchyNode left, AssetHierarchyNode right) =>
        left.sortOrder.compareTo(right.sortOrder) != 0
            ? left.sortOrder.compareTo(right.sortOrder)
            : left.name.toLowerCase().compareTo(right.name.toLowerCase());
    for (final siblings in children.values) {
      siblings.sort(compare);
    }
    return AssetHierarchyTree(
      roots: List<AssetHierarchyNode>.unmodifiable(
        children[null] ?? const <AssetHierarchyNode>[],
      ),
      childrenByParent: Map<String?, List<AssetHierarchyNode>>.unmodifiable(
        children.map(
          (key, value) =>
              MapEntry(key, List<AssetHierarchyNode>.unmodifiable(value)),
        ),
      ),
      integrityErrors: List<String>.unmodifiable(errors.toSet()),
    );
  }

  List<AssetHierarchyNode> childrenOf(String? parentId) =>
      childrenByParent[parentId] ?? const <AssetHierarchyNode>[];
}
