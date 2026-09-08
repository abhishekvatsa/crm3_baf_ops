import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_creation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final samePayload in [false, true]) {
    test('independently cached tabs retain both lost-response intents '
        '(same payload: $samePayload)', () async {
      final scenario = await _twoTabs(samePayload: samePayload);
      final platform = scenario.platform;
      final store = OperationalEventCreationStore(
        preferencesLoader: () async => _CachedPreferences(platform),
      );
      final replayed = <Map<String, dynamic>>[];
      for (var index = 0; index < 2; index++) {
        final pending = await store.pending('actor-a');
        expect(
          pending,
          isNotNull,
          reason: 'Every dispatched intent must survive tab loss/restart.',
        );
        replayed.add(pending!.toRequest());
        // This is the same accepted server request, not a newly minted event.
        expect(scenario.accepted, contains(equals(pending.toRequest())));
        await store.clearIfMatches(actorUid: 'actor-a', identity: pending);
      }
      expect(await store.pending('actor-a'), isNull);
      expect(replayed.toSet(), hasLength(2));
      expect(replayed.first, scenario.accepted.first);
      expect(
        replayed.map((value) => value['requestId']).toSet(),
        scenario.accepted.map((value) => value['requestId']).toSet(),
      );
    });
  }

  test(
    'clearing an exact intent preserves another tab and another actor',
    () async {
      final scenario = await _twoTabs();
      final store = OperationalEventCreationStore(
        preferencesLoader: () async => _CachedPreferences(scenario.platform),
      );
      final otherActor = await store.resolve(
        actorUid: 'actor-b',
        payload: _payload('B'),
      );
      final first = (await store.pending('actor-a'))!;
      final impostor = PendingOperationalEventCreation(
        requestId: first.requestId,
        eventId: otherActor.eventId,
        payloadFingerprint: first.payloadFingerprint,
        payload: first.payload,
      );
      final before = Map<String, Object>.from(scenario.platform);
      await store.clearIfMatches(actorUid: 'actor-a', identity: impostor);
      await store.clearIfMatches(actorUid: 'actor-b', identity: first);
      expect(scenario.platform, before);
      await store.clearIfMatches(actorUid: 'actor-a', identity: first);
      final next = await store.pending('actor-a');
      expect(next, isNotNull);
      expect(next!.requestId, isNot(first.requestId));
      expect((await store.pending('actor-b'))!.requestId, otherActor.requestId);
    },
  );

  test(
    'legacy intent remains first and exact clearing preserves newer records',
    () async {
      final scenario = await _twoTabs();
      final legacy = _legacyRecord();
      scenario.platform[_actorKey('actor-a')] = jsonEncode(legacy);
      final store = OperationalEventCreationStore(
        preferencesLoader: () async => _CachedPreferences(scenario.platform),
      );
      final pending = (await store.pending('actor-a'))!;
      expect(pending.requestId, legacy['requestId']);
      expect(
        (await store.resolve(
          actorUid: 'actor-a',
          payload: _payload('legacy'),
        )).requestId,
        pending.requestId,
      );
      final before = Map<String, Object>.from(scenario.platform)
        ..remove(_actorKey('actor-a'));
      await store.clearIfMatches(actorUid: 'actor-a', identity: pending);
      expect(scenario.platform, before);
      expect(await store.pending('actor-a'), isNotNull);
    },
  );

  test(
    'legacy corruption preserves all records and cannot be replaced',
    () async {
      final platform = <String, Object>{};
      final store = OperationalEventCreationStore(
        preferencesLoader: () async => _CachedPreferences(platform),
      );
      await store.resolve(actorUid: 'actor-a', payload: _payload('new'));
      platform[_actorKey('actor-a')] = '{damaged legacy record';
      final before = Map<String, Object>.from(platform);
      expect(before, hasLength(2));
      await expectLater(store.pending('actor-a'), throwsStateError);
      await expectLater(
        store.resolve(actorUid: 'actor-a', payload: _payload('replacement')),
        throwsStateError,
      );
      expect(platform, before);
    },
  );

  test(
    'a successful remove acknowledgement requires durable readback',
    () async {
      final platform = <String, Object>{};
      final preferences = _CachedPreferences(platform)..retainOnRemove = true;
      final store = OperationalEventCreationStore(
        preferencesLoader: () async => preferences,
      );
      final identity = await store.resolve(
        actorUid: 'actor-a',
        payload: _payload('A'),
      );
      await expectLater(
        store.clearIfMatches(actorUid: 'actor-a', identity: identity),
        throwsStateError,
      );
      expect((await store.pending('actor-a'))!.requestId, identity.requestId);
    },
  );
  for (final field in ['requestId', 'eventId', 'payloadFingerprint']) {
    test('dispatch cannot adopt a different persisted $field', () async {
      final platform = <String, Object>{};
      final preferences = _CachedPreferences(platform)
        ..afterWrite = (key, raw) {
          final record = jsonDecode(raw) as Map<String, dynamic>;
          record[field] = field == 'payloadFingerprint'
              ? 'wrong fingerprint'
              : 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
          platform[key] = jsonEncode(record);
        };
      final store = OperationalEventCreationStore(
        preferencesLoader: () async => preferences,
      );
      await expectLater(
        store.resolve(actorUid: 'actor-a', payload: _payload('A')),
        throwsStateError,
      );
      expect(platform, hasLength(1));
      expect(
        (jsonDecode(platform.values.single as String) as Map)[field],
        field == 'payloadFingerprint'
            ? 'wrong fingerprint'
            : 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      );
    });
  }

  for (final damage in ['key', 'schema', 'chronology', 'payload', 'type']) {
    test(
      'damaged request-slot $damage is retained without new intent',
      () async {
        final platform = <String, Object>{};
        final store = OperationalEventCreationStore(
          preferencesLoader: () async => _CachedPreferences(platform),
        );
        await store.resolve(actorUid: 'actor-a', payload: _payload('A'));
        final key = platform.keys.single;
        final record =
            jsonDecode(platform[key] as String) as Map<String, dynamic>;
        switch (damage) {
          case 'key':
            platform['${_actorKey('actor-a')}::wrong-request-id'] = platform
                .remove(key)!;
            break;
          case 'schema':
            record['schemaVersion'] = 1;
            platform[key] = jsonEncode(record);
            break;
          case 'chronology':
            record['savedAtMicros'] = 'yesterday';
            platform[key] = jsonEncode(record);
            break;
          case 'payload':
            (record['payload'] as Map)['reason'] = 'Changed reason';
            platform[key] = jsonEncode(record);
            break;
          case 'type':
            platform[key] = true;
            break;
        }
        final before = Map<String, Object>.from(platform);
        await expectLater(store.pending('actor-a'), throwsStateError);
        await expectLater(
          store.resolve(actorUid: 'actor-a', payload: _payload('B')),
          throwsStateError,
        );
        expect(platform, before);
        expect(await store.pending('actor-b'), isNull);
      },
    );
  }
}

