import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormalities_home_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/charge_abnormalities_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/presentation/directives_screen.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_inbox_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/quality/presentation/quality_home_screen.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('business screens fail closed throughout authority refresh', () {
    const paths = <String>[
      'lib/features/abnormalities/presentation/abnormalities_home_screen.dart',
      'lib/features/abnormalities/presentation/charge_abnormalities_screen.dart',
      'lib/features/directives/presentation/directives_screen.dart',
      'lib/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart',
      'lib/features/maintenance_workflow/presentation/screens/compliance_inbox_screen.dart',
      'lib/features/quality/presentation/quality_home_screen.dart',
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

  testWidgets('authority error hides quality data after an approved session', (
    tester,
  ) async {
    final actors = StreamController<AppUser?>();
    addTearDown(actors.close);
    actors.add(_approvedActor());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => actors.stream),
          qualityWarningsProvider.overrideWith(
            (ref) => Stream<List<QualityWarning>>.value(const []),
          ),
          qualityMonitoringRequestsProvider.overrideWith(
            (ref) => Stream<List<QualityMonitoringRequest>>.value(const []),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const QualityHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Warnings (0)'), findsOneWidget);

    actors.addError(StateError('authority stream failed'));
    await tester.pumpAndSettle();

    expect(find.text('Quality access could not be verified.'), findsOneWidget);
    expect(find.text('Warnings (0)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quality rejects before warning and monitoring reads', (
    tester,
  ) async {
    var warningReads = 0;
    var monitoringReads = 0;

    await _pumpUnapproved(
      tester,
      screen: const QualityHomeScreen(),
      overrides: [
        qualityWarningsProvider.overrideWith((ref) {
          warningReads++;
          return Stream<List<QualityWarning>>.value(const []);
        }),
        qualityMonitoringRequestsProvider.overrideWith((ref) {
          monitoringReads++;
          return Stream<List<QualityMonitoringRequest>>.value(const []);
        }),
      ],
    );

    expect(find.text('Quality access required'), findsOneWidget);
    expect(warningReads, 0);
    expect(monitoringReads, 0);
  });

  testWidgets('abnormalities home rejects before type reads', (tester) async {
    var activeTypeReads = 0;
    var allTypeReads = 0;

    await _pumpUnapproved(
      tester,
      screen: const AbnormalitiesHomeScreen(),
      overrides: [
        activeAbnormalityTypesProvider.overrideWith((ref) {
          activeTypeReads++;
          return Stream<List<AbnormalityType>>.value(const []);
        }),
        allAbnormalityTypesProvider.overrideWith((ref) {
          allTypeReads++;
          return Stream<List<AbnormalityType>>.value(const []);
        }),
      ],
    );

    expect(find.text('Abnormality access required'), findsOneWidget);
    expect(activeTypeReads, 0);
    expect(allTypeReads, 0);
  });

  testWidgets('charge abnormalities rejects before charge reads', (
    tester,
  ) async {
    var chargeReads = 0;

    await _pumpUnapproved(
      tester,
      screen: const ChargeAbnormalitiesScreen(sourceChargeNo: 12001),
      overrides: [
        abnormalitiesForChargeProvider.overrideWith((ref, sourceChargeNo) {
          chargeReads++;
          return Stream<List<ChargeAbnormality>>.value(const []);
        }),
      ],
    );

    expect(find.text('Charge-abnormality access required'), findsOneWidget);
    expect(find.textContaining('12001'), findsNothing);
    expect(chargeReads, 0);
  });

  testWidgets('charge abnormality actions reflect the signed-in authority', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final record = _sampleChargeAbnormality();

    Future<void> pumpFor(AppUser actor) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(actor.uid),
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(actor),
            ),
            abnormalitiesForChargeProvider.overrideWith(
              (ref, sourceChargeNo) =>
                  Stream<List<ChargeAbnormality>>.value([record]),
            ),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: const ChargeAbnormalitiesScreen(sourceChargeNo: 51139),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pumpFor(_approvedActor());
    expect(find.text('Log Abnormality'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);

    await pumpFor(_approvedMaintenanceViewer());
    expect(find.text('Log Abnormality'), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);

    await pumpFor(_adminActor());
    expect(find.text('Log Abnormality'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets(
    'operations can reach the full RA lifecycle form at phone width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final type =
          AbnormalityType()
            ..firestoreId = 'TYPE_1'
            ..code = 'TYPE_1'
            ..title = 'Observed process condition'
            ..category = AbnormalityCategory.process
            ..severity = AbnormalitySeverity.high
            ..suggestsReannealing = true
            ..isActive = true
            ..isDeleted = false
            ..createdAt = DateTime.utc(2026, 9, 2)
            ..updatedAt = DateTime.utc(2026, 9, 2);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_approvedActor()),
            ),
            abnormalitiesForChargeProvider.overrideWith(
              (ref, sourceChargeNo) =>
                  Stream<List<ChargeAbnormality>>.value(const []),
            ),
            abnormalityRepositoryProvider.overrideWithValue(
              _ActiveTypeRepository(type),
            ),
            syncCoordinatorProvider.overrideWithValue(_FakeSyncCoordinator()),
            assetClassesProvider.overrideWith(
              (ref) =>
                  Stream<List<AssetClassRecord>>.value([_furnaceAssetClass()]),
            ),
            assetInstancesProvider.overrideWith(
              (ref, assetClassId) =>
                  Stream<List<AssetInstanceRecord>>.value([_furnaceAsset()]),
            ),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: const ChargeAbnormalitiesScreen(sourceChargeNo: 51139),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Charge 51139'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Log Abnormality'));
      await tester.pumpAndSettle();

      expect(find.text('Log charge abnormality'), findsOneWidget);
      expect(
        find.text(
          'This opinion is also carried into the linked Quality warning.',
        ),
        findsOneWidget,
      );
      final formList = find.byType(ListView).last;
      await tester.drag(formList, const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Affected equipment'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furnace').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furnace 7').last);
      await tester.pumpAndSettle();
      expect(find.text('Choose component or subcomponent'), findsOneWidget);

      await tester.drag(formList, const Offset(0, -1200));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Re-annealing / RA traceability'));
      await tester.pumpAndSettle();
      expect(find.text('RA lifecycle state'), findsOneWidget);
      await tester.tap(
        find.byType(DropdownButtonFormField<ReannealingStatus>).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('directives rejects before directive reads', (tester) async {
    var directiveReads = 0;

    await _pumpUnapproved(
      tester,
      screen: const Scaffold(body: DirectivesScreen()),
      overrides: [
        openDirectivesProvider.overrideWith((ref) {
          directiveReads++;
          return Stream<List<OperationalDirective>>.value(const []);
        }),
      ],
    );

    expect(find.text('Directive access required'), findsOneWidget);
    expect(directiveReads, 0);
  });

  testWidgets('compliance inbox rejects before obligation reads', (
    tester,
  ) async {
    var complianceReads = 0;

    await _pumpUnapproved(
      tester,
      screen: const ComplianceInboxScreen(laneKey: 'inst'),
      overrides: [
        workflowAllComplianceProvider.overrideWith((ref) {
          complianceReads++;
          return Stream<List<ComplianceRequestRecord>>.value(const []);
        }),
      ],
    );

    expect(find.text('Compliance access required'), findsOneWidget);
    expect(find.textContaining('INST'), findsNothing);
    expect(complianceReads, 0);
  });

  testWidgets('compliance detail rejects before aggregate reads', (
    tester,
  ) async {
    var aggregateReads = 0;
    final record =
        ComplianceRequestRecord()
          ..firestoreId = 'compliance-1'
          ..title = 'Move Furnace 7'
          ..linkedWorkflowId = 'workflow-1';

    await _pumpUnapproved(
      tester,
      screen: ComplianceDetailScreen(record: record),
      overrides: [
        workflowAuthoritativeRecordProvider.overrideWith((ref, scope) {
          aggregateReads++;
          return Future.value(null);
        }),
      ],
    );

    expect(find.text('Compliance access required'), findsOneWidget);
    expect(find.text('Move Furnace 7'), findsNothing);
    expect(aggregateReads, 0);
  });

  testWidgets('compliance detail rejects an approved unrelated audience', (
    tester,
  ) async {
    var aggregateReads = 0;
    final record =
        ComplianceRequestRecord()
          ..firestoreId = 'compliance-private'
          ..title = 'Electrical isolation support'
          ..description = 'Isolate the burner control supply.'
          ..originLaneKey = 'mechanical'
          ..targetLaneKey = 'inst'
          ..raisedByUid = 'mechanical-1'
          ..linkedWorkflowId = 'workflow-private';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_approvedActor()),
          ),
          workflowAuthoritativeRecordProvider.overrideWith((ref, scope) {
            aggregateReads++;
            return Future.value(null);
          }),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: ComplianceDetailScreen(record: record),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compliance access required'), findsOneWidget);
    expect(find.text('Electrical isolation support'), findsNothing);
    expect(aggregateReads, 0);
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

AppUser _approvedMaintenanceViewer() => AppUser(
  uid: 'approved-mechanical',
  name: 'Approved Mechanical',
  email: 'approved.mechanical@example.com',
  roles: const <AppRole>[AppRole.seniorMechanical],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 24),
);

AppUser _adminActor() => AppUser(
  uid: 'approved-admin',
  name: 'Approved Admin',
  email: 'approved.admin@example.com',
  roles: const <AppRole>[AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 24),
);

ChargeAbnormality _sampleChargeAbnormality() {
  final timestamp = DateTime.utc(2026, 9, 2, 7, 30);
  return ChargeAbnormality()
    ..firestoreId = 'abnormality-authority-test'
    ..sourceChargeNo = 51139
    ..abnormalityTypeId = 'QC03'
    ..abnormalityTypeCode = 'QC03'
    ..abnormalityTypeTitle = 'H2 ingress during cooling'
    ..category = AbnormalityCategory.process
    ..severity = AbnormalitySeverity.high
    ..observedReason = 'Annealing colour requires review.'
    ..loggedAt = timestamp
    ..updatedAt = timestamp
    ..loggedByUid = 'approved-operations'
    ..loggedByName = 'Approved Operations'
    ..isSynced = true;
}

class _ActiveTypeRepository extends Fake implements AbnormalityRepository {
  _ActiveTypeRepository(this.type);

  final AbnormalityType type;

  @override
  Future<List<AbnormalityType>> getActiveTypes() async => [type];
}

class _FakeSyncCoordinator extends Fake implements SyncCoordinator {}

AssetClassRecord _furnaceAssetClass() => AssetClassRecord(
  id: 'class-furnace',
  code: 'FR',
  name: 'Furnace',
  majorArea: 'BAF Shop',
  legacyAssetTypeKey: 'furnace',
  status: AssetHierarchyStatus.active,
  version: 2,
  createdAt: DateTime.utc(2026, 8, 1),
  createdByUid: 'admin-1',
  updatedAt: DateTime.utc(2026, 9, 1),
  updatedByUid: 'admin-1',
  lastMutationId: 'class-furnace-v2',
);

AssetInstanceRecord _furnaceAsset() => AssetInstanceRecord(
  id: 'asset-furnace-7',
  assetClassId: 'class-furnace',
  assetClassCode: 'FR',
  assetClassName: 'Furnace',
  assetNumber: 7,
  name: 'Furnace 7',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Operations',
  accountableRoleKeys: const ['operations'],
  status: AssetHierarchyStatus.active,
  activeComponentCount: 10,
  version: 4,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
  lastMutationId: 'asset-furnace-7-v4',
);
