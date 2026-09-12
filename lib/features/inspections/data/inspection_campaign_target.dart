part of 'inspection_campaign.dart';

class InspectionCampaignTarget {
  const InspectionCampaignTarget({
    required this.targetKey,
    required this.assetTypeKey,
    required this.assetClassId,
    required this.assetNumber,
    required this.assetInstanceId,
    required this.assetInstanceVersion,
    required this.assetInstanceName,
    required this.hostAssetClassId,
    required this.hostAssetInstanceId,
    required this.hostAssetInstanceVersion,
    required this.hostAssetNumber,
    required this.hostAssetInstanceName,
    required this.subjectSerialNumber,
    required this.linkageId,
    required this.linkageVersion,
    required this.linkedAt,
    required this.componentNodeId,
    required this.physicalPosition,
    required this.disposition,
    required this.dispositionReason,
    required this.dispositionAt,
    required this.dispositionByUid,
    required this.dispositionByName,
    required this.addedLater,
    required this.lastObservationId,
    required this.lastObservedAt,
    this.contextReview,
  });

  final String targetKey;
  final String assetTypeKey;
  final String assetClassId;
  final int assetNumber;
  final String assetInstanceId;
  final int assetInstanceVersion;
  final String assetInstanceName;
  final String? hostAssetClassId;
  final String? hostAssetInstanceId;
  final int? hostAssetInstanceVersion;
  final int? hostAssetNumber;
  final String? hostAssetInstanceName;
  final String? subjectSerialNumber;
  final String? linkageId;
  final int? linkageVersion;
  final DateTime? linkedAt;
  final String? componentNodeId;
  final String? physicalPosition;
  final InspectionTargetDisposition disposition;
  final String? dispositionReason;
  final DateTime dispositionAt;
  final String dispositionByUid;
  final String dispositionByName;
  final bool addedLater;
  final String? lastObservationId;
  final DateTime? lastObservedAt;
  final InspectionTargetContextReview? contextReview;

  InspectionCampaignTarget get currentContext => contextReview?.context ?? this;
  int get contextRevision => contextReview?.revision ?? 0;

  bool get hasInstalledInnerCoverContext =>
      hostAssetClassId != null &&
      hostAssetInstanceId != null &&
      hostAssetInstanceVersion != null &&
      hostAssetNumber != null &&
      hostAssetInstanceName != null &&
      subjectSerialNumber != null &&
      linkageId != null &&
      linkageVersion != null &&
      linkedAt != null;

  String get rowLabel => currentContext.hasInstalledInnerCoverContext
      ? 'Base ${currentContext.hostAssetNumber} (${currentContext.subjectSerialNumber})'
      : currentContext.assetInstanceName;

