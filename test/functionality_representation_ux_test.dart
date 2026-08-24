import 'package:crm3_baf_ops/features/audit/presentation/audit_timeline_screen.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/ticket_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/workflow_queue_view.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/closed_job_dossiers_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'approved operations can view records without receiving mutation rights',
    () {
      final actor = _actor(AppRole.operations);

      expect(actor.canViewOperationalAssets, isTrue);
      expect(actor.canViewClosedMaintenanceTickets, isTrue);
      expect(actor.canViewClosedJobDossiers, isTrue);
      expect(actor.canReopenMaintenanceTicket, isTrue);
      expect(actor.canCloseMaintenanceTicket, isFalse);
      expect(actor.canViewAuditLogs, isFalse);
    },
  );

  test('resolved issue correction is limited to Admin and SI', () {
    expect(_actor(AppRole.admin).canCorrectMaintenanceTicket, isTrue);
    expect(_actor(AppRole.si).canCorrectMaintenanceTicket, isTrue);
    expect(
      _actor(AppRole.contractSupervisor).canCorrectMaintenanceTicket,
      isFalse,
    );
    expect(_actor(AppRole.operations).canCorrectMaintenanceTicket, isFalse);
  });

  test('field roles can work and submit only their own module disciplines', () {
    final operations = _actor(AppRole.operations);
    final refractory = _actor(AppRole.refractory);

    expect(operations.canSaveJobModuleWorkFor('operations'), isTrue);
    expect(operations.canSubmitJobModule('operations'), isTrue);
    expect(operations.canSaveJobModuleWorkFor('mechanical'), isFalse);
    expect(operations.canSubmitJobModule('mechanical'), isFalse);
    expect(operations.canAcceptJobModule, isFalse);

    expect(refractory.canSaveJobModuleWorkFor('refractory'), isTrue);
    expect(refractory.canSubmitJobModule('refractory'), isTrue);
    expect(refractory.canSaveJobModuleWorkFor('electrical'), isFalse);
    expect(refractory.canSubmitJobModule('electrical'), isFalse);
    expect(refractory.canReopenJobModule, isFalse);
  });

  test(
    'ticket acknowledgement follows receiving route and supervisor scope',
    () {
      final electrical = _actor(AppRole.seniorElectrical);
      final operations = _actor(AppRole.operations);
      final supervisor = _actor(AppRole.contractSupervisor);

      expect(
        electrical.canAcknowledgeMaintenanceTicket(RoutedTo.electrical),
        isTrue,
      );
      expect(
        electrical.canAcknowledgeMaintenanceTicket(RoutedTo.mechanical),
        isFalse,
      );
      expect(
        operations.canAcknowledgeMaintenanceTicket(RoutedTo.operations),
        isTrue,
      );
      expect(
        operations.canAcknowledgeMaintenanceTicket(RoutedTo.electrical),
        isFalse,
      );
      expect(
        operations.canViewMaintenanceTicket(
          loggedByUid: 'another-operator',
          routedTo: RoutedTo.operations,
        ),
        isTrue,
      );
      expect(
        operations.canViewMaintenanceTicket(
          loggedByUid: 'another-operator',
          routedTo: RoutedTo.electrical,
        ),
        isFalse,
      );
      for (final route in RoutedTo.values) {
        expect(supervisor.canAcknowledgeMaintenanceTicket(route), isTrue);
      }
    },
  );

  testWidgets('operations sees and can acknowledge another user route ticket', (
    tester,
  ) async {
    final ticket = _maintenanceTicket(
      loggedByUid: 'another-operator',
      routedTo: RoutedTo.operations,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
          ),
          openTicketsProvider.overrideWith(
            (ref) => Stream<List<MaintenanceRecord>>.value([ticket]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TicketScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operations-routed burner issue'), findsOneWidget);
    expect(find.text('Acknowledge'), findsOneWidget);
    expect(
      find.text('Issues raised by you or routed to your team.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Operations-routed burner issue'));
    await tester.pumpAndSettle();
    expect(find.text('Issue context'), findsOneWidget);
    expect(find.text('Accountability'), findsOneWidget);
    expect(find.text('Work recorded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed dossiers are searchable and usable on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
          ),
          closedExecutionsProvider.overrideWith(
            (ref) => Stream<List<JobExecution>>.value([
              _execution(
                id: 'completed-1',
                name: 'Furnace inspection',
                assetNumber: 3,
                completed: true,
              ),
              _execution(
                id: 'cancelled-1',
                name: 'Cooler alignment',
                assetNumber: 8,
                cancelled: true,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: ClosedJobDossiersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Furnace inspection'), findsOneWidget);
    expect(find.text('Cooler alignment'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('closed-job-dossiers-search')),
      'cooler',
    );
    await tester.pump();

    expect(find.text('Furnace inspection'), findsNothing);
    expect(find.text('Cooler alignment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed dossiers reject before starting their data stream', (
    tester,
  ) async {
    var dossierReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(
              _actor(AppRole.operations, isApproved: false),
            ),
          ),
          closedExecutionsProvider.overrideWith((ref) {
            dossierReads++;
            return Stream<List<JobExecution>>.value(const []);
          }),
        ],
        child: const MaterialApp(home: ClosedJobDossiersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approved access required'), findsOneWidget);
    expect(dossierReads, 0);
  });

  testWidgets('workflow queue rejects before lane and compliance reads', (
    tester,
  ) async {
    var laneReads = 0;
    var complianceReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(
              _actor(AppRole.operations, isApproved: false),
            ),
          ),
          workflowAllLanesProvider.overrideWith((ref) {
            laneReads++;
            return Stream<List<JobLaneRecord>>.value(const []);
          }),
          workflowAllComplianceProvider.overrideWith((ref) {
            complianceReads++;
            return Stream<List<ComplianceRequestRecord>>.value(const []);
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WorkflowQueueView(bottomPadding: 24)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approved access is required.'), findsOneWidget);
    expect(laneReads, 0);
    expect(complianceReads, 0);
  });

  testWidgets('entity audit rejects non-admin before the audit read', (
    tester,
  ) async {
    var auditReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
          ),
          auditTimelineProvider.overrideWith((ref, scope) {
            auditReads++;
            return Future.value(const []);
          }),
        ],
        child: const MaterialApp(
          home: AuditTimelineScreen(
            entityType: 'execution',
            entityId: 'execution-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin access required'), findsOneWidget);
    expect(auditReads, 0);
  });

  testWidgets('approved admin can open the recent audit log', (tester) async {
    var auditReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
          ),
          recentAuditEventsProvider.overrideWith((ref, actorUid) {
            auditReads++;
            return Future.value(const []);
          }),
        ],
        child: const MaterialApp(home: RecentAuditLogScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No audit activity available'), findsOneWidget);
    expect(auditReads, 1);
  });
}

AppUser _actor(AppRole role, {bool isApproved = true}) => AppUser(
  uid: 'representation-${role.name}',
  name: 'Representation ${role.name}',
  email: 'representation.${role.name}@example.com',
  roles: <AppRole>[role],
  isApproved: isApproved,
  createdAt: DateTime.utc(2026, 7, 31),
);

JobExecution _execution({
  required String id,
  required String name,
  required int assetNumber,
  bool completed = false,
  bool cancelled = false,
}) {
  final timestamp = DateTime.utc(2026, 7, 31, 20);
  return JobExecution()
    ..firestoreId = id
    ..templateFirestoreId = 'template-$id'
    ..templateName = name
    ..assetType = AssetType.furnace
    ..assetNumber = assetNumber
    ..isCompleted = completed
    ..isCancelled = cancelled
    ..completedAt = completed ? timestamp : null
    ..cancelledAt = cancelled ? timestamp : null
    ..assignedAgencies = const ['operations']
    ..createdAt = timestamp
    ..updatedAt = timestamp
    ..isSynced = true;
}

MaintenanceRecord _maintenanceTicket({
  required String loggedByUid,
  required RoutedTo routedTo,
}) {
  final timestamp = DateTime.now().subtract(const Duration(hours: 1));
  return MaintenanceRecord()
    ..firestoreId = 'route-ticket-1'
    ..version = 1
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Operations-routed burner issue'
    ..routedTo = routedTo
    ..component = 'Burner system'
    ..loggedByUid = loggedByUid
    ..loggedByName = 'Another operator'
    ..startDate = timestamp
    ..createdAt = timestamp
    ..updatedAt = timestamp
    ..isSynced = true;
}
