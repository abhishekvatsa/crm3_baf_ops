import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_service.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_creation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  OperationalEventDraft draft() => OperationalEventDraft(
    eventType: OperationalEventType.powerTrip,
    title: 'Incoming power interruption',
    description: 'Incoming supply was lost across the shop.',
    severity: OperationalEventSeverity.critical,
    scope: OperationalEventScope.plantWide,
    affectedAssetClassIds: const [],
    affectedAssetInstanceIds: const [],
    startedAt: DateTime.utc(2026, 8, 14, 10),
  );

  OperationalEventDraft scopedDraft({
    required bool assets,
    required int count,
    bool duplicateLast = false,
  }) {
    final ids = List.generate(
      count,
      (index) => 'selected-${duplicateLast && index == count - 1 ? 0 : index}',
    );
    return OperationalEventDraft(
      eventType: OperationalEventType.powerTrip,
      title: 'Selected equipment interruption',
      description: 'Record the selected equipment affected by the supply loss.',
      severity: OperationalEventSeverity.critical,
      scope: assets
          ? OperationalEventScope.assets
          : OperationalEventScope.assetClasses,
      affectedAssetClassIds: assets ? const ['asset-class'] : ids,
      affectedAssetInstanceIds: assets ? ids : const [],
      startedAt: DateTime.utc(2026, 8, 14, 10),
    );
  }

  for (final assets in [false, true]) {
    final maximum = assets ? 50 : 20;
    final label = assets ? 'assets' : 'classes';
    test(
      'oversized CREATE $label selections save nothing and send nothing',
      () async {
        final functions = _RecordingFunctions()..loseFirstResponse = false;
        final service = OperationalEventService(
          functions: functions,
          actorUidResolver: () => 'actor-a',
        );
        await expectLater(
          service.create(
            draft: scopedDraft(assets: assets, count: maximum + 1),
            reason: 'Original reason',
          ),
          throwsA(
            isA<OperationalEventCommandException>().having(
              (error) => error.code,
              'code',
              'invalid-argument',
            ),
          ),
        );
        expect(await service.pendingCreation(), isNull);
        expect(functions.requests, isEmpty);
        await service.create(
          draft: scopedDraft(assets: assets, count: maximum),
          reason: 'Corrected selection',
        );
        expect(functions.requests, hasLength(1));
        expect(await service.pendingCreation(), isNull);
      },
    );

    test('CREATE $label limits count normalized unique selections', () async {
      final functions = _RecordingFunctions()..loseFirstResponse = false;
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await service.create(
        draft: scopedDraft(
          assets: assets,
          count: maximum + 1,
          duplicateLast: true,
        ),
        reason: 'Record unique selection',
      );
      final eventDraft = functions.requests.single['eventDraft'] as Map;
      expect(
        eventDraft[assets
            ? 'affectedAssetInstanceIds'
            : 'affectedAssetClassIds'],
        hasLength(maximum),
      );
    });

    test(
      'oversized CREATE $label selections cannot replace an existing pending intent',
      () async {
        final functions = _RecordingFunctions();
        final service = OperationalEventService(
          functions: functions,
          actorUidResolver: () => 'actor-a',
        );
        await expectLater(
          service.create(draft: draft(), reason: 'Original reason'),
          throwsA(isA<OperationalEventCommandException>()),
        );
        final pending = await service.pendingCreation();
        await expectLater(
          service.create(
            draft: scopedDraft(assets: assets, count: maximum + 1),
            reason: 'Oversized selection',
          ),
          throwsA(
            isA<OperationalEventCommandException>().having(
              (error) => error.code,
              'code',
              'invalid-argument',
            ),
          ),
        );
        expect(functions.requests, hasLength(1));
        expect(
          (await service.pendingCreation())?.requestId,
          pending?.requestId,
        );
        expect(
          (await service.pendingCreation())?.payloadFingerprint,
          pending?.payloadFingerprint,
        );
      },
    );
  }

  test(
    'restart can retry saved payload without reconstructing the form',
    () async {
      final functions = _RecordingFunctions();
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      final restarted = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      expect(
        (await restarted.pendingCreation())?.payload['reason'],
        'Original reason',
      );
      await restarted.retryPendingCreation();
      expect(functions.requests[1], functions.requests[0]);
      expect(await restarted.pendingCreation(), isNull);
    },
  );

  test(
    'uncertain creation cannot be overwritten by an edited payload',
    () async {
      final functions = _RecordingFunctions();
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Changed reason'),
        throwsStateError,
      );
      expect(functions.requests, hasLength(1));
      expect(
        (await service.pendingCreation())?.payload['reason'],
        'Original reason',
      );
    },
  );

  test(
    'a confirmed event does not deduplicate a genuine new identical event',
    () async {
      final functions = _RecordingFunctions()..loseFirstResponse = false;
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await service.create(draft: draft(), reason: 'Same reason');
      await service.create(draft: draft(), reason: 'Same reason');
      expect(
        functions.requests[1]['eventId'],
        isNot(functions.requests[0]['eventId']),
      );
      expect(
        functions.requests[1]['requestId'],
        isNot(functions.requests[0]['requestId']),
      );
    },
  );

  test(
    'pending payload and identity remain scoped to the original actor',
    () async {
      final functions = _RecordingFunctions();
      var actorUid = 'actor-a';
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => actorUid,
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Same reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      actorUid = 'actor-b';
      expect(await service.pendingCreation(), isNull);
      await service.create(draft: draft(), reason: 'Same reason');
      expect(
        functions.requests[1]['eventId'],
        isNot(functions.requests[0]['eventId']),
      );
      actorUid = 'actor-a';
      await service.retryPendingCreation();
      expect(functions.requests[2], functions.requests[0]);
    },
  );

  test(
    'account change during storage blocks dispatch and preserves original intent',
    () async {
      final functions = _RecordingFunctions()..loseFirstResponse = false;
      var actorUid = 'actor-a';
      final store = OperationalEventCreationStore(
        preferencesLoader: () async {
          actorUid = 'actor-b';
          return SharedPreferences.getInstance();
        },
      );
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => actorUid,
        creationStore: store,
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(functions.requests, isEmpty);
      expect(await store.pending('actor-a'), isNotNull);
      expect(await store.pending('actor-b'), isNull);
    },
  );

  test('failed durable write sends no event', () async {
    final functions = _RecordingFunctions()..loseFirstResponse = false;
    final service = OperationalEventService(
      functions: functions,
      actorUidResolver: () => 'actor-a',
      creationStore: OperationalEventCreationStore(
        preferencesLoader: () async => _RejectingPreferences(),
      ),
    );
    await expectLater(
      service.create(draft: draft(), reason: 'Original reason'),
      throwsStateError,
    );
    expect(functions.requests, isEmpty);
  });

  test(
    'successful write acknowledgement without durable readback sends no event',
    () async {
      final functions = _RecordingFunctions()..loseFirstResponse = false;
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
        creationStore: OperationalEventCreationStore(
          preferencesLoader: () async =>
              _RejectingPreferences(pretendSuccess: true),
        ),
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsStateError,
      );
      expect(functions.requests, isEmpty);
    },
  );

  test(
    'actor change after response preserves original pending evidence',
    () async {
      var actorUid = 'actor-a';
      final functions = _RecordingFunctions()
        ..loseFirstResponse = false
        ..beforeReply = () => actorUid = 'actor-b';
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => actorUid,
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(await service.pendingCreation(), isNull);
      actorUid = 'actor-a';
      expect(await service.pendingCreation(), isNotNull);
    },
  );

  test(
    'a form opened for another actor cannot dispatch under the new account',
    () async {
      final functions = _RecordingFunctions()..loseFirstResponse = false;
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-b',
      );
      await expectLater(
        service.create(
          draft: draft(),
          reason: 'Original reason',
          expectedActorUid: 'actor-a',
        ),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(functions.requests, isEmpty);
    },
  );

  test('mismatched response cannot clear the saved creation', () async {
    final functions = _RecordingFunctions()
      ..loseFirstResponse = false
      ..malformedResponse = true;
    final service = OperationalEventService(
      functions: functions,
      actorUidResolver: () => 'actor-a',
    );
    await expectLater(
      service.create(draft: draft(), reason: 'Original reason'),
      throwsA(isA<OperationalEventCommandException>()),
    );
    expect(await service.pendingCreation(), isNotNull);
  });

  test(
    'definitive rejection releases saved intent for a corrected event',
    () async {
      final functions = _RecordingFunctions()
        ..loseFirstResponse = false
        ..terminalRejection = true;
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(await service.pendingCreation(), isNull);
      functions.terminalRejection = false;
      await service.create(draft: draft(), reason: 'Corrected reason');
      expect(
        functions.requests.last['requestId'],
        isNot(functions.requests.first['requestId']),
      );
    },
  );

  test(
    'ordinary domain errors without a committed receipt retain saved intent',
    () async {
      final functions = _RecordingFunctions()
        ..loseFirstResponse = false
        ..domainRejection = true;
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(await service.pendingCreation(), isNotNull);
    },
  );

  test(
    'committed asset reclassification rejection releases saved intent',
    () async {
      final functions = _RecordingFunctions()
        ..loseFirstResponse = false
        ..terminalRejection = true
        ..rejectionReasonCode = 'operational-event-asset-class-mismatch';
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(await service.pendingCreation(), isNull);
    },
  );

  test(
    'lost rejection response retains intent until restarted exact retry',
    () async {
      final functions = _RecordingFunctions()..terminalRejection = true;
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(await service.pendingCreation(), isNotNull);
      final restarted = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        restarted.retryPendingCreation(),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(functions.requests.last, functions.requests.first);
      expect(await restarted.pendingCreation(), isNull);
    },
  );

  test(
    'future-start rejection after response loss lets the restarted user correct the clock',
    () async {
      final functions = _RecordingFunctions()
        ..terminalRejection = true
        ..rejectionReasonCode = 'operational-event-started-at-future';
      final futureDraft = OperationalEventDraft(
        eventType: OperationalEventType.powerTrip,
        title: 'Clock-ahead event',
        description: 'Recorded with the phone clock ten years ahead.',
        severity: OperationalEventSeverity.critical,
        scope: OperationalEventScope.plantWide,
        affectedAssetClassIds: const [],
        affectedAssetInstanceIds: const [],
        startedAt: DateTime.utc(2036, 8, 14, 13),
      );
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        service.create(draft: futureDraft, reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(await service.pendingCreation(), isNotNull);
      final restarted = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        restarted.retryPendingCreation(),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(functions.requests.last, functions.requests.first);
      expect(await restarted.pendingCreation(), isNull);
      functions.terminalRejection = false;
      await restarted.create(draft: draft(), reason: 'Corrected phone clock');
      expect(
        functions.requests.last['requestId'],
        isNot(functions.requests.first['requestId']),
      );
    },
  );

  for (final field in [
    'requestId',
    'eventId',
    'actorUid',
    'operation',
    'fingerprint',
    'committedAt',
    'outcome',
    'schemaVersion',
  ]) {
    test('wrong terminal rejection $field retains evidence', () async {
      final functions = _RecordingFunctions()
        ..loseFirstResponse = false
        ..terminalRejection = true
        ..wrongRejectionField = field;
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(await service.pendingCreation(), isNotNull);
    });
  }

  test(
    'new creation guards the actor during callable token acquisition',
    () async {
      final functions = _RecordingFunctions()..loseFirstResponse = false;
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await service.create(draft: draft(), reason: 'Original reason');
      expect(functions.requests.single['expectedActorUid'], 'actor-a');
    },
  );

  test(
    'token account switch cannot consume another actors saved intent',
    () async {
      final functions = _RecordingFunctions()
        ..loseFirstResponse = false
        ..authenticatedActorUid = 'actor-b';
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'actor-a',
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      expect(await service.pendingCreation(), isNotNull);
      functions.authenticatedActorUid = 'actor-a';
      await service.retryPendingCreation();
      expect(functions.requests.last, functions.requests.first);
      expect(await service.pendingCreation(), isNull);
    },
  );

  test('creation fingerprint matches the real server normalization fixture', () {
    const identity = PendingOperationalEventCreation(
      requestId: '22222222-2222-4222-8222-222222222222',
      eventId: '11111111-1111-4111-8111-111111111111',
      payloadFingerprint: 'unused',
      payload: <String, dynamic>{
        'reason': '  Record affected equipment.  ',
        'eventDraft': <String, dynamic>{
          'eventType': 'powerTrip',
          'title': '  Power interruption  ',
          'description': '  Supply lost.  ',
          'severity': 'critical',
          'scope': 'assets',
          'affectedAssetClassIds': ['z-class', 'a-class'],
          'affectedAssetInstanceIds': ['z-asset', 'a-asset'],
          'startedAt': '2026-08-14T10:00:00.000Z',
        },
      },
    );
    expect(
      identity.commandFingerprint,
      'operationalevent1-sha256:dd617524615b87af9537a844f02d8ad7d5d5463c501ccb9f5cfcaddd9f3d0c4b',
    );
  });

  test(
    'actor changes after terminal rejection preserve the original evidence',
    () async {
      var actor = 'actor-a';
      final functions = _RecordingFunctions()
        ..loseFirstResponse = false
        ..terminalRejection = true
        ..beforeReply = () => actor = 'actor-b';
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => actor,
      );
      await expectLater(
        service.create(draft: draft(), reason: 'Original reason'),
        throwsA(isA<OperationalEventCommandException>()),
      );
      actor = 'actor-a';
      expect(await service.pendingCreation(), isNotNull);
    },
  );

  test('concurrent store instances preserve one unresolved identity', () async {
    final payload = <String, dynamic>{
      'reason': 'Original reason',
      'eventDraft': draft().toCommandMap(),
    };
    final identities = await Future.wait(
      List.generate(
        8,
        (_) => OperationalEventCreationStore().resolve(
          actorUid: 'actor-a',
          payload: payload,
        ),
      ),
    );
    expect(identities.map((value) => value.requestId).toSet(), hasLength(1));
    expect(identities.map((value) => value.eventId).toSet(), hasLength(1));
  });

  test(
    'corrupt pending payload fails closed without replacing evidence',
    () async {
      final store = OperationalEventCreationStore();
      await store.resolve(
        actorUid: 'actor-a',
        payload: <String, dynamic>{
          'reason': 'Original reason',
          'eventDraft': draft().toCommandMap(),
        },
      );
      final preferences = await SharedPreferences.getInstance();
      final key = preferences.getKeys().single;
      final corrupt =
          jsonDecode(preferences.getString(key)!) as Map<String, dynamic>;
      (corrupt['payload'] as Map<String, dynamic>)['reason'] =
          'Changed after persistence';
      final raw = jsonEncode(corrupt);
      await preferences.setString(key, raw);
      await expectLater(store.pending('actor-a'), throwsStateError);
      expect(preferences.getString(key), raw);
    },
  );

  test(
    'lost create response and restarted service retry one physical event',
    () async {
      final functions = _RecordingFunctions();
      final draft = OperationalEventDraft(
        eventType: OperationalEventType.powerTrip,
        title: 'Incoming power interruption',
        description: 'Incoming supply was lost across the shop.',
        severity: OperationalEventSeverity.critical,
        scope: OperationalEventScope.plantWide,
        affectedAssetClassIds: const [],
        affectedAssetInstanceIds: const [],
        startedAt: DateTime.utc(2026, 8, 14, 10),
      );
      final service = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'operations-1',
      );
      await expectLater(
        service.create(draft: draft, reason: 'Record interrupted supply.'),
        throwsA(isA<OperationalEventCommandException>()),
      );

      final restarted = OperationalEventService(
        functions: functions,
        actorUidResolver: () => 'operations-1',
      );
      await restarted.create(
        draft: draft,
        reason: 'Record interrupted supply.',
      );

      expect(functions.requests, hasLength(2));
      expect(functions.requests[1], functions.requests[0]);
    },
  );
}

