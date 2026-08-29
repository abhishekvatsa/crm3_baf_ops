import '../../../core/serialization/persisted_data_reader.dart';

enum InnerCoverLifecycleState {
  available,
  reserved,
  installed,
  awaitingInspection,
  underInspection,
  underRepair,
  underFabrication,
  quarantined,
  rejected,
  retiredForSalvage,
  partiallyDismantled,
  fullyConsumedAsDonor,
  disposed;

  String get label => switch (this) {
    available => 'Available',
    reserved => 'Reserved',
    installed => 'Installed',
    awaitingInspection => 'Awaiting inspection',
    underInspection => 'Under inspection',
    underRepair => 'Under repair',
    underFabrication => 'Under fabrication',
    quarantined => 'Quarantined',
    rejected => 'Rejected',
    retiredForSalvage => 'Retired for salvage',
    partiallyDismantled => 'Partially dismantled',
    fullyConsumedAsDonor => 'Fully consumed as donor',
    disposed => 'Disposed',
  };
}

enum InnerCoverRetirementCondition { bulged, notBulged }

extension InnerCoverRetirementConditionLabel on InnerCoverRetirementCondition {
  String get label => switch (this) {
    InnerCoverRetirementCondition.bulged => 'Bulged',
    InnerCoverRetirementCondition.notBulged => 'Not bulged',
  };
}

enum InnerCoverSourceType {
  purchased,
  fabricated,
  legacyExisting;

  String get label => switch (this) {
    purchased => 'Purchased',
    fabricated => 'Fabricated',
    legacyExisting => 'Existing legacy cover',
  };
}

enum InnerCoverOriginClassification {
  documentedPurchase,
  documentedFabrication,
  ownerDeclaredNew,
  ownerDeclaredFabricated,
  legacyUndocumented;

  String get label => switch (this) {
    documentedPurchase => 'Purchased · documented',
    documentedFabrication => 'Fabricated · documented',
    ownerDeclaredNew => 'New · owner-declared',
    ownerDeclaredFabricated => 'Fabricated · owner-declared',
    legacyUndocumented => 'Existing · origin undocumented',
  };
}

InnerCoverOriginClassification _legacyOriginClassification(
  InnerCoverSourceType sourceType,
  InnerCoverTraceabilityGrade traceabilityGrade,
) => switch (sourceType) {
  InnerCoverSourceType.purchased =>
    InnerCoverOriginClassification.documentedPurchase,
  InnerCoverSourceType.fabricated =>
    traceabilityGrade == InnerCoverTraceabilityGrade.t0
        ? InnerCoverOriginClassification.ownerDeclaredFabricated
        : InnerCoverOriginClassification.documentedFabrication,
  InnerCoverSourceType.legacyExisting =>
    InnerCoverOriginClassification.legacyUndocumented,
};

bool _originMatchesSource(
  InnerCoverOriginClassification origin,
  InnerCoverSourceType sourceType,
) => switch (origin) {
  InnerCoverOriginClassification.documentedPurchase =>
    sourceType == InnerCoverSourceType.purchased,
  InnerCoverOriginClassification.documentedFabrication ||
  InnerCoverOriginClassification
      .ownerDeclaredFabricated => sourceType == InnerCoverSourceType.fabricated,
  InnerCoverOriginClassification.ownerDeclaredNew ||
  InnerCoverOriginClassification
      .legacyUndocumented => sourceType == InnerCoverSourceType.legacyExisting,
};

enum InnerCoverTraceabilityGrade {
  t0,
  t1,
  t2,
  t3;

  String get storageKey => name.toUpperCase();

  String get label => switch (this) {
    t0 => 'T0 · unknown legacy ancestry',
    t1 => 'T1 · limited reconstructed trace',
    t2 => 'T2 · known mixed-source trace',
    t3 => 'T3 · complete new-material trace',
  };
}

DateTime innerCoverIncorporationInstantForLocalDate(DateTime selectedDate) =>
    DateTime(selectedDate.year, selectedDate.month, selectedDate.day).toUtc();

InnerCoverTraceabilityGrade _readTraceabilityGrade(
  dynamic value, {
  required String source,
}) {
  if (value is String) {
    for (final grade in InnerCoverTraceabilityGrade.values) {
      if (grade.storageKey == value) return grade;
    }
  }
  throw PersistedDataFormatException(
    field: 'traceabilityGrade',
    source: source,
    detail: 'unknown traceability grade "$value"',
  );
}

