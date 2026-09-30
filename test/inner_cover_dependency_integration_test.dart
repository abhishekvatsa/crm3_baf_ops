import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/furnace_stuckup_record.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_stock_summary.dart';
import 'package:crm3_baf_ops/features/assets/domain/physical_plant_inventory.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/domain/qualified_plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:crm3_baf_ops/features/reports/domain/base_inner_cover_register.dart';
import 'plant_asset_overview_test.dart' as f;
import 'inner_cover_dependencies_test.dart' as d;
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/apply_inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_workflow_evidence.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'inner_cover_lifecycle_model_test.dart' as p;

// Synthetic domain-only proof: no cloud client/provider, phone or production IO.
final at = DateTime.utc(2026, 9, 20, 8);
final installedAt = at.subtract(const Duration(days: 1));
final baseClass = f.assetClass(
  id: 'fixture-base-class',
  code: 'BASE',
  name: 'Base',
  legacyKey: 'base',
);
final coverClass = f.assetClass(
  id: 'fixture-cover-class',
  code: 'INNER_COVER',
  name: 'Inner Cover',
  legacyKey: 'innerCover',
);
DecodedSnapshotBatch<T> batch<T>(List<T> rows) =>
    DecodedSnapshotBatch(records: rows, rejectedDocumentIds: const []);

class Fixture {
  Fixture({bool swapped = false, bool newEpisode = false}) {
    bases = [
      for (final n in [119, 120])
        f.asset(id: 'fixture-base-$n', assetClass: baseClass, number: n),
    ];
    profiles = [
      for (final (i, s) in ['G66', 'G99'].indexed)
        InnerCoverProfile.fromMap({
          ...p.profileMap(
            state: 'installed',
            baseId: bases[swapped ? 1 - i : i].id,
            baseNumber: bases[swapped ? 1 - i : i].assetNumber,
            baseName: bases[swapped ? 1 - i : i].name,
            linkageId: 'fixture-link-$s${newEpisode ? '-new' : ''}',
          ),
          'innerCoverId': 'fixture-cover-$s',
          'assetClassId': coverClass.id,
          'assetClassCode': coverClass.code,
          'serialNumber': s,
          'normalizedSerialNumber': s,
          'updatedAt': installedAt,
        }, 'fixture-cover-$s'),
    ];
    assignments = [
      for (final (i, c) in profiles.indexed)
        BaseInnerCoverAssignment(
          baseAssetInstanceId: bases[swapped ? 1 - i : i].id,
          baseAssetClassId: baseClass.id,
          baseAssetNumber: bases[swapped ? 1 - i : i].assetNumber,
          baseAssetName: bases[swapped ? 1 - i : i].name,
          innerCoverId: c.id,
          innerCoverSerialNumber: c.serialNumber,
          linkageId: c.currentLinkageId!,
          linkedAt: installedAt,
          version: 1,
          updatedAt: installedAt,
          lastMutationId: 'fixture-assignment-$i',
        ),
    ];
    links = [
      for (final (i, c) in profiles.indexed)
        InnerCoverLinkage(
          id: c.currentLinkageId!,
          baseAssetInstanceId: bases[swapped ? 1 - i : i].id,
          baseAssetNumber: bases[swapped ? 1 - i : i].assetNumber,
          baseAssetName: bases[swapped ? 1 - i : i].name,
          innerCoverId: c.id,
          innerCoverSerialNumber: c.serialNumber,
          installedAt: installedAt,
          installedByUid: 'fixture-owner',
          installedByName: 'Fixture owner',
          active: true,
          version: 1,
        ),
    ];
  }
  late final List<AssetInstanceRecord> bases;
  late final List<InnerCoverProfile> profiles;
  late final List<BaseInnerCoverAssignment> assignments;
  late final List<InnerCoverLinkage> links;
  MaintenanceRecord issue() {
    final base = bases.first;
    final cover = profiles.first;
    final ref = AssetHierarchyReference.fromMap({
      ...base.toReference().toMap(),
      'schemaVersion': 3,
      'innerCoverAssociation': InnerCoverEventReference(
        baseAssetInstanceId: base.id,
        baseAssetNumber: base.assetNumber,
        positionState: InnerCoverPositionState.linked,
        innerCoverId: cover.id,
        innerCoverSerialNumber: cover.serialNumber,
        linkageId: cover.currentLinkageId,
        assignmentVersion: 1,
        linkedAt: installedAt,
        eventAt: at,
        confirmedAt: at,
        confirmedByUid: 'fixture-owner',
        confirmedByName: 'Fixture owner',
      ).toMap(),
    });
    return f.issueCondition(
        id: 'fixture-inner-cover-issue',
        asset: base,
        effect: MaintenanceIssuePlantConditionEffect.unavailable,
        description: 'Synthetic cover issue for dependency reproduction',
      )
      ..assetType = AssetType.innerCover
      ..assetHierarchyRefJson = ref.encode()
      ..startDate = at
      ..createdAt = at
      ..updatedAt = at;
  }

