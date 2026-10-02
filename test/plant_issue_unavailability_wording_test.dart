import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'plant_asset_overview_test.dart' as fixture;

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'explicit issue-unavailability label keeps its exact board filter at320px/$scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final cls = fixture.assetClass(
          id: 'base',
          code: 'BASE',
          name: 'Base',
          legacyKey: 'base',
        );
        final issue = fixture.asset(
          id: 'base-101',
          assetClass: cls,
          number: 101,
        );
        final unfit = fixture.asset(
          id: 'base-102',
          assetClass: cls,
          number: 102,
        );
        final overview = PlantAssetOverview.build(
          assetClasses: [cls],
          assetInstances: [issue, unfit],
          operationalConditions: [
            fixture.condition(
              asset: unfit,
              condition: AssetOperationalCondition.unfit,
            ),
          ],
          workflowStatuses: [],
          maintenanceTickets: [
            fixture.issueCondition(
              id: 'issue-101',
              asset: issue,
              effect: MaintenanceIssuePlantConditionEffect.unavailable,
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith(
                (ref) => Stream.value(
                  AppUser(
                    uid: 'reader',
                    name: 'Reader',
                    email: 'reader@example.invalid',
                    roles: [AppRole.operations],
                    isApproved: true,
                    createdAt: DateTime.utc(2026),
                  ),
                ),
              ),
              plantAssetOverviewProvider.overrideWith(
                (ref) => AsyncData(overview),
              ),
              plantConditionTicketsProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
            ],
            child: MaterialApp(
              theme: BafAppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const AssetConditionBoard(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final chip = find.widgetWithText(ChoiceChip, '1 unavailable by issue');
        await tester.scrollUntilVisible(
          chip,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
        expect(find.text('1 unfit'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Base 101'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Base 101'), findsOneWidget);
        expect(find.text('Base 102'), findsNothing);
        expect(find.text('Unavailable by issue'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