enum InnerCoverFabricationSectionType {
  lowerAssembly,
  flatVertical,
  corrugatedShell,
  topCover,
  catchRing,
  liftingRing,
  guideArms,
  other;

  String get label => switch (this) {
    lowerAssembly => 'Lower / water-jacket assembly',
    flatVertical => 'Flat SS vertical / transition',
    corrugatedShell => 'Corrugated shell',
    topCover => 'Top cover / crown',
    catchRing => 'Catch ring',
    liftingRing => 'Lifting ring',
    guideArms => 'Guide arms',
    other => 'Other section',
  };
}

enum InnerCoverSectionMaterialSource {
  newPurchased,
  newFabricated,
  reusedKnownDonor,
  reusedUnknownLegacyDonor;

  String get label => switch (this) {
    newPurchased => 'New purchased material',
    newFabricated => 'New fabricated material',
    reusedKnownDonor => 'Reused, known donor',
    reusedUnknownLegacyDonor => 'Reused, unknown legacy donor',
  };
}

String normalizeInnerCoverSerial(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');

class InnerCoverFabricationSectionDraft {
  final InnerCoverFabricationSectionType type;
  final InnerCoverSectionMaterialSource materialSource;
  final InnerCoverProfile? donor;
  final String? donorSectionKey;
  final double? lengthMm;
  final int cutCount;
  final String? notes;

  const InnerCoverFabricationSectionDraft({
    required this.type,
    required this.materialSource,
    this.donor,
    this.donorSectionKey,
    this.lengthMm,
    this.cutCount = 1,
    this.notes,
  });

  List<String> validate() {
    final errors = <String>[];
    final knownDonor =
        materialSource == InnerCoverSectionMaterialSource.reusedKnownDonor;
    if (knownDonor &&
        (donor == null || (donorSectionKey?.trim().isEmpty ?? true))) {
      errors.add('${type.label}: choose the donor and identify its section.');
    }
    if (!knownDonor && (donor != null || donorSectionKey != null)) {
      errors.add(
        '${type.label}: donor details are not allowed for this source.',
      );
    }
    if (lengthMm != null &&
        (!lengthMm!.isFinite || lengthMm! <= 0 || lengthMm! > 100000)) {
      errors.add('${type.label}: length must be greater than zero.');
    }
    if (cutCount < 1 || cutCount > 100) {
      errors.add('${type.label}: cut count must be between 1 and 100.');
    }
    if ((notes?.trim().length ?? 0) > 1000) {
      errors.add('${type.label}: notes cannot exceed 1,000 characters.');
    }
    return errors;
  }
}

void _requireSchema(Map<String, dynamic> map, String source) {
  final schema = readRequiredPersistedInt(
    map['schemaVersion'],
    field: 'schemaVersion',
    source: source,
    minimum: 1,
  );
  if (schema != 1) {
    throw PersistedDataFormatException(
      field: 'schemaVersion',
      source: source,
      detail: 'unsupported Inner Cover schema $schema',
    );
  }
}

class InnerCoverProfile {
  final String id;
  final String assetClassId;
  final String assetClassCode;
  final String assetClassName;
  final String serialNumber;
  final String normalizedSerialNumber;
  final InnerCoverSourceType sourceType;
  final InnerCoverOriginClassification originClassification;
  final InnerCoverLifecycleState lifecycleState;
  final InnerCoverRetirementCondition? retirementCondition;
  final InnerCoverTraceabilityGrade traceabilityGrade;
  final String? supplierOrFabricator;
  final DateTime? receivedOrCompletedOn;
  final DateTime? incorporatedOn;
  final String? drawingReference;
  final String? materialGrade;
  final String? acceptanceReference;
  final DateTime? acceptedAt;
  final String? acceptedByUid;
  final String? acceptedByName;
  final String? currentBaseAssetInstanceId;
  final int? currentBaseAssetNumber;
  final String? currentBaseAssetName;
  final String? currentLinkageId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMutationId;

  const InnerCoverProfile({
    required this.id,
    required this.assetClassId,
    required this.assetClassCode,
    required this.assetClassName,
    required this.serialNumber,
    required this.normalizedSerialNumber,
    required this.sourceType,
    this.originClassification =
        InnerCoverOriginClassification.legacyUndocumented,
    required this.lifecycleState,
    this.retirementCondition,
    required this.traceabilityGrade,
    this.supplierOrFabricator,
    this.receivedOrCompletedOn,
    this.incorporatedOn,
    this.drawingReference,
    this.materialGrade,
    this.acceptanceReference,
    this.acceptedAt,
    this.acceptedByUid,
    this.acceptedByName,
    this.currentBaseAssetInstanceId,
    this.currentBaseAssetNumber,
    this.currentBaseAssetName,
    this.currentLinkageId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMutationId,
  });

  bool get isInstalled => lifecycleState == InnerCoverLifecycleState.installed;
  bool get isAvailable => lifecycleState == InnerCoverLifecycleState.available;

  factory InnerCoverProfile.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'inner_cover_profiles/$documentId';
    _requireSchema(map, source);
    final id = readRequiredPersistedString(
      map['innerCoverId'],
      field: 'innerCoverId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'innerCoverId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final serial = readRequiredPersistedString(
      map['serialNumber'],
      field: 'serialNumber',
      source: source,
    );
    final normalized = readRequiredPersistedString(
      map['normalizedSerialNumber'],
      field: 'normalizedSerialNumber',
      source: source,
    );
    if (normalized != normalizeInnerCoverSerial(serial)) {
      throw PersistedDataFormatException(
        field: 'normalizedSerialNumber',
        source: source,
        detail: 'must match the normalized serial number',
      );
    }
    final state = readRequiredPersistedEnum(
      InnerCoverLifecycleState.values,
      map['lifecycleState'],
      field: 'lifecycleState',
      source: source,
    );
    final retirementCondition = readOptionalPersistedEnum(
      InnerCoverRetirementCondition.values,
      map['retirementCondition'],
      field: 'retirementCondition',
      source: source,
    );
    final retirementEvidenceAllowed = const <InnerCoverLifecycleState>{
      InnerCoverLifecycleState.retiredForSalvage,
      InnerCoverLifecycleState.partiallyDismantled,
      InnerCoverLifecycleState.fullyConsumedAsDonor,
      InnerCoverLifecycleState.disposed,
    }.contains(state);
    if (retirementCondition != null && !retirementEvidenceAllowed) {
      throw PersistedDataFormatException(
        field: 'retirementCondition',
        source: source,
        detail: 'is allowed only after retirement for salvage',
      );
    }
    final sourceType = readRequiredPersistedEnum(
      InnerCoverSourceType.values,
      map['sourceType'],
      field: 'sourceType',
      source: source,
    );
    final baseId = readOptionalPersistedString(
      map['currentBaseAssetInstanceId'],
      field: 'currentBaseAssetInstanceId',
      source: source,
    );
    final baseNumber = readOptionalPersistedInt(
      map['currentBaseAssetNumber'],
      field: 'currentBaseAssetNumber',
      source: source,
      minimum: 1,
    );
    final baseName = readOptionalPersistedString(
      map['currentBaseAssetName'],
      field: 'currentBaseAssetName',
      source: source,
    );
    final linkageId = readOptionalPersistedString(
      map['currentLinkageId'],
      field: 'currentLinkageId',
      source: source,
    );
    final completeProjection =
        baseId != null &&
        baseNumber != null &&
        baseName != null &&
        linkageId != null;
    final absentProjection =
        baseId == null &&
        baseNumber == null &&
        baseName == null &&
        linkageId == null;
    if ((state == InnerCoverLifecycleState.installed && !completeProjection) ||
        (state != InnerCoverLifecycleState.installed && !absentProjection)) {
      throw PersistedDataFormatException(
        field: 'currentBaseAssetInstanceId',
        source: source,
        detail: 'the complete Base projection is required together or absent',
      );
    }
    final receivedOrCompletedOn = readOptionalPersistedDateTime(
      map['receivedOrCompletedOn'],
      field: 'receivedOrCompletedOn',
      source: source,
    );
    final incorporatedOn = readOptionalPersistedDateTime(
      map['incorporatedOn'],
      field: 'incorporatedOn',
      source: source,
    );
    final traceabilityGrade = _readTraceabilityGrade(
      map['traceabilityGrade'],
      source: source,
    );
    final originClassification =
        map['originClassification'] == null
            ? _legacyOriginClassification(sourceType, traceabilityGrade)
            : readRequiredPersistedEnum(
              InnerCoverOriginClassification.values,
              map['originClassification'],
              field: 'originClassification',
              source: source,
            );
    if (!_originMatchesSource(originClassification, sourceType)) {
      throw PersistedDataFormatException(
        field: 'originClassification',
        source: source,
        detail: 'does not match sourceType',
      );
    }
    final traceabilityMatchesOrigin = switch (originClassification) {
      InnerCoverOriginClassification.documentedPurchase =>
        traceabilityGrade == InnerCoverTraceabilityGrade.t3,
      InnerCoverOriginClassification.documentedFabrication => const {
        InnerCoverTraceabilityGrade.t2,
        InnerCoverTraceabilityGrade.t3,
      }.contains(traceabilityGrade),
      InnerCoverOriginClassification.ownerDeclaredNew =>
        traceabilityGrade == InnerCoverTraceabilityGrade.t1,
      InnerCoverOriginClassification.ownerDeclaredFabricated ||
      InnerCoverOriginClassification.legacyUndocumented =>
        traceabilityGrade == InnerCoverTraceabilityGrade.t0,
    };
    if (!traceabilityMatchesOrigin) {
      throw PersistedDataFormatException(
        field: 'traceabilityGrade',
        source: source,
        detail: 'does not match originClassification',
      );
    }
    final acceptanceReference = readOptionalPersistedString(
      map['acceptanceReference'],
      field: 'acceptanceReference',
      source: source,
    );
    final acceptedAt = readOptionalPersistedDateTime(
      map['acceptedAt'],
      field: 'acceptedAt',
      source: source,
    );
    final acceptedByUid = readOptionalPersistedString(
      map['acceptedByUid'],
      field: 'acceptedByUid',
      source: source,
    );
    final acceptedByName = readOptionalPersistedString(
      map['acceptedByName'],
      field: 'acceptedByName',
      source: source,
    );
    final acceptanceValues = <Object?>[
      acceptanceReference,
      acceptedAt,
      acceptedByUid,
      acceptedByName,
    ];
    final completeAcceptance = acceptanceValues.every((value) => value != null);
    final absentAcceptance = acceptanceValues.every((value) => value == null);
    final acceptedState = <InnerCoverLifecycleState>{
      InnerCoverLifecycleState.available,
      InnerCoverLifecycleState.reserved,
      InnerCoverLifecycleState.installed,
    }.contains(state);
    if ((!completeAcceptance && !absentAcceptance) ||
        (acceptedState && !completeAcceptance)) {
      throw PersistedDataFormatException(
        field: 'acceptanceReference',
        source: source,
        detail: 'acceptance evidence must be complete together',
      );
    }
    final createdAt = readRequiredPersistedDateTime(
      map['createdAt'],
      field: 'createdAt',
      source: source,
    );
    final updatedAt = readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    );
    if (createdAt.isAfter(updatedAt) ||
        (receivedOrCompletedOn?.isAfter(updatedAt) ?? false) ||
        (incorporatedOn?.isAfter(updatedAt) ?? false) ||
        (receivedOrCompletedOn != null &&
            incorporatedOn != null &&
            receivedOrCompletedOn.isAfter(incorporatedOn)) ||
        (acceptedAt?.isAfter(updatedAt) ?? false) ||
        (receivedOrCompletedOn != null &&
            acceptedAt != null &&
            receivedOrCompletedOn.isAfter(acceptedAt))) {
      throw PersistedDataFormatException(
        field: 'updatedAt',
        source: source,
        detail: 'profile chronology is inconsistent',
      );
    }
    return InnerCoverProfile(
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
      serialNumber: serial,
      normalizedSerialNumber: normalized,
      sourceType: sourceType,
      originClassification: originClassification,
      lifecycleState: state,
      retirementCondition: retirementCondition,
      traceabilityGrade: traceabilityGrade,
      supplierOrFabricator: readOptionalPersistedString(
        map['supplierOrFabricator'],
        field: 'supplierOrFabricator',
        source: source,
      ),
      receivedOrCompletedOn: receivedOrCompletedOn,
      incorporatedOn: incorporatedOn,
      drawingReference: readOptionalPersistedString(
        map['drawingReference'],
        field: 'drawingReference',
        source: source,
      ),
      materialGrade: readOptionalPersistedString(
        map['materialGrade'],
        field: 'materialGrade',
        source: source,
      ),
      acceptanceReference: acceptanceReference,
      acceptedAt: acceptedAt,
      acceptedByUid: acceptedByUid,
      acceptedByName: acceptedByName,
      currentBaseAssetInstanceId: baseId,
      currentBaseAssetNumber: baseNumber,
      currentBaseAssetName: baseName,
      currentLinkageId: linkageId,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMutationId: readRequiredPersistedString(
        map['lastMutationId'],
        field: 'lastMutationId',
        source: source,
      ),
    );
  }
}

