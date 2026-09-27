import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/plant_condition_evidence.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/missing_equipment_projection.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/equipment_status_board.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/missing_equipment_projection_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plant_asset_overview_test.dart' as f;

final _class = f.assetClass(
  id: 'furnaces',
  code: 'FURNACE',
  name: 'Furnace',
  legacyKey: 'furnace',
);
final _asset = f.asset(id: 'physical-furnace-1', assetClass: _class, number: 1);

PlantEvidenceBatch<T> _batch<T>(
  List<T> rows, {
  bool current = true,
  Map<String, String> rejected = const {},
}) => PlantEvidenceBatch(
  rows: rows,
  rejected: rejected,
  fromServer: current,
  observedAt: DateTime.utc(2026, 9, 27),
);

AppUser _actor({
  String uid = 'admin-one',
  AppRole role = AppRole.admin,
  bool approved = true,
}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [role],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

EquipmentStatusRecord _projection({String? instanceId}) =>
    EquipmentStatusRecord()
      ..firestoreId = 'furnace_1'
      ..assetTypeKey = 'furnace'
      ..assetNumber = 1
      ..assetClassId = 'furnaces'
      ..assetInstanceId = instanceId ?? _asset.id;

class _Harness {
  final actors = StreamController<AppUser?>.broadcast();
  final classes =
      StreamController<PlantEvidenceBatch<AssetClassRecord>>.broadcast();
  final assets =
      StreamController<PlantEvidenceBatch<AssetInstanceRecord>>.broadcast();
  final workflow =
      StreamController<PlantEvidenceBatch<EquipmentStatusRecord>>.broadcast();
  final commands = <WorkflowCommand>[];
  int failuresRemaining = 0;

  Future<void> pump(
    WidgetTester tester, {
    AppUser? actor,
    bool board = false,
    bool current = true,
    Map<String, String> rejected = const {},
    List<AssetInstanceRecord>? registry,
    List<EquipmentStatusRecord> projections = const [],
  }) async {
    addTearDown(() async {
      await actors.close();
      await classes.close();
      await assets.close();
      await workflow.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((_) async* {
            yield actor ?? _actor();
            yield* actors.stream;
          }),
          equipmentStatusProvider.overrideWith(
            (_, _) => Stream.value(projections),
          ),
          plantClassEvidenceProvider.overrideWith((_) async* {
            yield _batch([_class]);
            yield* classes.stream;
          }),
          plantAssetEvidenceProvider.overrideWith((_) async* {
            yield _batch(registry ?? [_asset]);
            yield* assets.stream;
          }),
          plantWorkflowEvidenceProvider.overrideWith((_) async* {
            yield _batch(projections, current: current, rejected: rejected);
            yield* workflow.stream;
          }),
          workflowCommandControllerProvider.overrideWith(
            (_) => WorkflowCommandController.forTesting(
              executeCommand: (command) async {
                commands.add(command);
                if (failuresRemaining > 0) {
                  failuresRemaining--;
                  throw StateError(
                    'Receipt unavailable; original request retained.',
                  );
                }
                return WorkflowCommandReceipt(
                  commandId: command.commandId,
                  resultKey: 'equipment-reconciled',
                  aggregateVersion: 1,
                  result: {
                    'state': 'available',
                    'assetTypeKey': 'furnace',
                    'assetNumber': 1,
                  },
                  appliedAt: DateTime.utc(2026, 9, 27),
                );
              },
              pullProjections: () async {},
            ),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: board
              ? const EquipmentStatusBoard()
              : const MissingEquipmentProjectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> review(WidgetTester tester) async {
    await tester.tap(find.byKey(ValueKey('reconcile-missing-${_asset.id}')));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Reconcile'));
    await tester.pumpAndSettle();
  }
}

void main() {
  test(
    'complete empty status collection discovers all 98 physical identities without zero defaults',
    () {
      final classes = [
        f.assetClass(
          id: 'fc',
          code: 'FC',
          name: 'Forced Cooler',
          legacyKey: 'forceCooler',
        ),
        f.assetClass(id: 'base', code: 'BASE', name: 'Base', legacyKey: 'base'),
        _class,
      ];
      final numbers = [25, 47, 26];
      final assets = <AssetInstanceRecord>[
        for (var i = 0; i < classes.length; i++)
          for (var number = 1; number <= numbers[i]; number++)
            f.asset(
              id: '${classes[i].id}-$number',
              assetClass: classes[i],
              number: number,
            ),
      ];
      final candidates = missingEquipmentProjections(
        classes: _batch(classes),
        assets: _batch(assets),
        workflow: _batch([]),
      )!;
      expect(candidates, hasLength(98));
      expect(candidates.map((r) => r.documentId).toSet(), hasLength(98));
      for (final candidate in candidates) {
        final command = candidate.command();
        expect(command.type, WorkflowCommandType.reconcileEquipment);
        expect(command.expectedVersion, 0);
        expect(command.aggregateId, 'equipment_${candidate.documentId}');
        expect(
          command.payload.keys,
          unorderedEquals([
            'assetTypeKey',
            'assetNumber',
            'assetClassId',
            'assetInstanceId',
          ]),
        );
        expect(command.payload['assetInstanceId'], candidate.asset.id);
        expect(
          () => command.payload['state'] = 'available',
          throwsUnsupportedError,
        );
      }
    },
  );

  for (final source in ['classes', 'assets', 'workflow']) {
    for (final mode in ['cached', 'rejected']) {
      test('$mode $source cannot prove absence', () {
        PlantEvidenceBatch<T> batch<T>(String name, List<T> rows) => _batch(
          rows,
          current: source != name || mode != 'cached',
          rejected: source == name && mode == 'rejected'
              ? {'bad': 'Unreadable record'}
              : {},
        );
        expect(
          missingEquipmentProjections(
            classes: batch('classes', [_class]),
            assets: batch('assets', [_asset]),
            workflow: batch('workflow', []),
          ),
          isNull,
        );
      });
    }
  }

  test(
    'duplicate physical numbers and duplicate legacy classes stay excluded',
    () {
      expect(
        missingEquipmentProjections(
          classes: _batch([_class]),
          assets: _batch([
            _asset,
            f.asset(id: 'another', assetClass: _class, number: 1),
          ]),
          workflow: _batch([]),
        ),
        isEmpty,
      );
      final duplicateClass = f.assetClass(
        id: 'another-class',
        code: 'OTHER',
        name: 'Other',
        legacyKey: 'furnace',
      );
      expect(
        missingEquipmentProjections(
          classes: _batch([_class, duplicateClass]),
          assets: _batch([_asset]),
          workflow: _batch([]),
        ),
        isEmpty,
      );
    },
  );

  test(
    'present mismatched projection is not offered as absent; serial covers are not slots',
    () {
      expect(
        missingEquipmentProjections(
          classes: _batch([_class]),
          assets: _batch([_asset]),
          workflow: _batch([_projection(instanceId: 'old-identity')]),
        ),
        isEmpty,
      );
      final coverClass = f.assetClass(
        id: 'cover-class',
        code: 'IC',
        name: 'Inner Covers',
        legacyKey: 'innerCover',
      );
      expect(
        missingEquipmentProjections(
          classes: _batch([coverClass]),
          assets: _batch([
            f.asset(id: 'position', assetClass: coverClass, number: 1),
          ]),
          workflow: _batch([]),
        ),
        isEmpty,
      );
    },
  );

  for (final role in [AppRole.admin, AppRole.si]) {
    testWidgets(
      '${role.name} can recover an empty board with exact governed identity',
      (tester) async {
        final h = _Harness();
        await h.pump(tester, actor: _actor(role: role), board: true);
        expect(find.text('No equipment projections'), findsOneWidget);
        expect(find.text('0 workflow records'), findsOneWidget);
        await tester.tap(find.text('Review missing equipment states'));
        await tester.pumpAndSettle();
        await h.review(tester);
        expect(
          find.textContaining('No available state or zero counts are assumed'),
          findsOneWidget,
        );
        await h.confirm(tester);
        expect(h.commands, hasLength(1));
        expect(h.commands.single.expectedVersion, 0);
        expect(h.commands.single.payload, {
          'assetTypeKey': 'furnace',
          'assetNumber': 1,
          'assetClassId': 'furnaces',
          'assetInstanceId': 'physical-furnace-1',
        });
        expect(find.text('Accepted; awaiting current state'), findsOneWidget);
        h.workflow.add(_batch([_projection()]));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('reconcile-missing-${_asset.id}')),
          findsNothing,
        );
        expect(
          find.textContaining('This is not a plant availability clearance.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final actor in [
    _actor(role: AppRole.operations),
    _actor(approved: false),
  ]) {
    testWidgets(
      '${actor.roles.first.name} approved=${actor.isApproved} cannot use recovery',
      (tester) async {
        final h = _Harness();
        await h.pump(tester, actor: actor);
        expect(find.text('Admin or SI access required'), findsOneWidget);
        expect(find.text('Review reconciliation'), findsNothing);
        expect(h.commands, isEmpty);
      },
    );
  }

  for (final change in [
    'actor',
    'revoke-restore',
    'cached',
    'projection',
    'registry',
  ]) {
    testWidgets('$change during confirmation prevents dispatch', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      await h.review(tester);
      switch (change) {
        case 'actor':
          h.actors.add(_actor(uid: 'another-admin'));
        case 'revoke-restore':
          h.actors.add(_actor(approved: false));
          await tester.pumpAndSettle();
          h.actors.add(_actor());
        case 'cached':
          h.workflow.add(_batch([], current: false));
        case 'projection':
          h.workflow.add(_batch([_projection()]));
        case 'registry':
          h.assets.add(_batch([]));
      }
      await tester.pumpAndSettle();
      await h.confirm(tester);
      expect(h.commands, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'partial server evidence is visible and never an empty eligible result',
    (tester) async {
      final h = _Harness();
      await h.pump(tester, rejected: {'furnace_1': 'Malformed projection'});
      expect(find.text('Current evidence is required'), findsOneWidget);
      expect(find.text('Review reconciliation'), findsNothing);
      expect(h.commands, isEmpty);
    },
  );

  testWidgets('uncertain retry reuses its original immutable command', (
    tester,
  ) async {
    final h = _Harness()..failuresRemaining = 1;
    await h.pump(tester);
    await h.review(tester);
    await h.confirm(tester);
    expect(h.commands, hasLength(1));
    final original = h.commands.single;
    await h.review(tester);
    await h.confirm(tester);
    expect(h.commands, hasLength(2));
    expect(h.commands.last.commandId, original.commandId);
    expect(h.commands.last.toMap(), original.toMap());
    expect(find.text('Accepted; awaiting current state'), findsOneWidget);
  });
}
