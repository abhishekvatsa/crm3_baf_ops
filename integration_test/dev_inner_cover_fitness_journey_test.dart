// Actual DEV UI -> authenticated local Functions -> server readback -> Plant.
// Run only on a separate emulator with the isolated CI namespace/ports. Setup
// creates the fresh catalogue and registers/accepts/installs the cover through
// lifecycle commands; no stuck-up issue, cause or release may be pre-seeded.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/presentation/furnace_stuckup_board.dart';
import 'package:crm3_baf_ops/features/assets/presentation/widgets/inner_cover_stock_panel.dart';
import 'package:crm3_baf_ops/features/assets/providers/furnace_stuckup_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/furnace_stuckup_case.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_form.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart'
    show field, keyedPrefix, waitFor, goBack;
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
const _baseId = 'dev-ic-fitness-base-101';
const _furnaceId = 'seed-asset-furnace-01';
const _coverId = '515a060f-400d-568e-bad3-b03f1a287c95';
const _serial = 'DEV-IC-FITNESS-31';
const _operations = 'dev.operations@example.invalid';
const _si = 'dev.usability-si@example.invalid';
const _charge = 77131;
// Explicit continuation of one previously UI-created, confirmed active DEV
// case. Empty means the original fresh, complete issue/cause/release journey.
const _resumeCaseId = String.fromEnvironment('CRM_DEV_IC_RESUME_CASE_ID');
const _expectedSiUid = String.fromEnvironment('CRM_DEV_IC_EXPECTED_SI_UID');
const _resumeStage = String.fromEnvironment(
  'CRM_DEV_IC_RESUME_STAGE',
  defaultValue: 'confirmed',
);
const _expectedReleasedAt = String.fromEnvironment(
  'CRM_DEV_IC_EXPECTED_RELEASED_AT',
);
const _readbackOnly = _resumeStage == 'released';
const _description = 'DEV isolated IC fitness: stuck Furnace on $_serial';

void _verifyEnvironment() {
  expect(crm3UseEmulators, isTrue);
  expect(crm3DemoProjectId, 'demo-crm3-ci-journeys');
  expect(crm3EmulatorHost, '10.0.2.2');
  expect(crm3AuthEmulatorPort, 19099);
  expect(crm3FirestoreEmulatorPort, 18080);
  expect(crm3FunctionsEmulatorPort, 15001);
  expect(_resumeStage, anyOf('confirmed', 'released'));
  if (_readbackOnly) {
    expect(_resumeCaseId, isNotEmpty);
    expect(_expectedReleasedAt, isNotEmpty);
  }
}

Object? _jsonValue(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': _jsonValue(entry.value),
    };
  }
  if (value is Iterable) return value.map(_jsonValue).toList();
  return value;
}

Map<String, Object?> _formObservation(WidgetTester tester) => {
  'formPresent': find.byType(MaintenanceForm).evaluate().isNotEmpty,
  'mountedText': [
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      if (text.data != null) text.data,
  ],
  'mountedFields': [
    for (final text in tester.widgetList<TextField>(find.byType(TextField)))
      {
        'label': text.decoration?.labelText,
        'text': text.controller?.text,
        'error': text.decoration?.errorText,
      },
  ],
  'validationErrors': [
    for (final element
        in find.byWidgetPredicate((widget) => widget is FormField).evaluate())
      if ((element as StatefulElement).state case FormFieldState state)
        if (state.errorText != null)
          {'key': '${element.widget.key}', 'error': state.errorText},
  ],
  'snackbars': [
    for (final text in tester.widgetList<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
    ))
      text.data,
  ],
};

Future<void> _home(WidgetTester tester) async {
  for (
    var depth = 0;
    depth < 8 && find.byType(HomeScreen).evaluate().isEmpty;
    depth++
  ) {
    await goBack(tester);
  }
  expect(find.byType(HomeScreen), findsOneWidget);
  await tapControl(tester, find.text('Home'));
}

Future<Map<String, Map<String, dynamic>>> _coverCases() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('furnace_stuckup_cases')
      .where('innerCoverId', isEqualTo: _coverId)
      .get(_server);
  return {for (final doc in snapshot.docs) doc.id: doc.data()};
}