  EquipmentStatusRecord workflow(
    AssetInstanceRecord base, {
    bool coverMaintenance = false,
  }) =>
      f.workflow(
          key: coverMaintenance ? 'innerCover' : 'base',
          number: base.assetNumber,
          assetClassId: base.assetClassId,
          assetInstanceId: base.id,
          maintenance: coverMaintenance ? 1 : 0,
        )
        ..firestoreId =
            'fixture-${coverMaintenance ? 'cover' : 'base'}-${base.assetNumber}'
        ..isSynced = true
        ..stateKey = coverMaintenance ? 'underMaintenance' : 'available'
        ..updatedAt = at;
  PlantAssetOverview build({
    bool withIssue = false,
    bool withWorkflow = false,
  }) {
    final classes = [baseClass, coverClass];
    final register = buildBaseInnerCoverRegister(
      classes: batch(classes),
      assets: batch(bases),
      assignments: batch(assignments),
      covers: batch(profiles),
      linkages: batch(links),
    );
    expect(register.populationConfirmed, isTrue);
    expect(register.evidenceConfirmed, isTrue);
    expect(register.rows, hasLength(2));
    expect(
      register.rows.every((r) => r.state == BaseCoverLinkState.linked),
      isTrue,
    );
    final stock = buildInnerCoverStockSummary(
      classes: batch(classes),
      profiles: batch(profiles),
      assignments: batch(assignments),
      links: batch(links),
      register: register,
      cases: batch(<FurnaceStuckupRecord>[]),
      declarations: batch(<AssetConditionDeclarationRecord>[]),
    );
    expect(stock.inventoryConfirmed, isTrue);
    expect(stock.linkageConfirmed, isTrue);
    expect(stock.bulgeEvidenceConfirmed, isTrue);
    expect(stock.installed, 2);
    final numbered = qualifiedPlantAssetOverview(
      classes: classes,
      assets: bases,
      conditions: const [],
      workflow: [
        for (final b in bases) workflow(b),
        if (withWorkflow) workflow(bases.first, coverMaintenance: true),
      ],
      availability: const [],
      tickets: [if (withIssue) issue()],
      populationWarnings: const [],
      manualSourcesCurrent: true,
    );
    expect(numbered.evidenceWarnings, isEmpty);
    return physicalPlantInventory(
      overview: numbered,
      classes: classes,
      profiles: profiles,
      innerCoverStock: stock,
    );
  }
}

BaseInnerCoverRegister registerFor(
  Fixture f, {
  bool verified = true,
  List<BaseCoverRegisterRow>? rows,
}) {
  final register = buildBaseInnerCoverRegister(
    classes: batch([baseClass, coverClass]),
    assets: batch(f.bases),
    assignments: batch(f.assignments),
    covers: batch(f.profiles),
    linkages: batch(f.links),
  );
  return BaseInnerCoverRegister(
    rows: rows ?? register.rows,
    populationConfirmed: true,
    evidenceConfirmed: verified,
    notes: const [],
  );
}