extension InnerCoverPlantCondition on InnerCoverProfile {
  bool get countsAsAssetInventory =>
      !const {
        InnerCoverLifecycleState.fullyConsumedAsDonor,
        InnerCoverLifecycleState.disposed,
      }.contains(lifecycleState);

  bool get isAvailableForPlantCondition => const {
    InnerCoverLifecycleState.available,
    InnerCoverLifecycleState.installed,
  }.contains(lifecycleState);

  bool get isUnderMaintenanceForPlantCondition => const {
    InnerCoverLifecycleState.underInspection,
    InnerCoverLifecycleState.underRepair,
    InnerCoverLifecycleState.underFabrication,
  }.contains(lifecycleState);

  bool get isUnfitForPlantCondition => const {
    InnerCoverLifecycleState.quarantined,
    InnerCoverLifecycleState.rejected,
    InnerCoverLifecycleState.retiredForSalvage,
    InnerCoverLifecycleState.partiallyDismantled,
  }.contains(lifecycleState);
}

class BaseInnerCoverAssignment {
  final String baseAssetInstanceId;
  final String baseAssetClassId;
  final int baseAssetNumber;
  final String baseAssetName;
  final String innerCoverId;
  final String innerCoverSerialNumber;
  final String linkageId;
  final DateTime linkedAt;
  final int version;
  final DateTime updatedAt;
  final String lastMutationId;

