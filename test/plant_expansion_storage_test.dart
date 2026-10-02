import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/base_cover_reconciliation.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_stock_summary.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/presentation/widgets/base_cover_reconciliation_panel.dart';
import 'package:crm3_baf_ops/features/assets/presentation/widgets/inner_cover_stock_panel.dart';
import 'package:crm3_baf_ops/features/reports/domain/base_inner_cover_register.dart';
import 'inner_cover_lifecycle_model_test.dart' as profile;
import 'plant_asset_overview_test.dart' as fixture;

final _cover = InnerCoverProfile.fromMap(
  profile.profileMap(state: 'quarantined'),
  'cover-1',
);
final _coverState = PlantInnerCoverState(profile: _cover);
final _baseClass = fixture.assetClass(
  id: 'bases',
  code: 'BASE',
  name: 'Base',
  legacyKey: 'base',
);
final _baseRow = BaseCoverRegisterRow(
  base: fixture.asset(
    id: 'synthetic-base',
    assetClass: _baseClass,
    number: 901,
  ),
  state: BaseCoverLinkState.empty,
  explanation: 'No recorded link',
);
final _reconciliation = BaseCoverReconciliation(
  rows: [_baseRow],
  needsReview: [_baseRow],
  conditionUnverified: 0,
  populationConfirmed: true,
);
final _stock = InnerCoverStockSummary(
  rows: [
    InnerCoverStockRow(
      profile: _cover,
      disposition: InnerCoverStockDisposition.excluded,
      reviewReasons: ['Quarantined'],
      evidenceUnverified: false,
      activeConfirmedBulging: false,
      pendingBulgeAssessment: false,
      bulgeHistory: false,
      inconclusiveBulgeAssessment: false,
    ),
  ],
  inventoryConfirmed: true,
  linkageConfirmed: true,
  bulgeEvidenceConfirmed: true,
  dependencyEvidenceConfirmed: true,
);
final _fallback = PlantAssetOverview(
  classes: [
    PlantAssetClassSummary(
      assetClass: fixture.assetClass(
        id: 'class-1',
        code: 'INNER_COVER',
        name: 'Inner Cover',
        legacyKey: 'innerCover',
      ),
      assets: const [],
      innerCovers: [_coverState],
    ),
  ],
  assets: const [],
  innerCovers: [_coverState],
);

void main() {
  final panels = <String, Widget Function()>{
    'Base reconciliation': () => BaseCoverReconciliationPanel(
      summary: _reconciliation,
      onReviewBase: (_) {},
      onReviewLinks: () {},
    ),
    'Inner Cover stock': () => InnerCoverStockPanel(summary: _stock),
    'fallback Inner Cover summary': () =>
        PlantOverviewPanel(overview: AsyncData(_fallback), onOpen: () {}),
  };
  for (final panel in panels.entries) {
    testWidgets(
      '${panel.key} appears after a real saved scroll offset without a storage type collision',
      (tester) async {
        final bucket = PageStorageBucket();
        final content = ValueNotifier<Widget>(const SizedBox(height: 180));
        addTearDown(content.dispose);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PageStorage(
                bucket: bucket,
                child: ListView(
                  key: const PageStorageKey('home-list'),
                  controller: controller,
                  children: [
                    const SizedBox(height: 400),
                    ValueListenableBuilder<Widget>(
                      valueListenable: content,
                      builder: (_, value, _) => value,
                    ),
                    const SizedBox(height: 1400),
                  ],
                ),
              ),
            ),
          ),
        );
        controller.jumpTo(160);
        await tester.pumpAndSettle();
        expect(bucket.readState(tester.element(find.byType(ListView))), 160.0);
        content.value = panel.value();
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Late business data must not read the ListView double as an expansion boolean.',
        );
        if (panel.key == 'fallback Inner Cover summary') {
          final toggle = find.byKey(
            const ValueKey('plant-inner-cover-toggle-class-1'),
          );
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
        }
        final tile = find.byType(ExpansionTile);
        expect(tile, findsOneWidget);
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: tile, matching: find.byType(ListTile)).first,
        );
        await tester.pumpAndSettle();
        final scrollOffset = bucket.readState(
          tester.element(find.byType(ListView)),
        );
        expect(scrollOffset, isA<double>());
        expect(bucket.readState(tester.element(tile)), isTrue);
        content.value = const SizedBox(height: 180);
        await tester.pumpAndSettle();
        content.value = panel.value();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (panel.key == 'fallback Inner Cover summary' &&
            find.byType(ExpansionTile).evaluate().isEmpty) {
          final toggle = find.byKey(
            const ValueKey('plant-inner-cover-toggle-class-1'),
          );
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
        }
        expect(
          bucket.readState(tester.element(find.byType(ExpansionTile))),
          isTrue,
        );
        expect(
          bucket.readState(tester.element(find.byType(ListView))),
          isA<double>(),
        );
      },
    );
  }
}
