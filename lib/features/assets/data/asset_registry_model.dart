import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import 'asset_hierarchy_model.dart';

class AssetTagClaimRecord {
  final String id;
  final String normalizedTag;
  final String displayTag;
  final String componentInstanceId;
  final String definitionNodeId;
  final String definitionName;
  final String assetInstanceId;
  final String assetInstanceName;
  final int assetNumber;
  final String assetClassId;
  final String assetClassName;
  final List<String> hierarchyPath;
  final AssetOwnershipStatus ownershipStatus;
  final String? ownerDiscipline;
  final List<String> accountableRoleKeys;
  final DateTime claimedAt;
  final String claimedByUid;
  final String lastMutationId;

  const AssetTagClaimRecord({
    required this.id,
    required this.normalizedTag,
    required this.displayTag,
    required this.componentInstanceId,
    required this.definitionNodeId,
    required this.definitionName,
    required this.assetInstanceId,
    required this.assetInstanceName,
    required this.assetNumber,
    required this.assetClassId,
    required this.assetClassName,
    required this.hierarchyPath,
    required this.ownershipStatus,
    this.ownerDiscipline,
    required this.accountableRoleKeys,
    required this.claimedAt,
    required this.claimedByUid,
    required this.lastMutationId,
  });

  factory AssetTagClaimRecord.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'asset_tag_claims/$documentId';
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    if (schemaVersion != 2) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail:
            'unsupported installed-component tag-claim schema $schemaVersion',
      );
    }
    final ownerType = readRequiredPersistedString(
      map['ownerType'],
      field: 'ownerType',
      source: source,
    );
    if (ownerType != 'installed_component') {
      throw PersistedDataFormatException(
        field: 'ownerType',
        source: source,
        detail: 'must identify an installed component',
      );
    }
    final normalizedTag = readRequiredPersistedString(
      map['normalizedTag'],
      field: 'normalizedTag',
      source: source,
    );
    if (normalizeAssetComponentTag(normalizedTag) != normalizedTag ||
        sha256.convert(utf8.encode(normalizedTag)).toString() != documentId) {
      throw PersistedDataFormatException(
        field: 'normalizedTag',
        source: source,
        detail: 'must be canonical and match the tag-claim document ID',
      );
    }
    final record = AssetTagClaimRecord(
      id: documentId,
      normalizedTag: normalizedTag,
      displayTag: readRequiredPersistedString(
        map['displayTag'],
        field: 'displayTag',
        source: source,
      ),
      componentInstanceId: readRequiredPersistedString(
        map['componentInstanceId'],
        field: 'componentInstanceId',
        source: source,
      ),
      definitionNodeId: readRequiredPersistedString(
        map['definitionNodeId'],
        field: 'definitionNodeId',
        source: source,
      ),
      definitionName: readRequiredPersistedString(
        map['definitionName'],
        field: 'definitionName',
        source: source,
      ),
      assetInstanceId: readRequiredPersistedString(
        map['assetInstanceId'],
        field: 'assetInstanceId',
        source: source,
      ),
      assetInstanceName: readRequiredPersistedString(
        map['assetInstanceName'],
        field: 'assetInstanceName',
        source: source,
      ),
      assetNumber: readRequiredPersistedInt(
        map['assetNumber'],
        field: 'assetNumber',
        source: source,
        minimum: 1,
      ),
      assetClassId: readRequiredPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      assetClassName: readRequiredPersistedString(
        map['assetClassName'],
        field: 'assetClassName',
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
      claimedAt: readRequiredPersistedDateTime(
        map['claimedAt'],
        field: 'claimedAt',
        source: source,
      ),
      claimedByUid: readRequiredPersistedString(
        map['claimedByUid'],
        field: 'claimedByUid',
        source: source,
      ),
      lastMutationId: readRequiredPersistedString(
        map['lastMutationId'],
        field: 'lastMutationId',
        source: source,
      ),
    );
    if (record.ownershipStatus != AssetOwnershipStatus.confirmed) {
      throw PersistedDataFormatException(
        field: 'ownershipStatus',
        source: source,
        detail: 'an active installed-component tag claim must be confirmed',
      );
    }
    if (normalizeAssetComponentTag(record.displayTag) != normalizedTag) {
      throw PersistedDataFormatException(
        field: 'displayTag',
        source: source,
        detail: 'must normalize to the claimed tag',
      );
    }
    requireValidPersistedAssetOwnership(
      record.ownershipStatus,
      record.ownerDiscipline,
      record.accountableRoleKeys,
      source: source,
    );
    return record;
  }
}

