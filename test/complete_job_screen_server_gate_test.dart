import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/complete_job_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/planned_job_server_completion_service.dart';

AppUser _supervisor() => AppUser(
  uid: 'supervisor_1',
  name: 'Shift Supervisor',
  email: 'shift@example.com',
  roles: [AppRole.shiftSupervisor],
  isApproved: true,
  createdAt: DateTime.utc(2026, 5, 16),
);

JobExecution _execution() {
  return JobExecution()
    ..id = 101
    ..firestoreId = 'exec_1'
    ..templateFirestoreId = ''
    ..templateName = 'BAF closure template'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..isCompleted = false
    ..assignedByUid = 'planner'
    ..assignedByName = 'Planner'
    ..assignedAgencies = [RoutedTo.mechanical.name]
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..version = 2
    ..isDeleted = false
    ..createdAt = DateTime.utc(2026, 5, 16, 8)
    ..updatedAt = DateTime.utc(2026, 5, 16, 8, 30)
    ..isSynced = true;
}

JobModuleInstance _acceptedModule() {
  return JobModuleInstance()
    ..id = 1
    ..firestoreId = 'module_1'
    ..jobExecutionFirestoreId = 'exec_1'
    ..jobExecutionLocalId = 101
    ..templateFirestoreId = 'template_1'
    ..moduleCode = 'M-01'
    ..moduleTitle = 'Inspect base fan'
    ..moduleSnapshotJson = '{}'
    ..fieldDefinitionsJson =
        '[{"key":"vt_reading","type":"number","isRequired":true}]'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..status = JobModuleStatus.accepted
    ..useMode = JobModuleUseMode.scheduledPM
    ..discipline = JobModuleDiscipline.mechanical
    ..safetyClass = JobModuleSafetyClass.normal
    ..isRequired = true
    ..requiredForClosure = true
    ..responsesJson = '[{"key":"vt_reading","value":"2.1"}]'
    ..actionsJson = '[]'
    ..createdByUid = 'supervisor_1'
    ..createdByName = 'Shift Supervisor'
    ..createdAt = DateTime.utc(2026, 5, 16, 8)
    ..updatedByUid = 'supervisor_1'
    ..updatedByName = 'Shift Supervisor'
    ..updatedAt = DateTime.utc(2026, 5, 16, 8, 45)
    ..version = 1
    ..isSynced = true
    ..isDeleted = false;
}

class _GateRejectingPlannedRepository extends PlannedMaintenanceRepository {
  int completionCalls = 0;

  @override
  Future<JobTemplate?> getTemplateByFirestoreId(String firestoreId) async {
    return null;
  }

  @override
  Future<void> completeExecution(
    dynamic id, {
    required AppUser actor,
    String? remarks,
    List<String>? teamsInvolved,
    List<FieldResponse>? responses,
    List<ComponentAction>? actions,
  }) async {
    completionCalls += 1;
    throw const PlannedJobServerClosureGateException(
      message: 'Cannot complete planned job: modules are not ready.',
      issues: [
        PlannedJobServerClosureIssue(
          type: 'missingRequiredEvidence',
          count: 1,
          message: '1 required module(s) missing required evidence',
          moduleFirestoreIds: ['module_1'],
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticJobModuleRepository implements JobModuleRepository {
  _StaticJobModuleRepository(this.modules);

  final List<JobModuleInstance> modules;

  @override
  Stream<List<JobModuleInstance>> watchModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  }) {
    return Stream<List<JobModuleInstance>>.value(modules);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpFrames(
  WidgetTester tester, {
  int frames = 8,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < frames; i += 1) {
    await tester.pump(step);
  }
}

void main() {
  testWidgets('malformed saved execution responses block completion visibly', (
    tester,
  ) async {
    final execution = _execution()..responsesJson = '[{"key":"pressure"}]';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_supervisor()),
          ),
          plannedRepositoryProvider.overrideWithValue(
            _GateRejectingPlannedRepository(),
          ),
          jobModuleRepositoryProvider.overrideWithValue(
            _StaticJobModuleRepository([_acceptedModule()]),
          ),
        ],
        child: MaterialApp(home: CompleteJobScreen(execution: execution)),
      ),
    );

    await _pumpFrames(tester);

    expect(find.text('Saved response evidence needs repair'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark Job Completed'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('malformed module definitions become a closure repair blocker', (
    tester,
  ) async {
    final module =
        _acceptedModule()
          ..fieldDefinitionsJson = '[{"type":"text","required":true}]';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_supervisor()),
          ),
          plannedRepositoryProvider.overrideWithValue(
            _GateRejectingPlannedRepository(),
          ),
          jobModuleRepositoryProvider.overrideWithValue(
            _StaticJobModuleRepository([module]),
          ),
        ],
        child: MaterialApp(home: CompleteJobScreen(execution: _execution())),
      ),
    );

    await _pumpFrames(tester);

    expect(find.textContaining('needing evidence repair'), findsOneWidget);
    expect(find.text('1', skipOffstage: false), findsWidgets);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark Job Completed'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('server closure-gate rejection shows actionable dialog', (
    tester,
  ) async {
    final plannedRepo = _GateRejectingPlannedRepository();
    final moduleRepo = _StaticJobModuleRepository([_acceptedModule()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_supervisor()),
          ),
          plannedRepositoryProvider.overrideWithValue(plannedRepo),
          jobModuleRepositoryProvider.overrideWithValue(moduleRepo),
        ],
        child: MaterialApp(home: CompleteJobScreen(execution: _execution())),
      ),
    );

    await _pumpFrames(tester);

    await tester.tap(find.text('Mark Job Completed'));
    await _pumpFrames(tester, frames: 12);

    expect(plannedRepo.completionCalls, 1);
    expect(find.text('Server closure gate blocked'), findsOneWidget);
    expect(find.textContaining('canonical remote modules'), findsOneWidget);
    expect(find.textContaining('missing required evidence'), findsOneWidget);
    expect(find.textContaining('module_1'), findsOneWidget);
    expect(find.text('Failed to complete'), findsNothing);
  });
}
