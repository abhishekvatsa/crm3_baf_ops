import 'dart:async';

import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/charge_abnormalities_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('final Log includes selected equipment without Add', (
    tester,
  ) async {
    final h = await _open(tester);
    await _select(tester, 'Furnace', 7);
    await _log(tester);
    expect(h.repository.saved, hasLength(1));
    final record = h.repository.saved.single;
    expect(record.affectedAssets.single.assetNumber, 7);
    expect(record.affectedAssets.single.assetType, AssetType.furnace);
    expect(
      record.affectedAssets.single.assetHierarchyReference!.assetInstanceId,
      'furnace-7',
    );
    expect(record.possibleRootReasonCategory, RootReasonCategory.unknown);
    expect(record.assessment!.candidateCauses, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'final Log includes the selected governed component without Add',
    (tester) async {
      final h = await _open(tester);
      await _select(tester, 'Furnace', 7);
      final picker = find.text('Choose component or subcomponent');
      await _reveal(tester, picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Use Burner nozzle'));
      await tester.pumpAndSettle();
      await _log(tester);
      final asset = h.repository.saved.single.affectedAssets.single;
      expect(
        asset.assetHierarchyReference!.scope,
        AssetHierarchyReferenceScope.componentDefinitionOnAsset,
      );
      expect(asset.assetHierarchyReference!.nodeId, 'furnace-nozzle');
      expect(asset.assetHierarchyReference!.nodeVersion, 3);
      expect(asset.assetHierarchyReference!.assetInstanceId, 'furnace-7');
      expect(asset.componentLabel, contains('Burner nozzle'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'final Log retains staged equipment and includes a second selection',
    (tester) async {
      final h = await _open(tester);
      await _select(tester, 'Furnace', 7);
      await _add(tester);
      await _select(tester, 'Furnace', 8, selectClass: false);
      await _log(tester);
      expect(
        h.repository.saved.single.affectedAssets.map((a) => a.assetNumber),
        [7, 8],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('class left after Add does not block a staged-only submission', (
    tester,
  ) async {
    final h = await _open(tester);
    await _select(tester, 'Furnace', 7);
    await _add(tester);
    expect(
      tester.state<FormFieldState<String>>(_field('Registered asset')).value,
      isNull,
    );
    await _log(tester);
    expect(h.repository.saved.single.affectedAssets.map((a) => a.assetNumber), [
      7,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'withdrawn pending equipment blocks final Log despite a valid staged asset',
    (tester) async {
      final h = await _open(tester);
      await _select(tester, 'Furnace', 7);
      await _add(tester);
      await _select(tester, 'Furnace', 8, selectClass: false);
      h.assets.add([_asset(7)]);
      await tester.pumpAndSettle();
      await _log(tester);
      expect(h.repository.saved, isEmpty);
      expect(find.text('Log charge abnormality'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duplicate pending equipment is explicit and never silently dropped',
    (tester) async {
      final h = await _open(tester);
      await _select(tester, 'Furnace', 7);
      await _add(tester);
      await _select(tester, 'Furnace', 7, selectClass: false);
      await _log(tester);
      expect(h.repository.saved, isEmpty);
      expect(find.textContaining('already included'), findsOneWidget);
      expect(find.text('Log charge abnormality'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a pending fifty-first asset cannot bypass the edit limit', (
    tester,
  ) async {
    final existing = ChargeAbnormality.createRaCoilColour(
      firestoreId: 'existing-fifty',
      sourceChargeNo: 91234,
      affectedAssets: [
        for (var i = 1; i <= 50; i++)
          AffectedAssetRef(assetType: AssetType.furnace, assetNumber: i),
      ],
      observedReason: 'Existing recorded observation',
      loggedByUid: 'operator',
      loggedByName: 'Operator',
    );
    final h = await _open(tester, existing: existing);
    await _select(tester, 'Furnace', 57);
    final correction = find.byWidgetPredicate(
      (w) =>
          w is TextField && w.decoration?.labelText == 'Reason for correction',
    );
    await _reveal(tester, correction);
    await tester.enterText(correction, 'Include newly identified equipment');
    await _log(tester, edit: true);
    expect(h.repository.saved, isEmpty);
    expect(h.commandReads, 0);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _reveal(tester, find.textContaining('at most 50'));
    expect(find.textContaining('at most 50'), findsOneWidget);
    expect(existing.affectedAssets, hasLength(50));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'slow Base freeze accepts one final Log and captures actual context',
    (tester) async {
      final pending = Completer<GovernedAssetEventContext?>();
      final h = await _open(tester, pendingContext: pending);
      await _select(tester, 'Base', 220);
      await tester.tap(_logButton());
      await tester.tap(_logButton());
      await tester.pump();
      expect(h.hierarchy.contextCalls, 1);
      expect(h.repository.saved, isEmpty);
      pending.complete(_context());
      await tester.pumpAndSettle();
      expect(h.repository.saved, hasLength(1));
      final association = h
          .repository
          .saved
          .single
          .affectedAssets
          .single
          .assetHierarchyReference!
          .innerCoverAssociation!;
      expect(association.baseAssetInstanceId, 'base-220');
      expect(association.positionState, InnerCoverPositionState.noneLinked);
      expect(association.confirmedByUid, 'operator');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actor change during Base confirmation cannot submit for the old actor',
    (tester) async {
      final pending = Completer<GovernedAssetEventContext?>();
      final h = await _open(tester, pendingContext: pending);
      await _select(tester, 'Base', 220);
      await tester.tap(_logButton());
      await tester.pump();
      expect(h.hierarchy.contextCalls, 1);
      h.actors.add(_actor(uid: 'another-operator'));
      await tester.pump();
      pending.complete(_context());
      await tester.pumpAndSettle();
      expect(h.repository.saved, isEmpty);
      expect(h.commandReads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'catalogue withdrawal during Base confirmation cannot submit stale equipment',
    (tester) async {
      final pending = Completer<GovernedAssetEventContext?>();
      final h = await _open(tester, pendingContext: pending);
      await _select(tester, 'Base', 220);
      await tester.tap(_logButton());
      await tester.pump();
      expect(h.hierarchy.contextCalls, 1);
      h.assets.add([_asset(221, classId: 'base')]);
      await tester.pump();
      pending.complete(_context());
      await tester.pumpAndSettle();
      expect(h.repository.saved, isEmpty);
      expect(find.text('Log charge abnormality'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed Base confirmation preserves the form and does not save', (
    tester,
  ) async {
    final pending = Completer<GovernedAssetEventContext?>();
    final h = await _open(tester, pendingContext: pending);
    await _select(tester, 'Base', 220);
    await tester.tap(_logButton());
    await tester.pump();
    expect(h.hierarchy.contextCalls, 1);
    pending.completeError(
      const AssetHierarchyException('Synthetic context unavailable'),
    );
    await tester.pumpAndSettle();
    expect(h.repository.saved, isEmpty);
    expect(
      find.textContaining('Synthetic context unavailable'),
      findsOneWidget,
    );
    expect(find.text('Log charge abnormality'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancel while Base confirmation is pending cannot submit after completion',
    (tester) async {
      final pending = Completer<GovernedAssetEventContext?>();
      final h = await _open(tester, pendingContext: pending);
      await _select(tester, 'Base', 220);
      await tester.tap(_logButton());
      await tester.pump();
      expect(h.hierarchy.contextCalls, 1);
      final popsBeforeCancel = h.navigator.pops;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      // Complete before route reverse animation/disposal, when mounted is still true.
      pending.complete(_context());
      await tester.pumpAndSettle();
      expect(h.repository.saved, isEmpty);
      expect(find.text('Log charge abnormality'), findsNothing);
      expect(find.byType(ChargeAbnormalitiesScreen), findsOneWidget);
      expect(h.navigator.pops, popsBeforeCancel + 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'keyboard change during Base confirmation must pass final validation',
    (tester) async {
      final pending = Completer<GovernedAssetEventContext?>();
      final h = await _open(tester, pendingContext: pending);
      await _select(tester, 'Base', 220);
      final observation = find.byKey(const ValueKey('abnormality-observation'));
      await _reveal(tester, observation);
      await tester.showKeyboard(observation);
      await tester.tap(_logButton());
      await tester.pump();
      expect(h.hierarchy.contextCalls, 1);
      // The focused editor still accepts keyboard input through AbsorbPointer.
      tester.testTextInput.enterText('');
      await tester.pump();
      pending.complete(_context());
      await tester.pumpAndSettle();
      expect(h.repository.saved, isEmpty);
      expect(find.text('Log charge abnormality'), findsOneWidget);
      expect(find.text('Observation is required'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _field(String label) => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField<String> && w.decoration.labelText == label,
);
Finder _logButton({bool edit = false}) =>
    find.text(edit ? 'Save correction' : 'Log abnormality');
Future<void> _log(WidgetTester tester, {bool edit = false}) async {
  await tester.tap(_logButton(edit: edit));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      )
      .first;
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 80,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.4);
  await tester.pumpAndSettle();
}

Future<void> _select(
  WidgetTester tester,
  String name,
  int number, {
  bool selectClass = true,
}) async {
  if (selectClass) {
    await _reveal(tester, _field('Asset class'));
    await tester.tap(_field('Asset class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }
  await _reveal(tester, _field('Registered asset'));
  await tester.tap(_field('Registered asset'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$name $number').last);
  await tester.pumpAndSettle();
}

Future<void> _add(WidgetTester tester) async {
  final button = find.text('Add affected equipment');
  await _reveal(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _Harness {
  final actors = StreamController<AppUser?>.broadcast();
  final assets = StreamController<List<AssetInstanceRecord>>.broadcast();
  final repository = _Repository();
  final navigator = _Navigation();
  final _Hierarchy hierarchy;
  int commandReads = 0;
  _Harness(Completer<GovernedAssetEventContext?>? context)
    : hierarchy = _Hierarchy(context);
}

Future<_Harness> _open(
  WidgetTester tester, {
  ChargeAbnormality? existing,
  Completer<GovernedAssetEventContext?>? pendingContext,
}) async {
  final h = _Harness(pendingContext);
  await tester.binding.setSurfaceSize(const Size(900, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(h.actors.close);
  addTearDown(h.assets.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) async* {
          yield _actor(admin: existing != null);
          yield* h.actors.stream;
        }),
        abnormalitiesForChargeProvider.overrideWith(
          (ref, charge) => Stream.value([if (existing != null) existing]),
        ),
        activeAbnormalityTypesProvider.overrideWith(
          (ref) => Stream.value([AbnormalityType.seedRaCoilColour()]),
        ),
        abnormalityRepositoryProvider.overrideWithValue(h.repository),
        chargeAbnormalityCommandServiceProvider.overrideWith((ref) {
          h.commandReads++;
          throw StateError('Unexpected correction command');
        }),
        syncCoordinatorProvider.overrideWithValue(_Sync()),
        assetHierarchyRepositoryProvider.overrideWithValue(h.hierarchy),
        assetClassesProvider.overrideWith(
          (ref) => Stream.value([_assetClass('furnace'), _assetClass('base')]),
        ),
        assetInstancesProvider.overrideWith((ref, id) async* {
          yield id == 'base'
              ? [_asset(220, classId: 'base'), _asset(221, classId: 'base')]
              : [_asset(7), _asset(8), _asset(57)];
          yield* h.assets.stream.map(
            (assets) =>
                assets.where((asset) => asset.assetClassId == id).toList(),
          );
        }),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        navigatorObservers: [h.navigator],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const ChargeAbnormalitiesScreen(sourceChargeNo: 91234),
                  ),
                ),
                child: const Text('Open synthetic charge'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open synthetic charge'));
  await tester.pumpAndSettle();
  if (existing == null) {
    await tester.tap(find.text('Log Abnormality'));
    await tester.pumpAndSettle();
    final observation = find.byKey(const ValueKey('abnormality-observation'));
    await _reveal(tester, observation);
    await tester.enterText(
      observation,
      'Observed coil result for synthetic test',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
  } else {
    await tester.tap(
      find.byKey(const ValueKey('charge-abnormality-status-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Edit'));
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
  }
  return h;
}

AppUser _actor({String uid = 'operator', bool admin = false}) => AppUser(
  uid: uid,
  name: 'Operator',
  email: 'operator@example.test',
  roles: admin ? const [AppRole.admin] : const [AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

class _Repository extends Fake implements AbnormalityRepository {
  final saved = <ChargeAbnormality>[];
  @override
  Future<void> saveAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    saved.add(copyChargeAbnormality(abnormality));
  }

  @override
  Future<List<AbnormalityType>> getActiveTypes() async => [
    AbnormalityType.seedRaCoilColour(),
  ];
}

class _Sync extends Fake implements SyncCoordinator {
  @override
  Future<SyncRequestOutcome> runFullSyncWithResult({
    String reason = 'unspecified',
    bool force = false,
  }) async => SyncRequestOutcome.queued;
}

class _Hierarchy extends Fake implements AssetHierarchyRepository {
  final Completer<GovernedAssetEventContext?>? pending;
  int contextCalls = 0;
  _Hierarchy(this.pending);
  @override
  Stream<List<AssetHierarchyNode>> watchNodes(String id) =>
      Stream.value([_node()]);
  @override
  Future<GovernedAssetEventContext?> resolveGovernedAssetEventContext({
    required String legacyAssetTypeKey,
    required int assetNumber,
  }) {
    contextCalls++;
    return pending?.future ?? Future.value(_context());
  }
}

AssetClassRecord _assetClass(String id) => AssetClassRecord(
  id: id,
  code: id.toUpperCase(),
  name: id == 'base' ? 'Base' : 'Furnace',
  majorArea: 'BAF',
  legacyAssetTypeKey: id,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026),
  createdByUid: 'admin',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'admin',
  lastMutationId: 'fixture',
);
AssetInstanceRecord _asset(int number, {String classId = 'furnace'}) =>
    AssetInstanceRecord(
      id: '$classId-$number',
      assetClassId: classId,
      assetClassCode: classId.toUpperCase(),
      assetClassName: classId == 'base' ? 'Base' : 'Furnace',
      assetNumber: number,
      name: '${classId == 'base' ? 'Base' : 'Furnace'} $number',
      serviceState: AssetServiceState.inService,
      ownershipStatus: AssetOwnershipStatus.confirmed,
      ownerDiscipline: 'Mechanical',
      accountableRoleKeys: const ['contractSupervisor'],
      status: AssetHierarchyStatus.active,
      activeComponentCount: 0,
      version: 1,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      lastMutationId: 'fixture',
    );
GovernedAssetEventContext _context() => GovernedAssetEventContext(
  assetClass: _assetClass('base'),
  asset: _asset(220, classId: 'base'),
);
AssetHierarchyNode _node() => AssetHierarchyNode(
  id: 'furnace-nozzle',
  assetClassId: 'furnace',
  nodeType: AssetHierarchyNodeType.component,
  name: 'Burner nozzle',
  discipline: 'Mechanical',
  operatingType: 'Burner',
  contactArrangement: ElectricalContactArrangement.notStated,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Mechanical',
  accountableRoleKeys: const ['contractSupervisor'],
  sortOrder: 1,
  ancestorNodeIds: const [],
  hierarchyPath: const ['Burner nozzle'],
  activeChildCount: 0,
  status: AssetHierarchyStatus.active,
  version: 3,
  createdAt: DateTime.utc(2026),
  createdByUid: 'admin',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'admin',
  lastMutationId: 'component-fixture',
);

class _Navigation extends NavigatorObserver {
  int pops = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
    super.didPop(route, previousRoute);
  }
}