Map<String, dynamic> _payload(String reason) => <String, dynamic>{
  'reason': reason,
  'eventDraft': <String, dynamic>{
    'eventType': 'powerTrip',
    'title': 'Power interrupted',
    'description': 'Incoming supply was lost.',
    'severity': 'critical',
    'scope': 'plantWide',
    'affectedAssetClassIds': <String>[],
    'affectedAssetInstanceIds': <String>[],
    'startedAt': '2026-08-14T10:00:00.000Z',
  },
};

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String _actorKey(String actor) =>
    'PENDING_OPERATIONAL_EVENT_CREATION::'
    '${sha256.convert(utf8.encode(actor))}';

Map<String, dynamic> _legacyRecord() {
  final payload = _payload('legacy');
  return <String, dynamic>{
    'schemaVersion': 1,
    'requestId': '11111111-1111-4111-8111-111111111111',
    'eventId': '22222222-2222-4222-8222-222222222222',
    'payloadFingerprint': sha256
        .convert(
          utf8.encode(
            jsonEncode(_canonical({'actorUid': 'actor-a', 'payload': payload})),
          ),
        )
        .toString(),
    'payload': payload,
  };
}

class _CachedPreferences extends Fake implements SharedPreferences {
  _CachedPreferences(this.platform);
  final Map<String, Object> platform;
  Map<String, Object> cache = {};
  bool retainOnRemove = false;
  void Function(String, String)? afterWrite;

