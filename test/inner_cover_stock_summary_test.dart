import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/furnace_stuckup_record.dart';
import 'package:crm3_baf_ops/features/assets/data/plant_condition_evidence.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/furnace_stuckup_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_stock_summary.dart';
import 'package:crm3_baf_ops/features/assets/domain/physical_plant_inventory.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/presentation/widgets/inner_cover_stock_panel.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/furnace_stuckup_case.dart';
import 'package:crm3_baf_ops/features/reports/domain/base_inner_cover_register.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/apply_inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_workflow_evidence.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'inner_cover_lifecycle_model_test.dart' as profile_fixture;
import 'plant_asset_overview_test.dart' as f;

final _baseClass = f.assetClass(
  id: 'bases',
  code: 'BASE',
  name: 'Base',
  legacyKey: 'base',
);
final _coverClass = f.assetClass(
  id: 'covers',
  code: 'INNER_COVER',
  name: 'Inner Cover',
  legacyKey: 'innerCover',
);
final _at = DateTime.utc(2026, 8, 10);
InnerCoverProfile _cover(
  String serial, {
  String state = 'available',
  int? base,
  bool reaccept = false,
}) {
  final id = 'cover-$serial';
  return InnerCoverProfile.fromMap({
    ...profile_fixture.profileMap(
      state: state,
      baseId: base == null ? null : 'base-$base',
      baseNumber: base,
      baseName: base == null ? null : 'Base $base',
      linkageId: base == null ? null : 'link-$serial',
    ),
    'innerCoverId': id,
    'assetClassId': _coverClass.id,
    'assetClassCode': _coverClass.code,
    'serialNumber': serial,
    'normalizedSerialNumber': serial.replaceAll(RegExp(r'[^A-Z0-9]'), ''),
    'updatedAt': _at,
    if (reaccept) ...{
      'assuranceInvalidatedAt': DateTime.utc(2026, 8, 3),
      'assuranceInvalidatedRecordedAt': DateTime.utc(2026, 8, 4),
      'assuranceInvalidatedByUid': 'fixture',
      'assuranceInvalidatedByName': 'Fixture',
      'assuranceInvalidationReason': 'Removal for inspection',
      'assuranceEpisodeId': 'episode-1',
    },
  }, id);
}

BaseInnerCoverAssignment _assignment(InnerCoverProfile p, int base) =>
    BaseInnerCoverAssignment(
      baseAssetInstanceId: 'base-$base',
      baseAssetClassId: _baseClass.id,
      baseAssetNumber: base,
      baseAssetName: 'Base $base',
      innerCoverId: p.id,
      innerCoverSerialNumber: p.serialNumber,
      linkageId: 'link-${p.serialNumber}',
      linkedAt: _at,
      version: 1,
      updatedAt: _at,
      lastMutationId: 'fixture',
    );
InnerCoverLinkage _link(InnerCoverProfile p, int base) => InnerCoverLinkage(
  id: 'link-${p.serialNumber}',
  baseAssetInstanceId: 'base-$base',
  baseAssetNumber: base,
  baseAssetName: 'Base $base',
  innerCoverId: p.id,
  innerCoverSerialNumber: p.serialNumber,
  installedAt: _at,
  installedByUid: 'fixture',
  installedByName: 'Fixture',
  active: true,
  version: 1,
);
AssetConditionDeclarationRecord _history(
  InnerCoverProfile p, {
  DateTime? recordedAt,
  String? serial,
}) => AssetConditionDeclarationRecord(
  id: 'bulged-${p.id}',
  assetId: p.id,
  assetSerialNumber: serial ?? p.serialNumber,
  evidenceCount: 1,
  firstConfirmedAt: recordedAt ?? _at,
  latestEvidenceAt: recordedAt ?? _at,
);
FurnaceStuckupRecord _case(
  InnerCoverProfile p, {
  bool active = true,
  bool confirmed = false,
  bool inconclusive = false,
}) => FurnaceStuckupRecord(
  id: 'case-${p.id}',
  ticketId: 'ticket-1',
  version: 1,
  obstructionStatus: active
      ? FurnaceStuckupObstructionStatus.active
      : FurnaceStuckupObstructionStatus.released,
  adjudicationStatus: inconclusive
      ? FurnaceStuckupAdjudicationStatus.inconclusive
      : confirmed
      ? FurnaceStuckupAdjudicationStatus.confirmed
      : FurnaceStuckupAdjudicationStatus.pending,
  suspectedCause: FurnaceStuckupCause.innerCoverBulging,
  confirmedCause: inconclusive
      ? FurnaceStuckupCause.inconclusive
      : confirmed
      ? FurnaceStuckupCause.innerCoverBulging
      : null,
  furnaceAssetInstanceId: 'furnace-1',
  furnaceAssetNumber: 1,
  baseAssetInstanceId: 'base-101',
  baseAssetNumber: 101,
  innerCoverId: p.id,
  innerCoverSerialNumber: p.serialNumber,
  operatingContext: FurnaceStuckupOperatingContext.maintenanceMovement,
  chargeNoAtEvent: null,
  reportedAt: _at,
  reportedByName: 'Fixture',
  releasedAt: active ? null : _at,
  releaseNotes: active ? null : 'Removed',
  adjudicatedAt: confirmed ? _at : null,
  adjudicationNotes: confirmed ? 'Confirmed' : null,
  conditionDeclarationId: confirmed ? 'bulged-${p.id}' : null,
  updatedAt: _at,
);