class _RecordingFunctions extends Fake implements FirebaseFunctions {
  final requests = <Map<String, dynamic>>[];
  bool loseFirstResponse = true;
  bool malformedResponse = false;
  bool terminalRejection = false;
  bool domainRejection = false;
  String rejectionReasonCode = 'operational-event-asset-invalid';
  String? wrongRejectionField;
  String? authenticatedActorUid;
  void Function()? beforeReply;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _RecordingCallable(this);
}

class _RecordingCallable extends Fake implements HttpsCallable {
  _RecordingCallable(this.owner);
  final _RecordingFunctions owner;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final request = Map<String, dynamic>.from(parameters as Map);
    owner.requests.add(request);
    if (owner.authenticatedActorUid != null &&
        request['expectedActorUid'] != null &&
        request['expectedActorUid'] != owner.authenticatedActorUid) {
      throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'The signed-in account changed before the event was sent.',
      );
    }
    if (owner.requests.length == 1 && owner.loseFirstResponse) {
      throw FirebaseFunctionsException(
        code: 'unavailable',
        message: 'Response lost after server accepted the event.',
      );
    }
    owner.beforeReply?.call();
    if (owner.domainRejection) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Affected asset was retired.',
        details: const <String, dynamic>{
          'reasonCode': 'operational-event-asset-invalid',
        },
      );
    }
    if (owner.terminalRejection) {
      final proof = <String, dynamic>{
        'schemaVersion': 1,
        'outcome': 'rejected',
        'requestId': request['requestId'],
        'eventId': request['eventId'],
        'actorUid': 'actor-a',
        'operation': request['operation'],
        'fingerprint': _serverFingerprint(request),
        'committedAt': '2026-08-14T12:00:00.000Z',
      };
      if (owner.wrongRejectionField != null) {
        proof[owner.wrongRejectionField!] = 'wrong';
      }
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message:
            owner.rejectionReasonCode == 'operational-event-started-at-future'
            ? 'An operational event cannot start after the current server time.'
            : 'Affected asset was retired.',
        details: <String, dynamic>{
          'reasonCode': owner.rejectionReasonCode,
          'terminalRejection': proof,
        },
      );
    }
    return _Result<T>(
      <String, dynamic>{
            'ok': true,
            'requestId': request['requestId'],
            'operation': request['operation'],
            'eventId': owner.malformedResponse
                ? 'wrong-event'
                : request['eventId'],
            'status': 'open',
            'version': 1,
            'auditId': 'operational_event_${request['requestId']}',
            'committedAt': '2026-08-14T12:00:00.000Z',
            'idempotentReplay': true,
          }
          as T,
    );
  }
}

String _serverFingerprint(Map<String, dynamic> request) {
  final draft = Map<String, dynamic>.from(request['eventDraft'] as Map);
  draft['startedAtIso'] = draft.remove('startedAt');
  final normalized = <String, dynamic>{
    'requestId': request['requestId'],
    'eventId': request['eventId'],
    'operation': request['operation'],
    'expectedVersion': 0,
    'reason': request['reason'],
    'eventDraft': draft,
    'resolutionNote': null,
  };
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: canonical(value[key]),
      };
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  return 'operationalevent1-sha256:${sha256.convert(utf8.encode(jsonEncode(canonical(normalized))))}';
}

class _RejectingPreferences extends Fake implements SharedPreferences {
  _RejectingPreferences({this.pretendSuccess = false});
  final bool pretendSuccess;
  @override
  Future<void> reload() async {}
  @override
  String? getString(String key) => null;
  @override
  Future<bool> setString(String key, String value) async => pretendSuccess;
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}
