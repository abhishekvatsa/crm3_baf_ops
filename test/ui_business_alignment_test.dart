import 'dart:io';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormalities_home_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/workflow_diagnostics_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/complete_job_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/job_module_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/planned_job_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUser _actor(AppRole role, {bool approved = true}) => AppUser(
  uid: 'actor-${role.name}',
  name: role.name,
  email: '${role.name}@example.com',
  roles: <AppRole>[role],
  isApproved: approved,
  createdAt: DateTime.utc(2026, 7, 31),
);

JobExecution _governedExecution() {
  final timestamp = DateTime.utc(2026, 7, 31, 18);
  return JobExecution()
    ..id = 31
    ..firestoreId = 'execution-ui-alignment'
    ..templateFirestoreId = 'version-ui-alignment'
    ..templateName = 'Governed UI alignment job'
    ..templatePackageId = 'package-ui-alignment'
    ..templateVersionId = 'version-ui-alignment'
    ..templateVersionNumber = 3
    ..templateVersionLabel = 'Release 3'
    ..templateContentHash = 'tg2-sha256:ui-alignment'
    ..templatePackageCode = 'BAF-UI-ALIGNMENT'
    ..assetType = AssetType.base
    ..assetNumber = 31
    ..isCompleted = false
    ..assignedByUid = 'planner'
    ..assignedByName = 'Planner'
    ..assignedAgencies = <String>['mechanical']
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..workflowSchemaVersion = 0
    ..version = 1
    ..isDeleted = false
    ..isSynced = true
    ..createdAt = timestamp
    ..updatedAt = timestamp;
}

JobExecution _cancelledExecution() {
  final execution = _governedExecution();
  return execution
    ..isCancelled = true
    ..cancelledAt = DateTime.utc(2026, 7, 31, 19)
    ..cancelledByUid = 'supervisor-1'
    ..cancelledByName = 'Shift Supervisor'
    ..cancellationReason = 'Asset returned to Operations before work started.'
    ..version = 2
    ..updatedAt = DateTime.utc(2026, 7, 31, 19);
}

JobExecution _deletedExecution() {
  final execution = _governedExecution();
  return execution
    ..isDeleted = true
    ..deletedAt = DateTime.utc(2026, 7, 31, 19)
    ..deletedByUid = 'admin-1'
    ..deletedByName = 'System Administrator'
    ..deleteReason = 'Duplicate historical execution.'
    ..version = 2
    ..updatedAt = DateTime.utc(2026, 7, 31, 19);
}

JobModuleInstance _openModule() {
  final timestamp = DateTime.utc(2026, 7, 31, 18, 15);
  return JobModuleInstance()
    ..id = 41
    ..firestoreId = 'module-ui-alignment'
    ..jobExecutionFirestoreId = 'execution-ui-alignment'
    ..moduleCode = 'F-01'
    ..moduleTitle = 'Burner and combustion inspection'
    ..moduleSnapshotJson = '{}'
    ..fieldDefinitionsJson = '[]'
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..assetType = AssetType.base
    ..assetNumber = 31
    ..status = JobModuleStatus.inProgress
    ..discipline = JobModuleDiscipline.mechanical
    ..createdAt = timestamp
    ..updatedAt = timestamp
    ..isSynced = true;
}

class _StaticJobModuleRepository implements JobModuleRepository {
  _StaticJobModuleRepository([this.modules = const <JobModuleInstance>[]]);

  final List<JobModuleInstance> modules;
  bool? lastIncludeDeleted;
  int? lastLimit;

