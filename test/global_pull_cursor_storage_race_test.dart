import 'dart:async';

import 'package:crm3_baf_ops/core/services/global_pull_cursor_store.dart';
import 'package:crm3_baf_ops/core/services/global_pull_protocol.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('plugins.flutter.io/shared_preferences');
const _actor = 'cursor-race-operator';
const _generation = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Object> persisted;
  late SharedPreferences preferences;
  late SharedPreferencesGlobalPullCursorStore store;
  late GlobalPullRunEnvelope prepared;
  late String key;
  Future<bool> Function(String, Object)? write;
  PlatformException? readFailure;

  setUp(() async {
    SharedPreferences.resetStatic();
    persisted = <String, Object>{};
    write = null;
    readFailure = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'getAll') {
            if (readFailure != null) throw readFailure!;
            return Map<String, Object>.from(persisted);
          }
          if (call.method == 'setString') {
            final arguments = call.arguments as Map;
            final wireKey = arguments['key'] as String;
            final value = arguments['value'] as Object;
            if (write != null) return write!(wireKey, value);
            persisted[wireKey] = value;
            return true;
          }
          throw StateError('Unexpected preferences operation ${call.method}');
        });
    preferences = await SharedPreferences.getInstance();
    store = SharedPreferencesGlobalPullCursorStore(preferences);
    prepared = await store.begin(
      actorUid: _actor,
      databaseGenerationId: _generation,
      authority: GlobalPullRunAuthority(
        actorUid: _actor,
        authorityDigest:
            'auth1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        activatedAt: DateTime.utc(2026, 9, 27, 1),
        serverAnchor: DateTime.utc(2026, 9, 27, 2),
      ),
      runId: '11111111-1111-4111-8111-111111111111',
    );
    key = store.keyFor(actorUid: _actor, databaseGenerationId: _generation);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    SharedPreferences.resetStatic();
  });

  test('unrelated reload during a cursor write cannot falsify readback', () async {
    final entered = Completer<void>();
    final finishWrite = Completer<void>();
    write = (wireKey, value) async {
      entered.complete();
      await finishWrite.future;
      persisted[wireKey] = value;
      return true;
    };

    final completion = store.completeDomain(
      prepared,
      GlobalPullDomain.knowledgeBase,
    );
    await entered.future;
    // Assignment retry loads its journal with reload() on this same singleton.
    // The native cursor write has not completed, so this legitimately reads the
    // previous envelope and replaces the plugin's optimistic cache.
    await preferences.reload();
    expect(preferences.getString(key), prepared.encode());
    finishWrite.complete();

    final completed = await completion;
    expect(
      completed.cursorFor(GlobalPullDomain.knowledgeBase).completedInRun,
      isTrue,
    );
    expect(persisted['flutter.$key'], completed.encode());
    expect(
      store.read(actorUid: _actor, databaseGenerationId: _generation)?.encode(),
      completed.encode(),
    );
  });

  test(
    'successful acknowledgement without persisted bytes still fails closed',
    () async {
      write = (_, _) async => true;
      await expectLater(
        store.completeDomain(prepared, GlobalPullDomain.knowledgeBase),
        throwsA(
          isA<GlobalPullCursorException>().having(
            (error) => error.reasonCode,
            'reason',
            'cursor-write-failed',
          ),
        ),
      );
      expect(persisted['flutter.$key'], prepared.encode());
    },
  );

  test(
    'storage returning different bytes still fails the exact readback',
    () async {
      write = (wireKey, _) async {
        persisted[wireKey] = 'corrupt cursor bytes';
        return true;
      };
      await expectLater(
        store.completeDomain(prepared, GlobalPullDomain.knowledgeBase),
        throwsA(
          isA<GlobalPullCursorException>().having(
            (error) => error.reasonCode,
            'reason',
            'cursor-write-failed',
          ),
        ),
      );
      expect(persisted['flutter.$key'], 'corrupt cursor bytes');
    },
  );

  test('false native write acknowledgement remains a write failure', () async {
    write = (wireKey, value) async {
      persisted[wireKey] = value;
      return false;
    };
    await expectLater(
      store.completeDomain(prepared, GlobalPullDomain.knowledgeBase),
      throwsA(
        isA<GlobalPullCursorException>().having(
          (error) => error.reasonCode,
          'reason',
          'cursor-write-failed',
        ),
      ),
    );
  });

  test(
    'native readback error is propagated instead of trusting cache',
    () async {
      readFailure = PlatformException(code: 'storage-unavailable');
      await expectLater(
        store.completeDomain(prepared, GlobalPullDomain.knowledgeBase),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'storage-unavailable',
          ),
        ),
      );
    },
  );
}
