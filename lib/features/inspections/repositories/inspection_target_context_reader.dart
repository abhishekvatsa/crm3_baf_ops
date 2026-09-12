part of 'inspection_repository.dart';

/// Server evidence for an explicit review. The mutation repeats these reads
/// transactionally; a changing installation cannot be approved from this draft.
Future<Map<String, Object?>> _readInspectionTargetContext(
  FirebaseFirestore firestore,
  InspectionCampaignTarget original,
) async {
  const source = 'InspectionTargetContextReview';
  String text(Map<String, dynamic> row, String field) =>
      readRequiredPersistedString(row[field], field: field, source: source);
  int number(Map<String, dynamic> row, String field) =>
      readRequiredPersistedInt(
        row[field],
        field: field,
        source: source,
        minimum: 1,
      );
  Future<Map<String, dynamic>> row(String collection, String id) async {
    final snapshot = await firestore
        .collection(collection)
        .doc(id)
        .get(InspectionRepository._serverRead);
    final data = snapshot.data();
    if (!snapshot.exists ||
        data == null ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites) {
      throw StateError(
        'Current physical identity could not be verified. Reconnect and try again.',
      );
    }
    return data;
  }

  final result = Map<String, Object?>.from(original.contextIdentity);
  if (!original.hasInstalledInnerCoverContext) {
    final asset = await row('asset_instances', original.assetInstanceId);
    if (asset['assetInstanceId'] != original.assetInstanceId ||
        asset['assetClassId'] != original.assetClassId ||
        asset['assetNumber'] != original.assetNumber ||
        asset['status'] != 'active') {
      throw StateError(
        'The original physical asset is no longer an active matching target.',
      );
    }
    result['assetInstanceVersion'] = number(asset, 'version');
    result['assetInstanceName'] = text(asset, 'name');
    return Map.unmodifiable(result);
  }
  // Locate the original serial first, never the present occupant of its old Base.
  final cover = await row('inner_cover_profiles', original.assetInstanceId);
  if (cover['innerCoverId'] != original.assetInstanceId ||
      cover['assetClassId'] != original.assetClassId ||
      cover['serialNumber'] != original.subjectSerialNumber ||
      cover['lifecycleState'] != 'installed') {
    throw StateError(
      'The original Inner Cover must be installed with the same serial before follow-up.',
    );
  }
  final baseId = text(cover, 'currentBaseAssetInstanceId');
  final linkageId = text(cover, 'currentLinkageId');
  final base = await row('asset_instances', baseId);
  final assignment = await row('base_inner_cover_assignments', baseId);
  final linkage = await row('inner_cover_linkages', linkageId);
  final baseNumber = number(base, 'assetNumber');
  final linkedAt = _readInspectionAssignmentLinkedAt(assignment['linkedAt']);
  final installedAt = _readInspectionInstallationTime(linkage['installedAt']);
  if (base['assetInstanceId'] != baseId ||
      base['assetClassId'] != original.hostAssetClassId ||
      base['status'] != 'active' ||
      cover['currentBaseAssetNumber'] != baseNumber ||
      assignment['baseAssetInstanceId'] != baseId ||
      assignment['baseAssetClassId'] != original.hostAssetClassId ||
      assignment['baseAssetNumber'] != baseNumber ||
      assignment['innerCoverId'] != original.assetInstanceId ||
      assignment['innerCoverSerialNumber'] != original.subjectSerialNumber ||
      assignment['linkageId'] != linkageId ||
      linkage['linkageId'] != linkageId ||
      linkage['baseAssetInstanceId'] != baseId ||
      linkage['innerCoverId'] != original.assetInstanceId ||
      linkage['innerCoverSerialNumber'] != original.subjectSerialNumber ||
      linkage['active'] != true ||
      !installedAt.isAtSameMomentAs(linkedAt)) {
    throw StateError(
      'The current Inner Cover installation evidence is inconsistent. Refresh and check its lifecycle record.',
    );
  }
  number(assignment, 'version');
  result.addAll({
    'assetNumber': baseNumber,
    'assetInstanceVersion': number(cover, 'version'),
    'assetInstanceName': 'Inner Cover ${original.subjectSerialNumber}',
    'hostAssetInstanceId': baseId,
    'hostAssetInstanceVersion': number(base, 'version'),
    'hostAssetInstanceName': text(base, 'name'),
    'hostAssetNumber': baseNumber,
    'linkageId': linkageId,
    'linkageVersion': number(linkage, 'version'),
    'linkedAt': linkedAt.toUtc().toIso8601String(),
  });
  return Map.unmodifiable(result);
}

DateTime _readInspectionAssignmentLinkedAt(Object? value) =>
    readRequiredPersistedDateTime(
      value,
      field: 'linkedAt',
      source: 'InspectionTargetContextReview',
    );

DateTime _readInspectionInstallationTime(Object? value) =>
    readRequiredPersistedDateTime(
      value,
      field: 'installedAt',
      source: 'InspectionTargetContextReview',
    );
