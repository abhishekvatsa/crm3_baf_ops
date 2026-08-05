// FILE: lib/core/services/remote_tombstone_apply_result.dart

class RemoteTombstoneIntegrityException extends FormatException {
  final String entityLabel;
  final String? firestoreId;

  RemoteTombstoneIntegrityException({
    required this.entityLabel,
    required this.firestoreId,
  }) : super(
         'Remote $entityLabel${firestoreId == null ? '' : ' $firestoreId'} '
         'is marked deleted but has no authoritative deletedAt timestamp.',
       );
}

DateTime requireRemoteTombstoneDeletedAt(
  DateTime? deletedAt, {
  required String entityLabel,
  required String? firestoreId,
}) {
  if (deletedAt != null) return deletedAt;
  throw RemoteTombstoneIntegrityException(
    entityLabel: entityLabel,
    firestoreId: firestoreId,
  );
}

/// Outcome from applying a remote tombstone to the local Isar cache.
///
/// This lets pull orchestration distinguish a genuinely applied delete from a
/// preserved local dirty edit. Without this, pull accounting can report a
/// remote deletion as applied even when the repository correctly skipped it to
/// protect newer unsynced local evidence.
enum RemoteTombstoneApplyOutcome {
  applied,
  localDirtyPreserved,
  localMissing,
  alreadyDeleted,
  notDeletedRemote,
}

class RemoteTombstoneApplyResult {
  final RemoteTombstoneApplyOutcome outcome;
  final Object? localRecord;

  const RemoteTombstoneApplyResult._(this.outcome, [this.localRecord]);

  const RemoteTombstoneApplyResult.applied([Object? localRecord])
      : this._(RemoteTombstoneApplyOutcome.applied, localRecord);

  const RemoteTombstoneApplyResult.localDirtyPreserved(Object localRecord)
      : this._(RemoteTombstoneApplyOutcome.localDirtyPreserved, localRecord);

  const RemoteTombstoneApplyResult.localMissing()
      : this._(RemoteTombstoneApplyOutcome.localMissing);

  const RemoteTombstoneApplyResult.alreadyDeleted([Object? localRecord])
      : this._(RemoteTombstoneApplyOutcome.alreadyDeleted, localRecord);

  const RemoteTombstoneApplyResult.notDeletedRemote()
      : this._(RemoteTombstoneApplyOutcome.notDeletedRemote);
}
