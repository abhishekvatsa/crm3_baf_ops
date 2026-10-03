// Phase 1: real required-RED creation and Operations receipt loss on isolated DEV.
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'support/required_red_journey.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'required RED YES uses real role handoff and preserves a lost receipt',
    (tester) async {
      await startRedApp(tester, resume: false);
      final evidence = await evidenceFile();
      expect(
        await evidence.exists(),
        isFalse,
        reason: 'Never replace prior interrupted-journey evidence.',
      );
      expect((await relay('status'))['phase'], 'idle');
      await actor(tester, redSi);
      final parentVersion = await publishDraft(
        tester,
        redParentPackage,
        'ci-required-red-parent-version-1',
        'DEV required RED parent inspection',
      );
      final successorVersion = await publishDraft(
        tester,
        redSuccessorPackage,
        'ci-required-red-successor-version-1',
        'DEV required RED refractory inspection',
      );
      final parent = await assignParent(tester, parentVersion);
      await submitAndAccept(
        tester,
        parent,
        'dev.usability-contractsupervisor@example.invalid',
        'Inspection findings',
        'CI required RED parent inspection; refractory follow-up required.',
      );
      final closedParent = await finishJob(
        tester,
        parent,
        'mech',
        requiredRed: true,
      );
      final child = closedParent['spawnedRedExecutionFirestoreId'] as String;
      expect(child, matches(RegExp(r'^red_[a-f0-9]{28}$')));
      final childExecution = await committed('job_executions/$child');
      expect(childExecution['templateVersionId'], successorVersion);
      final compliance = '${child}_preparation';
      final requestPath = 'compliance_requests/$compliance';
      final lanePath = 'job_lanes/${child}_red_1';
      final workflowPath = 'maintenance_workflows/$child';
      final initialRequest = await committed(requestPath);
      expect(initialRequest['status'], 'raised');
      expect(initialRequest['originLaneKey'], 'red');
      expect(initialRequest['targetLaneKey'], 'oprn');
      expect(
        initialRequest['gatesLaneFirestoreId'],
        'job_lanes/${child}_red_1',
      );
      final initialWorkflow = await committed(workflowPath);
      final initialLane = await committed(lanePath);
      expect(initialLane['status'], 'pending');
      expect(initialLane['gatingComplianceRequestId'], compliance);
      final equipment = await committed('equipment_status/furnace_1');
      expect(equipment['awaitingPreparationCount'], 1);
      expect(equipment['activeRedWorkCount'], 0);

      // Wrong department sees a disabled real control. A tap must not progress it.
      await actor(tester, redElectrical);
      await openJob(tester, child);
      await tapControl(
        tester,
        find.byKey(const ValueKey('workflow-lane-red-1')),
      );
      final denied = find.widgetWithText(ListTile, 'Acknowledge lane');
      expect(tester.widget<ListTile>(denied).enabled, isFalse);
      await tapControl(tester, denied);
      expect(find.widgetWithText(ListTile, 'RED lane'), findsOneWidget);
      expect((await committed(lanePath))['version'], initialLane['version']);
      expect(
        (await committed(workflowPath))['version'],
        initialWorkflow['version'],
      );
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));

      // Correct RED department still cannot start before Operations preparation.
      await actor(tester, redWorker);
      final deniedActorUid = FirebaseAuth.instance.currentUser!.uid;
      await openJob(tester, child);
      await laneAction(tester, 'red', 'Acknowledge lane');
      await waitFor(
        tester,
        () =>
            find
                .textContaining('required equipment preparation')
                .evaluate()
                .isNotEmpty ||
            find
                .textContaining('RED work has not been released')
                .evaluate()
                .isNotEmpty,
        'Real backend must reject RED work before preparation',
      );
      expect((await committed(lanePath))['status'], 'pending');
      expect(
        (await committed(workflowPath))['version'],
        initialWorkflow['version'],
      );
      expect(
        (await committed(requestPath))['version'],
        initialRequest['version'],
      );
      final deniedRows = (await nativeWorkflow.getPendingCommands())
          .where(
            (row) =>
                row.aggregateId == child &&
                row.commandTypeKey == 'acknowledgeLane' &&
                row.lastErrorCode == 'redPreparationIncomplete',
          )
          .toList();
      expect(deniedRows, hasLength(1));
      final deniedRow = deniedRows.single;
      expect(deniedRow.stateKey, 'manualReview');
      expect(
        (jsonDecode(deniedRow.payloadJson) as Map)['__workflowOriginBoundV1'],
        deniedActorUid,
      );
      expect(await nativeWorkflow.getReceipt(deniedRow.commandId), isNull);
      debugPrint('DEV_REQUIRED_RED_DENIED_ROLE_AND_PREPARATION');
      await waitFor(
        tester,
        () => find.byType(SnackBar).evaluate().isEmpty,
        'Expected denial notice finishes',
        seconds: 20,
      );

      await actor(tester, redOperations);
      final operationsUid = FirebaseAuth.instance.currentUser!.uid;
      expect(operationsUid, isNot(deniedActorUid));
      final deniedAfterSwitch = await nativeWorkflow.getRetryCommand(
        deniedRow.commandId,
      );
      expect(deniedAfterSwitch, isNotNull);
      expect(deniedAfterSwitch!.payloadJson, deniedRow.payloadJson);
      expect(deniedAfterSwitch.stateKey, deniedRow.stateKey);
      expect(deniedAfterSwitch.expectedVersion, deniedRow.expectedVersion);
      expect(deniedAfterSwitch.attemptCount, deniedRow.attemptCount);
      expect(deniedAfterSwitch.lastAttemptAt, deniedRow.lastAttemptAt);
      expect(await nativeWorkflow.getReceipt(deniedRow.commandId), isNull);
      await openPreparation(tester, child);
      await relay('arm', {
        'project': redProject,
        'workflowId': child,
        'complianceId': compliance,
        'actorUid': operationsUid,
      });
      final acknowledge = find.widgetWithText(FilledButton, 'Acknowledge');
      await showControl(tester, acknowledge);
      await waitFor(
        tester,
        () => tester.widget<FilledButton>(acknowledge).onPressed != null,
        'Operations may acknowledge',
      );
      // Actual repeated gesture after the busy frame, no callback invocation.
      await tester.tap(acknowledge.hitTestable());
      await tester.pump(const Duration(milliseconds: 100));
      final busy = find.widgetWithText(FilledButton, 'Working online\u2026');
      await waitFor(
        tester,
        () => busy.evaluate().isNotEmpty,
        'Real command displays busy state',
      );
      expect(tester.widget<FilledButton>(busy.first).onPressed, isNull);
      await tester.tap(busy.first.hitTestable());
      await tester.pump(const Duration(milliseconds: 150));
      final acknowledged = await untilRecord(
        tester,
        requestPath,
        (row) => row['status'] == 'acknowledged',
      );
      expect(acknowledged['acknowledgedByUid'], operationsUid);
      expect(acknowledged['version'], (initialRequest['version'] as int) + 1);
      Map<String, dynamic> transport = {};
      final untilHeld = DateTime.now().add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(untilHeld)) {
        transport = await relay('status');
        if (transport['phase'] == 'withheld') break;
        await tester.pump(const Duration(milliseconds: 250));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect(transport['phase'], 'withheld');
      expect(transport['forwardedAttempts'], 1);
      expect(
        transport['guardRejectCount'],
        0,
        reason:
            'Repeated gesture must not create a second command masked by relay rejection.',
      );
      final commandId = transport['commandId'] as String;
      final untilSaved = DateTime.now().add(const Duration(seconds: 90));
      while (DateTime.now().isBefore(untilSaved)) {
        final saved = await nativeWorkflow.getRetryCommand(commandId);
        if (saved?.stateKey == 'uncertainOutcome') break;
        await tester.pump(const Duration(milliseconds: 400));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final saved = await nativeWorkflow.getRetryCommand(commandId);
      expect(saved, isNotNull);
      expect(saved!.stateKey, 'uncertainOutcome');
      expect(saved.commandTypeKey, 'acknowledgeCompliance');
      expect(saved.aggregateId, child);
      expect(await nativeWorkflow.getReceipt(commandId), isNull);

      // A later legitimate command B makes replay A's original version stale.
      // The original acknowledgement stays uncertain in its native journal.
      await waitFor(
        tester,
        () => find.byType(SnackBar).evaluate().isEmpty,
        'Receipt-loss notice finishes',
        seconds: 20,
      );
      await tapControl(tester, find.byTooltip('Refresh request'));
      final comply = find.widgetWithText(FilledButton, 'Mark complied');
      await waitFor(
        tester,
        () =>
            comply.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(comply).onPressed != null,
        'Committed acknowledgement can be followed by the real Operations completion',
      );
      await tapControl(tester, comply);
      await enter(
        tester,
        'What was completed?',
        'CI equipment placed on maintenance stand and made ready.',
      );
      await tapControl(tester, find.text('Continue'));
      final complied = await untilRecord(
        tester,
        requestPath,
        (row) => row['status'] == 'complied',
      );
      expect(complied['compliedByUid'], operationsUid);
      final laterWorkflow = await committed(workflowPath);
      expect(
        laterWorkflow['version'],
        greaterThan(transport['acceptedAggregateVersion'] as int),
      );
      final retained = await nativeWorkflow.getRetryCommand(commandId);
      expect(retained, isNotNull);
      expect(retained!.payloadJson, saved.payloadJson);
      expect(retained.expectedVersion, saved.expectedVersion);
      expect(await nativeWorkflow.getReceipt(commandId), isNull);
      final ackEvents = await FirebaseFirestore.instance
          .collection('maintenance_workflow_events')
          .where('commandId', isEqualTo: commandId)
          .get(server);
      expect(ackEvents.docs, hasLength(1));
      expect((await relay('status'))['guardRejectCount'], 0);
      final proof = {
        'project': redProject,
        'preparedPid': pid,
        'actorUid': operationsUid,
        'parentId': parent,
        'parentVersion': parentVersion,
        'successorVersion': successorVersion,
        'childId': child,
        'complianceId': compliance,
        'commandId': commandId,
        'payloadJson': retained.payloadJson,
        'expectedVersion': retained.expectedVersion,
        'acceptedAggregateVersion': transport['acceptedAggregateVersion'],
        'acceptedAppliedAt': transport['acceptedAppliedAt'],
        'acceptedResultSha256': transport['acceptedResultSha256'],
        'acceptedReceiptSha256': transport['acceptedReceiptSha256'],
        'deniedCommandId': deniedRow.commandId,
        'deniedPayloadJson': deniedRow.payloadJson,
        'deniedActorUid': deniedActorUid,
        'deniedExpectedVersion': deniedRow.expectedVersion,
        'deniedAttemptCount': deniedRow.attemptCount,
        'deniedLastAttemptAt': deniedRow.lastAttemptAt
            ?.toUtc()
            .toIso8601String(),
        'laterWorkflowVersion': laterWorkflow['version'],
        'laterComplianceVersion': complied['version'],
        'oneAcknowledgementEventId': ackEvents.docs.single.id,
        'deniedElectricalUi': true,
        'deniedPrematureRedBackend': true,
        'repeatedBusyTap': true,
      };
      await evidence.writeAsString(jsonEncode(proof), flush: true);
      debugPrint(
        'DEV_REQUIRED_RED_PREPARED ${jsonEncode({'parent': parent, 'child': child, 'commandId': commandId, 'pid': pid, 'realReceiptWithheld': true, 'laterProgressPreserved': true})}',
      );
      // Runner ends only this isolated DEV process and retains this native store.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
