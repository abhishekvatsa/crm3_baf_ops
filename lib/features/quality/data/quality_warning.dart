import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/validation/charge_number.dart';

enum QualityWarningSourceType { issue, abnormality }

enum QualityWarningStatus { open, closureRequested, closed }

enum QualityWarningClosureDisposition {
  coilFoundAcceptable,
  reannealingCompleted,
  qualityAdjudication,
}

class QualityAffectedAsset {
  const QualityAffectedAsset({
    required this.assetType,
    required this.assetNumber,
  });

  final String assetType;
  final int assetNumber;

  String get label => '${assetType.toUpperCase()} $assetNumber';

  factory QualityAffectedAsset.fromMap(
    Map<String, dynamic> map, {
    required String source,
  }) => QualityAffectedAsset(
    assetType: readRequiredPersistedString(
      map['assetType'],
      field: 'assetType',
      source: source,
    ),
    assetNumber: readRequiredPersistedInt(
      map['assetNumber'],
      field: 'assetNumber',
      source: source,
      minimum: 1,
    ),
  );
}

class QualityWarning {
  const QualityWarning({
    required this.warningId,
    required this.sourceType,
    required this.sourceId,
    required this.sourceVersion,
    required this.sourceChargeNo,
    required this.sourceSummary,
    required this.sourceSeverity,
    required this.warningReason,
    required this.affectedAssets,
    required this.status,
    required this.createdAt,
    required this.createdByUid,
    required this.updatedAt,
    required this.updatedByUid,
    required this.version,
    this.component,
    this.closureRequestReason,
    this.closureRequestedAt,
    this.closureRequestedByUid,
    this.closureRequestedByName,
    this.closedAt,
    this.closedByUid,
    this.closedByName,
    this.closureDisposition,
    this.linkedReannealingChargeNos = const <int>[],
    this.decisionReason,
    this.createdByName,
    this.updatedByName,
  });

  final String warningId;
  final QualityWarningSourceType sourceType;
  final String sourceId;
  final int sourceVersion;
  final int sourceChargeNo;
  final String sourceSummary;
  final String sourceSeverity;
  final String warningReason;
  final List<QualityAffectedAsset> affectedAssets;
  final String? component;
  final QualityWarningStatus status;
  final String? closureRequestReason;
  final DateTime? closureRequestedAt;
  final String? closureRequestedByUid;
  final String? closureRequestedByName;
  final DateTime? closedAt;
  final String? closedByUid;
  final String? closedByName;
  final QualityWarningClosureDisposition? closureDisposition;
  final List<int> linkedReannealingChargeNos;
  final String? decisionReason;
  final DateTime createdAt;
  final String createdByUid;
  final String? createdByName;
  final DateTime updatedAt;
  final String updatedByUid;
  final String? updatedByName;
  final int version;

  bool get isOpen => status != QualityWarningStatus.closed;

