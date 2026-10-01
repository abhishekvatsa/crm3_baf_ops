import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance_workflow/data/equipment_status_record.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/inner_cover_lifecycle.dart';
import '../data/inner_cover_workflow_evidence.dart';
import '../data/furnace_stuckup_record.dart';
import '../../maintenance/domain/furnace_stuckup_case.dart';

enum InnerCoverDependencyKind {
  unfit,
  unavailable,
  maintenance,
  red,
  preparation,
  assessment,
}

class InnerCoverDependencyReason {
  const InnerCoverDependencyReason({
    required this.key,
    required this.sourceId,
    required this.kind,
    required this.coverId,
    required this.serialNumber,
    required this.eventHostAssetId,
    required this.eventHostClassId,
    required this.eventHostNumber,
    required this.eventLinkageId,
    required this.awaitingServerConfirmation,
  });
  final String key;
  final String sourceId;
  final InnerCoverDependencyKind kind;
  final String coverId;
  final String serialNumber;
  final String eventHostAssetId;
  final String eventHostClassId;
  final int eventHostNumber;
  final String eventLinkageId;
  final bool awaitingServerConfirmation;
}

class InnerCoverDependencyState {
  InnerCoverDependencyState({
    required this.coverId,
    required this.serialNumber,
    required Iterable<InnerCoverDependencyReason> reasons,
    required Iterable<String> warnings,
    required this.complete,
  }) : reasons = List.unmodifiable(reasons),
       warnings = List.unmodifiable(warnings);
  final String coverId;
  final String serialNumber;
  final List<InnerCoverDependencyReason> reasons;
  final List<String> warnings;
  final bool complete;
  bool get isUnfit =>
      reasons.any((r) => r.kind == InnerCoverDependencyKind.unfit);
  bool get isUnavailable =>
      reasons.any((r) => r.kind == InnerCoverDependencyKind.unavailable);
  bool get hasRedWork =>
      reasons.any((r) => r.kind == InnerCoverDependencyKind.red);
  bool get isAwaitingPreparation =>
      reasons.any((r) => r.kind == InnerCoverDependencyKind.preparation);
  bool get needsCurrentAssessment =>
      reasons.any((r) => r.kind == InnerCoverDependencyKind.assessment);
  bool get isUnderMaintenance => reasons.any(
    (r) => const {
      InnerCoverDependencyKind.maintenance,
      InnerCoverDependencyKind.red,
      InnerCoverDependencyKind.preparation,
    }.contains(r.kind),
  );
  bool get hasRestrictions => reasons.isNotEmpty;
  bool get confirmsNoRestriction => complete && reasons.isEmpty;
}

class InnerCoverDependencies {
  InnerCoverDependencies({
    required Map<String, InnerCoverDependencyState> byCoverId,
    required Iterable<String> evidenceWarnings,
    required this.complete,
  }) : byCoverId = Map.unmodifiable(byCoverId),
       evidenceWarnings = List.unmodifiable(evidenceWarnings);
  final Map<String, InnerCoverDependencyState> byCoverId;
  final List<String> evidenceWarnings;
  final bool complete;
}

