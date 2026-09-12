import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/inspections/domain/inspection_campaign_submission.dart';
import 'package:crm3_baf_ops/features/inspections/services/inspection_campaign_submission_controller.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';
import '../tool/test_support/inspection_campaign_submission_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository store;
  late InspectionCampaignSubmissionController controller;
  late CampaignCreationServer server;
  late AppUser actor;
  var probes = 0;
  Future<void> Function(String)? capability;

  Future<void> open() async {
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'campaign_submission',
      inspector: false,
    );
    store = DurableSubmissionRepository(database);
    controller = InspectionCampaignSubmissionController(
      store: store,
      gateway: server,
      reader: server,
      requireActor: () => actor,
      requireCapability: (uid) async {
        probes++;
        await capability?.call(uid);
      },
    );
  }

  Future<void> reopen() async {
    await database.close();
    await open();
  }

  Future<DurableSubmission> prepare({
    String id = 'command-1',
    String campaign = 'campaign-1',
    Map<String, Object?>? payload,
    String? origin,
  }) => controller.prepare(
    originActorUid: origin ?? actor.uid,
    payload: payload ?? campaignCreationPayload(),
    definitionCode: 'FURNACE_PT',
    definitionTitle: 'Pressure setting',
    commandId: id,
    campaignId: campaign,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('campaign_submission_');
    server = CampaignCreationServer();
    actor = campaignManager();
    probes = 0;
    capability = null;
    await open();
  });
  tearDown(() async {
    if (database.isOpen) await database.close(deleteFromDisk: true);
    if (directory.existsSync() && directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  });

  test(
    'response lost then database reopen retries exact envelope and both original IDs',
    () async {
      final saved = await prepare();
      server.loseNextResponse = true;
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<InspectionCampaignSubmissionException>()),
      );
      expect(server.campaigns.length, 1);
      await reopen();
      final restored = (await controller.restore())!;
      expect(restored.envelopeJson, saved.envelopeJson);
      expect(restored.state, DurableSubmissionState.uncertain);
      expect(restored.aggregateId, 'campaign-1');
      final result = await controller.check(restored.submissionId);
      expect(result.id, 'campaign-1');
      expect(server.envelopes, [saved.envelopeJson, saved.envelopeJson]);
      expect(server.campaigns.length, 1);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test(
    'accepted receipt survives read failure and reopen; reconciliation sends nothing',
    () async {
      final saved = await prepare();
      server.failRead = true;
      await expectLater(controller.check(saved.submissionId), throwsStateError);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      await reopen();
      server.failRead = false;
      await controller.check(saved.submissionId);
      expect(server.envelopes.length, 1);
      expect(probes, 1);
      expect(await controller.restore(), isNull);
      await prepare(id: 'command-2', campaign: 'campaign-2');
      await controller.check('command-2');
      expect(
        server.campaigns.length,
        2,
        reason:
            'A later intentional identical action is not content-hash deduplicated.',
      );
    },
  );

  test(
    'wrong domain receipt cannot settle acceptance or reach readback',
    () async {
      final saved = await prepare();
      server.wrongReceipt = true;
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<InspectionCampaignSubmissionException>()),
      );
      final current = (await store.read(saved.submissionId))!;
      expect(current.state, DurableSubmissionState.uncertain);
      expect(current.receiptJson, isNull);
      expect(server.reads, 0);
    },
  );

  test(
    'changed payload and replacement IDs cannot bypass an unresolved logical submission',
    () async {
      final original = campaignCreationPayload();
      final saved = await prepare(payload: original);
      (original['targetAssetNumbers'] as List).add(8);
      expect(
        InspectionCampaignSubmission.parse(
          saved.envelopeJson,
        ).command.payload['targetAssetNumbers'],
        [7],
      );
      await expectLater(
        prepare(
          payload: {...campaignCreationPayload(), 'purpose': 'Changed purpose'},
        ),
        throwsA(isA<DurableSubmissionException>()),
      );
      await expectLater(
        prepare(id: 'command-2', campaign: 'campaign-2'),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect(
        (await store.read(saved.submissionId))!.envelopeJson,
        saved.envelopeJson,
      );
      expect(server.envelopes, isEmpty);
    },
  );

  test(
    'capability unavailable retains intent without claim or network dispatch',
    () async {
      final saved = await prepare();
      capability = (_) async => throw StateError('V2 not deployed');
      await expectLater(controller.check(saved.submissionId), throwsStateError);
      final current = (await store.read(saved.submissionId))!;
      expect(current.state, DurableSubmissionState.intent);
      expect(current.attemptCount, 0);
      expect(server.envelopes, isEmpty);
    },
  );

  test(
    'account switch while checking capability cannot dispatch original saved work',
    () async {
      final saved = await prepare();
      capability = (_) async {
        actor = campaignManager('manager-b');
      };
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<InspectionCampaignSubmissionException>()),
      );
      expect(server.envelopes, isEmpty);
      expect((await store.read(saved.submissionId))!.attemptCount, 0);
      expect(await controller.restore(), isNull);
      await expectLater(
        prepare(origin: 'manager-a'),
        throwsA(isA<InspectionCampaignSubmissionException>()),
      );
    },
  );

  test(
    'account switch during readback retains validated receipt until original actor returns',
    () async {
      final saved = await prepare();
      server.onRead = () {
        actor = campaignManager('manager-b');
      };
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<InspectionCampaignSubmissionException>()),
      );
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      actor = campaignManager();
      server.onRead = null;
      await controller.check(saved.submissionId);
      expect(server.envelopes.length, 1);
    },
  );

  test(
    'contradictory exact server creation identity cannot clear the accepted owner',
    () async {
      final saved = await prepare();
      server.failRead = true;
      await expectLater(controller.check(saved.submissionId), throwsStateError);
      server.failRead = false;
      server.campaigns['campaign-1']!['createdByUid'] = 'another-actor';
      await expectLater(
        controller.check(saved.submissionId),
        throwsA(isA<InspectionCampaignSubmissionException>()),
      );
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      expect(server.envelopes.length, 1);
    },
  );

  test(
    'later valid status and population changes survive creation reconciliation',
    () async {
      final saved = await prepare();
      server.failRead = true;
      await expectLater(controller.check(saved.submissionId), throwsStateError);
      final current = server.campaigns['campaign-1']!;
      current['version'] = 3;
      current['status'] = 'paused';
      (current['targetAssetNumbers'] as List).add(8);
      (current['targetPopulation'] as List).add(
        campaignCreationTarget(8, server.appliedAt, actor.uid)
          ..['addedLater'] = true,
      );
      current['expectedPopulation'] = 2;
      (current['targetDispositionCounts'] as Map)['pending'] = 2;
      server.failRead = false;
      final result = await controller.check(saved.submissionId);
      expect(result.version, 3);
      expect(result.status, InspectionCampaignStatus.paused);
      expect(result.targetAssetNumbers, [7, 8]);
      expect(
        (await store.read(saved.submissionId))!.envelopeJson,
        saved.envelopeJson,
      );
      expect(server.envelopes.length, 1);
    },
  );

  test('two simultaneous checks get one dispatch grant', () async {
    final saved = await prepare();
    final gate = Completer<void>();
    server.dispatchGate = gate;
    final first = controller.check(saved.submissionId);
    while (server.envelopes.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await expectLater(
      controller.check(saved.submissionId),
      throwsA(isA<InspectionCampaignSubmissionException>()),
    );
    gate.complete();
    await first;
    expect(server.envelopes.length, 1);
    expect(server.campaigns.length, 1);
  });

  test(
    'only positively never-sent work can cancel; unknown outcome keeps resource claim',
    () async {
      await prepare();
      await controller.cancelNeverSent('command-1');
      await prepare(id: 'command-2', campaign: 'campaign-2');
      server.loseNextResponse = true;
      await expectLater(
        controller.check('command-2'),
        throwsA(isA<InspectionCampaignSubmissionException>()),
      );
      await expectLater(
        controller.cancelNeverSent('command-2'),
        throwsA(isA<DurableSubmissionException>()),
      );
      await reopen();
      expect((await controller.restore())!.submissionId, 'command-2');
      expect(
        (await store.read('command-1'))!.state,
        DurableSubmissionState.cancelledBeforeSend,
      );
    },
  );

  test('closed native store never falls back to a capable gateway', () async {
    await prepare();
    await database.close();
    await expectLater(controller.check('command-1'), throwsA(isA<IsarError>()));
    expect(server.envelopes, isEmpty);
  });

  for (final stage in ['prepare', 'reconcile', 'cancel']) {
    test(
      'account switch after native $stage cannot receive original actor result',
      () async {
        final gated = _AfterNativeWriteStore(database, stage, () {
          actor = campaignManager('manager-b');
        });
        controller = InspectionCampaignSubmissionController(
          store: gated,
          gateway: server,
          reader: server,
          requireActor: () => actor,
          requireCapability: (_) async {},
        );
        if (stage == 'prepare') {
          await expectLater(
            prepare(),
            throwsA(isA<InspectionCampaignSubmissionException>()),
          );
          expect(
            (await store.read('command-1'))!.state,
            DurableSubmissionState.intent,
          );
        } else {
          await prepare();
          await expectLater(
            stage == 'reconcile'
                ? controller.check('command-1')
                : controller.cancelNeverSent('command-1'),
            throwsA(isA<InspectionCampaignSubmissionException>()),
          );
          expect(
            (await store.read('command-1'))!.state,
            stage == 'reconcile'
                ? DurableSubmissionState.reconciled
                : DurableSubmissionState.cancelledBeforeSend,
          );
        }
        expect(await controller.restore(), isNull);
      },
    );
  }
}

class _AfterNativeWriteStore extends DurableSubmissionRepository {
  _AfterNativeWriteStore(super.isar, this.stage, this.changeActor);
  final String stage;
  final void Function() changeActor;
  @override
  Future<DurableSubmission> prepare(DurableSubmissionDraft draft) async {
    final result = await super.prepare(draft);
    if (stage == 'prepare') changeActor();
    return result;
  }

  @override
  Future<DurableSubmission> markReconciled({
    required String submissionId,
    required String envelopeSha256,
    required String receiptSha256,
    Future<void> Function(Isar transactionStore)? adoptInTransaction,
  }) async {
    final result = await super.markReconciled(
      submissionId: submissionId,
      envelopeSha256: envelopeSha256,
      receiptSha256: receiptSha256,
      adoptInTransaction: adoptInTransaction,
    );
    if (stage == 'reconcile') changeActor();
    return result;
  }

  @override
  Future<DurableSubmission> cancelNeverSent({
    required String submissionId,
    required String actorUid,
  }) async {
    final result = await super.cancelNeverSent(
      submissionId: submissionId,
      actorUid: actorUid,
    );
    if (stage == 'cancel') changeActor();
    return result;
  }
}