class _Fixture {
  _Fixture({int installed = 0, List<InnerCoverProfile> extra = const []}) {
    bases = List.generate(
      47,
      (i) => f.asset(
        id: 'base-${101 + i}',
        assetClass: _baseClass,
        number: 101 + i,
      ),
    );
    profiles = [
      for (var i = 0; i < installed; i++)
        _cover('C${101 + i}', state: 'installed', base: 101 + i),
      ...extra,
    ];
    assignments = [
      for (var i = 0; i < installed; i++) _assignment(profiles[i], 101 + i),
    ];
    links = [for (var i = 0; i < installed; i++) _link(profiles[i], 101 + i)];
  }
  late List<AssetInstanceRecord> bases;
  late List<InnerCoverProfile> profiles;
  late List<BaseInnerCoverAssignment> assignments;
  late List<InnerCoverLinkage> links;
  InnerCoverStockSummary build({
    String? unqualified,
    String mode = 'cache',
    bool qualifyDependencies = true,
    List<FurnaceStuckupRecord> cases = const [],
    List<AssetConditionDeclarationRecord> declarations = const [],
  }) {
    DecodedSnapshotBatch<T> batch<T>(String source, List<T> records) =>
        DecodedSnapshotBatch(
          records: records,
          isFromCache: unqualified == source && mode == 'cache',
          hasPendingWrites: unqualified == source && mode == 'pending',
          rejectedDocumentIds: unqualified == source && mode == 'rejected'
              ? ['unreadable']
              : [],
        );
    final classBatch = batch<AssetClassRecord>('classes', [
      _baseClass,
      _coverClass,
    ]);
    final assetBatch = batch('assets', bases);
    final profileBatch = batch('profiles', profiles);
    final assignmentBatch = batch('assignments', assignments);
    final linkBatch = batch('links', links);
    final register = buildBaseInnerCoverRegister(
      classes: classBatch,
      assets: assetBatch,
      assignments: assignmentBatch,
      covers: profileBatch,
      linkages: linkBatch,
    );
    final summary = buildInnerCoverStockSummary(
      classes: classBatch,
      profiles: profileBatch,
      assignments: assignmentBatch,
      links: linkBatch,
      register: register,
      cases: batch('cases', cases),
      declarations: batch('declarations', declarations),
    );
    return qualifyDependencies
        ? annotateInnerCoverStockDependencies(summary, _dependencies(this))
        : summary;
  }

  PlantAssetOverview overview(InnerCoverStockSummary stock) =>
      physicalPlantInventory(
        overview: const PlantAssetOverview(classes: [], assets: []),
        classes: [_baseClass, _coverClass],
        profiles: profiles,
        innerCoverStock: stock,
      );
}

InnerCoverDependencyReason _workReason(
  InnerCoverProfile cover,
  InnerCoverDependencyKind kind, {
  String sourceId = 'work-1',
  bool pending = false,
}) => InnerCoverDependencyReason(
  key: '${kind.name}:$sourceId',
  sourceId: sourceId,
  kind: kind,
  coverId: cover.id,
  serialNumber: cover.serialNumber,
  eventHostAssetId: 'base-101',
  eventHostClassId: 'bases',
  eventHostNumber: 101,
  eventLinkageId: 'historic-link',
  awaitingServerConfirmation: pending,
);

