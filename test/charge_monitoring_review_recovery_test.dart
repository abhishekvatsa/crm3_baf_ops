import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/quality/services/quality_command_service.dart';
import 'package:crm3_baf_ops/features/quality/services/quality_monitoring_submission_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/charge_monitoring_review_actual_handler.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  Map<String, dynamic> response(String key) =>
      Map<String, dynamic>.from(fixture[key] as Map);
  QualityMonitoringRequest entity(String key) {
    final result = response(key);
    return QualityMonitoringRequest.fromMap(
      Map<String, dynamic>.from(result['entity'] as Map),
      result['entityId'] as String,
    );
  }

  late Directory directory;
  late Isar db;
  late DurableSubmissionRepository store;
  late QualityMonitoringSubmissionController controller;
  late AppUser actor;
  late String mode;
  late List<Map<String, dynamic>> sent;
  bool lose = false, tamper = false, refuse = false;
  Future<void> open() async {
    db = await Isar.open(
      [DurableSubmissionRecordSchema],
      directory: directory.path,
      name: 'monitoring_review',
      inspector: false,
    );
    store = DurableSubmissionRepository(db);
    controller = QualityMonitoringSubmissionController(
      store: store,
      projectId: 'test-project',
      requireActor: () => actor,
      newId: () => response(mode)['requestId'] as String,
      requireCapability: (_) async {},
      requireReviewCapability: (_) async {},
      invoke: (envelope) async {
        sent.add(envelope);
        expect(envelope['originActorUid'], 'admin');
        expect(
          envelope['request'],
          fixture[mode == 'corrected'
              ? 'correct'
              : mode == 'cancelled'
              ? 'cancel'
              : 'closeRequest'],
        );
        if (refuse) {
          throw FirebaseFunctionsException(
            code: 'aborted',
            message: 'This revision changed',
            details: const {
              'reasonCode': 'quality-monitoring-version-conflict',
            },
          );
        }
        if (lose) {
          lose = false;
          throw TimeoutException('reply lost after commit');
        }
        return response(mode);
      },
      readFromServer: (_) async => tamper
          ? {
              ...response(mode)['entity'] as Map<String, dynamic>,
              'grade': 'Altered after acceptance',
            }
          : mode == 'closed'
          ? response('archived')
          : Map<String, dynamic>.from(response(mode)['entity'] as Map),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('monitoring_review_');
    actor = AppUser(
      uid: 'admin',
      name: 'Admin',
      email: 'admin@example.com',
      roles: [AppRole.admin],
      isApproved: true,
      createdAt: DateTime.utc(2026),
    );
    mode = 'corrected';
    sent = [];
    lose = false;
    tamper = false;
    refuse = false;
    await open();
  });
  tearDown(() async {
    if (db.isOpen) await db.close(deleteFromDisk: true);
    if (directory.existsSync() && directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  });
  Future<DurableSubmission> saved() async =>
      (await store.listForActor('admin', includeTerminal: true)).single;
  Future<QualityCommandResult> send() {
    final request = Map<String, dynamic>.from(
      fixture[mode == 'corrected'
              ? 'correct'
              : mode == 'cancelled'
              ? 'cancel'
              : 'closeRequest']
          as Map,
    );
    for (final key in [
      'requestId',
      'operation',
      'monitoringRequestId',
      'expectedVersion',
    ]) {
      request.remove(key);
    }
    return controller.reviewMonitoring(
      request: entity(mode == 'cancelled' ? 'corrected' : 'created'),
      operation: mode == 'corrected'
          ? QualityCommandOperation.correctMonitoringRequest
          : mode == 'cancelled'
          ? QualityCommandOperation.cancelMonitoringRequest
          : QualityCommandOperation.closeMonitoringRequest,
      payload: request,
    );
  }

  for (final kind in ['corrected', 'cancelled', 'closed']) {
    test(
      '$kind actual backend receipt survives lost response and native database restart with identical envelope',
      () async {
        mode = kind;
        lose = true;
        await expectLater(send(), throwsA(isA<QualityCommandException>()));
        final original = await saved();
        expect(original.state, DurableSubmissionState.uncertain);
        await db.close();
        await open();
        final result = await controller.checkSavedChange(original.aggregateId);
        expect(sent[1], sent[0]);
        expect((await saved()).envelopeJson, original.envelopeJson);
        expect((await saved()).state, DurableSubmissionState.reconciled);
        expect(result.monitoringRequest!.isCancelled, kind == 'cancelled');
      },
    );
  }
  test(
    'same-revision altered business evidence remains accepted but unreconciled',
    () async {
      tamper = true;
      await expectLater(send(), throwsA(isA<QualityCommandException>()));
      expect((await saved()).state.isAccepted, true);
      expect((await saved()).state, isNot(DurableSubmissionState.reconciled));
      tamper = false;
      await controller.checkSavedChange((await saved()).aggregateId);
      expect(sent.length, 1);
      expect((await saved()).state, DurableSubmissionState.reconciled);
    },
  );
  test(
    'lost acceptance followed by stale refusal preserves identity and specific explanation',
    () async {
      lose = true;
      await expectLater(send(), throwsA(isA<QualityCommandException>()));
      final original = await saved();
      refuse = true;
      await expectLater(
        controller.checkSavedChange(original.aggregateId),
        throwsA(
          isA<QualityCommandException>().having(
            (e) => e.reasonCode,
            'reason',
            'quality-monitoring-version-conflict',
          ),
        ),
      );
      final retained = await saved();
      expect(retained.state, DurableSubmissionState.uncertain);
      expect(retained.envelopeJson, original.envelopeJson);
      refuse = false;
      await controller.checkSavedChange(original.aggregateId);
      expect((await saved()).state, DurableSubmissionState.reconciled);
    },
  );
  test(
    'account switch cannot dispatch another actor saved correction',
    () async {
      lose = true;
      await expectLater(send(), throwsA(isA<QualityCommandException>()));
      final original = await saved();
      actor = AppUser(
        uid: 'another-admin',
        name: 'Other',
        email: 'other@example.com',
        roles: [AppRole.admin],
        isApproved: true,
        createdAt: DateTime.utc(2026),
      );
      await expectLater(
        controller.checkSavedChange(original.aggregateId),
        throwsA(isA<QualityCommandException>()),
      );
      expect(sent.length, 1);
    },
  );
  test(
    'approved origin can read a retained acceptance after losing management authority without sending again',
    () async {
      tamper = true;
      await expectLater(send(), throwsA(isA<QualityCommandException>()));
      final original = await saved();
      actor = AppUser(
        uid: 'admin',
        name: 'Former manager',
        email: 'admin@example.com',
        roles: [AppRole.operations],
        isApproved: true,
        createdAt: DateTime.utc(2026),
      );
      tamper = false;
      await controller.checkSavedChange(original.aggregateId);
      expect(sent.length, 1);
      expect((await saved()).state, DurableSubmissionState.reconciled);
    },
  );
  test(
    'schema-1 creation replay from actual handler retains a strict legacy payload',
    () {
      final result = response('legacyCreationReplay');
      expect((result['entity'] as Map).containsKey('visibilityState'), false);
      expect(
        entity('legacyCreationReplay').status,
        QualityMonitoringStatus.active,
      );
    },
  );
  test(
    'legacy cancellation keeps missing registered identity missing and distinct from completion',
    () {
      final record = entity('legacyCancelled');
      expect(record.baseAssetInstanceId, isNull);
      expect(record.isCancelled, true);
    },
  );
}
