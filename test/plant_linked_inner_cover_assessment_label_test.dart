import 'package:crm3_baf_ops/features/assets/domain/apply_inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_condition_submission_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'inner_cover_dependency_integration_test.dart' as fixture;

void main() {
  for (final scenario in [
    (393.0, 1.0, false),
    (320.0, 2.5, false),
    (393.0, 1.0, true),
  ]) {
    testWidgets(
      'Base row explains linked cover fitness assessment at $scenario',
      (tester) async {
        tester.view.physicalSize = Size(scenario.$1, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = fixture.Fixture();
        final cover = f.profiles.first;
        final dependencies = InnerCoverDependencies(
          byCoverId: {
            for (final profile in f.profiles)
              profile.id: InnerCoverDependencyState(
                coverId: profile.id,
                serialNumber: profile.serialNumber,
                reasons: [
                  if (profile.id == cover.id)
                    for (final kind in [
                      InnerCoverDependencyKind.assessment,
                      if (scenario.$3) InnerCoverDependencyKind.maintenance,
                    ])
                      InnerCoverDependencyReason(
                        key: 'fixture-${kind.name}',
                        sourceId: 'fixture-${kind.name}',
                        kind: kind,
                        coverId: profile.id,
                        serialNumber: profile.serialNumber,
                        eventHostAssetId: f.bases.first.id,
                        eventHostClassId: fixture.baseClass.id,
                        eventHostNumber: f.bases.first.assetNumber,
                        eventLinkageId: f.links.first.id,
                        awaitingServerConfirmation: false,
                      ),
                ],
                warnings: const [],
                complete: true,
              ),
          },
          evidenceWarnings: const [],
          complete: true,
        );
        final view = applyInnerCoverDependencies(
          overview: f.build(),
          register: fixture.registerFor(f),
          dependencies: dependencies,
        );
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
                    createdAt: fixture.at,
                  ),
                ),
              ),
              plantAssetOverviewProvider.overrideWith((ref) => AsyncData(view)),
              plantConditionTicketsProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              for (final base in f.bases)
                assetConditionPendingProvider(
                  base.id,
                ).overrideWith((ref) async => null),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
                child: child!,
              ),
              home: AssetConditionBoard(
                initialAssetClassId: fixture.baseClass.id,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Base 119'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final expected =
            'Linked Inner Cover G66: '
            '${scenario.$3 ? 'maintenance work open · ' : ''}fitness assessment needed';
        expect(find.text(expected), findsOneWidget);
        expect(find.text('Linked Inner Cover G66: '), findsNothing);
        expect(view.assets.first.isDown, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