Future<Map<String, dynamic>> _createdCase(WidgetTester tester) async {
  final until = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(until)) {
    final cases = await _coverCases();
    if (cases.isNotEmpty) {
      expect(cases, hasLength(1));
      return cases.values.single;
    }
    await tester.pump(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw TestFailure(
    'The real issue submission did not create its server case.',
  );
}

Finder _caseCard(String id) => find.byWidgetPredicate((widget) {
  if (widget.runtimeType.toString() != '_StuckupCaseCard') return false;
  return (widget as dynamic).record.id == id;
});

Future<void> _caseAction(
  WidgetTester tester,
  Map<String, dynamic> expected,
  String action, {
  required String actorEmail,
  required Directory destination,
  required Future<void> Function(String) capture,
}) async {
  final id = expected['caseId'] as String;
  final board = find.byType(FurnaceStuckupBoard);
  final container = ProviderScope.containerOf(tester.element(board));
  // Keep the qualified stream alive while the ordinary board uses its own
  // legacy list. Do not substitute data or invalidate either provider here.
  final subscription = container.listen(
    furnaceStuckupCaseBatchProvider,
    (_, _) {},
  );
  final control = find.descendant(
    of: _caseCard(id),
    matching: find.text(action),
  );
  var retriedVisibleError = false;
  Future<void> observe(String suffix) async {
    final actor = container.read(currentAppUserProvider);
    final cases = container.read(furnaceStuckupCasesProvider);
    final qualified = container.read(furnaceStuckupCaseBatchProvider);
    final observation = {
      'action': action,
      'expectedCase': expected,
      'authUid': FirebaseAuth.instance.currentUser?.uid,
      'authEmail': FirebaseAuth.instance.currentUser?.email,
      'actorLoading': actor.isLoading,
      'actorError': '${actor.error}',
      'actorUid': actor.asData?.value?.uid,
      'actorEmail': actor.asData?.value?.email,
      'actorRoles': actor.asData?.value?.roles.map((r) => r.name).toList(),
      'casesLoading': cases.isLoading,
      'casesError': '${cases.error}',
      'qualifiedError': '${qualified.error}',
      'serverConfirmed': qualified.asData?.value.isServerConfirmed,
      'complete': qualified.asData?.value.isComplete,
      'serverCase': await read('furnace_stuckup_cases/$id'),
      'screen': _formObservation(tester),
      'ordinaryVisibleRetryUsed': retriedVisibleError,
    };
    final name = 'case-${action.replaceAll(' ', '-')}-$suffix';
    await File('${destination.path}/$name.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(_jsonValue(observation)),
    );
    await capture(name);
  }

  try {
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    var ready = false;
    while (!ready && DateTime.now().isBefore(deadline)) {
      final actorState = container.read(currentAppUserProvider);
      final actor = actorState.asData?.value;
      final actorReady =
          !actorState.isLoading &&
          !actorState.hasError &&
          actor?.uid == FirebaseAuth.instance.currentUser?.uid &&
          actor?.email == actorEmail &&
          actor?.isApproved == true &&
          FirebaseAuth.instance.currentUser?.email == actorEmail &&
          (action == 'Confirm removal'
              ? actor?.canReleaseFurnaceStuckup == true
              : actor?.canAdjudicateFurnaceStuckup == true);
      final retry = find.descendant(of: board, matching: find.text('Retry'));
      if (actorReady &&
          !retriedVisibleError &&
          container.read(furnaceStuckupCasesProvider).hasError &&
          retry.evaluate().length == 1) {
        await observe('before-visible-retry');
        await tapControl(tester, retry);
        retriedVisibleError = true;
      }
      final batch = container
          .read(furnaceStuckupCaseBatchProvider)
          .asData
          ?.value;
      final rows = batch?.records.where((r) => r.id == id).toList();
      final exactFeed =
          batch?.isServerConfirmed == true &&
          batch?.isComplete == true &&
          rows?.length == 1 &&
          rows!.single.version == expected['version'] &&
          rows.single.ticketId == expected['ticketId'] &&
          rows.single.innerCoverId == _coverId &&
          rows.single.innerCoverSerialNumber == _serial &&
          rows.single.baseAssetInstanceId == _baseId &&
          rows.single.furnaceAssetInstanceId == _furnaceId &&
          rows.single.chargeNoAtEvent == _charge &&
          rows.single.obstructionStatus.name == expected['obstructionStatus'] &&
          rows.single.adjudicationStatus.name ==
              expected['adjudicationStatus'] &&
          rows.single.confirmedCause?.name == expected['confirmedCause'];
      if (actorReady && exactFeed && _caseCard(id).evaluate().length == 1) {
        final dynamic card = tester.widget(_caseCard(id));
        final cardReady =
            card.record.version == expected['version'] &&
            card.busy == false &&
            (action == 'Confirm removal'
                    ? card.canRelease
                    : card.canAdjudicate) ==
                true;
        if (cardReady && control.evaluate().length == 1) {
          // The board is a SingleChildScrollView; ensureVisible also handles
          // it without requiring a ListView or invoking a callback directly.
          await Scrollable.ensureVisible(
            tester.element(control),
            alignment: 0.4,
          );
          await tester.pump(const Duration(milliseconds: 350));
          final button = find.ancestor(
            of: control,
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          );
          ready =
              button.evaluate().length == 1 &&
              tester.widget<ButtonStyleButton>(button).onPressed != null &&
              control.hitTestable().evaluate().length == 1;
        }
      }
      if (!ready) {
        await tester.pump(const Duration(milliseconds: 200));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    if (!ready) {
      throw TestFailure(
        'Exact actor, server case and enabled $action did not become ready.',
      );
    }
    await observe('ready');
    expect(
      await read('furnace_stuckup_cases/$id'),
      expected,
      reason: 'The server case must remain unchanged before the UI action.',
    );
    await tapControl(tester, control);
  } catch (_) {
    await observe('failure');
    rethrow;
  } finally {
    subscription.close();
  }
}

Future<void> _openCases(WidgetTester tester) async {
  await _home(tester);
  await openMore(tester, 'Furnace stuck-up');
  await waitFor(
    tester,
    () => find.byType(FurnaceStuckupBoard).evaluate().isNotEmpty,
    'The ordinary stuck-up board must open.',
  );
}

DateTime _observedTime(Object? value) => switch (value) {
  Timestamp value => value.toDate().toUtc(),
  DateTime value => value.toUtc(),
  String value => DateTime.parse(value).toUtc(),
  _ => throw TestFailure('A server evidence time is missing or malformed.'),
};

Future<PlantAssetOverview> _openPlant(
  WidgetTester tester, {
  Map<String, dynamic>? releasedCase,
  Map<String, dynamic>? expectedDeclaration,
  Map<String, dynamic>? expectedTicket,
  Map<String, Map<String, dynamic>>? expectedProjections,
}) async {
  await _home(tester);
  await tapControl(
    tester,
    find
        .descendant(
          of: find.byType(PlantOverviewPanel),
          matching: find.textContaining('Plant condition'),
        )
        .first,
  );
  await waitFor(
    tester,
    () => find.byType(AssetConditionBoard).evaluate().isNotEmpty,
    'The ordinary Plant condition board must open.',
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AssetConditionBoard)),
    listen: false,
  );
  await waitFor(
    tester,
    () {
      final overview = container.read(plantAssetOverviewProvider).asData?.value;
      final stock = overview?.innerCoverStock;
      if (releasedCase != null) {
        final cases = container
            .read(furnaceStuckupCaseBatchProvider)
            .asData
            ?.value;
        final matchingCases = cases?.records
            .where((row) => row.id == releasedCase['caseId'])
            .toList();
        if (cases?.isServerConfirmed != true ||
            cases?.isComplete != true ||
            matchingCases?.length != 1 ||
            matchingCases!.single.version != releasedCase['version'] ||
            matchingCases.single.isActive ||
            matchingCases.single.confirmedCause?.name !=
                releasedCase['confirmedCause']) {
          return false;
        }
        final declarations = container
            .read(innerCoverBulgeDeclarationBatchProvider)
            .asData
            ?.value;
        final matchingDeclarations = declarations?.records
            .where((row) => row.id == expectedDeclaration!['declarationId'])
            .toList();
        // This read model deliberately exposes no latestCaseId/version. Bind
        // the exact server declaration through all available identity/time
        // fields; the raw server latestCaseId is asserted separately below.
        if (declarations?.isServerConfirmed != true ||
            declarations?.isComplete != true ||
            matchingDeclarations?.length != 1 ||
            matchingDeclarations!.single.assetId != _coverId ||
            matchingDeclarations.single.assetSerialNumber != _serial ||
            matchingDeclarations.single.evidenceCount !=
                expectedDeclaration!['evidenceCount'] ||
            !matchingDeclarations.single.latestEvidenceAt.isAtSameMomentAs(
              _observedTime(expectedDeclaration['latestEvidenceAt']),
            )) {
          return false;
        }
        final tickets = container
            .read(plantTicketEvidenceProvider)
            .asData
            ?.value;
        final matchingTickets = tickets?.rows
            .where((row) => row.firestoreId == releasedCase['ticketId'])
            .toList();
        if (tickets?.fromServer != true ||
            tickets?.complete != true ||
            matchingTickets?.length != 1 ||
            matchingTickets!.single.version != expectedTicket!['version'] ||
            !matchingTickets.single.canStillAffectPlantCondition) {
          return false;
        }
        final projections = container
            .read(plantAvailabilityEvidenceProvider)
            .asData
            ?.value;
        if (projections?.fromServer != true || projections?.complete != true) {
          return false;
        }
        for (final entry in expectedProjections!.entries) {
          final matching = projections!.rows
              .where((row) => row.assetInstanceId == entry.key)
              .toList();
          if (matching.length != 1 ||
              matching.single.version != entry.value['version'] ||
              matching.single.state.name != entry.value['availabilityState'] ||
              !matching.single.updatedAt.isAtSameMomentAs(
                _observedTime(entry.value['updatedAt']),
              )) {
            return false;
          }
        }
      }
      return overview?.innerCovers.any((row) => row.profile.id == _coverId) ==
              true &&
          stock?.inventoryConfirmed == true &&
          stock?.linkageConfirmed == true &&
          stock?.bulgeEvidenceConfirmed == true &&
          stock?.dependencyEvidenceConfirmed == true;
    },
    'Actual server-confirmed stock/link/condition/work feeds must settle.',
  );
  return container.read(plantAssetOverviewProvider).requireValue;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('obstruction release does not certify Inner Cover fitness', (
    tester,
  ) async {
    _verifyEnvironment();
    final flutterError = FlutterError.onError;
    final platformError = PlatformDispatcher.instance.onError;
    try {
      await tester.runAsync(app.startCrmBafApp);
    } finally {
      FlutterError.onError = flutterError;
      PlatformDispatcher.instance.onError = platformError;
    }
    expect(Firebase.app().options.projectId, 'demo-crm3-ci-journeys');
    await waitFor(
      tester,
      () =>
          find.text('Sign in with Google').evaluate().isNotEmpty ||
          find.byType(HomeScreen).evaluate().isNotEmpty,
      'Normal access gate',
    );
    if (find.text('Sign in with Google').evaluate().isNotEmpty) {
      await tapControl(tester, find.text('Sign in with Google'));
    }
    await waitFor(
      tester,
      () => find.byType(HomeScreen).evaluate().isNotEmpty,
      'Approved DEV Home',
    );
    if (FirebaseAuth.instance.currentUser?.email != _operations) {
      await switchActor(tester, _operations);
    }
    final operationsUid = FirebaseAuth.instance.currentUser!.uid;
    expect((await read('users/$operationsUid'))['roles'], ['operations']);
    final classes = await FirebaseFirestore.instance
        .collection('asset_classes')
        .get(_server);
    for (final kind in ['base', 'furnace', 'innerCover']) {
      expect(
        classes.docs.where(
          (row) =>
              row.data()['legacyAssetTypeKey'] == kind &&
              row.data()['status'] == 'active',
        ),
        hasLength(1),
        reason:
            'No ambiguous legacy class or interactive-preview fixture is allowed.',
      );
    }
    final profileBefore = await read('inner_cover_profiles/$_coverId');
    final assignmentBefore = await read(
      'base_inner_cover_assignments/$_baseId',
    );
    expect(profileBefore['serialNumber'], _serial);
    expect(profileBefore['lifecycleState'], 'installed');
    expect(profileBefore['currentBaseAssetInstanceId'], _baseId);
    expect(assignmentBefore['innerCoverId'], _coverId);
    if (_resumeCaseId.isEmpty) {
      expect(
        await _coverCases(),
        isEmpty,
        reason:
            'Issue, cause and release must all be created by this UI journey.',
      );
      expect(
        (await FirebaseFirestore.instance
                .doc(
                  'asset_condition_declarations/inner_cover_bulged_$_coverId',
                )
                .get(_server))
            .exists,
        isFalse,
      );
    }

    final destination = Directory(
      '${(await getApplicationSupportDirectory()).path}/'
      'ic_fitness_${DateTime.now().microsecondsSinceEpoch}',
    );
    await destination.create(recursive: true);
    await binding.convertFlutterSurfaceToImage();
    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      final bytes = await binding.takeScreenshot(name);
      await File('${destination.path}/$name.png').writeAsBytes(bytes);
      binding.reportData?.remove('screenshots');
      debugPrint('DEV_IC_FITNESS_SCREEN ${destination.path}/$name.png');
    }

    late final String caseId;
    late final String ticketId;
    late final Map<String, dynamic> ticketBefore;
    late final Map<String, dynamic> confirmed;
    final readbackBefore = <String, Map<String, dynamic>>{};
    if (_resumeCaseId.isNotEmpty) {
      expect(
        _resumeCaseId,
        matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')),
      );
      final cases = await _coverCases();
      expect(cases.keys.toList(), [_resumeCaseId]);
      confirmed = cases[_resumeCaseId]!;
      caseId = _resumeCaseId;
      ticketId = _resumeCaseId;
      for (final expected in {
        'caseId': caseId,
        'ticketId': ticketId,
        'schemaVersion': 1,
        'version': _readbackOnly ? 3 : 2,
        'obstructionStatus': _readbackOnly ? 'released' : 'active',
        'adjudicationStatus': 'confirmed',
        'confirmedCause': 'innerCoverBulging',
        'innerCoverId': _coverId,
        'innerCoverSerialNumber': _serial,
        'baseAssetInstanceId': _baseId,
        'furnaceAssetInstanceId': _furnaceId,
        'chargeNoAtEvent': _charge,
        'reportedByUid': operationsUid,
        'innerCoverLinkageId': assignmentBefore['linkageId'],
        'innerCoverAssignmentVersion': assignmentBefore['version'],
        if (!_readbackOnly) 'releasedAt': null,
        'releasedByUid': _readbackOnly ? operationsUid : null,
        'releaseNotes': _readbackOnly
            ? 'DEV simulation: Furnace separated only; IC not repaired, assessed fit or reaccepted.'
            : null,
      }.entries) {
        expect(
          confirmed[expected.key],
          expected.value,
          reason: 'Resume ${expected.key}',
        );
      }
      expect(profileBefore['version'], 3);
      expect(profileBefore['currentLinkageId'], assignmentBefore['linkageId']);
      expect(assignmentBefore['version'], 1);
      expect(
        _observedTime(
          profileBefore['acceptedAt'],
        ).isBefore(_observedTime(confirmed['reportedAt'])),
        isTrue,
      );
      // Operations cannot read another user's role record. The private runner
      // must supply the UID from the retained, verified SI session that made
      // this UI decision; the fresh journey still checks its own SI roles.
      expect(
        _expectedSiUid,
        isNotEmpty,
        reason: 'Resume requires the previously verified SI session UID.',
      );
      expect(_expectedSiUid, isNot(operationsUid));
      expect(confirmed['adjudicatedByUid'], _expectedSiUid);
      ticketBefore = await read('maintenance_records/$ticketId');
      for (final expected in {
        'firestoreId': ticketId,
        'version': 1,
        'status': 'open',
        'isResolved': false,
        'isDeleted': false,
        'classification': 'furnaceStuckup',
        'description': _description,
        'chargeNoAtEvent': _charge,
        'stuckupBaseAssetRefJson': confirmed['baseAssetRefJson'],
        'assetHierarchyRefJson': confirmed['furnaceAssetRefJson'],
      }.entries) {
        expect(
          ticketBefore[expected.key],
          expected.value,
          reason: 'Resume ticket ${expected.key}',
        );
      }
      final baseReference =
          jsonDecode(confirmed['baseAssetRefJson'] as String) as Map;
      final association = baseReference['innerCoverAssociation'] as Map;
      expect(baseReference['assetInstanceId'], _baseId);
      expect(association['innerCoverId'], _coverId);
      expect(association['innerCoverSerialNumber'], _serial);
      expect(association['linkageId'], assignmentBefore['linkageId']);
      expect(association['assignmentVersion'], assignmentBefore['version']);
      expect(
        _observedTime(association['eventAt']),
        _observedTime(confirmed['reportedAt']),
      );
      final declaration = await read(
        'asset_condition_declarations/inner_cover_bulged_$_coverId',
      );
      expect(declaration['state'], 'confirmed');
      expect(declaration['latestCaseId'], caseId);
      expect(declaration['evidenceCount'], 1);
      if (_readbackOnly) {
        expect(
          _observedTime(confirmed['releasedAt']),
          DateTime.parse(_expectedReleasedAt).toUtc(),
        );
        readbackBefore.addAll({
          'furnace_stuckup_cases/$caseId': confirmed,
          'maintenance_records/$ticketId': ticketBefore,
          'asset_condition_declarations/inner_cover_bulged_$_coverId':
              declaration,
          'inner_cover_profiles/$_coverId': profileBefore,
          'base_inner_cover_assignments/$_baseId': assignmentBefore,
        });
        for (final assetId in [_baseId, _furnaceId]) {
          for (final path in [
            'asset_availability_constraints/${caseId}_$assetId',
            'asset_availability_current/$assetId',
          ]) {
            readbackBefore[path] = await read(path);
          }
        }
      }
      await File(
        '${destination.path}/00-resume-preconditions.json',
      ).writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          _jsonValue({
            'mode': _readbackOnly
                ? 'read-only-existing-ui-released-case'
                : 'resume-existing-ui-confirmed-case',
            'case': confirmed,
            'ticket': ticketBefore,
            'declaration': declaration,
            'profile': profileBefore,
            'assignment': assignmentBefore,
            'newIssueOrAdjudicationPerformed': false,
            'businessMutationAllowed': !_readbackOnly,
            if (_readbackOnly) 'exactServerBefore': readbackBefore,
          }),
        ),
      );
    } else {
      final initialOverview = await _openPlant(tester);
      final initialCover = initialOverview.innerCovers.singleWhere(
        (c) => c.profile.id == _coverId,
      );
      expect(
        initialCover.isAvailable,
        isTrue,
        reason:
            'Fresh accepted/installed cover must start with verified clear evidence.',
      );
      await _home(tester);
      await openMore(tester, 'Raise issue');
      await waitFor(
        tester,
        () => find.byType(MaintenanceForm).evaluate().isNotEmpty,
        'Ordinary issue form',
      );
      await tapControl(tester, find.text('Not suspected'));
      await tapControl(tester, find.text('Furnace stuck-up'));
      await select(tester, keyedPrefix('stuckup-base-'), 'Base 101');
      await tapControl(tester, find.text('Yes'));
      await select(tester, keyedPrefix('stuckup-furnace-'), 'Furnace 01');
      await select(
        tester,
        find.byType(DropdownButtonFormField<FurnaceStuckupCause>),
        'Inner Cover bulging',
      );
      const description = _description;
      await enter(tester, 'Fault description', description);
      final descriptionController = tester
          .widget<TextField>(field('Fault description'))
          .controller!;
      expect(descriptionController.text, description);
      await enter(tester, 'Charge number', '$_charge');
      final chargeController = tester
          .widget<TextField>(field('Charge number'))
          .controller!;
      expect(chargeController.text, '$_charge');
      await capture('01-issue-before-submit');
      expect(descriptionController.text, description);
      expect(chargeController.text, '$_charge');
      await tapControl(tester, find.text('Submit Issue'));
      final postTap = _formObservation(tester);
      await File(
        '${destination.path}/01-submit-feedback.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(postTap));
      debugPrint('DEV_IC_FITNESS_SUBMIT_FEEDBACK ${jsonEncode(postTap)}');
      await capture('01-submit-feedback');
      final rejectionMessages = (postTap['snackbars']! as List)
          .whereType<String>()
          .where(
            (message) =>
                const {
                  'Choose an active governed asset before submitting.',
                  'Choose the Base carrying the affected Inner Cover.',
                  'Confirm that the currently linked Inner Cover is physically installed on this Base.',
                  'Correct the Base–Inner Cover pairing before raising this stuck-up.',
                  'Your issue details changed while they were being verified. Review them and submit again.',
                }.contains(message) ||
                message.startsWith('Failed to submit:'),
          )
          .toList();
      if (postTap['formPresent'] == true &&
          (rejectionMessages.isNotEmpty ||
              (postTap['validationErrors']! as List).isNotEmpty)) {
        fail('Real form submission was rejected: ${jsonEncode(postTap)}');
      }
      try {
        await waitFor(
          tester,
          () => find.byType(MaintenanceForm).evaluate().isEmpty,
          'Issue form must leave only after ordinary submission.',
        );
      } catch (_) {
        final failure = _formObservation(tester);
        await File(
          '${destination.path}/01-submit-failure.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(failure));
        debugPrint('DEV_IC_FITNESS_SUBMIT_FAILURE ${jsonEncode(failure)}');
        await capture('01-submit-failure');
        rethrow;
      }
      final created = await _createdCase(tester);
      caseId = created['caseId'] as String;
      ticketId = created['ticketId'] as String;
      expect(created['obstructionStatus'], 'active');
      expect(created['adjudicationStatus'], 'pending');
      expect(created['innerCoverId'], _coverId);
      expect(created['innerCoverSerialNumber'], _serial);
      expect(created['baseAssetInstanceId'], _baseId);
      expect(created['furnaceAssetInstanceId'], _furnaceId);
      expect(created['reportedByUid'], operationsUid);
      ticketBefore = await read('maintenance_records/$ticketId');
      expect(ticketBefore['description'], description);
      expect(ticketBefore['status'], 'open');
      expect(ticketBefore['classification'], 'furnaceStuckup');

      await _home(tester);
      await switchActor(tester, _si);
      final siUid = FirebaseAuth.instance.currentUser!.uid;
      expect((await read('users/$siUid'))['roles'], ['si']);
      await _openCases(tester);
      await _caseAction(
        tester,
        created,
        'Adjudicate cause',
        actorEmail: _si,
        destination: destination,
        capture: capture,
      );
      await select(
        tester,
        find.byType(DropdownButtonFormField<FurnaceStuckupCause>),
        'Inner Cover bulging',
      );
      await enter(
        tester,
        'Inspection evidence',
        'DEV simulation: current bulging confirmed; no repair or satisfactory reassessment.',
      );
      await tapControl(tester, find.text('Record decision'));
      confirmed = await awaitRecord(
        tester,
        'furnace_stuckup_cases/$caseId',
        (row) => row['adjudicationStatus'] == 'confirmed',
      );
      expect(confirmed['confirmedCause'], 'innerCoverBulging');
      expect(confirmed['adjudicatedByUid'], siUid);
      expect(confirmed['obstructionStatus'], 'active');
      await capture('02-cause-confirmed');
    }

    await _home(tester);
    if (FirebaseAuth.instance.currentUser?.email != _operations) {
      await switchActor(tester, _operations);
    }
    late final Map<String, dynamic> released;
    if (_readbackOnly) {
      released = confirmed;
    } else {
      await _openCases(tester);
      await _caseAction(
        tester,
        confirmed,
        'Confirm removal',
        actorEmail: _operations,
        destination: destination,
        capture: capture,
      );
      await enter(
        tester,
        'Release evidence',
        'DEV simulation: Furnace separated only; IC not repaired, assessed fit or reaccepted.',
      );
      await tapControl(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Confirm removal'),
        ),
      );
      released = await awaitRecord(
        tester,
        'furnace_stuckup_cases/$caseId',
        (row) => row['obstructionStatus'] == 'released',
      );
    }
    expect(released['confirmedCause'], 'innerCoverBulging');
    expect(released['adjudicationStatus'], 'confirmed');
    expect(released['releasedByUid'], operationsUid);
    expect(
      released['version'],
      _readbackOnly ? 3 : (confirmed['version'] as num) + 1,
    );
    final ticketAfter = await read('maintenance_records/$ticketId');
    final declaration = await read(
      'asset_condition_declarations/inner_cover_bulged_$_coverId',
    );
    final profileAfter = await read('inner_cover_profiles/$_coverId');
    final assignmentAfter = await read('base_inner_cover_assignments/$_baseId');
    expect(ticketAfter['status'], 'open');
    expect(ticketAfter['classification'], 'furnaceStuckup');
    expect(ticketAfter['version'], ticketBefore['version']);
    expect(declaration['state'], 'confirmed');
    expect(declaration['latestCaseId'], caseId);
    expect(
      profileAfter,
      profileBefore,
      reason: 'Release must not reaccept or rewrite the IC lifecycle.',
    );
    expect(
      assignmentAfter,
      assignmentBefore,
      reason: 'Release must not rewrite installation identity.',
    );
    final releasedProjections = <String, Map<String, dynamic>>{};
    for (final assetId in [_baseId, _furnaceId]) {
      expect(
        (await read(
          'asset_availability_constraints/${caseId}_$assetId',
        ))['status'],
        'released',
      );
      final projection = await read('asset_availability_current/$assetId');
      expect(projection['availabilityState'], 'clear');
      releasedProjections[assetId] = projection;
    }
    if (!_readbackOnly) {
      await tapControl(tester, find.widgetWithText(ChoiceChip, 'History'));
      await showControl(tester, _caseCard(caseId));
      await capture('03-obstruction-released-issue-retained');
    }

    final overview = await _openPlant(
      tester,
      releasedCase: released,
      expectedDeclaration: declaration,
      expectedTicket: ticketAfter,
      expectedProjections: releasedProjections,
    );
    final cover = overview.innerCovers.singleWhere(
      (c) => c.profile.id == _coverId,
    );
    final stock = overview.innerCoverStock!;
    final stockRow = stock.rows.singleWhere((r) => r.profile.id == _coverId);
    final base = overview.assets.singleWhere((a) => a.asset.id == _baseId);
    const baseAssessmentLabel =
        'Linked Inner Cover $_serial: fitness assessment needed';
    final visibleBaseAssessment = find.descendant(
      of: find.byType(AssetConditionBoard),
      matching: find.text(baseAssessmentLabel),
    );
    await showControl(tester, visibleBaseAssessment);
    expect(
      visibleBaseAssessment.hitTestable(),
      findsOneWidget,
      reason:
          'The actual Base row must visibly explain its linked-cover fitness hold.',
    );
    await capture('03b-base-fitness-assessment-visible');
    await showControl(tester, find.byType(InnerCoverStockPanel));
    await capture('04-plant-stock-after-release');
    await showControl(
      tester,
      find.byKey(const ValueKey('plant-inner-cover-$_coverId')),
    );
    await capture('05-plant-serial-after-release');
    final readbackAfter = <String, Map<String, dynamic>>{};
    if (_readbackOnly) {
      for (final entry in readbackBefore.entries) {
        readbackAfter[entry.key] = await read(entry.key);
        expect(
          readbackAfter[entry.key],
          entry.value,
          reason:
              'Read-only Plant inspection must preserve exact ${entry.key}.',
        );
      }
    }
    final result = {
      'project': crm3DemoProjectId,
      'journeyMode': _resumeCaseId.isEmpty
          ? 'fresh-whole-journey'
          : _readbackOnly
          ? 'read-only-existing-ui-released-case'
          : 'resume-existing-ui-confirmed-case',
      'businessMutationPerformedThisRun': !_readbackOnly,
      if (_readbackOnly) 'exactServerBefore': readbackBefore,
      if (_readbackOnly) 'exactServerAfter': readbackAfter,
      'case': released,
      'ticket': ticketAfter,
      'declaration': declaration,
      'profile': profileAfter,
      'assignment': assignmentAfter,
      'releasedProjections': releasedProjections,
      'plantExactServerEvidenceMatched': true,
      'coverAvailable': cover.isAvailable,
      'coverCondition': cover.conditionSummary,
      'coverUnfit': cover.isUnfit,
      'coverUnderMaintenance': cover.isUnderMaintenance,
      'coverIssueUnavailable': cover.isIssueUnavailable,
      'currentAssessmentRequired': stockRow.needsCurrentAssessment,
      'stockDisposition': stockRow.disposition.name,
      'baseAvailable': base.isAvailable,
      'baseUnderMaintenance': base.isUnderMaintenance,
      'baseEvidenceWarnings': base.evidenceWarnings,
      'baseAssessmentLabel': baseAssessmentLabel,
      'baseAssessmentLabelVerifiedVisible': true,
      'physicalDeviceEvidence': false,
      'assessmentOrReacceptancePerformed': false,
    };
    await File(
      '${destination.path}/server-and-plant-readback.json',
    ).writeAsString(
      const JsonEncoder.withIndent('  ').convert(_jsonValue(result)),
    );
    debugPrint(
      'DEV_IC_FITNESS_READBACK ${destination.path}/server-and-plant-readback.json',
    );
    // Save actual state before assertions, including a truthful red if release
    // alone currently creates an apparent all-clear. Do not weaken this to
    // "history exists" or treat missing/loading evidence as a positive proof.
    expect(
      cover.isAvailable,
      isFalse,
      reason:
          'Furnace separation alone cannot certify a confirmed-bulged IC fit.',
    );
    expect(
      cover.isUnderMaintenance ||
          cover.isUnfit ||
          cover.isIssueUnavailable ||
          stockRow.needsCurrentAssessment,
      isTrue,
      reason:
          'A positive retained restriction or explicit reassessment need must explain the hold.',
    );
    expect(
      stockRow.needsCurrentAssessment,
      isTrue,
      reason:
          'The exact unresolved confirmed-bulging concern must require current assessment after physical separation.',
    );
    expect(
      base.isAvailable,
      isFalse,
      reason:
          'A Base must not become available while its installed IC still needs disposition.',
    );
    expect(
      base.evidenceWarnings,
      contains(
        'Linked Inner Cover $_serial: current fitness assessment required for an unresolved confirmed-bulging concern.',
      ),
      reason:
          'The Base hold must include this exact linked-cover assessment concern, not only unrelated incomplete evidence.',
    );
    expect(tester.takeException(), isNull);
    debugPrint('DEV_IC_FITNESS_PASS $caseId');
  });
}
