import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_event_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/widgets/workflow_progress_route.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/widgets/workflow_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compliance route identifies completed and waiting stages', (
    tester,
  ) async {
    final record = ComplianceRequestRecord()
      ..firestoreId = 'compliance-1'
      ..title = 'Mechanical follow-up'
      ..description = 'Restore burner block'
      ..originLaneKey = 'oprn'
      ..targetLaneKey = 'mech'
      ..statusKey = 'complied'
      ..raisedByName = 'Operator One'
      ..raisedAt = DateTime.utc(2026, 8, 1, 8)
      ..acknowledgedByName = 'Mechanical One'
      ..acknowledgedAt = DateTime.utc(2026, 8, 1, 8, 15)
      ..compliedByName = 'Mechanical One'
      ..compliedAt = DateTime.utc(2026, 8, 1, 9)
      ..complianceNote = 'Burner block replaced';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ComplianceProgressRoute(record: record),
          ),
        ),
      ),
    );

    expect(find.text('Request raised'), findsOneWidget);
    expect(find.text('Target lane acknowledged'), findsOneWidget);
    expect(find.text('Work reported'), findsOneWidget);
    expect(find.text('Origin accepted completion'), findsOneWidget);
    expect(find.text('Waiting for Operations'), findsOneWidget);
    expect(find.textContaining('Burner block replaced'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returned compliance route preserves correction evidence', (
    tester,
  ) async {
    final record = ComplianceRequestRecord()
      ..firestoreId = 'compliance-2'
      ..title = 'Correct evidence'
      ..description = 'Provide clearer findings'
      ..originLaneKey = 'oprn'
      ..targetLaneKey = 'inst'
      ..statusKey = 'acknowledged'
      ..raisedAt = DateTime.utc(2026, 8, 2, 8)
      ..acknowledgedAt = DateTime.utc(2026, 8, 2, 8, 5)
      ..lastCorrectionByName = 'Shift In-charge'
      ..lastCorrectionAt = DateTime.utc(2026, 8, 2, 9)
      ..lastCorrectionReason = 'Add the measured microamp value';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ComplianceProgressRoute(record: record)),
      ),
    );

    expect(find.text('Returned for correction'), findsOneWidget);
    expect(find.text('Corrected work reported'), findsOneWidget);
    expect(find.textContaining('measured microamp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'condition route shows reactivation without inventing acknowledgement',
    (tester) async {
      final record = ComplianceRequestRecord()
        ..firestoreId = 'condition-1'
        ..title = 'Resume after charge completion'
        ..description = 'Release deferred maintenance after the charge'
        ..originLaneKey = 'mech'
        ..targetLaneKey = 'inst'
        ..statusKey = 'complied'
        ..conditionTypeKey = 'chargeComplete'
        ..conditionRef = '51139'
        ..requestPurposeKey = 'deferment'
        ..raisedByName = 'Mechanical One'
        ..raisedAt = DateTime.utc(2026, 8, 2, 8)
        ..dueMarkedByName = 'Operations One'
        ..dueMarkedAt = DateTime.utc(2026, 8, 2, 10)
        ..compliedByName = 'Operations One'
        ..compliedAt = DateTime.utc(2026, 8, 2, 10)
        ..complianceNote = 'Charge complete; linked work reactivated';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ComplianceProgressRoute(record: record)),
        ),
      );

      expect(find.text('Target lane acknowledged'), findsNothing);
      expect(find.text('Work reported'), findsNothing);
      expect(
        find.text('Release condition confirmed; linked work reactivated'),
        findsOneWidget,
      );
      expect(find.text('Origin accepted release'), findsOneWidget);
      expect(find.textContaining('Operations One'), findsOneWidget);
      expect(
        find.textContaining('Charge complete; linked work reactivated'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'workflow timeline translates storage events into business text',
    (tester) async {
      final event = WorkflowEventRecord()
        ..firestoreId = 'event-1'
        ..aggregateId = 'workflow-1'
        ..eventTypeKey = 'compliance.returnedForCorrection'
        ..laneKey = 'oprn'
        ..actorName = 'Shift In-charge'
        ..occurredAt = DateTime.utc(2026, 8, 2, 9)
        ..payloadJson =
            '{"complianceId":"internal-1","moduleFirestoreId":"module-1",'
            '"reason":"Add the measured value"}';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowTimeline(
              events: <WorkflowEventRecord>[event],
              complianceLabels: const <String, String>{
                'internal-1': 'Burner release confirmation',
              },
              moduleLabels: const <String, String>{
                'module-1': 'F-03 - Burner inspection',
              },
            ),
          ),
        ),
      );

      expect(find.text('Completion returned for correction'), findsOneWidget);
      expect(find.text('Request: Burner release confirmation'), findsOneWidget);
      expect(find.text('Module: F-03 - Burner inspection'), findsOneWidget);
      expect(
        find.textContaining('Shift In-charge - Operations lane'),
        findsOneWidget,
      );
      expect(find.text('Reason: Add the measured value'), findsOneWidget);
      expect(find.textContaining('internal-1'), findsNothing);
      expect(
        find.textContaining('compliance.returnedForCorrection'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('workflow timeline retains an unresolved business reference', (
    tester,
  ) async {
    final event = WorkflowEventRecord()
      ..firestoreId = 'event-2'
      ..aggregateId = 'workflow-1'
      ..eventTypeKey = 'compliance.acknowledged'
      ..occurredAt = DateTime.utc(2026, 8, 2, 9)
      ..payloadJson = '{"complianceId":"request-not-loaded"}';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkflowTimeline(events: <WorkflowEventRecord>[event]),
        ),
      ),
    );

    expect(find.text('Request reference: request-not-loaded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final legacyPayload in <String>[
    '"Legacy completion note retained verbatim"',
    '{"legacy":',
  ]) {
    testWidgets(
      'workflow timeline preserves unreadable stored payload: $legacyPayload',
      (tester) async {
        final event = WorkflowEventRecord()
          ..firestoreId = 'event-legacy'
          ..aggregateId = 'workflow-1'
          ..eventTypeKey = 'legacy.event'
          ..occurredAt = DateTime.utc(2026, 8, 2, 9)
          ..payloadJson = legacyPayload;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorkflowTimeline(events: <WorkflowEventRecord>[event]),
            ),
          ),
        );

        expect(
          find.text('Stored event details: $legacyPayload'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('workflow timeline preserves valid unrecognized payload fields', (
    tester,
  ) async {
    const legacyPayload =
        '{"templateFirestoreId":"template-legacy",'
        '"templateName":"Legacy furnace inspection",'
        '"assetTypeKey":"furnace","assetNumber":"03"}';
    final event = WorkflowEventRecord()
      ..firestoreId = 'event-valid-legacy'
      ..aggregateId = 'workflow-1'
      ..eventTypeKey = 'workflow.jobCreatedPendingClassification'
      ..occurredAt = DateTime.utc(2026, 8, 2, 9)
      ..payloadJson = legacyPayload;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkflowTimeline(events: <WorkflowEventRecord>[event]),
        ),
      ),
    );

    expect(find.text('Stored event details: $legacyPayload'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled compliance has no active waiting instruction', (
    tester,
  ) async {
    final record = ComplianceRequestRecord()
      ..firestoreId = 'cancelled-counter'
      ..title = 'Cancelled revised request'
      ..description = 'No longer required'
      ..originLaneKey = 'mech'
      ..targetLaneKey = 'oprn'
      ..statusKey = 'cancelled'
      ..conditionTypeKey = 'chargeComplete'
      ..counterRevisedDescription = 'Wait for the next charge'
      ..counterProposedByName = 'Operations One'
      ..counterProposedAt = DateTime.utc(2026, 8, 2, 9)
      ..raisedAt = DateTime.utc(2026, 8, 2, 8);

    final steps = complianceProgressSteps(record);

    expect(
      steps.where((step) => step.state == WorkflowProgressStepState.current),
      isEmpty,
    );
    expect(
      steps
          .singleWhere((step) => step.label == 'Revised condition proposed')
          .state,
      WorkflowProgressStepState.completed,
    );
    expect(steps.last.label, 'Request cancelled');
    expect(steps.last.state, WorkflowProgressStepState.stopped);
    expect(
      steps.where(
        (step) => step.detail?.toLowerCase().contains('waiting') == true,
      ),
      isEmpty,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ComplianceProgressRoute(record: record)),
      ),
    );
    expect(find.textContaining('Waiting'), findsNothing);
    expect(find.text('Request cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'workflow timeline preserves successor and replacement handoffs',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 2, 9);
      final events = <WorkflowEventRecord>[
        WorkflowEventRecord()
          ..firestoreId = 'event-finalized'
          ..aggregateId = 'workflow-1'
          ..eventTypeKey = 'workflow.finalized'
          ..occurredAt = timestamp
          ..payloadJson =
              '{"successorWorkflowId":"workflow-2",'
              '"successorExecutionId":"job-2",'
              '"preparationComplianceId":"request-2"}',
        WorkflowEventRecord()
          ..firestoreId = 'event-terminated'
          ..aggregateId = 'workflow-1'
          ..eventTypeKey = 'lane.terminated'
          ..occurredAt = timestamp
          ..payloadJson =
              '{"replacementLaneKey":"mech",'
              '"replacementGeneration":2,"remappedModuleCount":3}',
        WorkflowEventRecord()
          ..firestoreId = 'event-successor-created'
          ..aggregateId = 'workflow-2'
          ..eventTypeKey = 'workflow.redSuccessorCreated'
          ..occurredAt = timestamp
          ..payloadJson =
              '{"parentWorkflowId":"workflow-1",'
              '"parentExecutionId":"job-1"}',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowTimeline(
              events: events,
              complianceLabels: const <String, String>{
                'request-2': 'Prepare refractory access',
              },
            ),
          ),
        ),
      );

      expect(find.text('Successor workflow: workflow-2'), findsOneWidget);
      expect(find.text('Successor job: job-2'), findsOneWidget);
      expect(
        find.text('Preparation request: Prepare refractory access'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Replacement lane: Mechanical'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Replacement lane generation: 2'),
        findsOneWidget,
      );
      expect(find.textContaining('Modules transferred: 3'), findsOneWidget);
      expect(find.text('Originating workflow: workflow-1'), findsOneWidget);
      expect(find.text('Originating job: job-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('duplicate request titles retain unique references', (
    tester,
  ) async {
    final event = WorkflowEventRecord()
      ..firestoreId = 'event-duplicate'
      ..aggregateId = 'workflow-1'
      ..eventTypeKey = 'compliance.acknowledged'
      ..occurredAt = DateTime.utc(2026, 8, 2, 9)
      ..payloadJson = '{"complianceId":"request-b"}';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkflowTimeline(
            events: <WorkflowEventRecord>[event],
            complianceLabels: const <String, String>{
              'request-a': 'Inspect burner',
              'request-b': 'Inspect burner',
            },
          ),
        ),
      ),
    );

    expect(
      find.text('Request: Inspect burner (reference request-b)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'payload request titles and module labels retain duplicate references',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 2, 9);
      final events = <WorkflowEventRecord>[
        WorkflowEventRecord()
          ..firestoreId = 'event-request-a'
          ..aggregateId = 'workflow-1'
          ..eventTypeKey = 'compliance.raised'
          ..occurredAt = timestamp
          ..payloadJson =
              '{"complianceId":"request-a","title":"Inspect burner"}',
        WorkflowEventRecord()
          ..firestoreId = 'event-request-b'
          ..aggregateId = 'workflow-1'
          ..eventTypeKey = 'compliance.raised'
          ..occurredAt = timestamp
          ..payloadJson =
              '{"complianceId":"request-b","title":"Inspect burner"}',
        WorkflowEventRecord()
          ..firestoreId = 'event-module-b'
          ..aggregateId = 'workflow-1'
          ..eventTypeKey = 'module.reopened'
          ..occurredAt = timestamp
          ..payloadJson = '{"moduleFirestoreId":"module-b"}',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowTimeline(
              events: events,
              moduleLabels: const <String, String>{
                'module-a': 'Burner inspection',
                'module-b': 'Burner inspection',
              },
            ),
          ),
        ),
      );

      expect(
        find.text('Request: Inspect burner (reference request-a)'),
        findsOneWidget,
      );
      expect(
        find.text('Request: Inspect burner (reference request-b)'),
        findsOneWidget,
      );
      expect(
        find.text('Module: Burner inspection (reference module-b)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
