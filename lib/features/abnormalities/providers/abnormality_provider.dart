// FILE: lib/features/abnormalities/providers/abnormality_provider.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/persistence/app_database.dart';
import '../data/abnormality_model.dart';
import '../services/charge_abnormality_command_service.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../audit/providers/audit_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../auth/data/user_model.dart';
import '../../../core/services/sync_push_snapshot.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/services/sync_remote_freshness_policy.dart';
import '../../../core/services/global_pull_protocol.dart';
import '../../quality/domain/quality_warning_projection.dart';

part 'abnormality_provider.local.dart';
part 'abnormality_provider.remote.dart';

bool _isRemoteNewerByPolicy(dynamic local, dynamic remote) {
  return SyncRemoteFreshnessPolicy.isRemoteNewer(
    localVersion: local.version as int,
    localUpdatedAt: local.updatedAt as DateTime,
    remoteVersion: remote.version as int,
    remoteUpdatedAt: remote.updatedAt as DateTime,
  );
}

// ─────────────────────────────────────────────────────────────
// DATA TRANSFER OBJECTS
// ─────────────────────────────────────────────────────────────

class PaginatedAbnormalityTypesResult {
  final List<AbnormalityType> records;
  final fs.DocumentSnapshot? lastDoc;

  PaginatedAbnormalityTypesResult({required this.records, this.lastDoc});
}

class PaginatedChargeAbnormalitiesResult {
  final List<ChargeAbnormality> records;
  final fs.DocumentSnapshot? lastDoc;

  PaginatedChargeAbnormalitiesResult({required this.records, this.lastDoc});
}

// ─────────────────────────────────────────────────────────────
// INTERFACE
// ─────────────────────────────────────────────────────────────

abstract class AbnormalityRepository {
  // ── Type master data ───────────────────────────────────────

  Stream<List<AbnormalityType>> watchActiveTypes();
  Stream<List<AbnormalityType>> watchAllTypes();

  Future<List<AbnormalityType>> getActiveTypes();
  Future<List<AbnormalityType>> getAllTypes();
  Future<AbnormalityType?> getTypeById(dynamic id);
  Future<AbnormalityType?> getTypeByFirestoreId(String firestoreId);

