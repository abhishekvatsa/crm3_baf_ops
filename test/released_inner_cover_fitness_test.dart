import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/assets/data/furnace_stuckup_record.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_workflow_evidence.dart';
import 'package:crm3_baf_ops/features/assets/domain/apply_inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_stock_summary.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/furnace_stuckup_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'inner_cover_dependency_integration_test.dart' as f;
import 'inner_cover_lifecycle_model_test.dart' as p;
import 'plant_asset_overview_test.dart' as a;

// Synthetic reproduction of the separately retained DEV lifecycle failure.
// This test changes no production data and does not exercise server commands.
final _furnaceClass = a.assetClass(
  id: 'fixture-furnace-class',
  code: 'FURNACE',
  name: 'Furnace',
  legacyKey: 'furnace',
);
final _furnace = a.asset(
  id: 'fixture-furnace-1',
  assetClass: _furnaceClass,
  number: 1,
);
final _released = f.at.add(const Duration(minutes: 2));
const _id = 'fixture-released-bulge';

MaintenanceRecord _ticket(f.Fixture fixture) {
  final original = fixture.issue();
  final baseReference = original.assetHierarchyReference!;
  return a.issueCondition(
      id: _id,
      asset: _furnace,
      effect: MaintenanceIssuePlantConditionEffect.stuckUp,
    )
    ..classification = furnaceStuckupClassification
    ..furnaceStuckupCase = FurnaceStuckupCase(
      baseNumber: fixture.bases.first.assetNumber,
      baseAssetReference: baseReference,
      suspectedCause: FurnaceStuckupCause.innerCoverBulging,
      operatingContext: FurnaceStuckupOperatingContext.postAnnealingRemoval,
    )
    ..chargeNoAtEvent = 77131
    ..startDate = f.at
    ..createdAt = f.at
    ..updatedAt = f.at;
}

Map<String, dynamic> _caseMap(f.Fixture fixture) => {
  'schemaVersion': 1,
  'caseId': _id,
  'ticketId': _id,
  'version': 3,
  'obstructionStatus': 'released',
  'adjudicationStatus': 'confirmed',
  'suspectedCause': 'innerCoverBulging',
  'confirmedCause': 'innerCoverBulging',
  'furnaceAssetInstanceId': _furnace.id,
  'furnaceAssetNumber': _furnace.assetNumber,
  'furnaceAssetClassId': _furnaceClass.id,
  'baseAssetInstanceId': fixture.bases.first.id,
  'baseAssetNumber': fixture.bases.first.assetNumber,
  'baseAssetClassId': f.baseClass.id,
  'innerCoverId': fixture.profiles.first.id,
  'innerCoverSerialNumber': fixture.profiles.first.serialNumber,
  'innerCoverLinkageId': fixture.links.first.id,
  'innerCoverAssignmentVersion': 1,
  'operatingContext': 'postAnnealingRemoval',
  'chargeNoAtEvent': 77131,
  'reportedAt': f.at,
  'reportedByName': 'Synthetic Operations',
  'adjudicatedAt': f.at.add(const Duration(minutes: 1)),
  'adjudicationNotes': 'Synthetic SI confirmation',
  'releasedAt': _released,
  'releaseNotes': 'Synthetic physical separation only',
  'conditionDeclarationId': 'fixture-bulge-declaration',
  'updatedAt': _released,
};

FurnaceStuckupRecord _case(
  f.Fixture fixture, [
  Map<String, dynamic> changes = const {},
]) => FurnaceStuckupRecord.fromMap({..._caseMap(fixture), ...changes}, _id);

InnerCoverDependencies _derive(
  f.Fixture fixture, {
  List<MaintenanceRecord>? tickets,
  List<FurnaceStuckupRecord>? cases,
  List<InnerCoverProfile>? profiles,
  bool cache = false,
  bool maintenance = false,
}) => deriveInnerCoverDependencies(
  profiles: f.batch(profiles ?? fixture.profiles),
  tickets: f.batch(tickets ?? [_ticket(fixture)]),
  stuckupCases: DecodedSnapshotBatch(
    records: cases ?? [_case(fixture)],
    rejectedDocumentIds: const [],
    isFromCache: cache,
  ),
  workflows: f.batch(<InnerCoverWorkflowEvidence>[
    if (maintenance) f.job(fixture),
  ]),
  executions: f.batch(<JobExecution>[if (maintenance) f.execution(fixture)]),
);

