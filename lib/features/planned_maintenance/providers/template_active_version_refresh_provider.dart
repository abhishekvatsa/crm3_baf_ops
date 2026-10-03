import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/template_governance_model.dart';
import '../services/template_active_version_refresh.dart';
import 'template_governance_provider.dart';

AppUser? verifiedTemplateRefreshActor(
  AsyncValue<AppUser?> value,
  String? authenticatedUid,
) {
  final access = CurrentActorAccess.resolve(value);
  return access.isReady && access.actor?.uid == authenticatedUid
      ? access.actor
      : null;
}

/// Cached or pending snapshots must never authorize a local cache repair.
void requireConfirmedTemplateRefreshSnapshot({
  required bool exists,
  required bool isFromCache,
  required bool hasPendingWrites,
}) {
  if (!exists || isFromCache || hasPendingWrites) {
    throw const TemplateActiveVersionRefreshException(
      'The server could not confirm this catalogue. Check your connection and retry; saved work is retained.',
    );
  }
}

class FirestoreTemplateActiveVersionReader
    implements TemplateActiveVersionRemoteReader {
  FirestoreTemplateActiveVersionReader(this.firestore);
  final FirebaseFirestore firestore;

  Future<Map<String, dynamic>> _document(String collection, String id) async {
    final snapshot = await firestore
        .collection(collection)
        .doc(id)
        .get(const GetOptions(source: Source.server));
    requireConfirmedTemplateRefreshSnapshot(
      exists: snapshot.exists,
      isFromCache: snapshot.metadata.isFromCache,
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
    );
    return snapshot.data()!;
  }

  @override
  Future<TemplatePackage> package(String id) async =>
      TemplatePackage.fromMap(await _document('template_packages', id), id);

  @override
  Future<TemplateVersion> version(String id) async =>
      TemplateVersion.fromMap(await _document('template_versions', id), id);

  @override
  Future<List<TemplatePublishAudit>> audits(String versionId) async {
    final snapshot = await firestore
        .collection('template_publish_audits')
        .where('versionFirestoreId', isEqualTo: versionId)
        .get(const GetOptions(source: Source.server));
    requireConfirmedTemplateRefreshSnapshot(
      exists: true,
      isFromCache: snapshot.metadata.isFromCache,
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
    );
    return [for (final doc in snapshot.docs) _audit(doc)];
  }

  TemplatePublishAudit _audit(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    requireConfirmedTemplateRefreshSnapshot(
      exists: doc.exists,
      isFromCache: doc.metadata.isFromCache,
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
    return TemplatePublishAudit.fromMap(doc.data(), doc.id);
  }
}

final templateActiveVersionRefreshProvider =
    Provider<TemplateActiveVersionRefresh?>((ref) {
      if (kIsWeb) return null;
      final repository = ref.watch(isarTemplateGovernanceRepo);
      return TemplateActiveVersionRefresh(
        actor: () => verifiedTemplateRefreshActor(
          ref.read(currentAppUserProvider),
          ref.read(firebaseAuthProvider).currentUser?.uid,
        ),
        remote: FirestoreTemplateActiveVersionReader(
          ref.watch(authFirestoreProvider),
        ),
        localPackages: repository.getAllPackages,
        localVersion: repository.getVersionByFirestoreId,
        localAudits: repository.getAuditsForVersion,
        apply: (version, admission) =>
            repository.applyVersionFromRemote(version, beforeApply: admission),
      );
    });