  @override
  Future<void> reload() async => cache = Map.from(platform);
  @override
  Set<String> getKeys() => cache.keys.toSet();
  @override
  String? getString(String key) => cache[key] as String?;
  @override
  Future<bool> setString(String key, String value) async {
    platform[key] = value;
    cache[key] = value;
    afterWrite?.call(key, value);
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    cache.remove(key);
    if (!retainOnRemove) platform.remove(key);
    return true;
  }
}

class _TabScenario {
  _TabScenario(this.platform, this.accepted);
  final Map<String, Object> platform;
  final List<Map<String, dynamic>> accepted;
}

/// Each isolate owns its preferences cache and the store's isolate-local tail.
/// Both initial reloads capture empty durable storage. A dispatches and loses
/// its response before B resumes its already captured empty read and writes.
Future<_TabScenario> _twoTabs({bool samePayload = false}) async {
  final messages = ReceivePort();
  final platform = <String, Object>{};
  final firstReads = <String, SendPort>{};
  final accepted = <Map<String, dynamic>>[];
  final complete = Completer<void>();
  final workers = <Isolate>[];
  final subscription = messages.listen((dynamic value) {
    final message = Map<String, dynamic>.from(value as Map);
    final reply = message['reply'] as SendPort?;
    final tab = message['tab'] as String;
    switch (message['kind']) {
      case 'reload':
        if (!firstReads.containsKey(tab)) {
          firstReads[tab] = reply!;
          if (firstReads.length == 2) firstReads['a']!.send(<String, Object>{});
        } else {
          reply!.send(Map<String, Object>.from(platform));
        }
        break;
      case 'set':
        platform[message['key'] as String] = message['value'] as String;
        reply!.send(true);
        break;
      case 'dispatched-response-lost':
        accepted.add(Map<String, dynamic>.from(message['request'] as Map));
        if (tab == 'a') firstReads['b']!.send(<String, Object>{});
        if (accepted.length == 2) complete.complete();
        break;
      case 'failed':
        if (!complete.isCompleted) {
          complete.completeError(StateError(message['error'] as String));
        }
        break;
    }
  });
  try {
    for (final tab in ['a', 'b']) {
      workers.add(
        await Isolate.spawn(_independentTab, <String, dynamic>{
          'port': messages.sendPort,
          'tab': tab,
          'payload': _payload(samePayload ? 'same event' : 'event $tab'),
        }),
      );
    }
    await complete.future.timeout(const Duration(seconds: 15));
    expect(accepted.map((value) => value['requestId']).toSet(), hasLength(2));
    return _TabScenario(platform, accepted);
  } finally {
    for (final worker in workers) {
      worker.kill(priority: Isolate.immediate);
    }
    await subscription.cancel();
    messages.close();
  }
}

Future<void> _independentTab(Map<String, dynamic> args) async {
  final port = args['port'] as SendPort;
  final tab = args['tab'] as String;
  try {
    final preferences = _RemoteCachedPreferences(port, tab);
    final store = OperationalEventCreationStore(
      preferencesLoader: () async => preferences,
    );
    final identity = await store.resolve(
      actorUid: 'actor-a',
      payload: Map<String, dynamic>.from(args['payload'] as Map),
    );
    port.send({
      'tab': tab,
      'kind': 'dispatched-response-lost',
      'request': identity.toRequest(),
    });
  } catch (error, stack) {
    port.send({'tab': tab, 'kind': 'failed', 'error': '$error\n$stack'});
  }
}

class _RemoteCachedPreferences extends Fake implements SharedPreferences {
  _RemoteCachedPreferences(this.port, this.tab);
  final SendPort port;
  final String tab;
  Map<String, Object> cache = {};
  Future<dynamic> _ask(
    String kind, [
    Map<String, dynamic> fields = const {},
  ]) async {
    final answer = ReceivePort();
    port.send({'tab': tab, 'reply': answer.sendPort, 'kind': kind, ...fields});
    final value = await answer.first;
    answer.close();
    return value;
  }

  @override
  Future<void> reload() async =>
      cache = Map<String, Object>.from(await _ask('reload') as Map);
  @override
  Set<String> getKeys() => cache.keys.toSet();
  @override
  String? getString(String key) => cache[key] as String?;
  @override
  Future<bool> setString(String key, String value) async =>
      await _ask('set', {'key': key, 'value': value}) as bool;
}