enum AssetServiceState {
  inService,
  standby,
  outOfService;

  String get label => switch (this) {
    inService => 'In service',
    standby => 'Standby',
    outOfService => 'Out of service',
  };
}

class AssetInstanceDraft {
  final int assetNumber;
  final String name;
  final String? plantTag;
  final String? location;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final DateTime? commissionedOn;
  final AssetServiceState serviceState;
  final AssetOwnershipStatus ownershipStatus;
  final String? ownerDiscipline;
  final List<String> accountableRoleKeys;

  const AssetInstanceDraft({
    required this.assetNumber,
    required this.name,
    this.plantTag,
    this.location,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.commissionedOn,
    this.serviceState = AssetServiceState.inService,
    this.ownershipStatus = AssetOwnershipStatus.unassigned,
    this.ownerDiscipline,
    this.accountableRoleKeys = const <String>[],
  });

  AssetInstanceDraft normalized() => AssetInstanceDraft(
    assetNumber: assetNumber,
    name: name.trim(),
    plantTag: cleanHierarchyText(plantTag),
    location: cleanHierarchyText(location),
    manufacturer: cleanHierarchyText(manufacturer),
    model: cleanHierarchyText(model),
    serialNumber: cleanHierarchyText(serialNumber),
    commissionedOn: commissionedOn,
    serviceState: serviceState,
    ownershipStatus: ownershipStatus,
    ownerDiscipline: cleanHierarchyText(ownerDiscipline),
    accountableRoleKeys: _normalizedRoles(accountableRoleKeys),
  );

  List<String> validate() {
    final value = normalized();
    final errors = <String>[];
    if (value.assetNumber < 1 || value.assetNumber > 9999) {
      errors.add('Asset number must be between 1 and 9,999.');
    }
    if (value.name.isEmpty || value.name.length > 160) {
      errors.add('Asset name must contain 1-160 characters.');
    }
    _optionalLimit(errors, 'Plant tag', value.plantTag, 160);
    _optionalLimit(errors, 'Location', value.location, 240);
    _optionalLimit(errors, 'Manufacturer', value.manufacturer, 160);
    _optionalLimit(errors, 'Model', value.model, 160);
    _optionalLimit(errors, 'Serial number', value.serialNumber, 160);
    validateAssetOwnership(
      errors,
      value.ownershipStatus,
      value.ownerDiscipline,
      value.accountableRoleKeys,
    );
    return errors;
  }
}

class AssetInstanceRecord {
  final String id;
  final String assetClassId;
  final String assetClassCode;
  final String assetClassName;
  final int assetNumber;
  final String name;
  final String? plantTag;
  final String? location;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final DateTime? commissionedOn;
  final AssetServiceState serviceState;
  final AssetOwnershipStatus ownershipStatus;
  final String? ownerDiscipline;
  final List<String> accountableRoleKeys;
  final AssetHierarchyStatus status;
  final int activeComponentCount;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMutationId;

  const AssetInstanceRecord({
    required this.id,
    required this.assetClassId,
    required this.assetClassCode,
    required this.assetClassName,
    required this.assetNumber,
    required this.name,
    this.plantTag,
    this.location,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.commissionedOn,
    required this.serviceState,
    required this.ownershipStatus,
    this.ownerDiscipline,
    this.accountableRoleKeys = const <String>[],
    required this.status,
    required this.activeComponentCount,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMutationId,
  });

  bool get isActive => status == AssetHierarchyStatus.active;

  AssetInstanceDraft get draft => AssetInstanceDraft(
    assetNumber: assetNumber,
    name: name,
    plantTag: plantTag,
    location: location,
    manufacturer: manufacturer,
    model: model,
    serialNumber: serialNumber,
    commissionedOn: commissionedOn,
    serviceState: serviceState,
    ownershipStatus: ownershipStatus,
    ownerDiscipline: ownerDiscipline,
    accountableRoleKeys: accountableRoleKeys,
  );

