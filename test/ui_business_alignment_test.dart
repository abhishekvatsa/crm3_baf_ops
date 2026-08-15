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
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/planned_job_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
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

class _EmptyJobModuleRepository implements JobModuleRepository {
  @override
  Stream<List<JobModuleInstance>> watchModulesForJob({
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    JobModuleDiscipline? discipline,
    int? limit,
  }) => Stream<List<JobModuleInstance>>.value(const []);

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
          _EmptyJobModuleRepository(),
        ),
        jobDiaryRepositoryProvider.overrideWithValue(
          _EmptyJobDiaryRepository(),
        ),
      ],
      child: MaterialApp(
        home: PlannedJobDetailScreen(execution: _governedExecution()),
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
        expect(audit, contains('actor.canReviewSyncConflicts'));
        expect(
          diagnostics,
          contains('actor.canViewMaintenanceWorkflowDiagnostics'),
        );

        final resolverStart = providers.indexOf(
          'final workflowComplianceRecordProvider',
        );
        final resolverSource = providers.substring(resolverStart);
        final localRead = resolverSource.indexOf('getComplianceById(id)');
        final governedPull = resolverSource.indexOf(
          'workflowPullServiceProvider',
        );
        final reread = resolverSource.lastIndexOf('getComplianceById(id)');
        expect(resolverStart, greaterThanOrEqualTo(0));
        expect(localRead, greaterThanOrEqualTo(0));
        expect(governedPull, greaterThan(localRead));
        expect(reread, greaterThan(governedPull));
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
      expect(selector, greaterThanOrEqualTo(0));
      expect(tagField, greaterThan(selector));
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
                _EmptyJobModuleRepository(),
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
