import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
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

WorkflowAggregateRecord _workflow() {
  return WorkflowAggregateRecord()
    ..firestoreId = 'exec_1'
    ..jobExecutionFirestoreId = 'exec_1'
    ..assetTypeKey = 'base'
    ..assetNumber = 101
    ..statusKey = 'inProgress'
    ..version = 2;
}

JobLaneRecord _lane({String status = 'closed'}) {
  return JobLaneRecord()
    ..firestoreId = 'exec_1_mechanical_1'
    ..workflowFirestoreId = 'exec_1'
    ..jobExecutionFirestoreId = 'exec_1'
    ..laneKey = 'mechanical'
    ..statusKey = status;
}

ComplianceRequestRecord _compliance({String status = 'raised'}) {
  return ComplianceRequestRecord()
    ..firestoreId = 'compliance_1'
    ..title = 'Operations support'
    ..description = 'Move the furnace to its maintenance stand.'
    ..targetLaneKey = 'oprn'
    ..statusKey = status
    ..linkedWorkflowId = 'exec_1'
    ..gatesLaneFirestoreId = 'job_lanes/exec_1_mechanical_1';
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
  Future<List<JobModuleInstance>> getModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
    bool includeDeleted = false,
  }) async {
    var result =
        includeDeleted
            ? modules.toList()
            : modules.where((module) => !module.isDeleted).toList();
    if (discipline != null) {
      result =
          result.where((module) => module.discipline == discipline).toList();
    }
    if (limit != null && result.length > limit) {
      result = result.take(limit).toList();
    }
    return result;
  }

  @override
  Stream<List<JobModuleInstance>> watchModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
    bool includeDeleted = false,
  }) {
    return Stream<List<JobModuleInstance>>.value(modules);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticWorkflowRepository implements WorkflowRepository {
  _StaticWorkflowRepository({
    required this.workflow,
    required this.lanes,
    this.compliance = const <ComplianceRequestRecord>[],
    this.workflowError,
  });

  final WorkflowAggregateRecord? workflow;
  final List<JobLaneRecord> lanes;
  final List<ComplianceRequestRecord> compliance;
  final Object? workflowError;

  @override
  Stream<WorkflowAggregateRecord?> watchWorkflow(String workflowId) {
    if (workflowError != null) {
      return Stream<WorkflowAggregateRecord?>.error(workflowError!);
    }
    return Stream<WorkflowAggregateRecord?>.value(workflow);
  }

  @override
  Stream<List<JobLaneRecord>> watchLanes(String workflowId) {
    return Stream<List<JobLaneRecord>>.value(lanes);
  }

  @override
  Stream<List<ComplianceRequestRecord>> watchCompliance(String workflowId) {
    return Stream<List<ComplianceRequestRecord>>.value(compliance);
  }

  @override
  Future<WorkflowAggregateRecord?> getWorkflow(String workflowId) async {
    return workflow;
  }

  @override
  Future<List<JobLaneRecord>> getLanes(String workflowId) async {
    return lanes;
  }

  @override
  Future<List<ComplianceRequestRecord>> getCompliance(String workflowId) async {
    return compliance;
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

  testWidgets('malformed Inner Cover assignment blocks completion visibly', (
    tester,
  ) async {
    final execution =
        _execution()..metadataJson = '{"assignmentInnerCoverPosition":{}}';

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

    expect(
      find.text('Inner Cover assignment evidence needs repair'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark Job Completed'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('an unclosed accountable lane disables governed completion', (
    tester,
  ) async {
    final execution = _execution()..workflowSchemaVersion = 1;

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
          workflowRepositoryProvider.overrideWithValue(
            _StaticWorkflowRepository(
              workflow: _workflow(),
              lanes: [_lane(status: 'acknowledged')],
            ),
          ),
        ],
        child: MaterialApp(home: CompleteJobScreen(execution: execution)),
      ),
    );

    await _pumpFrames(tester);
    await tester.scrollUntilVisible(
      find.text('Workflow lane closure is incomplete'),
      200,
    );

    expect(find.text('Workflow lane closure is incomplete'), findsOneWidget);
    expect(find.text('0/1 lanes closed'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark Job Completed'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a governed job without workflow identity cannot be closed', (
    tester,
  ) async {
    final execution =
        _execution()
          ..workflowSchemaVersion = 1
          ..firestoreId = null;

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
    await tester.scrollUntilVisible(
      find.text('Workflow identity needs repair'),
      200,
    );

    expect(find.text('Workflow identity needs repair'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark Job Completed'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed workflow read blocks completion without crashing', (
    tester,
  ) async {
    final execution = _execution()..workflowSchemaVersion = 1;

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
          workflowRepositoryProvider.overrideWithValue(
            _StaticWorkflowRepository(
              workflow: _workflow(),
              lanes: [_lane()],
              workflowError: StateError('Workflow state is unavailable.'),
            ),
          ),
        ],
        child: MaterialApp(home: CompleteJobScreen(execution: execution)),
      ),
    );

    await _pumpFrames(tester);
    await tester.scrollUntilVisible(
      find.text('Workflow readiness cannot be verified'),
      200,
    );

    expect(find.text('Workflow readiness cannot be verified'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark Job Completed'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a terminal workflow cannot accept another planned closure', (
    tester,
  ) async {
    final execution = _execution()..workflowSchemaVersion = 1;
    final workflow =
        _workflow()
          ..statusKey = 'cancelled'
          ..cancelled = true;

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
          workflowRepositoryProvider.overrideWithValue(
            _StaticWorkflowRepository(workflow: workflow, lanes: [_lane()]),
          ),
        ],
        child: MaterialApp(home: CompleteJobScreen(execution: execution)),
      ),
    );

    await _pumpFrames(tester);
    await tester.scrollUntilVisible(
      find.text('Workflow is already closed'),
      200,
    );

    expect(find.text('Workflow is already closed'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark Job Completed'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('blocking coordination disables otherwise ready completion', (
    tester,
  ) async {
    final execution = _execution()..workflowSchemaVersion = 1;

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
          workflowRepositoryProvider.overrideWithValue(
            _StaticWorkflowRepository(
              workflow: _workflow(),
              lanes: [_lane()],
              compliance: [_compliance()],
            ),
          ),
        ],
        child: MaterialApp(home: CompleteJobScreen(execution: execution)),
      ),
    );

    await _pumpFrames(tester);
    await tester.scrollUntilVisible(
      find.text('Blocking coordination remains open'),
      200,
    );

    expect(find.text('Blocking coordination remains open'), findsOneWidget);
    expect(find.text('1 blocking obligation'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark Job Completed'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'closed lanes and settled coordination enable governed completion',
    (tester) async {
      final execution = _execution()..workflowSchemaVersion = 1;

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
            workflowRepositoryProvider.overrideWithValue(
              _StaticWorkflowRepository(
                workflow: _workflow(),
                lanes: [_lane()],
                compliance: [_compliance(status: 'confirmedClosed')],
              ),
            ),
          ],
          child: MaterialApp(home: CompleteJobScreen(execution: execution)),
        ),
      );

      await _pumpFrames(tester);
      await tester.scrollUntilVisible(
        find.text('All workflow lanes are closed'),
        200,
      );

      expect(find.text('All workflow lanes are closed'), findsOneWidget);
      expect(find.text('1/1 lanes closed'), findsOneWidget);
      expect(find.text('0 blocking obligations'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mark Job Completed'),
      );
      expect(button.onPressed, isNotNull);
    },
  );

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

  testWidgets(
    'unsynced current-job module blocks final closure after preflight',
    (tester) async {
      final plannedRepo = _GateRejectingPlannedRepository();
      final module = _acceptedModule()..isSynced = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_supervisor()),
            ),
            plannedRepositoryProvider.overrideWithValue(plannedRepo),
            jobModuleRepositoryProvider.overrideWithValue(
              _StaticJobModuleRepository([module]),
            ),
          ],
          child: MaterialApp(home: CompleteJobScreen(execution: _execution())),
        ),
      );

      await _pumpFrames(tester);
      await tester.tap(find.text('Mark Job Completed'));
      await _pumpFrames(tester, frames: 12);

      expect(plannedRepo.completionCalls, 0);
      expect(
        find.textContaining('module changes could not be synced'),
        findsOneWidget,
      );
    },
  );
}
