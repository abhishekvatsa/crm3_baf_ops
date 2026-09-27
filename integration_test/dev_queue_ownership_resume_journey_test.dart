// Second Android process: opens real phase-one data and persisted Auth B.
// It performs no seeding and never recreates business rows or saved envelopes.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/services/retained_row_mutations.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';

import 'dev_queue_ownership_journey_test.dart' as prepared;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'CF01 original owner resumes after an actual Android process restart',
    (tester) async {
      await tester.runAsync(() async {
        await prepared.initializeQueueOwnershipEmulators();
        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;
        final dir = await prepared.queueOwnershipDirectory();
        final marker = File('${dir.path}/prepared.json');
        expect(
          await marker.exists(),
          isTrue,
          reason: 'Preparation must run first with app data preserved.',
        );
        final evidence =
            jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
        expect(evidence['schemaVersion'], 1);
        expect(evidence['projectId'], crm3DemoProjectId);
        expect(evidence['preparingProcessId'], isA<int>());
        expect(
          pid,
          isNot(evidence['preparingProcessId']),
          reason:
              'A database reopen in the preparation process is insufficient.',
        );
        // No sign-in, sign-out or fixture write occurs before checking the
        // genuinely persisted Firebase session and native pending data.
        final persistedUser = await auth.authStateChanges().first.timeout(
          const Duration(seconds: 30),
        );
        expect(persistedUser, isNotNull);
        expect(persistedUser!.uid, evidence['actorBUid']);
        expect(persistedUser.email, 'dev.cf01-b@example.invalid');
        final actorB = await prepared.readQueueOwnershipActor();
        var db = await prepared.openQueueOwnershipDatabase(
          requireExisting: true,
        );
        try {
          final originalRequests = (evidence['requests'] as List)
              .cast<Map<String, dynamic>>();
          expect(originalRequests, hasLength(3));
          final saved = await DurableSubmissionRepository(db)
              .listForAdministrativeReview(
                requireReviewer: () {
                  expect(auth.currentUser!.uid, actorB.uid);
                  expect(
                    actorB.isApproved &&
                        actorB.isAdmin &&
                        actorB.hasServerAuthorityObservation,
                    isTrue,
                  );
                },
              );
          expect(saved, hasLength(3));
          expect(
            saved.map((row) => row.submissionId).toSet(),
            originalRequests.map((row) => row['submissionId']).toSet(),
          );
          for (final request in saved) {
            expect(request.protocol, 'maintenanceWorkflow.v2');
            expect(request.actorUid, evidence['actorAUid']);
            expect(request.state, DurableSubmissionState.intent);
            final original = originalRequests.singleWhere(
              (row) => row['submissionId'] == request.submissionId,
            );
            expect(request.envelopeSha256, original['envelopeSha256']);
          }
          await prepared.verifyQueueOwnershipBlocked(db, actorB, saved);
          final actorA = await prepared.signInQueueOwnershipActor('a');
          expect(actorA.uid, evidence['actorAUid']);
          final rows = await prepared.queueOwnershipRows(db);
          final first = saved.singleWhere(
            (request) => request.aggregateId == rows.first.$2.firestoreId,
          );
          // The real server accepts this exact frozen request, while its native
          // journal deliberately receives no acknowledgement. Retry must reuse it.
          final accepted = await const FirebaseWorkflowCommandGateway()
              .executeOriginBoundEnvelope(first.envelopeJson);
          expect(
            (await DurableSubmissionRepository(
              db,
            ).read(first.submissionId))!.state,
            DurableSubmissionState.intent,
          );
          expect(rows.first.$2.isSynced, false);
          await db.close();
          db = await prepared.openQueueOwnershipDatabase(requireExisting: true);
          final recoveredRows = await prepared.queueOwnershipRows(db);
          for (var index = 0; index < recoveredRows.length; index++) {
            final (kind, row) = recoveredRows[index];
            final original = saved.singleWhere(
              (request) => request.aggregateId == row.firestoreId,
            );
            expect(
              RetainedRowMutations.wire(row),
              original.envelope['command']['payload']['record'],
            );
            await RetainedRowMutations().synchronize(kind, row);
            final remote = await firestore
                .doc('${kind.collection}/${row.firestoreId}')
                .get(const GetOptions(source: Source.server));
            expect(
              remote.data()!['version'],
              kind == RetainedRowKind.executionWork ? 2 : 1,
            );
            final retained = await DurableSubmissionRepository(
              db,
            ).read(original.submissionId);
            expect(retained!.state, DurableSubmissionState.reconciled);
            expect(retained.envelopeJson, original.envelopeJson);
            final auditSnapshot = await firestore
                .doc('audit_logs/server_cf01_${original.requestId}')
                .get(const GetOptions(source: Source.server));
            final audit = decodePersistedAuditEvent(
              auditSnapshot.data()!,
              documentId: auditSnapshot.id,
            );
            expect(audit.performedByUid, actorA.uid);
            expect(
              audit.entityType,
              ['abnormality_type', 'job_template', 'job_execution'][index],
            );
            await RetainedRowMutations().check(
              retained.submissionId,
              kind: kind,
            );
            expect(
              (await firestore
                      .doc('${kind.collection}/${row.firestoreId}')
                      .get(const GetOptions(source: Source.server)))
                  .data()!['version'],
              kind == RetainedRowKind.executionWork ? 2 : 1,
            );
          }
          final replay = await const FirebaseWorkflowCommandGateway()
              .executeOriginBoundEnvelope(first.envelopeJson);
          expect(replay.commandId, accepted.commandId);
          expect(replay.appliedAt, accepted.appliedAt);
          for (final (_, row) in await prepared.queueOwnershipRows(db)) {
            expect(row.isSynced, true);
          }
          debugPrint(
            'DEV_QUEUE_OWNERSHIP_PASS three_domains process_restart persisted_actor_b exact_replay',
          );
        } finally {
          if (db.isOpen) await db.close();
          await auth.signOut();
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
