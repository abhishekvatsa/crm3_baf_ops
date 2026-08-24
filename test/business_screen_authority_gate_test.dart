import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormalities_home_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/charge_abnormalities_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
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
        workflowAggregateProvider.overrideWith((ref, workflowId) {
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
          workflowAggregateProvider.overrideWith((ref, workflowId) {
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