/// Positive serial restrictions are retained separately from source completeness.
/// The caller may add them to a CURRENT verified host, but must retain existing
/// recorded-host restrictions and flag moved bindings. This reducer neither
/// clears a Base constraint nor changes an immutable event or workflow identity.
InnerCoverDependencies deriveInnerCoverDependencies({
  required DecodedSnapshotBatch<InnerCoverProfile> profiles,
  required DecodedSnapshotBatch<MaintenanceRecord> tickets,
  required DecodedSnapshotBatch<InnerCoverWorkflowEvidence> workflows,
  required DecodedSnapshotBatch<JobExecution> executions,
  DecodedSnapshotBatch<FurnaceStuckupRecord>? stuckupCases,
}) {
  final warnings = <String>{};
  void qualify<T>(String name, DecodedSnapshotBatch<T> batch) {
    if (!batch.isServerConfirmed || !batch.isComplete) {
      warnings.add('$name evidence is incomplete or not server-confirmed.');
    }
  }

  qualify('Inner Cover profiles', profiles);
  qualify('Issues', tickets);
  qualify('Workflows', workflows);
  qualify('Executions', executions);
  if (stuckupCases != null) qualify('Stuck-up cases', stuckupCases);
  final profileById = <String, InnerCoverProfile>{};
  for (final p in profiles.records) {
    if (profileById.containsKey(p.id) ||
        profiles.records
                .where(
                  (other) =>
                      normalizeInnerCoverSerial(other.serialNumber) ==
                      normalizeInnerCoverSerial(p.serialNumber),
                )
                .length !=
            1) {
      warnings.add(
        'Inner Cover identity is duplicated or conflicting: ${p.id}',
      );
    }
    profileById.putIfAbsent(p.id, () => p);
  }
  final reasons = <String, Map<String, InnerCoverDependencyReason>>{};
  bool matchesProfile(String id, String serial) {
    final found = profiles.records.where((p) => p.id == id).toList();
    if (found.length != 1 ||
        normalizeInnerCoverSerial(found.single.serialNumber) !=
            normalizeInnerCoverSerial(serial)) {
      warnings.add(
        'Serial restriction has an unverified Inner Cover identity: $id',
      );
      return false;
    }
    return true;
  }

  void add(InnerCoverDependencyReason reason) {
    if (matchesProfile(reason.coverId, reason.serialNumber)) {
      reasons.putIfAbsent(reason.coverId, () => {})[reason.key] = reason;
    }
  }

  final ticketGroups = <String, List<MaintenanceRecord>>{};
  for (final ticket in tickets.records) {
    final id = ticket.firestoreId;
    if (id == null || id.trim().isEmpty) {
      if (ticket.assetType == AssetType.innerCover) {
        warnings.add('An Inner Cover issue has no canonical identity.');
      }
      continue;
    }
    ticketGroups.putIfAbsent(id, () => []).add(ticket);
  }
  for (final entry in ticketGroups.entries) {
    final ticketId = entry.key;
    final group = entry.value;
    // A local pending closure must not hide the last server restriction. When
    // several conflicting rows exist, retain all distinct adverse effects.
    if (group.length > 1) warnings.add('Duplicate issue evidence: $ticketId');
    for (final ticket in group) {
      if (ticket.assetType != AssetType.innerCover) continue;
      try {
        if (!ticket.canStillAffectPlantCondition) continue;
        final ref = ticket.assetHierarchyReference;
        final association = ref?.innerCoverAssociation;
        if (ref == null ||
            association == null ||
            association.positionState != InnerCoverPositionState.linked ||
            ref.assetInstanceId != association.baseAssetInstanceId ||
            ref.assetNumber != association.baseAssetNumber ||
            ticket.assetNumber != association.baseAssetNumber) {
          throw StateError(
            'Missing or inconsistent exact event serial/host identity',
          );
        }
        final effect = ticket.effectivePlantConditionEffect;
        final kind = switch (effect) {
          MaintenanceIssuePlantConditionEffect.unfit =>
            InnerCoverDependencyKind.unfit,
          MaintenanceIssuePlantConditionEffect.unavailable =>
            InnerCoverDependencyKind.unavailable,
          _ => null,
        };
        if (kind == null) throw StateError('Unknown generic IC issue effect');
        if (!ticket.isSynced) {
          warnings.add('Issue awaits server confirmation: $ticketId');
        }
        add(
          InnerCoverDependencyReason(
            key: 'issue:$ticketId:${kind.name}',
            sourceId: ticketId,
            kind: kind,
            coverId: association.innerCoverId!,
            serialNumber: association.innerCoverSerialNumber!,
            eventHostAssetId: association.baseAssetInstanceId,
            eventHostClassId: ref.assetClassId,
            eventHostNumber: association.baseAssetNumber,
            eventLinkageId: association.linkageId!,
            awaitingServerConfirmation:
                !ticket.isSynced || !tickets.isServerConfirmed,
          ),
        );
      } on Object catch (_) {
        warnings.add('Issue serial restriction is unverified: $ticketId');
      }
    }
  }
  // Physical separation closes only the obstruction. A confirmed bulging
  // concern still attached to its exact original issue requires fitness review;
  // neither a later stock acceptance nor a deleted ticket settles that issue.
  final seenCases = <String>{};
  if (stuckupCases == null &&
      tickets.records.any(
        (t) => t.classification == furnaceStuckupClassification,
      )) {
    warnings.add(
      'Stuck-up case evidence is unavailable for issue reconciliation.',
    );
  }
  if (stuckupCases != null) {
    for (final ticket in tickets.records.where(
      (t) => t.classification == furnaceStuckupClassification,
    )) {
      try {
        if (!ticket.isDeleted &&
            !ticket.canStillAffectPlantCondition &&
            ticket.isSynced &&
            ticket.isResolved &&
            ticket.status.isTerminal) {
          continue;
        }
      } on Object catch (_) {
        // Malformed closure does not settle the original concern.
      }
      if (stuckupCases.records
              .where(
                (c) =>
                    c.id == ticket.firestoreId &&
                    c.ticketId == ticket.firestoreId,
              )
              .length !=
          1) {
        warnings.add(
          'Original stuck-up issue has no matching case evidence: ${ticket.firestoreId}',
        );
      }
    }
  }
  for (final caseRecord in stuckupCases?.records ?? <FurnaceStuckupRecord>[]) {
    if (!seenCases.add(caseRecord.id)) {
      warnings.add('Duplicate stuck-up case identity: ${caseRecord.id}');
    }
    if (caseRecord.isActive ||
        caseRecord.adjudicationStatus !=
            FurnaceStuckupAdjudicationStatus.confirmed ||
        !const {
          FurnaceStuckupCause.innerCoverBulging,
          FurnaceStuckupCause.combinedCondition,
        }.contains(caseRecord.confirmedCause)) {
      continue;
    }
    final originals = ticketGroups[caseRecord.ticketId] ?? [];
    if (originals.length != 1) {
      warnings.add(
        'Released bulging concern has missing or conflicting original issue evidence: ${caseRecord.id}',
      );
    }
    for (final ticket in originals) {
      try {
        final furnace = ticket.assetHierarchyReference;
        final event = ticket.furnaceStuckupCase;
        final base = event?.baseAssetReference;
        final association = base?.innerCoverAssociation;
        if (caseRecord.id != caseRecord.ticketId ||
            ticket.assetType != AssetType.furnace ||
            ticket.classification != furnaceStuckupClassification ||
            furnace == null ||
            base == null ||
            association == null ||
            caseRecord.baseAssetClassId == null ||
            caseRecord.furnaceAssetClassId == null ||
            caseRecord.innerCoverLinkageId == null ||
            caseRecord.innerCoverAssignmentVersion == null ||
            furnace.assetInstanceId != caseRecord.furnaceAssetInstanceId ||
            furnace.assetClassId != caseRecord.furnaceAssetClassId ||
            furnace.assetNumber != caseRecord.furnaceAssetNumber ||
            ticket.assetNumber != caseRecord.furnaceAssetNumber ||
            base.assetInstanceId != caseRecord.baseAssetInstanceId ||
            base.assetClassId != caseRecord.baseAssetClassId ||
            base.assetNumber != caseRecord.baseAssetNumber ||
            event!.baseNumber != caseRecord.baseAssetNumber ||
            event.suspectedCause != caseRecord.suspectedCause ||
            event.operatingContext != caseRecord.operatingContext ||
            ticket.chargeNoAtEvent != caseRecord.chargeNoAtEvent ||
            !ticket.startDate.isAtSameMomentAs(caseRecord.reportedAt) ||
            association.positionState != InnerCoverPositionState.linked ||
            association.baseAssetInstanceId != caseRecord.baseAssetInstanceId ||
            association.baseAssetNumber != caseRecord.baseAssetNumber ||
            association.innerCoverId != caseRecord.innerCoverId ||
            normalizeInnerCoverSerial(
                  association.innerCoverSerialNumber ?? '',
                ) !=
                normalizeInnerCoverSerial(caseRecord.innerCoverSerialNumber) ||
            association.linkageId != caseRecord.innerCoverLinkageId ||
            association.assignmentVersion !=
                caseRecord.innerCoverAssignmentVersion ||
            !association.eventAt.isAtSameMomentAs(caseRecord.reportedAt) ||
            caseRecord.releasedAt == null ||
            caseRecord.adjudicatedAt == null ||
            caseRecord.releasedAt!.isBefore(caseRecord.reportedAt) ||
            caseRecord.adjudicatedAt!.isBefore(caseRecord.reportedAt) ||
            caseRecord.updatedAt.isBefore(caseRecord.releasedAt!) ||
            caseRecord.updatedAt.isBefore(caseRecord.adjudicatedAt!) ||
            !matchesProfile(
              caseRecord.innerCoverId,
              caseRecord.innerCoverSerialNumber,
            )) {
          throw StateError(
            'Exact original stuck-up issue identity is unverified',
          );
        }
        // A verified withdrawal is not a fitness disposition. Its exact serial
        // and event host remain known, so keep the assessment on that cover
        // without making unrelated covers' evidence incomplete. There is no
        // implied recovery or clearance from withdrawing the original issue.
        if (!ticket.isDeleted && !ticket.canStillAffectPlantCondition) {
          if (!ticket.isSynced ||
              !ticket.isResolved ||
              !ticket.status.isTerminal) {
            throw StateError('Original issue closure is unverified');
          }
          continue;
        }
        if (!ticket.isSynced) {
          warnings.add(
            'Original stuck-up issue awaits server confirmation: ${caseRecord.ticketId}',
          );
        }
        add(
          InnerCoverDependencyReason(
            key: 'fitness:${caseRecord.id}:${caseRecord.ticketId}',
            sourceId: caseRecord.ticketId,
            kind: InnerCoverDependencyKind.assessment,
            coverId: caseRecord.innerCoverId,
            serialNumber: caseRecord.innerCoverSerialNumber,
            eventHostAssetId: caseRecord.baseAssetInstanceId,
            eventHostClassId: base.assetClassId,
            eventHostNumber: caseRecord.baseAssetNumber,
            eventLinkageId: caseRecord.innerCoverLinkageId!,
            awaitingServerConfirmation:
                !ticket.isSynced ||
                !tickets.isServerConfirmed ||
                !stuckupCases!.isServerConfirmed,
          ),
        );
      } on Object catch (_) {
        warnings.add(
          'Released bulging concern requires original issue verification: ${caseRecord.id}',
        );
      }
    }
  }
  final executionGroups = <String, List<JobExecution>>{};
  for (final execution in executions.records) {
    final id = execution.firestoreId;
    if (id == null || id.trim().isEmpty) {
      if (execution.assetType == AssetType.innerCover &&
          !execution.isTerminal) {
        warnings.add(
          'An active Inner Cover execution has no canonical identity.',
        );
      }
      continue;
    }
    executionGroups.putIfAbsent(id, () => []).add(execution);
  }
  final seenWorkflowIds = <String>{};
  final seenExecutionIds = <String>{};
  final coordinationExecutionIds = workflows.records
      .where((w) => w.workflowKind == 'issueCoordination')
      .map((w) => w.executionId)
      .toSet();
  for (final workflow in workflows.records) {
    if (!workflow.concernsInnerCover) continue;
    if (!seenWorkflowIds.add(workflow.id) ||
        !seenExecutionIds.add(workflow.executionId)) {
      warnings.add('Duplicate workflow/execution identity: ${workflow.id}');
    }
    final candidates = executionGroups[workflow.executionId] ?? [];
    final execution = candidates.length == 1 ? candidates.single : null;
    if (execution == null) {
      warnings.add(
        'Workflow parent execution is missing or duplicated: ${workflow.id}',
      );
    }
    if (workflow.isTerminal) {
      if (execution == null ||
          !execution.isSynced ||
          (workflow.status == 'completed' && !execution.isCompleted) ||
          (workflow.status == 'cancelled' && !execution.isCancelled)) {
        warnings.add(
          'Workflow terminal evidence has not reconciled: ${workflow.id}',
        );
      }
      continue;
    }
    final position = workflow.position!;
    var reconciled = false;
    if (execution != null) {
      try {
        final assigned = execution.assignmentInnerCoverPosition;
        reconciled =
            execution.isSynced &&
            execution.workflowSchemaVersion == 1 &&
            !execution.isTerminal &&
            assigned != null &&
            assigned.baseAssetInstanceId == position.baseAssetInstanceId &&
            assigned.baseAssetClassId == position.baseAssetClassId &&
            assigned.baseAssetNumber == position.baseAssetNumber &&
            assigned.innerCoverId == position.innerCoverId &&
            normalizeInnerCoverSerial(assigned.innerCoverSerialNumber) ==
                normalizeInnerCoverSerial(position.innerCoverSerialNumber) &&
            assigned.linkageId == position.linkageId &&
            assigned.assignmentVersion == position.assignmentVersion;
      } on Object catch (_) {
        // Keep the exact aggregate's adverse evidence, but never certify the
        // serial clear from a missing/malformed/contradictory parent snapshot.
      }
    }
    if (!reconciled) {
      warnings.add(
        'Workflow assignment evidence is unverified: ${workflow.id}',
      );
    }
    final kind = workflow.activeRedWork
        ? InnerCoverDependencyKind.red
        : workflow.awaitingPreparation
        ? InnerCoverDependencyKind.preparation
        : InnerCoverDependencyKind.maintenance;
    add(
      InnerCoverDependencyReason(
        key:
            'workflow:${workflow.id}:${kind.name}:'
            '${position.baseAssetInstanceId}:${position.linkageId}',
        sourceId: workflow.id,
        kind: kind,
        coverId: position.innerCoverId,
        serialNumber: position.innerCoverSerialNumber,
        eventHostAssetId: position.baseAssetInstanceId,
        eventHostClassId: position.baseAssetClassId,
        eventHostNumber: position.baseAssetNumber,
        eventLinkageId: position.linkageId,
        awaitingServerConfirmation:
            !reconciled ||
            !workflows.isServerConfirmed ||
            !executions.isServerConfirmed,
      ),
    );
  }
  // An exact open execution without its workflow cannot disappear as clear.
  for (final entry in executionGroups.entries) {
    for (final execution in entry.value) {
      if (execution.assetType == AssetType.innerCover &&
          !execution.isTerminal &&
          !seenExecutionIds.contains(entry.key) &&
          !coordinationExecutionIds.contains(entry.key)) {
        warnings.add(
          'Active Inner Cover execution has no verified workflow: ${entry.key}',
        );
      }
    }
  }
  final complete = warnings.isEmpty;
  return InnerCoverDependencies(
    complete: complete,
    evidenceWarnings: warnings,
    byCoverId: {
      for (final p in profileById.values)
        p.id: InnerCoverDependencyState(
          coverId: p.id,
          serialNumber: p.serialNumber,
          reasons: reasons[p.id]?.values ?? [],
          warnings: warnings,
          complete: complete,
        ),
    },
  );
}