  factory QualityWarning.fromMap(Map<String, dynamic> map, String documentId) {
    final source = 'quality_warnings/$documentId';
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
        detail: 'unsupported quality warning schema version',
      );
    }
    final warningId = readRequiredPersistedString(
      map['warningId'],
      field: 'warningId',
      source: source,
    );
    if (warningId != documentId) {
      throw PersistedDataFormatException(
        field: 'warningId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final sourceType = readRequiredPersistedEnum(
      QualityWarningSourceType.values,
      map['sourceType'],
      field: 'sourceType',
      source: source,
    );
    final sourceId = readRequiredPersistedString(
      map['sourceId'],
      field: 'sourceId',
      source: source,
    );
    if (warningId != '${sourceType.name}_$sourceId') {
      throw PersistedDataFormatException(
        field: 'sourceId',
        source: source,
        detail: 'does not match the deterministic warning identity',
      );
    }
    final affectedRaw = map['affectedAssets'];
    if (affectedRaw is! List ||
        affectedRaw.isEmpty ||
        affectedRaw.length > 50) {
      throw PersistedDataFormatException(
        field: 'affectedAssets',
        source: source,
        detail: 'expected 1-50 asset maps',
      );
    }
    final affectedAssets = <QualityAffectedAsset>[];
    for (var index = 0; index < affectedRaw.length; index++) {
      final raw = affectedRaw[index];
      if (raw is! Map) {
        throw PersistedDataFormatException(
          field: 'affectedAssets[$index]',
          source: source,
          detail: 'expected an asset map',
        );
      }
      affectedAssets.add(
        QualityAffectedAsset.fromMap(
          Map<String, dynamic>.from(raw),
          source: '$source affectedAssets[$index]',
        ),
      );
    }
    final raRaw = map['linkedReannealingChargeNos'];
    if (raRaw is! List || raRaw.length > 20) {
      throw PersistedDataFormatException(
        field: 'linkedReannealingChargeNos',
        source: source,
        detail: 'expected at most 20 charge numbers',
      );
    }
    final raCharges = <int>[
      for (var index = 0; index < raRaw.length; index++)
        readRequiredPersistedInt(
          raRaw[index],
          field: 'linkedReannealingChargeNos[$index]',
          source: source,
          minimum: 1,
        ),
    ];
    if (raCharges.toSet().length != raCharges.length) {
      throw PersistedDataFormatException(
        field: 'linkedReannealingChargeNos',
        source: source,
        detail: 'duplicate charge numbers are not permitted',
      );
    }
    final status = readRequiredPersistedEnum(
      QualityWarningStatus.values,
      map['status'],
      field: 'status',
      source: source,
    );
    final disposition = readOptionalPersistedEnum(
      QualityWarningClosureDisposition.values,
      map['closureDisposition'],
      field: 'closureDisposition',
      source: source,
    );
    final closedAt = readOptionalPersistedDateTime(
      map['closedAt'],
      field: 'closedAt',
      source: source,
    );
    final closureRequestReason = readOptionalPersistedString(
      map['closureRequestReason'],
      field: 'closureRequestReason',
      source: source,
    );
    final closureRequestedAt = readOptionalPersistedDateTime(
      map['closureRequestedAt'],
      field: 'closureRequestedAt',
      source: source,
    );
    final closureRequestedByUid = readOptionalPersistedString(
      map['closureRequestedByUid'],
      field: 'closureRequestedByUid',
      source: source,
    );
    final closureRequestedByName = readOptionalPersistedString(
      map['closureRequestedByName'],
      field: 'closureRequestedByName',
      source: source,
    );
    final closedByUid = readOptionalPersistedString(
      map['closedByUid'],
      field: 'closedByUid',
      source: source,
    );
    final closedByName = readOptionalPersistedString(
      map['closedByName'],
      field: 'closedByName',
      source: source,
    );
    final decisionReason = readOptionalPersistedString(
      map['decisionReason'],
      field: 'decisionReason',
      source: source,
    );
    final requestEvidence = <Object?>[
      closureRequestReason,
      closureRequestedAt,
      closureRequestedByUid,
      closureRequestedByName,
    ];
    final hasRequestEvidence = requestEvidence.any((value) => value != null);
    final hasCompleteRequestEvidence = requestEvidence.every(
      (value) => value != null,
    );
    if (hasRequestEvidence != hasCompleteRequestEvidence) {
      throw PersistedDataFormatException(
        field: 'closureRequestReason',
        source: source,
        detail: 'closure-request evidence must be wholly present or absent',
      );
    }
    if (status == QualityWarningStatus.open &&
        (hasRequestEvidence ||
            closedAt != null ||
            closedByUid != null ||
            closedByName != null ||
            disposition != null ||
            decisionReason != null ||
            raCharges.isNotEmpty)) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'open state cannot contain closure evidence',
      );
    }
    if (status == QualityWarningStatus.closureRequested &&
        (!hasCompleteRequestEvidence ||
            closedAt != null ||
            closedByUid != null ||
            closedByName != null ||
            disposition != null ||
            decisionReason != null ||
            raCharges.isNotEmpty)) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail:
            'closure-requested state requires only complete request evidence',
      );
    }
    if (status == QualityWarningStatus.closed &&
        (closedAt == null ||
            closedByUid == null ||
            closedByName == null ||
            disposition == null ||
            decisionReason == null)) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'closed state requires complete decision evidence',
      );
    }
    if (disposition == QualityWarningClosureDisposition.reannealingCompleted &&
        raCharges.isEmpty) {
      throw PersistedDataFormatException(
        field: 'linkedReannealingChargeNos',
        source: source,
        detail: 're-annealing closure requires at least one RA charge',
      );
    }
    if (disposition != QualityWarningClosureDisposition.reannealingCompleted &&
        raCharges.isNotEmpty) {
      throw PersistedDataFormatException(
        field: 'linkedReannealingChargeNos',
        source: source,
        detail: 'RA charges are valid only for re-annealing closure',
      );
    }
    return QualityWarning(
      warningId: warningId,
      sourceType: sourceType,
      sourceId: sourceId,
      sourceVersion: readRequiredPersistedInt(
        map['sourceVersion'],
        field: 'sourceVersion',
        source: source,
        minimum: 1,
      ),
      sourceChargeNo: readRequiredPersistedInt(
        map['sourceChargeNo'],
        field: 'sourceChargeNo',
        source: source,
        minimum: 1,
      ),
      sourceSummary: readRequiredPersistedString(
        map['sourceSummary'],
        field: 'sourceSummary',
        source: source,
      ),
      sourceSeverity: readRequiredPersistedString(
        map['sourceSeverity'],
        field: 'sourceSeverity',
        source: source,
      ),
      warningReason: readRequiredPersistedString(
        map['warningReason'],
        field: 'warningReason',
        source: source,
      ),
      affectedAssets: List.unmodifiable(affectedAssets),
      component: readOptionalPersistedString(
        map['component'],
        field: 'component',
        source: source,
      ),
      status: status,
      closureRequestReason: closureRequestReason,
      closureRequestedAt: closureRequestedAt,
      closureRequestedByUid: closureRequestedByUid,
      closureRequestedByName: closureRequestedByName,
      closedAt: closedAt,
      closedByUid: closedByUid,
      closedByName: closedByName,
      closureDisposition: disposition,
      linkedReannealingChargeNos: List.unmodifiable(raCharges),
      decisionReason: decisionReason,
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
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
    );
  }
}