InnerCoverDependencies _dependencies(
  _Fixture fixture, {
  List<InnerCoverDependencyReason> reasons = const [],
  bool complete = true,
}) => InnerCoverDependencies(
  complete: complete,
  evidenceWarnings: complete ? [] : ['Issue/maintenance feed unavailable'],
  byCoverId: {
    for (final p in fixture.profiles)
      p.id: InnerCoverDependencyState(
        coverId: p.id,
        serialNumber: p.serialNumber,
        reasons: reasons.where((r) => r.coverId == p.id),
        warnings: complete ? [] : ['Issue/maintenance feed unavailable'],
        complete: complete,
      ),
  },
);

void main() {
  test('assessment with recorded work stays excluded from candidate stock', () {
    final cover = _cover('ASSESS-WORK');
    final fixture = _Fixture(extra: [cover]);
    for (final kind in InnerCoverDependencyKind.values) {
      final stock = annotateInnerCoverStockDependencies(
        fixture.build(cases: [_case(cover)]),
        _dependencies(fixture, reasons: [_workReason(cover, kind)]),
      );
      expect(stock.excluded, 1, reason: kind.name);
      expect(stock.assessmentRequired, 0);
      expect(stock.acceptedUnassigned, 0);
      expect(stock.rows.single.needsCurrentAssessment, isTrue);
    }
  });
  test(
    'confirmed bulging keeps physical unfit precedence over unavailable issue',
    () {
      final cover = _cover('BULGE-WORK');
      final fixture = _Fixture(extra: [cover]);
      final stock = fixture.build(cases: [_case(cover, confirmed: true)]);
      final plant = applyInnerCoverDependencies(
        overview: fixture.overview(stock),
        register: buildBaseInnerCoverRegister(
          classes: _batch([_baseClass, _coverClass]),
          assets: _batch(fixture.bases),
          assignments: _batch(fixture.assignments),
          covers: _batch(fixture.profiles),
          linkages: _batch(fixture.links),
        ),
        dependencies: _dependencies(
          fixture,
          reasons: [_workReason(cover, InnerCoverDependencyKind.unavailable)],
        ),
      );
      expect(plant.unfit, 1);
      expect(plant.issueUnavailable, 0);
      expect(plant.available, 0);
      expect(
        plant.innerCovers.single.conditionReasons,
        contains('Unavailable by Inner Cover issue'),
      );
    },
  );
  for (final width in [320.0, 360.0, 393.0]) {
    for (final scale in [1.0, 2.5]) {
      testWidgets(
        'compact cover counts keep current and history separate at $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final active = _cover('BULGING');
          final history = _cover('HISTORY');
          final fixture = _Fixture(installed: 1, extra: [active, history]);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: InnerCoverStockPanel(
                      summary: fixture.build(
                        cases: [_case(active, confirmed: true)],
                        declarations: [_history(history)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Spare candidates 1'), findsOneWidget);
          expect(find.text('Installed 1'), findsOneWidget);
          expect(find.text('Excluded 1'), findsOneWidget);
          expect(
            find.text('Current concerns: confirmed bulging 1'),
            findsOneWidget,
          );
          expect(find.textContaining('Bulge history: 2'), findsOneWidget);
          expect(find.textContaining('Inner Cover HISTORY:'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test('active confirmed bulging excludes a spare and Plant availability', () {
    final cover = _cover('ACTIVE');
    final fixture = _Fixture(extra: [cover]);
    final stock = fixture.build(cases: [_case(cover, confirmed: true)]);
    expect(stock.acceptedUnassigned, 0);
    expect(stock.excluded, 1);
    final plant = fixture.overview(stock);
    expect(plant.available, 0);
    expect(plant.unfit, 1);
    expect(plant.down, 0);
    expect(
      plant.innerCovers.single.conditionSummary,
      contains('Confirmed bulging'),
    );
  });
  test('active unresolved bulging needs assessment without claiming unfit', () {
    for (final inconclusive in [false, true]) {
      final cover = _cover('ASSESS');
      final fixture = _Fixture(extra: [cover]);
      final stock = fixture.build(
        cases: [_case(cover, inconclusive: inconclusive)],
      );
      expect(stock.acceptedUnassigned, 0);
      expect(stock.excluded, 0);
      final plant = fixture.overview(stock);
      expect(plant.available, 0);
      expect(plant.unfit, 0);
      expect(
        plant.innerCovers.single.conditionSummary,
        contains('Assessment needed'),
      );
    }
  });
  test('released assessment and history do not become current bulging', () {
    for (final inconclusive in [false, true]) {
      final cover = _cover('RELEASED');
      final fixture = _Fixture(extra: [cover]);
      final stock = fixture.build(
        cases: [_case(cover, active: false, inconclusive: inconclusive)],
        declarations: [_history(cover)],
      );
      expect(stock.acceptedUnassigned, 1);
      expect(fixture.overview(stock).available, 1);
      expect(fixture.overview(stock).unfit, 0);
    }
  });
  test(
    'installed current bulging retains linkage count without available claim',
    () {
      final fixture = _Fixture(installed: 1);
      final stock = fixture.build(
        cases: [_case(fixture.profiles.single, confirmed: true)],
      );
      expect(stock.installed, 1);
      expect(stock.acceptedUnassigned, 0);
      expect(fixture.overview(stock).available, 0);
      expect(fixture.overview(stock).unfit, 1);
      expect(fixture.overview(stock).down, 0);
    },
  );
  test('unverified current condition cannot be available in Plant', () {
    final fixture = _Fixture(extra: [_cover('UNKNOWN')]);
    for (final mode in ['cache', 'pending', 'rejected']) {
      final stock = fixture.build(unqualified: 'cases', mode: mode);
      expect(stock.acceptedUnassigned, isNull);
      expect(fixture.overview(stock).available, 0);
      expect(fixture.overview(stock).unfit, 0);
      expect(fixture.overview(stock).unverifiedWorkflowEvidence, 1);
    }
  });
  test(
    'dependency overlay excludes a restricted accepted unassigned cover from spare candidates',
    () {
      final cover = _cover('FAULTY');
      final fixture = _Fixture(extra: [cover]);
      final original = fixture.build();
      final overview = applyInnerCoverDependencies(
        overview: fixture.overview(original),
        register: buildBaseInnerCoverRegister(
          classes: _batch([_baseClass, _coverClass]),
          assets: _batch(fixture.bases),
          assignments: _batch(fixture.assignments),
          covers: _batch(fixture.profiles),
          linkages: _batch(fixture.links),
        ),
        dependencies: _dependencies(
          fixture,
          reasons: [_workReason(cover, InnerCoverDependencyKind.unfit)],
        ),
      );
      expect(overview.innerCoverStock!.acceptedUnassigned, 0);
      expect(overview.innerCoverStock!.excluded, 1);
      expect(original.acceptedUnassigned, 1);
    },
  );
  test(
    'all active dependency kinds exclude candidates without changing installed inventory',
    () {
      final spare = _cover('RESTRICTED');
      final fixture = _Fixture(installed: 1, extra: [spare]);
      final original = fixture.build();
      for (final kind in InnerCoverDependencyKind.values) {
        final summary = annotateInnerCoverStockDependencies(
          original,
          _dependencies(
            fixture,
            reasons: [
              _workReason(spare, kind),
              _workReason(
                fixture.profiles.first,
                kind,
                sourceId: 'installed-work',
              ),
            ],
          ),
        );
        expect(summary.installed, 1, reason: kind.name);
        expect(summary.acceptedUnassigned, 0, reason: kind.name);
        expect(summary.excluded, 1, reason: kind.name);
        expect(summary.review, hasLength(2), reason: kind.name);
        expect(summary.rows.last.reviewReasons.join(' '), contains('work-1'));
      }
      expect(original.installed, 1);
      expect(original.acceptedUnassigned, 1);
      expect(original.review, isEmpty);
    },
  );
  test(
    'clearing one restriction preserves the other and retained bulge history',
    () {
      final spare = _cover('HISTORY');
      final fixture = _Fixture(extra: [spare]);
      final original = fixture.build(declarations: [_history(spare)]);
      final issue = _workReason(spare, InnerCoverDependencyKind.unfit);
      final job = _workReason(
        spare,
        InnerCoverDependencyKind.maintenance,
        sourceId: 'job-2',
      );
      for (final remaining in [
        [issue, job],
        [job],
      ]) {
        final summary = annotateInnerCoverStockDependencies(
          original,
          _dependencies(fixture, reasons: remaining),
        );
        expect(summary.acceptedUnassigned, 0);
        expect(summary.excluded, 1);
        expect(summary.bulgeHistory, 1);
        expect(
          summary.review.single.reviewReasons,
          contains('Bulge history — confirm present condition'),
        );
      }
      final clear = annotateInnerCoverStockDependencies(
        original,
        _dependencies(fixture),
      );
      expect(clear.acceptedUnassigned, 1);
      expect(clear.acceptedUnassignedWithHistory, 1);
      expect(clear.bulgeHistory, 1);
    },
  );
  test(
    'unknown missing conflicting and pending dependency evidence never certifies candidates',
    () {
      final spare = _cover('SPARE');
      final fixture = _Fixture(installed: 1, extra: [spare]);
      final original = fixture.build();
      final good = _dependencies(fixture);
      final variants = <InnerCoverDependencies>[
        _dependencies(fixture, complete: false),
        InnerCoverDependencies(
          byCoverId: {},
          evidenceWarnings: [],
          complete: true,
        ),
        InnerCoverDependencies(
          byCoverId: good.byCoverId,
          evidenceWarnings: ['unreadable work'],
          complete: true,
        ),
        for (final serial in ['OTHER', spare.serialNumber])
          InnerCoverDependencies(
            byCoverId: {
              ...good.byCoverId,
              spare.id: InnerCoverDependencyState(
                coverId: spare.id,
                serialNumber: serial,
                reasons: [],
                warnings: [],
                complete: serial == 'OTHER',
              ),
            },
            evidenceWarnings: [],
            complete: true,
          ),
        _dependencies(
          fixture,
          reasons: [
            _workReason(spare, InnerCoverDependencyKind.unfit, pending: true),
          ],
        ),
      ];
      for (final dependencies in variants) {
        final summary = annotateInnerCoverStockDependencies(
          original,
          dependencies,
        );
        expect(summary.installed, 1);
        expect(summary.acceptedUnassigned, isNull);
        expect(summary.excluded, isNull);
        expect(summary.dependencyEvidenceConfirmed, isFalse);
        expect(summary.forClass('covers').acceptedUnassigned, isNull);
        expect(
          summary.review.map((r) => r.reviewReasons.join(' ')).join(' '),
          contains('evidence unverified'),
        );
      }
      final known = annotateInnerCoverStockDependencies(
        original,
        _dependencies(
          fixture,
          complete: false,
          reasons: [_workReason(spare, InnerCoverDependencyKind.unfit)],
        ),
      );
      expect(known.activeIssueRestrictions, 1);
      expect(
        known.rows.singleWhere((r) => r.profile.id == spare.id).disposition,
        InnerCoverStockDisposition.excluded,
      );
      expect(
        fixture.build(qualifyDependencies: false).acceptedUnassigned,
        isNull,
      );
    },
  );
  const evidenceDirectory = String.fromEnvironment('COVER_STOCK_EVIDENCE_DIR');
  if (evidenceDirectory.isNotEmpty) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(() async {
      await (FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Roboto-Medium.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
  }
  test(
    '47 installations plus stock does not mean total-minus-47 usable spares',
    () {
      final fixture = _Fixture(
        installed: 47,
        extra: [
          _cover('SPARE'),
          _cover('QUAR', state: 'quarantined'),
          _cover('REACCEPT', reaccept: true),
        ],
      );
      final stock = fixture.build();
      expect(stock.rows, hasLength(50));
      expect(stock.installed, 47);
      expect(stock.acceptedUnassigned, 1);
      expect(stock.excluded, 2);
      expect(
        stock.rows
            .singleWhere((r) => r.profile.serialNumber == 'REACCEPT')
            .reviewReasons,
        contains('Reacceptance required'),
      );
      expect(fixture.overview(stock).down, 0);
    },
  );
  test(
    'retained bulge history does not become current unfit or clear itself by timestamp',
    () {
      final cover = _cover('HISTORY');
      final fixture = _Fixture(extra: [cover]);
      for (final recorded in [
        DateTime.utc(2026, 8, 1),
        DateTime.utc(2026, 8, 9),
      ]) {
        final stock = fixture.build(
          declarations: [_history(cover, recordedAt: recorded)],
        );
        expect(stock.acceptedUnassigned, 1);
        expect(stock.excluded, 0);
        expect(stock.rows.single.reviewReasons, [
          'Bulge history — confirm present condition',
        ]);
      }
    },
  );
  test(
    'active confirmed and released pending bulge cases have distinct factual callouts',
    () {
      final cover = _cover('CONCERN');
      final fixture = _Fixture(extra: [cover]);
      expect(
        fixture
            .build(cases: [_case(cover, confirmed: true)])
            .rows
            .single
            .reviewReasons,
        contains('Active obstruction with confirmed bulging'),
      );
      final pending = fixture
          .build(cases: [_case(cover, active: false)])
          .rows
          .single;
      expect(
        pending.reviewReasons,
        contains('Released obstruction; bulge assessment pending'),
      );
      expect(
        pending.reviewReasons,
        isNot(contains('Active obstruction with confirmed bulging')),
      );
      expect(
        pending.disposition,
        InnerCoverStockDisposition.acceptedUnassigned,
      );
    },
  );
  test(
    'cache pending and rejected evidence cannot turn unknown stock into accepted spare counts',
    () {
      final fixture = _Fixture(extra: [_cover('SPARE')]);
      for (final source in [
        'classes',
        'assets',
        'profiles',
        'assignments',
        'links',
        'cases',
        'declarations',
      ]) {
        for (final mode in ['cache', 'pending', 'rejected']) {
          final stock = fixture.build(unqualified: source, mode: mode);
          expect(stock.acceptedUnassigned, isNull, reason: '$source $mode');
          expect(stock.unverified, 1);
        }
      }
    },
  );
  test(
    'orphan claims duplicate identities and contradictory concern serials remain unverified',
    () {
      final cover = _cover('SPARE');
      final orphan = _Fixture(extra: [cover])
        ..assignments = [_assignment(cover, 999)];
      expect(orphan.build().acceptedUnassigned, isNull);
      final duplicate = _Fixture(extra: [cover, cover]);
      expect(duplicate.build().acceptedUnassigned, isNull);
      expect(
        _Fixture(extra: [cover])
            .build(declarations: [_history(cover, serial: 'OTHER')])
            .acceptedUnassigned,
        isNull,
      );
    },
  );
  testWidgets(
    'Home separates accepted unassigned stock from installed and retained bulge history',
    (tester) async {
      final cover = _cover('SPARE');
      final fixture = _Fixture(installed: 47, extra: [cover]);
      final stock = fixture.build(declarations: [_history(cover)]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlantOverviewPanel(
                overview: AsyncData(fixture.overview(stock)),
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spare candidates 1'), findsOneWidget);
      expect(find.textContaining('Installed 47'), findsOneWidget);
      expect(find.textContaining('Inner Cover SPARE:'), findsNothing);
    },
  );

  test(
    'inconclusive suspected bulging retains active or released uncertainty without confirmed attribution',
    () {
      final cover = _cover('UNCERTAIN');
      final fixture = _Fixture(extra: [cover]);
      for (final active in [true, false]) {
        final summary = fixture.build(
          cases: [_case(cover, active: active, inconclusive: true)],
        );
        expect(summary.inconclusiveBulgeAssessment, 1);
        expect(summary.activeConfirmedBulging, 0);
        expect(summary.bulgeHistory, 0);
        expect(
          summary.review.single.reviewReasons,
          contains(
            active
                ? 'Active obstruction; bulge assessment inconclusive'
                : 'Released obstruction; bulge assessment inconclusive',
          ),
        );
      }
    },
  );
  test(
    'provider withholds availability while current bulge evidence is unverified',
    () async {
      final fixture = _Fixture(extra: [_cover('SPARE')]);
      final cases =
          StreamController<DecodedSnapshotBatch<FurnaceStuckupRecord>>();
      final declarations =
          StreamController<
            DecodedSnapshotBatch<AssetConditionDeclarationRecord>
          >();
      final container = _provider(
        fixture,
        cases: cases.stream,
        declarations: declarations.stream,
      );
      addTearDown(() async {
        container.dispose();
        await cases.close();
        await declarations.close();
      });
      await pumpEventQueue();
      InnerCoverStockSummary stock() => container
          .read(plantAssetOverviewProvider)
          .requireValue
          .innerCoverStock!;
      expect(stock().acceptedUnassigned, isNull);
      declarations.add(
        _batch([_history(fixture.profiles.single)], pending: true),
      );
      cases.add(_batch([], cached: true));
      await pumpEventQueue();
      expect(stock().acceptedUnassigned, isNull);
      cases.addError(StateError('Current concerns unavailable'));
      await pumpEventQueue();
      expect(stock().bulgeHistory, isNull);
      expect(
        container.read(plantAssetOverviewProvider).requireValue.available,
        0,
      );
      cases.add(_batch([]));
      declarations.add(_batch([_history(fixture.profiles.single)]));
      await pumpEventQueue();
      expect(stock().acceptedUnassigned, 1);
      expect(stock().acceptedUnassignedWithHistory, 1);
      expect(stock().bulgeHistory, 1);
      expect(
        container.read(plantAssetOverviewProvider).requireValue.available,
        1,
      );
      expect(container.read(plantAssetOverviewProvider).requireValue.down, 0);
    },
  );
  test(
    'provider still checks orphan assignments when no Base is registered',
    () async {
      final fixture = _Fixture(extra: [_cover('SPARE')]);
      fixture.bases = [];
      fixture.assignments = [_assignment(fixture.profiles.single, 999)];
      final container = _provider(
        fixture,
        cases: Stream.value(_batch([])),
        declarations: Stream.value(_batch([])),
      );
      addTearDown(container.dispose);
      await pumpEventQueue();
      expect(
        container
            .read(plantAssetOverviewProvider)
            .requireValue
            .innerCoverStock!
            .acceptedUnassigned,
        isNull,
      );
    },
  );
  test(
    'provider requires current workflow and execution evidence before confirming spare candidates',
    () async {
      final fixture = _Fixture(installed: 1, extra: [_cover('SPARE')]);
      final workflows =
          StreamController<PlantEvidenceBatch<InnerCoverWorkflowEvidence>>();
      final executions = StreamController<PlantEvidenceBatch<JobExecution>>();
      final container = _provider(
        fixture,
        cases: Stream.value(_batch([])),
        declarations: Stream.value(_batch([])),
        workflows: workflows.stream,
        executions: executions.stream,
      );
      addTearDown(() async {
        container.dispose();
        await workflows.close();
        await executions.close();
      });
      PlantEvidenceBatch<T> work<T>({
        bool current = true,
        bool rejected = false,
      }) => PlantEvidenceBatch(
        rows: <T>[],
        rejected: rejected ? {'bad-work': 'Invalid serial snapshot'} : {},
        fromServer: current,
        observedAt: _at,
      );
      InnerCoverStockSummary stock() => container
          .read(plantAssetOverviewProvider)
          .requireValue
          .innerCoverStock!;
      await pumpEventQueue();
      expect(stock().installed, 1);
      expect(stock().acceptedUnassigned, isNull);
      workflows.add(work(current: false));
      executions.add(work());
      await pumpEventQueue();
      expect(stock().acceptedUnassigned, isNull);
      workflows.add(work(rejected: true));
      await pumpEventQueue();
      expect(stock().acceptedUnassigned, isNull);
      workflows.addError(StateError('Work evidence unavailable'));
      await pumpEventQueue();
      expect(stock().acceptedUnassigned, isNull);
      workflows.add(work());
      executions.add(work(current: false));
      await pumpEventQueue();
      expect(stock().acceptedUnassigned, isNull);
      executions.add(work());
      await pumpEventQueue();
      expect(stock().installed, 1);
      expect(stock().acceptedUnassigned, 1);
      expect(stock().dependencyEvidenceConfirmed, isTrue);
    },
  );
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'stock concerns are visible and details stay compact at $width / $scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final spare = _cover('SPARE');
        final restricted = _cover('FAULTY');
        final fixture = _Fixture(
          installed: 47,
          extra: [
            spare,
            restricted,
            _cover('QUAR', state: 'quarantined'),
          ],
        );
        final dependencies = _dependencies(
          fixture,
          reasons: [
            _workReason(
              restricted,
              InnerCoverDependencyKind.unavailable,
              sourceId: 'issue-2',
            ),
            _workReason(
              restricted,
              InnerCoverDependencyKind.maintenance,
              sourceId: 'job-3',
            ),
          ],
        );
        final originalStock = fixture.build(declarations: [_history(spare)]);
        final overview = applyInnerCoverDependencies(
          overview: fixture.overview(originalStock),
          register: buildBaseInnerCoverRegister(
            classes: _batch([_baseClass, _coverClass]),
            assets: _batch(fixture.bases),
            assignments: _batch(fixture.assignments),
            covers: _batch(fixture.profiles),
            linkages: _batch(fixture.links),
          ),
          dependencies: dependencies,
        );
        var opens = 0;
        const previewKey = ValueKey('synthetic-stock-preview');
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              fontFamily: evidenceDirectory.isEmpty ? null : 'Roboto',
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              backgroundColor: Colors.white,
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: previewKey,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Synthetic preview — not phone evidence'),
                          PlantOverviewPanel(
                            overview: AsyncData(overview),
                            onOpen: () => opens++,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Bulge history: 1'), findsOneWidget);
        expect(find.textContaining('Check current condition'), findsOneWidget);
        expect(
          find.text('Current concerns: issues 1 · maintenance 1'),
          findsOneWidget,
        );
        expect(find.text('Spare candidates 1'), findsOneWidget);
        expect(find.textContaining('Inner Cover FAULTY:'), findsNothing);
        expect(find.textContaining('Inner Cover SPARE:'), findsNothing);
        expect(find.textContaining('Inner Cover C101:'), findsNothing);
        expect(find.byType(ExpansionTile), findsOneWidget);
        if (evidenceDirectory.isNotEmpty && scale == 1) {
          await tester.runAsync(() async {
            final image =
                await (tester.renderObject(find.byKey(previewKey))
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$evidenceDirectory/synthetic-stock-390.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        final review = find.byKey(
          const PageStorageKey('inner-cover-stock-review-covers'),
        );
        await tester.ensureVisible(review);
        await tester.tap(review);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'Inner Cover SPARE: Bulge history — confirm present condition',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Inner Cover QUAR: Not a spare candidate: Quarantined',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Inner Cover C101:'), findsNothing);
        expect(
          find.textContaining(
            'Inner Cover FAULTY: Active issue: unavailable (issue-2) · Active maintenance (job-3)',
          ),
          findsOneWidget,
        );
        expect(opens, 0);
        final all = find.text('Open Plant condition for all inner covers.');
        await tester.ensureVisible(all);
        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(opens, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

DecodedSnapshotBatch<T> _batch<T>(
  List<T> rows, {
  bool cached = false,
  bool pending = false,
}) => DecodedSnapshotBatch(
  records: rows,
  rejectedDocumentIds: [],
  isFromCache: cached,
  hasPendingWrites: pending,
);
ProviderContainer _provider(
  _Fixture fixture, {
  Stream<PlantEvidenceBatch<InnerCoverWorkflowEvidence>>? workflows,
  Stream<PlantEvidenceBatch<JobExecution>>? executions,
  required Stream<DecodedSnapshotBatch<FurnaceStuckupRecord>> cases,
  required Stream<DecodedSnapshotBatch<AssetConditionDeclarationRecord>>
  declarations,
}) {
  PlantEvidenceBatch<T> evidence<T>(List<T> rows) => PlantEvidenceBatch(
    rows: rows,
    rejected: {},
    fromServer: true,
    observedAt: _at,
  );
  final container = ProviderContainer(
    overrides: [
      plantClassEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence([_baseClass, _coverClass])),
      ),
      plantAssetEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence(fixture.bases)),
      ),
      plantManualEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence([])),
      ),
      plantWorkflowEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence([])),
      ),
      plantAvailabilityEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence([])),
      ),
      plantTicketEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence([])),
      ),
      plantConditionTicketsProvider.overrideWith((ref) => Stream.value([])),
      plantInnerCoverWorkflowEvidenceProvider.overrideWith(
        (ref) =>
            workflows ?? Stream.value(evidence<InnerCoverWorkflowEvidence>([])),
      ),
      plantInnerCoverExecutionEvidenceProvider.overrideWith(
        (ref) => executions ?? Stream.value(evidence<JobExecution>([])),
      ),
      plantInnerCoverEvidenceProvider.overrideWith(
        (ref) => Stream.value(evidence(fixture.profiles)),
      ),
      plantCoverAssignmentEvidenceProvider.overrideWith(
        (ref) => Stream.value(_batch(fixture.assignments)),
      ),
      plantActiveCoverLinkEvidenceProvider.overrideWith(
        (ref) => Stream.value(_batch(fixture.links)),
      ),
      furnaceStuckupCaseBatchProvider.overrideWith((ref) => cases),
      innerCoverBulgeDeclarationBatchProvider.overrideWith(
        (ref) => declarations,
      ),
    ],
  );
  container.listen(plantAssetOverviewProvider, (_, _) {});
  return container;
}
