import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm3_baf_ops/features/auth/services/notification_installation_registry.dart';

class _MemoryIdStore implements NotificationInstallationIdStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String installationId) async {
    value = installationId;
  }
}

class _DocumentWrite {
  final String uid;
  final String installationId;
  final String token;
  final String platform;

  const _DocumentWrite({
    required this.uid,
    required this.installationId,
    required this.token,
    required this.platform,
  });
}

class _DocumentRemoval {
  final String uid;
  final String installationId;
  final String? expectedToken;

  const _DocumentRemoval({
    required this.uid,
    required this.installationId,
    required this.expectedToken,
  });
}

class _RecordingDocumentStore implements NotificationInstallationDocumentStore {
  final List<_DocumentWrite> writes = <_DocumentWrite>[];
  final List<_DocumentRemoval> removals = <_DocumentRemoval>[];

  @override
  Future<void> upsert({
    required String uid,
    required String installationId,
    required String token,
    required String platform,
  }) async {
    writes.add(
      _DocumentWrite(
        uid: uid,
        installationId: installationId,
        token: token,
        platform: platform,
      ),
    );
  }

  @override
  Future<void> remove({
    required String uid,
    required String installationId,
    String? expectedToken,
  }) async {
    removals.add(
      _DocumentRemoval(
        uid: uid,
        installationId: installationId,
        expectedToken: expectedToken,
      ),
    );
  }
}

class _FakeTokenSource implements NotificationTokenSource {
  final StreamController<String> refreshController =
      StreamController<String>.broadcast();
  String? token;
  int deleteCount = 0;

  _FakeTokenSource(this.token);

  @override
  Future<String?> currentToken() async => token;

  @override
  Future<void> deleteToken() async {
    deleteCount += 1;
    token = null;
  }

  @override
  Stream<String> get tokenRefreshes => refreshController.stream;
}

void main() {
  group('notification installation registry', () {
    late _MemoryIdStore idStore;
    late _RecordingDocumentStore documentStore;
    late _FakeTokenSource tokenSource;
    late NotificationInstallationRegistry registry;

    setUp(() {
      idStore = _MemoryIdStore();
      documentStore = _RecordingDocumentStore();
      tokenSource = _FakeTokenSource('token-a');
      registry = NotificationInstallationRegistry(
        idStore: idStore,
        documentStore: documentStore,
        tokenSource: tokenSource,
        platform: 'android',
      );
    });

    tearDown(() async {
      await tokenSource.refreshController.close();
    });

    test(
      'creates one stable opaque installation ID and registers the token',
      () async {
        final first = await registry.registerCurrentToken(uid: 'user-1');
        final second = await registry.registerCurrentToken(uid: 'user-1');

        expect(
          first!.installationId,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(idStore.value, first.installationId);
        expect(second!.installationId, first.installationId);
        expect(documentStore.writes, hasLength(1));
        expect(documentStore.writes.single.uid, 'user-1');
        expect(documentStore.writes.single.token, 'token-a');
        expect(documentStore.writes.single.platform, 'android');
      },
    );

    test(
      'token refresh replaces only the same installation registration',
      () async {
        final first = await registry.registerCurrentToken(uid: 'user-1');
        final refreshed = await registry.registerToken(
          uid: 'user-1',
          token: 'token-b',
        );

        expect(documentStore.writes, hasLength(2));
        expect(refreshed!.installationId, first!.installationId);
        expect(documentStore.writes.last.token, 'token-b');
        expect(
          documentStore.writes.map((entry) => entry.installationId).toSet(),
          {first.installationId},
        );
      },
    );

    test(
      'a restarted registry reuses the persisted installation identity',
      () async {
        final first = await registry.registerCurrentToken(uid: 'user-1');
        final restarted = NotificationInstallationRegistry(
          idStore: idStore,
          documentStore: documentStore,
          tokenSource: tokenSource,
          platform: 'android',
        );

        final replay = await restarted.registerCurrentToken(uid: 'user-1');
        expect(replay!.installationId, first!.installationId);
        expect(documentStore.writes, hasLength(2));
      },
    );

    test(
      'sign-out removes only this installation and retires its token',
      () async {
        final registration = await registry.registerCurrentToken(uid: 'user-1');
        await registry.removeCurrentInstallation(uid: 'user-1');
        await registry.retireMessagingToken();

        expect(documentStore.removals, hasLength(1));
        expect(documentStore.removals.single.uid, 'user-1');
        expect(
          documentStore.removals.single.installationId,
          registration!.installationId,
        );
        expect(documentStore.removals.single.expectedToken, 'token-a');
        expect(tokenSource.deleteCount, 1);
        expect(idStore.value, registration.installationId);
      },
    );

    test('missing or blank tokens do not create registration state', () async {
      tokenSource.token = null;
      expect(await registry.registerCurrentToken(uid: 'user-1'), isNull);
      expect(await registry.registerToken(uid: 'user-1', token: '   '), isNull);
      expect(idStore.value, isNull);
      expect(documentStore.writes, isEmpty);
    });

    test('rejects non-canonical identities and oversized tokens', () async {
      expect(
        () => registry.registerToken(uid: ' user-1', token: 'token'),
        throwsArgumentError,
      );
      expect(
        () => registry.registerToken(uid: 'user-1', token: 't' * 4097),
        throwsArgumentError,
      );
    });
  });

  test(
    'shared preferences store accepts only lowercase UUID v4 values',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesNotificationInstallationIdStore.preferenceKey:
            'not-a-uuid',
      });
      final store = SharedPreferencesNotificationInstallationIdStore();
      expect(await store.read(), isNull);

      const valid = '55cf69a1-8a5d-4c80-a5af-7d1c2a744207';
      await store.write(valid);
      expect(await store.read(), valid);
    },
  );
}