  const BaseInnerCoverAssignment({
    required this.baseAssetInstanceId,
    required this.baseAssetClassId,
    required this.baseAssetNumber,
    required this.baseAssetName,
    required this.innerCoverId,
    required this.innerCoverSerialNumber,
    required this.linkageId,
    required this.linkedAt,
    required this.version,
    required this.updatedAt,
    required this.lastMutationId,
  });

  factory BaseInnerCoverAssignment.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'base_inner_cover_assignments/$documentId';
    _requireSchema(map, source);
    final baseId = readRequiredPersistedString(
      map['baseAssetInstanceId'],
      field: 'baseAssetInstanceId',
      source: source,
    );
    if (baseId != documentId) {
      throw PersistedDataFormatException(
        field: 'baseAssetInstanceId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    return BaseInnerCoverAssignment(
      baseAssetInstanceId: baseId,
      baseAssetClassId: readRequiredPersistedString(
        map['baseAssetClassId'],
        field: 'baseAssetClassId',
        source: source,
      ),
      baseAssetNumber: readRequiredPersistedInt(
        map['baseAssetNumber'],
        field: 'baseAssetNumber',
        source: source,
        minimum: 1,
      ),
      baseAssetName: readRequiredPersistedString(
        map['baseAssetName'],
        field: 'baseAssetName',
        source: source,
      ),
      innerCoverId: readRequiredPersistedString(
        map['innerCoverId'],
        field: 'innerCoverId',
        source: source,
      ),
      innerCoverSerialNumber: readRequiredPersistedString(
        map['innerCoverSerialNumber'],
        field: 'innerCoverSerialNumber',
        source: source,
      ),
      linkageId: readRequiredPersistedString(
        map['linkageId'],
        field: 'linkageId',
        source: source,
      ),
      linkedAt: readRequiredPersistedDateTime(
        map['linkedAt'],
        field: 'linkedAt',
        source: source,
      ),
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
      lastMutationId: readRequiredPersistedString(
        map['lastMutationId'],
        field: 'lastMutationId',
        source: source,
      ),
    );
  }
}

