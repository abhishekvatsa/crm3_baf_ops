import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/assets/presentation/burner_condition_round_screen.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/burner_condition_round_provider.dart';
import 'package:crm3_baf_ops/features/assets/services/burner_condition_round_service.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('authorized user records all eight positions at phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 16, 18, 30);
    final service = _FakeBurnerConditionRoundService(now);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_user(now: now)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.value([_furnaceClass(now)]),
          ),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.value([_furnace(now)]),
          ),
          burnerConditionRoundServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => const BurnerConditionRoundScreen(
                                    initialAssetInstanceId: 'furnace-2',
                                  ),
                            ),
                          ),
                      child: const Text('Open round'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open round'));
    await tester.pumpAndSettle();

    expect(find.text('Record burner round'), findsWidgets);
    expect(find.text('Burner observations'), findsOneWidget);
    expect(find.text('Red-hot burner block observed'), findsWidgets);
    await tester.tap(find.byTooltip('Apply flame observation to all burners'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flame seen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Apply UV condition to all burners'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In service').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Red-hot burner block observed').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Record round'));
    await tester.pumpAndSettle();

    expect(service.calls, hasLength(1));
    expect(service.calls.single, hasLength(8));
    expect(service.calls.single.first.position, 1);
    expect(service.calls.single.first.redHotObserved, isTrue);
    expect(service.calls.single.last.position, 8);
    expect(find.text('Open round'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unapproved direct entry does not expose round data', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 16);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_user(now: now, approved: false)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.error(StateError('must not be rendered')),
          ),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.error(StateError('must not be rendered')),
          ),
        ],
        child: const MaterialApp(home: BurnerConditionRoundScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Approved Operations or I&A access is required.'),
      findsOneWidget,
    );
    expect(find.text('Burner observations'), findsNothing);
  });
}

class _FakeBurnerConditionRoundService extends BurnerConditionRoundService {
  _FakeBurnerConditionRoundService(this.now);

  final DateTime now;
  final List<List<BurnerConditionObservation>> calls = [];

  @override
  Future<BurnerConditionRoundResult> record({
    required AssetInstanceRecord furnace,
    required List<BurnerConditionObservation> observations,
    required AppUser actor,
    String? roundNote,
    bool? draftSealRedHotObserved,
    bool? hotAirAtDraftSealObserved,
    List<BurnerUvObservation>? uvObservations,
  }) async {
    calls.add(List<BurnerConditionObservation>.from(observations));
    return BurnerConditionRoundResult(
      roundId: 'round-1',
      assetInstanceId: furnace.id,
      directiveId:
          observations.any((item) => item.redHotObserved)
              ? 'burner_round_red_hot_round-1'
              : null,
      committedAt: now,
      idempotentReplay: false,
    );
  }
}

AppUser _user({required DateTime now, bool approved = true}) => AppUser(
  uid: 'operations-1',
  name: 'Operations One',
  email: 'operations@example.com',
  roles: const [AppRole.operations],
  isApproved: approved,
  createdAt: now,
);

AssetClassRecord _furnaceClass(DateTime now) => AssetClassRecord(
  id: 'furnace-class',
  code: 'FURNACE',
  name: 'Furnace',
  majorArea: 'BAF shop',
  legacyAssetTypeKey: AssetType.furnace.name,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: now,
  createdByUid: 'admin-1',
  updatedAt: now,
  updatedByUid: 'admin-1',
  lastMutationId: 'class-mutation',
);

AssetInstanceRecord _furnace(DateTime now) => AssetInstanceRecord(
  id: 'furnace-2',
  assetClassId: 'furnace-class',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetNumber: 2,
  name: 'Furnace 2',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Operations',
  accountableRoleKeys: const ['operations'],
  status: AssetHierarchyStatus.active,
  activeComponentCount: 8,
  version: 1,
  createdAt: now,
  updatedAt: now,
  lastMutationId: 'asset-mutation',
);
