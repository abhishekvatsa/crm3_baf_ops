import 'dart:io';

import 'package:crm3_baf_ops/core/services/live_remote_sync_service.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_inbox_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/templates_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 25, 7);

  group('live workflow projection freshness', () {
    test('a new server projection is accepted', () {
      expect(
        shouldApplyLiveWorkflowProjection(
          localVersion: null,
          localUpdatedAt: null,
          remoteVersion: 1,
          remoteUpdatedAt: timestamp,
        ),
        isTrue,
      );
    });

    test('a newer server version wins despite an older client timestamp', () {
      expect(
        shouldApplyLiveWorkflowProjection(
          localVersion: 2,
          localUpdatedAt: timestamp.add(const Duration(minutes: 5)),
          localIsSynced: true,
          remoteVersion: 3,
          remoteUpdatedAt: timestamp,
        ),
        isTrue,
      );
    });

    test('a same-version server correction follows the canonical clock', () {
      expect(
        shouldApplyLiveWorkflowProjection(
          localVersion: 3,
          localUpdatedAt: timestamp,
          localIsSynced: true,
          remoteVersion: 3,
          remoteUpdatedAt: timestamp.add(const Duration(milliseconds: 1)),
        ),
        isTrue,
      );
    });

    test('older server versions cannot overwrite a newer local projection', () {
      expect(
        shouldApplyLiveWorkflowProjection(
          localVersion: 4,
          localUpdatedAt: timestamp,
          localIsSynced: true,
          remoteVersion: 3,
          remoteUpdatedAt: timestamp.add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });

    test(
      'unsynchronized local work is never overwritten by the live mirror',
      () {
        expect(
          shouldApplyLiveWorkflowProjection(
            localVersion: 2,
            localUpdatedAt: timestamp,
            localIsSynced: false,
            remoteVersion: 5,
            remoteUpdatedAt: timestamp.add(const Duration(hours: 1)),
          ),
          isFalse,
        );
      },
    );

    test('live listeners cover every actionable workflow projection', () {
      final source =
          File(
            'lib/core/services/live_remote_sync_service.dart',
          ).readAsStringSync();

      expect(source, contains(".collection('maintenance_workflows')"));
      expect(source, contains(".collection('job_lanes')"));
      expect(source, contains(".collection('compliance_requests')"));
      expect(
        source,
        contains(".where('status', whereIn: _activeWorkflowStatuses)"),
      );
      expect(
        source,
        contains(".where('status', whereIn: _activeLaneStatuses)"),
      );
      expect(
        source,
        contains(".where('status', whereIn: _activeComplianceStatuses)"),
      );
      expect(source, contains('!snapshot.metadata.isFromCache'));
      expect(source, contains('GetOptions(source: Source.server)'));
      expect(source, contains('row.isSynced &&'));
      expect(
        RegExp(
          r'if \(local != null && local\.isSynced\)',
        ).allMatches(source).length,
        greaterThanOrEqualTo(2),
      );
    });
  });

  group('role-aware workflow attention', () {
    test(
      'operations sees an acknowledged crane request before it is overdue',
      () {
        final request =
            _craneRequest()
              ..statusKey = 'acknowledged'
              ..becameDueAt = null;

        final summary = summarizeWorkflowAttention(
          actor: _actor(AppRole.operations),
          lanes: const <JobLaneRecord>[],
          compliance: <ComplianceRequestRecord>[request],
        );

        expect(summary.activeComplianceCount, 1);
        expect(summary.total, 1);
      },
    );

    test('the originating maintenance lane can track its support request', () {
      final summary = summarizeWorkflowAttention(
        actor: _actor(AppRole.seniorMechanical),
        lanes: const <JobLaneRecord>[],
        compliance: <ComplianceRequestRecord>[_craneRequest()],
      );

      expect(summary.activeComplianceCount, 1);
    });

    test('an unrelated discipline cannot see another lane obligation', () {
      final summary = summarizeWorkflowAttention(
        actor: _actor(AppRole.seniorInstrumentation),
        lanes: const <JobLaneRecord>[],
        compliance: <ComplianceRequestRecord>[_craneRequest()],
      );

      expect(summary.total, 0);
    });

    test('terminal and deleted obligations are excluded', () {
      final closed = _craneRequest()..statusKey = 'confirmedClosed';
      final deleted = _craneRequest()..isDeleted = true;

      final summary = summarizeWorkflowAttention(
        actor: _actor(AppRole.operations),
        lanes: <JobLaneRecord>[
          JobLaneRecord()
            ..laneKey = 'oprn'
            ..statusKey = 'closed',
        ],
        compliance: <ComplianceRequestRecord>[closed, deleted],
      );

      expect(summary.total, 0);
    });

    test('an unapproved actor never receives workflow counts', () {
      final summary = summarizeWorkflowAttention(
        actor: _actor(AppRole.operations, approved: false),
        lanes: <JobLaneRecord>[
          JobLaneRecord()
            ..laneKey = 'oprn'
            ..statusKey = 'pending',
        ],
        compliance: <ComplianceRequestRecord>[_craneRequest()],
      );

      expect(summary.total, 0);
    });
  });

  testWidgets('operations Work opens directly on an active crane obligation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
          ),
          activeTemplatesProvider.overrideWith(
            (ref) => Stream<List<JobTemplate>>.value(const <JobTemplate>[]),
          ),
          openExecutionsProvider.overrideWith(
            (ref) => Stream<List<JobExecution>>.value(const <JobExecution>[]),
          ),
          workflowAllLanesProvider.overrideWith(
            (ref) => Stream<List<JobLaneRecord>>.value(const <JobLaneRecord>[]),
          ),
          workflowAllComplianceProvider.overrideWith(
            (ref) => Stream<List<ComplianceRequestRecord>>.value(
              <ComplianceRequestRecord>[_craneRequest()],
            ),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const Scaffold(body: TemplatesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workflow queue'), findsOneWidget);
    expect(find.text('Operations support required'), findsOneWidget);
    expect(find.textContaining('1 workflow actions'), findsOneWidget);
    expect(find.byTooltip('Refresh workflow obligations'), findsOneWidget);

    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();

    expect(find.text('Workflow queue'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an empty compliance inbox can refresh without administrator rights',
    (tester) async {
      var refreshCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(_actor(AppRole.operations)),
            ),
            workflowAllComplianceProvider.overrideWith(
              (ref) => Stream<List<ComplianceRequestRecord>>.value(
                const <ComplianceRequestRecord>[],
              ),
            ),
            workflowProjectionRefreshProvider.overrideWith(
              (ref) => () async => refreshCount++,
            ),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: const ComplianceInboxScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No actionable obligations'), findsOneWidget);
      await tester.tap(find.text('Refresh obligations'));
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

AppUser _actor(AppRole role, {bool approved = true}) => AppUser(
  uid: 'freshness-${role.name}',
  name: 'Freshness ${role.name}',
  email: 'freshness.${role.name}@example.com',
  roles: <AppRole>[role],
  isApproved: approved,
  createdAt: DateTime.utc(2026, 8, 25),
);

ComplianceRequestRecord _craneRequest() =>
    ComplianceRequestRecord()
      ..firestoreId = 'issue_compliance_crane_1'
      ..title = 'Operations support required'
      ..description = 'Crane movement is required for mechanical work.'
      ..requestPurposeKey = 'operationsSupport'
      ..operationsSupportTypeKey = 'craneMovement'
      ..operationsResourceKey = 'crane'
      ..originLaneKey = 'mech'
      ..targetLaneKey = 'oprn'
      ..statusKey = 'acknowledged'
      ..raisedByUid = 'another-mechanical-user';
