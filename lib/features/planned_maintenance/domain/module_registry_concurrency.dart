import '../data/module_registry_model.dart';

class ModuleRegistryDraftExpectation {
  final int version;
  final String contentHash;

  const ModuleRegistryDraftExpectation({
    required this.version,
    required this.contentHash,
  });

  factory ModuleRegistryDraftExpectation.fromRevision(
    ModuleRegistryRevision revision,
  ) {
    return ModuleRegistryDraftExpectation(
      version: revision.version,
      contentHash: revision.contentHash.trim(),
    );
  }
}

class ModuleRegistryStaleDraftException implements Exception {
  final String registryModuleId;
  final String revisionId;
  final ModuleRegistryDraftExpectation expected;
  final ModuleRegistryDraftExpectation actual;

  const ModuleRegistryStaleDraftException({
    required this.registryModuleId,
    required this.revisionId,
    required this.expected,
    required this.actual,
  });

  String get operatorMessage =>
      'This registry draft changed after it was opened. Your edit was not '
      'applied. Reload the current draft, review the newer content, then '
      'either edit that revision or create a separate draft for governed merge.';

  String get diagnosticMessage =>
      '$operatorMessage Registry=$registryModuleId revision=$revisionId '
      'expectedVersion=${expected.version} actualVersion=${actual.version} '
      'expectedHash=${expected.contentHash} actualHash=${actual.contentHash}';

  @override
  String toString() => operatorMessage;
}

void requireCurrentRegistryDraftMatchesExpectation({
  required ModuleRegistryRevision current,
  required ModuleRegistryDraftExpectation expected,
}) {
  final actual = ModuleRegistryDraftExpectation.fromRevision(current);
  if (actual.version == expected.version &&
      actual.contentHash == expected.contentHash) {
    return;
  }

  throw ModuleRegistryStaleDraftException(
    registryModuleId: current.registryModuleId,
    revisionId: current.revisionId,
    expected: expected,
    actual: actual,
  );
}
