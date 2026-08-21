import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/validation/charge_number.dart';
import '../../maintenance/domain/furnace_stuckup_case.dart';

enum FurnaceStuckupObstructionStatus { active, released }

enum FurnaceStuckupAdjudicationStatus { pending, confirmed, inconclusive }

class FurnaceStuckupRecord {
  const FurnaceStuckupRecord({
    required this.id,
    required this.ticketId,
    required this.version,
    required this.obstructionStatus,
    required this.adjudicationStatus,
    required this.suspectedCause,
    required this.confirmedCause,
    required this.furnaceAssetInstanceId,
    required this.furnaceAssetNumber,
    required this.baseAssetInstanceId,
    required this.baseAssetNumber,
    required this.innerCoverId,
    required this.innerCoverSerialNumber,
    required this.operatingContext,
    required this.chargeNoAtEvent,
    required this.reportedAt,
    required this.reportedByName,
    required this.releasedAt,
    required this.releaseNotes,
    required this.adjudicatedAt,
    required this.adjudicationNotes,
    required this.conditionDeclarationId,
    required this.updatedAt,
  });

  final String id;
  final String ticketId;
  final int version;
  final FurnaceStuckupObstructionStatus obstructionStatus;
  final FurnaceStuckupAdjudicationStatus adjudicationStatus;
  final FurnaceStuckupCause suspectedCause;
  final FurnaceStuckupCause? confirmedCause;
  final String furnaceAssetInstanceId;
  final int furnaceAssetNumber;
  final String baseAssetInstanceId;
  final int baseAssetNumber;
  final String innerCoverId;
  final String innerCoverSerialNumber;
  final FurnaceStuckupOperatingContext operatingContext;
  final int? chargeNoAtEvent;
  final DateTime reportedAt;
  final String reportedByName;
  final DateTime? releasedAt;
  final String? releaseNotes;
  final DateTime? adjudicatedAt;
  final String? adjudicationNotes;
  final String? conditionDeclarationId;
  final DateTime updatedAt;

  bool get isActive =>
      obstructionStatus == FurnaceStuckupObstructionStatus.active;
  bool get needsAdjudication =>
      adjudicationStatus == FurnaceStuckupAdjudicationStatus.pending;

  factory FurnaceStuckupRecord.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'furnace_stuckup_cases/$documentId';
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
    final caseId = readRequiredPersistedString(
      map['caseId'],
      field: 'caseId',
      source: source,
    );
    if (caseId != documentId) {
      throw PersistedDataFormatException(
        field: 'caseId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    return FurnaceStuckupRecord(
      id: caseId,
      ticketId: readRequiredPersistedString(
        map['ticketId'],
        field: 'ticketId',
        source: source,
      ),
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      obstructionStatus: readRequiredPersistedEnum(
        FurnaceStuckupObstructionStatus.values,
        map['obstructionStatus'],
        field: 'obstructionStatus',
        source: source,
      ),
      adjudicationStatus: readRequiredPersistedEnum(
        FurnaceStuckupAdjudicationStatus.values,
        map['adjudicationStatus'],
        field: 'adjudicationStatus',
        source: source,
      ),
      suspectedCause: readRequiredPersistedEnum(
        FurnaceStuckupCause.values,
        map['suspectedCause'],
        field: 'suspectedCause',
        source: source,
      ),
      confirmedCause: readOptionalPersistedEnum(
        FurnaceStuckupCause.values,
        map['confirmedCause'],
        field: 'confirmedCause',
        source: source,
      ),
      furnaceAssetInstanceId: readRequiredPersistedString(
        map['furnaceAssetInstanceId'],
        field: 'furnaceAssetInstanceId',
        source: source,
      ),
      furnaceAssetNumber: readRequiredPersistedInt(
        map['furnaceAssetNumber'],
        field: 'furnaceAssetNumber',
        source: source,
        minimum: 1,
      ),
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
      operatingContext: readRequiredPersistedEnum(
        FurnaceStuckupOperatingContext.values,
        map['operatingContext'],
        field: 'operatingContext',
        source: source,
      ),
      chargeNoAtEvent: readOptionalPersistedChargeNumber(
        map['chargeNoAtEvent'],
        field: 'chargeNoAtEvent',
        source: source,
      ),
      reportedAt: readRequiredPersistedDateTime(
        map['reportedAt'],
        field: 'reportedAt',
        source: source,
      ),
      reportedByName: readRequiredPersistedString(
        map['reportedByName'],
        field: 'reportedByName',
        source: source,
      ),
      releasedAt: readOptionalPersistedDateTime(
        map['releasedAt'],
        field: 'releasedAt',
        source: source,
      ),
      releaseNotes: readOptionalPersistedString(
        map['releaseNotes'],
        field: 'releaseNotes',
        source: source,
      ),
      adjudicatedAt: readOptionalPersistedDateTime(
        map['adjudicatedAt'],
        field: 'adjudicatedAt',
        source: source,
      ),
      adjudicationNotes: readOptionalPersistedString(
        map['adjudicationNotes'],
        field: 'adjudicationNotes',
        source: source,
      ),
      conditionDeclarationId: readOptionalPersistedString(
        map['conditionDeclarationId'],
        field: 'conditionDeclarationId',
        source: source,
      ),
      updatedAt: readRequiredPersistedDateTime(
        map['updatedAt'],
        field: 'updatedAt',
        source: source,
      ),
    );
  }
}

class AssetConditionDeclarationRecord {
  const AssetConditionDeclarationRecord({
    required this.id,
    required this.assetId,
    required this.assetSerialNumber,
    required this.evidenceCount,
    required this.firstConfirmedAt,
    required this.latestEvidenceAt,
  });

  final String id;
  final String assetId;
  final String assetSerialNumber;
  final int evidenceCount;
  final DateTime firstConfirmedAt;
  final DateTime latestEvidenceAt;

  factory AssetConditionDeclarationRecord.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'asset_condition_declarations/$documentId';
    if (map['schemaVersion'] != 1 ||
        map['declarationId'] != documentId ||
        map['conditionType'] != 'innerCoverBulged' ||
        map['assetType'] != 'innerCover' ||
        map['state'] != 'confirmed') {
      throw PersistedDataFormatException(
        field: 'conditionType',
        source: source,
        detail: 'unsupported or inconsistent condition declaration',
      );
    }
    return AssetConditionDeclarationRecord(
      id: documentId,
      assetId: readRequiredPersistedString(
        map['assetId'],
        field: 'assetId',
        source: source,
      ),
      assetSerialNumber: readRequiredPersistedString(
        map['assetSerialNumber'],
        field: 'assetSerialNumber',
        source: source,
      ),
      evidenceCount: readRequiredPersistedInt(
        map['evidenceCount'],
        field: 'evidenceCount',
        source: source,
        minimum: 1,
      ),
      firstConfirmedAt: readRequiredPersistedDateTime(
        map['firstConfirmedAt'],
        field: 'firstConfirmedAt',
        source: source,
      ),
      latestEvidenceAt: readRequiredPersistedDateTime(
        map['latestEvidenceAt'],
        field: 'latestEvidenceAt',
        source: source,
      ),
    );
  }
}
