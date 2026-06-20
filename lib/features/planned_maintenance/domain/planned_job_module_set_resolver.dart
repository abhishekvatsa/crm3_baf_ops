// FILE: lib/features/planned_maintenance/domain/planned_job_module_set_resolver.dart

import '../data/job_module_model.dart';

/// Resolves the authoritative local module set for one planned-job execution.
///
/// Firestore document ids are the cross-device identity. Isar integer ids are
/// device-local implementation details and may collide with ids transported
/// from another installation.
class PlannedJobModuleSetResolution {
  final List<JobModuleInstance> modules;

  /// Rows that clearly belong to another remote execution and were only found
  /// because a non-authoritative local integer happened to collide.
  final List<JobModuleInstance> ignoredForeignParentCollisions;

  /// Rows linked by this device-local execution id but lacking the canonical
  /// Firestore parent while the execution itself already has one. These are
  /// not safe to include in a server-governed closure because the server query
  /// cannot see them under the current execution. Callers must fail closed and
  /// repair/reconcile their parent identity before proceeding.
  final List<JobModuleInstance> unresolvedLocalParentModules;

  /// Distinct local rows that claim the same canonical module Firestore id.
  /// Silently choosing one could omit evidence, so callers must fail closed.
  final List<JobModuleInstance> duplicateCanonicalModules;

  const PlannedJobModuleSetResolution({
    required this.modules,
    required this.ignoredForeignParentCollisions,
    required this.unresolvedLocalParentModules,
    required this.duplicateCanonicalModules,
  });

  bool get hasUnresolvedIdentity =>
      unresolvedLocalParentModules.isNotEmpty ||
      duplicateCanonicalModules.isNotEmpty;
}

class PlannedJobModuleSetResolver {
  const PlannedJobModuleSetResolver._();

  static PlannedJobModuleSetResolution resolve({
    required String? executionFirestoreId,
    required int executionLocalId,
    required Iterable<JobModuleInstance> firestoreLinkedModules,
    required Iterable<JobModuleInstance> localLinkedModules,
  }) {
    final canonicalExecutionId = _clean(executionFirestoreId);
    final byKey = <String, JobModuleInstance>{};
    final collisions = <String, JobModuleInstance>{};
    final unresolved = <String, JobModuleInstance>{};
    final duplicateRows = <int, JobModuleInstance>{};

    void addCanonical(JobModuleInstance module) {
      if (module.isDeleted) return;
      final key = _moduleKey(module);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = module;
        return;
      }

      // The same Isar row is expected to appear in both the canonical-parent
      // query and the local-parent query. A different Isar row claiming the
      // same Firestore id is an ambiguity, not a harmless duplicate.
      if (existing.id != module.id) {
        duplicateRows[existing.id] = existing;
        duplicateRows[module.id] = module;
      }

      if (_prefer(module, existing)) {
        byKey[key] = module;
      }
    }

    if (canonicalExecutionId == null) {
      for (final module in localLinkedModules) {
        if (module.isDeleted ||
            module.jobExecutionLocalId != executionLocalId) {
          continue;
        }

        // Even a local-only execution must not absorb a remote-backed child
        // that belongs to some other execution merely because an Isar integer
        // collides. Startup repair should clear this link, but the resolver is
        // independently defensive.
        final moduleRemoteParent = _clean(module.jobExecutionFirestoreId);
        if (moduleRemoteParent != null) {
          collisions.putIfAbsent(_moduleKey(module), () => module);
          continue;
        }
        addCanonical(module);
      }
      return PlannedJobModuleSetResolution(
        modules: byKey.values.toList(growable: false),
        ignoredForeignParentCollisions: collisions.values.toList(
          growable: false,
        ),
        unresolvedLocalParentModules: const <JobModuleInstance>[],
        duplicateCanonicalModules: duplicateRows.values.toList(growable: false),
      );
    }

    for (final module in firestoreLinkedModules) {
      if (_clean(module.jobExecutionFirestoreId) == canonicalExecutionId) {
        addCanonical(module);
      }
    }

    for (final module in localLinkedModules) {
      if (module.isDeleted || module.jobExecutionLocalId != executionLocalId) {
        continue;
      }

      final moduleRemoteParent = _clean(module.jobExecutionFirestoreId);
      if (moduleRemoteParent == canonicalExecutionId) {
        addCanonical(module);
        continue;
      }

      if (moduleRemoteParent == null) {
        unresolved.putIfAbsent(_moduleKey(module), () => module);
        continue;
      }

      collisions.putIfAbsent(_moduleKey(module), () => module);
    }

    return PlannedJobModuleSetResolution(
      modules: byKey.values.toList(growable: false),
      ignoredForeignParentCollisions: collisions.values.toList(growable: false),
      unresolvedLocalParentModules: unresolved.values.toList(growable: false),
      duplicateCanonicalModules: duplicateRows.values.toList(growable: false),
    );
  }

  static bool _prefer(JobModuleInstance candidate, JobModuleInstance current) {
    if (candidate.version != current.version) {
      return candidate.version > current.version;
    }
    return candidate.updatedAt.isAfter(current.updatedAt);
  }

  static String _moduleKey(JobModuleInstance module) {
    final firestoreId = _clean(module.firestoreId);
    return firestoreId == null
        ? 'local:${module.id}'
        : 'firestore:$firestoreId';
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
