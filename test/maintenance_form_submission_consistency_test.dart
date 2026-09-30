import 'dart:async';

import 'package:crm3_baf_ops/core/services/auto_sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/repositories/asset_hierarchy_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_form.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/frequent_issue_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets(
    'held event verification blocks pointer and focused keyboard editing and preserves submitted values',
    (tester) async {
      final h = await _prepare(tester);
      await tester.showKeyboard(_charge);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      await _submit(tester, h);
      final busy = find.byKey(
        const ValueKey('maintenance-submission-input-lock'),
      );
      expect(tester.widget<AbsorbPointer>(busy).absorbing, isTrue);
      final focusLock = find.byKey(
        const ValueKey('maintenance-submission-focus-lock'),
      );
      expect(tester.widget<ExcludeFocus>(focusLock).excluding, isTrue);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      final assessment = find.byType(SegmentedButton<IssueQualityAssessment>);
      // A real pointer event lands on the busy form and cannot change its choice.
      await tester.tapAt(tester.getCenter(find.text('Suspected').first));
      await tester.pump();
      expect(
        tester
            .widget<SegmentedButton<IssueQualityAssessment>>(assessment)
            .selected,
        {IssueQualityAssessment.notSuspected},
      );
      h.hierarchy.context.complete(_context());
      await tester.pumpAndSettle();
      expect(h.saved.single.chargeNoAtEvent, 91234);
      expect(h.saved.single.description, 'Synthetic seal observation');
      expect(
        h.saved.single.qualityIntent?.assessment,
        IssueQualityAssessment.notSuspected,
      );
      expect(tester.widget<AbsorbPointer>(busy).absorbing, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in ['charge', 'description', 'plant condition']) {
    testWidgets(
      'a retained $change callback while event lookup waits aborts before saving mixed fields',
      (tester) async {
        final h = await _prepare(tester);
        final charge = tester.widget<TextFormField>(_charge).controller!;
        final description = tester
            .widget<TextFormField>(_description)
            .controller!;
        final route = tester
            .widget<SegmentedButton<MaintenanceIssuePlantConditionEffect>>(
              find.byType(
                SegmentedButton<MaintenanceIssuePlantConditionEffect>,
              ),
            );
        await _submit(tester, h);
        if (change == 'charge') {
          charge.text = '94567';
        }
        if (change == 'description') {
          description.text = 'Later observation retained';
        }
        if (change == 'plant condition') {
          route.onSelectionChanged!({
            MaintenanceIssuePlantConditionEffect.unavailable,
          });
        }
        await tester.pump();
        h.hierarchy.context.complete(_context());
        await tester.pumpAndSettle();
        expect(h.saved, isEmpty);
        expect(
          find.text(
            'Your issue details changed while they were being verified. Review them and submit again.',
          ),
          findsOneWidget,
        );
        expect(find.text('Submit Issue'), findsOneWidget);
        if (change == 'charge') {
          expect(charge.text, '94567');
        }
        if (change == 'description') {
          expect(description.text, 'Later observation retained');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('changed governed asset version during lookup is not inherited', (
    tester,
  ) async {
    final h = await _prepare(tester);
    await _submit(tester, h);
    h.assets.add([_asset(version: 2)]);
    await tester.pump();
    h.hierarchy.context.complete(_context());
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

  testWidgets(
    'failed snapshot preserves edit and permits a newly validated retry',
    (tester) async {
      final h = await _prepare(tester);
      final charge = tester.widget<TextFormField>(_charge).controller!;
      await _submit(tester, h);
      charge.text = '94567';
      h.hierarchy.context.complete(_context());
      await tester.pumpAndSettle();
      expect(h.saved, isEmpty);
      await tester.tap(find.text('Submit Issue'));
      await tester.pumpAndSettle();
      expect(h.hierarchy.contextReads, 2);
      expect(h.saved.single.chargeNoAtEvent, 94567);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'controlled tag normalization remains valid across the later event check',
    (tester) async {
      final h = await _prepare(tester, governedTag: true);
      await _submit(tester, h);
      expect(h.hierarchy.tagReads, 1);
      h.hierarchy.context.complete(_context());
      await tester.pumpAndSettle();
      expect(h.saved.single.tag, 'TAG-220');
      expect(h.saved.single.component, 'Hydraulic clamp');
      expect(h.saved.single.assetHierarchyReference?.nodeId, 'clamp');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changed draft during held tag resolution aborts before applying the tag or event lookup',
    (tester) async {
      final h = await _prepare(tester, governedTag: true, holdTag: true);
      final charge = tester.widget<TextFormField>(_charge).controller!;
      await tester.tap(find.text('Submit Issue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(h.hierarchy.tagReads, 1);
      expect(h.hierarchy.contextReads, 0);
      charge.text = '94567';
      h.hierarchy.tag!.complete(null);
      await tester.pumpAndSettle();
      expect(h.saved, isEmpty);
      expect(h.hierarchy.contextReads, 0);
      expect(charge.text, '94567');
      expect(
        find.text(
          'Your issue details changed while they were being verified. Review them and submit again.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Finder get _description =>
    find.byKey(const ValueKey('maintenance-issue-observations'));
Finder get _charge => find.ancestor(
  of: find.text('Charge number'),
  matching: find.byType(TextFormField),
);

Future<void> _submit(WidgetTester tester, _Harness h) async {
  await tester.tap(find.text('Submit Issue'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(
    h.hierarchy.contextReads,
    1,
    reason:
        'The real form must pass validation and reach the held event-context lookup.',
  );
  expect(h.saved, isEmpty);
}

Future<_Harness> _prepare(
  WidgetTester tester, {
  bool governedTag = false,
  bool holdTag = false,
}) async {
  final h = _Harness(holdTag: holdTag);
  addTearDown(h.assets.close);
  await tester.binding.setSurfaceSize(const Size(1100, 2700));
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
        assetClassesProvider.overrideWith((ref) => Stream.value([_class()])),
        assetInstancesProvider.overrideWith((ref, id) async* {
          yield [_asset()];
          yield* h.assets.stream;
        }),
        innerCoverAssignmentsProvider.overrideWith((ref) => Stream.value([])),
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
  await tester.tap(find.text('Not suspected'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('issue-asset-class')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Base').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('issue-physical-asset-base')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_asset().displayLabel).last);
  await tester.pumpAndSettle();
  if (governedTag) {
    await tester.tap(
      find.byKey(const ValueKey('maintenance-component-intake-state')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registered component').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose component from hierarchy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hydraulic clamp'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(_description, 'Synthetic seal observation');
  await tester.enterText(_charge, '91234');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return h;
}

class _Harness {
  _Harness({bool holdTag = false}) : hierarchy = _Hierarchy(holdTag: holdTag);
  final assets = StreamController<List<AssetInstanceRecord>>.broadcast();
  final _Hierarchy hierarchy;
  final saved = <MaintenanceRecord>[];
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
    // Capture only: intentionally do not enter sync/transport/acceptance.
    throw StateError('Synthetic command captured; transport disabled');
  }
}

class _Hierarchy extends Fake implements AssetHierarchyRepository {
  _Hierarchy({bool holdTag = false})
    : tag = holdTag ? Completer<InstalledComponentRecord?>() : null;
  final Completer<InstalledComponentRecord?>? tag;
  int tagReads = 0;
  @override
  Future<InstalledComponentRecord?> findActiveInstalledComponentByTag(
    String rawTag,
  ) {
    tagReads++;
    return tag?.future ?? Future.value(null);
  }

  @override
  Stream<List<AssetHierarchyNode>> watchNodes(String assetClassId) =>
      Stream.value([_node()]);
  final context = Completer<GovernedAssetEventContext?>();
  int contextReads = 0;
  @override
  Future<GovernedAssetEventContext?> resolveGovernedAssetEventContext({
    required String legacyAssetTypeKey,
    required int assetNumber,
  }) {
    expect(legacyAssetTypeKey, 'base');
    expect(assetNumber, 220);
    contextReads++;
    return context.future;
  }
}

AssetClassRecord _class() => AssetClassRecord(
  id: 'base',
  code: 'BASE',
  name: 'Base',
  majorArea: 'BAF',
  legacyAssetTypeKey: 'base',
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026),
  createdByUid: 'admin',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'admin',
  lastMutationId: 'class-fixture',
);
AssetInstanceRecord _asset({int version = 1}) => AssetInstanceRecord(
  id: 'base-220',
  assetClassId: 'base',
  assetClassCode: 'BASE',
  assetClassName: 'Base',
  assetNumber: 220,
  name: 'Base 220',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Mechanical',
  accountableRoleKeys: ['contractSupervisor'],
  status: AssetHierarchyStatus.active,
  activeComponentCount: 0,
  version: version,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  lastMutationId: 'asset-fixture-$version',
);
GovernedAssetEventContext _context() =>
    GovernedAssetEventContext(assetClass: _class(), asset: _asset());

AssetHierarchyNode _node() => AssetHierarchyNode(
  id: 'clamp',
  assetClassId: 'base',
  nodeType: AssetHierarchyNodeType.component,
  name: 'Hydraulic clamp',
  componentTag: 'TAG-220',
  contactArrangement: ElectricalContactArrangement.notStated,
  discipline: 'Mechanical',
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Mechanical',
  accountableRoleKeys: ['contractSupervisor'],
  sortOrder: 1,
  ancestorNodeIds: [],
  hierarchyPath: ['Hydraulic clamp'],
  activeChildCount: 0,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026),
  createdByUid: 'admin',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'admin',
  lastMutationId: 'node-fixture',
);
