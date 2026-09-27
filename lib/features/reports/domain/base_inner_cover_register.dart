import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';

enum BaseCoverLinkState { linked, empty, unknown, inconsistent }

class BaseCoverRegisterRow {
  const BaseCoverRegisterRow({
    required this.base,
    required this.state,
    required this.explanation,
    this.assignment,
    this.cover,
    this.linkage,
  });
  final AssetInstanceRecord base;
  final BaseCoverLinkState state;
  final String explanation;
  final BaseInnerCoverAssignment? assignment;
  final InnerCoverProfile? cover;
  final InnerCoverLinkage? linkage;
  String get label => switch (state) {
    BaseCoverLinkState.linked => 'Confirmed linked',
    BaseCoverLinkState.empty => 'No recorded linkage',
    BaseCoverLinkState.unknown => 'Unknown / evidence unavailable',
    BaseCoverLinkState.inconsistent =>
      'Inconsistent evidence — review required',
  };
}

class BaseInnerCoverRegister {
  const BaseInnerCoverRegister({
    required this.rows,
    required this.populationConfirmed,
    required this.evidenceConfirmed,
    required this.notes,
    this.capturedAt,
  });
  final List<BaseCoverRegisterRow> rows;
  final bool populationConfirmed;
  final bool evidenceConfirmed;
  final List<String> notes;
  final DateTime? capturedAt;
}

/// Absence is meaningful only after all relevant populations have arrived from
/// the server without pending writes or decode omissions. Cross-collection
/// emissions are independent; contradictory emissions remain unknown/flagged.
BaseInnerCoverRegister buildBaseInnerCoverRegister({
  required DecodedSnapshotBatch<AssetClassRecord> classes,
  required DecodedSnapshotBatch<AssetInstanceRecord> assets,
  required DecodedSnapshotBatch<BaseInnerCoverAssignment> assignments,
  required DecodedSnapshotBatch<InnerCoverProfile> covers,
  required DecodedSnapshotBatch<InnerCoverLinkage> linkages,
  DateTime? capturedAt,
  String? selectedClassId,
  String? selectedAssetId,
}) {
  bool qualified<T>(DecodedSnapshotBatch<T> batch) =>
      batch.isComplete && batch.isServerConfirmed;
  final populationConfirmed = qualified(classes) && qualified(assets);
  final evidenceConfirmed =
      populationConfirmed &&
      qualified(assignments) &&
      qualified(covers) &&
      qualified(linkages);
  final baseClasses = classes.records
      .where((c) => c.legacyAssetTypeKey == 'base')
      .map((c) => c.id)
      .toSet();
  final bases =
      assets.records
          .where(
            (b) =>
                baseClasses.contains(b.assetClassId) &&
                (selectedClassId == null ||
                    b.assetClassId == selectedClassId) &&
                (selectedAssetId == null || b.id == selectedAssetId),
          )
          .toList()
        ..sort((a, b) => a.assetNumber.compareTo(b.assetNumber));
  final rows = <BaseCoverRegisterRow>[];
  for (final base in bases) {
    final claims = assignments.records
        .where((a) => a.baseAssetInstanceId == base.id)
        .toList();
    final installed = covers.records
        .where((c) => c.currentBaseAssetInstanceId == base.id)
        .toList();
    final activeLinks = linkages.records
        .where((l) => l.active && l.baseAssetInstanceId == base.id)
        .toList();
    final assignment = claims.length == 1 ? claims.single : null;
    final matchingCovers = assignment == null
        ? <InnerCoverProfile>[]
        : covers.records.where((c) => c.id == assignment.innerCoverId).toList();
    final cover = matchingCovers.length == 1 ? matchingCovers.single : null;
    final matchingLinks = assignment == null
        ? <InnerCoverLinkage>[]
        : activeLinks.where((l) => l.id == assignment.linkageId).toList();
    final linkage = matchingLinks.length == 1 ? matchingLinks.single : null;
    BaseCoverLinkState state;
    String reason;
    if (!evidenceConfirmed) {
      state = BaseCoverLinkState.unknown;
      reason =
          'A source is cached, pending, unavailable or incomplete. Vacancy is not inferred.';
    } else if (claims.isEmpty && installed.isEmpty && activeLinks.isEmpty) {
      state = BaseCoverLinkState.empty;
      reason =
          'No assignment, installed-cover claim or active linkage in complete server-confirmed source snapshots.';
    } else if (assignment != null &&
        cover != null &&
        linkage != null &&
        claims.length == 1 &&
        installed.length == 1 &&
        activeLinks.length == 1 &&
        assignment.baseAssetClassId == base.assetClassId &&
        assignment.baseAssetNumber == base.assetNumber &&
        cover.isInstalled &&
        cover.currentBaseAssetInstanceId == base.id &&
        cover.currentBaseAssetNumber == base.assetNumber &&
        cover.currentLinkageId == assignment.linkageId &&
        cover.serialNumber == assignment.innerCoverSerialNumber &&
        linkage.innerCoverId == cover.id &&
        linkage.innerCoverSerialNumber == cover.serialNumber &&
        linkage.baseAssetNumber == base.assetNumber &&
        linkage.installedAt.isAtSameMomentAs(assignment.linkedAt) &&
        assignments.records.where((a) => a.innerCoverId == cover.id).length ==
            1 &&
        linkages.records
                .where((l) => l.active && l.innerCoverId == cover.id)
                .length ==
            1) {
      state = BaseCoverLinkState.linked;
      reason = 'Assignment, installed profile and active linkage agree.';
    } else {
      state = BaseCoverLinkState.inconsistent;
      reason =
          'Assignment, cover custody or active linkage disagree; do not treat as empty.';
    }
    rows.add(
      BaseCoverRegisterRow(
        base: base,
        state: state,
        explanation: reason,
        assignment: assignment,
        cover: cover,
        linkage: linkage,
      ),
    );
  }
  return BaseInnerCoverRegister(
    rows: List.unmodifiable(rows),
    capturedAt: capturedAt,
    populationConfirmed: populationConfirmed,
    evidenceConfirmed: evidenceConfirmed,
    notes: [
      'Current snapshot only. Selected historical dates do not reconstruct earlier installations. Separate source snapshots are not an atomic server cutoff.',
      if (!populationConfirmed)
        'Base population is incomplete or not server-confirmed; this is not a complete Base register.',
      if (!evidenceConfirmed)
        'One or more linkage sources are incomplete or not server-confirmed; absence is unknown.',
      if (bases.isEmpty)
        'No readable Bases match the selected scope. Select a Base class or all asset classes.',
    ],
  );
}
