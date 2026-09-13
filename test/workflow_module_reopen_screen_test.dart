import 'dart:async';
import 'package:crm3_baf_ops/core/persistence/durable_submission.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/job_module_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/workflow_module_reopen_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/workflow_module_reopen_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _actor(String uid) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.test',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
JobModuleInstance _module(JobModuleStatus status) => JobModuleInstance()
  ..id = 9
  ..firestoreId = 'module-9'
  ..jobExecutionFirestoreId = 'job-7'
  ..jobExecutionLocalId = 7
  ..assetType = AssetType.base
  ..assetNumber = 107
  ..moduleTitle = 'Seal inspection'
  ..discipline = JobModuleDiscipline.mechanical
  ..laneKey = 'mech'
  ..createdAt = DateTime.utc(2026, 9, 12)
  ..updatedAt = DateTime.utc(2026, 9, 13)
  ..status = status
  ..version = 5
  ..isSynced = true;
JobExecution _execution() => JobExecution()
  ..id = 7
  ..firestoreId = 'job-7'
  ..templateFirestoreId = 'template-7'
  ..assetType = AssetType.base
  ..assetNumber = 107
  ..workflowSchemaVersion = 1
  ..createdAt = DateTime.utc(2026, 9, 12)
  ..updatedAt = DateTime.utc(2026, 9, 13);
DurableSubmission _saved() => DurableSubmission(
  submissionId: 'saved-reopen-1',
  actorUid: 'editor',
  requestId: 'saved-reopen-1',
  aggregateId: 'job-7',
  resourceKey: 'workflowModuleReopen:module-9',
  protocol: 'maintenanceWorkflow.v2',
  envelopeJson: '{}',
  displayMetadataJson: null,
  state: DurableSubmissionState.acceptedPendingAdoption,
  attemptCount: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  claimToken: null,
  claimExpiresAt: null,
  nextRetryAt: null,
  receiptJson: '{}',
  receiptSha256: 'ui-only',
  lastErrorCode: null,
  lastErrorMessage: null,
  legacySourceKey: null,
  legacySourceBase64: null,
);

class _Controller extends Fake implements WorkflowModuleReopenController {
  DurableSubmission? saved;
  int checks = 0, prepares = 0;
  Completer<JobModuleInstance>? pending;
  @override
  Future<DurableSubmission?> restore(String id) async => saved;
  @override
  Future<JobModuleInstance> check(String id) async {
    checks++;
    expect(id, 'saved-reopen-1');
    final current =
        await (pending?.future ??
            Future.value(_module(JobModuleStatus.accepted)..version = 6));
    saved = null;
    return current;
  }

  @override
  Future<DurableSubmission> prepare({
    required String actorUid,
    required String executionId,
    required int workflowVersion,
    required String reason,
    required JobModuleInstance baseline,
  }) async {
    prepares++;
    throw StateError('Unexpected new request');
  }
}

void main() {
  late StreamController<AppUser?> accounts;
  late _Controller controller;
  Future<void> open(WidgetTester tester, {bool saved = true}) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    accounts = StreamController<AppUser?>.broadcast();
    controller = _Controller()..saved = saved ? _saved() : null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => accounts.stream),
          workflowModuleReopenControllerProvider.overrideWithValue(controller),
        ],
        child: MaterialApp(
          home: JobModuleDetailScreen(
            execution: _execution(),
            module: _module(
              saved ? JobModuleStatus.reopened : JobModuleStatus.accepted,
            ),
          ),
        ),
      ),
    );
    accounts.add(_actor('editor'));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await accounts.close();
    });
  }

  Future<void> showButton(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'saved reopen remains discoverable after mirror and displays actual later state',
    (tester) async {
      await open(tester);
      await showButton(tester, 'Check saved reopen');
      await tester.tap(find.text('Check saved reopen'));
      await tester.pumpAndSettle();
      expect(controller.checks, 1);
      expect(controller.prepares, 0);
      expect(find.text('Current module state confirmed'), findsOneWidget);
      expect(find.text('Check saved reopen'), findsNothing);
      expect(find.text('Reopen Module'), findsOneWidget);
    },
  );
  testWidgets(
    'late saved-reopen result never adopts or reports success under another account',
    (tester) async {
      await open(tester);
      controller.pending = Completer<JobModuleInstance>();
      await showButton(tester, 'Check saved reopen');
      await tester.tap(find.text('Check saved reopen'));
      await tester.pump();
      accounts.add(_actor('other'));
      await tester.pump();
      controller.pending!.complete(
        _module(JobModuleStatus.accepted)..version = 6,
      );
      await tester.pumpAndSettle();
      expect(controller.checks, 1);
      expect(find.text('Current module state confirmed'), findsNothing);
      expect(find.text('Reopen Module'), findsNothing);
    },
  );
  testWidgets(
    'reopen reason hides on account/error and returns intact for original account',
    (tester) async {
      await open(tester, saved: false);
      await showButton(tester, 'Reopen Module');
      await tester.tap(find.text('Reopen Module'));
      await tester.pumpAndSettle();
      final reason = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Reopen reason',
      );
      await tester.enterText(reason, 'Original private reason');
      for (final error in [false, true]) {
        if (error) {
          accounts.addError(StateError('Authority refresh failed'));
        } else {
          accounts.add(_actor('other'));
        }
        await tester.pumpAndSettle();
        expect(reason, findsNothing);
        expect(find.text('Original private reason'), findsNothing);
        expect(find.text('Account verification required'), findsOneWidget);
        accounts.add(_actor('editor'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(reason).controller!.text,
          'Original private reason',
        );
      }
      final route = tester.element(reason);
      accounts.add(_actor('other'));
      await tester.pumpAndSettle();
      Navigator.of(route).pop('Original private reason');
      await tester.pumpAndSettle();
      expect(controller.prepares, 0);
      expect(controller.checks, 0);
    },
  );
}