InnerCoverWorkflowEvidence job(
  Fixture f, {
  bool red = false,
  bool preparation = false,
}) => d.dependencyWorkflowFixture(
  overrides: {
    'assetNumber': f.bases.first.assetNumber,
    'assetClassId': baseClass.id,
    'assetInstanceId': f.bases.first.id,
    'innerCoverId': f.profiles.first.id,
    'innerCoverSerialNumber': f.profiles.first.serialNumber,
    'innerCoverLinkageId': f.links.first.id,
    'activeRedWork': red,
    'awaitingPreparation': preparation,
  },
);
JobExecution execution(Fixture f) => d.dependencyExecutionFixture(
  position: {
    'baseAssetInstanceId': f.bases.first.id,
    'baseAssetClassId': baseClass.id,
    'baseAssetNumber': f.bases.first.assetNumber,
    'innerCoverId': f.profiles.first.id,
    'innerCoverSerialNumber': f.profiles.first.serialNumber,
    'linkageId': f.links.first.id,
    'assignmentVersion': 1,
  },
);
InnerCoverDependencies derive(
  Fixture f, {
  bool issue = false,
  bool maintenance = false,
  bool red = false,
  bool preparation = false,
  bool cache = false,
  List<MaintenanceRecord>? tickets,
}) {
  final raw = deriveInnerCoverDependencies(
    profiles: batch(f.profiles),
    tickets: DecodedSnapshotBatch(
      records: tickets ?? [if (issue) f.issue()],
      rejectedDocumentIds: const [],
      isFromCache: cache,
    ),
    workflows: batch([
      if (maintenance) job(f, red: red, preparation: preparation),
    ]),
    executions: batch([if (maintenance) execution(f)]),
  );
  final projected = f.workflow(f.bases.first, coverMaintenance: true);
  if (red || preparation) {
    projected.openMaintenanceCount = 0;
    projected.openRedCount = red ? 1 : 0;
    projected.awaitingPreparationCount = preparation ? 1 : 0;
    projected.stateKey = red ? 'underRED' : 'awaitingPreparation';
  }
  return qualifyInnerCoverDependencyProjections(
    raw,
    batch([
      for (final base in f.bases) f.workflow(base),
      if (maintenance) projected,
    ]),
  );
}