  Future<void> saveType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<void> updateType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<void> softDeleteType(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<RemoteTombstoneApplyResult> applyTombstoneFromTypeRemote(
    AbnormalityType remote,
  );

  Future<void> seedDefaultTypes({required AppUser actor});

  // ── Charge abnormality events ──────────────────────────────

  Stream<List<ChargeAbnormality>> watchAbnormalitiesForCharge(
    int sourceChargeNo,
  );

  Future<List<ChargeAbnormality>> getAbnormalitiesForCharge(int sourceChargeNo);

  Future<List<ChargeAbnormality>> getAllAbnormalities();

  Future<ChargeAbnormality?> getAbnormalityById(dynamic id);

  Future<ChargeAbnormality?> getAbnormalityByFirestoreId(String firestoreId);

  Future<void> saveAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<void> updateAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<void> softDeleteAbnormality(
    dynamic id, {
    required AppUser actor,
    AuditContext? auditContext,
  });

  Future<RemoteTombstoneApplyResult> applyTombstoneFromAbnormalityRemote(
    ChargeAbnormality remote,
  );

  // ── Sync helpers: local push side ──────────────────────────

  Future<List<AbnormalityType>> getUnsyncedTypes();
  Future<List<ChargeAbnormality>> getUnsyncedAbnormalities();

  Future<void> markTypeSynced(dynamic id, String firestoreId);
  Future<void> markAbnormalitySynced(dynamic id, String firestoreId);

  Future<void> markTypesSynced(List<int> ids);
  Future<void> markTypesSyncedIfUnchanged(List<SyncPushSnapshot> snapshots);
  Future<void> markAbnormalitiesSynced(List<int> ids);
  Future<void> markAbnormalitiesSyncedIfUnchanged(
    List<SyncPushSnapshot> snapshots,
  );

  // ── Sync helpers: remote pull side ─────────────────────────

  Future<PaginatedAbnormalityTypesResult> getUpdatedTypes({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  });

  Future<PaginatedChargeAbnormalitiesResult> getUpdatedAbnormalities({
    DateTime? since,
    DateTime? through,
    int limit = 500,
    fs.DocumentSnapshot? startAfter,
  });

  Future<List<AbnormalityType>> getTypesByFirestoreIds(
    List<String> firestoreIds,
  );

  Future<List<ChargeAbnormality>> getAbnormalitiesByFirestoreIds(
    List<String> firestoreIds,
  );

  Future<void> insertTypeFromRemote(AbnormalityType remote);
  Future<void> updateTypeFromRemote(AbnormalityType remote);

  Future<void> insertAbnormalityFromRemote(ChargeAbnormality remote);
  Future<void> updateAbnormalityFromRemote(ChargeAbnormality remote);
  Future<bool> applyAbnormalityServerReadbackIfUnchanged(
    ChargeAbnormality remote, {
    required SyncPushSnapshot expectedLocal,
    required bool expectedLocalSynced,
  });

  Future<void> batchUpsertTypes(List<AbnormalityType> records);
  Future<void> batchUpsertAbnormalities(List<ChargeAbnormality> records);
}

void _requireCanManageAbnormalityTypes(AppUser actor) {
  if (!actor.canManageAbnormalityTypes) {
    throw StateError('Not authorized to manage abnormality type master data.');
  }
}

void _requireCanLogChargeAbnormality(AppUser actor) {
  if (!actor.canLogChargeAbnormality) {
    throw StateError('Not authorized to log charge abnormalities.');
  }
}

void _requireCanEditChargeAbnormality(AppUser actor) {
  if (!actor.canEditChargeAbnormality) {
    throw StateError('Not authorized to edit charge abnormalities.');
  }
}

void _requireCanSoftDeleteChargeAbnormality(AppUser actor) {
  if (!actor.canSoftDeleteChargeAbnormality) {
    throw StateError('Not authorized to delete charge abnormalities.');
  }
}

// ─────────────────────────────────────────────────────────────
// ISAR IMPLEMENTATION
// ─────────────────────────────────────────────────────────────

final isarAbnormalityRepoProvider = Provider<IsarAbnormalityRepository>(
  (ref) => IsarAbnormalityRepository(
    auditRepository: ref.read(auditRepositoryProvider),
  ),
);

final firestoreAbnormalityRepoProvider =
    Provider<FirestoreAbnormalityRepository>(
      (ref) => FirestoreAbnormalityRepository(
        auditRepository: ref.read(auditRepositoryProvider),
      ),
    );

final chargeAbnormalityCommandServiceProvider =
    Provider<ChargeAbnormalityCommandService>(
      (ref) => ChargeAbnormalityCommandService(),
    );

final abnormalityRepositoryProvider = Provider<AbnormalityRepository>((ref) {
  if (kIsWeb) {
    return ref.watch(firestoreAbnormalityRepoProvider);
  }
  return ref.watch(isarAbnormalityRepoProvider);
});

final activeAbnormalityTypesProvider = StreamProvider<List<AbnormalityType>>((
  ref,
) {
  return ref.watch(abnormalityRepositoryProvider).watchActiveTypes();
});

final allAbnormalityTypesProvider = StreamProvider<List<AbnormalityType>>((
  ref,
) {
  return ref.watch(abnormalityRepositoryProvider).watchAllTypes();
});

final abnormalitiesForChargeProvider =
    StreamProvider.family<List<ChargeAbnormality>, int>((ref, sourceChargeNo) {
      return ref
          .watch(abnormalityRepositoryProvider)
          .watchAbnormalitiesForCharge(sourceChargeNo);
    });

// ─────────────────────────────────────────────────────────────
// PUBLIC COPY / NORMALIZATION HELPERS
// ─────────────────────────────────────────────────────────────

/// Creates a detached abnormality-type copy for safe edit dialogs.
AbnormalityType copyAbnormalityType(AbnormalityType source) {
  final copy =
      AbnormalityType()
        ..id = source.id
        ..firestoreId = source.firestoreId
        ..code = source.code
        ..title = source.title
        ..description = source.description
        ..category = source.category
        ..severity = source.severity
        ..applicableAssetTypeIndexes = [...source.applicableAssetTypeIndexes]
        ..suggestsReannealing = source.suggestsReannealing
        ..isActive = source.isActive
        ..isDeleted = source.isDeleted
        ..deletedAt = source.deletedAt
        ..deletedByUid = source.deletedByUid
        ..deletedByName = source.deletedByName
        ..deleteReason = source.deleteReason
        ..version = source.version
        ..isSynced = source.isSynced
        ..createdAt = source.createdAt
        ..updatedAt = source.updatedAt
        ..createdByUid = source.createdByUid
        ..createdByName = source.createdByName
        ..lastEditedByUid = source.lastEditedByUid
        ..lastEditedByName = source.lastEditedByName;

  _normalizeType(copy);
  return copy;
}

/// Creates a detached charge-abnormality copy for safe edit dialogs.
ChargeAbnormality copyChargeAbnormality(ChargeAbnormality source) {
  final copy =
      ChargeAbnormality()
        ..id = source.id
        ..firestoreId = source.firestoreId
        ..sourceChargeNo = source.sourceChargeNo
        ..abnormalityTypeId = source.abnormalityTypeId
        ..abnormalityTypeTitle = source.abnormalityTypeTitle
        ..abnormalityTypeCode = source.abnormalityTypeCode
        ..category = source.category
        ..severity = source.severity
        ..affectedAssetsJson = source.affectedAssetsJson
        ..component = source.component
        ..observedReason = source.observedReason
        ..description = source.description
        ..possibleRootReasonCategory = source.possibleRootReasonCategory
        ..possibleRootReasonNotes = source.possibleRootReasonNotes
        ..reannealingStatus = source.reannealingStatus
        ..reannealedToChargeNo = source.reannealedToChargeNo
        ..loggedAt = source.loggedAt
        ..updatedAt = source.updatedAt
        ..loggedByUid = source.loggedByUid
        ..loggedByName = source.loggedByName
        ..updatedByUid = source.updatedByUid
        ..updatedByName = source.updatedByName
        ..linkedTicketFirestoreId = source.linkedTicketFirestoreId
        ..linkedExecutionFirestoreId = source.linkedExecutionFirestoreId
        ..version = source.version
        ..isSynced = source.isSynced
        ..isDeleted = source.isDeleted
        ..deletedAt = source.deletedAt
        ..deletedByUid = source.deletedByUid
        ..deletedByName = source.deletedByName
        ..deleteReason = source.deleteReason;

  _normalizeAbnormality(copy);
  return copy;
}

// ─────────────────────────────────────────────────────────────
// PRIVATE HELPERS
// ─────────────────────────────────────────────────────────────

int _sortTypes(AbnormalityType a, AbnormalityType b) {
  final activeCompare = (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
  if (activeCompare != 0) return activeCompare;

  final categoryCompare = a.category.name.compareTo(b.category.name);
  if (categoryCompare != 0) return categoryCompare;

  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

int _sortAbnormalities(ChargeAbnormality a, ChargeAbnormality b) {
  final dateCompare = b.loggedAt.compareTo(a.loggedAt);
  if (dateCompare != 0) return dateCompare;

  return b.updatedAt.compareTo(a.updatedAt);
}

void _validateTypeForSave(AbnormalityType type) {
  _normalizeType(type);

  _requireLocalText(type.code, 'code', maximum: 160);
  _requireLocalText(type.title, 'title', maximum: 500);
  _requireOptionalLocalText(type.description, 'description', maximum: 4000);
  _requireLocalText(type.createdByUid, 'createdByUid', maximum: 512);
  _requireOptionalLocalText(type.createdByName, 'createdByName', maximum: 500);
  _requireLocalText(type.lastEditedByUid, 'lastEditedByUid', maximum: 512);
  _requireOptionalLocalText(
    type.lastEditedByName,
    'lastEditedByName',
    maximum: 500,
  );
  if (type.version <= 0) {
    throw ArgumentError.value(type.version, 'version', 'must be positive');
  }
  if (type.updatedAt.isBefore(type.createdAt)) {
    throw ArgumentError.value(
      type.updatedAt,
      'updatedAt',
      'cannot precede createdAt',
    );
  }
  final indexes = type.applicableAssetTypeIndexes;
  if (indexes.toSet().length != indexes.length ||
      indexes.any((index) => index < 0 || index >= AssetType.values.length)) {
    throw ArgumentError.value(
      indexes,
      'applicableAssetTypeIndexes',
      'must contain unique supported asset types',
    );
  }
  if (type.isDeleted) {
    if (type.isActive || type.deletedAt == null) {
      throw ArgumentError(
        'Deleted abnormality types require inactive state and deletedAt.',
      );
    }
    _requireLocalText(type.deletedByUid, 'deletedByUid', maximum: 512);
    _requireOptionalLocalText(
      type.deletedByName,
      'deletedByName',
      maximum: 500,
    );
    _requireOptionalLocalText(type.deleteReason, 'deleteReason', maximum: 2000);
    _requireLocalDeletionTimeline(
      createdAt: type.createdAt,
      updatedAt: type.updatedAt,
      deletedAt: type.deletedAt!,
    );
  } else if (type.deletedAt != null ||
      type.deletedByUid != null ||
      type.deletedByName != null ||
      type.deleteReason != null) {
    throw ArgumentError(
      'Non-deleted abnormality types cannot carry deletion state.',
    );
  }
}

void _validateAbnormalityForSave(ChargeAbnormality abnormality) {
  _normalizeAbnormality(abnormality);

  if (abnormality.sourceChargeNo <= 0) {
    throw ArgumentError.value(
      abnormality.sourceChargeNo,
      'sourceChargeNo',
      'must be positive',
    );
  }
  _requireLocalText(
    abnormality.abnormalityTypeId,
    'abnormalityTypeId',
    maximum: 512,
  );
  _requireLocalText(
    abnormality.abnormalityTypeTitle,
    'abnormalityTypeTitle',
    maximum: 500,
  );
  _requireLocalText(
    abnormality.abnormalityTypeCode,
    'abnormalityTypeCode',
    maximum: 160,
  );
  _requireOptionalLocalText(abnormality.component, 'component', maximum: 200);
  _requireLocalText(
    abnormality.observedReason,
    'observedReason',
    maximum: 2000,
  );
  _requireOptionalLocalText(
    abnormality.description,
    'description',
    maximum: 4000,
  );
  _requireOptionalLocalText(
    abnormality.possibleRootReasonNotes,
    'possibleRootReasonNotes',
    maximum: 4000,
  );
  _requireLocalText(abnormality.loggedByUid, 'loggedByUid', maximum: 512);
  _requireOptionalLocalText(
    abnormality.loggedByName,
    'loggedByName',
    maximum: 500,
  );
  _requireLocalText(abnormality.updatedByUid, 'updatedByUid', maximum: 512);
  _requireOptionalLocalText(
    abnormality.updatedByName,
    'updatedByName',
    maximum: 500,
  );
  _requireOptionalLocalText(
    abnormality.linkedTicketFirestoreId,
    'linkedTicketFirestoreId',
    maximum: 512,
  );
  _requireOptionalLocalText(
    abnormality.linkedExecutionFirestoreId,
    'linkedExecutionFirestoreId',
    maximum: 512,
  );
  if (abnormality.version <= 0) {
    throw ArgumentError.value(
      abnormality.version,
      'version',
      'must be positive',
    );
  }
  if (abnormality.updatedAt.isBefore(abnormality.loggedAt)) {
    throw ArgumentError.value(
      abnormality.updatedAt,
      'updatedAt',
      'cannot precede loggedAt',
    );
  }
  final affectedAssets = abnormality.affectedAssets;
  if (affectedAssets.length > 50) {
    throw ArgumentError.value(
      affectedAssets.length,
      'affectedAssets',
      'must contain at most 50 assets',
    );
  }
  final assetIdentities = <String>{};
  for (final asset in affectedAssets) {
    if (asset.assetNumber <= 0) {
      throw ArgumentError.value(
        asset.assetNumber,
        'affectedAssets',
        'asset numbers must be positive',
      );
    }
    final identity = '${asset.assetType.name}:${asset.assetNumber}';
    if (!assetIdentities.add(identity)) {
      throw ArgumentError.value(
        identity,
        'affectedAssets',
        'must not contain duplicate assets',
      );
    }
  }
  final completed =
      abnormality.reannealingStatus == ReannealingStatus.completed;
  final hasTarget = abnormality.reannealedToChargeNo != null;
  if (completed != hasTarget ||
      (abnormality.reannealedToChargeNo ?? 1) <= 0 ||
      abnormality.reannealedToChargeNo == abnormality.sourceChargeNo) {
    throw ArgumentError(
      'Completed re-annealing requires a distinct positive target charge.',
    );
  }
  if (abnormality.isDeleted) {
    if (abnormality.deletedAt == null) {
      throw ArgumentError('Deleted abnormalities require deletedAt.');
    }
    _requireLocalText(abnormality.deletedByUid, 'deletedByUid', maximum: 512);
    _requireLocalText(abnormality.deletedByName, 'deletedByName', maximum: 500);
    _requireLocalText(abnormality.deleteReason, 'deleteReason', maximum: 500);
    _requireLocalDeletionTimeline(
      createdAt: abnormality.loggedAt,
      updatedAt: abnormality.updatedAt,
      deletedAt: abnormality.deletedAt!,
    );
  } else if (abnormality.deletedAt != null ||
      abnormality.deletedByUid != null ||
      abnormality.deletedByName != null ||
      abnormality.deleteReason != null) {
    throw ArgumentError('Active abnormalities cannot carry deletion state.');
  }
}

String? _cleanOptionalText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

void _requireLocalText(String? value, String field, {required int maximum}) {
  if (value == null || value.trim().isEmpty) {
    throw ArgumentError.value(value, field, 'must be a non-empty string');
  }
  if (value.length > maximum) {
    throw ArgumentError.value(
      value,
      field,
      'must not exceed $maximum characters',
    );
  }
}

void _requireOptionalLocalText(
  String? value,
  String field, {
  required int maximum,
}) {
  if (value != null) {
    _requireLocalText(value, field, maximum: maximum);
  }
}

void _requireLocalDeletionTimeline({
  required DateTime createdAt,
  required DateTime updatedAt,
  required DateTime deletedAt,
}) {
  if (deletedAt.isBefore(createdAt) || deletedAt.isAfter(updatedAt)) {
    throw ArgumentError.value(
      deletedAt,
      'deletedAt',
      'must fall between the creation and update timestamps',
    );
  }
}

void _normalizeType(AbnormalityType type) {
  type
    ..code = type.code.trim().toUpperCase()
    ..title = type.title.trim()
    ..description = _cleanOptionalText(type.description)
    ..deletedByUid = _cleanOptionalText(type.deletedByUid)
    ..deletedByName = _cleanOptionalText(type.deletedByName)
    ..deleteReason = _cleanOptionalText(type.deleteReason)
    ..createdByUid = _cleanOptionalText(type.createdByUid)
    ..createdByName = _cleanOptionalText(type.createdByName)
    ..lastEditedByUid = _cleanOptionalText(type.lastEditedByUid)
    ..lastEditedByName = _cleanOptionalText(type.lastEditedByName);

  type.applicableAssetTypeIndexes.sort();
}

void _normalizeAbnormality(ChargeAbnormality abnormality) {
  abnormality
    ..abnormalityTypeId = abnormality.abnormalityTypeId.trim()
    ..abnormalityTypeCode = abnormality.abnormalityTypeCode.trim()
    ..abnormalityTypeTitle = abnormality.abnormalityTypeTitle.trim()
    ..component = _cleanOptionalText(abnormality.component)
    ..observedReason = abnormality.observedReason.trim()
    ..description = _cleanOptionalText(abnormality.description)
    ..possibleRootReasonNotes = _cleanOptionalText(
      abnormality.possibleRootReasonNotes,
    )
    ..loggedByUid = _cleanOptionalText(abnormality.loggedByUid)
    ..loggedByName = _cleanOptionalText(abnormality.loggedByName)
    ..updatedByUid = _cleanOptionalText(abnormality.updatedByUid)
    ..updatedByName = _cleanOptionalText(abnormality.updatedByName)
    ..linkedTicketFirestoreId = _cleanOptionalText(
      abnormality.linkedTicketFirestoreId,
    )
    ..linkedExecutionFirestoreId = _cleanOptionalText(
      abnormality.linkedExecutionFirestoreId,
    )
    ..deletedByUid = _cleanOptionalText(abnormality.deletedByUid)
    ..deletedByName = _cleanOptionalText(abnormality.deletedByName)
    ..deleteReason = _cleanOptionalText(abnormality.deleteReason);
}

Map<String, dynamic>? _sanitizeForAudit(Map<String, dynamic>? data) {
  if (data == null) return null;

  final sanitized = <String, dynamic>{};

  data.forEach((key, value) {
    if (value is fs.Timestamp) {
      sanitized[key] = value.toDate().toIso8601String();
    } else if (value is fs.DocumentReference) {
      sanitized[key] = value.path;
    } else if (value is fs.GeoPoint) {
      sanitized[key] = {
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    } else if (value is Iterable) {
      sanitized[key] =
          value.map((item) {
            if (item is fs.Timestamp) return item.toDate().toIso8601String();
            if (item is fs.DocumentReference) return item.path;
            if (item is Map) return Map<String, dynamic>.from(item);
            return item;
          }).toList();
    } else if (value is Map) {
      sanitized[key] = Map<String, dynamic>.from(value);
    } else {
      sanitized[key] = value;
    }
  });

  return sanitized;
}

void _logAudit({
  required AuditRepository auditRepository,
  required String entityType,
  required String entityId,
  required AuditAction action,
  required AuditContext context,
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
}) {
  unawaited(
    auditRepository.log(
      AuditEvent.fromContext(
        entityType: entityType,
        entityId: entityId,
        action: action,
        context: context.copyWith(before: before, after: after),
      ),
    ),
  );
}
