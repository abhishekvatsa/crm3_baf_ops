part of 'job_module_provider.dart';

// Preserve unchanged wire evidence after verifying its semantic identity.
extension _RemoteWireEvidence on FirestoreJobModuleRepository {
  Map<String, dynamic> _moduleUpdateData(
    JobModuleInstance module,
    JobModuleInstance before,
    Map<String, dynamic> original,
  ) {
    final data = module.toMap();
    void timestamp(
      String field,
      DateTime? candidate,
      DateTime? existing, {
      bool immutable = false,
    }) {
      final unchanged = candidate == null
          ? existing == null
          : existing != null && candidate.isAtSameMomentAs(existing);
      if (!unchanged && immutable) {
        throw StateError('The module $field origin cannot be changed.');
      }
      if (unchanged) {
        // Isar restores dates in the device zone. Rules correctly pin the raw
        // creation and prior lifecycle evidence, not just its parsed instant.
        if (original.containsKey(field)) {
          data[field] = original[field];
        } else {
          data.remove(field);
        }
      } else {
        // A new lifecycle event remains a real change for Rules to authorize;
        // use an explicit instant instead of a timezone-free device clock.
        data[field] = candidate?.toUtc().toIso8601String();
      }
    }

    timestamp('createdAt', module.createdAt, before.createdAt, immutable: true);
    timestamp('addedAt', module.addedAt, before.addedAt, immutable: true);
    timestamp('submittedAt', module.submittedAt, before.submittedAt);
    timestamp('acceptedAt', module.acceptedAt, before.acceptedAt);
    timestamp('reopenedAt', module.reopenedAt, before.reopenedAt);
    timestamp(
      'notApplicableAt',
      module.notApplicableAt,
      before.notApplicableAt,
    );
    timestamp('deletedAt', module.deletedAt, before.deletedAt);
    data['updatedAt'] = module.updatedAt.toUtc().toIso8601String();
    return data;
  }
}
