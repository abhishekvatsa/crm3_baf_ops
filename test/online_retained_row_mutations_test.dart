import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/services/online_retained_row_mutations.dart';
import 'package:crm3_baf_ops/core/services/retained_row_mutations.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final instant = DateTime.utc(2026, 9, 20, 10);
  var uid = 'actor-a';
  var project = 'demo-online-ownership';
  late SharedPreferences preferences;
  late _Gateway gateway;

  AppUser actor() => AppUser(
    uid: uid,
    name: uid,
    email: '$uid@example.invalid',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: instant,
  );

  dynamic fixture(RetainedRowKind kind) => switch (kind) {
    RetainedRowKind.abnormalityType =>
      AbnormalityType.seedRaCoilColour(
          createdByUid: 'actor-a',
          createdByName: 'actor-a',
        )
        ..firestoreId = 'type-one'
        ..createdAt = instant
        ..updatedAt = instant,
    RetainedRowKind.legacyTemplate =>
      JobTemplate()
        ..firestoreId = 'template-one'
        ..jobName = 'Original inspection'
        ..applicableAssetType = AssetType.furnace
        ..createdAt = instant
        ..updatedAt = instant
        ..createdByUid = 'actor-a'
        ..createdByName = 'actor-a',
    RetainedRowKind.executionWork =>
      JobExecution()
        ..firestoreId = 'execution-one'
        ..templateFirestoreId = 'template-one'
        ..assetType = AssetType.furnace
        ..assetNumber = 1
        ..assignedByUid = 'actor-a'
        ..assignedByName = 'actor-a'
        ..createdAt = instant
        ..updatedAt = instant,
  };

  OnlineRetainedRowMutations controller() => OnlineRetainedRowMutations(
    preferences: () async => preferences,
    currentActorUid: () => uid,
    projectId: () => project,
    gateway: gateway,
  );

  Future<void> save(RetainedRowKind kind, dynamic row) => controller().save(
    kind: kind,
    actor: actor(),
    record: row,
    readRemote: () async => gateway.current == null
        ? null
        : RetainedRowMutations.decode(kind, gateway.current!, row.firestoreId),
    normalize: (_) => row.updatedAt = instant.add(const Duration(minutes: 1)),
  );

  Map<String, Object> savedPreferences() => {
    for (final key in preferences.getKeys()) key: preferences.get(key)!,
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    uid = 'actor-a';
    project = 'demo-online-ownership';
    gateway = _Gateway();
  });

  for (final kind in RetainedRowKind.values) {
    test(
      '${kind.name} lost response survives B and reloaded journal without borrowing ownership',
      () async {
        final row = fixture(kind);
        if (kind == RetainedRowKind.executionWork) {
          gateway.current = RetainedRowMutations.wire(fixture(kind));
        }
        gateway.loseResponse = true;
        await expectLater(save(kind, row), throwsA(isA<SocketException>()));
        final frozen = gateway.calls.single;
        final saved = savedPreferences();
        expect(saved, isNotEmpty);
        expect(row.isSynced, isFalse);

        uid = 'actor-b';
        await expectLater(save(kind, fixture(kind)), throwsStateError);
        expect(gateway.calls, [frozen]);
        expect(savedPreferences(), saved);

        // Recreate the platform preference cache and the adapter from retained
        // values, as a fresh web application instance would read them.
        SharedPreferences.setMockInitialValues(saved);
        preferences = await SharedPreferences.getInstance();
        await expectLater(save(kind, fixture(kind)), throwsStateError);
        expect(gateway.calls, [frozen]);
        uid = 'actor-a';
        final newer = fixture(kind);
        final newerBefore = RetainedRowMutations.wire(newer);
        await expectLater(
          save(kind, newer),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'reload required',
              contains('earlier saved edit'),
            ),
          ),
        );
        expect(gateway.calls, [frozen, frozen]);
        expect(
          gateway.accepted.length,
          1,
          reason: 'The original request is replayed, not recreated.',
        );
        expect(savedPreferences(), isEmpty);
        expect(
          RetainedRowMutations.wire(newer),
          newerBefore,
          reason:
              'Confirming earlier work must not claim a newer edit was saved.',
        );
        expect(newer.isSynced, isFalse);
      },
    );

    test(
      '${kind.name} mismatched receipt keeps exact request for later review',
      () async {
        final row = fixture(kind);
        if (kind == RetainedRowKind.executionWork) {
          gateway.current = RetainedRowMutations.wire(fixture(kind));
        }
        gateway.mismatchedReceipt = true;
        await expectLater(save(kind, row), throwsStateError);
        final saved = savedPreferences();
        final frozen = gateway.calls.single;
        expect(saved, isNotEmpty);
        expect(row.isSynced, isFalse);
        await expectLater(save(kind, row), throwsStateError);
        expect(gateway.calls, [frozen, frozen]);
        expect(savedPreferences(), saved);
        expect(row.isSynced, isFalse);
      },
    );
  }

  test(
    'authority change while receipt is in flight retains the web request',
    () async {
      final row = fixture(RetainedRowKind.abnormalityType);
      gateway.afterAccept = () => uid = 'actor-b';
      await expectLater(
        save(RetainedRowKind.abnormalityType, row),
        throwsStateError,
      );
      final frozen = gateway.calls.single;
      expect(savedPreferences(), isNotEmpty);
      expect(row.isSynced, isFalse);
      gateway.afterAccept = null;
      uid = 'actor-a';
      await expectLater(
        save(RetainedRowKind.abnormalityType, row),
        throwsStateError,
      );
      expect(gateway.calls, [frozen, frozen]);
      expect(savedPreferences(), isEmpty);
    },
  );

  test(
    'project change while reading canonical state stops before journal or dispatch',
    () async {
      final row = fixture(RetainedRowKind.abnormalityType);
      await expectLater(
        controller().save(
          kind: RetainedRowKind.abnormalityType,
          actor: actor(),
          record: row,
          readRemote: () async {
            project = 'demo-other';
            return null;
          },
          normalize: (_) =>
              fail('Changed session must not normalize or persist the edit.'),
        ),
        throwsStateError,
      );
      expect(gateway.calls, isEmpty);
      expect(savedPreferences(), isEmpty);
    },
  );

  test(
    'dispatch uses the retained snapshot when caller mutates a list during preference append',
    () async {
      final agencies = <String>['mechanical'];
      final row = fixture(RetainedRowKind.legacyTemplate) as JobTemplate
        ..assignedAgencies = agencies;
      Map<String, dynamic>? retainedEnvelope;
      gateway.afterAccept = () {
        final raw = preferences.getString(preferences.getKeys().single)!;
        retainedEnvelope = Map<String, dynamic>.from(
          jsonDecode(raw)['record'] as Map,
        );
      };
      await expectLater(
        controller().save(
          kind: RetainedRowKind.legacyTemplate,
          actor: actor(),
          record: row,
          readRemote: () async => null,
          normalize: (_) {
            row.updatedAt = instant.add(const Duration(minutes: 1));
            scheduleMicrotask(() => agencies.add('electrical'));
          },
        ),
        throwsStateError,
      );
      expect(agencies, ['mechanical', 'electrical']);
      expect(row.isSynced, isFalse);
      expect(gateway.accepted, hasLength(1));
      expect(savedPreferences(), isEmpty);
      final dispatched =
          jsonDecode(gateway.calls.single) as Map<String, dynamic>;
      expect(dispatched, retainedEnvelope);
      expect(dispatched['command']['payload']['record']['assignedAgencies'], [
        'mechanical',
      ]);
    },
  );
}

