import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crm3_baf_ops/features/assets/data/plant_condition_evidence.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/domain/qualified_plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_condition_submission_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'plant_asset_overview_test.dart' as f;

PlantEvidenceBatch<T> batch<T>(
  List<T> rows, {
  bool current = true,
  Map<String, String> rejected = const {},
}) => PlantEvidenceBatch(
  rows: rows,
  rejected: rejected,
  fromServer: current,
  observedAt: DateTime.utc(2026, 9, 20),
);
void main() {
  final cls = f.assetClass(
    id: 'furnace',
    code: 'FURNACE',
    name: 'Furnace',
    legacyKey: 'furnace',
  );
  final asset = f.asset(id: 'furnace-7', assetClass: cls, number: 7);
  final actor = AppUser(
    uid: 'admin',
    name: 'Admin',
    email: 'test@invalid.test',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  test(
    'actual provider combines partial sources without inventing an all-clear',
    () async {
      final container = ProviderContainer(
        overrides: [
          plantClassEvidenceProvider.overrideWith(
            (ref) => Stream.value(batch([cls])),
          ),
          plantAssetEvidenceProvider.overrideWith(
            (ref) => Stream.value(batch([asset])),
          ),
          plantManualEvidenceProvider.overrideWith(
            (ref) => Stream.value(
              batch([
                f.condition(
                  asset: asset,
                  condition: AssetOperationalCondition.down,
                ),
              ]),
            ),
          ),
          plantWorkflowEvidenceProvider.overrideWith(
            (ref) =>
                Stream.value(batch([f.workflow(key: 'furnace', number: 7)])),
          ),
          plantAvailabilityEvidenceProvider.overrideWith(
            (ref) => Stream.value(batch([])),
          ),
          plantTicketEvidenceProvider.overrideWith(
            (ref) => Stream.error(StateError('Issue source unavailable')),
          ),
          plantConditionTicketsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        plantAssetOverviewProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await pumpEventQueue();
      final result = container.read(plantAssetOverviewProvider).requireValue;
      expect(result.down, 1);
      expect(result.available, 0);
      expect(result.evidenceWarnings, isNotEmpty);
      expect(result.assets.single.permitsManualChange, isTrue);
    },
  );
  testWidgets('board shows partial evidence even when local issue feed fails', (
    tester,
  ) async {
    final overview = qualifiedPlantAssetOverview(
      classes: [cls],
      assets: [asset],
      conditions: [
        f.condition(asset: asset, condition: AssetOperationalCondition.down),
      ],
      workflow: [f.workflow(key: 'furnace', number: 7)],
      availability: [],
      tickets: [],
      populationWarnings: ['Issue source incomplete'],
      manualSourcesCurrent: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => Stream.value(actor)),
          plantAssetOverviewProvider.overrideWith((ref) => AsyncData(overview)),
          plantConditionTicketsProvider.overrideWith(
            (ref) => Stream.error(StateError('Local issue source unavailable')),
          ),
          assetConditionPendingProvider.overrideWith((ref, id) async => null),
        ],
        child: const MaterialApp(home: AssetConditionBoard()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Partial evidence — no fleet all-clear'), findsOneWidget);
  });
  test(
    'damaged selected registry blocks manual changes but unrelated registry damage does not',
    () {
      final result = qualifiedPlantAssetOverview(
        classes: [cls],
        assets: [asset],
        conditions: [],
        workflow: [f.workflow(key: 'furnace', number: 7)],
        availability: [],
        tickets: [],
        populationWarnings: ['Register contradiction'],
        manualSourcesCurrent: true,
        rejectedAssets: {asset.id},
      );
      expect(result.assets.single.permitsManualChange, isFalse);
      expect(result.available, 0);
    },
  );
}