class InnerCoverLinkage {
  final String id;
  final String baseAssetInstanceId;
  final int baseAssetNumber;
  final String baseAssetName;
  final String innerCoverId;
  final String innerCoverSerialNumber;
  final DateTime installedAt;
  final String installedByUid;
  final String installedByName;
  final DateTime? removedAt;
  final String? removalAction;
  final String? removalReason;
  final bool active;
  final int version;

  const InnerCoverLinkage({
    required this.id,
    required this.baseAssetInstanceId,
    required this.baseAssetNumber,
    required this.baseAssetName,
    required this.innerCoverId,
    required this.innerCoverSerialNumber,
    required this.installedAt,
    required this.installedByUid,
    required this.installedByName,
    this.removedAt,
    this.removalAction,
    this.removalReason,
    required this.active,
    required this.version,
  });

  factory InnerCoverLinkage.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'inner_cover_linkages/$documentId';
    _requireSchema(map, source);
    final id = readRequiredPersistedString(
      map['linkageId'],
      field: 'linkageId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'linkageId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final active = readRequiredPersistedBool(
      map['active'],
      field: 'active',
      source: source,
    );
    final removedAt = readOptionalPersistedDateTime(
      map['removedAt'],
      field: 'removedAt',
      source: source,
    );
    final removalAction = readOptionalPersistedString(
      map['removalAction'],
      field: 'removalAction',
      source: source,
    );
    final removalReason = readOptionalPersistedString(
      map['removalReason'],
      field: 'removalReason',
      source: source,
    );
    if ((active &&
            (removedAt != null ||
                removalAction != null ||
                removalReason != null)) ||
        (!active &&
            (removedAt == null ||
                removalAction == null ||
                removalReason == null))) {
      throw PersistedDataFormatException(
        field: 'active',
        source: source,
        detail:
            'removal evidence must be absent when active and complete when closed',
      );
    }
    return InnerCoverLinkage(
      id: id,
      baseAssetInstanceId: readRequiredPersistedString(
        map['baseAssetInstanceId'],
        field: 'baseAssetInstanceId',
        source: source,
      ),
      baseAssetNumber: readRequiredPersistedInt(
        map['baseAssetNumber'],
        field: 'baseAssetNumber',
        source: source,
        minimum: 1,
      ),
      baseAssetName: readRequiredPersistedString(
        map['baseAssetName'],
        field: 'baseAssetName',
        source: source,
      ),
      innerCoverId: readRequiredPersistedString(
        map['innerCoverId'],
        field: 'innerCoverId',
        source: source,
      ),
      innerCoverSerialNumber: readRequiredPersistedString(
        map['innerCoverSerialNumber'],
        field: 'innerCoverSerialNumber',
        source: source,
      ),
      installedAt: readRequiredPersistedDateTime(
        map['installedAt'],
        field: 'installedAt',
        source: source,
      ),
      installedByUid: readRequiredPersistedString(
        map['installedByUid'],
        field: 'installedByUid',
        source: source,
      ),
      installedByName: readRequiredPersistedString(
        map['installedByName'],
        field: 'installedByName',
        source: source,
      ),
      removedAt: removedAt,
      removalAction: removalAction,
      removalReason: removalReason,
      active: active,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
    );
  }
}

