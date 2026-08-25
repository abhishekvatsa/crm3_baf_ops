import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/templates_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Work defaults to open jobs and shows governed executions even with no legacy templates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final observer = _RecordingNavigatorObserver();
      final execution = _governedOpenExecution();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_adminActor()),
            ),
            activeTemplatesProvider.overrideWith(
              (ref) => Stream<List<JobTemplate>>.value(<JobTemplate>[]),
            ),
            openExecutionsProvider.overrideWith(
              (ref) =>
                  Stream<List<JobExecution>>.value(<JobExecution>[execution]),
            ),
            workflowAllLanesProvider.overrideWith(
              (ref) => Stream<List<JobLaneRecord>>.value(const []),
            ),
            workflowAllComplianceProvider.overrideWith(
              (ref) => Stream<List<ComplianceRequestRecord>>.value(const []),
            ),
          ],
          child: MaterialApp(
            navigatorObservers: [observer],
            home: const Scaffold(body: TemplatesScreen()),
          ),
        ),
      );

      await _pumpFrames(tester, count: 6);

      expect(find.text('Open assigned jobs'), findsOneWidget);
      expect(find.text('70F Runtime Archive Test 2026-06-15'), findsOneWidget);
      expect(find.textContaining('BASE 17'), findsOneWidget);
      expect(find.text('Governed source'), findsOneWidget);
      expect(find.text('Remote-backed / synced'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('open-job-execution-visible-70f')),
        findsOneWidget,
      );
      expect(find.text('No templates yet'), findsNothing);

      final openJobCard = find.byKey(
        const ValueKey<String>('open-job-execution-visible-70f'),
      );
      final pushCountBeforeTap = observer.pushCount;
      await tester.ensureVisible(openJobCard);
      await tester.tap(openJobCard);

      expect(observer.pushCount, pushCountBeforeTap + 1);
    },
  );

  testWidgets('Templates remain available through the explicit view switch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_adminActor()),
          ),
          activeTemplatesProvider.overrideWith(
            (ref) => Stream<List<JobTemplate>>.value(<JobTemplate>[
              _legacyTemplate(),
            ]),
          ),
          openExecutionsProvider.overrideWith(
            (ref) => Stream<List<JobExecution>>.value(<JobExecution>[
              _governedOpenExecution(),
            ]),
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

    await _pumpFrames(tester, count: 6);
    expect(find.text('70F Runtime Archive Test 2026-06-15'), findsOneWidget);
    expect(find.text('Legacy preventive template'), findsNothing);

    await tester.tap(find.text('Templates'));
    await _pumpFrames(tester, count: 5);

    expect(find.text('Legacy preventive template'), findsOneWidget);
    expect(find.text('70F Runtime Archive Test 2026-06-15'), findsNothing);
  });

  testWidgets(
    'live role downgrade leaves the hidden template view immediately',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final actors = StreamController<AppUser?>();
      addTearDown(actors.close);
      actors.add(_adminActor());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            activeTemplatesProvider.overrideWith(
              (ref) => Stream<List<JobTemplate>>.value(<JobTemplate>[
                _legacyTemplate(),
              ]),
            ),
            openExecutionsProvider.overrideWith(
              (ref) => Stream<List<JobExecution>>.value(const <JobExecution>[]),
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

      await _pumpFrames(tester, count: 6);
      await tester.tap(find.text('Templates'));
      await _pumpFrames(tester, count: 4);
      expect(find.text('Legacy preventive template'), findsOneWidget);

      actors.add(_operationsActor());
      await _pumpFrames(tester, count: 6);

      expect(find.text('Templates'), findsNothing);
      expect(find.text('Legacy preventive template'), findsNothing);
      expect(find.text('Open assigned jobs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}

Future<void> _pumpFrames(WidgetTester tester, {required int count}) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

JobExecution _governedOpenExecution() {
  final timestamp = DateTime.utc(2026, 6, 16, 20, 30);
  return JobExecution()
    ..id = 17
    ..firestoreId = 'execution-visible-70f'
    ..templateFirestoreId = 'version-visible-70f'
    ..templateName = '70F Runtime Archive Test 2026-06-15'
    ..templatePackageId = 'package-visible-70f'
    ..templateVersionId = 'version-visible-70f'
    ..templateVersionNumber = 1
    ..templateVersionLabel = 'tg2-sha2'
    ..templateContentHash = 'tg2-sha256:visible'
    ..templatePackageCode = 'BAF-70F-RUNTIME-ARCHIVE-20260615'
    ..assetType = AssetType.base
    ..assetNumber = 17
    ..isCompleted = false
    ..assignedByUid = 'admin-visible'
    ..assignedByName = 'Runtime Verification Admin'
    ..assignedAgencies = <String>['mechanical']
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..createdAt = timestamp
    ..updatedAt = timestamp
    ..isDeleted = false
    ..isSynced = true;
}

JobTemplate _legacyTemplate() {
  final timestamp = DateTime.utc(2026, 6, 16, 19);
  return JobTemplate()
    ..id = 1
    ..firestoreId = 'legacy-template-visible'
    ..jobName = 'Legacy preventive template'
    ..applicableAssetType = AssetType.base
    ..assignedAgencies = <String>['mechanical']
    ..fieldsJson = '[]'
    ..createdAt = timestamp
    ..updatedAt = timestamp
    ..isDeleted = false
    ..isSynced = true;
}

AppUser _adminActor() {
  return AppUser(
    uid: 'admin-visible',
    name: 'Runtime Verification Admin',
    email: 'runtime.admin@example.com',
    roles: const <AppRole>[AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026, 6, 16),
  );
}

AppUser _operationsActor() {
  return AppUser(
    uid: 'operations-visible',
    name: 'Runtime Operations',
    email: 'runtime.operations@example.com',
    roles: const <AppRole>[AppRole.operations],
    isApproved: true,
    createdAt: DateTime.utc(2026, 6, 16),
  );
}
