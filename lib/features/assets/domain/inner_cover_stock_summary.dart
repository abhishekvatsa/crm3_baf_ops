import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../maintenance/domain/furnace_stuckup_case.dart';
import '../../reports/domain/base_inner_cover_register.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/furnace_stuckup_record.dart';
import '../data/inner_cover_lifecycle.dart';
import 'inner_cover_dependencies.dart';

enum InnerCoverStockDisposition {
  installed,
  acceptedUnassigned,
  excluded,
  assessmentRequired,
  unverified,
}

class InnerCoverStockRow {
  const InnerCoverStockRow({
    required this.profile,
    required this.disposition,
    required this.reviewReasons,
    required this.evidenceUnverified,
    required this.activeConfirmedBulging,
    required this.pendingBulgeAssessment,
    required this.bulgeHistory,
    required this.inconclusiveBulgeAssessment,
    this.activeIssueRestriction = false,
    this.activeMaintenanceRestriction = false,
    this.needsCurrentAssessment = false,
  });
  final InnerCoverProfile profile;
  final InnerCoverStockDisposition disposition;
  final List<String> reviewReasons;
  final bool evidenceUnverified;
  final bool activeConfirmedBulging;
  final bool pendingBulgeAssessment;
  final bool bulgeHistory;
  final bool inconclusiveBulgeAssessment;
  final bool activeIssueRestriction;
  final bool activeMaintenanceRestriction;
  final bool needsCurrentAssessment;
}

/// Recorded stock and concerns, never a certification of current physical fitness.
class InnerCoverStockSummary {
  const InnerCoverStockSummary({
    required this.rows,
    required this.inventoryConfirmed,
    required this.linkageConfirmed,
    required this.bulgeEvidenceConfirmed,
    this.dependencyEvidenceConfirmed = false,
  });
  final List<InnerCoverStockRow> rows;
  final bool inventoryConfirmed;
  final bool linkageConfirmed;
  final bool bulgeEvidenceConfirmed;
  final bool dependencyEvidenceConfirmed;
  int? get installed => inventoryConfirmed && linkageConfirmed
      ? rows
            .where((r) => r.disposition == InnerCoverStockDisposition.installed)
            .length
      : null;
  int? get acceptedUnassigned =>
      inventoryConfirmed &&
          linkageConfirmed &&
          bulgeEvidenceConfirmed &&
          dependencyEvidenceConfirmed
      ? rows
            .where(
              (r) =>
                  r.disposition ==
                  InnerCoverStockDisposition.acceptedUnassigned,
            )
            .length
      : null;
  int? get excluded =>
      inventoryConfirmed &&
          linkageConfirmed &&
          bulgeEvidenceConfirmed &&
          dependencyEvidenceConfirmed
      ? rows
            .where((r) => r.disposition == InnerCoverStockDisposition.excluded)
            .length
      : null;
  int? get activeConfirmedBulging =>
      inventoryConfirmed && bulgeEvidenceConfirmed
      ? rows.where((r) => r.activeConfirmedBulging).length
      : null;
  int? get pendingBulgeAssessment =>
      inventoryConfirmed && bulgeEvidenceConfirmed
      ? rows.where((r) => r.pendingBulgeAssessment).length
      : null;
  int? get inconclusiveBulgeAssessment =>
      inventoryConfirmed && bulgeEvidenceConfirmed
      ? rows.where((r) => r.inconclusiveBulgeAssessment).length
      : null;
  int? get bulgeHistory => inventoryConfirmed && bulgeEvidenceConfirmed
      ? rows.where((r) => r.bulgeHistory).length
      : null;
  int? get acceptedUnassignedWithHistory => acceptedUnassigned == null
      ? null
      : rows
            .where(
              (r) =>
                  r.disposition ==
                      InnerCoverStockDisposition.acceptedUnassigned &&
                  r.bulgeHistory,
            )
            .length;
  int get activeIssueRestrictions =>
      rows.where((r) => r.activeIssueRestriction).length;
  int get activeMaintenanceRestrictions =>
      rows.where((r) => r.activeMaintenanceRestriction).length;
  int get unverified => rows.where((r) => r.evidenceUnverified).length;
  int? get assessmentRequired =>
      inventoryConfirmed &&
          linkageConfirmed &&
          bulgeEvidenceConfirmed &&
          dependencyEvidenceConfirmed
      ? rows
            .where(
              (r) =>
                  r.disposition ==
                  InnerCoverStockDisposition.assessmentRequired,
            )
            .length
      : null;
  List<InnerCoverStockRow> get review =>
      rows.where((r) => r.reviewReasons.isNotEmpty).toList(growable: false);
  InnerCoverStockSummary forClass(String id) => InnerCoverStockSummary(
    rows: List.unmodifiable(rows.where((r) => r.profile.assetClassId == id)),
    inventoryConfirmed: inventoryConfirmed,
    linkageConfirmed: linkageConfirmed,
    bulgeEvidenceConfirmed: bulgeEvidenceConfirmed,
    dependencyEvidenceConfirmed: dependencyEvidenceConfirmed,
  );
}

