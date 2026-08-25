import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/models/lane_closure_readiness.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/widgets/lane_strip.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LaneClosureReadiness', () {
    test('requires acknowledgement even when assigned modules are settled', () {
      final readiness = LaneClosureReadiness.fromRecords(
        lane: _lane(status: 'pending'),
        modules: [_module(status: JobModuleStatus.accepted)],
        complianceRequests: const [],
      );

      expect(readiness.readyForClosure, isFalse);
      expect(
        readiness.blockingReasons,
        contains('Lane acknowledgement is required'),
      );
    });

    test('reports open modules and exact blocking compliance', () {
      final readiness = LaneClosureReadiness.fromRecords(
        lane: _lane(),
        modules: [
          _module(status: JobModuleStatus.inProgress),
          _module(
            id: 'old-generation-module',
            laneId: 'execution-1_elec_0',
            status: JobModuleStatus.inProgress,
          ),
        ],
        complianceRequests: [
          _compliance(gatesLaneId: 'job_lanes/execution-1_elec_1'),
          _compliance(
            id: 'other-lane-compliance',
            gatesLaneId: 'job_lanes/execution-1_mech_1',
          ),
        ],
      );

      expect(readiness.moduleCount, 1);
      expect(readiness.openModuleCount, 1);
      expect(readiness.blockingComplianceCount, 1);
      expect(readiness.readyForClosure, isFalse);
    });

    test('submitted required module remains blocked pending acceptance', () {
      final readiness = LaneClosureReadiness.fromRecords(
        lane: _lane(),
        modules: [
          _module(status: JobModuleStatus.submitted, requiredForClosure: true),
        ],
        complianceRequests: const [],
      );

      expect(
        readiness.blockingReasons,
        contains('1 required module(s) submitted but not accepted'),
      );
      expect(readiness.readyForClosure, isFalse);
    });

    test('missing authoritative module lane linkage fails closed', () {
      final module = _module(status: JobModuleStatus.accepted)
        ..workflowLaneFirestoreId = null;
      final readiness = LaneClosureReadiness.fromRecords(
        lane: _lane(),
        modules: [module],
        complianceRequests: const [],
      );

      expect(readiness.unlinkedModuleCount, 1);
      expect(
        readiness.blockingReasons,
        contains('1 module lacks authoritative lane linkage'),
      );
      expect(readiness.readyForClosure, isFalse);
    });

    test('accepted required module with no open gate is ready', () {
      final readiness = LaneClosureReadiness.fromRecords(
        lane: _lane(),
        modules: [
          _module(status: JobModuleStatus.accepted, requiredForClosure: true),
        ],
        complianceRequests: const [],
      );

      expect(readiness.blockingReasons, isEmpty);
      expect(readiness.readyForClosure, isTrue);
      expect(readiness.canOfferClosure(actorMayClose: true), isTrue);
      expect(readiness.canOfferClosure(actorMayClose: false), isFalse);
      expect(readiness.summary, contains('ready to close'));
    });

    test('malformed saved evidence becomes a visible closure blocker', () {
      final module = _module(
        status: JobModuleStatus.accepted,
        requiredForClosure: true,
      )..responsesJson = '[{"key":"pressure"}]';

      final readiness = LaneClosureReadiness.fromRecords(
        lane: _lane(),
        modules: [module],
        complianceRequests: const [],
      );

      expect(readiness.readyForClosure, isFalse);
      expect(
        readiness.blockingReasons,
        contains('1 module has saved evidence that needs repair'),
      );
      expect(readiness.summary, contains('needs repair'));
    });

    test('terminal lanes never advertise closure readiness', () {
      final removed = LaneClosureReadiness.fromRecords(
        lane: _lane(status: 'removed'),
        modules: const [],
        complianceRequests: const [],
      );
      final terminated = LaneClosureReadiness.fromRecords(
        lane: _lane(status: 'terminated'),
        modules: [_module(status: JobModuleStatus.accepted)],
        complianceRequests: const [],
      );

      expect(removed.summary, 'Removed');
      expect(removed.readyForClosure, isFalse);
      expect(removed.blockingReasons, isEmpty);
      expect(terminated.summary, 'Terminated - 1 module retained');
      expect(terminated.readyForClosure, isFalse);
      expect(terminated.canOfferClosure(actorMayClose: true), isFalse);
    });
  });

  testWidgets('lane strip presents readiness without narrow-screen overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lane = _lane();
    final readiness = LaneClosureReadiness.fromRecords(
      lane: lane,
      modules: [_module(status: JobModuleStatus.accepted)],
      complianceRequests: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: WorkflowLaneStrip(
              lanes: [lane],
              readinessByLaneId: {lane.firestoreId!: readiness},
              onLaneTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Electrical'), findsOneWidget);
    expect(find.textContaining('ready to close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty lane strip remains harmless', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WorkflowLaneStrip(lanes: []))),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('closed lanes retain their exact completion time and actor', (
    tester,
  ) async {
    final lane =
        _lane(status: 'closed')
          ..closedAt = DateTime(2026, 8, 25, 14, 35)
          ..closedByName = 'Electrical Supervisor';

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: WorkflowLaneStrip(lanes: [lane]))),
    );

    expect(
      find.text('Closed 25 Aug 2026, 14:35 by Electrical Supervisor'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workflow-lane-closure-elec-1')),
      findsOneWidget,
    );
  });
}

JobLaneRecord _lane({String status = 'acknowledged'}) {
  return JobLaneRecord()
    ..firestoreId = 'execution-1_elec_1'
    ..workflowFirestoreId = 'execution-1'
    ..jobExecutionFirestoreId = 'execution-1'
    ..laneKey = 'elec'
    ..statusKey = status
    ..activationGeneration = 1;
}

JobModuleInstance _module({
  String id = 'module-1',
  String laneId = 'execution-1_elec_1',
  required JobModuleStatus status,
  bool requiredForClosure = false,
}) {
  return JobModuleInstance()
    ..firestoreId = id
    ..jobExecutionFirestoreId = 'execution-1'
    ..workflowLaneFirestoreId = laneId
    ..laneKey = 'elec'
    ..moduleTitle = id
    ..status = status
    ..requiredForClosure = requiredForClosure
    ..fieldDefinitionsJson = '[]'
    ..responsesJson = '[]'
    ..actionsJson = '[]';
}

ComplianceRequestRecord _compliance({
  String id = 'compliance-1',
  required String gatesLaneId,
}) {
  return ComplianceRequestRecord()
    ..firestoreId = id
    ..title = id
    ..description = 'Controlled closure prerequisite'
    ..targetLaneKey = 'elec'
    ..statusKey = 'raised'
    ..gatesLaneFirestoreId = gatesLaneId;
}
