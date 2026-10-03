// Actual withdrawal and explicit assessment recovery through ordinary DEV forms.
// Fresh CI follows the issue/cause/release journey; explicit resume remains read-only.
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
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/features/admin/presentation/admin_data_browser.dart';
import 'package:crm3_baf_ops/features/assets/presentation/furnace_stuckup_board.dart';
import 'package:crm3_baf_ops/features/assets/presentation/inner_cover_lifecycle_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart' show waitFor;
import 'support/required_red_journey.dart' show returnRequiredRedHome;
import 'dev_issue_quality_journey_test.dart'
    show tapControl, showControl, read, enter, openMore, awaitRecord;

const _requestedCase = String.fromEnvironment('CRM_DEV_WITHDRAWN_CASE_ID');
const _affected = '515a060f-400d-568e-bad3-b03f1a287c95';
const _unrelated = 'f43b7a65-bb12-4781-861c-c52853b93e68';
const _base1 = 'dev-ic-fitness-base-101';
const _base2 = 'dev-ic-fitness-base-102';
const _resume = bool.fromEnvironment('CRM_DEV_WITHDRAWN_READ_ONLY');

Object? _json(Object? v) {
  if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is Map) return {for (final e in v.entries) '${e.key}': _json(e.value)};
  if (v is Iterable) return v.map(_json).toList();
  return v;
}

