import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/domain/current_actor_access.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/critical_alarm/providers/critical_alarm_providers.dart';
import 'package:crm3_baf_ops/features/critical_alarm/services/critical_alarm_command_service.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

class _Gateway implements OriginBoundWorkflowCommandGateway {
  final List<String> envelopes = [];

  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(String raw) async {
    envelopes.add(raw);
    final command = (jsonDecode(raw) as Map)['command'] as Map;
    return WorkflowCommandReceipt(
      commandId: command['commandId'] as String,
      resultKey: 'critical-alarm-raised',
      aggregateVersion: 1,
      result: {
        'alarmId': command['aggregateId'],
        'status': 'raised',
        'detailsPending': false,
      },
      appliedAt: DateTime.utc(2026, 9, 19),
    );
  }
}

AppUser _actor(String uid) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.com',
  roles: const [AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository store;
  late StreamController<AppUser?> authority;
  late ProviderContainer container;
  late ProviderSubscription<AsyncValue<List<DurableSubmission>>> keepAlive;
  late CriticalAlarmCommandService service;
  late _Gateway gateway;
  late bool online;

  Future<List<DurableSubmission>> pendingWhere(
    bool Function(List<DurableSubmission>) predicate,
  ) {
    final completion = Completer<List<DurableSubmission>>();
    late ProviderSubscription<AsyncValue<List<DurableSubmission>>> subscription;
    subscription = container.listen(criticalAlarmPendingSubmissionsProvider, (
      _,
      next,
    ) {
      if (next.isLoading || next.hasError || completion.isCompleted) return;
      final values = next.valueOrNull;
      if (values != null && predicate(values)) completion.complete(values);
    }, fireImmediately: true);
    return completion.future
        .timeout(const Duration(seconds: 5))
        .whenComplete(subscription.close);
  }

  Future<void> changeAuthority(AppUser? actor, {bool error = false}) async {
    final completion = Completer<void>();
    final subscription = container.listen(currentAppUserProvider, (_, next) {
      final matches = error
          ? next.hasError
          : !next.isLoading &&
                !next.hasError &&
                next.valueOrNull?.uid == actor?.uid;
      if (matches && !completion.isCompleted) completion.complete();
    });
    if (error) {
      authority.addError(StateError('Synthetic account verification failure'));
    } else {
      authority.add(actor);
    }
    await completion.future.timeout(const Duration(seconds: 5));
    subscription.close();
  }

  Future<void> saveOffline() => expectLater(
    service.raise(
      definition: CriticalAlarmDefinition.byKey['fire']!,
      location: 'Synthetic review bay',
      initialDetails: 'Synthetic test incident',
    ),
    throwsA(
      isA<WorkflowException>().having(
        (e) => e.details['reasonCode'],
        'reason',
        'critical-alarm-saved-offline',
      ),
    ),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'alarm_pending_provider_',
    );
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'alarm_pending_provider',
      inspector: false,
    );
    store = DurableSubmissionRepository(database);
    authority = StreamController<AppUser?>.broadcast();
    gateway = _Gateway();
    online = false;
    service = CriticalAlarmCommandService(
      connectivity: Connectivity(),
      durableStore: store,
      originBoundGateway: gateway,
      currentActorUid: () =>
          CurrentActorAccess.resolve(
            container.read(currentAppUserProvider),
          ).actor?.uid ??
          '',
      checkConnectivity: () async => [
        online ? ConnectivityResult.wifi : ConnectivityResult.none,
      ],
      immediateReplayDelay: Duration.zero,
    );
    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((_) => authority.stream),
        criticalAlarmCommandServiceProvider.overrideWithValue(service),
      ],
    );
    keepAlive = container.listen(
      criticalAlarmPendingSubmissionsProvider,
      (_, __) {},
      fireImmediately: true,
    );
    await changeAuthority(_actor('operator-1'));
    await pendingWhere((rows) => rows.isEmpty);
  });
  tearDown(() async {
    keepAlive.close();
    container.dispose();
    await authority.close();
    await database.close(deleteFromDisk: true);
    directory.deleteSync(recursive: true);
  });

  test(
    'mounted pending provider observes new intent and accepted settlement without invalidation',
    () async {
      final appeared = pendingWhere((rows) => rows.length == 1);
      await saveOffline();
      final original = (await appeared).single;
      expect(original.state, DurableSubmissionState.intent);
      expect(original.attemptCount, 0);
      expect(gateway.envelopes, isEmpty);
      online = true;
      final disappeared = pendingWhere((rows) => rows.isEmpty);
      await service.resume(original.submissionId);
      await disappeared;
      expect(gateway.envelopes, [original.envelopeJson]);
      expect(
        (await store.read(original.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test(
    'account changes select only that actor and retain both original envelopes',
    () async {
      await saveOffline();
      final first = (await pendingWhere((rows) => rows.length == 1)).single;
      await changeAuthority(_actor('operator-2'));
      await pendingWhere((rows) => rows.isEmpty);
      await saveOffline();
      final second = (await pendingWhere(
        (rows) => rows.length == 1 && rows.single.actorUid == 'operator-2',
      )).single;
      expect(second.requestId, isNot(first.requestId));
      await changeAuthority(null);
      await pendingWhere((rows) => rows.isEmpty);
      await changeAuthority(_actor('operator-1'));
      final restored = (await pendingWhere(
        (rows) => rows.length == 1 && rows.single.actorUid == 'operator-1',
      )).single;
      expect(restored.envelopeJson, first.envelopeJson);
      expect(
        (await store.read(second.submissionId))!.envelopeJson,
        second.envelopeJson,
      );
      expect(gateway.envelopes, isEmpty);
    },
  );

  test(
    'account verification error hides retained actor data and recovery restores exact pending row',
    () async {
      await saveOffline();
      final first = (await pendingWhere((rows) => rows.length == 1)).single;
      await changeAuthority(null, error: true);
      await pendingWhere((rows) => rows.isEmpty);
      await expectLater(
        service.resume(first.submissionId),
        throwsA(isA<WorkflowException>()),
      );
      expect(gateway.envelopes, isEmpty);
      await changeAuthority(_actor('operator-1'));
      final restored = (await pendingWhere((rows) => rows.length == 1)).single;
      expect(restored.envelopeJson, first.envelopeJson);
      expect(restored.state, DurableSubmissionState.intent);
    },
  );
}
