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
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/equipment_status_board.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plant_asset_overview_test.dart' as fixtures;

final _class = fixtures.assetClass(
  id: 'furnace-class',
  code: 'FURNACE',
  name: 'Furnace',
  legacyKey: 'furnace',
);

AppUser _actor({
  String uid = 'admin-one',
  AppRole role = AppRole.admin,
  bool approved = true,
}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@test.invalid',
  roles: [role],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

AssetInstanceRecord _asset({
  String id = 'replacement-physical-id',
  int version = 9,
  int number = 7,
  String classId = 'furnace-class',
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
}) => AssetInstanceRecord(
  id: id,
  assetClassId: classId,
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetNumber: number,
  name: id == 'retired-physical-id'
      ? 'Original furnace'
      : 'Replacement furnace',
  serviceState: AssetServiceState.standby,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  status: status,
  activeComponentCount: 0,
  version: version,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 9, 21),
  lastMutationId: 'registry-change',
);

AssetInstanceRecord _previous({int version = 5}) => _asset(
  id: 'retired-physical-id',
  version: version,
  status: AssetHierarchyStatus.retired,
);

EquipmentStatusRecord _row({int version = 12}) => EquipmentStatusRecord()
  ..firestoreId = 'furnace_7'
  ..assetTypeKey = 'furnace'
  ..assetNumber = 7
  ..assetClassId = 'furnace-class'
  ..assetInstanceId = 'retired-physical-id'
  ..version = version
  ..stateKey = 'inService'
  ..inServiceSince = DateTime.utc(2020);

PlantEvidenceBatch<T> _batch<T>(
  List<T> rows, {
  bool current = true,
  Map<String, String> rejected = const {},
}) => PlantEvidenceBatch(
  rows: rows,
  rejected: rejected,
  fromServer: current,
  observedAt: DateTime.utc(2026, 9, 21),
);

class _Board {
  final actors = StreamController<AppUser?>();
  final rows = StreamController<List<EquipmentStatusRecord>>();
  final classes =
      StreamController<PlantEvidenceBatch<AssetClassRecord>>.broadcast();
  final assets =
      StreamController<PlantEvidenceBatch<AssetInstanceRecord>>.broadcast();
  final commands = <WorkflowCommand>[];

