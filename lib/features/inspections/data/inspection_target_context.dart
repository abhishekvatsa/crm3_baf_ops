part of 'inspection_campaign.dart';

/// An audited successor to a target's physical context. The original target
/// remains the campaign baseline and owns coverage and reading history.
class InspectionTargetContextReview {
  const InspectionTargetContextReview({
    required this.revision,
    required this.auditId,
    required this.reviewedAt,
    required this.reviewedByUid,
    required this.reviewedByName,
    required this.reason,
    required this.context,
  });

  final int revision;
  final String auditId;
  final DateTime reviewedAt;
  final String reviewedByUid;
  final String reviewedByName;
  final String reason;
  final InspectionCampaignTarget context;

  factory InspectionTargetContextReview.fromMap(
    Object? value, {
    required String source,
  }) {
    if (value is! Map ||
        value['schemaVersion'] != 1 ||
        value['context'] is! Map ||
        (value['context'] as Map)['contextReview'] != null) {
      throw PersistedDataFormatException(
        field: 'contextReview',
        source: source,
        detail: 'unsupported or nested context review',
      );
    }
    final data = value;
    String text(String key) =>
        readRequiredPersistedString(value[key], field: key, source: source);
    return InspectionTargetContextReview(
      revision: readRequiredPersistedInt(
        value['revision'],
        field: 'revision',
        source: source,
        minimum: 1,
      ),
      auditId: text('auditId'),
      reviewedAt: readRequiredPersistedDateTime(
        data['reviewedAt'],
        field: 'reviewedAt',
        source: source,
      ),
      reviewedByUid: text('reviewedByUid'),
      reviewedByName: text('reviewedByName'),
      reason: text('reason'),
      context: InspectionCampaignTarget.fromMap(
        Map<String, dynamic>.from(value['context'] as Map),
        source: '$source.context',
      ),
    );
  }
}

extension InspectionTargetPhysicalIdentity on InspectionCampaignTarget {
  bool hasSamePhysicalSubject(InspectionCampaignTarget other) =>
      assetTypeKey == other.assetTypeKey &&
      assetClassId == other.assetClassId &&
      assetInstanceId == other.assetInstanceId &&
      subjectSerialNumber == other.subjectSerialNumber &&
      componentNodeId == other.componentNodeId &&
      physicalPosition == other.physicalPosition &&
      hostAssetClassId == other.hostAssetClassId &&
      (subjectSerialNumber != null || assetNumber == other.assetNumber);

  Map<String, Object?> get contextIdentity => {
    'assetTypeKey': assetTypeKey,
    'assetClassId': assetClassId,
    'assetInstanceId': assetInstanceId,
    'assetInstanceVersion': assetInstanceVersion,
    'assetInstanceName': assetInstanceName,
    'assetNumber': assetNumber,
    'hostAssetClassId': hostAssetClassId,
    'hostAssetInstanceId': hostAssetInstanceId,
    'hostAssetInstanceVersion': hostAssetInstanceVersion,
    'hostAssetInstanceName': hostAssetInstanceName,
    'hostAssetNumber': hostAssetNumber,
    'subjectSerialNumber': subjectSerialNumber,
    'linkageId': linkageId,
    'linkageVersion': linkageVersion,
    'linkedAt': linkedAt?.toUtc().toIso8601String(),
    'componentNodeId': componentNodeId,
    'physicalPosition': physicalPosition,
  };
}
