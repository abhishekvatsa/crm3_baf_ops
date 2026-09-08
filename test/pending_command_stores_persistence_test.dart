import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:crm3_baf_ops/features/assets/services/burner_condition_round_idempotency_store.dart';
import 'package:crm3_baf_ops/features/morning_review/services/morning_review_command_idempotency_store.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_idempotency_store.dart';
import 'package:crm3_baf_ops/features/quality/services/monitoring_creation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kinds = ['monitoring', 'morning', 'burner', 'assignment'];

void main() {
  for (final kind in _kinds) {
    test(
      '$kind preserves both independently dispatched lost-response intents',
      () async {
        final scenario = await _twoTabs(kind);
        final store = _store(
          kind,
          () async => _CachedPreferences(scenario.platform),
        );
        final recovered = <String>[];
        for (var index = 0; index < 2; index++) {
          final pending = await _pending(kind, store);
          expect(
            pending,
            isNotNull,
            reason: 'A second tab must not erase submitted work.',
          );
          recovered.add(pending!['requestId'] as String);
          await _clear(kind, store, pending);
        }
        expect(recovered.toSet(), scenario.accepted.toSet());
        expect(await _pending(kind, store), isNull);
      },
    );

    test('$kind requires durable write and removal readback', () async {
      final platform = <String, Object>{};
      final preferences = _CachedPreferences(platform)..dropWrites = true;
      final store = _store(kind, () async => preferences);
      await expectLater(_resolve(kind, store, 'a'), throwsA(anything));
      preferences.dropWrites = false;
      final pending = await _resolve(kind, store, 'a');
      preferences.retainOnRemove = true;
      await expectLater(_clear(kind, store, pending), throwsA(anything));
      expect((await _pending(kind, store))!['requestId'], pending['requestId']);
    });

    test(
      '$kind retains corrupt legacy evidence alongside newer intent',
      () async {
        final platform = <String, Object>{};
        final store = _store(kind, () async => _CachedPreferences(platform));
        await _resolve(kind, store, 'a');
        platform[_legacyKey(kind)] = '{broken';
        final before = Map<String, Object>.from(platform);
        expect(before, hasLength(2));
        await expectLater(_pending(kind, store), throwsA(anything));
        await expectLater(_resolve(kind, store, 'b'), throwsA(anything));
        expect(platform, before);
      },
    );

    test(
      '$kind reads and clears legacy intent without removing newer work',
      () async {
        final platform = <String, Object>{};
        final store = _store(kind, () async => _CachedPreferences(platform));
        final current = await _resolve(kind, store, 'a');
        final legacy = _legacyRecord(kind);
        final serialized = jsonEncode(legacy);
        platform[_legacyKey(kind)] = serialized;
        expect(
          (await _pending(kind, store))!['requestId'],
          legacy['requestId'],
        );
        expect(platform[_legacyKey(kind)], serialized);
        await _clear(kind, store, legacy);
        expect(
          (await _pending(kind, store))!['requestId'],
          current['requestId'],
        );
      },
    );
  }

  for (final kind in ['burner', 'assignment']) {
    test(
      '$kind isolates request namespaces from delimiter-bearing actor IDs',
      () async {
        final platform = <String, Object>{};
        final dynamic store = _store(
          kind,
          () async => _CachedPreferences(platform),
        );
        final dynamic first = await store.resolve(
          actorUid: 'actor-a',
          payloadFingerprint: 'a' * 64,
        );
        final otherActor = 'actor-a::${first.requestId}';
        final dynamic second = await store.resolve(
          actorUid: otherActor,
          payloadFingerprint: 'b' * 64,
        );
        await store.clearIfMatches(
          actorUid: 'actor-a',
          requestId: first.requestId,
        );
        expect(await store.read(actorUid: 'actor-a'), isNull);
        expect(
          (await store.read(actorUid: otherActor)).requestId,
          second.requestId,
        );
      },
    );

    test(
      '$kind restores P after Q without losing either request identity',
      () async {
        final platform = <String, Object>{};
        final store = _store(kind, () async => _CachedPreferences(platform));
        final first = await _resolve(kind, store, 'a');
        final second = await _resolve(kind, store, 'b');
        expect(second['requestId'], isNot(first['requestId']));
        final resumedStore = _store(
          kind,
          () async => _CachedPreferences(platform),
        );
        expect(
          (await _resolve(kind, resumedStore, 'a'))['requestId'],
          first['requestId'],
        );
        await _clear(kind, resumedStore, first);
        expect(
          (await _resolve(kind, resumedStore, 'b'))['requestId'],
          second['requestId'],
        );
      },
    );
  }
}

