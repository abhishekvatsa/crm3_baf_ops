// Phase 2: actual new Android PID resumes the original command after later progress.
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
    'required RED survives real restart and exact stale-version receipt replay',
    (tester) async {
      await startRedApp(tester, resume: true);
      final evidence = await evidenceFile();
      expect(
        await evidence.exists(),
        isTrue,
        reason: 'Original native evidence must survive the stopped process.',
      );
      final proof =
          jsonDecode(await evidence.readAsString()) as Map<String, dynamic>;
      expect(proof['project'], redProject);
      expect(
        pid,
        isNot(proof['preparedPid']),
        reason: 'Actual OS restart, not a rebuilt widget tree.',
      );
      expect(FirebaseAuth.instance.currentUser!.uid, proof['actorUid']);
      final deniedRow = await nativeWorkflow.getRetryCommand(
        proof['deniedCommandId'] as String,
      );
      expect(deniedRow, isNotNull);
      expect(deniedRow!.payloadJson, proof['deniedPayloadJson']);
      expect(
        (jsonDecode(deniedRow.payloadJson) as Map)['__workflowOriginBoundV1'],
        proof['deniedActorUid'],
      );
      expect(deniedRow.stateKey, 'manualReview');
      expect(deniedRow.expectedVersion, proof['deniedExpectedVersion']);
      expect(deniedRow.attemptCount, proof['deniedAttemptCount']);
      expect(
        deniedRow.lastAttemptAt?.toUtc().toIso8601String(),
        proof['deniedLastAttemptAt'],
      );
      expect(await nativeWorkflow.getReceipt(deniedRow.commandId), isNull);
      final commandId = proof['commandId'] as String;
      final child = proof['childId'] as String;
      final compliance = proof['complianceId'] as String;
      final requestPath = 'compliance_requests/$compliance';
      final workflowPath = 'maintenance_workflows/$child';
      final saved = await nativeWorkflow.getRetryCommand(commandId);
      expect(saved, isNotNull);
      expect(saved!.payloadJson, proof['payloadJson']);
      expect(saved.expectedVersion, proof['expectedVersion']);
      expect(await nativeWorkflow.getReceipt(commandId), isNull);
      expect((await committed(requestPath))['status'], 'complied');
      expect(
        (await committed(requestPath))['version'],
        proof['laterComplianceVersion'],
      );
      expect(
        (await committed(workflowPath))['version'],
        proof['laterWorkflowVersion'],
      );
      final transportBefore = await relay('status');
      expect(transportBefore['phase'], 'withheld');
      expect(transportBefore['commandId'], commandId);
      expect(transportBefore['guardRejectCount'], 0);
      await relay('release', {'commandId': commandId});

      // Wait out the production backoff without editing its journal/timestamps.
      final retryAt = saved.nextRetryAt;
      if (retryAt != null) {
        expect(
          retryAt.difference(DateTime.now()),
          lessThan(const Duration(minutes: 3)),
          reason:
              'Unexpected backoff is evidence, not permission to rewrite the queue.',
        );
        while (DateTime.now().isBefore(retryAt)) {
          await tester.pump(const Duration(milliseconds: 300));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      await syncThroughUi(tester);
      final deadline = DateTime.now().add(const Duration(seconds: 120));
      while (DateTime.now().isBefore(deadline)) {
        if (await nativeWorkflow.getReceipt(commandId) != null) break;
        await tester.pump(const Duration(milliseconds: 400));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final receipt = await nativeWorkflow.getReceipt(commandId);
      expect(
        receipt,
        isNotNull,
        reason: 'Production retry must settle the original canonical receipt.',
      );
      expect(receipt!.commandId, commandId);
      expect(receipt.resultKey, 'compliance-acknowledged');
      expect(receipt.aggregateVersion, proof['acceptedAggregateVersion']);
      expect(
        receipt.appliedAt.toUtc().toIso8601String(),
        proof['acceptedAppliedAt'],
      );
      final receiptEnvelope = jsonDecode(receipt.resultJson) as Map;
      expect(receiptEnvelope['__workflowAcceptedEnvelopeV1'], isA<String>());
      expect(
        canonicalResultSha256(receiptEnvelope['result']),
        proof['acceptedResultSha256'],
      );
      expect(
        canonicalResultSha256({
          'commandId': receipt.commandId,
          'resultKey': receipt.resultKey,
          'aggregateVersion': receipt.aggregateVersion,
          'appliedAt': receipt.appliedAt.toUtc().toIso8601String(),
          'result': receiptEnvelope['result'],
        }),
        proof['acceptedReceiptSha256'],
      );
      expect(await nativeWorkflow.getRetryCommand(commandId), isNull);
      expect((await committed(requestPath))['status'], 'complied');
      expect(
        (await committed(requestPath))['version'],
        proof['laterComplianceVersion'],
      );
      expect(
        (await committed(workflowPath))['version'],
        proof['laterWorkflowVersion'],
        reason:
            'Original expectedVersion replay cannot regress later progress or increment twice.',
      );
      final events = await FirebaseFirestore.instance
          .collection('maintenance_workflow_events')
          .where('commandId', isEqualTo: commandId)
          .get(server);
      expect(events.docs, hasLength(1));
      expect(events.docs.single.id, proof['oneAcknowledgementEventId']);
      final transportAfter = await relay('status');
      expect(
        transportAfter['replayForwardedAttempts'],
        greaterThanOrEqualTo(1),
      );
      expect(transportAfter['forwardedAttempts'], 1);
      expect(transportAfter['verifiedReplayReceipts'], greaterThanOrEqualTo(1));
      expect(transportAfter['replayReceiptMismatchCount'], 0);
      expect(
        transportAfter['lastReplayReceiptSha256'],
        proof['acceptedReceiptSha256'],
      );
      expect(transportAfter['guardRejectCount'], 0);
      debugPrint(
        'DEV_REQUIRED_RED_RESTART_REPLAY_VERIFIED ${jsonEncode({'oldPid': proof['preparedPid'], 'newPid': pid, 'commandId': commandId, 'currentVersionPreserved': proof['laterWorkflowVersion']})}',
      );

      // Independent originating department accepts Operations preparation.
      await actor(tester, redWorker);
      final refractoryUid = FirebaseAuth.instance.currentUser!.uid;
      expect(refractoryUid, isNot(proof['actorUid']));
      await openPreparation(tester, child);
      await tapControl(tester, find.text('Accept Operations completion'));
      await enter(
        tester,
        'Confirmation note (optional)',
        'CI refractory witnessed safe preparation.',
      );
      await tapControl(tester, find.text('Continue'));
      final confirmed = await untilRecord(
        tester,
        requestPath,
        (row) => row['status'] == 'confirmedClosed',
      );
      expect(confirmed['confirmedByUid'], refractoryUid);
      final equipment = await committed('equipment_status/furnace_1');
      expect(equipment['awaitingPreparationCount'], 0);
      expect(equipment['activeRedWorkCount'], 1);
      await openJob(tester, child);
      await laneAction(tester, 'red', 'Acknowledge lane');
      final lane = await untilRecord(
        tester,
        'job_lanes/${child}_red_1',
        (row) => row['status'] == 'acknowledged',
      );
      expect(lane['acknowledgedByUid'], refractoryUid);
      await submitAndAccept(
        tester,
        child,
        redWorker,
        'Refractory findings',
        'CI RED refractory inspection completed after independently confirmed stand preparation.',
      );
      final completedChild = await finishJob(
        tester,
        child,
        'red',
        requiredRed: false,
      );
      expect(completedChild['isCompleted'], isTrue);
      expect(completedChild['spawnedRedExecutionFirestoreId'], isNull);
      final parent = await committed('job_executions/${proof['parentId']}');
      expect(parent['isCompleted'], isTrue);
      expect(parent['spawnedRedExecutionFirestoreId'], child);
      final finalEquipment = await committed('equipment_status/furnace_1');
      expect(finalEquipment['activeRedWorkCount'], 0);
      expect(finalEquipment['awaitingPreparationCount'], 0);
      expect(
        (await committed(
          'template_versions/${proof['successorVersion']}',
        ))['status'],
        'published',
      );
      final finalProof = File(
        '${evidence.parent.path}/required-red-completed.json',
      );
      expect(await finalProof.exists(), isFalse);
      await finalProof.writeAsString(
        jsonEncode({
          'project': redProject,
          'parent': proof['parentId'],
          'child': child,
          'commandId': commandId,
          'oldPid': proof['preparedPid'],
          'newPid': pid,
          'requiredRedYes': true,
          'preparationRequiredYes': true,
          'realUiRoleHandoff': true,
          'exactReceiptReplayedAfterLaterProgress': true,
          'childCompleted': true,
        }),
        flush: true,
      );
      debugPrint('DEV_REQUIRED_RED_PASS ${await finalProof.readAsString()}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
