// Real phone UI -> ordinary commands -> local Firebase -> canonical readback.
// Prepare tool/dev/seed_usability_phone_fixture.py and seed_quality_phone_actor.py.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_form.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_ticket_detail_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/ticket_screen.dart';
import 'package:crm3_baf_ops/features/reports/presentation/operations_report_pdf_screen.dart';
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
        confirmCurrentRaTime,
        switchActor;

Future<void> _boot(WidgetTester tester) async {
  expect(crm3UseEmulators, isTrue);
  final flutterError = FlutterError.onError;
  final platformError = PlatformDispatcher.instance.onError;
  try {
    await tester.runAsync(app.startCrmBafApp);
  } finally {
    FlutterError.onError = flutterError;
    PlatformDispatcher.instance.onError = platformError;
  }
  expect(Firebase.app().options.projectId, 'demo-crm3-baf-ops');
  await waitFor(
    tester,
    () =>
        find.text('Sign in with Google').evaluate().isNotEmpty ||
        find.byType(HomeScreen).evaluate().isNotEmpty,
    'Normal approval gate',
  );
  if (find.text('Sign in with Google').evaluate().isNotEmpty) {
    await tester.tap(find.text('Sign in with Google'));
  }
  await waitFor(
    tester,
    () => find.byType(HomeScreen).evaluate().isNotEmpty,
    'Approved home',
  );
  if (FirebaseAuth.instance.currentUser?.email !=
      'dev.operations@example.invalid') {
    await switchActor(tester, 'dev.operations@example.invalid');
  }
}

Future<void> _home(WidgetTester tester) async {
  while (find.byType(HomeScreen).evaluate().isEmpty) {
    await goBack(tester);
  }
  await tester.tap(find.text('Home'));
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _issueCard(int charge) => find
    .ancestor(
      of: find.text('Charge $charge'),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_TicketCard',
      ),
    )
    .first;

Future<void> _report(
  WidgetTester tester,
  String preset,
  String fileName, {
  bool maintenance = false,
  bool baseRegister = false,
}) async {
  await _home(tester);
  await openMore(tester, 'Operations intelligence');
  await waitFor(
    tester,
    () => find.text('Scope and period').evaluate().isNotEmpty,
    'Live operations report sources must load',
  );
  await tapControl(tester, find.text('Scope and period'));
  await select(
    tester,
    keyedPrefix('asset-class-'),
    baseRegister ? 'All asset classes' : 'Annealing furnace',
  );
  await tapControl(tester, find.byTooltip('Create PDF report'));
  await tapControl(tester, find.text(preset));
  if (maintenance) {
    await select(
      tester,
      find.byKey(const ValueKey('report-maintenance-period-basis')),
      'Opened / assigned during period',
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('report-maintenance-details')),
    );
  } else if (!baseRegister) {
    await select(
      tester,
      find.byKey(const ValueKey('report-quality-period-basis')),
      'RA performed during period',
    );
    await tapControl(tester, find.byKey(const ValueKey('report-ra-only')));
  }
  await tapControl(tester, find.byKey(const ValueKey('report-build-preview')));
  await waitFor(
    tester,
    () => find.byType(OperationsReportPdfPreviewScreen).evaluate().isNotEmpty,
    'Actual selected report must reach PDF preview',
  );
  final preview = tester.widget<OperationsReportPdfPreviewScreen>(
    find.byType(OperationsReportPdfPreviewScreen),
  );
  final bytes = await tester.runAsync(() => preview.bytes);
  expect(bytes, isNotNull);
  expect(bytes!.length, greaterThan(3000));
  expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
  final path = '${Directory.systemTemp.path}/$fileName';
  await tester.runAsync(() => File(path).writeAsBytes(bytes, flush: true));
  debugPrint(
    'DEV_USABILITY_PDF ${jsonEncode({'path': path, 'bytes': bytes.length, 'preset': preset})}',
  );
  await _home(tester);
}