Object _store(String kind, Future<SharedPreferences> Function() load) =>
    switch (kind) {
      'monitoring' => MonitoringCreationStore(preferencesLoader: load),
      'morning' => MorningReviewCommandIdempotencyStore(
        preferencesLoader: load,
      ),
      'burner' => BurnerConditionRoundIdempotencyStore(preferencesLoader: load),
      _ => PublishedTemplateAssignmentIdempotencyStore(preferencesLoader: load),
    };

Future<Map<String, dynamic>> _resolve(
  String kind,
  Object store,
  String label,
) async {
  switch (kind) {
    case 'monitoring':
      return (store as MonitoringCreationStore).prepare('project:actor-a', {
        'baseNumber': 1,
        'baseAssetClassId': 'base-class',
        'baseAssetInstanceId': 'base-1',
        'baseAssetInstanceVersion': 1,
        'grade': 'grade',
        'cycleReference': label,
        'chargeNumbers': <int>[12345],
        'reason': 'reason $label',
      });
    case 'morning':
      final value = await (store as MorningReviewCommandIdempotencyStore)
          .resolve(
            actorUid: 'actor-a',
            operation: 'ADD_MORNING_REVIEW_ENTRY',
            sessionId: '2026-09-09',
            extra: {
              'entryDraft': {'text': label},
            },
          );
      return {
        'requestId': value.requestId,
        'payloadFingerprint': value.payloadFingerprint,
      };
    case 'burner':
      final value = await (store as BurnerConditionRoundIdempotencyStore)
          .resolve(actorUid: 'actor-a', payloadFingerprint: label * 64);
      return value.toMap();
    default:
      final value = await (store as PublishedTemplateAssignmentIdempotencyStore)
          .resolve(actorUid: 'actor-a', payloadFingerprint: label * 64);
      return value.toMap();
  }
}

Future<Map<String, dynamic>?> _pending(String kind, Object store) async {
  switch (kind) {
    case 'monitoring':
      return (store as MonitoringCreationStore).pending('project:actor-a');
    case 'morning':
      final value = await (store as MorningReviewCommandIdempotencyStore)
          .pending('actor-a');
      return value == null
          ? null
          : {
              'requestId': value.requestId,
              'payloadFingerprint': value.payloadFingerprint,
            };
    case 'burner':
      return (await (store as BurnerConditionRoundIdempotencyStore).read(
        actorUid: 'actor-a',
      ))?.toMap();
    default:
      return (await (store as PublishedTemplateAssignmentIdempotencyStore).read(
        actorUid: 'actor-a',
      ))?.toMap();
  }
}

Future<void> _clear(
  String kind,
  Object store,
  Map<String, dynamic> value,
) => switch (kind) {
  'monitoring' => (store as MonitoringCreationStore).complete(
    'project:actor-a',
    value['requestId'] as String,
  ),
  'morning' => (store as MorningReviewCommandIdempotencyStore).clearIfMatches(
    actorUid: 'actor-a',
    requestId: value['requestId'] as String,
    payloadFingerprint: value['payloadFingerprint'] as String,
  ),
  'burner' => (store as BurnerConditionRoundIdempotencyStore).clearIfMatches(
    actorUid: 'actor-a',
    requestId: value['requestId'] as String,
  ),
  _ => (store as PublishedTemplateAssignmentIdempotencyStore).clearIfMatches(
    actorUid: 'actor-a',
    requestId: value['requestId'] as String,
  ),
};

