import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/apply_inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/physical_plant_inventory.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/test_support/home_class_overview_fixture.dart';
import 'inner_cover_dependency_integration_test.dart' as linked;
import 'inner_cover_lifecycle_model_test.dart' as lifecycle;

PlantAssetOverview assessmentOverview({
  bool complete = true,
  bool known = true,
  bool overlap = false,
}) {
  final fixture = linked.Fixture();
  final cover = fixture.profiles.first;
  final base = fixture.bases.first;
  final dependencies = InnerCoverDependencies(
    byCoverId: {
      for (final profile in fixture.profiles)
        profile.id: InnerCoverDependencyState(
          coverId: profile.id,
          serialNumber: profile.serialNumber,
          reasons: [
            if (profile.id == cover.id && known)
              for (final kind in [
                InnerCoverDependencyKind.assessment,
                if (overlap) InnerCoverDependencyKind.maintenance,
              ])
                InnerCoverDependencyReason(
                  key: kind.name,
                  sourceId: 'retained-confirmed-case',
                  kind: kind,
                  coverId: cover.id,
                  serialNumber: cover.serialNumber,
                  eventHostAssetId: base.id,
                  eventHostClassId: base.assetClassId,
                  eventHostNumber: base.assetNumber,
                  eventLinkageId: cover.currentLinkageId!,
                  awaitingServerConfirmation: false,
                ),
          ],
          warnings: const [],
          complete: profile.id != cover.id || complete,
        ),
    },
    evidenceWarnings: const [],
    complete: complete,
  );
  return applyInnerCoverDependencies(
    overview: fixture.build(withWorkflow: overlap),
    register: linked.registerFor(fixture),
    dependencies: dependencies,
  );
}

Future<void> pump(
  WidgetTester tester,
  PlantAssetOverview value, {
  double scale = 1,
  required VoidCallback open,
}) async {
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
          child: PlantOverviewPanel(overview: AsyncData(value), onOpen: open),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [(393.0, 1.0), (320.0, 2.5)]) {
    testWidgets(
      'whole Plant header opens board and preserves independent disclosures at $size',
      (tester) async {
        tester.view.physicalSize = Size(size.$1, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opens = 0;
        await pump(
          tester,
          homeClassOverviewFixture(),
          scale: size.$2,
          open: () => opens++,
        );
        final header = find.byKey(
          const ValueKey('plant-condition-open-header'),
        );
        expect(header, findsOneWidget);
        expect(tester.getSize(header).height, greaterThanOrEqualTo(48));
        await tester.tap(find.text('Plant condition'));
        expect(opens, 1);
        final bounds = tester.getRect(header);
        await tester.tapAt(Offset(bounds.right - 66, bounds.top + 22));
        expect(
          opens,
          2,
          reason: 'Header whitespace is part of the navigation target.',
        );
        final arrow = find.byTooltip('Open plant condition');
        expect(arrow, findsOneWidget);
        await tester.tap(arrow);
        expect(
          opens,
          3,
          reason: 'Nested arrow must invoke navigation exactly once.',
        );
        final classRow = find.byKey(const ValueKey('plant-class-row-bases'));
        await tester.ensureVisible(classRow);
        await tester.tap(classRow);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plant-class-details-bases')),
          findsOneWidget,
        );
        expect(opens, 3);
        final ic = find.byKey(
          const ValueKey('plant-inner-cover-toggle-covers'),
        );
        await tester.ensureVisible(ic);
        await tester.tap(ic);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plant-inner-cover-details-covers')),
          findsOneWidget,
        );
        expect(opens, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final complete in [true, false]) {
    for (final overlap in [false, true]) {
      test(
        'known linked-cover assessment is unavailable once, complete=$complete overlap=$overlap',
        () {
          final value = assessmentOverview(
            complete: complete,
            overlap: overlap,
          );
          for (final summary in value.classes) {
            expect(summary.total, 2);
            expect(summary.available, 1);
            expect(summary.unavailable, 1);
            expect(summary.unverifiedAvailability, 0);
            expect(
              summary.available +
                  summary.unavailable +
                  summary.unverifiedAvailability,
              summary.total,
            );
            expect(
              summary.availabilityRate,
              isNull,
              reason:
                  'Pending fitness/evidence must not become a verified percentage.',
            );
          }
          expect(value.assets.first.isAvailable, isFalse);
          expect(value.innerCovers.first.isAvailable, isFalse);
          expect(value.assets.last.isAvailable, isTrue);
          expect(value.innerCovers.last.isAvailable, isTrue);
          expect(value.assets.first.asset.id, 'fixture-base-119');
          expect(
            value.assets.first.linkedInnerCoverDependency!.serialNumber,
            'G66',
          );
          expect(value.innerCovers.first.profile.serialNumber, 'G66');
          expect(value.down, 0);
          expect(
            value.unfit,
            0,
            reason:
                'A fitness assessment hold does not fabricate physical unfitness.',
          );
          expect(
            value.innerCovers.first.conditionReasons,
            contains('Assessment needed'),
          );
        },
      );
    }
  }
  test(
    'unknown-only linked evidence stays Unverified rather than unavailable',
    () {
      final value = assessmentOverview(complete: false, known: false);
      for (final summary in value.classes) {
        expect(summary.available, 1);
        expect(summary.unavailable, 0);
        expect(summary.unverifiedAvailability, 1);
        expect(summary.inventoryComplete, isTrue);
        expect(summary.availabilityRate, isNull);
      }
      expect(value.down, 0);
      expect(value.unfit, 0);
    },
  );
  testWidgets(
    'Home names exact Base and linked serial behind assessment hold',
    (tester) async {
      await pump(tester, assessmentOverview(), open: () {});
      await tester.tap(
        find.byKey(ValueKey('plant-class-row-${linked.baseClass.id}')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Cover assessment needed 1: Base 119 (Inner Cover G66)'),
        findsOneWidget,
      );
      expect(find.textContaining('Down 1'), findsNothing);
      expect(find.textContaining('Base 120 (Inner Cover G66)'), findsNothing);
    },
  );
  testWidgets(
    'wrong-class serial shows actionable review with optional record details',
    (tester) async {
      final original = linked.Fixture().profiles.first;
      final profile = InnerCoverProfile.fromMap({
        ...lifecycle.profileMap(state: 'underRepair'),
        'innerCoverId': original.id,
        'serialNumber': original.serialNumber,
        'normalizedSerialNumber': original.normalizedSerialNumber,
        'assetClassId': linked.baseClass.id,
        'assetClassCode': linked.baseClass.code,
        'assetClassName': linked.baseClass.name,
        'lifecycleState': 'underRepair',
      }, original.id);
      final view = physicalPlantInventory(
        overview: const PlantAssetOverview(classes: [], assets: []),
        classes: [linked.baseClass],
        profiles: [profile],
      );
      await pump(tester, view, open: () {});
      expect(find.text('Review class for 1 Inner Cover'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('plant-class-row-${linked.baseClass.id}')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Inner Cover G66:'), findsOneWidget);
      expect(find.textContaining('Under repair'), findsOneWidget);
      expect(
        find.text(
          "Check this Inner Cover's asset class before use. Open the condition board to review its record.",
        ),
        findsOneWidget,
      );
      expect(
        find.text('Inner Cover class is missing, retired or unverified.'),
        findsNothing,
      );
      final details = find.byKey(
        ValueKey('plant-cover-record-details-${profile.id}'),
      );
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(
        find.text('Inner Cover class is missing, retired or unverified.'),
        findsOneWidget,
      );
      expect(view.classes.single.unavailable, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