  factory AssetInstanceRecord.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'asset_instances/$documentId';
    final id = readRequiredPersistedString(
      map['assetInstanceId'],
      field: 'assetInstanceId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'assetInstanceId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    _requireSchema(map, source);
    final record = AssetInstanceRecord(
      id: id,
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
      name: readRequiredPersistedString(
        map['name'],
        field: 'name',
        source: source,
      ),
      plantTag: readOptionalPersistedString(
        map['plantTag'],
        field: 'plantTag',
        source: source,
      ),
      location: readOptionalPersistedString(
        map['location'],
        field: 'location',
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
      serialNumber: readOptionalPersistedString(
        map['serialNumber'],
        field: 'serialNumber',
        source: source,
      ),
      commissionedOn: readOptionalPersistedDateTime(
        map['commissionedOn'],
        field: 'commissionedOn',
        source: source,
      ),
      serviceState: readRequiredPersistedEnum(
        AssetServiceState.values,
        map['serviceState'],
        field: 'serviceState',
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
      status: readRequiredPersistedEnum(
        AssetHierarchyStatus.values,
        map['status'],
        field: 'status',
        source: source,
      ),
      activeComponentCount: readRequiredPersistedInt(
        map['activeComponentCount'],
        field: 'activeComponentCount',
        source: source,
        minimum: 0,
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
      updatedAt: readRequiredPersistedDateTime(
        map['updatedAt'],
        field: 'updatedAt',
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
}

class InstalledComponentDraft {
  final String definitionNodeId;
  final String? componentTag;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final DateTime? installedOn;
  final AssetServiceState serviceState;
  final AssetOwnershipStatus ownershipStatus;
  final String? ownerDiscipline;
  final List<String> accountableRoleKeys;

  const InstalledComponentDraft({
    required this.definitionNodeId,
    this.componentTag,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.installedOn,
    this.serviceState = AssetServiceState.inService,
    this.ownershipStatus = AssetOwnershipStatus.unassigned,
    this.ownerDiscipline,
    this.accountableRoleKeys = const <String>[],
  });

  InstalledComponentDraft normalized() => InstalledComponentDraft(
    definitionNodeId: definitionNodeId.trim(),
    componentTag: cleanHierarchyText(componentTag),
    manufacturer: cleanHierarchyText(manufacturer),
    model: cleanHierarchyText(model),
    serialNumber: cleanHierarchyText(serialNumber),
    installedOn: installedOn,
    serviceState: serviceState,
    ownershipStatus: ownershipStatus,
    ownerDiscipline: cleanHierarchyText(ownerDiscipline),
    accountableRoleKeys: _normalizedRoles(accountableRoleKeys),
  );

  List<String> validate() {
    final value = normalized();
    final errors = <String>[];
    if (value.definitionNodeId.isEmpty) {
      errors.add('Select a component definition.');
    }
    _optionalLimit(errors, 'Component tag', value.componentTag, 160);
    if (value.componentTag != null &&
        normalizeAssetComponentTag(value.componentTag!).isEmpty) {
      errors.add('Component tag must contain letters or numbers.');
    }
    _optionalLimit(errors, 'Manufacturer', value.manufacturer, 160);
    _optionalLimit(errors, 'Model', value.model, 160);
    _optionalLimit(errors, 'Serial number', value.serialNumber, 160);
    validateAssetOwnership(
      errors,
      value.ownershipStatus,
      value.ownerDiscipline,
      value.accountableRoleKeys,
    );
    return errors;
  }
}

class InstalledComponentRecord {
  final String id;
  final String assetInstanceId;
  final int assetInstanceVersionAtMutation;
  final int assetNumber;
  final String assetInstanceName;
  final String assetClassId;
  final String assetClassCode;
  final String assetClassName;
  final String definitionNodeId;
  final int definitionNodeVersion;
  final String definitionName;
  final List<String> hierarchyPath;
  final String? componentTag;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final DateTime? installedOn;
  final AssetServiceState serviceState;
  final AssetOwnershipStatus ownershipStatus;
  final String? ownerDiscipline;
  final List<String> accountableRoleKeys;
  final AssetHierarchyStatus status;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMutationId;

  const InstalledComponentRecord({
    required this.id,
    required this.assetInstanceId,
    required this.assetInstanceVersionAtMutation,
    required this.assetNumber,
    required this.assetInstanceName,
    required this.assetClassId,
    required this.assetClassCode,
    required this.assetClassName,
    required this.definitionNodeId,
    required this.definitionNodeVersion,
    required this.definitionName,
    required this.hierarchyPath,
    this.componentTag,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.installedOn,
    required this.serviceState,
    required this.ownershipStatus,
    this.ownerDiscipline,
    this.accountableRoleKeys = const <String>[],
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMutationId,
  });

  bool get isActive => status == AssetHierarchyStatus.active;

  InstalledComponentDraft get draft => InstalledComponentDraft(
    definitionNodeId: definitionNodeId,
    componentTag: componentTag,
    manufacturer: manufacturer,
    model: model,
    serialNumber: serialNumber,
    installedOn: installedOn,
    serviceState: serviceState,
    ownershipStatus: ownershipStatus,
    ownerDiscipline: ownerDiscipline,
    accountableRoleKeys: accountableRoleKeys,
  );

  AssetHierarchyReference toReference() => AssetHierarchyReference(
    scope: AssetHierarchyReferenceScope.installedComponent,
    assetClassId: assetClassId,
    assetClassCode: assetClassCode,
    assetClassName: assetClassName,
    nodeId: definitionNodeId,
    nodeVersion: definitionNodeVersion,
    nodeName: definitionName,
    assetInstanceId: assetInstanceId,
    assetInstanceVersion: assetInstanceVersionAtMutation,
    assetNumber: assetNumber,
    assetInstanceName: assetInstanceName,
    componentInstanceId: id,
    componentInstanceVersion: version,
    componentTag: componentTag,
    hierarchyPath: hierarchyPath,
    ownershipStatus: ownershipStatus,
    ownerDiscipline: ownerDiscipline,
    accountableRoleKeys: accountableRoleKeys,
  );

  factory InstalledComponentRecord.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'asset_component_instances/$documentId';
    final id = readRequiredPersistedString(
      map['componentInstanceId'],
      field: 'componentInstanceId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'componentInstanceId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    _requireSchema(map, source);
    final record = InstalledComponentRecord(
      id: id,
      assetInstanceId: readRequiredPersistedString(
        map['assetInstanceId'],
        field: 'assetInstanceId',
        source: source,
      ),
      assetInstanceVersionAtMutation: readRequiredPersistedInt(
        map['assetInstanceVersionAtMutation'],
        field: 'assetInstanceVersionAtMutation',
        source: source,
        minimum: 1,
      ),
      assetNumber: readRequiredPersistedInt(
        map['assetNumber'],
        field: 'assetNumber',
        source: source,
        minimum: 1,
      ),
      assetInstanceName: readRequiredPersistedString(
        map['assetInstanceName'],
        field: 'assetInstanceName',
        source: source,
      ),
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
      definitionNodeId: readRequiredPersistedString(
        map['definitionNodeId'],
        field: 'definitionNodeId',
        source: source,
      ),
      definitionNodeVersion: readRequiredPersistedInt(
        map['definitionNodeVersion'],
        field: 'definitionNodeVersion',
        source: source,
        minimum: 1,
      ),
      definitionName: readRequiredPersistedString(
        map['definitionName'],
        field: 'definitionName',
        source: source,
      ),
      hierarchyPath: List<String>.unmodifiable(
        readOptionalPersistedStringList(
          map['hierarchyPath'],
          field: 'hierarchyPath',
          source: source,
        ),
      ),
      componentTag: readOptionalPersistedString(
        map['componentTag'],
        field: 'componentTag',
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
      serialNumber: readOptionalPersistedString(
        map['serialNumber'],
        field: 'serialNumber',
        source: source,
      ),
      installedOn: readOptionalPersistedDateTime(
        map['installedOn'],
        field: 'installedOn',
        source: source,
      ),
      serviceState: readRequiredPersistedEnum(
        AssetServiceState.values,
        map['serviceState'],
        field: 'serviceState',
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
      updatedAt: readRequiredPersistedDateTime(
        map['updatedAt'],
        field: 'updatedAt',
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
}

void _requireSchema(Map<String, dynamic> map, String source) {
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
      detail: 'unsupported asset registry schema $schemaVersion',
    );
  }
}

List<String> _normalizedRoles(List<String> roles) =>
    roles
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

void _optionalLimit(
  List<String> errors,
  String label,
  String? value,
  int maximum,
) {
  if ((value?.length ?? 0) > maximum) {
    errors.add('$label cannot exceed $maximum characters.');
  }
}
