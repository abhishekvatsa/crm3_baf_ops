// Real publication, assignment, accountable work and closure through phone UI.
// Prepare tool/dev/prepare_final_planned_phone_fixture.py first.
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/complete_job_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/job_module_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/planned_job_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/published_template_assignment_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/saved_published_assignment_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/template_publisher_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/job_module_card.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart' show keyedPrefix, waitFor, goBack;
import 'dev_issue_quality_journey_test.dart'
    show
        showControl,
        tapControl,
        enter,
        select,
        openMore,
        read,
        awaitRecord,
        switchActor;

const _server = GetOptions(source: Source.server);
const _package = 'dev-usability-planned-final-package';
const _title = 'DEV Furnace planned final inspection';
const _si = 'dev.usability-si@example.invalid';

Future<void> _home(WidgetTester tester) async {
  while (find.byType(HomeScreen).evaluate().isEmpty) {
    await goBack(tester);
  }
  await tester.tap(find.text('Home'));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _openJob(WidgetTester tester, String id) async {
  await _home(tester);
  await tester.tap(find.text('Work'));
  await tester.pump(const Duration(milliseconds: 500));
  await showControl(tester, find.byKey(ValueKey('open-job-$id')));
  await tapControl(tester, find.byKey(ValueKey('open-job-$id')));
  await waitFor(
    tester,
    () => find.byType(PlannedJobDetailScreen).evaluate().isNotEmpty,
    'Exact governed job dossier must open.',
  );
}

Future<void> _lane(WidgetTester tester, String action) async {
  await showControl(tester, find.byType(PlannedJobWorkflowPanel));
  final chip = find.descendant(
    of: find.byType(PlannedJobWorkflowPanel),
    matching: find.byKey(const ValueKey('workflow-lane-mech-1')),
  );
  await waitFor(
    tester,
    () => chip.evaluate().isNotEmpty,
    'The classified Mechanical lane must be loaded.',
  );
  await tapControl(tester, chip.first);
  await waitFor(
    tester,
    () => find
        .ancestor(of: find.text(action), matching: find.byType(ListTile))
        .evaluate()
        .any((element) => (element.widget as ListTile).onTap != null),
    'Lane readiness must enable $action before it is tapped.',
  );
  await tapControl(tester, find.text(action));
}

Future<bool> _recheckHeldWorkIfPresent(WidgetTester tester) async {
  await _home(tester);
  await openMore(tester, 'Sync health');
  await waitFor(
    tester,
    () => find.byType(DraggableScrollableSheet).evaluate().isNotEmpty,
    'Saved work health must open for the current approved actor.',
  );
  final recheck = find.byKey(const ValueKey('recheck-held-sync-changes'));
  var requested = false;
  final until = DateTime.now().add(const Duration(seconds: 3));
  while (recheck.evaluate().isEmpty && DateTime.now().isBefore(until)) {
    await tester.pump(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (recheck.evaluate().isNotEmpty) {
    await showControl(tester, recheck);
    await waitFor(
      tester,
      () =>
          recheck.evaluate().isNotEmpty &&
          (tester.widget(recheck) as ButtonStyleButton).onPressed != null,
      'Explicit retry waits for any current sync to finish.',
    );
    await tester.tap(recheck);
    requested = true;
    await tester.pump(const Duration(milliseconds: 500));
    debugPrint('DEV_PLANNED_ORIGIN_ACTOR_RECHECK_REQUESTED');
  }
  await tester.binding.handlePopRoute();
  await tester.pump(const Duration(milliseconds: 350));
  await _home(tester);
  return requested;
}

Future<QueryDocumentSnapshot<Map<String, dynamic>>> _findOne(
  WidgetTester tester,
  String collection,
  String fieldName,
  Object value,
) async {
  final until = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(until)) {
    final query = await FirebaseFirestore.instance
        .collection(collection)
        .where(fieldName, isEqualTo: value)
        .get(_server);
    if (query.docs.isNotEmpty) {
      expect(
        query.docs,
        hasLength(1),
        reason: 'Unique fixture intent, not arbitrary first row.',
      );
      return query.docs.single;
    }
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw TestFailure('$collection did not contain the saved intent.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'phone planned work publication to reviewed completion',
    (tester) async {
      expect(crm3UseEmulators, isTrue);
      final flutterError = FlutterError.onError;
      final platformError = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        FlutterError.onError = flutterError;
        PlatformDispatcher.instance.onError = platformError;
      }
      expect(crm3DemoProjectId, startsWith('demo-'));
      expect(Firebase.app().options.projectId, crm3DemoProjectId);
      await waitFor(
        tester,
        () =>
            find.text('Sign in with Google').evaluate().isNotEmpty ||
            find.byType(HomeScreen).evaluate().isNotEmpty,
        'Normal access gate',
      );
      if (find.text('Sign in with Google').evaluate().isNotEmpty) {
        await tester.tap(find.text('Sign in with Google'));
      }
      await waitFor(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'Approved app home',
      );
      if (FirebaseAuth.instance.currentUser?.email != _si) {
        await switchActor(tester, _si);
      }
      // Preserve and recover the accepted version and rejected dependent writes
      // from phone02 through the same explicit recovery action a user sees.
      final earlierPackage = await FirebaseFirestore.instance
          .doc('template_packages/dev-usability-planned-package')
          .get(_server);
      // Fresh CI has no historical phone02 rejection. When that record exists,
      // retain the original normal recovery proof before creating new work.
      if (earlierPackage.exists &&
          earlierPackage.data()!['activeVersionFirestoreId'] == null) {
        await openMore(tester, 'Sync health');
        await waitFor(
          tester,
          () => find.byType(DraggableScrollableSheet).evaluate().isNotEmpty,
          'The approved SI can reach detailed saved-write recovery.',
        );
        final recheck = find.byKey(const ValueKey('recheck-held-sync-changes'));
        await showControl(tester, recheck);
        await waitFor(
          tester,
          () =>
              recheck.evaluate().isNotEmpty &&
              (tester.widget(recheck) as ButtonStyleButton).onPressed != null,
          'Initial automatic sync must finish before explicit recovery.',
        );
        await tester.tap(recheck);
        await tester.pump(const Duration(milliseconds: 350));
        await awaitRecord(
          tester,
          'template_packages/dev-usability-planned-package',
          (row) => row['activeVersionFirestoreId'] == 'Ok3vJRHTVFbPiJOPQ6ek',
        );
        await awaitRecord(
          tester,
          'template_publish_audits/nTFIybnD4Fs6kHGjkQLa',
          (row) => row['versionFirestoreId'] == 'Ok3vJRHTVFbPiJOPQ6ek',
        );
        debugPrint('DEV_PLANNED_REJECTED_PUBLICATION_RECOVERED');
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 350));
        await _home(tester);
      }
      var package = await read('template_packages/$_package');
      final publishedHere = package['activeVersionFirestoreId'] == null;
      if (publishedHere) {
        await openMore(tester, 'Legacy template publisher');
        await waitFor(
          tester,
          () =>
              find.byType(TemplatePublisherScreen).evaluate().isNotEmpty &&
              find
                  .byType(DropdownButtonFormField<String?>)
                  .evaluate()
                  .isNotEmpty,
          'Normal publisher must load the fixture draft.',
        );
        await select(
          tester,
          find.byType(DropdownButtonFormField<String?>).first,
          _title,
        );
        final resume = find.byKey(
          const ValueKey(
            'resume-template-version-dev-usability-planned-final-version-1',
          ),
        );
        await waitFor(
          tester,
          () => resume.evaluate().isNotEmpty,
          'The exact prepared draft must be available to resume.',
        );
        await tapControl(tester, resume);
        await tapControl(tester, find.text('Publish New Version'));
        final confirmReview = find.byKey(
          const ValueKey('confirm-template-closure-review'),
        );
        await waitFor(
          tester,
          () => confirmReview.evaluate().isNotEmpty,
          'A successor requires an explicit fresh review of closure requirements.',
        );
        expect(find.text('Review closure requirements'), findsOneWidget);
        await tapControl(tester, confirmReview);
        package = await awaitRecord(
          tester,
          'template_packages/$_package',
          (row) => row['activeVersionFirestoreId'] is String,
        );
        debugPrint(
          'DEV_PLANNED_UI_PUBLISHED ${package['activeVersionFirestoreId']}',
        );
      }
      final versionId = package['activeVersionFirestoreId'] as String;
      final published = await read('template_versions/$versionId');
      expect(published['status'], 'published');
      expect(
        published['publishedByUid'],
        FirebaseAuth.instance.currentUser!.uid,
      );
      final publishedSnapshot = Map<String, dynamic>.from(published)
        ..remove('_globalPullServerUpdatedAt');
      final priorExecutions = await FirebaseFirestore.instance
          .collection('job_executions')
          .where('templateVersionId', isEqualTo: versionId)
          .get(_server);
      final existingWork = priorExecutions.docs
          .where(
            (doc) =>
                doc.data()['isCompleted'] != true &&
                (doc.data()['remarks'] as String? ?? '').startsWith(
                  'DEV phone planned assignment ',
                ),
          )
          .toList();
      expect(
        existingWork.length,
        lessThanOrEqualTo(1),
        reason:
            'Resume the same interrupted DEV work; never duplicate assignment.',
      );
      // The real publication notice can outlive the server readback and follow
      // us onto Home. Let its normal lifetime finish before touching controls
      // that it can cover on a smaller emulator display.
      await waitFor(
        tester,
        () => find.byType(SnackBar).evaluate().isEmpty,
        'Publication confirmation must finish before assignment navigation.',
        seconds: 20,
      );
      await _home(tester);
      await tester.tap(find.text('Work'));
      await tester.pump(const Duration(milliseconds: 500));
      final assignPublished = find.text('Assign Published');
      await showControl(tester, assignPublished);
      await waitFor(
        tester,
        () => assignPublished.hitTestable().evaluate().isNotEmpty,
        'Assign Published must be visible and unobstructed before tapping.',
      );
      await tapControl(tester, assignPublished.hitTestable());
      await waitFor(
        tester,
        () => find
            .byType(PublishedTemplateAssignmentScreen)
            .evaluate()
            .isNotEmpty,
        'Governed assignment form',
      );
      await waitFor(
        tester,
        () =>
            find.byType(SavedPublishedAssignmentScreen).evaluate().isNotEmpty ||
            find
                .byKey(const ValueKey('published-package-selector'))
                .evaluate()
                .isNotEmpty,
        'Saved assignment or the governed catalogue selector must load.',
      );
      late final int charge;
      late final String intent;
      final savedAssignment = find.byType(SavedPublishedAssignmentScreen);
      if (savedAssignment.evaluate().isNotEmpty) {
        // Read the displayed durable request only; submit through the real UI.
        final envelope = tester
            .widget<SavedPublishedAssignmentScreen>(savedAssignment)
            .submission
            .envelope;
        final original = envelope['request'] as Map<String, dynamic>;
        expect(original['packageId'], _package);
        expect(original['versionId'], versionId);
        intent = original['remarks'] as String;
        expect(intent, startsWith('DEV phone planned assignment '));
        charge = (original['chargeNoAtEvent'] as num).toInt();
        debugPrint('DEV_PLANNED_RESUMING_SAVED_ASSIGNMENT $intent');
        final retryButton = find.widgetWithText(
          FilledButton,
          'Check saved assignment',
        );
        await showControl(tester, retryButton);
        await waitFor(
          tester,
          () => tester.widget<FilledButton>(retryButton).onPressed != null,
          'Saved evidence must finish refreshing before retry.',
        );
        await tester.tap(retryButton);
        await tester.pump(const Duration(milliseconds: 350));
      } else if (existingWork.isNotEmpty) {
        final original = existingWork.single.data();
        intent = original['remarks'] as String;
        charge = (original['chargeNoAtEvent'] as num).toInt();
        debugPrint(
          'DEV_PLANNED_RESUMING_ACCEPTED_JOB ${existingWork.single.id}',
        );
        await goBack(tester);
      } else {
        await select(
          tester,
          find.byKey(const ValueKey('published-package-selector')),
          _title,
        );
        await select(tester, keyedPrefix('planned-work-asset-'), 'Furnace 01');
        charge = 60000 + DateTime.now().millisecondsSinceEpoch % 9999;
        intent =
            'DEV phone planned assignment ${DateTime.now().microsecondsSinceEpoch}';
        await enter(tester, 'Active charge number', '$charge');
        await enter(tester, 'Instructions / remarks', intent);
        await waitFor(
          tester,
          () => find
              .ancestor(
                of: find.text('Assign Published Job'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is ButtonStyleButton,
                ),
              )
              .evaluate()
              .any(
                (element) =>
                    (element.widget as ButtonStyleButton).onPressed != null,
              ),
          'Assignment readiness must enable the actual submit button.',
        );
        await tapControl(tester, find.text('Assign Published Job'));
      }
      await waitFor(tester, () {
        final recoveryError = find.byKey(
          const ValueKey('published-assignment-recovery-message'),
        );
        if (recoveryError.evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty) {
          throw TestFailure(
            'Saved assignment was not accepted: ${tester.widget<Text>(recoveryError).data}',
          );
        }
        return find
            .byType(PublishedTemplateAssignmentScreen)
            .evaluate()
            .isEmpty;
      }, 'Assignment must be accepted, not merely retained locally.');
      final execution = await _findOne(
        tester,
        'job_executions',
        'remarks',
        intent,
      );
      final executionId = execution.id;
      debugPrint('DEV_PLANNED_ASSIGNED $executionId');
      expect(execution.data()['templateVersionId'], versionId);
      expect(execution.data()['assetInstanceId'], 'seed-asset-furnace-01');
      final module = await _findOne(
        tester,
        'job_modules',
        'jobExecutionFirestoreId',
        executionId,
      );
      expect(module.data()['moduleCode'], 'DEV-MECH');
      await _openJob(tester, executionId);
      final lanePath = 'job_lanes/${executionId}_mech_1';
      var lane = await FirebaseFirestore.instance.doc(lanePath).get(_server);
      if (!lane.exists) {
        await tapControl(tester, find.text('Classify lanes'));
        await tapControl(tester, find.text('MECH - Mechanical'));
        await tapControl(tester, find.text('Finalise 1 lane'));
        await waitFor(
          tester,
          () => find.byType(PlannedJobDetailScreen).evaluate().isNotEmpty,
          'Lane classification must return to the dossier.',
        );
        lane = await FirebaseFirestore.instance.doc(lanePath).get(_server);
      }
      if (lane.data()?['status'] != 'acknowledged' &&
          lane.data()?['status'] != 'closed') {
        await _lane(tester, 'Acknowledge lane');
      }
      await awaitRecord(
        tester,
        lanePath,
        (row) => row['status'] == 'acknowledged' || row['status'] == 'closed',
      );
      debugPrint('DEV_PLANNED_LANE_ACKNOWLEDGED');
      await _home(tester);
      await switchActor(
        tester,
        'dev.usability-contractsupervisor@example.invalid',
      );
      final findings =
          'DEV trial: furnace inspection completed; no further defect found. $charge';
      final recheckedWorkerDraft = await _recheckHeldWorkIfPresent(tester);
      if (recheckedWorkerDraft) {
        await awaitRecord(
          tester,
          'job_modules/${module.id}',
          (row) => (row['responsesJson'] as String? ?? '').contains(findings),
        );
      }
      await _openJob(tester, executionId);
      await tapControl(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is JobModuleCard && widget.module.firestoreId == module.id,
        ),
      );
      await waitFor(
        tester,
        () => find.byType(JobModuleDetailScreen).evaluate().isNotEmpty,
        'Assigned module work must open.',
      );
      var currentModule = await read('job_modules/${module.id}');
      if (!(currentModule['responsesJson'] as String? ?? '').contains(
        findings,
      )) {
        await enter(tester, 'Inspection findings *', findings);
        final saveDraft = find.text('Save Responses as Draft');
        await tapControl(
          tester,
          saveDraft.evaluate().isNotEmpty
              ? saveDraft
              : find.text('Save Structured Responses'),
        );
      }
      await awaitRecord(
        tester,
        'job_modules/${module.id}',
        (row) => (row['responsesJson'] as String? ?? '').contains(findings),
      );
      currentModule = await read('job_modules/${module.id}');
      if (currentModule['status'] != 'submitted' &&
          currentModule['status'] != 'accepted') {
        await tapControl(tester, find.text('Submit'));
        await enter(
          tester,
          'Submission note',
          'DEV: completed inspection evidence submitted.',
        );
        await tapControl(tester, find.text('Submit Module'));
      }
      await awaitRecord(
        tester,
        'job_modules/${module.id}',
        (row) => row['status'] == 'submitted' || row['status'] == 'accepted',
      );
      debugPrint('DEV_PLANNED_WORKER_SUBMITTED');
      await _home(tester);
      await switchActor(tester, _si);
      await _openJob(tester, executionId);
      await tapControl(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is JobModuleCard && widget.module.firestoreId == module.id,
        ),
      );
      currentModule = await read('job_modules/${module.id}');
      if (currentModule['status'] != 'accepted') {
        await tapControl(tester, find.text('Accept'));
        await enter(
          tester,
          'Acceptance note',
          'DEV: independent SI review of recorded inspection.',
        );
        await tapControl(tester, find.text('Accept Module'));
      }
      await awaitRecord(
        tester,
        'job_modules/${module.id}',
        (row) => row['status'] == 'accepted',
      );
      debugPrint('DEV_PLANNED_REVIEWER_ACCEPTED');
      await goBack(tester);
      await showControl(tester, find.text('Live diary / handover'));
      await waitFor(
        tester,
        () => find.text('Add diary entry').evaluate().isNotEmpty,
        'The diary must load before adding the handover note.',
      );
      await tapControl(tester, find.text('Add diary entry').first);
      await enter(tester, 'Title (optional)', 'DEV handover $charge');
      await enter(
        tester,
        'Diary note *',
        'DEV trial: reviewed work and inspection evidence retained for handover.',
      );
      await tapControl(tester, find.text('Save entry'));
      final diary = await _findOne(
        tester,
        'job_diary_entries',
        'jobExecutionFirestoreId',
        executionId,
      );
      expect(
        diary.data()['createdByUid'],
        FirebaseAuth.instance.currentUser!.uid,
      );
      await _lane(tester, 'Close lane');
      await tapControl(tester, find.text('Continue').last);
      await awaitRecord(
        tester,
        'job_lanes/${executionId}_mech_1',
        (row) => row['status'] == 'closed',
      );
      await tapControl(tester, find.text('Complete Job'));
      await waitFor(
        tester,
        () => find.byType(CompleteJobScreen).evaluate().isNotEmpty,
        'Completion must check the accepted modules and closed lane.',
      );
      await enter(
        tester,
        'Remarks (optional)',
        'DEV phone: work reviewed and handed back.',
      );
      await tapControl(tester, find.text('Mark Job Completed'));
      await waitFor(
        tester,
        () => find.text('Final maintenance check').evaluate().isNotEmpty,
        'Explicit RED decision is required before final closure.',
      );
      await tapControl(
        tester,
        find.byKey(const ValueKey('planned-red-required-no')),
      );
      await tapControl(tester, find.text('Continue'));
      final completed = await awaitRecord(
        tester,
        'job_executions/$executionId',
        (row) => row['isCompleted'] == true,
      );
      expect(
        completed['completedByUid'],
        FirebaseAuth.instance.currentUser!.uid,
      );
      expect(completed['completedAt'], isNotNull);
      final accepted = await read('job_modules/${module.id}');
      expect(accepted['status'], 'accepted');
      expect(accepted['responsesJson'], contains(findings));
      final templateAfterWork = Map<String, dynamic>.from(
        await read('template_versions/$versionId'),
      )..remove('_globalPullServerUpdatedAt');
      expect(
        templateAfterWork,
        publishedSnapshot,
        reason:
            'Assigned work and completion must not mutate the published template.',
      );
      debugPrint(
        'DEV_PLANNED_WORK_PASS ${jsonEncode({'executionId': executionId, 'moduleId': module.id, 'diaryId': diary.id, 'templateVersionId': versionId, 'publishedThroughUiThisRun': publishedHere, 'charge': charge, 'explicitNoRed': true, 'separateWorkerAndReviewer': true, 'status': 'passed'})}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
    timeout: const Timeout(Duration(minutes: 18)),
  );
}