  @override
  Stream<List<JobModuleInstance>> watchModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
    bool includeDeleted = false,
  }) {
    lastIncludeDeleted = includeDeleted;
    lastLimit = limit;
    return Stream<List<JobModuleInstance>>.value(
      includeDeleted
          ? modules
          : modules.where((module) => !module.isDeleted).toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyJobDiaryRepository implements JobDiaryRepository {
  @override
  Stream<List<JobDiaryEntry>> watchEntriesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    int? limit,
  }) => Stream<List<JobDiaryEntry>>.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DiagnosticsReadProbeRepository implements WorkflowRepository {
  int pendingCommandReads = 0;

  @override
  Future<List<WorkflowCommandRecord>> getPendingCommands() async {
    pendingCommandReads += 1;
    return const <WorkflowCommandRecord>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required AppUser actor,
  required Size size,
  JobExecution? execution,
  JobModuleRepository? moduleRepository,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream<AppUser?>.value(actor),
        ),
        jobModuleRepositoryProvider.overrideWithValue(
          moduleRepository ?? _StaticJobModuleRepository(),
        ),
        jobDiaryRepositoryProvider.overrideWithValue(
          _EmptyJobDiaryRepository(),
        ),
        maintenanceClassDefinitionsProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
        maintenanceDueStatesProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
        maintenancePlansProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: MaterialApp(
        home: PlannedJobDetailScreen(
          execution: execution ?? _governedExecution(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('UI business alignment', () {
    test(
      'equipment deployment capability follows generated command policy',
      () {
        for (final role in <AppRole>[
          AppRole.admin,
          AppRole.si,
          AppRole.operations,
          AppRole.shiftSupervisor,
        ]) {
          expect(
            _actor(role).canDeployMaintenanceEquipment,
            isTrue,
            reason: role.name,
          );
        }

        for (final role in <AppRole>[
          AppRole.contractSupervisor,
          AppRole.seniorElectrical,
          AppRole.seniorMechanical,
          AppRole.seniorInstrumentation,
          AppRole.refractory,
          AppRole.seniorRefractory,
        ]) {
          expect(
            _actor(role).canDeployMaintenanceEquipment,
            isFalse,
            reason: role.name,
          );
        }
        expect(
          _actor(
            AppRole.operations,
            approved: false,
          ).canDeployMaintenanceEquipment,
          isFalse,
        );
      },
    );

    test(
      'notification and navigation source preserve exact business context',
      () {
        final home = File('lib/home_screen.dart').readAsStringSync();
        final resolver =
            File(
              'lib/features/maintenance_workflow/presentation/screens/'
              'compliance_notification_screen.dart',
            ).readAsStringSync();
        final providers =
            File(
              'lib/features/maintenance_workflow/providers/workflow_providers.dart',
            ).readAsStringSync();
        final remote =
            File(
              'lib/features/maintenance_workflow/repositories/'
              'firestore_workflow_read_repository.dart',
            ).readAsStringSync();
        final audit =
            File(
              'lib/features/audit/presentation/audit_timeline_screen.dart',
            ).readAsStringSync();
        final diagnostics =
            File(
              'lib/features/maintenance_workflow/presentation/screens/'
              'workflow_diagnostics_screen.dart',
            ).readAsStringSync();

        expect(home, contains("message.data['complianceId']"));
        expect(home, contains('ComplianceNotificationScreen('));
        expect(home, isNot(contains('module: BafModules.charges')));
        expect(resolver, contains('ComplianceDetailScreen(record: record)'));
        expect(resolver, contains('ComplianceInboxScreen('));
        expect(resolver, contains('actorUid: actor.uid'));
        expect(audit, contains('actor.canReviewSyncConflicts'));
        expect(
          diagnostics,
          contains('actor.canViewMaintenanceWorkflowDiagnostics'),
        );

        expect(providers, contains('typedef WorkflowComplianceRecordScope'));
        expect(providers, contains('workflowCompliancePointReaderProvider'));
        expect(providers, contains('ActorSessionComplianceCache'));
        expect(providers, contains('_isOfflineCompliancePointRead'));
        expect(remote, contains('fetchComplianceById'));
        expect(remote, contains('GetOptions(source: Source.server)'));
        expect(remote, contains('if (document.metadata.hasPendingWrites)'));
        expect(remote, contains('return record.isDeleted ? null : record;'));
      },
    );

    test(
      'source gates dossier mutation affordances and legacy-only sections',
      () {
        final detail =
            File(
              'lib/features/planned_maintenance/presentation/'
              'planned_job_detail_screen.dart',
            ).readAsStringSync();
        final modules =
            File(
              'lib/features/planned_maintenance/presentation/dossier/'
              'planned_job_module_dossier.dart',
            ).readAsStringSync();
        final diary =
            File(
              'lib/features/planned_maintenance/presentation/dossier/'
              'planned_job_diary_dossier.dart',
            ).readAsStringSync();

        expect(detail, contains('actor?.canCreateJobDiaryEntry ?? false'));
        expect(
          detail,
          contains('actor?.canAddJobModuleDuringExecution ?? false'),
        );
        expect(detail, contains('actor?.canCompleteJobExecution ?? false'));
        expect(
          detail,
          contains('if (!execution.isGovernedTemplateAssignment)'),
        );
        expect(modules, contains('isOpenJob && onAddModule != null'));
        expect(diary, contains('isOpenJob && onAddEntry != null'));
      },
    );

    test('issue creation requires governed equipment before tag evidence', () {
      final source =
          File(
            'lib/features/maintenance/presentation/maintenance_form.dart',
          ).readAsStringSync();

      final selector = source.indexOf('_GovernedIssueAssetSelector(');
      final tagField = source.indexOf('controller: _tagController');
      final submit = source.indexOf('Future<void> _submit()');
      final awaitedTagVerdict = source.indexOf(
        'final accepted = await _resolveTag(',
        submit,
      );
      final actorRead = source.indexOf(
        'final appUser = ref.read(currentAppUserProvider).value;',
        submit,
      );
      final ticketSave = source.indexOf('await repository.saveTicket(record);');
      expect(selector, greaterThanOrEqualTo(0));
      expect(tagField, greaterThan(selector));
      expect(awaitedTagVerdict, greaterThan(submit));
      expect(actorRead, greaterThan(awaitedTagVerdict));
      expect(ticketSave, greaterThan(actorRead));
      expect(source, isNot(contains('_assetNumController')));
      expect(source, contains('hasGovernedAssetIdentity: true'));
      expect(source, contains('Duration(milliseconds: 450)'));
      expect(source, contains('_tagController.clear();'));
      expect(source, contains('must belong to the selected asset'));
      expect(source, contains('Select the Base carrying the Inner Cover'));
    });

    testWidgets('read-only governed dossier exposes no mutation bar', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        actor: _actor(AppRole.operations),
        size: const Size(320, 700),
      );

      expect(find.text('Add Note'), findsNothing);
      expect(find.text('Complete Job'), findsNothing);
      expect(find.text('Legacy execution summary'), findsNothing);
      expect(find.text('Checklist responses'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'cancelled planned job is a read-only dossier with cancellation evidence',
      (tester) async {
        final cancelledModule =
            _openModule()
              ..isDeleted = true
              ..deletedAt = DateTime.utc(2026, 7, 31, 19)
              ..deletedByUid = 'supervisor-1'
              ..deletedByName = 'Shift Supervisor'
              ..deleteReason =
                  'Workflow cancelled: Asset returned to Operations before work started.';
        final earlierTombstone =
            _openModule()
              ..id = 42
              ..firestoreId = 'module-removed-before-cancellation'
              ..isDeleted = true
              ..deletedAt = DateTime.utc(2026, 7, 31, 18, 30)
              ..deletedByUid = 'supervisor-2'
              ..deletedByName = 'Maintenance Supervisor'
              ..deleteReason = 'Removed as duplicate module.';
        final moduleRepository = _StaticJobModuleRepository([
          cancelledModule,
          earlierTombstone,
        ]);
        await _pumpDetail(
          tester,
          actor: _actor(AppRole.admin),
          size: const Size(320, 800),
          execution: _cancelledExecution(),
          moduleRepository: moduleRepository,
        );

        expect(moduleRepository.lastIncludeDeleted, isTrue);
        expect(moduleRepository.lastLimit, isNull);
        expect(find.text('Cancelled'), findsWidgets);
        expect(find.text('Cancelled job dossier'), findsOneWidget);
        expect(find.text('Cancelled-job dossier is read-only'), findsOneWidget);
        expect(
          find.text(
            'Reason: Asset returned to Operations before work started.',
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Cancelled module evidence'),
          400,
        );
        await tester.pumpAndSettle();
        expect(find.text('Cancelled module evidence'), findsOneWidget);
        expect(find.text('Cancelled with job'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Earlier removed module evidence'),
          400,
        );
        await tester.pumpAndSettle();
        expect(find.text('Earlier removed module evidence'), findsOneWidget);
        expect(find.text('Removed before cancellation'), findsOneWidget);
        expect(find.textContaining('Workflow cancelled:'), findsWidgets);
        expect(find.text('Add Note'), findsNothing);
        expect(find.text('Complete Job'), findsNothing);
        expect(find.text('Classify'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('deleted execution opens only as an immutable audit dossier', (
      tester,
    ) async {
      final moduleRepository = _StaticJobModuleRepository([_openModule()]);
      await _pumpDetail(
        tester,
        actor: _actor(AppRole.admin),
        size: const Size(320, 800),
        execution: _deletedExecution(),
        moduleRepository: moduleRepository,
      );

      expect(moduleRepository.lastIncludeDeleted, isFalse);
      expect(moduleRepository.lastLimit, 100);
      expect(find.text('Deleted job dossier'), findsOneWidget);
      expect(find.text('Deleted-job dossier is read-only'), findsOneWidget);
      expect(
        find.text('Reason: Duplicate historical execution.'),
        findsOneWidget,
      );
      expect(find.text('Add Note'), findsNothing);
      expect(find.text('Complete Job'), findsNothing);
      expect(find.text('Classify'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelled job cannot reopen completion controls', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
            ),
          ],
          child: MaterialApp(
            home: CompleteJobScreen(execution: _cancelledExecution()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This planned job was cancelled'), findsOneWidget);
      expect(find.text('Mark Job Completed'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelled parent locks the entire module workspace', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
            ),
          ],
          child: MaterialApp(
            home: JobModuleDetailScreen(
              execution: _cancelledExecution(),
              module: _openModule(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Read-only module evidence'), findsOneWidget);
      expect(find.text('Save Progress'), findsNothing);
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Save Responses as Draft'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'abnormality viewers see reports but not admin master actions',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith(
                (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
              ),
              activeAbnormalityTypesProvider.overrideWith(
                (ref) => Stream<List<AbnormalityType>>.value(const []),
              ),
              allAbnormalityTypesProvider.overrideWith(
                (ref) => Stream<List<AbnormalityType>>.value(const []),
              ),
            ],
            child: const MaterialApp(home: AbnormalitiesHomeScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -650));
        await tester.pumpAndSettle();

        expect(find.text('Reports / Intelligence'), findsOneWidget);
        expect(find.text('Abnormality Types'), findsNothing);
        expect(find.text('Default RA Type'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('diagnostics rejects before reading privileged local data', (
      tester,
    ) async {
      final repository = _DiagnosticsReadProbeRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
            ),
            workflowRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: WorkflowDiagnosticsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin/SI access required'), findsOneWidget);
      expect(repository.pendingCommandReads, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('admin can repair only a corrupt workflow quarantine log', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'last_maintenance_workflow_pull_v2_quarantine': '{not-json',
      });
      final repository = _DiagnosticsReadProbeRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
            ),
            workflowRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: WorkflowDiagnosticsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workflow diagnostics need repair'), findsOneWidget);
      expect(find.text('Clear local log'), findsOneWidget);
      expect(repository.pendingCommandReads, 0);

      await tester.tap(find.text('Clear local log'));
      await tester.pumpAndSettle();

      expect(find.text('Workflow diagnostics need repair'), findsNothing);
      expect(
        find.text('No malformed workflow projection is retained locally.'),
        findsOneWidget,
      );
      expect(repository.pendingCommandReads, 1);
      expect(tester.takeException(), isNull);
    });

    for (final size in <Size>[const Size(320, 700), const Size(900, 700)]) {
      testWidgets('authorized governed dossier is stable at ${size.width}px', (
        tester,
      ) async {
        await _pumpDetail(tester, actor: _actor(AppRole.admin), size: size);

        expect(find.text('Add Note'), findsOneWidget);
        expect(find.text('Complete Job'), findsOneWidget);
        expect(find.text('Legacy execution summary'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'governed completion uses module gate instead of legacy checklist',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith(
                (ref) => Stream<AppUser?>.value(_actor(AppRole.admin)),
              ),
              jobModuleRepositoryProvider.overrideWithValue(
                _StaticJobModuleRepository(),
              ),
            ],
            child: MaterialApp(
              home: CompleteJobScreen(execution: _governedExecution()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Module closure gate'), findsOneWidget);
        expect(find.text('Checklist responses'), findsNothing);
        expect(
          find.text('No checklist defined for this template.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
