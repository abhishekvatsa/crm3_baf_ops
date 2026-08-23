import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/audit/presentation/audit_timeline_screen.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/lane_classification_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/workflow_diagnostics_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/assign_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('assignment rejects before governed asset reads', (tester) async {
    var assetReads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
          ),
          assetClassesProvider.overrideWith((ref) {
            assetReads++;
            throw StateError('asset classes must not be read');
          }),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: AssignJobScreen(template: _template()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assignment access required'), findsOneWidget);
    expect(assetReads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lane classification rejects before command-state activation', (
    tester,
  ) async {
    var commandReads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
          ),
          workflowCommandControllerProvider.overrideWith((ref) {
            commandReads++;
            throw StateError('command controller must not be read');
          }),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const LaneClassificationScreen(
            workflowId: 'workflow-1',
            expectedVersion: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lane-classification access required'), findsOneWidget);
    expect(commandReads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'diagnostics reload for a new actor and hide on authority error',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final actors = StreamController<AppUser?>();
      final repository = _WorkflowRepositoryProbe();
      addTearDown(actors.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            workflowRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: const WorkflowDiagnosticsScreen(),
          ),
        ),
      );

      actors.add(_actor(AppRole.admin, uid: 'admin-one'));
      await tester.pumpAndSettle();
      expect(repository.pendingCommandReads, 1);

      actors.add(_actor(AppRole.si, uid: 'si-two'));
      await tester.pumpAndSettle();
      expect(repository.pendingCommandReads, 2);

      actors.addError(StateError('authority unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Diagnostics access could not be verified'),
        findsOneWidget,
      );
      expect(find.text('Local workflow health'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('audit history hides when live authority enters error', (
    tester,
  ) async {
    const entity = (type: 'execution', id: 'execution-1');
    final actors = StreamController<AppUser?>();
    var auditReads = 0;
    addTearDown(actors.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => actors.stream),
          auditTimelineProvider(entity).overrideWith((ref) {
            auditReads++;
            return Future.value(const []);
          }),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const AuditTimelineScreen(
            entityType: 'execution',
            entityId: 'execution-1',
          ),
        ),
      ),
    );

    actors.add(_actor(AppRole.admin));
    await tester.pumpAndSettle();
    expect(find.text('No recorded history'), findsOneWidget);
    expect(auditReads, 1);

    actors.addError(StateError('authority unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Audit access could not be verified'), findsOneWidget);
    expect(find.text('No recorded history'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

AppUser _actor(AppRole role, {String? uid}) => AppUser(
  uid: uid ?? 'authority-${role.name}',
  name: 'Authority ${role.name}',
  email: 'authority.${role.name}@example.com',
  roles: <AppRole>[role],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 24),
);

JobTemplate _template() {
  final timestamp = DateTime.utc(2026, 8, 24);
  return JobTemplate()
    ..firestoreId = 'template-1'
    ..jobName = 'Furnace inspection'
    ..applicableAssetType = AssetType.furnace
    ..assignedAgencies = <String>['mechanical']
    ..fieldsJson = '[]'
    ..createdAt = timestamp
    ..updatedAt = timestamp
    ..isDeleted = false
    ..isSynced = true;
}

class _WorkflowRepositoryProbe implements WorkflowRepository {
  int pendingCommandReads = 0;

  @override
  Future<List<WorkflowCommandRecord>> getPendingCommands() async {
    pendingCommandReads++;
    return const <WorkflowCommandRecord>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