  factory InspectionCampaignTarget.fromMap(
    Map<String, dynamic> map, {
    required String source,
  }) {
    if (readRequiredPersistedInt(
          map['schemaVersion'],
          field: 'schemaVersion',
          source: source,
        ) !=
        1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported target schema',
      );
    }
    final target = InspectionCampaignTarget(
      contextReview: map['contextReview'] == null
          ? null
          : InspectionTargetContextReview.fromMap(
              map['contextReview'],
              source: '$source.contextReview',
            ),
      targetKey: readRequiredPersistedString(
        map['targetKey'],
        field: 'targetKey',
        source: source,
      ),
      assetTypeKey: readRequiredPersistedString(
        map['assetTypeKey'],
        field: 'assetTypeKey',
        source: source,
      ),
      assetClassId: readRequiredPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      assetNumber: readRequiredPersistedInt(
        map['assetNumber'],
        field: 'assetNumber',
        source: source,
        minimum: 1,
      ),
      assetInstanceId: readRequiredPersistedString(
        map['assetInstanceId'],
        field: 'assetInstanceId',
        source: source,
      ),
      assetInstanceVersion: readRequiredPersistedInt(
        map['assetInstanceVersion'],
        field: 'assetInstanceVersion',
        source: source,
        minimum: 1,
      ),
      assetInstanceName: readRequiredPersistedString(
        map['assetInstanceName'],
        field: 'assetInstanceName',
        source: source,
      ),
      hostAssetClassId: readOptionalPersistedString(
        map['hostAssetClassId'],
        field: 'hostAssetClassId',
        source: source,
      ),
      hostAssetInstanceId: readOptionalPersistedString(
        map['hostAssetInstanceId'],
        field: 'hostAssetInstanceId',
        source: source,
      ),
      hostAssetInstanceVersion: readOptionalPersistedInt(
        map['hostAssetInstanceVersion'],
        field: 'hostAssetInstanceVersion',
        source: source,
        minimum: 1,
      ),
      hostAssetNumber: readOptionalPersistedInt(
        map['hostAssetNumber'],
        field: 'hostAssetNumber',
        source: source,
        minimum: 1,
      ),
      hostAssetInstanceName: readOptionalPersistedString(
        map['hostAssetInstanceName'],
        field: 'hostAssetInstanceName',
        source: source,
      ),
      subjectSerialNumber: readOptionalPersistedString(
        map['subjectSerialNumber'],
        field: 'subjectSerialNumber',
        source: source,
      ),
      linkageId: readOptionalPersistedString(
        map['linkageId'],
        field: 'linkageId',
        source: source,
      ),
      linkageVersion: readOptionalPersistedInt(
        map['linkageVersion'],
        field: 'linkageVersion',
        source: source,
        minimum: 1,
      ),
      linkedAt: readOptionalPersistedDateTime(
        map['linkedAt'],
        field: 'linkedAt',
        source: source,
      ),
      componentNodeId: readOptionalPersistedString(
        map['componentNodeId'],
        field: 'componentNodeId',
        source: source,
      ),
      physicalPosition: readOptionalPersistedString(
        map['physicalPosition'],
        field: 'physicalPosition',
        source: source,
      ),
      disposition: readRequiredPersistedEnum(
        InspectionTargetDisposition.values,
        map['disposition'],
        field: 'disposition',
        source: source,
      ),
      dispositionReason: readOptionalPersistedString(
        map['dispositionReason'],
        field: 'dispositionReason',
        source: source,
      ),
      dispositionAt: readRequiredPersistedDateTime(
        map['dispositionAt'],
        field: 'dispositionAt',
        source: source,
      ),
      dispositionByUid: readRequiredPersistedString(
        map['dispositionByUid'],
        field: 'dispositionByUid',
        source: source,
      ),
      dispositionByName: readRequiredPersistedString(
        map['dispositionByName'],
        field: 'dispositionByName',
        source: source,
      ),
      addedLater: readRequiredPersistedBool(
        map['addedLater'],
        field: 'addedLater',
        source: source,
      ),
      lastObservationId: readOptionalPersistedString(
        map['lastObservationId'],
        field: 'lastObservationId',
        source: source,
      ),
      lastObservedAt: readOptionalPersistedDateTime(
        map['lastObservedAt'],
        field: 'lastObservedAt',
        source: source,
      ),
    );
    final installedContextFields = <Object?>[
      target.hostAssetClassId,
      target.hostAssetInstanceId,
      target.hostAssetInstanceVersion,
      target.hostAssetNumber,
      target.hostAssetInstanceName,
      target.subjectSerialNumber,
      target.linkageId,
      target.linkageVersion,
      target.linkedAt,
    ];
    final contextAbsent = installedContextFields.every(
      (value) => value == null,
    );
    if (target.targetKey !=
            _inspectionTargetKey(
              assetClassId: target.assetClassId,
              assetInstanceId: target.assetInstanceId,
              componentNodeId: target.componentNodeId,
              physicalPosition: target.physicalPosition,
              linkageId: target.linkageId,
            ) ||
        (!contextAbsent && !target.hasInstalledInnerCoverContext) ||
        (target.hasInstalledInnerCoverContext &&
            (target.assetTypeKey != 'innerCover' ||
                target.assetNumber != target.hostAssetNumber)) ||
        (target.disposition == InspectionTargetDisposition.observed &&
            (target.lastObservationId == null ||
                target.lastObservedAt == null)) ||
        (target.disposition == InspectionTargetDisposition.pending &&
            target.dispositionReason != null) ||
        (![
              InspectionTargetDisposition.pending,
              InspectionTargetDisposition.observed,
            ].contains(target.disposition) &&
            target.dispositionReason == null)) {
      throw PersistedDataFormatException(
        field: 'disposition',
        source: source,
        detail: 'target disposition evidence is inconsistent',
      );
    }
    if (target.contextReview != null &&
        !target.hasSamePhysicalSubject(target.contextReview!.context)) {
      throw PersistedDataFormatException(
        field: 'contextReview',
        source: source,
        detail: 'review must retain the original physical subject',
      );
    }
    return target;
  }
}
