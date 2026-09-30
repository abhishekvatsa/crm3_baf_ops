import '../../reports/domain/base_inner_cover_register.dart';

/// A disagreement between recorded linkage and declared Base condition, not
/// evidence of physical absence and never an inferred Down declaration.
class BaseCoverReconciliation {
  const BaseCoverReconciliation({
    required this.rows,
    required this.needsReview,
    required this.conditionUnverified,
    required this.populationConfirmed,
  });

  final List<BaseCoverRegisterRow> rows;
  final List<BaseCoverRegisterRow> needsReview;
  final int conditionUnverified;
  final bool populationConfirmed;

  int get linked =>
      rows.where((row) => row.state == BaseCoverLinkState.linked).length;
  int get noRecordedLinkage =>
      rows.where((row) => row.state == BaseCoverLinkState.empty).length;
  int get linkageUnverified => rows
      .where(
        (row) =>
            row.state == BaseCoverLinkState.unknown ||
            row.state == BaseCoverLinkState.inconsistent,
      )
      .length;
}

BaseCoverReconciliation reconcileBaseCoverRegister({
  required BaseInnerCoverRegister register,
  required Set<String> activeBaseIds,
  required Set<String> verifiedConditionBaseIds,
  required Set<String> downBaseIds,
}) {
  final rows = register.rows
      .where((row) => activeBaseIds.contains(row.base.id))
      .toList(growable: false);
  final empty = rows.where((row) => row.state == BaseCoverLinkState.empty);
  return BaseCoverReconciliation(
    rows: List.unmodifiable(rows),
    populationConfirmed: register.populationConfirmed,
    needsReview: List.unmodifiable(
      empty.where(
        (row) =>
            verifiedConditionBaseIds.contains(row.base.id) &&
            !downBaseIds.contains(row.base.id),
      ),
    ),
    conditionUnverified: empty
        .where((row) => !verifiedConditionBaseIds.contains(row.base.id))
        .length,
  );
}