class InnerCoverFabricationSection {
  final String id;
  final InnerCoverFabricationSectionType type;
  final InnerCoverSectionMaterialSource materialSource;
  final String? donorInnerCoverId;
  final String? donorSectionKey;
  final double? lengthMm;
  final int cutCount;
  final String? notes;

  const InnerCoverFabricationSection({
    required this.id,
    required this.type,
    required this.materialSource,
    this.donorInnerCoverId,
    this.donorSectionKey,
    this.lengthMm,
    required this.cutCount,
    this.notes,
  });

  factory InnerCoverFabricationSection.fromMap(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final materialSource = readRequiredPersistedEnum(
      InnerCoverSectionMaterialSource.values,
      map['materialSource'],
      field: 'materialSource',
      source: source,
    );
    final donorId = readOptionalPersistedString(
      map['donorInnerCoverId'],
      field: 'donorInnerCoverId',
      source: source,
    );
    final donorSectionKey = readOptionalPersistedString(
      map['donorSectionKey'],
      field: 'donorSectionKey',
      source: source,
    );
    final knownDonor =
        materialSource == InnerCoverSectionMaterialSource.reusedKnownDonor;
    if (knownDonor != (donorId != null && donorSectionKey != null)) {
      throw PersistedDataFormatException(
        field: 'donorInnerCoverId',
        source: source,
        detail: 'known donor identity and section key must appear together',
      );
    }
    return InnerCoverFabricationSection(
      id: readRequiredPersistedString(
        map['sectionId'],
        field: 'sectionId',
        source: source,
      ),
      type: readRequiredPersistedEnum(
        InnerCoverFabricationSectionType.values,
        map['sectionType'],
        field: 'sectionType',
        source: source,
      ),
      materialSource: materialSource,
      donorInnerCoverId: donorId,
      donorSectionKey: donorSectionKey,
      lengthMm: readOptionalPersistedDouble(
        map['lengthMm'],
        field: 'lengthMm',
        source: source,
      ),
      cutCount: readRequiredPersistedInt(
        map['cutCount'],
        field: 'cutCount',
        source: source,
        minimum: 1,
      ),
      notes: readOptionalPersistedString(
        map['notes'],
        field: 'notes',
        source: source,
      ),
    );
  }
}

