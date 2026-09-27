part of 'template_governance_provider.dart';

// Preserve unchanged wire evidence after verifying its semantic identity.
extension _RemoteWireEvidence on FirestoreTemplateGovernanceRepository {
  Map<String, dynamic> _packageWriteDataPreservingCreation(
    TemplatePackage record,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = record.toMap();
    if (!snapshot.exists) return data;
    final remoteData = snapshot.data()!;
    final remote = TemplatePackage.fromMap(remoteData, snapshot.id);
    if (!record.createdAt.isAtSameMomentAs(remote.createdAt)) {
      throw StateError(
        'Template package creation time changed. Reload before saving.',
      );
    }
    // Isar reloads dates in the device timezone. Rules pin the original wire
    // value, which may be a local/UTC string or a native Firestore Timestamp.
    // Preserve it only after proving that the candidate retains its instant.
    data['createdAt'] = remoteData['createdAt'];
    return data;
  }

  Map<String, dynamic> _versionWriteDataPreservingCreation(
    TemplateVersion record,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = record.toMap();
    if (!snapshot.exists) return data;
    final remoteData = snapshot.data()!;
    final remote = TemplateVersion.fromMap(remoteData, snapshot.id);
    if (!record.createdAt.isAtSameMomentAs(remote.createdAt)) {
      throw StateError(
        'Template version creation time changed. Reload before saving.',
      );
    }
    data['createdAt'] = remoteData['createdAt'];
    return data;
  }
}