/// Adds recorded work restrictions without mutating stock or certifying fitness.
/// Missing work evidence cannot establish that an accepted cover is a candidate.
InnerCoverStockSummary annotateInnerCoverStockDependencies(
  InnerCoverStockSummary summary,
  InnerCoverDependencies dependencies,
) {
  bool identityMatches(
    InnerCoverStockRow row,
    InnerCoverDependencyState? state,
  ) =>
      state != null &&
      state.coverId == row.profile.id &&
      normalizeInnerCoverSerial(state.serialNumber) ==
          normalizeInnerCoverSerial(row.profile.serialNumber) &&
      state.reasons.every(
        (reason) =>
            reason.coverId == row.profile.id &&
            normalizeInnerCoverSerial(reason.serialNumber) ==
                normalizeInnerCoverSerial(row.profile.serialNumber),
      );
  bool confirmed(InnerCoverStockRow row) {
    final state = dependencies.byCoverId[row.profile.id];
    return identityMatches(row, state) &&
        state!.complete &&
        state.warnings.isEmpty &&
        !state.reasons.any((reason) => reason.awaitingServerConfirmation);
  }

  final complete =
      dependencies.complete &&
      dependencies.evidenceWarnings.isEmpty &&
      summary.rows.every(confirmed);
  final rows = summary.rows
      .map((row) {
        final state = dependencies.byCoverId[row.profile.id];
        final matched = identityMatches(row, state);
        final workReasons = matched
            ? state!.reasons
            : <InnerCoverDependencyReason>[];
        final reasons = <String>{...row.reviewReasons};
        final rowComplete = complete && confirmed(row);
        if (!matched) {
          reasons.add('Issue/maintenance identity missing or conflicting');
        }
        if (!rowComplete) reasons.add('Issue/maintenance evidence unverified');
        for (final reason in workReasons) {
          final label = switch (reason.kind) {
            InnerCoverDependencyKind.unfit => 'Active issue: unfit',
            InnerCoverDependencyKind.unavailable => 'Active issue: unavailable',
            InnerCoverDependencyKind.maintenance => 'Active maintenance',
            InnerCoverDependencyKind.red => 'Active RED work',
            InnerCoverDependencyKind.preparation =>
              'Awaiting maintenance preparation',
            InnerCoverDependencyKind.assessment =>
              'Obstruction released; unresolved confirmed-bulging concern needs fitness assessment',
          };
          reasons.add(
            '$label (${reason.sourceId})'
            '${reason.awaitingServerConfirmation ? ' — awaiting server confirmation' : ''}',
          );
        }
        var disposition = row.disposition;
        if (disposition == InnerCoverStockDisposition.acceptedUnassigned ||
            disposition == InnerCoverStockDisposition.assessmentRequired) {
          disposition =
              workReasons.any(
                (r) => r.kind != InnerCoverDependencyKind.assessment,
              )
              ? InnerCoverStockDisposition.excluded
              : rowComplete
              ? state?.needsCurrentAssessment == true
                    ? InnerCoverStockDisposition.assessmentRequired
                    : disposition
              : InnerCoverStockDisposition.unverified;
        }
        return InnerCoverStockRow(
          profile: row.profile,
          disposition: disposition,
          reviewReasons: List.unmodifiable(reasons),
          evidenceUnverified: row.evidenceUnverified || !rowComplete,
          activeConfirmedBulging: row.activeConfirmedBulging,
          pendingBulgeAssessment: row.pendingBulgeAssessment,
          bulgeHistory: row.bulgeHistory,
          inconclusiveBulgeAssessment: row.inconclusiveBulgeAssessment,
          activeIssueRestriction: workReasons.any(
            (r) => const {
              InnerCoverDependencyKind.unfit,
              InnerCoverDependencyKind.unavailable,
            }.contains(r.kind),
          ),
          activeMaintenanceRestriction: workReasons.any(
            (r) => const {
              InnerCoverDependencyKind.maintenance,
              InnerCoverDependencyKind.red,
              InnerCoverDependencyKind.preparation,
            }.contains(r.kind),
          ),
          needsCurrentAssessment:
              row.needsCurrentAssessment ||
              state?.needsCurrentAssessment == true,
        );
      })
      .toList(growable: false);
  return InnerCoverStockSummary(
    rows: List.unmodifiable(rows),
    inventoryConfirmed: summary.inventoryConfirmed,
    linkageConfirmed: summary.linkageConfirmed,
    bulgeEvidenceConfirmed: summary.bulgeEvidenceConfirmed,
    dependencyEvidenceConfirmed: complete,
  );
}