enum QualityMonitoringStatus { active, closed }

enum QualityMonitoringVisibilityState { active, recent, archived }

class QualityMonitoringRequest {
  const QualityMonitoringRequest({
    required this.requestId,
    required this.baseNumber,
    required this.grade,
    required this.cycleReference,
    required this.chargeNumbers,
    required this.reason,
    required this.status,
    required this.visibilityState,
    required this.visibleUntil,
    required this.archivedAt,
    required this.createdAt,
    required this.createdByUid,
    required this.updatedAt,
    required this.updatedByUid,
    required this.version,
    this.createdByName,
    this.updatedByName,
    this.closedAt,
    this.closedByUid,
    this.closedByName,
    this.closeReason,
  });

  final String requestId;
  final int baseNumber;
  final String grade;
  final String cycleReference;
  final List<int> chargeNumbers;
  final String reason;
  final QualityMonitoringStatus status;
  final QualityMonitoringVisibilityState visibilityState;
  final DateTime? visibleUntil;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final String createdByUid;
  final String? createdByName;
  final DateTime? closedAt;
  final String? closedByUid;
  final String? closedByName;
  final String? closeReason;
  final DateTime updatedAt;
  final String updatedByUid;
  final String? updatedByName;
  final int version;

  factory QualityMonitoringRequest.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'quality_monitoring_requests/$documentId';
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported monitoring schema version',
      );
    }
    final id = readRequiredPersistedString(
      map['requestId'],
      field: 'requestId',
      source: source,
    );
    if (id != documentId) {
      throw PersistedDataFormatException(
        field: 'requestId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final rawCharges = map['chargeNumbers'];
    if (rawCharges is! List || rawCharges.length > 50) {
      throw PersistedDataFormatException(
        field: 'chargeNumbers',
        source: source,
        detail: 'expected at most 50 charge numbers',
      );
    }
    final chargeNumbers = <int>[
      for (var index = 0; index < rawCharges.length; index++)
        readRequiredPersistedChargeNumber(
          rawCharges[index],
          field: 'chargeNumbers[$index]',
          source: source,
        ),
    ];
    if (chargeNumbers.toSet().length != chargeNumbers.length) {
      throw PersistedDataFormatException(
        field: 'chargeNumbers',
        source: source,
        detail: 'duplicate charge numbers are not permitted',
      );
    }
    final status = readRequiredPersistedEnum(
      QualityMonitoringStatus.values,
      map['status'],
      field: 'status',
      source: source,
    );
    final closedAt = readOptionalPersistedDateTime(
      map['closedAt'],
      field: 'closedAt',
      source: source,
    );
    final closedByUid = readOptionalPersistedString(
      map['closedByUid'],
      field: 'closedByUid',
      source: source,
    );
    final closedByName = readOptionalPersistedString(
      map['closedByName'],
      field: 'closedByName',
      source: source,
    );
    final closeReason = readOptionalPersistedString(
      map['closeReason'],
      field: 'closeReason',
      source: source,
    );
    final closureEvidence = <Object?>[
      closedAt,
      closedByUid,
      closedByName,
      closeReason,
    ];
    final hasClosureEvidence = closureEvidence.any((value) => value != null);
    final hasCompleteClosureEvidence = closureEvidence.every(
      (value) => value != null,
    );
    if ((status == QualityMonitoringStatus.active && hasClosureEvidence) ||
        (status == QualityMonitoringStatus.closed &&
            !hasCompleteClosureEvidence)) {
      throw PersistedDataFormatException(
        field: 'status',
        source: source,
        detail: 'monitoring status and closure evidence are inconsistent',
      );
    }
    const retention = Duration(days: 7);
    const visibilityFields = <String>{
      'visibilityState',
      'visibleUntil',
      'archivedAt',
    };
    final visibilityFieldCount = visibilityFields.where(map.containsKey).length;
    final isLegacyVisibility = schemaVersion == 1;
    if ((isLegacyVisibility && visibilityFieldCount != 0) ||
        (!isLegacyVisibility &&
            visibilityFieldCount != visibilityFields.length)) {
      throw PersistedDataFormatException(
        field: 'visibilityState',
        source: source,
        detail:
            isLegacyVisibility
                ? 'legacy schema must omit the complete visibility projection'
                : 'schema v2 requires the complete visibility projection',
      );
    }
    final visibilityState =
        isLegacyVisibility
            ? status == QualityMonitoringStatus.active
                ? QualityMonitoringVisibilityState.active
                : QualityMonitoringVisibilityState.recent
            : readRequiredPersistedEnum(
              QualityMonitoringVisibilityState.values,
              map['visibilityState'],
              field: 'visibilityState',
              source: source,
            );
    final visibleUntil =
        isLegacyVisibility
            ? status == QualityMonitoringStatus.closed
                ? closedAt!.toUtc().add(retention)
                : null
            : readOptionalPersistedDateTime(
              map['visibleUntil'],
              field: 'visibleUntil',
              source: source,
            );
    final archivedAt =
        isLegacyVisibility
            ? null
            : readOptionalPersistedDateTime(
              map['archivedAt'],
              field: 'archivedAt',
              source: source,
            );
    if (status == QualityMonitoringStatus.active) {
      if (visibilityState != QualityMonitoringVisibilityState.active ||
          visibleUntil != null ||
          archivedAt != null) {
        throw PersistedDataFormatException(
          field: 'visibilityState',
          source: source,
          detail: 'active monitoring visibility is inconsistent',
        );
      }
    } else if (visibilityState == QualityMonitoringVisibilityState.recent) {
      if (closedAt == null ||
          visibleUntil == null ||
          archivedAt != null ||
          visibleUntil.toUtc() != closedAt.toUtc().add(retention)) {
        throw PersistedDataFormatException(
          field: 'visibleUntil',
          source: source,
          detail: 'recent monitoring visibility deadline is inconsistent',
        );
      }
    } else if (visibilityState == QualityMonitoringVisibilityState.archived) {
      if (closedAt == null ||
          visibleUntil != null ||
          archivedAt == null ||
          archivedAt.toUtc().isBefore(closedAt.toUtc().add(retention))) {
        throw PersistedDataFormatException(
          field: 'archivedAt',
          source: source,
          detail: 'archived monitoring evidence is inconsistent',
        );
      }
    } else {
      throw PersistedDataFormatException(
        field: 'visibilityState',
        source: source,
        detail: 'closed monitoring must be recent or archived',
      );
    }
    return QualityMonitoringRequest(
      requestId: id,
      baseNumber: readRequiredPersistedInt(
        map['baseNumber'],
        field: 'baseNumber',
        source: source,
        minimum: 1,
      ),
      grade: readRequiredPersistedString(
        map['grade'],
        field: 'grade',
        source: source,
      ),
      cycleReference: readRequiredPersistedString(
        map['cycleReference'],
        field: 'cycleReference',
        source: source,
      ),
      chargeNumbers: List.unmodifiable(chargeNumbers),
      reason: readRequiredPersistedString(
        map['reason'],
        field: 'reason',
        source: source,
      ),
      status: status,
      visibilityState: visibilityState,
      visibleUntil: visibleUntil,
      archivedAt: archivedAt,
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
      closedAt: closedAt,
      closedByUid: closedByUid,
      closedByName: closedByName,
      closeReason: closeReason,
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
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
    );
  }
}