String _legacyKey(String kind) => switch (kind) {
  'monitoring' =>
    'PENDING_QUALITY_MONITORING::${Uri.encodeComponent('project:actor-a')}',
  'morning' =>
    'PENDING_MORNING_REVIEW_COMMAND::${sha256.convert(utf8.encode('actor-a'))}',
  'burner' => 'PENDING_BURNER_CONDITION_ROUND::actor-a',
  _ => 'PENDING_GOVERNED_ASSIGNMENT::actor-a',
};

Map<String, dynamic> _legacyRecord(String kind) {
  const requestId = '11111111-1111-4111-8111-111111111111';
  if (kind == 'monitoring') {
    return {
      'schemaVersion': 2,
      'requestId': requestId,
      'monitoringRequestId': '22222222-2222-4222-8222-222222222222',
      'operation': 'CREATE_QUALITY_MONITORING_REQUEST',
      'expectedVersion': 0,
      'baseNumber': 1,
      'baseAssetClassId': 'base-class',
      'baseAssetInstanceId': 'base-1',
      'baseAssetInstanceVersion': 1,
      'grade': 'grade',
      'cycleReference': 'legacy',
      'chargeNumbers': <int>[12345],
      'reason': 'legacy',
    };
  }
  if (kind == 'morning') {
    const extra = <String, dynamic>{
      'entryDraft': {'text': 'legacy'},
    };
    return {
      'schemaVersion': 1,
      'requestId': requestId,
      'operation': 'ADD_MORNING_REVIEW_ENTRY',
      'sessionId': '2026-09-09',
      'extra': extra,
      'payloadFingerprint': MorningReviewCommandIdempotencyStore.fingerprintFor(
        actorUid: 'actor-a',
        operation: 'ADD_MORNING_REVIEW_ENTRY',
        sessionId: '2026-09-09',
        extra: extra,
      ),
    };
  }
  return {'requestId': requestId, 'payloadFingerprint': 'c' * 64};
}

class _CachedPreferences extends Fake implements SharedPreferences {
  _CachedPreferences(this.platform) : cache = Map.from(platform);
  final Map<String, Object> platform;
  Map<String, Object> cache;
  bool retainOnRemove = false;
  bool dropWrites = false;
  @override
  Future<void> reload() async => cache = Map.from(platform);
  @override
  Set<String> getKeys() => cache.keys.toSet();
  @override
  String? getString(String key) => cache[key] as String?;
  @override
  Future<bool> setString(String key, String value) async {
    cache[key] = value;
    if (!dropWrites) platform[key] = value;
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
  final List<String> accepted;
}

Future<_TabScenario> _twoTabs(String kind) async {
  final messages = ReceivePort();
  final platform = <String, Object>{};
  final firstReads = <String, SendPort>{};
  final accepted = <String>[];
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
        accepted.add(message['requestId'] as String);
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
        await Isolate.spawn(_independentTab, {
          'port': messages.sendPort,
          'tab': tab,
          'storeKind': kind,
        }),
      );
    }
    await complete.future.timeout(const Duration(seconds: 15));
    expect(accepted.toSet(), hasLength(2));
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
  final kind = args['storeKind'] as String;
  try {
    final preferences = _RemoteCachedPreferences(port, tab);
    // Older fingerprint-only stores do not reload themselves. Their loader
    // receives an independently captured platform snapshot, as a new tab does.
    if (kind == 'burner' || kind == 'assignment') await preferences.reload();
    final store = _store(kind, () async => preferences);
    final identity = await _resolve(kind, store, tab);
    port.send({
      'tab': tab,
      'kind': 'dispatched-response-lost',
      'requestId': identity['requestId'],
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
  Future<bool> setString(String key, String value) async {
    cache[key] = value;
    return await _ask('set', {'key': key, 'value': value}) as bool;
  }
}