InnerCoverStockSummary buildInnerCoverStockSummary({
  required DecodedSnapshotBatch<AssetClassRecord> classes,
  required DecodedSnapshotBatch<InnerCoverProfile> profiles,
  required DecodedSnapshotBatch<BaseInnerCoverAssignment> assignments,
  required DecodedSnapshotBatch<InnerCoverLinkage> links,
  required BaseInnerCoverRegister register,
  required DecodedSnapshotBatch<FurnaceStuckupRecord> cases,
  required DecodedSnapshotBatch<AssetConditionDeclarationRecord> declarations,
}) {
  bool qualified<T>(DecodedSnapshotBatch<T> batch) =>
      batch.isComplete && batch.isServerConfirmed;
  String serial(String value) => normalizeInnerCoverSerial(value);
  bool hasAcceptance(InnerCoverProfile p) =>
      p.acceptedAt != null &&
      p.acceptanceReference?.trim().isNotEmpty == true &&
      p.acceptedByUid?.trim().isNotEmpty == true &&
      p.acceptedByName?.trim().isNotEmpty == true;
  bool validIdentity(InnerCoverProfile p) {
    final matchingClasses = classes.records
        .where((c) => c.id == p.assetClassId)
        .toList();
    final projection = [
      p.currentBaseAssetInstanceId,
      p.currentBaseAssetNumber,
      p.currentBaseAssetName,
      p.currentLinkageId,
    ];
    final projectionValid = p.isInstalled
        ? projection.every((v) => v != null)
        : projection.every((v) => v == null);
    return projectionValid &&
        profiles.records.where((c) => c.id == p.id).length == 1 &&
        profiles.records
                .where((c) => serial(c.serialNumber) == serial(p.serialNumber))
                .length ==
            1 &&
        matchingClasses.length == 1 &&
        matchingClasses.single.isActive &&
        matchingClasses.single.legacyAssetTypeKey == 'innerCover' &&
        matchingClasses.single.code == p.assetClassCode &&
        (!const {
              InnerCoverLifecycleState.available,
              InnerCoverLifecycleState.reserved,
              InnerCoverLifecycleState.installed,
            }.contains(p.lifecycleState) ||
            hasAcceptance(p));
  }

  final inventoryConfirmed =
      qualified(classes) &&
      qualified(profiles) &&
      profiles.records.every(validIdentity);
  final linkedRows = register.rows
      .where((r) => r.state == BaseCoverLinkState.linked)
      .toList();
  // The register validates each Base. Also reject orphan claims outside its
  // population, so an unknown Base/cover never becomes evidence of spare stock.
  final linkageConfirmed =
      register.evidenceConfirmed &&
      qualified(assignments) &&
      qualified(links) &&
      register.rows.every(
        (r) =>
            r.state == BaseCoverLinkState.linked ||
            r.state == BaseCoverLinkState.empty,
      ) &&
      assignments.records.every(
        (a) => linkedRows.any((r) => identical(r.assignment, a)),
      ) &&
      links.records
          .where((l) => l.active)
          .every((l) => linkedRows.any((r) => identical(r.linkage, l))) &&
      profiles.records
          .where((p) => p.isInstalled)
          .every((p) => linkedRows.any((r) => identical(r.cover, p)));
  bool evidenceIdentity(String id, String number) =>
      profiles.records
          .where((p) => p.id == id && serial(p.serialNumber) == serial(number))
          .length ==
      1;
  final bulgeEvidenceConfirmed =
      qualified(cases) &&
      qualified(declarations) &&
      cases.records.map((c) => c.id).toSet().length == cases.records.length &&
      declarations.records.map((d) => d.id).toSet().length ==
          declarations.records.length &&
      declarations.records.map((d) => d.assetId).toSet().length ==
          declarations.records.length &&
      cases.records.every(
        (c) =>
            evidenceIdentity(c.innerCoverId, c.innerCoverSerialNumber) &&
            (c.adjudicationStatus !=
                    FurnaceStuckupAdjudicationStatus.confirmed ||
                c.confirmedCause != null),
      ) &&
      declarations.records.every(
        (d) => evidenceIdentity(d.assetId, d.assetSerialNumber),
      );
  bool bulging(FurnaceStuckupCause? cause) => const {
    FurnaceStuckupCause.innerCoverBulging,
    FurnaceStuckupCause.combinedCondition,
  }.contains(cause);
  final rows = <InnerCoverStockRow>[];
  final seenIds = <String>{};
  for (final p in profiles.records) {
    if (!p.countsAsAssetInventory || !seenIds.add(p.id)) continue;
    final reasons = <String>[];
    final identityConfirmed = inventoryConfirmed && validIdentity(p);
    final evidenceUnverified =
        !identityConfirmed || !linkageConfirmed || !bulgeEvidenceConfirmed;
    if (!identityConfirmed) {
      reasons.add('Stock identity or population unverified');
    }
    if (!linkageConfirmed) {
      reasons.add('Assignment/linkage evidence unverified');
    }
    if (!bulgeEvidenceConfirmed) reasons.add('Bulge evidence unverified');
    if (identityConfirmed) {
      if (p.requiresReacceptance) reasons.add('Reacceptance required');
      if (!p.isInstalled &&
          p.lifecycleState != InnerCoverLifecycleState.available) {
        reasons.add('Not a spare candidate: ${p.lifecycleState.label}');
      }
    }
    final coverCases = cases.records.where((c) => c.innerCoverId == p.id);
    final concernsQualified = identityConfirmed && bulgeEvidenceConfirmed;
    final activeConfirmedBulging =
        concernsQualified &&
        coverCases.any(
          (c) =>
              c.isActive &&
              c.adjudicationStatus ==
                  FurnaceStuckupAdjudicationStatus.confirmed &&
              bulging(c.confirmedCause),
        );
    final pendingActive =
        concernsQualified &&
        coverCases.any(
          (c) => c.needsAdjudication && c.isActive && bulging(c.suspectedCause),
        );
    final pendingReleased =
        concernsQualified &&
        coverCases.any(
          (c) =>
              c.needsAdjudication && !c.isActive && bulging(c.suspectedCause),
        );
    final history =
        concernsQualified &&
        (p.retirementCondition == InnerCoverRetirementCondition.bulged ||
            declarations.records.any((d) => d.assetId == p.id) ||
            coverCases.any(
              (c) =>
                  c.adjudicationStatus ==
                      FurnaceStuckupAdjudicationStatus.confirmed &&
                  bulging(c.confirmedCause),
            ));
    final inconclusive =
        concernsQualified &&
        coverCases.any(
          (c) =>
              c.adjudicationStatus ==
                  FurnaceStuckupAdjudicationStatus.inconclusive &&
              bulging(c.suspectedCause),
        );
    final activeInconclusive =
        concernsQualified &&
        coverCases.any(
          (c) =>
              c.isActive &&
              c.adjudicationStatus ==
                  FurnaceStuckupAdjudicationStatus.inconclusive &&
              bulging(c.suspectedCause),
        );
    if (inconclusive) {
      final active = coverCases.any(
        (c) =>
            c.isActive &&
            c.adjudicationStatus ==
                FurnaceStuckupAdjudicationStatus.inconclusive &&
            bulging(c.suspectedCause),
      );
      reasons.add(
        active
            ? 'Active obstruction; bulge assessment inconclusive'
            : 'Released obstruction; bulge assessment inconclusive',
      );
    }
    if (activeConfirmedBulging) {
      reasons.add('Active obstruction with confirmed bulging');
    }
    if (pendingActive) reasons.add('Bulging suspected — assessment pending');
    if (pendingReleased) {
      reasons.add('Released obstruction; bulge assessment pending');
    }
    if (history) reasons.add('Bulge history — confirm present condition');
    final needsCurrentAssessment =
        !activeConfirmedBulging && (pendingActive || activeInconclusive);
    final disposition = !identityConfirmed || !linkageConfirmed
        ? InnerCoverStockDisposition.unverified
        : p.isInstalled
        ? InnerCoverStockDisposition.installed
        : !p.isAvailable || activeConfirmedBulging
        ? InnerCoverStockDisposition.excluded
        : !bulgeEvidenceConfirmed
        ? InnerCoverStockDisposition.unverified
        : needsCurrentAssessment
        ? InnerCoverStockDisposition.assessmentRequired
        : InnerCoverStockDisposition.acceptedUnassigned;
    rows.add(
      InnerCoverStockRow(
        profile: p,
        disposition: disposition,
        reviewReasons: List.unmodifiable(reasons),
        evidenceUnverified: evidenceUnverified,
        activeConfirmedBulging: activeConfirmedBulging,
        pendingBulgeAssessment: pendingActive || pendingReleased,
        bulgeHistory: history,
        inconclusiveBulgeAssessment: inconclusive,
        needsCurrentAssessment: needsCurrentAssessment,
      ),
    );
  }
  rows.sort(
    (a, b) => a.profile.normalizedSerialNumber.compareTo(
      b.profile.normalizedSerialNumber,
    ),
  );
  return InnerCoverStockSummary(
    rows: List.unmodifiable(rows),
    inventoryConfirmed: inventoryConfirmed,
    linkageConfirmed: linkageConfirmed,
    bulgeEvidenceConfirmed: bulgeEvidenceConfirmed,
  );
}