  Future<void> pump(
    WidgetTester tester, {
    AppUser? actor,
    List<AssetInstanceRecord>? registry,
    List<AssetClassRecord>? classRows,
    bool current = true,
    Map<String, String> rejected = const {},
  }) async {
    actors.add(actor ?? _actor());
    rows.add([_row()]);
    addTearDown(() async {
      await actors.close();
      await rows.close();
      await classes.close();
      await assets.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((_) => actors.stream),
          equipmentStatusProvider.overrideWith((_, _) => rows.stream),
          plantClassEvidenceProvider.overrideWith((_) async* {
            yield _batch(classRows ?? [_class]);
            yield* classes.stream;
          }),
          plantAssetEvidenceProvider.overrideWith((_) async* {
            yield _batch(
              registry ?? [_previous(), _asset()],
              current: current,
              rejected: rejected,
            );
            yield* assets.stream;
          }),
          workflowCommandControllerProvider.overrideWith(
            (_) => WorkflowCommandController.forTesting(
              executeCommand: (command) async {
                commands.add(command);
                return WorkflowCommandReceipt(
                  commandId: command.commandId,
                  resultKey: 'equipment-reconciled',
                  aggregateVersion: command.expectedVersion + 1,
                  result: {
                    'rebound': true,
                    'assetClassId': 'furnace-class',
                    'assetInstanceId': 'replacement-physical-id',
                  },
                  appliedAt: DateTime.utc(2026, 9, 21),
                );
              },
              pullProjections: () async {},
            ),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const EquipmentStatusBoard(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> review(WidgetTester tester) async {
    await tester.tap(find.text('Review replacement'));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField),
      'Physical replacement reviewed',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm replacement'));
    await tester.tap(find.text('Confirm replacement'));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final role in [AppRole.admin, AppRole.si]) {
    testWidgets(
      '${role.name} reviews both physical identities and sends exact replacement basis',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final board = _Board();
        await board.pump(tester, actor: _actor(role: role));
        await board.review(tester);
        expect(
          find.textContaining('Record: retired-physical-id'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Record: replacement-physical-id'),
          findsOneWidget,
        );
        expect(
          find.textContaining('previous availability record will be archived'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'manual condition assessments, service placement and elapsed age',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('age remains unknown where evidence is missing'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm replacement'),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(find.byType(TextField), '   ');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm replacement'),
              )
              .onPressed,
          isNull,
        );
        expect(board.commands, isEmpty);
        await board.confirm(tester);
        expect(board.commands, hasLength(1));
        final command = board.commands.single;
        expect(command.type, WorkflowCommandType.reconcileEquipment);
        expect(command.aggregateId, 'equipment_furnace_7');
        expect(command.expectedVersion, 12);
        expect(command.payload, {
          'assetTypeKey': 'furnace',
          'assetNumber': 7,
          'assetClassId': 'furnace-class',
          'assetInstanceId': 'replacement-physical-id',
          'registryRebinding': {
            'previousAssetClassId': 'furnace-class',
            'previousAssetInstanceId': 'retired-physical-id',
            'expectedPreviousAssetVersion': 5,
            'expectedTargetAssetVersion': 9,
            'reason': 'Physical replacement reviewed',
          },
        });
        expect(command.payload.containsKey('inServiceSince'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cancelling a replacement review sends nothing', (tester) async {
    final board = _Board();
    await board.pump(tester);
    await board.review(tester);
    await tester.enterText(find.byType(TextField), 'Not yet approved');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(board.commands, isEmpty);
  });

  for (final change in [
    'actor',
    'revoked actor',
    'status version',
    'previous version',
    'target version',
    'registry offline',
  ]) {
    testWidgets('$change during review cannot submit the stale replacement', (
      tester,
    ) async {
      final board = _Board();
      await board.pump(tester);
      await board.review(tester);
      switch (change) {
        case 'actor':
          board.actors.add(_actor(uid: 'another-admin'));
        case 'revoked actor':
          board.actors.add(_actor(approved: false));
        case 'status version':
          board.rows.add([_row(version: 13)]);
        case 'previous version':
          board.assets.add(_batch([_previous(version: 6), _asset()]));
        case 'target version':
          board.assets.add(_batch([_previous(), _asset(version: 10)]));
        case 'registry offline':
          board.assets.add(_batch([_previous(), _asset()], current: false));
      }
      await tester.pumpAndSettle();
      await board.confirm(tester);
      expect(board.commands, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final population in [
    'active previous',
    'missing previous',
    'ambiguous target',
    'wrong number',
    'wrong class',
    'ambiguous class',
    'offline',
    'rejected row',
    'unauthorized',
  ]) {
    testWidgets('$population does not offer registry replacement', (
      tester,
    ) async {
      final board = _Board();
      final registry = switch (population) {
        'active previous' => [_asset(id: 'retired-physical-id'), _asset()],
        'missing previous' => [_asset()],
        'ambiguous target' => [
          _previous(),
          _asset(),
          _asset(id: 'another-target'),
        ],
        'wrong number' => [_previous(), _asset(number: 8)],
        'wrong class' => [_previous(), _asset(classId: 'unrelated-class')],
        _ => [_previous(), _asset()],
      };
      await board.pump(
        tester,
        registry: registry,
        actor: _actor(
          role: population == 'unauthorized'
              ? AppRole.operations
              : AppRole.admin,
        ),
        classRows: population == 'ambiguous class'
            ? [
                _class,
                fixtures.assetClass(
                  id: 'other-furnace-class',
                  code: 'OTHER',
                  name: 'Other',
                  legacyKey: 'furnace',
                ),
              ]
            : null,
        current: population != 'offline',
        rejected: population == 'rejected row'
            ? {'unknown-record': 'Malformed registry row'}
            : {},
      );
      expect(find.text('Review replacement'), findsNothing);
      expect(board.commands, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'ordinary reconcile still addresses the original physical equipment',
    (tester) async {
      final board = _Board();
      await board.pump(tester);
      await tester.tap(find.byTooltip('Reconcile derived equipment state'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reconcile'));
      await tester.pumpAndSettle();
      expect(board.commands.single.payload, {
        'assetTypeKey': 'furnace',
        'assetNumber': 7,
        'assetClassId': 'furnace-class',
        'assetInstanceId': 'retired-physical-id',
      });
    },
  );
}
