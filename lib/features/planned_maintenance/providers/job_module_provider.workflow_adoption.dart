part of 'job_module_provider.dart';

/// The server owns lifecycle versions/times. This path only adopts an actual
/// server read while the transaction still contains the reviewed clean row.
Future<JobModuleInstance> _adoptWorkflowModuleReopen(
  IsarJobModuleRepository repository,
  JobModuleInstance remote,
  AppUser actor,
  JobModuleSaveBaseline expectedLocal,
) async {
  _requireCanModerateModule(actor, ModuleModerationAction.reopen);
  repository._verifyActor?.call(actor);
  final candidate = copyJobModuleForEditing(remote);
  final expected = Map<String, dynamic>.from(
    jsonDecode(expectedLocal.preimageJson) as Map,
  );
  if (candidate.firestoreId == null ||
      candidate.firestoreId != expected['firestoreId'] ||
      candidate.version < 1 ||
      !candidate.fieldDefinitionsReadResult.isValid ||
      !candidate.responsesReadResult.isValid ||
      !candidate.actionsReadResult.isValid) {
    throw StateError(
      'The server module identity or saved evidence needs review.',
    );
  }
  final result = await isar.writeTxn(() async {
    final matches = await isar.jobModuleInstances
        .filter()
        .firestoreIdEqualTo(candidate.firestoreId!)
        .findAll();
    repository._verifyActor?.call(actor);
    if (matches.length != 1 || matches.single.id != expectedLocal.localId) {
      throw StateError(
        'The original local module is missing or ambiguous. The accepted reopen is retained.',
      );
    }
    final current = matches.single;
    if (!current.isSynced) {
      throw StateError(
        'New local module work is pending. It and the accepted reopen are retained.',
      );
    }
    if (jobModuleClientSnapshotsEquivalentForSync(current, candidate)) {
      return current; // A mirror got there first; no increment and no write.
    }
    if (!expectedLocal.matches(current) ||
        candidate.version <= current.version ||
        candidate.updatedAt.isBefore(current.updatedAt)) {
      throw StateError(
        'The module changed during confirmation. Check the saved reopen again after synchronization.',
      );
    }
    candidate
      ..id = current.id
      ..jobExecutionLocalId = current.jobExecutionLocalId
      ..isSynced = true;
    repository._verifyActor?.call(actor);
    await isar.jobModuleInstances.put(candidate);
    repository._verifyActor?.call(
      actor,
    ); // A failed fence rolls the transaction back.
    return candidate;
  });
  repository._verifyActor?.call(actor);
  return result;
}