Future<String> _logAssessment(
  WidgetTester tester,
  int charge, {
  required String observation,
  String? processId,
  String? processObservation,
  String? ticketId,
}) async {
  final result = processId != null;
  await _home(tester);
  await openMore(tester, 'Abnormalities');
  await tester.enterText(find.byType(TextField).first, '$charge');
  await tester.tap(find.text('Open').first);
  await waitFor(
    tester,
    () => find
        .byKey(const ValueKey('charge-abnormalities-create'))
        .evaluate()
        .isNotEmpty,
    'Charge workspace',
  );
  await tapControl(
    tester,
    find.byKey(const ValueKey('charge-abnormalities-create')),
  );
  await waitFor(
    tester,
    () => find.text('Log charge abnormality').evaluate().isNotEmpty,
    'Actual abnormality form',
  );
  if (!result) {
    await tapControl(tester, find.text('Process / equipment'));
  }
  await select(
    tester,
    keyedPrefix('abnormality-type-'),
    result ? 'DEV-COLOUR' : 'BURN-FAULT',
  );
  await showControl(
    tester,
    find.byKey(const ValueKey('abnormality-observation')),
  );
  await tester.enterText(
    find.byKey(const ValueKey('abnormality-observation')),
    observation,
  );
  await select(
    tester,
    find.byKey(const ValueKey('abnormality-asset-class')),
    'Annealing furnace',
  );
  await select(
    tester,
    keyedPrefix('abnormality-asset-seed-class-'),
    'Furnace 01',
  );
  await tapControl(tester, find.text('Add affected equipment'));
  if (result) {
    // This catalogue row deliberately suggests RA. The operator must decide.
    await showControl(
      tester,
      find.byKey(const ValueKey('abnormality-ra-decision')),
    );
    final decision = tester.widget<DropdownButtonFormField<ReannealingStatus>>(
      find.byKey(const ValueKey('abnormality-ra-decision')),
    );
    expect(decision.initialValue, ReannealingStatus.pendingDecision);
    await tapControl(
      tester,
      find.byKey(const ValueKey('abnormality-add-cause')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('abnormality-cause-description')),
      'DEV $charge: process fault may explain the colour',
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('abnormality-link-maintenance')),
    );
    await waitFor(
      tester,
      () => find.text('Maintenance issue on this charge').evaluate().isNotEmpty,
      'Real same-charge maintenance evidence',
    );
    await tapControl(
      tester,
      find.text('Unusual noise observed from the Furnace.').last,
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('abnormality-link-process')),
    );
    await waitFor(
      tester,
      () => find
          .text('Existing process observation on this charge')
          .evaluate()
          .isNotEmpty,
      'Real same-charge process evidence',
    );
    await tapControl(
      tester,
      find.descendant(
        of: find.byType(ListView).last,
        matching: find.text(processObservation!),
      ),
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('abnormality-keep-cause')),
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('abnormality-add-cause')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('abnormality-cause-description')),
      'DEV $charge: cooling water leak considered',
    );
    await select(
      tester,
      find.byKey(const ValueKey('abnormality-cause-assessment')),
      'Ruled out with evidence',
    );
    await showControl(
      tester,
      find.byKey(const ValueKey('abnormality-cause-evidence')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('abnormality-cause-evidence')),
      'DEV trial inspection found the water circuit dry and intact.',
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('abnormality-keep-cause')),
    );
    await select(
      tester,
      find.byKey(const ValueKey('abnormality-ra-decision')),
      'Required',
    );
    await tapControl(
      tester,
      find.byKey(const ValueKey('abnormality-ra-performed')),
    );
    await enter(tester, 'New RA charge number', '${charge + 1}');
    await confirmCurrentRaTime(tester);
    await select(
      tester,
      find.byKey(const ValueKey('abnormality-post-ra-result')),
      'Acceptable',
    );
    await enter(
      tester,
      'Post-RA observations',
      'DEV trial: colour acceptable after RA examination.',
    );
  }
  await tapControl(tester, find.text('Log abnormality'));
  await waitFor(
    tester,
    () => find.text('Log charge abnormality').evaluate().isEmpty,
    'Assessment accepted through the real submit flow',
  );
  String? id;
  Map<String, dynamic>? row;
  for (var i = 0; i < 90 && id == null; i++) {
    final docs = await FirebaseFirestore.instance
        .collection('charge_abnormalities')
        .where('sourceChargeNo', isEqualTo: charge)
        .get(const GetOptions(source: Source.server));
    final matches = docs.docs.where(
      (doc) => doc.data()['observedReason'] == observation,
    );
    if (matches.isNotEmpty) {
      expect(matches, hasLength(1));
      id = matches.single.id;
      row = matches.single.data();
    } else {
      await tester.pump(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }
  expect(
    id,
    isNotNull,
    reason: 'Only canonical acceptance proves the new observation saved.',
  );
  final assessment = Map<String, dynamic>.from(row!['assessment'] as Map);
  expect(
    row['possibleRootReasonCategory'],
    'unknown',
    reason: 'Selecting affected equipment must not invent a cause.',
  );
  expect(row['possibleRootReasonNotes'], isNull);
  final warning = await read('quality_warnings/abnormality_$id');
  expect(warning['status'], 'open');
  expect(warning['sourceId'], id);
  expect(warning['sourceChargeNo'], charge);
  expect(
    assessment['observationKind'],
    result ? 'resultFinding' : 'processEquipment',
  );
  if (result) {
    final causes = assessment['candidateCauses'] as List;
    expect(causes, hasLength(2));
    expect(causes.first['assessment'], 'suspected');
    expect(causes.first['maintenanceTicketId'], ticketId);
    expect(causes.first['processAbnormalityId'], processId);
    expect(causes.last['assessment'], 'ruledOut');
    expect(causes.last['evidence'], contains('water circuit dry'));
    expect(assessment['raPerformedAt'], isNotNull);
    expect(assessment['postRaResult'], 'acceptable');
    expect(row['reannealingStatus'], 'completed');
    expect(row['reannealedToChargeNo'], charge + 1);
    expect(
      (await read('charge_abnormalities/$processId'))['observedReason'],
      processObservation,
    );
  } else {
    expect(assessment['candidateCauses'], isEmpty);
    expect(assessment['raPerformedAt'], isNull);
    expect(row['reannealingStatus'], 'pendingDecision');
  }
  await _home(tester);
  return id!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'DEV report before diagnosis, supervised identification and actual PDF reports',
    (tester) async {
      await _boot(tester);
      var charge = 80000 + DateTime.now().millisecondsSinceEpoch % 9000;
      while ((await FirebaseFirestore.instance
              .collection('maintenance_records')
              .where('chargeNoAtEvent', isEqualTo: charge)
              .get(const GetOptions(source: Source.server)))
          .docs
          .isNotEmpty) {
        charge++;
      }
      await openMore(tester, 'Raise issue');
      await waitFor(
        tester,
        () => find.byType(MaintenanceForm).evaluate().isNotEmpty,
        'Real issue form',
      );
      await tapControl(tester, find.text('Not suspected'));
      await select(
        tester,
        find.byKey(const ValueKey('issue-asset-class')),
        'Annealing furnace',
      );
      await select(tester, keyedPrefix('issue-physical-asset-'), 'Furnace 01');
      await select(
        tester,
        find.byKey(const ValueKey('maintenance-component-intake-state')),
        'Not yet identified',
      );
      await tapControl(tester, find.byTooltip('Choose issue'));
      await tapControl(tester, find.text('Unusual noise from Furnace'));
      await enter(tester, 'Charge number', '$charge');
      // Intentionally no component name and no additional free-text observation.
      await tapControl(tester, find.text('Submit Issue'));
      await waitFor(
        tester,
        () => find.byType(MaintenanceForm).evaluate().isEmpty,
        'Server-accepted issue submission',
      );
      String? ticketId;
      for (var attempt = 0; attempt < 90 && ticketId == null; attempt++) {
        final docs = await FirebaseFirestore.instance
            .collection('maintenance_records')
            .where('chargeNoAtEvent', isEqualTo: charge)
            .get(const GetOptions(source: Source.server));
        final matches = docs.docs.where(
          (doc) =>
              doc.data()['description'] ==
              'Unusual noise observed from the Furnace.',
        );
        if (matches.isNotEmpty) {
          expect(matches, hasLength(1));
          ticketId = matches.single.id;
        } else {
          await tester.pump(const Duration(seconds: 1));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
      expect(
        ticketId,
        isNotNull,
        reason: 'Local pending save does not count as accepted creation',
      );
      final path = 'maintenance_records/$ticketId';
      final created = await read(path);
      expect(created['componentIntakeState'], 'unidentified');
      expect(created['componentIdentification'], isNull);
      expect(
        created['description'],
        'Unusual noise observed from the Furnace.',
      );
      expect(created['qualityWarningId'], isNull);
      final originalReference = created['assetHierarchyRefJson'];
      debugPrint(
        'DEV_USABILITY issue accepted: charge=$charge ticket=$ticketId',
      );

      await _home(tester);
      await switchActor(
        tester,
        'dev.usability-contractsupervisor@example.invalid',
      );
      await tapControl(tester, find.text('Open issues'));
      await waitFor(
        tester,
        () => find.byType(TicketScreen).evaluate().isNotEmpty,
        'Open issues screen',
      );
      await tester.enterText(
        find.byType(TextField).first,
        'Unusual noise observed',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await showControl(tester, find.text('Charge $charge'));
      await tapControl(
        tester,
        find.descendant(
          of: _issueCard(charge),
          matching: find.text('Acknowledge'),
        ),
      );
      await tapControl(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Acknowledge'),
        ),
      );
      await awaitRecord(tester, path, (row) => row['status'] == 'acknowledged');
      final acknowledged = await read(path);
      debugPrint('DEV_USABILITY acknowledged: ticket=$ticketId');
      final actions = find.descendant(
        of: _issueCard(charge),
        matching: find.byType(PopupMenuButton<int>),
      );
      await waitFor(
        tester,
        () =>
            actions.evaluate().isNotEmpty &&
            tester.widget<PopupMenuButton<int>>(actions).enabled,
        'Acknowledgement must converge before the card accepts another action',
      );
      await tapControl(
        tester,
        find.descendant(
          of: _issueCard(charge),
          matching: find.byTooltip('Issue record and actions'),
        ),
      );
      await waitFor(
        tester,
        () => find.text('View complete record').evaluate().isNotEmpty,
        'Issue actions popup',
      );
      await tapControl(tester, find.text('View complete record'));
      await waitFor(
        tester,
        () => find.byType(MaintenanceTicketDetailScreen).evaluate().isNotEmpty,
        'Exact issue record',
      );
      await tapControl(
        tester,
        find.byKey(const ValueKey('maintenance-identify-component')),
      );
      await tapControl(
        tester,
        find.byKey(const ValueKey('maintenance-identification-choose')),
      );
      await tapControl(tester, find.text('Furnace seal'));
      final basis =
          'DEV $charge: supervisor inspected and identified the Furnace seal.';
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-identification-basis')),
        basis,
      );
      await tapControl(
        tester,
        find.byKey(const ValueKey('maintenance-identification-save')),
      );
      final identified = await awaitRecord(
        tester,
        path,
        (row) => row['componentIdentification'] != null,
      );
      debugPrint('DEV_USABILITY component identified: ticket=$ticketId');
      final identification = Map<String, dynamic>.from(
        identified['componentIdentification'] as Map,
      );
      expect(
        identification['identifiedByUid'],
        FirebaseAuth.instance.currentUser!.uid,
      );
      expect(identification['basis'], basis);
      expect(
        jsonDecode(identification['targetReferenceJson'] as String)['nodeId'],
        'dev-usability-furnace-seal',
      );
      expect(identified['assetHierarchyRefJson'], originalReference);
      for (final field in [
        'component',
        'description',
        'isResolved',
        'status',
        'endDate',
        'actionsJson',
        'issueLanePlanJson',
        'qualityWarningId',
        'qualityAbnormalityId',
      ]) {
        expect(
          identified[field],
          acknowledged[field],
          reason: 'Identification must preserve original $field',
        );
      }
      await _home(tester);
      await switchActor(tester, 'dev.operations@example.invalid');
      final processObservation =
          'DEV $charge: Furnace burner instability observed';
      final processId = await _logAssessment(
        tester,
        charge,
        observation: processObservation,
      );
      final resultId = await _logAssessment(
        tester,
        charge,
        observation: 'DEV $charge: uneven annealing colour observed',
        processId: processId,
        processObservation: processObservation,
        ticketId: ticketId,
      );
      expect(processId, isNot(resultId));
      final independent = await FirebaseFirestore.instance
          .collection('charge_abnormalities')
          .where('sourceChargeNo', isEqualTo: charge)
          .get(const GetOptions(source: Source.server));
      expect(independent.docs.map((doc) => doc.id).toSet(), {
        processId,
        resultId,
      });
      await _report(
        tester,
        'Maintenance register and performance',
        'crm3-usability-maintenance.pdf',
        maintenance: true,
      );
      await _report(
        tester,
        'Quality and RA assurance',
        'crm3-usability-quality.pdf',
      );
      await _report(
        tester,
        'Current Base / Inner Cover register',
        'crm3-usability-base-register.pdf',
        baseRegister: true,
      );
      await _home(tester);
      debugPrint(
        'DEV_OPERATIONAL_USABILITY_PASS ${jsonEncode({'chargeNo': charge, 'ticketId': ticketId, 'processId': processId, 'resultId': resultId, 'initialComponent': 'unidentified', 'frequentChoiceWithoutExtraTyping': true, 'identifiedBy': 'contractSupervisor', 'afterAcknowledgement': true, 'originalEvidencePreserved': true, 'explicitRaDateAndIndependentCauses': true, 'threeActualPdfFilesGenerated': true, 'status': 'passed'})}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
