import 'dart:async';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/domain/current_actor_access.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/inspections/domain/inspection_campaign_submission.dart';
import 'package:crm3_baf_ops/features/inspections/presentation/saved_inspection_campaign_panel.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_campaign_submission_provider.dart';
import 'package:crm3_baf_ops/features/inspections/services/inspection_campaign_submission_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_durable_submission_store.dart';
import 'support/inspection_campaign_submission_fixture.dart';

void main() {
  late InMemoryDurableSubmissionStore store;
  late CampaignCreationServer server;
  late InspectionCampaignSubmissionController controller;
  late ProviderContainer container;
  late StreamController<AppUser?> accounts;
  setUp(() async {
    store = InMemoryDurableSubmissionStore();
    server = CampaignCreationServer();
    accounts = StreamController<AppUser?>();
    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => accounts.stream),
        inspectionCampaignSubmissionControllerProvider.overrideWith(
          (ref) => controller,
        ),
      ],
    );
    controller = InspectionCampaignSubmissionController(
      store: store,
      gateway: server,
      reader: server,
      requireActor: () {
        final access = CurrentActorAccess.resolve(
          container.read(currentAppUserProvider),
        );
        if (!access.isReady) {
          throw InspectionCampaignSubmissionException(access.message);
        }
        return access.actor!;
      },
      requireCapability: (_) async {},
    );
    container.listen(currentAppUserProvider, (_, _) {});
    accounts.add(campaignManager());
    await container.read(currentAppUserProvider.future);
    await controller.prepare(
      originActorUid: 'manager-a',
      payload: campaignCreationPayload(),
      definitionCode: 'FURNACE_PT',
      definitionTitle: 'Pressure setting',
      commandId: 'command-1',
      campaignId: 'campaign-1',
    );
  });
  tearDown(() async {
    container.dispose();
    await accounts.close();
  });

  Future<void> showPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SavedInspectionCampaignPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Review saved programme'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'dismissed saved form reopens with fixed entries and retries the same IDs',
    (tester) async {
      await showPanel(tester);
      await open(tester);
      expect(find.text('Verify furnace pressure settings.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await open(tester);
      server.loseNextResponse = true;
      await tester.tap(find.text('Check saved programme'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Programme creation is not confirmed.'),
        findsOneWidget,
      );
      expect(server.campaigns.length, 1);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.text('Cancel unsent programme'), findsNothing);
      await tester.tap(find.text('Check saved programme'));
      await tester.pumpAndSettle();
      expect(server.envelopes.length, 2);
      expect(server.envelopes.toSet().length, 1);
      expect(server.campaigns.length, 1);
      expect(
        (await store.read('command-1'))!.state,
        DurableSubmissionState.reconciled,
      );
      expect(find.text('Review saved programme'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'verification error and account switch hide saved payload and stop actions',
    (tester) async {
      await showPanel(tester);
      await open(tester);
      accounts.addError(StateError('Transient account verification failure'));
      await tester.pumpAndSettle();
      expect(find.text('Verify furnace pressure settings.'), findsNothing);
      expect(find.text('Check saved programme'), findsNothing);
      accounts.add(campaignManager('manager-b'));
      await tester.pumpAndSettle();
      expect(find.text('Verify furnace pressure settings.'), findsNothing);
      expect(find.text('Check saved programme'), findsNothing);
      accounts.add(campaignManager());
      await tester.pumpAndSettle();
      expect(find.text('Verify furnace pressure settings.'), findsOneWidget);
      expect((await store.read('command-1'))!.attemptCount, 0);
      expect(server.envelopes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving dialog during a server response retains the outcome without disposed ref access',
    (tester) async {
      await showPanel(tester);
      await open(tester);
      final gate = Completer<void>();
      server.dispatchGate = gate;
      await tester.tap(find.text('Check saved programme'));
      await tester.pump();
      await tester.tap(find.text('Close'));
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        (await store.read('command-1'))!.state,
        DurableSubmissionState.reconciled,
      );
      expect(server.envelopes.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UI double validates receipt before settlement and keeps prior immutable snapshots',
    () async {
      final original = (await store.read('command-1'))!;
      await store.claim(
        submissionId: original.submissionId,
        actorUid: original.actorUid!,
      );
      await expectLater(
        store.settleAccepted(
          submissionId: original.submissionId,
          envelopeSha256: original.envelopeSha256,
          receiptJson: '{}',
          validateReceipt: (_, _) => false,
        ),
        throwsA(isA<DurableSubmissionException>()),
      );
      expect((await store.read(original.submissionId))!.receiptJson, isNull);
      expect(original.state, DurableSubmissionState.intent);
      expect(original.attemptCount, 0);
    },
  );
}
