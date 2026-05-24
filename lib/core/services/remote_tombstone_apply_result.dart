// FILE: lib/core/services/remote_tombstone_apply_result.dart

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
