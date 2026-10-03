// Real app/screens/native journal; no provider overrides or business fixture writes.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart';
import 'package:crm3_baf_ops/core/widgets/live_dropdown_form_field.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/complete_job_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/job_module_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/planned_job_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/published_template_assignment_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/template_publisher_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/job_module_card.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;
import '../dev_abnormality_journey_test.dart' show waitFor;
import '../dev_issue_quality_journey_test.dart'
    show showControl, tapControl, enter, select, openMore, switchActor;

import 'journey_pointer.dart' show currentRouteLists;

export '../dev_abnormality_journey_test.dart' show waitFor, goBack;
export '../dev_issue_quality_journey_test.dart'
    show showControl, tapControl, enter, openMore;

const redProject = 'demo-crm3-ci-journeys';
const redSi = 'dev.usability-si@example.invalid';
const redWorker = 'dev.required-red-refractory@example.invalid';
const redOperations = 'dev.operations@example.invalid';
const redElectrical = 'dev.required-red-electrical@example.invalid';
const redParentPackage = 'ci-required-red-parent-package';
const redSuccessorPackage = 'ci-required-red-successor-package';
const redIntent = 'CI required RED parent UI';
const server = GetOptions(source: Source.server);
IsarWorkflowRepository get nativeWorkflow => IsarWorkflowRepository(isar);

String canonicalResultSha256(Object? value) {
  Object? ordered(Object? item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: ordered(item[key])};
    }
    if (item is List) return item.map(ordered).toList();
    return item;
  }

  return sha256.convert(utf8.encode(jsonEncode(ordered(value)))).toString();
}

Future<void> startRedApp(WidgetTester tester, {required bool resume}) async {
  expect(crm3UseEmulators, isTrue);
  expect(crm3DemoProjectId, redProject);
  expect(crm3EmulatorHost, '10.0.2.2');
  expect(crm3FirestoreEmulatorPort, 18080);
  expect(crm3AuthEmulatorPort, 19099);
  expect(crm3FunctionsEmulatorPort, 15002);
  final error = FlutterError.onError;
  final platform = PlatformDispatcher.instance.onError;
  try {
    await tester.runAsync(app.startCrmBafApp);
  } finally {
    FlutterError.onError = error;
    PlatformDispatcher.instance.onError = platform;
  }
  expect(Firebase.app().options.projectId, redProject);
  await waitFor(
    tester,
    () =>
        find.byType(HomeScreen).evaluate().isNotEmpty ||
        find.text('Sign in with Google').evaluate().isNotEmpty,
    'Actual app approval gate',
  );
  if (resume) {
    expect(
      FirebaseAuth.instance.currentUser?.email,
      redOperations,
      reason:
          'Fresh process must retain the original Operations session without re-sign-in.',
    );
  } else if (find.text('Sign in with Google').evaluate().isNotEmpty) {
    await tapControl(tester, find.text('Sign in with Google'));
  }
  await waitFor(
    tester,
    () => find.byType(HomeScreen).evaluate().isNotEmpty,
    'Approved Home',
  );
}

bool _redRouteSettled(Element element) {
  final route = ModalRoute.of(element);
  return route != null &&
      route.isCurrent &&
      (route.animation == null ||
          route.animation!.status == AnimationStatus.completed) &&
      (route.secondaryAnimation == null ||
          route.secondaryAnimation!.status == AnimationStatus.dismissed);
}

