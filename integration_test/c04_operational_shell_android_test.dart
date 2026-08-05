import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/presentation/login_screen.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/templates_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android runtime renders recovery, sign-in, and role-scoped work flows',
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.android);

      final failure = StartupFailure(
        stage: 'local_database_open',
        error: StateError('C-04 deterministic startup witness'),
        stackTrace: StackTrace.fromString('c04-android-integration'),
        occurredAt: DateTime.utc(2026, 8, 5),
      );
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('c04-recovery-scope'),
          child: CrmBafApp(startupFailure: failure),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Local database could not be opened'), findsOneWidget);
      expect(find.text('Create Recovery Package'), findsOneWidget);
      expect(find.text('Retry Opening Database'), findsOneWidget);
      expect(find.text('Backup & Rebuild Local DB'), findsOneWidget);

      await tester.pumpWidget(
        const ProviderScope(
          key: ValueKey('c04-login-scope'),
          child: MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CRM-III BAF Ops'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);

      final actor = AppUser(
        uid: 'c04-operations',
        name: 'C-04 Operations',
        email: 'c04.operations@example.invalid',
        roles: const <AppRole>[AppRole.operations],
        isApproved: true,
        createdAt: DateTime.utc(2026, 8, 5),
      );
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('c04-work-scope'),
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(actor),
            ),
            activeTemplatesProvider.overrideWith(
              (ref) => Stream<List<JobTemplate>>.value(const []),
            ),
            openExecutionsProvider.overrideWith(
              (ref) => Stream<List<JobExecution>>.value(const []),
            ),
            workflowAllLanesProvider.overrideWith(
              (ref) => Stream<List<JobLaneRecord>>.value(const []),
            ),
            workflowAllComplianceProvider.overrideWith(
              (ref) => Stream<List<ComplianceRequestRecord>>.value(const []),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: TemplatesScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jobs'), findsOneWidget);
      expect(find.text('Workflow'), findsOneWidget);
      expect(find.text('Templates'), findsNothing);
      expect(find.text('Assign Published'), findsNothing);

      await tester.tap(find.text('Workflow'));
      await tester.pumpAndSettle();

      expect(find.text('Workflow queue'), findsOneWidget);
      expect(
        find.text('No workflow tasks need your attention.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