class InnerCoverFabricationDossier {
  final String id;
  final String resultingInnerCoverId;
  final String resultingSerialNumber;
  final String? supplierOrFabricator;
  final DateTime? completedOn;
  final String? drawingReference;
  final String? materialGrade;
  final InnerCoverTraceabilityGrade traceabilityGrade;
  final List<InnerCoverFabricationSection> sections;
  final String status;
  final String? acceptanceReference;

  const InnerCoverFabricationDossier({
    required this.id,
    required this.resultingInnerCoverId,
    required this.resultingSerialNumber,
    this.supplierOrFabricator,
    this.completedOn,
    this.drawingReference,
    this.materialGrade,
    required this.traceabilityGrade,
    required this.sections,
    required this.status,
    this.acceptanceReference,
  });

  factory InnerCoverFabricationDossier.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'inner_cover_fabrications/$documentId';
    _requireSchema(map, source);
    final id = readRequiredPersistedString(
      map['fabricationId'],
      field: 'fabricationId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'fabricationId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final rawSections = map['sections'];
    if (rawSections is! List ||
        rawSections.isEmpty ||
        rawSections.length > 100) {
      throw PersistedDataFormatException(
        field: 'sections',
        source: source,
        detail: 'expected 1-100 fabrication sections',
      );
    }
    final sections = <InnerCoverFabricationSection>[];
    for (var index = 0; index < rawSections.length; index++) {
      final raw = rawSections[index];
      if (raw is! Map) {
        throw PersistedDataFormatException(
          field: 'sections[$index]',
          source: source,
          detail: 'expected an object',
        );
      }
      sections.add(
        InnerCoverFabricationSection.fromMap(
          Map<String, dynamic>.from(raw),
          source: '$source.sections[$index]',
        ),
      );
    }
    if (sections.map((section) => section.id).toSet().length !=
        sections.length) {
      throw PersistedDataFormatException(
        field: 'sections',
        source: source,
        detail: 'section IDs must be unique',
      );
    }
    return InnerCoverFabricationDossier(
      id: id,
      resultingInnerCoverId: readRequiredPersistedString(
        map['resultingInnerCoverId'],
        field: 'resultingInnerCoverId',
        source: source,
      ),
      resultingSerialNumber: readRequiredPersistedString(
        map['resultingSerialNumber'],
        field: 'resultingSerialNumber',
        source: source,
      ),
      supplierOrFabricator: readOptionalPersistedString(
        map['supplierOrFabricator'],
        field: 'supplierOrFabricator',
        source: source,
      ),
      completedOn: readOptionalPersistedDateTime(
        map['completedOn'],
        field: 'completedOn',
        source: source,
      ),
      drawingReference: readOptionalPersistedString(
        map['drawingReference'],
        field: 'drawingReference',
        source: source,
      ),
      materialGrade: readOptionalPersistedString(
        map['materialGrade'],
        field: 'materialGrade',
        source: source,
      ),
      traceabilityGrade: _readTraceabilityGrade(
        map['traceabilityGrade'],
        source: source,
      ),
      sections: List.unmodifiable(sections),
      status: readRequiredPersistedString(
        map['status'],
        field: 'status',
        source: source,
      ),
      acceptanceReference: readOptionalPersistedString(
        map['acceptanceReference'],
        field: 'acceptanceReference',
        source: source,
      ),
    );
  }
}