void main() {
  test(
    'physical release retains current fitness assessment and exact host warning',
    () {
      final fixture = f.Fixture();
      final original = fixture.build();
      expect(original.innerCovers.first.isAvailable, isTrue);
      expect(original.assets.first.isAvailable, isTrue);
      final dependencies = _derive(fixture);
      expect(dependencies.complete, isTrue);
      final reason =
          dependencies.byCoverId[fixture.profiles.first.id]!.reasons.single;
      expect(reason.kind, InnerCoverDependencyKind.assessment);
      expect(reason.sourceId, _id);
      expect(reason.eventLinkageId, fixture.links.first.id);
      final plant = applyInnerCoverDependencies(
        overview: original,
        register: f.registerFor(fixture),
        dependencies: dependencies,
      );
      final cover = plant.innerCovers.first;
      expect(cover.isAvailable, isFalse);
      expect(cover.isUnfit, isFalse);
      expect(cover.conditionReasons, contains('Assessment needed'));
      final base = plant.assets.first;
      expect(base.isAvailable, isFalse);
      expect(base.isDown, isFalse);
      expect(base.isUnfit, isFalse);
      expect(base.isTemporarilyBlocked, isFalse);
      expect(
        base.evidenceWarnings,
        contains(
          'Linked Inner Cover G66: current fitness assessment required for an unresolved confirmed-bulging concern.',
        ),
      );
      expect(plant.down, 0);
      expect(plant.unfit, 0);
      expect(plant.innerCoverStock!.rows.first.needsCurrentAssessment, isTrue);
      expect(plant.innerCoverStock!.installed, 2);
      expect(original.innerCovers.first.isAvailable, isTrue);
    },
  );
  test('combined confirmed cause has the same bounded assessment effect', () {
    final fixture = f.Fixture();
    final state = _derive(
      fixture,
      cases: [
        _case(fixture, {'confirmedCause': 'combinedCondition'}),
      ],
    ).byCoverId[fixture.profiles.first.id]!;
    expect(state.needsCurrentAssessment, isTrue);
    expect(state.isUnfit, isFalse);
  });
  test(
    'other, active and unconfirmed cases do not become released-fitness evidence',
    () {
      final fixture = f.Fixture();
      for (final changes in [
        {'confirmedCause': 'draftSealPlateDamagedOrFallen'},
        {'obstructionStatus': 'active'},
        {'adjudicationStatus': 'pending', 'confirmedCause': null},
      ]) {
        expect(
          _derive(
            fixture,
            cases: [_case(fixture, changes)],
          ).byCoverId[fixture.profiles.first.id]!.needsCurrentAssessment,
          isFalse,
          reason: '$changes',
        );
      }
    },
  );
  test(
    'missing, deleted and conflicting originals are unverified, never clearance',
    () {
      final fixture = f.Fixture();
      final deleted = _ticket(fixture)..isDeleted = true;
      for (final originals in <List<MaintenanceRecord>>[
        [],
        [deleted],
        [_ticket(fixture), _ticket(fixture)],
      ]) {
        final dependencies = _derive(fixture, tickets: originals);
        expect(dependencies.complete, isFalse);
        final plant = applyInnerCoverDependencies(
          overview: fixture.build(),
          register: f.registerFor(fixture),
          dependencies: dependencies,
        );
        expect(plant.innerCovers.first.isAvailable, isFalse);
        expect(plant.assets.first.isAvailable, isFalse);
        expect(plant.down, 0);
      }
    },
  );
  test(
    'an original issue without its case cannot establish current fitness',
    () {
      final fixture = f.Fixture();
      expect(_derive(fixture, cases: []).complete, isFalse);
      final closed = _ticket(fixture)
        ..isResolved = true
        ..status = TicketStatus.resolved;
      expect(_derive(fixture, cases: [], tickets: [closed]).complete, isTrue);
    },
  );
  test('exact frozen identity and chronology mismatches remain unverified', () {
    final fixture = f.Fixture();
    for (final changes in <Map<String, dynamic>>[
      {'ticketId': 'another-ticket'},
      {'baseAssetClassId': null},
      {'furnaceAssetClassId': null},
      {'innerCoverLinkageId': null},
      {'innerCoverAssignmentVersion': null},
      {'baseAssetInstanceId': 'other-base'},
      {'baseAssetClassId': 'other-class'},
      {'furnaceAssetInstanceId': 'other-furnace'},
      {'innerCoverId': 'other-cover'},
      {'innerCoverSerialNumber': 'OTHER'},
      {'innerCoverLinkageId': 'other-link'},
      {'innerCoverAssignmentVersion': 2},
      {'chargeNoAtEvent': 77132},
      {'operatingContext': 'other'},
      {'suspectedCause': 'unknown'},
      {'reportedAt': f.at.subtract(const Duration(minutes: 1))},
      {'releasedAt': null},
      {'adjudicatedAt': null},
      {'releasedAt': f.at.subtract(const Duration(minutes: 1))},
      {'updatedAt': f.at},
    ]) {
      final result = _derive(fixture, cases: [_case(fixture, changes)]);
      expect(result.complete, isFalse, reason: '$changes');
      expect(
        result.byCoverId[fixture.profiles.first.id]!.needsCurrentAssessment,
        isFalse,
        reason: '$changes',
      );
    }
  });
  test('strict optional identity decoder rejects malformed present fields', () {
    final fixture = f.Fixture();
    for (final changes in <Map<String, dynamic>>[
      {'baseAssetClassId': 123},
      {'furnaceAssetClassId': false},
      {'innerCoverLinkageId': []},
      {'innerCoverAssignmentVersion': 0},
      {'innerCoverAssignmentVersion': '1'},
    ]) {
      expect(() => _case(fixture, changes), throwsFormatException);
    }
  });
  test(
    'pending closure or cached case retains adverse evidence without all-clear',
    () {
      final fixture = f.Fixture();
      final pending = _ticket(fixture)
        ..isResolved = true
        ..status = TicketStatus.resolved
        ..isSynced = false;
      for (final result in [
        _derive(fixture, tickets: [pending]),
        _derive(fixture, cache: true),
      ]) {
        expect(result.complete, isFalse);
        expect(
          result.byCoverId[fixture.profiles.first.id]!.needsCurrentAssessment,
          isTrue,
        );
        expect(
          result
              .byCoverId[fixture.profiles.first.id]!
              .reasons
              .single
              .awaitingServerConfirmation,
          isTrue,
        );
      }
    },
  );
  test(
    'authoritative closure ends only this concern and preserves other maintenance',
    () {
      final fixture = f.Fixture();
      final closed = _ticket(fixture)
        ..isResolved = true
        ..status = TicketStatus.resolved;
      final dependencies = _derive(
        fixture,
        tickets: [closed],
        maintenance: true,
      );
      expect(dependencies.complete, isTrue);
      final state = dependencies.byCoverId[fixture.profiles.first.id]!;
      expect(state.needsCurrentAssessment, isFalse);
      expect(state.isUnderMaintenance, isTrue);
      final plant = applyInnerCoverDependencies(
        overview: fixture.build(withWorkflow: true),
        register: f.registerFor(fixture),
        dependencies: dependencies,
      );
      expect(plant.innerCovers.first.isAvailable, isFalse);
      expect(plant.assets.first.isUnderMaintenance, isTrue);
      expect(plant.assets.first.workflowStatus!.openMaintenanceCount, 1);
    },
  );
  test(
    'administrative still-relevant stays held, relevance-ended leaves history',
    () {
      final fixture = f.Fixture();
      for (final disposition in IssueAdministrativeClosureDisposition.values) {
        final closed = _ticket(fixture)
          ..isResolved = true
          ..status = TicketStatus.closedWithoutResolution
          ..administrativeClosure = IssueAdministrativeClosure(
            disposition: disposition,
            reason: 'Synthetic review',
          );
        final state = _derive(
          fixture,
          tickets: [closed],
        ).byCoverId[fixture.profiles.first.id]!;
        expect(
          state.needsCurrentAssessment,
          disposition == IssueAdministrativeClosureDisposition.stillRelevant,
        );
        expect(state.complete, isTrue);
      }
      final malformed = _ticket(fixture)
        ..isResolved = true
        ..status = TicketStatus.closedWithoutResolution;
      expect(_derive(fixture, tickets: [malformed]).complete, isFalse);
      final inconsistent = _ticket(fixture)..isResolved = true;
      expect(_derive(fixture, tickets: [inconsistent]).complete, isFalse);
    },
  );
  test(
    'later acceptance alone cannot clear an unresolved original concern',
    () {
      final fixture = f.Fixture();
      final acceptedLater = InnerCoverProfile.fromMap({
        ...p.profileMap(),
        'innerCoverId': fixture.profiles.first.id,
        'serialNumber': 'G66',
        'normalizedSerialNumber': 'G66',
        'acceptedAt': _released.add(const Duration(days: 1)),
        'updatedAt': _released.add(const Duration(days: 1)),
      }, fixture.profiles.first.id);
      final state = _derive(
        fixture,
        profiles: [acceptedLater, fixture.profiles.last],
      ).byCoverId[fixture.profiles.first.id]!;
      expect(state.needsCurrentAssessment, isTrue);
    },
  );
  test(
    'moved serial holds verified current host and preserves original-host warning',
    () {
      final original = f.Fixture();
      final current = f.Fixture(swapped: true, newEpisode: true);
      final dependencies = _derive(original, profiles: current.profiles);
      final plant = applyInnerCoverDependencies(
        overview: current.build(),
        register: f.registerFor(current),
        dependencies: dependencies,
      );
      final oldBase = plant.assets.firstWhere(
        (b) => b.asset.id == original.bases.first.id,
      );
      final newBase = plant.assets.firstWhere(
        (b) => b.asset.id == original.bases.last.id,
      );
      expect(
        newBase.linkedInnerCoverDependency!.needsCurrentAssessment,
        isTrue,
      );
      expect(newBase.isAvailable, isFalse);
      expect(
        oldBase.evidenceWarnings.join(' '),
        contains('recorded work remains pending reconciliation'),
      );
      expect(oldBase.workflowStatus!.openMaintenanceCount, 0);
      expect(plant.down, 0);
    },
  );
  test(
    'unverified current linkage does not assign assessment to a guessed host',
    () {
      final fixture = f.Fixture();
      final plant = applyInnerCoverDependencies(
        overview: fixture.build(),
        register: f.registerFor(fixture, verified: false),
        dependencies: _derive(fixture),
      );
      expect(
        plant.assets.every((b) => b.linkedInnerCoverDependency == null),
        isTrue,
      );
      expect(
        plant.innerCovers.first.dependency!.needsCurrentAssessment,
        isTrue,
      );
      expect(plant.down, 0);
    },
  );
  test(
    'history with authoritative closure stays history and is not permanent unfit',
    () {
      final fixture = f.Fixture();
      final closed = _ticket(fixture)
        ..isResolved = true
        ..status = TicketStatus.resolved;
      final rawStock = buildInnerCoverStockSummary(
        classes: f.batch([f.baseClass, f.coverClass]),
        profiles: f.batch(fixture.profiles),
        assignments: f.batch(fixture.assignments),
        links: f.batch(fixture.links),
        register: f.registerFor(fixture),
        cases: f.batch([_case(fixture)]),
        declarations: f.batch([
          AssetConditionDeclarationRecord(
            id: 'fixture-bulge-declaration',
            assetId: fixture.profiles.first.id,
            assetSerialNumber: 'G66',
            evidenceCount: 1,
            firstConfirmedAt: f.at,
            latestEvidenceAt: f.at,
          ),
        ]),
      );
      final stock = annotateInnerCoverStockDependencies(
        rawStock,
        _derive(fixture, tickets: [closed]),
      );
      expect(stock.rows.first.bulgeHistory, isTrue);
      expect(stock.rows.first.needsCurrentAssessment, isFalse);
      expect(stock.rows.first.activeConfirmedBulging, isFalse);
      expect(stock.installed, 2);
    },
  );
}
