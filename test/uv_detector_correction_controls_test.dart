import 'dart:async';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/assets/data/uv_detector_installation_correction.dart';
import 'package:crm3_baf_ops/features/assets/data/uv_detector_lifecycle_event.dart';
import 'package:crm3_baf_ops/features/assets/presentation/widgets/uv_detector_lifecycle_list.dart';
import 'package:crm3_baf_ops/features/assets/providers/uv_detector_correction_provider.dart';
import 'package:crm3_baf_ops/features/assets/repositories/uv_detector_correction_repository.dart';
import 'package:crm3_baf_ops/features/assets/services/uv_detector_correction_command_service.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/test_support/in_memory_durable_submission_store.dart';

final _event = UvDetectorLifecycleEvent(
  eventId: 'event-a',
  assetClassId: 'furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetInstanceId: 'furnace-a',
  assetInstanceName: 'Furnace 1',
  assetNumber: 1,
  hierarchyNodeId: 'uv',
  hierarchyNodeName: 'UV flame scanner',
  hierarchyPath: const ['Furnace', 'UV flame scanner'],
  componentTag: 'UV-1',
  burnerPosition: 1,
  replacementDisposition: UvDetectorReplacementDisposition.newPart,
  performedByName: 'Technician',
  sourceType: UvDetectorLifecycleSourceType.workflowPlannedJob,
  sourceId: 'execution-a',
  sourceModuleId: 'module-a',
  sourceActionId: 'action-a',
  sourceActionIndex: 0,
  actionPerformedAt: DateTime.utc(2025, 9, 18, 10),
  completedAt: DateTime.utc(2025, 9, 19),
  completedByUid: 'supervisor',
  completedByName: 'Supervisor',
  recordedAt: DateTime.utc(2025, 9, 19),
  version: 1,
);

AppUser _actor(String uid, AppRole role) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.test',
  roles: [role],
  isApproved: true,
  createdAt: DateTime.utc(2025),
);

