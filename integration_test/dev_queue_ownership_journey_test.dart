// Real native storage, Auth, Functions and Rules. Run the resume journey in a
// separate Android process with app data preserved after this phase succeeds.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as database;
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/services/retained_row_mutations.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';

Future<void> initializeQueueOwnershipEmulators() async {
  expect(crm3UseEmulators, isTrue);
  expect(crm3DemoProjectId, 'demo-crm3-ci-journeys');
  await Firebase.initializeApp(options: crm3DemoFirebaseOptions);
  await connectCrm3Emulators();
}

Future<Directory> queueOwnershipDirectory() async {
  final root = await getApplicationSupportDirectory();
  return Directory('${root.path}/cf01-proof');
}

Future<Isar> openQueueOwnershipDatabase({bool requireExisting = false}) async {
  final dir = await queueOwnershipDirectory();
  if (requireExisting) {
    expect(
      await File('${dir.path}/cf01-proof.isar').exists(),
      isTrue,
      reason: 'Resume must open phase-one native data, never a new fixture.',
    );
  } else {
    await dir.create();
  }
  final db = await Isar.open(
    [
      AbnormalityTypeSchema,
      JobTemplateSchema,
      JobExecutionSchema,
      DurableSubmissionRecordSchema,
    ],
    directory: dir.path,
    name: 'cf01-proof',
    inspector: false,
  );
  database.isar = db;
  return db;
}

Future<AppUser> readQueueOwnershipActor() async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final snapshot = await FirebaseFirestore.instance
      .doc('users/$uid')
      .get(const GetOptions(source: Source.server));
  final actor = AppUser.fromFirestore(
    snapshot.data()!,
    uid,
    fromCache: snapshot.metadata.isFromCache,
    hasPendingWrites: snapshot.metadata.hasPendingWrites,
    observedAt: DateTime.now(),
  );
  expect(
    actor.isApproved && actor.isAdmin && actor.hasServerAuthorityObservation,
    isTrue,
  );
  return actor;
}

Future<AppUser> signInQueueOwnershipActor(String suffix) async {
  final auth = FirebaseAuth.instance;
  await auth.signOut();
  await auth.signInWithEmailAndPassword(
    email: 'dev.cf01-$suffix@example.invalid',
    password: crm3DevSignInSecret,
  );
  return readQueueOwnershipActor();
}

Future<List<(RetainedRowKind, dynamic)>> queueOwnershipRows(Isar db) async {
  final types = await db.abnormalityTypes.where().findAll();
  final templates = await db.jobTemplates.where().findAll();
  final executions = await db.jobExecutions.where().findAll();
  expect(types, hasLength(1));
  expect(templates, hasLength(1));
  expect(executions, hasLength(1));
  return [
    (RetainedRowKind.abnormalityType, types.single),
    (RetainedRowKind.legacyTemplate, templates.single),
    (RetainedRowKind.executionWork, executions.single),
  ];
}