/// Reconciles serial workflow evidence with the existing recorded-host counters.
/// A projection never identifies a serial by itself. Unmatched counters make
/// the population unverified rather than assigning a guessed restriction or
/// declaring any cover clear. Existing adverse reasons are always retained.
InnerCoverDependencies qualifyInnerCoverDependencyProjections(
  InnerCoverDependencies dependencies,
  DecodedSnapshotBatch<EquipmentStatusRecord> projections,
) {
  final warnings = <String>{};
  if (!projections.isServerConfirmed || !projections.isComplete) {
    warnings.add(
      'Equipment projection evidence is incomplete or not server-confirmed.',
    );
  }
  // Each backend workflow contributes to exactly one counter. The Dart
  // openMaintenanceCount decoder maps activeNonRedMaintenanceCount; RED and
  // preparation have their own counters even though all mean maintenance in UI.
  final expected =
      <_InnerCoverEventHost, Map<InnerCoverDependencyKind, Set<String>>>{};
  for (final state in dependencies.byCoverId.values) {
    for (final reason in state.reasons) {
      if (!const {
        InnerCoverDependencyKind.maintenance,
        InnerCoverDependencyKind.red,
        InnerCoverDependencyKind.preparation,
      }.contains(reason.kind)) {
        continue;
      }
      final host = (
        classId: reason.eventHostClassId,
        instanceId: reason.eventHostAssetId,
        number: reason.eventHostNumber,
      );
      expected
          .putIfAbsent(host, () => {})
          .putIfAbsent(reason.kind, () => <String>{})
          .add(reason.sourceId);
    }
  }
  final seenIds = <String>{};
  final seenHosts = <_InnerCoverEventHost>{};
  for (final projection in projections.records) {
    if (projection.assetTypeKey != 'innerCover') continue;
    final id = projection.firestoreId;
    if (id == null ||
        id.trim().isEmpty ||
        !seenIds.add(id) ||
        !projection.isSynced ||
        projection.version < 1) {
      warnings.add(
        'Inner Cover equipment projection identity or revision is unverified.',
      );
    }
    final counters = {
      InnerCoverDependencyKind.maintenance: projection.openMaintenanceCount,
      InnerCoverDependencyKind.red: projection.openRedCount,
      InnerCoverDependencyKind.preparation: projection.awaitingPreparationCount,
    };
    final restricted = counters.values.any((count) => count > 0);
    final stateFromCounters = projection.openRedCount > 0
        ? 'underRED'
        : projection.awaitingPreparationCount > 0
        ? 'awaitingPreparation'
        : projection.openMaintenanceCount > 0
        ? 'underMaintenance'
        : null;
    if (counters.values.any((count) => count < 0) ||
        (stateFromCounters != null &&
            projection.stateKey != stateFromCounters) ||
        (stateFromCounters == null &&
            !const {'available', 'inService'}.contains(projection.stateKey))) {
      warnings.add(
        'Inner Cover equipment projection state and counters disagree: $id',
      );
    }
    final classId = projection.assetClassId;
    final instanceId = projection.assetInstanceId;
    if (classId == null ||
        classId.trim().isEmpty ||
        instanceId == null ||
        instanceId.trim().isEmpty ||
        projection.assetNumber < 1) {
      // A legacy zero-counter row contributes no serial restriction. Positive
      // legacy counters cannot be attached to today's cover using a Base number.
      if (restricted || (classId != null) != (instanceId != null)) {
        warnings.add(
          'Inner Cover equipment projection has no exact recorded host: $id',
        );
      }
      continue;
    }
    final host = (
      classId: classId,
      instanceId: instanceId,
      number: projection.assetNumber,
    );
    if (!seenHosts.add(host)) {
      warnings.add(
        'Duplicate Inner Cover equipment projection host: $instanceId',
      );
    }
    for (final entry in counters.entries) {
      final count = expected[host]?[entry.key]?.length ?? 0;
      if (entry.value != count) {
        warnings.add(
          'Inner Cover ${entry.key.name} projection has unmatched workflow evidence: $instanceId',
        );
      }
    }
  }
  for (final host in expected.keys) {
    if (!seenHosts.contains(host)) {
      warnings.add(
        'Inner Cover workflow has no exact equipment projection: ${host.instanceId}',
      );
    }
  }
  if (warnings.isEmpty) return dependencies;
  final allWarnings = {...dependencies.evidenceWarnings, ...warnings};
  return InnerCoverDependencies(
    complete: false,
    evidenceWarnings: allWarnings,
    byCoverId: {
      for (final entry in dependencies.byCoverId.entries)
        entry.key: InnerCoverDependencyState(
          coverId: entry.value.coverId,
          serialNumber: entry.value.serialNumber,
          reasons: entry.value.reasons,
          warnings: {...entry.value.warnings, ...warnings},
          complete: false,
        ),
    },
  );
}

typedef _InnerCoverEventHost = ({
  String classId,
  String instanceId,
  int number,
});
