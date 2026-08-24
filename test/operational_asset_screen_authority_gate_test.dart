import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/presentation/burner_condition_round_screen.dart';
import 'package:crm3_baf_ops/features/assets/presentation/furnace_stuckup_board.dart';
import 'package:crm3_baf_ops/features/assets/presentation/inner_cover_lifecycle_screen.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/furnace_stuckup_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/equipment_status_board.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asset screens fail closed throughout authority refresh', () {
    const paths = <String>[
      'lib/features/assets/presentation/asset_condition_board.dart',
      'lib/features/assets/presentation/asset_registry_screen.dart',
      'lib/features/assets/presentation/burner_condition_round_screen.dart',
      'lib/features/assets/presentation/furnace_stuckup_board.dart',
      'lib/features/assets/presentation/inner_cover_lifecycle_screen.dart',
      'lib/features/maintenance_workflow/presentation/screens/equipment_status_board.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, contains('if (actorAsync.isLoading) {'), reason: path);
      expect(
        source,
        isNot(contains('actorAsync.isLoading && !actorAsync.hasValue')),
        reason: path,
      );
    }
  });

  testWidgets('Inner Covers rejects before hierarchy and lifecycle reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const InnerCoverLifecycleScreen(),
      overrides: [
        innerCoverProfilesProvider.overrideWith((ref) {
          reads++;
          throw StateError('profiles must not be read');
        }),
        innerCoverAssignmentsProvider.overrideWith((ref) {
          reads++;
          throw StateError('assignments must not be read');
        }),
        assetClassesProvider.overrideWith((ref) {
          reads++;
          throw StateError('classes must not be read');
        }),
        allAssetInstancesProvider.overrideWith((ref) {
          reads++;
          throw StateError('assets must not be read');
        }),
      ],
    );

    expect(find.text('Inner Cover access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('plant condition rejects before overview and ticket reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const AssetConditionBoard(),
      overrides: [
        plantAssetOverviewProvider.overrideWith((ref) {
          reads++;
          throw StateError('overview must not be read');
        }),
        openTicketsProvider.overrideWith((ref) {
          reads++;
          throw StateError('tickets must not be read');
        }),
      ],
    );

    expect(find.text('Plant-condition access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('Furnace stuck-up rejects before case and condition reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const FurnaceStuckupBoard(),
      overrides: [
        furnaceStuckupCasesProvider.overrideWith((ref) {
          reads++;
          throw StateError('cases must not be read');
        }),
        assetConditionDeclarationsProvider.overrideWith((ref) {
          reads++;
          throw StateError('conditions must not be read');
        }),
      ],
    );

    expect(find.text('Furnace stuck-up access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('equipment availability rejects before projection reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const EquipmentStatusBoard(),
      overrides: [
        equipmentStatusProvider.overrideWith((ref, stateKey) {
          reads++;
          throw StateError('equipment projections must not be read');
        }),
      ],
    );

    expect(find.text('Equipment-state access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('burner rounds reject before Furnace hierarchy reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const BurnerConditionRoundScreen(),
      overrides: [
        assetClassesProvider.overrideWith((ref) {
          reads++;
          throw StateError('classes must not be read');
        }),
        allAssetInstancesProvider.overrideWith((ref) {
          reads++;
          throw StateError('assets must not be read');
        }),
      ],
    );

    expect(
      find.text('Approved Operations or I&A access is required.'),
      findsOneWidget,
    );
    expect(reads, 0);
  });

  testWidgets('authority failure hides approved Inner Cover data', (
    tester,
  ) async {
    final actors = StreamController<AppUser?>();
    addTearDown(actors.close);
    actors.add(_approvedActor());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => actors.stream),
          innerCoverProfilesProvider.overrideWith(
            (ref) => Stream<List<InnerCoverProfile>>.value(const []),
          ),
          innerCoverAssignmentsProvider.overrideWith(
            (ref) => Stream<List<BaseInnerCoverAssignment>>.value(const []),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream<List<AssetClassRecord>>.value(const []),
          ),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream<List<AssetInstanceRecord>>.value(const []),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const InnerCoverLifecycleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 installed'), findsOneWidget);

    actors.addError(StateError('authority stream failed'));
    await tester.pumpAndSettle();

    expect(
      find.text('Inner Cover access could not be verified.'),
      findsOneWidget,
    );
    expect(find.text('0 installed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authority failure hides an approved burner-round view', (
    tester,
  ) async {
    final actors = StreamController<AppUser?>();
    addTearDown(actors.close);
    actors.add(_approvedActor());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => actors.stream),
          assetClassesProvider.overrideWith(
            (ref) => Stream<List<AssetClassRecord>>.value(const []),
          ),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream<List<AssetInstanceRecord>>.value(const []),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const BurnerConditionRoundScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Furnace asset authority needs reconciliation.'),
      findsOneWidget,
    );

    actors.addError(StateError('authority stream failed'));
    await tester.pumpAndSettle();

    expect(find.text('Could not verify burner-round access.'), findsOneWidget);
    expect(
      find.text('Furnace asset authority needs reconciliation.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUnapproved(
  WidgetTester tester, {
  required Widget screen,
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream<AppUser?>.value(_unapprovedActor()),
        ),
        ...overrides,
      ],
      child: MaterialApp(theme: BafAppTheme.light, home: screen),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

AppUser _unapprovedActor() => AppUser(
  uid: 'revoked-operations',
  name: 'Revoked Operations',
  email: 'revoked.operations@example.com',
  roles: const <AppRole>[AppRole.operations],
  isApproved: false,
  createdAt: DateTime.utc(2026, 8, 24),
);

AppUser _approvedActor() => AppUser(
  uid: 'approved-operations',
  name: 'Approved Operations',
  email: 'approved.operations@example.com',
  roles: const <AppRole>[AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 24),
);
