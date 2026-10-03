import 'dart:convert';

import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../auth/data/user_model.dart';
import '../data/template_governance_model.dart';
import '../domain/template_publication_readiness.dart';

/// Authenticated server-only reads, deliberately independent of pull cursors and
/// the most-recent-100 live listener. Implementations must reject cached data.
abstract interface class TemplateActiveVersionRemoteReader {
  Future<TemplatePackage> package(String id);
  Future<TemplateVersion> version(String id);
  Future<List<TemplatePublishAudit>> audits(String versionId);
}

class TemplateActiveVersionRefreshException implements Exception {
  const TemplateActiveVersionRefreshException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TemplateActiveVersionRefresh {
  const TemplateActiveVersionRefresh({
    required this.actor,
    required this.remote,
    required this.localPackages,
    required this.localVersion,
    required this.localAudits,
    required this.apply,
  });

  final AppUser? Function() actor;
  final TemplateActiveVersionRemoteReader remote;
  final Future<List<TemplatePackage>> Function() localPackages;
  final Future<TemplateVersion?> Function(String) localVersion;
  final Future<List<TemplatePublishAudit>> Function(String) localAudits;

  /// The callback must run inside the native transaction before any write.
  final Future<RemoteRecordApplyResult<TemplateVersion>> Function(
    TemplateVersion version,
    Future<void> Function() admission,
  )
  apply;

  Future<TemplatePublicationReadinessDecision> refresh({
    required String packageId,
    required String versionId,
  }) async {
    if (!_validId(packageId) || !_validId(versionId)) {
      throw const TemplateActiveVersionRefreshException(
        'The published catalogue identity is missing. Ask an administrator to review it.',
      );
    }
    final uid = _requireActor();
    void checkActor() {
      if (_requireActor() != uid) {
        throw const TemplateActiveVersionRefreshException(
          'The signed-in user changed. Reopen the catalogue before refreshing.',
        );
      }
    }

    Future<TemplatePackage> checkedLocalPackage() async {
      checkActor();
      final rows = (await localPackages())
          .where((row) => row.firestoreId == packageId)
          .toList();
      checkActor();
      if (rows.length != 1 ||
          !rows.single.isSynced ||
          rows.single.isDeleted ||
          rows.single.lifecycleStatus !=
              TemplatePackageLifecycleStatus.active ||
          rows.single.activeVersionFirestoreId != versionId) {
        throw const TemplateActiveVersionRefreshException(
          'The selected package changed or has unconfirmed work. Sync it and select it again; saved work is retained.',
        );
      }
      return rows.single;
    }

    final initial = await checkedLocalPackage();
    final localBinding = jsonEncode(initial.toMap());
    final serverPackage = await remote.package(packageId);
    checkActor();
    final serverBinding = jsonEncode(serverPackage.toMap());
    if (serverPackage.firestoreId != packageId ||
        serverPackage.activeVersionFirestoreId != versionId) {
      throw const TemplateActiveVersionRefreshException(
        'The active publication changed on the server. Sync the package and select it again.',
      );
    }
    final serverVersion = await remote.version(versionId);
    checkActor();
    final serverAudits = await remote.audits(versionId);
    checkActor();
    if (serverVersion.firestoreId != versionId) {
      throw const TemplateActiveVersionRefreshException(
        'The publication identity does not match. Ask an administrator to review it.',
      );
    }
    _requireReady(serverPackage, serverVersion, serverAudits);
    final finalServerPackage = await remote.package(packageId);
    checkActor();
    if (finalServerPackage.firestoreId != packageId ||
        !finalServerPackage.isSynced ||
        jsonEncode(finalServerPackage.toMap()) != serverBinding) {
      throw const TemplateActiveVersionRefreshException(
        'The active publication changed during refresh. Select the package again.',
      );
    }
    Future<void> admission() async {
      final current = await checkedLocalPackage();
      if (jsonEncode(current.toMap()) != localBinding) {
        throw const TemplateActiveVersionRefreshException(
          'The selected package changed during refresh. Saved work is retained; select the package again.',
        );
      }
      // The existing local publication audit must also remain qualified. This
      // repair never overwrites package/audit rows or dirty/unknown versions.
      final audits = await localAudits(versionId);
      checkActor();
      _requireReady(current, serverVersion, audits);
      final existing = await localVersion(versionId);
      checkActor();
      if (existing != null &&
          (!existing.isSynced ||
              _versionBinding(existing) != _versionBinding(serverVersion))) {
        throw const TemplateActiveVersionRefreshException(
          'A different or unsynchronized local version is retained. Ask an administrator to review it; refresh has not replaced it.',
        );
      }
    }

    await admission();
    final result = await apply(serverVersion, admission);
    checkActor();
    if (result.outcome != RemoteRecordApplyOutcome.inserted &&
        result.outcome != RemoteRecordApplyOutcome.unchanged) {
      throw const TemplateActiveVersionRefreshException(
        'The local catalogue needs review. Saved work is retained and assignment remains blocked.',
      );
    }
    final finalLocalPackage = await checkedLocalPackage();
    final restored = await localVersion(versionId);
    final audits = await localAudits(versionId);
    checkActor();
    return _requireReady(finalLocalPackage, restored, audits);
  }

  // Isar restores DateTime values in local time. Normalize only these typed
  // timestamp representations; payload JSON and every other field stay exact.
  static String _versionBinding(TemplateVersion version) => jsonEncode({
    ...version.toMap(),
    'createdAt': version.createdAt.toUtc().toIso8601String(),
    'updatedAt': version.updatedAt.toUtc().toIso8601String(),
    'publishedAt': version.publishedAt?.toUtc().toIso8601String(),
    'retiredAt': version.retiredAt?.toUtc().toIso8601String(),
    'deletedAt': version.deletedAt?.toUtc().toIso8601String(),
    'closureReviewConfirmedAt': version.closureReviewConfirmedAt
        ?.toUtc()
        .toIso8601String(),
  });

  String _requireActor() {
    final current = actor();
    if (current == null ||
        !current.canAssignJobExecution ||
        current.uid.isEmpty) {
      throw const TemplateActiveVersionRefreshException(
        'Approved assignment access is required. Verify your signed-in account and try again.',
      );
    }
    return current.uid;
  }

  static bool _validId(String value) =>
      value.isNotEmpty &&
      value == value.trim() &&
      !value.contains('/') &&
      value != '.' &&
      value != '..';

  static TemplatePublicationReadinessDecision _requireReady(
    TemplatePackage package,
    TemplateVersion? version,
    Iterable<TemplatePublishAudit> audits,
  ) {
    final result = evaluateTemplatePublicationReadiness(
      package: package,
      version: version,
      audits: audits,
    );
    if (!result.isReady) {
      throw TemplateActiveVersionRefreshException(
        '${result.operatorMessage} Saved work is retained; ask an administrator to review the catalogue if this persists.',
      );
    }
    return result;
  }
}
