import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as database;
import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/services/charge_abnormality_command_service.dart';
import 'package:crm3_baf_ops/features/abnormalities/services/charge_abnormality_queue_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar db;
  var actor = 'admin-a';

  Future<void> open() async {
    db = await Isar.open(
      [ChargeAbnormalitySchema, DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'abnormality_queue_origin',
      inspector: false,
    );
    database.isar = db;
  }

  ChargeAbnormalityQueueGuard guard() => ChargeAbnormalityQueueGuard(
    store: DurableSubmissionRepository(db),
    projectId: () => 'demo-cf01-test',
    currentActorUid: () => actor,
  );

  ChargeAbnormality record({int version = 1, bool deleted = false}) =>
      ChargeAbnormality()
        ..firestoreId = 'origin-test'
        ..sourceChargeNo = 12001
        ..abnormalityTypeId = 'test-type'
        ..abnormalityTypeTitle = 'Test condition'
        ..abnormalityTypeCode = 'TEST'
        ..observedReason = 'Retained original evidence'
        ..affectedAssetsJson = '[{"assetType":"furnace","assetNumber":1}]'
        ..loggedAt = DateTime.utc(2026, 9, 20)
        ..updatedAt = DateTime.utc(2026, 9, 21)
        ..loggedByUid = 'admin-a'
        ..updatedByUid = 'admin-a'
        ..version = version
        ..isDeleted = deleted
        ..isSynced = false;

  setUp(() async {
    actor = 'admin-a';
    directory = await Directory.systemTemp.createTemp('cf01_abnormality_');
    await open();
  });
  tearDown(() async {
    if (db.isOpen) await db.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  AppUser approvedActor() => AppUser(
    uid: actor,
    name: actor,
    email: '$actor@example.invalid',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026, 9, 20),
  );

  for (final collision in ['local identity', 'document identity']) {
    test('new creation cannot replace an existing $collision', () async {
      final prior = record();
      await db.writeTxn(() => db.chargeAbnormalitys.put(prior));
      final before = jsonEncode(prior.toMap());
      final incoming = record()..observedReason = 'Different proposed creation';
      if (collision == 'local identity') {
        incoming.id = prior.id;
        incoming.firestoreId = 'different-document';
      }
      await expectLater(
        IsarAbnormalityRepository().saveAbnormality(
          incoming,
          actor: approvedActor(),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'collision preserved',
            contains('evidence'),
          ),
        ),
      );
      expect(await db.chargeAbnormalitys.count(), 1);
      expect(
        jsonEncode((await db.chargeAbnormalitys.get(prior.id))!.toMap()),
        before,
      );
    });
  }

  for (final action in ['update', 'delete']) {
    test(
      'privileged generic $action cannot replace saved abnormality evidence',
      () async {
        final prior = record()..isSynced = true;
        await db.writeTxn(() => db.chargeAbnormalitys.put(prior));
        final before = jsonEncode(prior.toMap());
        final proposed =
            ChargeAbnormality.fromMap(prior.toMap(), prior.firestoreId!)
              ..id = prior.id
              ..observedReason = 'Unbound privileged edit';
        final repository = IsarAbnormalityRepository();
        await expectLater(
          action == 'update'
              ? repository.updateAbnormality(proposed, actor: approvedActor())
              : repository.softDeleteAbnormality(
                  prior.id,
                  actor: approvedActor(),
                ),
          throwsStateError,
        );
        expect(await db.chargeAbnormalitys.count(), 1);
        expect(
          jsonEncode((await db.chargeAbnormalitys.get(prior.id))!.toMap()),
          before,
        );
        expect((await db.chargeAbnormalitys.get(prior.id))!.isSynced, isTrue);
      },
    );
  }

  test('creation remains owned by A across B and database restart', () async {
    final row = record();
    await db.writeTxn(() => db.chargeAbnormalitys.put(row));
    actor = 'admin-b';
    final mismatch = isA<ChargeAbnormalityMutationException>()
        .having(
          (e) => e.reasonCode,
          'reason',
          'abnormality-original-account-required',
        )
        .having(
          (e) => e.isDurableRejection,
          'temporary account mismatch',
          false,
        );
    await expectLater(guard().requireOwnedCreation(row), throwsA(mismatch));
    try {
      await guard().requireOwnedCreation(row);
      fail('B must not acquire A\'s pending creation.');
    } on ChargeAbnormalityMutationException catch (error) {
      expect(
        () => rethrowIfSyncRunMustAbort(error),
        returnsNormally,
        reason: 'Another owner\'s row must not stop B\'s independent refresh.',
      );
    }
    await db.close();
    await open();
    final retained = (await db.chargeAbnormalitys.get(row.id))!;
    await expectLater(
      guard().requireOwnedCreation(retained),
      throwsA(mismatch),
    );
    expect(retained.isSynced, isFalse);
    expect(retained.toMap(), row.toMap());
    actor = 'admin-a';
    await guard().requireOwnedCreation(retained);
    expect(
      (await db.chargeAbnormalitys.get(row.id))!.isSynced,
      isFalse,
      reason: 'Admission alone never acknowledges a queued record.',
    );
  });

  for (final deleted in [false, true]) {
    test(
      'legacy ${deleted ? 'deletion' : 'edit'} stays unbound and retained',
      () async {
        final row = record(version: 2, deleted: deleted);
        await db.writeTxn(() => db.chargeAbnormalitys.put(row));
        final expected = jsonEncode(row.toMap());
        final held = isA<ChargeAbnormalityMutationException>().having(
          (e) => e.reasonCode,
          'reason',
          'legacy-abnormality-origin-unknown',
        );
        actor = 'admin-b';
        await expectLater(guard().requireOwnedCreation(row), throwsA(held));
        await db.close();
        await open();
        actor = 'admin-a';
        await expectLater(guard().requireOwnedCreation(row), throwsA(held));
        final journal = await DurableSubmissionRepository(
          db,
        ).listForAdministrativeReview(requireReviewer: () {});
        expect(journal, hasLength(1));
        expect(journal.single.actorUid, isNull);
        expect(journal.single.state, DurableSubmissionState.needsReview);
        expect(
          utf8.decode(base64Decode(journal.single.legacySourceBase64!)),
          expected,
        );
        expect((await db.chargeAbnormalitys.get(row.id))!.isSynced, isFalse);
        expect(
          jsonEncode((await db.chargeAbnormalitys.get(row.id))!.toMap()),
          expected,
        );
      },
    );
  }
}