PlantAssetOverview apply(
  Fixture f, {
  bool issue = false,
  bool maintenance = false,
  bool red = false,
  bool preparation = false,
  bool cache = false,
  BaseInnerCoverRegister? register,
  PlantAssetOverview? original,
  List<MaintenanceRecord>? tickets,
}) => applyInnerCoverDependencies(
  overview: original ?? f.build(withIssue: issue, withWorkflow: maintenance),
  register: register ?? registerFor(f),
  dependencies: derive(
    f,
    issue: issue,
    maintenance: maintenance,
    red: red,
    preparation: preparation,
    cache: cache,
    tickets: tickets,
  ),
);
void main() {
  test('qualified two-pair positive control stays available', () {
    final view = apply(Fixture());
    expect(view.total, 4);
    expect(view.available, 4);
    expect(view.down, 0);
    expect(view.hasCompleteEvidence, isTrue);
  });
  for (final kind in ['issue', 'maintenance', 'red', 'preparation']) {
    test(
      '$kind restricts exact serial and linked Base without double counting or Down',
      () {
        final f = Fixture();
        final view = apply(
          f,
          issue: kind == 'issue',
          maintenance: kind != 'issue',
          red: kind == 'red',
          preparation: kind == 'preparation',
        );
        expect(view.assets.first.isAvailable, isFalse);
        expect(view.innerCovers.first.isAvailable, isFalse);
        expect(view.assets.last.isAvailable, isTrue);
        expect(view.innerCovers.last.isAvailable, isTrue);
        expect(view.available, 2);
        expect(view.down, 0);
        expect(view.underMaintenance, kind == 'issue' ? 0 : 2);
        expect(view.issueUnavailable, kind == 'issue' ? 2 : 0);
        expect(view.innerCoverStock!.installed, 2);
        expect(
          view.innerCoverStock!.activeIssueRestrictions,
          kind == 'issue' ? 1 : 0,
        );
        expect(
          view.innerCoverStock!.activeMaintenanceRestrictions,
          kind == 'issue' ? 0 : 1,
        );
      },
    );
  }
  test(
    'cached issue population cannot clear serial or host; known restriction retained',
    () {
      final view = apply(Fixture(), issue: true, cache: true);
      expect(view.available, 0);
      expect(view.issueUnavailable, 2);
      expect(view.hasCompleteEvidence, isFalse);
      expect(view.innerCoverStock!.acceptedUnassigned, isNull);
      expect(view.down, 0);
    },
  );
  test('Base-only issue does not propagate incidental IC association', () {
    final f = Fixture();
    final t = f.issue()..assetType = AssetType.base;
    final view = apply(f, tickets: [t]);
    expect(view.innerCovers.every((c) => c.isAvailable), isTrue);
    expect(
      view.assets.every(
        (b) => b.linkedInnerCoverDependency?.hasRestrictions == false,
      ),
      isTrue,
    );
  });
  test('clearing issue keeps independent maintenance restriction', () {
    final f = Fixture();
    final both = apply(f, issue: true, maintenance: true);
    final maintenanceOnly = apply(f, maintenance: true);
    expect(both.available, 2);
    expect(maintenanceOnly.available, 2);
    expect(maintenanceOnly.issueUnavailable, 0);
    expect(maintenanceOnly.underMaintenance, 2);
    final clear = apply(f);
    expect(clear.available, 4);
  });
  test('missing linkage is a warning, never an automatic Down declaration', () {
    final f = Fixture();
    final reg = registerFor(f);
    final view = apply(
      f,
      register: registerFor(
        f,
        rows: [
          BaseCoverRegisterRow(
            base: f.bases.first,
            state: BaseCoverLinkState.empty,
            explanation: 'Synthetic confirmed empty',
          ),
          reg.rows.last,
        ],
      ),
    );
    expect(view.down, 0);
    expect(view.assets.first.linkedInnerCoverDependency, isNull);
  });
  for (final state in [
    BaseCoverLinkState.unknown,
    BaseCoverLinkState.inconsistent,
  ]) {
    test('$state linkage does not claim physical departure', () {
      final f = Fixture();
      final reg = registerFor(f);
      final view = apply(
        f,
        issue: true,
        register: registerFor(
          f,
          rows: [
            BaseCoverRegisterRow(
              base: f.bases.first,
              state: state,
              explanation: 'Synthetic unverified',
            ),
            reg.rows.last,
          ],
        ),
      );
      expect(
        view.assets.first.evidenceWarnings.any(
          (w) => w.contains('no longer linked'),
        ),
        isFalse,
      );
      expect(
        view.assets.first.evidenceWarnings.any(
          (w) => w.contains('verification'),
        ),
        isTrue,
      );
      expect(view.down, 0);
    });
  }
  for (final scenario in ['move', 'new installation']) {
    test(
      '$scenario uses a real consistent register and retains original work for reconciliation',
      () {
        final f = Fixture();
        final current = Fixture(swapped: scenario == 'move', newEpisode: true);
        final reg = registerFor(current);
        expect(reg.evidenceConfirmed, isTrue);
        expect(
          reg.rows.every((r) => r.state == BaseCoverLinkState.linked),
          isTrue,
        );
        final before = f.build(withIssue: true);
        final currentOverview = physicalPlantInventory(
          overview: before,
          classes: [baseClass, coverClass],
          profiles: current.profiles,
        );
        final view = applyInnerCoverDependencies(
          overview: currentOverview,
          register: reg,
          dependencies: derive(f, issue: true),
        );
        final currentHost = scenario == 'move'
            ? view.assets.last
            : view.assets.first;
        expect(currentHost.isIssueUnavailable, isTrue);
        expect(
          view.assets.first.issueConditionContributions,
          same(before.assets.first.issueConditionContributions),
        );
        expect(
          view.assets.first.evidenceWarnings.any(
            (w) => w.contains('pending reconciliation'),
          ),
          isTrue,
        );
        expect(
          view.assets.first.evidenceWarnings.any(
            (w) => w.contains(
              scenario == 'move'
                  ? 'no longer linked'
                  : 'different installation',
            ),
          ),
          isTrue,
        );
        expect(view.innerCovers.first.isAvailable, isFalse);
        expect(view.down, 0);
      },
    );
  }
  for (final issue in [true, false]) {
    for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
      testWidgets(
        'serial issue=$issue reason and filtering stay readable at $size',
        (tester) async {
          tester.view.physicalSize = Size(size.$1, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final view = apply(Fixture(), issue: issue, maintenance: !issue);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentAppUserProvider.overrideWith(
                  (ref) => Stream.value(
                    AppUser(
                      uid: 'fixture',
                      name: 'Fixture',
                      email: 'fixture@example.invalid',
                      roles: [AppRole.operations],
                      isApproved: true,
                      createdAt: at,
                    ),
                  ),
                ),
                plantAssetOverviewProvider.overrideWith(
                  (ref) => AsyncData(view),
                ),
                plantConditionTicketsProvider.overrideWith(
                  (ref) => Stream.value([]),
                ),
              ],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(size.$2)),
                  child: child!,
                ),
                home: AssetConditionBoard(
                  initialAssetClassId: coverClass.id,
                  initialFilter: issue
                      ? AssetConditionFilter.unavailable
                      : AssetConditionFilter.maintenance,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('plant-inner-cover-fixture-cover-G66')),
            200,
          );
          expect(find.text('Inner Cover G66'), findsOneWidget);
          expect(
            find.textContaining(
              issue
                  ? 'Unavailable by Inner Cover issue'
                  : 'Maintenance work remains open',
            ),
            findsOneWidget,
          );
          expect(find.text('Inner Cover G99'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
