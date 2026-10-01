import 'dart:async';

import 'package:crm3_baf_ops/core/services/auto_sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_form.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/frequent_issue_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('stuck-up selection survives the lazy selector leaving view', (
    tester,
  ) async {
    final h = await _prepare(tester);
    expect(find.byKey(const ValueKey('stuckup-furnace-furnace')), findsNothing);
    await _tap(tester, find.text('Submit Issue'));
    expect(
      h.hierarchy.reads,
      1,
      reason:
          'The actual form must reach fresh Base/IC event validation after scrolling.',
    );
    expect(
      h.saved,
      hasLength(1),
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .join(' | '),
    );
    expect(
      h.saved.single.assetHierarchyReference?.assetInstanceId,
      'furnace-1',
    );
    expect(
      h.saved.single.furnaceStuckupCase?.baseAssetReference.assetInstanceId,
      'base-101',
    );
    expect(
      h
          .saved
          .single
          .furnaceStuckupCase
          ?.baseAssetReference
          .innerCoverAssociation
          ?.innerCoverId,
      '515a060f-400d-568e-bad3-b03f1a287c95',
    );
    expect(
      h.disposed,
      isEmpty,
      reason: 'The parent must keep both selected asset feeds alive.',
    );
    expect(tester.takeException(), isNull);
  });

  for (final kind in ['base', 'furnace']) {
    for (final change in ['removed', 'inactive', 'wrong class']) {
      testWidgets(
        'fresh $kind $change is not replaced by a retained selection',
        (tester) async {
          final h = await _prepare(tester);
          h.assets[kind]!.add(switch (change) {
            'removed' => [],
            'inactive' => [_asset(kind, status: AssetHierarchyStatus.retired)],
            _ => [_asset(kind, classId: 'different-class')],
          });
          await tester.pumpAndSettle();
          await _tap(tester, find.text('Submit Issue'));
          expect(h.saved, isEmpty);
          expect(h.hierarchy.reads, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('a changed physical linkage still needs new confirmation', (
    tester,
  ) async {
    final h = await _prepare(tester);
    h.assignments.add([_assignment(linkage: 'replacement-linkage')]);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Submit Issue'));
    expect(h.saved, isEmpty);
    expect(h.hierarchy.reads, 0);
    expect(
      find.text(
        'Confirm that the currently linked Inner Cover is physically installed on this Base.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a fresh ambiguous Base class does not inherit the old selection',
    (tester) async {
      final h = await _prepare(tester);
      h.classes.add([
        _class('base'),
        _class('furnace'),
        _class('base', id: 'another-base'),
      ]);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Submit Issue'));
      expect(h.saved, isEmpty);
      expect(h.hierarchy.reads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in ['ambiguous', 'different legacy kind']) {
    testWidgets('fresh Furnace class $change cannot use a retained asset', (
      tester,
    ) async {
      final h = await _prepare(tester);
      h.classes.add([
        _class('base'),
        if (change == 'ambiguous') ...[
          _class('furnace'),
          _class('furnace', id: 'another-furnace'),
        ] else
          _class('forceCooler', id: 'furnace'),
      ]);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Submit Issue'));
      expect(h.saved, isEmpty);
      expect(h.hierarchy.reads, 0);
      expect(
        find.text('Choose an active governed asset before submitting.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changed Furnace version during Base lookup aborts the draft', (
    tester,
  ) async {
    final h = await _prepare(tester, holdContext: true);
    await _tap(tester, find.text('Submit Issue'), settle: false);
    expect(h.hierarchy.reads, 1);
    h.assets['furnace']!.add([_asset('furnace', version: 2)]);
    await tester.pump();
    h.hierarchy.held!.complete(_context());
    await tester.pumpAndSettle();
    expect(h.saved, isEmpty);
    expect(
      find.text(
        'Your issue details changed while they were being verified. Review them and submit again.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _show(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final viewport = find.byType(Scrollable).first;
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(viewport).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 200, scrollable: viewport);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  bool settle = true,
}) async {
  await _show(tester, target);
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _choose(WidgetTester tester, String key, String text) async {
  await _tap(tester, find.byKey(ValueKey(key)));
  await _tap(tester, find.text(text).last);
}

Future<_Harness> _prepare(
  WidgetTester tester, {
  bool holdContext = false,
}) async {
  final h = _Harness(holdContext: holdContext);
  addTearDown(h.close);
  await tester.binding.setSurfaceSize(const Size(393, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              uid: 'form-actor',
              name: 'Synthetic operator',
              email: 'operator@example.invalid',
              roles: [AppRole.operations],
              isApproved: true,
              createdAt: DateTime.utc(2026),
            ),
          ),
        ),
        firebaseAuthProvider.overrideWithValue(_Auth()),
        activeAbnormalityTypesProvider.overrideWith((ref) => Stream.value([])),
        frequentIssueDefinitionsProvider.overrideWith(
          (ref) => Stream.value([]),
        ),
        assetClassesProvider.overrideWith((ref) async* {
          yield [_class('base'), _class('furnace')];
          yield* h.classes.stream;
        }),
        assetInstancesProvider.overrideWith((ref, id) {
          ref.onDispose(() => h.disposed.add(id));
          return h.assetStream(id);
        }),
        innerCoverAssignmentsProvider.overrideWith((ref) async* {
          yield [_assignment()];
          yield* h.assignments.stream;
        }),
        assetHierarchyRepositoryProvider.overrideWithValue(h.hierarchy),
        maintenanceRepositoryProvider.overrideWithValue(_Tickets(h.saved)),
        syncCoordinatorProvider.overrideWithValue(_Sync()),
        autoSyncServiceProvider.overrideWithValue(_AutoSync()),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: const MaintenanceForm(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Not suspected'));
  await _tap(tester, find.text('Furnace stuck-up'));
  await _choose(tester, 'stuckup-base-base', 'Base 101');
  await _tap(tester, find.text('Yes'));
  await _choose(tester, 'stuckup-furnace-furnace', 'Furnace 01');
  final notes = find.byKey(const ValueKey('maintenance-issue-observations'));
  await _show(tester, notes);
  await tester.enterText(notes, 'Synthetic current IC concern');
  final charge = find.ancestor(
    of: find.text('Charge number'),
    matching: find.byType(TextFormField),
  );
  await _show(tester, charge);
  await tester.enterText(charge, '77131');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  // Really remove the selector sliver, rather than manually disposing a provider.
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return h;
}

class _Harness {
  _Harness({required bool holdContext}) : hierarchy = _Hierarchy(holdContext);
  final _Hierarchy hierarchy;
  final classes = StreamController<List<AssetClassRecord>>.broadcast();
  final assignments =
      StreamController<List<BaseInnerCoverAssignment>>.broadcast();
  final assets = {
    'base': StreamController<List<AssetInstanceRecord>>.broadcast(),
    'furnace': StreamController<List<AssetInstanceRecord>>.broadcast(),
  };
  final subscriptions = <String, int>{};
  final disposed = <String>[];
  final saved = <MaintenanceRecord>[];
  Stream<List<AssetInstanceRecord>> assetStream(String id) async* {
    subscriptions.update(id, (value) => value + 1, ifAbsent: () => 1);
    // async* first emits after the subscribing frame, like the real stream.
    // A submit reading a disposed provider therefore cannot see it immediately.
    yield [_asset(id)];
    yield* assets[id]!.stream;
  }

  Future<void> close() async {
    await classes.close();
    await assignments.close();
    for (final controller in assets.values) {
      await controller.close();
    }
  }
}

class _User extends Fake implements User {
  @override
  String get uid => 'form-actor';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _Sync extends Fake implements SyncCoordinator {}

class _AutoSync extends Fake implements AutoSyncService {}

class _Tickets extends Fake implements MaintenanceRepository {
  _Tickets(this.saved);
  final List<MaintenanceRecord> saved;
  @override
  Future<void> saveTicket(MaintenanceRecord record) async {
    saved.add(record);
    throw StateError('Synthetic command captured; no transport');
  }
}

class _Hierarchy extends Fake implements AssetHierarchyRepository {
  _Hierarchy(bool hold)
    : held = hold ? Completer<GovernedAssetEventContext?>() : null;
  final Completer<GovernedAssetEventContext?>? held;
  int reads = 0;
  @override
  Future<GovernedAssetEventContext?> resolveGovernedAssetEventContext({
    required String legacyAssetTypeKey,
    required int assetNumber,
  }) {
    expect(legacyAssetTypeKey, 'base');
    expect(assetNumber, 101);
    reads++;
    return held?.future ?? Future.value(_context());
  }
}

AssetClassRecord _class(String kind, {String? id}) => AssetClassRecord(
  id: id ?? kind,
  code: kind.toUpperCase(),
  name: kind == 'base' ? 'Base' : 'Furnace',
  majorArea: 'BAF',
  legacyAssetTypeKey: kind,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026),
  createdByUid: 'admin',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'admin',
  lastMutationId: 'fixture-class',
);
AssetInstanceRecord _asset(
  String kind, {
  int version = 1,
  String? classId,
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
}) => AssetInstanceRecord(
  id: kind == 'base' ? 'base-101' : 'furnace-1',
  assetClassId: classId ?? kind,
  assetClassCode: kind.toUpperCase(),
  assetClassName: kind == 'base' ? 'Base' : 'Furnace',
  assetNumber: kind == 'base' ? 101 : 1,
  name: kind == 'base' ? 'Base 101' : 'Furnace 01',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Mechanical',
  accountableRoleKeys: ['contractSupervisor'],
  status: status,
  activeComponentCount: 0,
  version: version,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  lastMutationId: 'fixture-asset-$version',
);
BaseInnerCoverAssignment _assignment({String linkage = 'fixture-linkage'}) =>
    BaseInnerCoverAssignment(
      baseAssetInstanceId: 'base-101',
      baseAssetClassId: 'base',
      baseAssetNumber: 101,
      baseAssetName: 'Base 101',
      innerCoverId: '515a060f-400d-568e-bad3-b03f1a287c95',
      innerCoverSerialNumber: 'SYNTHETIC-IC-31',
      linkageId: linkage,
      linkedAt: DateTime.utc(2026),
      version: 1,
      updatedAt: DateTime.utc(2026),
      lastMutationId: 'fixture-link',
    );
GovernedAssetEventContext _context() => GovernedAssetEventContext(
  assetClass: _class('base'),
  asset: _asset('base'),
  innerCoverAssignment: _assignment(),
);