Map<String, Object?> _state(PlantAssetOverview model) => {
  'dependencyEvidenceConfirmed':
      model.innerCoverStock?.dependencyEvidenceConfirmed,
  'covers': [
    for (final c in model.innerCovers)
      {
        'id': c.profile.id,
        'available': c.isAvailable,
        'condition': c.conditionSummary,
        'complete': c.dependency?.complete,
        'assessment': c.dependency?.needsCurrentAssessment,
      },
  ],
  'bases': [
    for (final b in model.assets.where(
      (b) => [_base1, _base2].contains(b.asset.id),
    ))
      {
        'id': b.asset.id,
        'available': b.isAvailable,
        'warnings': b.evidenceWarnings,
        'assessment': b.linkedInnerCoverDependency?.needsCurrentAssessment,
      },
  ],
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('withdrawal keeps exact cover assessment without poisoning its neighbour', (
    tester,
  ) async {
    expect(crm3UseEmulators, isTrue);
    expect(crm3DemoProjectId, 'demo-crm3-ci-journeys');
    expect(crm3EmulatorHost, '10.0.2.2');
    expect(crm3AuthEmulatorPort, 19099);
    expect(crm3FirestoreEmulatorPort, 18080);
    expect(crm3FunctionsEmulatorPort, 15001);
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
      'DEV access gate',
    );
    if (find.text('Sign in with Google').evaluate().isNotEmpty) {
      await tapControl(tester, find.text('Sign in with Google'));
    }
    await waitFor(
      tester,
      () => find.byType(HomeScreen).evaluate().isNotEmpty,
      'DEV Home',
    );
    expect(
      FirebaseAuth.instance.currentUser?.email,
      'dev.cf01-b@example.invalid',
    );
    expect(
      (await read('users/${FirebaseAuth.instance.currentUser!.uid}'))['roles'],
      ['admin'],
    );
    final caseRows = await FirebaseFirestore.instance
        .collection('furnace_stuckup_cases')
        .where('innerCoverId', isEqualTo: _affected)
        .get(const GetOptions(source: Source.server));
    expect(
      caseRows.docs,
      hasLength(1),
      reason: 'Only the actual preceding fitness journey case is eligible.',
    );
    final caseId = caseRows.docs.single.id;
    if (_requestedCase.isNotEmpty) expect(caseId, _requestedCase);
    final originalCase = caseRows.docs.single.data();
    expect(originalCase['obstructionStatus'], 'released');
    expect(originalCase['confirmedCause'], 'innerCoverBulging');
    expect(originalCase['concernDisposition'], isNull);
    final out = Directory(
      '${(await getApplicationSupportDirectory()).path}/ic_withdrawn_${DateTime.now().microsecondsSinceEpoch}',
    );
    await out.create(recursive: true);
    await binding.convertFlutterSurfaceToImage();
    Future<void> save(String name, Object? data) async {
      await File(
        '${out.path}/$name.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(_json(data)));
      debugPrint('DEV_WITHDRAWN_EVIDENCE ${out.path}/$name.json');
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await File(
        '${out.path}/$name.png',
      ).writeAsBytes(await binding.takeScreenshot(name));
      binding.reportData?.remove('screenshots');
      debugPrint('DEV_WITHDRAWN_EVIDENCE ${out.path}/$name.png');
    }

    final stablePaths = [
      'furnace_stuckup_cases/$caseId',
      'inner_cover_profiles/$_affected',
      'inner_cover_profiles/$_unrelated',
      'base_inner_cover_assignments/$_base1',
      'base_inner_cover_assignments/$_base2',
      'equipment_status/base_101',
      'equipment_status/base_102',
    ];
    final stableBefore = {for (final p in stablePaths) p: await read(p)};
    final ticketBefore = await read('maintenance_records/$caseId');
    expect(ticketBefore['isDeleted'] == true, _resume);
    await tapControl(tester, find.text('Home'));
    await tapControl(
      tester,
      find
          .descendant(
            of: find.byType(PlantOverviewPanel),
            matching: find.byTooltip('Open plant condition'),
          )
          .first,
    );
    await waitFor(
      tester,
      () => find.byType(AssetConditionBoard).evaluate().isNotEmpty,
      'Plant board',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AssetConditionBoard)),
      listen: false,
    );
    Future<PlantAssetOverview> settled(bool deleted) async {
      await waitFor(tester, () {
        final tickets = container
            .read(plantTicketEvidenceProvider)
            .asData
            ?.value;
        final found = tickets?.rows
            .where((t) => t.firestoreId == caseId)
            .toList();
        final model = container.read(plantAssetOverviewProvider).asData?.value;
        return tickets?.fromServer == true &&
            tickets?.complete == true &&
            found?.length == 1 &&
            found!.single.isDeleted == deleted &&
            model?.innerCovers.length == 2 &&
            model?.innerCoverStock?.inventoryConfirmed == true &&
            model?.innerCoverStock?.linkageConfirmed == true &&
            model?.innerCoverStock?.dependencyEvidenceConfirmed == true;
      }, 'Exact server feeds and withdrawn issue must settle');
      return container.read(plantAssetOverviewProvider).requireValue;
    }

    final before = await settled(_resume);
    await save('01-before', {
      'syntheticCopiedPreconditions': _resume,
      'freshPrecedingUiJourney': !_resume,
      'state': _state(before),
      'ticket': ticketBefore,
      'stable': stableBefore,
      'readOnlyContinuation': _resume,
    });
    expect(
      before.innerCovers
          .singleWhere((c) => c.profile.id == _unrelated)
          .isAvailable,
      isTrue,
    );
    expect(
      before.assets.singleWhere((b) => b.asset.id == _base2).isAvailable,
      isTrue,
    );
    Future<void> home() async {
      await returnRequiredRedHome(tester, find.byType(HomeScreen));
      await tapControl(tester, find.text('Home'));
    }

    Future<void> openPlant() async {
      await home();
      await tapControl(
        tester,
        find.descendant(
          of: find.byType(PlantOverviewPanel),
          matching: find.byTooltip('Open plant condition'),
        ),
      );
      await waitFor(
        tester,
        () => find.byType(AssetConditionBoard).evaluate().isNotEmpty,
        'Plant board',
      );
    }

    if (!_resume) {
      await home();
      await openMore(tester, 'Administration');
      await waitFor(
        tester,
        () => find.byType(AdminDataBrowser).evaluate().isNotEmpty,
        'Admin data browser',
      );
      await tapControl(tester, find.text('Tickets'));
      final search = find.byKey(const ValueKey('admin-tickets-search'));
      await waitFor(
        tester,
        () => search.evaluate().isNotEmpty,
        'Admin ticket search',
      );
      await tester.enterText(search, ticketBefore['description'] as String);
      await tester.pump(const Duration(milliseconds: 500));
      final card = find.byKey(ValueKey('admin-ticket-$caseId'));
      await showControl(tester, card);
      final remove = find.descendant(
        of: card,
        matching: find.byTooltip('Mark deleted'),
      );
      await tapControl(tester, remove);
      await enter(
        tester,
        'Additional notes (optional)',
        'Synthetic DEV issue withdrawal; the confirmed physical concern remains for technical assessment.',
      );
      await tapControl(
        tester,
        find.widgetWithText(FilledButton, 'Mark Deleted'),
      );
      await awaitRecord(
        tester,
        'maintenance_records/$caseId',
        (row) =>
            row['isDeleted'] == true &&
            row['version'] == (ticketBefore['version'] as num) + 1,
      );
      await capture('02-withdrawal-form-complete');
      await openPlant();
    }
    final after = await settled(true);
    final ticketAfter = await read('maintenance_records/$caseId');
    final stableAfter = {for (final p in stablePaths) p: await read(p)};
    await save('03-after', {
      'state': _state(after),
      'ticket': ticketAfter,
      'stable': stableAfter,
      'productionTouched': false,
      'withdrawalThroughRealAppForm': !_resume,
      'physicalFitnessAssessed': false,
    });
    expect(ticketAfter['isDeleted'], isTrue);
    expect(
      ticketAfter['version'],
      _resume ? ticketBefore['version'] : (ticketBefore['version'] as num) + 1,
    );
    expect(stableAfter, stableBefore);
    final affected = after.innerCovers.singleWhere(
      (c) => c.profile.id == _affected,
    );
    expect(affected.isAvailable, isFalse);
    expect(affected.dependency?.needsCurrentAssessment, isTrue);
    expect(
      after.innerCovers
          .singleWhere((c) => c.profile.id == _unrelated)
          .isAvailable,
      isTrue,
    );
    expect(
      after.assets.singleWhere((b) => b.asset.id == _base1).isAvailable,
      isFalse,
    );
    expect(
      after.assets.singleWhere((b) => b.asset.id == _base2).isAvailable,
      isTrue,
    );
    final warning = find.text(
      'Linked Inner Cover DEV-IC-FITNESS-31: fitness assessment needed',
    );
    await showControl(tester, warning);
    expect(warning.hitTestable(), findsOneWidget);
    await capture('04-affected-base');
    for (final id in [_affected, _unrelated]) {
      final row = find.byKey(ValueKey('plant-inner-cover-$id'));
      await showControl(tester, row);
      await capture(
        id == _affected ? '05-affected-cover' : '06-unrelated-cover',
      );
    }
    if (!_resume) {
      const declarationPath =
          'asset_condition_declarations/inner_cover_bulged_$_affected';
      final declarationBefore = await read(declarationPath);
      await home();
      await openMore(tester, 'Furnace stuck-up');
      await waitFor(
        tester,
        () => find.byType(FurnaceStuckupBoard).evaluate().isNotEmpty,
        'Stuck-up history',
      );
      await tapControl(tester, find.widgetWithText(ChoiceChip, 'History'));
      final retained = find.byKey(ValueKey('ic-assessment-retained-$caseId'));
      await showControl(tester, retained);
      expect(
        find.byKey(ValueKey('ic-assessment-review-$caseId')),
        findsNothing,
        reason: 'An installed cover without new acceptance cannot be settled.',
      );
      await tapControl(
        tester,
        find.descendant(
          of: retained,
          matching: find.text('Open Inner Cover records'),
        ),
      );
      await waitFor(
        tester,
        () => find.byType(InnerCoverLifecycleScreen).evaluate().isNotEmpty,
        'Inner Cover records',
      );
      await tapControl(tester, find.widgetWithText(Tab, 'All covers'));
      await tapControl(tester, find.text('DEV-IC-FITNESS-31'));
      await tapControl(tester, find.text('Delink from Base'));
      await enter(
        tester,
        'Reason',
        'Synthetic inspection after retained confirmed concern; actual delink form.',
      );
      await tapControl(tester, find.widgetWithText(FilledButton, 'Confirm'));
      final delinked = await awaitRecord(
        tester,
        'inner_cover_profiles/$_affected',
        (row) =>
            row['lifecycleState'] == 'awaitingInspection' &&
            row['currentBaseAssetInstanceId'] == null,
      );
      await capture('07-delinked-awaiting-inspection');
      // The standard inspection picker records minutes. Wait for a real later
      // minute; do not falsify a future or pre-removal inspection timestamp.
      final floorRaw = delinked['assuranceInvalidatedAt'];
      final floor = floorRaw is Timestamp
          ? floorRaw.toDate()
          : DateTime.parse(floorRaw as String);
      final nextMinute = DateTime(
        floor.year,
        floor.month,
        floor.day,
        floor.hour,
        floor.minute + 1,
      );
      while (DateTime.now().isBefore(
        nextMinute.add(const Duration(seconds: 1)),
      )) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tapControl(tester, find.text('DEV-IC-FITNESS-31'));
      await tapControl(tester, find.text('Accept').hitTestable());
      await tapControl(tester, find.text('Choose inspection date and time'));
      await tapControl(tester, find.text('OK')); // Actual selected current day.
      await tapControl(
        tester,
        find.text('OK'),
      ); // Actual current minute, after delink.
      await enter(tester, 'Acceptance reference', 'DEV-POST-EVENT-$caseId');
      await enter(tester, 'Leak-test reference', 'DEV-LEAK-$caseId');
      await enter(tester, 'NDT reference', 'DEV-NDT-$caseId');
      await enter(
        tester,
        'Inspection notes',
        'Synthetic physical inspection after removal resolves recorded bulging concern.',
      );
      await enter(
        tester,
        'Acceptance reason',
        'Synthetic post-event technical assessment and inspection evidence.',
      );
      await tapControl(tester, find.text('Accept').hitTestable());
      final accepted = await awaitRecord(
        tester,
        'inner_cover_profiles/$_affected',
        (row) =>
            row['lifecycleState'] == 'available' &&
            row['acceptanceReference'] == 'DEV-POST-EVENT-$caseId',
      );
      final acceptanceId = accepted['lastMutationId'] as String;
      final acceptanceAudit = await read(
        'inner_cover_lifecycle_audits/inner_cover_$acceptanceId',
      );
      expect(acceptanceAudit['operation'], 'ACCEPT_INNER_COVER');
      expect(
        (await read('furnace_stuckup_cases/$caseId'))['concernDisposition'],
        isNull,
        reason:
            'Stock acceptance alone must not settle the retained assessment.',
      );
      await openPlant();
      await waitFor(
        tester,
        () =>
            container
                .read(plantAssetOverviewProvider)
                .asData
                ?.value
                .innerCovers
                .any(
                  (row) =>
                      row.profile.id == _affected &&
                      row.profile.version == accepted['version'],
                ) ==
            true,
        'Actual acceptance revision must reach the ordinary Plant provider',
      );
      final afterAcceptance = await settled(true);
      expect(
        afterAcceptance.innerCovers
            .singleWhere((c) => c.profile.id == _affected)
            .dependency
            ?.needsCurrentAssessment,
        isTrue,
      );
      await capture('08-acceptance-alone-keeps-assessment');
      await home();
      await openMore(tester, 'Furnace stuck-up');
      await tapControl(tester, find.widgetWithText(ChoiceChip, 'History'));
      final review = find.byKey(ValueKey('ic-assessment-review-$caseId'));
      await showControl(tester, review);
      await tapControl(tester, review);
      await tester.enterText(
        find.byKey(const ValueKey('ic-assessment-reason')),
        'I reviewed this synthetic post-event inspection and confirm that it resolves this exact retained concern.',
      );
      await tapControl(
        tester,
        find.byKey(const ValueKey('ic-assessment-confirm')),
      );
      await tapControl(
        tester,
        find.byKey(const ValueKey('ic-assessment-submit')),
      );
      final recovered = await awaitRecord(
        tester,
        'furnace_stuckup_cases/$caseId',
        (row) => row['concernDisposition'] is Map,
      );
      final disposition = recovered['concernDisposition'] as Map;
      expect(disposition['acceptanceRequestId'], acceptanceId);
      expect(disposition['innerCoverId'], _affected);
      expect(
        disposition['eventLinkageId'],
        originalCase['innerCoverLinkageId'],
      );
      expect(recovered['version'], (originalCase['version'] as num) + 1);
      final preservedCase = Map<String, dynamic>.from(recovered)
        ..remove('concernDisposition')
        ..['updatedAt'] = originalCase['updatedAt']
        ..['version'] = originalCase['version'];
      expect(preservedCase, originalCase);
      expect(await read('maintenance_records/$caseId'), ticketAfter);
      expect(await read(declarationPath), declarationBefore);
      expect(
        await read('inner_cover_profiles/$_unrelated'),
        stableBefore['inner_cover_profiles/$_unrelated'],
      );
      expect(
        await read('base_inner_cover_assignments/$_base2'),
        stableBefore['base_inner_cover_assignments/$_base2'],
      );
      await openPlant();
      await waitFor(
        tester,
        () =>
            container
                .read(plantAssetOverviewProvider)
                .asData
                ?.value
                .innerCovers
                .any(
                  (c) =>
                      c.profile.id == _affected &&
                      c.dependency?.needsCurrentAssessment == false &&
                      c.isAvailable,
                ) ==
            true,
        'Server-confirmed explicit assessment settlement',
      );
      await capture('09-explicit-settlement-available-cover');
      await save('10-recovery-proof', {
        'case': recovered,
        'acceptance': accepted,
        'immutableAcceptanceAudit': acceptanceAudit,
        'withdrawnIssueUnchanged': true,
        'bulgeHistoryUnchanged': true,
        'unrelatedCoverUnchanged': true,
        'throughOrdinaryForms': true,
        'productionTouched': false,
      });
    }
    expect(tester.takeException(), isNull);
    debugPrint('DEV_WITHDRAWN_PASS ${out.path}');
  });
}