Future<void> verifyQueueOwnershipBlocked(
  Isar db,
  AppUser actorB,
  List<DurableSubmission> saved,
) async {
  final rows = await queueOwnershipRows(db);
  for (var index = 0; index < rows.length; index++) {
    final (kind, row) = rows[index];
    final request = saved.singleWhere(
      (value) => value.aggregateId == row.firestoreId,
    );
    expect(request.actorUid, isNot(actorB.uid));
    expect(
      RetainedRowMutations.wire(row),
      request.envelope['command']['payload']['record'],
    );
    await expectLater(
      RetainedRowMutations().synchronize(kind, row),
      throwsA(
        isA<DurableSubmissionException>().having(
          (e) => e.code,
          'ownership',
          'origin-mismatch',
        ),
      ),
    );
    final remote = await FirebaseFirestore.instance
        .doc('${kind.collection}/${row.firestoreId}')
        .get(const GetOptions(source: Source.server));
    if (kind == RetainedRowKind.executionWork) {
      expect(remote.data()!['version'], 1);
      expect(remote.data()!['remarks'], isNull);
    } else {
      expect(remote.exists, isFalse);
    }
    expect(row.isSynced, false);
    final retained = await DurableSubmissionRepository(
      db,
    ).read(request.submissionId);
    expect(retained!.envelopeJson, request.envelopeJson);
    expect(retained.state, DurableSubmissionState.intent);
    expect(retained.attemptCount, 0);
    switch (kind) {
      case RetainedRowKind.abnormalityType:
        await expectLater(
          IsarAbnormalityRepository().saveType(
            row as AbnormalityType,
            actor: actorB,
          ),
          throwsA(isA<DurableSubmissionException>()),
        );
      case RetainedRowKind.legacyTemplate:
        await expectLater(
          IsarPlannedRepository().saveTemplate(
            row as JobTemplate,
            actor: actorB,
          ),
          throwsA(isA<DurableSubmissionException>()),
        );
      case RetainedRowKind.executionWork:
        await expectLater(
          IsarPlannedRepository().saveExecution(
            row as JobExecution,
            actor: actorB,
          ),
          throwsA(isA<DurableSubmissionException>()),
        );
    }
  }
  final preserved = await queueOwnershipRows(db);
  for (final (_, row) in preserved) {
    final request = saved.singleWhere(
      (value) => value.aggregateId == row.firestoreId,
    );
    expect(row.isSynced, false);
    expect(
      RetainedRowMutations.wire(row),
      request.envelope['command']['payload']['record'],
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'CF01 prepares three retained edits and leaves account B signed in',
    (tester) async {
      await tester.runAsync(() async {
        await initializeQueueOwnershipEmulators();
        final firestore = FirebaseFirestore.instance;
        final auth = FirebaseAuth.instance;
        var db = await openQueueOwnershipDatabase();
        try {
          expect(await db.abnormalityTypes.count(), 0);
          expect(await db.jobTemplates.count(), 0);
          expect(await db.jobExecutions.count(), 0);
          final actorA = await signInQueueOwnershipActor('a');
          final suffix = DateTime.now().microsecondsSinceEpoch;
          final now = DateTime.now().toUtc();
          final type = AbnormalityType()
            ..firestoreId = 'cf01-type-$suffix'
            ..code = 'CF01-$suffix'
            ..title = 'Synthetic ownership test'
            ..createdByUid = actorA.uid
            ..createdByName = actorA.name
            ..lastEditedByUid = actorA.uid
            ..lastEditedByName = actorA.name
            ..createdAt = now
            ..updatedAt = now;
          final template = JobTemplate()
            ..firestoreId = 'cf01-template-$suffix'
            ..jobName = 'Synthetic retained template'
            ..applicableAssetType = AssetType.furnace
            ..assignedAgencies = ['mechanical']
            ..createdAt = now
            ..updatedAt = now;
          final execution = JobExecution()
            ..firestoreId = 'cf01-job-$suffix'
            ..templateFirestoreId = 'cf01-existing-legacy-template'
            ..templateName = 'Synthetic existing assignment'
            ..assetType = AssetType.furnace
            ..assetNumber = 1
            ..assignedByUid = actorA.uid
            ..assignedByName = actorA.name
            ..assignedAgencies = ['mechanical']
            ..createdAt = now
            ..updatedAt = now
            ..version = 1
            ..isSynced = true;
          final executionRef = firestore.doc(
            'job_executions/${execution.firestoreId}',
          );
          await executionRef.set(execution.toClientWritableMap());
          await IsarPlannedRepository().applyExecutionFromRemote(
            JobExecution.fromMap(
              (await executionRef.get(
                const GetOptions(source: Source.server),
              )).data()!,
              execution.firestoreId!,
            ),
          );
          await firestore.disableNetwork();
          try {
            await IsarAbnormalityRepository().saveType(type, actor: actorA);
            await IsarPlannedRepository().saveTemplate(template, actor: actorA);
            execution.remarks = 'Work saved by original account A';
            await IsarPlannedRepository().saveExecution(
              execution,
              actor: actorA,
            );
          } finally {
            await firestore.enableNetwork();
          }
          final rows = await queueOwnershipRows(db);
          final controller = RetainedRowMutations();
          final requests = <DurableSubmission>[];
          for (final (kind, row) in rows) {
            final saved = await controller.store.findUnresolvedForResource(
              controller.resourceKey(
                kind,
                row.firestoreId as String,
                crm3DemoProjectId,
              ),
            );
            expect(saved!.actorUid, actorA.uid);
            requests.add(saved);
          }
          final actorB = await signInQueueOwnershipActor('b');
          expect(actorB.uid, isNot(actorA.uid));
          await verifyQueueOwnershipBlocked(db, actorB, requests);
          await db.close();
          db = await openQueueOwnershipDatabase(requireExisting: true);
          await verifyQueueOwnershipBlocked(db, actorB, requests);
          // Acceptance metadata only; phase two discovers real native records.
          // No envelope or business-row copy can reseed the second process.
          final evidence = jsonEncode({
            'schemaVersion': 1,
            'projectId': crm3DemoProjectId,
            'preparingProcessId': pid,
            'actorAUid': actorA.uid,
            'actorBUid': actorB.uid,
            'requests': [
              for (final value in requests)
                {
                  'submissionId': value.submissionId,
                  'envelopeSha256': value.envelopeSha256,
                },
            ],
          });
          final dir = await queueOwnershipDirectory();
          final marker = File('${dir.path}/prepared.json');
          await marker.writeAsString(evidence, flush: true);
          expect(await marker.readAsString(), evidence);
          expect(auth.currentUser!.uid, actorB.uid);
          debugPrint(
            'DEV_QUEUE_OWNERSHIP_PREPARED three_domains actor_b_pending',
          );
        } finally {
          if (db.isOpen) await db.close();
          // Keep B's genuine Firebase session for the next Android process.
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