// Home can appear while a submitted form is returning. Unlike a general control
// reveal, a Back button needs no scrolling: reacquire it after every pump, and
// send one real pointer gesture only while its exact settled route is current.
Future<void> returnRequiredRedHome(
  WidgetTester tester,
  Finder destination, {
  int maxPumps = 150,
  int maxBackGestures = 12,
  int popPumps = 50,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  Element? previousBack;
  Rect? previousRect;
  var gestures = 0;
  for (var attempt = 0; attempt < maxPumps; attempt++) {
    final home = destination.evaluate().where(_redRouteSettled).toList();
    if (home.length == 1) return;
    expect(home.length, lessThanOrEqualTo(1), reason: 'Home must be unique.');
    final backs = find
        .byTooltip('Back')
        .hitTestable()
        .evaluate()
        .where(_redRouteSettled)
        .toList();
    if (backs.length == 1 && tester.view.viewInsets.bottom == 0) {
      final element = backs.single;
      final target = find.byElementPredicate((e) => identical(e, element));
      final rect = tester.getRect(target);
      if (identical(previousBack, element) && previousRect == rect) {
        final route = ModalRoute.of(element)!;
        // No await separates this current-route/reachability check from the tap.
        if (_redRouteSettled(element) &&
            target.hitTestable().evaluate().length == 1) {
          expect(
            ++gestures,
            lessThanOrEqualTo(maxBackGestures),
            reason: 'RED Home navigation must be bounded.',
          );
          await tester.tap(target);
          await waitRequiredRedAutomaticReturn(
            tester,
            route,
            maxPumps: popPumps,
          );
          previousBack = null;
          previousRect = null;
          continue;
        }
      }
      previousBack = element;
      previousRect = rect;
    } else {
      previousBack = null;
      previousRect = null;
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  fail('RED navigation did not reach the exact settled Home route.');
}

Future<void> home(WidgetTester tester) async {
  await returnRequiredRedHome(tester, find.byType(HomeScreen));
  expect(find.byType(HomeScreen), findsOneWidget);
  await tapControl(tester, find.text('Home'));
}

Future<void> actor(WidgetTester tester, String email) async {
  await home(tester);
  if (FirebaseAuth.instance.currentUser?.email != email) {
    await switchActor(tester, email);
  }
}

Future<Map<String, dynamic>> committed(String path) async {
  final snap = await FirebaseFirestore.instance.doc(path).get(server);
  expect(snap.exists, isTrue, reason: path);
  expect(snap.metadata.isFromCache, isFalse, reason: path);
  expect(snap.metadata.hasPendingWrites, isFalse, reason: path);
  return snap.data()!;
}

Future<Map<String, dynamic>> untilRecord(
  WidgetTester tester,
  String path,
  bool Function(Map<String, dynamic>) ready,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  String last = 'missing';
  while (DateTime.now().isBefore(deadline)) {
    final snap = await FirebaseFirestore.instance.doc(path).get(server);
    last =
        'exists=${snap.exists}, pending=${snap.metadata.hasPendingWrites}, '
        'cache=${snap.metadata.isFromCache}, status=${snap.data()?['status']}';
    if (snap.exists &&
        !snap.metadata.hasPendingWrites &&
        !snap.metadata.isFromCache &&
        ready(snap.data()!)) {
      return snap.data()!;
    }
    await tester.pump(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure('Committed state did not converge: $path ($last)');
}

Future<QueryDocumentSnapshot<Map<String, dynamic>>> oneBy(
  WidgetTester tester,
  String collection,
  String field,
  Object value,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where(field, isEqualTo: value)
        .get(server);
    if (snap.docs.isNotEmpty &&
        !snap.metadata.hasPendingWrites &&
        !snap.metadata.isFromCache) {
      expect(
        snap.docs,
        hasLength(1),
        reason:
            'Exact unique synthetic intent; do not select an arbitrary row.',
      );
      return snap.docs.single;
    }
    await tester.pump(const Duration(milliseconds: 350));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw TestFailure('No committed unique $collection for $field=$value');
}

Future<String> publishDraft(
  WidgetTester tester,
  String package,
  String draft,
  String title,
) async {
  expect(
    (await committed('template_packages/$package'))['activeVersionFirestoreId'],
    isNull,
  );
  await home(tester);
  await openMore(tester, 'Legacy template publisher');
  await waitFor(
    tester,
    () =>
        find.byType(TemplatePublisherScreen).evaluate().isNotEmpty &&
        find.byType(DropdownButtonFormField<String?>).evaluate().isNotEmpty,
    'Publisher loads actual draft',
  );
  await select(
    tester,
    find.byType(DropdownButtonFormField<String?>).first,
    title,
  );
  final resume = find.byKey(ValueKey('resume-template-version-$draft'));
  await waitFor(
    tester,
    () => resume.evaluate().isNotEmpty,
    'Exact unpublished fixture draft',
  );
  await tapControl(tester, resume);
  await tapControl(tester, find.text('Publish New Version'));
  final review = find.byKey(const ValueKey('confirm-template-closure-review'));
  await waitFor(
    tester,
    () => review.evaluate().isNotEmpty,
    'Explicit closure review',
  );
  await tapControl(tester, review);
  final pointer = await untilRecord(
    tester,
    'template_packages/$package',
    (row) => row['activeVersionFirestoreId'] is String,
  );
  final version = pointer['activeVersionFirestoreId'] as String;
  final published = await untilRecord(
    tester,
    'template_versions/$version',
    (row) =>
        row['status'] == 'published' &&
        row['publishedByUid'] == FirebaseAuth.instance.currentUser!.uid &&
        row['publishedAt'] != null,
  );
  expect(published['status'], 'published');
  final auditDeadline = DateTime.now().add(const Duration(seconds: 90));
  QueryDocumentSnapshot<Map<String, dynamic>>? publishedAudit;
  while (DateTime.now().isBefore(auditDeadline)) {
    final rows = await FirebaseFirestore.instance
        .collection('template_publish_audits')
        .where('versionFirestoreId', isEqualTo: version)
        .get(server);
    final matches = rows.docs
        .where(
          (row) =>
              !row.metadata.hasPendingWrites &&
              !row.metadata.isFromCache &&
              row.data()['action'] == 'published' &&
              row.data()['packageFirestoreId'] == package &&
              row.data()['performedByUid'] ==
                  FirebaseAuth.instance.currentUser!.uid,
        )
        .toList();
    expect(
      matches.length,
      lessThanOrEqualTo(1),
      reason: 'One immutable publication event for the exact version.',
    );
    if (!rows.metadata.hasPendingWrites &&
        !rows.metadata.isFromCache &&
        matches.length == 1) {
      publishedAudit = matches.single;
      break;
    }
    await tester.pump(const Duration(milliseconds: 350));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  expect(
    publishedAudit,
    isNotNull,
    reason: 'The exact committed publication audit is required.',
  );
  expect(publishedAudit!.data()['afterHash'], published['contentHash']);
  expect(
    (await committed('template_packages/$package'))['activeVersionFirestoreId'],
    version,
  );
  await waitFor(
    tester,
    () => find.byType(SnackBar).evaluate().isEmpty,
    'Publication notice finishes',
    seconds: 20,
  );
  debugPrint('DEV_REQUIRED_RED_PUBLICATION_COMMITTED $package $version');
  return version;
}

Future<void> openJob(WidgetTester tester, String id) async {
  await home(tester);
  await tapControl(tester, find.text('Work'));
  final open = find.byKey(ValueKey('open-job-$id'));
  await showControl(tester, open);
  await tapControl(tester, open);
  await waitFor(
    tester,
    () => find.byType(PlannedJobDetailScreen).evaluate().isNotEmpty,
    'Exact job dossier',
  );
}

Future<void> laneAction(WidgetTester tester, String lane, String action) async {
  await showControl(tester, find.byType(PlannedJobWorkflowPanel));
  final chip = find.descendant(
    of: find.byType(PlannedJobWorkflowPanel),
    matching: find.byKey(ValueKey('workflow-lane-$lane-1')),
  );
  await waitFor(tester, () => chip.evaluate().isNotEmpty, 'Exact $lane lane');
  await tapControl(tester, chip.first);
  await waitFor(
    tester,
    () => find
        .ancestor(of: find.text(action), matching: find.byType(ListTile))
        .evaluate()
        .any((e) => (e.widget as ListTile).onTap != null),
    'Enabled $lane action: $action',
  );
  await tapControl(tester, find.text(action));
}

// The package change can replace the catalogue ListView while asset streams
// load. Reacquire its current viewport after each pump; never retain a scrollable
// across loading/rebuilds or retry the selection itself.
Future<void> selectRequiredRedParentAsset(
  WidgetTester tester, {
  int maxReadinessPumps = 450,
}) async {
  final control = find.descendant(
    of: currentRouteLists(),
    matching: find.byKey(
      const ValueKey('planned-work-asset-seed-class-annealing-furnace'),
    ),
  );
  Rect? previousRect;
  for (var attempt = 0; attempt < maxReadinessPumps; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
    final matches = control.evaluate().toList();
    if (matches.length == 1) {
      final field = matches.single.widget;
      final ready =
          field is LiveDropdownFormField<String> &&
          field.onChanged != null &&
          field.items
                  .where(
                    (item) =>
                        item.value == 'seed-asset-furnace-01' && item.enabled,
                  )
                  .length ==
              1;
      if (ready) {
        if (control.hitTestable().evaluate().isNotEmpty) {
          final rect = tester.getRect(control);
          if (rect == previousRect) {
            await select(tester, control, 'Furnace 01');
            return;
          }
          previousRect = rect;
        } else {
          previousRect = null;
          await Scrollable.ensureVisible(matches.single, alignment: 0.4);
        }
      } else {
        previousRect = null;
      }
      continue;
    }
    previousRect = null;
    final lists = currentRouteLists().hitTestable().evaluate().toList();
    if (lists.isNotEmpty) {
      // One real scroll gesture, then resolve the new tree on the next pass.
      final current = lists.last;
      await tester.drag(
        find.byElementPredicate((element) => identical(element, current)),
        const Offset(0, -220),
      );
    }
  }
  fail(
    'Required RED assignment did not expose a stable enabled Furnace 01 '
    'control with its exact governed asset identity.',
  );
}

// Server commitment can precede local adoption and the form's automatic pop.
// Observe the submitted route through disposal; never add a Back gesture while
// its response or reverse transition is still finishing.
Future<void> waitRequiredRedAutomaticReturn(
  WidgetTester tester,
  ModalRoute<dynamic> route, {
  int maxPumps = 450,
}) async {
  var completed = false;
  unawaited(route.completed.then<void>((_) => completed = true));
  for (var attempt = 0; attempt < maxPumps && !completed; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(
    completed,
    isTrue,
    reason:
        'The submitted or popped route must finish leaving before another navigation gesture.',
  );
}

Future<String> assignParent(WidgetTester tester, String version) async {
  final before = await FirebaseFirestore.instance
      .collection('job_executions')
      .where('remarks', isEqualTo: redIntent)
      .get(server);
  expect(
    before.docs,
    isEmpty,
    reason:
        'Fresh fixture only; failed attempts remain evidence and must not be silently reused.',
  );
  await home(tester);
  await tapControl(tester, find.text('Work'));
  await tapControl(tester, find.text('Assign Published'));
  await waitFor(
    tester,
    () =>
        find.byType(PublishedTemplateAssignmentScreen).evaluate().isNotEmpty &&
        find
            .byKey(const ValueKey('published-package-selector'))
            .evaluate()
            .isNotEmpty,
    'Actual assignment catalogue',
  );
  await select(
    tester,
    find.byKey(const ValueKey('published-package-selector')),
    'DEV required RED parent inspection',
  );
  await selectRequiredRedParentAsset(tester);
  await enter(tester, 'Active charge number', '71031');
  await enter(tester, 'Instructions / remarks', redIntent);
  final assignmentRoute = ModalRoute.of(
    tester.element(find.byType(PublishedTemplateAssignmentScreen)),
  );
  expect(assignmentRoute, isNotNull);
  await tapControl(tester, find.text('Assign Published Job'));
  await waitRequiredRedAutomaticReturn(tester, assignmentRoute!);
  final execution = await oneBy(tester, 'job_executions', 'remarks', redIntent);
  expect(execution.data()['templateVersionId'], version);
  expect(execution.data()['assetInstanceId'], 'seed-asset-furnace-01');
  await openJob(tester, execution.id);
  await tapControl(tester, find.text('Classify lanes'));
  await tapControl(tester, find.text('MECH - Mechanical'));
  await tapControl(tester, find.text('Finalise 1 lane'));
  await untilRecord(
    tester,
    'job_lanes/${execution.id}_mech_1',
    (row) => row['status'] == 'pending',
  );
  await laneAction(tester, 'mech', 'Acknowledge lane');
  await untilRecord(
    tester,
    'job_lanes/${execution.id}_mech_1',
    (row) => row['status'] == 'acknowledged',
  );
  return execution.id;
}

Future<void> submitAndAccept(
  WidgetTester tester,
  String execution,
  String worker,
  String field,
  String evidence,
) async {
  final module = await oneBy(
    tester,
    'job_modules',
    'jobExecutionFirestoreId',
    execution,
  );
  await actor(tester, worker);
  await openJob(tester, execution);
  Finder card() => find.byWidgetPredicate(
    (w) => w is JobModuleCard && w.module.firestoreId == module.id,
  );
  await tapControl(tester, card());
  await waitFor(
    tester,
    () => find.byType(JobModuleDetailScreen).evaluate().isNotEmpty,
    'Actual module form',
  );
  await enter(tester, '$field *', evidence);
  final save = find.text('Save Responses as Draft');
  await tapControl(
    tester,
    save.evaluate().isNotEmpty ? save : find.text('Save Structured Responses'),
  );
  await untilRecord(
    tester,
    'job_modules/${module.id}',
    (row) => (row['responsesJson'] as String? ?? '').contains(evidence),
  );
  await tapControl(tester, find.text('Submit'));
  await enter(
    tester,
    'Submission note',
    'Synthetic Android examination evidence.',
  );
  await tapControl(tester, find.text('Submit Module'));
  final submitted = await untilRecord(
    tester,
    'job_modules/${module.id}',
    (row) => row['status'] == 'submitted',
  );
  final workerUid = FirebaseAuth.instance.currentUser!.uid;
  expect(submitted['submittedByUid'], workerUid);
  await actor(tester, redSi);
  await openJob(tester, execution);
  await tapControl(tester, card());
  await tapControl(tester, find.text('Accept'));
  await enter(
    tester,
    'Acceptance note',
    'Independent SI examined the recorded work.',
  );
  await tapControl(tester, find.text('Accept Module'));
  final accepted = await untilRecord(
    tester,
    'job_modules/${module.id}',
    (row) => row['status'] == 'accepted',
  );
  expect(accepted['acceptedByUid'], FirebaseAuth.instance.currentUser!.uid);
  expect(accepted['acceptedByUid'], isNot(workerUid));
  expect(accepted['responsesJson'], contains(evidence));
}

Future<Map<String, dynamic>> finishJob(
  WidgetTester tester,
  String execution,
  String lane, {
  required bool requiredRed,
}) async {
  await openJob(tester, execution);
  await laneAction(tester, lane, 'Close lane');
  await tapControl(tester, find.text('Continue').last);
  await untilRecord(
    tester,
    'job_lanes/${execution}_${lane}_1',
    (row) => row['status'] == 'closed',
  );
  await tapControl(tester, find.text('Complete Job'));
  await waitFor(
    tester,
    () => find.byType(CompleteJobScreen).evaluate().isNotEmpty,
    'Final closure form',
  );
  await enter(
    tester,
    'Remarks (optional)',
    'Synthetic Android examined closure.',
  );
  final completionRoute = ModalRoute.of(
    tester.element(find.byType(CompleteJobScreen)),
  );
  expect(completionRoute, isNotNull);
  await tapControl(tester, find.text('Mark Job Completed'));
  if (requiredRed) {
    await waitFor(
      tester,
      () => find.text('Final maintenance check').evaluate().isNotEmpty,
      'Explicit required RED decision',
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('planned-red-required-yes')),
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('planned-red-preparation-yes')),
    );
    await tapControl(tester, find.text('Continue'));
  }
  final completed = await untilRecord(
    tester,
    'job_executions/$execution',
    (row) => row['isCompleted'] == true,
  );
  await waitRequiredRedAutomaticReturn(tester, completionRoute!);
  return completed;
}

Future<void> openPreparation(WidgetTester tester, String child) async {
  await openJob(tester, child);
  final panel = find.byType(PlannedJobWorkflowPanel);
  final tile = find.descendant(
    of: panel,
    matching: find.widgetWithText(
      ListTile,
      'Place furnace 1 on maintenance stand',
    ),
  );
  await showControl(tester, tile);
  await tapControl(tester, tile);
  await waitFor(
    tester,
    () => find.byType(ComplianceDetailScreen).evaluate().isNotEmpty,
    'Actual preparation compliance',
  );
}

Future<Map<String, dynamic>> relay(
  String action, [
  Map<String, Object?>? body,
]) async {
  final client = HttpClient()..findProxy = (_) => 'DIRECT';
  try {
    final uri = Uri(
      scheme: 'http',
      host: crm3EmulatorHost,
      port: 15002,
      path: '/__required_red/$action',
    );
    final request = body == null
        ? await client.getUrl(uri)
        : await client.postUrl(uri);
    request.followRedirects = false;
    if (body != null) writeRequiredRedRelayControlBody(request, body);
    final response = await request.close();
    expect(
      response.statusCode,
      200,
      reason: 'Exact demo-only transport control',
    );
    return jsonDecode(await utf8.decoder.bind(response).join())
        as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

// The fixed demo relay deliberately refuses unbounded/chunked control bodies.
void writeRequiredRedRelayControlBody(
  HttpClientRequest request,
  Map<String, Object?> body,
) {
  final bytes = utf8.encode(jsonEncode(body));
  request.headers.contentType = ContentType.json;
  request.contentLength = bytes.length;
  request.add(bytes);
}

Future<File> evidenceFile() async {
  final directory = await getApplicationSupportDirectory();
  return File('${directory.path}/required-red-prepared.json');
}

Future<void> syncThroughUi(WidgetTester tester) async {
  await home(tester);
  await openMore(tester, 'Sync health');
  final sync = find.widgetWithText(FilledButton, 'Sync now');
  await showControl(tester, sync);
  await waitFor(
    tester,
    () =>
        sync.evaluate().isNotEmpty &&
        tester.widget<FilledButton>(sync).onPressed != null,
    'Normal manual sync becomes available',
  );
  await tapControl(tester, sync);
  await tester.binding.handlePopRoute();
  await tester.pump(const Duration(milliseconds: 300));
}