class _Gateway implements OriginBoundWorkflowCommandGateway {
  final calls = <String>[];
  final accepted = <String, WorkflowCommandReceipt>{};
  Map<String, dynamic>? current;
  bool loseResponse = false;
  bool mismatchedReceipt = false;
  void Function()? afterAccept;

  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    calls.add(envelopeJson);
    final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    final command = envelope['command'] as Map<String, dynamic>;
    final id = command['commandId'] as String;
    final record = Map<String, dynamic>.from(
      command['payload']['record'] as Map,
    );
    final kind = RetainedRowKind.values.singleWhere(
      (value) => value.commandType.name == command['commandType'],
    );
    final receipt = accepted.putIfAbsent(
      id,
      () => WorkflowCommandReceipt(
        commandId: id,
        resultKey: 'retained-queue-mutation-applied',
        aggregateVersion: record['version'] as int,
        result: {
          'collection': kind.collection,
          'recordId': command['aggregateId'],
          'record': record,
        },
        appliedAt: DateTime.utc(2026, 9, 20, 10, 2),
      ),
    );
    current = record;
    afterAccept?.call();
    if (loseResponse) {
      loseResponse = false;
      throw const SocketException('Server accepted but response was lost');
    }
    if (mismatchedReceipt) {
      return WorkflowCommandReceipt(
        commandId: 'another-request',
        resultKey: receipt.resultKey,
        aggregateVersion: receipt.aggregateVersion,
        result: receipt.result,
        appliedAt: receipt.appliedAt,
      );
    }
    return receipt;
  }
}