UvDetectorInstallationCorrection _correction(String id, String? prior) =>
    UvDetectorInstallationCorrection(
      id: id,
      eventId: _event.eventId,
      expectedCurrentEventId: _event.eventId,
      expectedCurrentActionPerformedAt: _event.actionPerformedAt,
      assetInstanceId: _event.assetInstanceId,
      assetClassId: _event.assetClassId,
      assetNumber: _event.assetNumber,
      componentTag: _event.componentTag,
      burnerPosition: _event.burnerPosition,
      originalAt: _event.actionPerformedAt,
      effectiveAt: DateTime.utc(2025, 9, prior == null ? 17 : 16, 10),
      correctedAt: DateTime.utc(2025, 9, 20),
      reason: 'Reviewed explanation $id',
      reviewerUid: 'admin-a',
      reviewerName: 'Admin A',
      supersedesId: prior,
    );

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Stream<AppUser?> actors,
    required _Service service,
    required _Repository repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => actors),
          uvDetectorCorrectionCommandServiceProvider.overrideWithValue(service),
          uvDetectorCorrectionRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(body: UvDetectorLifecycleList(events: [_event])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('only an approved Admin or SI sees installation correction', (
    tester,
  ) async {
    for (final role in [AppRole.operations, AppRole.seniorInstrumentation]) {
      await pump(
        tester,
        actors: Stream.value(_actor('operator', role)),
        service: _Service(),
        repository: _Repository(),
      );
      expect(find.byTooltip('Review installation correction'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    for (final role in [AppRole.admin, AppRole.si]) {
      await pump(
        tester,
        actors: Stream.value(_actor('reviewer', role)),
        service: _Service(),
        repository: _Repository(),
      );
      expect(find.byTooltip('Review installation correction'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'review preserves the original and shows every linked correction',
    (tester) async {
      final service = _Service();
      await pump(
        tester,
        actors: Stream.value(_actor('admin-a', AppRole.admin)),
        service: service,
        repository: _Repository(),
      );
      await tester.tap(find.byTooltip('Review installation correction'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Originally recorded installation:'),
        findsOneWidget,
      );
      expect(
        find.textContaining('does not record another replacement'),
        findsOneWidget,
      );
      await tester.tap(find.text('Correction history'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reviewed explanation first'), findsOneWidget);
      expect(find.textContaining('Reviewed explanation second'), findsWidgets);
      expect(service.correctCalls, 0);
    },
  );

  testWidgets(
    'saved correction resumes its original identity without opening a fresh form',
    (tester) async {
      final store = InMemoryDurableSubmissionStore();
      final pending = await store.prepare(
        DurableSubmissionDraft(
          submissionId: 'saved-request',
          actorUid: 'admin-a',
          requestId: 'saved-request',
          aggregateId: 'saved-correction',
          resourceKey: UvDetectorCorrectionCommandService.resource(
            _event.eventId,
          ),
          protocol: 'maintenanceWorkflow.v2',
          envelopeJson:
              '{"protocolVersion":2,"originActorUid":"admin-a","command":{"commandId":"saved-request","aggregateId":"saved-correction","expectedVersion":0,"commandType":"correctUvDetectorInstallation","payload":{}}}',
        ),
      );
      final service = _Service(pending: pending);
      final repository = _Repository();
      await pump(
        tester,
        actors: Stream.value(_actor('admin-a', AppRole.admin)),
        service: service,
        repository: repository,
      );
      await tester.tap(find.byTooltip('Review installation correction'));
      await tester.pumpAndSettle();
      expect(find.text('Check saved correction'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(repository.reads, 0);
      await tester.tap(find.text('Check saved correction'));
      await tester.pumpAndSettle();
      expect(service.resumed, ['saved-request']);
      expect(service.correctCalls, 0);
      expect(
        find.textContaining('Installation correction confirmed'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'changing account while review is open hides its evidence and disables submission',
    (tester) async {
      final actors = StreamController<AppUser?>();
      addTearDown(actors.close);
      final service = _Service();
      await pump(
        tester,
        actors: actors.stream,
        service: service,
        repository: _Repository(),
      );
      actors.add(_actor('admin-a', AppRole.admin));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Review installation correction'));
      await tester.pumpAndSettle();
      expect(find.text('Save correction'), findsOneWidget);
      actors.add(_actor('admin-b', AppRole.admin));
      await tester.pumpAndSettle();
      expect(find.text('Save correction'), findsNothing);
      expect(
        find.textContaining('Originally recorded installation:'),
        findsNothing,
      );
      expect(
        find.textContaining('An approved original account is required.'),
        findsOneWidget,
      );
      expect(service.correctCalls, 0);
    },
  );
}

class _Repository implements UvDetectorCorrectionRepository {
  int reads = 0;
  @override
  Future<UvDetectorCorrectionReview> review(String eventId) async {
    reads++;
    final first = _correction('first', null);
    final second = _correction('second', 'first');
    return UvDetectorCorrectionReview(
      original: _event,
      current: _event,
      corrections: [second, first],
      effectiveCorrection: second,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Service implements UvDetectorCorrectionCommandService {
  _Service({this.pending});
  final DurableSubmission? pending;
  final resumed = <String>[];
  int correctCalls = 0;

  @override
  Future<DurableSubmission?> pendingForEvent(String eventId) async => pending;

  @override
  Future<WorkflowCommandReceipt> resume(String submissionId) async {
    resumed.add(submissionId);
    return _receipt;
  }

  @override
  Future<WorkflowCommandReceipt> correct({
    required String correctionId,
    required String eventId,
    required String expectedCurrentEventId,
    required String expectedCurrentActionPerformedAt,
    required String correctedActionPerformedAt,
    required String reason,
    String? supersedesCorrectionId,
  }) async {
    correctCalls++;
    return _receipt;
  }

  WorkflowCommandReceipt get _receipt => WorkflowCommandReceipt(
    commandId: 'saved-request',
    resultKey: 'uv-detector-installation-corrected',
    aggregateVersion: 1,
    result: const {},
    appliedAt: DateTime.utc(2025, 9, 20),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
