import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/release/backend_release_identity_service.dart';

void main() {
  test('parses backend release identity returned by callable', () {
    final identity = BackendReleaseIdentity.fromCallableData(<String, dynamic>{
      'releaseId': 'backend-70i-1',
      'firebaseProjectId': 'crm3-baf-ops-b8638',
      'environment': 'production',
      'gitCommit': 'abcdef1',
      'functionsRevision': 'assign-00001',
      'functionsDigest': 'FUNCTIONS_SHA',
      'firestoreRulesReleaseId': 'ruleset-123',
      'firestoreRulesDigest': 'RULES_SHA',
      'firestoreIndexesDigest': 'INDEX_SHA',
      'deployedAt': '2026-06-19T12:00:00Z',
    });

    expect(identity.releaseId, 'backend-70i-1');
    expect(identity.firebaseProjectId, 'crm3-baf-ops-b8638');
    expect(identity.functionsRevision, 'assign-00001');
    expect(identity.deployedAt, DateTime.parse('2026-06-19T12:00:00Z'));
  });

  test('rejects an incomplete backend identity response', () {
    expect(
      () => BackendReleaseIdentity.fromCallableData(const <String, dynamic>{
        'releaseId': 'backend-70i-1',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('accepts an absent optional deployment timestamp', () {
    final identity =
        BackendReleaseIdentity.fromCallableData(const <String, dynamic>{
          'releaseId': 'backend-70i-1',
          'firebaseProjectId': 'crm3-baf-ops-b8638',
          'environment': 'production',
        });

    expect(identity.deployedAt, isNull);
  });

  test('parses a complete serialized callable timestamp', () {
    final identity = BackendReleaseIdentity.fromCallableData(
      const <String, dynamic>{
        'releaseId': 'backend-70i-1',
        'firebaseProjectId': 'crm3-baf-ops-b8638',
        'environment': 'production',
        'deployedAt': <String, Object>{
          '_seconds': 1785911400,
          '_nanoseconds': 123456000,
        },
      },
    );

    expect(identity.deployedAt, DateTime.utc(2026, 8, 5, 6, 30, 0, 123, 456));
  });

  test('malformed present deployment timestamps fail closed', () {
    for (final deployedAt in <Object>[
      'not-a-timestamp',
      const <String, Object>{'_seconds': 1785911400},
      const <String, Object>{'_seconds': 1785911400, '_nanoseconds': -1},
      const <String, Object>{'_seconds': 253402300800, '_nanoseconds': 0},
    ]) {
      expect(
        () => BackendReleaseIdentity.fromCallableData(<String, dynamic>{
          'releaseId': 'backend-70i-1',
          'firebaseProjectId': 'crm3-baf-ops-b8638',
          'environment': 'production',
          'deployedAt': deployedAt,
        }),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test(
    'unauthenticated does not mistake attestation rejection for sign-out',
    () {
      const error = BackendReleaseIdentityException(
        code: 'unauthenticated',
        message: 'Unauthenticated',
      );

      expect(error.toString(), contains('installation or sign-in'));
      expect(error.toString(), isNot(contains('Sign in again')));
      expect(error.toString(), isNot(contains('Check connectivity')));
      expect(error.toString(), contains('does not identify which'));
      expect(error.toString(), contains('Local diagnostics remain available'));
    },
  );

  test(
    'disabled production attestation performs no request or auth refresh',
    () async {
      final functions = _Functions(
        (_) async => throw StateError('must not call'),
      );
      final auth = _Auth();
      final service = BackendReleaseIdentityService(
        functions: functions,
        auth: auth,
        appCheckEnabled: false,
        useEmulators: false,
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          service.fetch(),
          throwsA(
            _code('app-check-disabled').having(
              (error) => error.toString(),
              'operator explanation',
              allOf(
                contains('not available in this build'),
                contains('App Check'),
                contains('Local diagnostics remain available'),
              ),
            ),
          ),
        );
      }
      expect(functions.calls, 0);
      expect(functions.timeouts, isEmpty);
      expect(auth.user!.refreshes, 0);
    },
  );

  test(
    'signed-out access still fails before the disabled-build preflight',
    () async {
      final functions = _Functions(
        (_) async => throw StateError('must not call'),
      );
      final auth = _Auth()..user = null;
      final service = BackendReleaseIdentityService(
        functions: functions,
        auth: auth,
        appCheckEnabled: false,
        useEmulators: false,
      );
      await expectLater(service.fetch(), throwsA(_code('unauthenticated')));
      expect(functions.calls, 0);
      expect(functions.timeouts, isEmpty);
    },
  );

  test(
    'supported demo emulator mode can read identity without attestation',
    () async {
      final functions = _Functions(
        (_) async => _identity,
        projectId: 'demo-test',
      );
      final auth = _Auth();
      final service = BackendReleaseIdentityService(
        functions: functions,
        auth: auth,
        appCheckEnabled: false,
        useEmulators: true,
      );
      expect((await service.fetch()).releaseId, 'backend-current');
      expect(functions.calls, 1);
      expect(auth.user!.refreshes, 0);
    },
  );

  test('emulator flag cannot exempt a real Firebase project', () async {
    final functions = _Functions(
      (_) async => throw StateError('must not call'),
    );
    final auth = _Auth();
    final service = BackendReleaseIdentityService(
      functions: functions,
      auth: auth,
      appCheckEnabled: false,
      useEmulators: true,
    );
    await expectLater(service.fetch(), throwsA(_code('app-check-disabled')));
    expect(functions.calls, 0);
    expect(functions.timeouts, isEmpty);
    expect(auth.user!.refreshes, 0);
  });

  test(
    'enabled attestation keeps one auth refresh that may recover access',
    () async {
      final functions = _Functions((call) async {
        if (call == 1) {
          throw FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'Unauthenticated',
          );
        }
        return _identity;
      });
      final auth = _Auth();
      final service = BackendReleaseIdentityService(
        functions: functions,
        auth: auth,
        appCheckEnabled: true,
        useEmulators: false,
      );
      expect((await service.fetch()).releaseId, 'backend-current');
      expect(functions.calls, 2);
      expect(auth.user!.refreshes, 1);
    },
  );

  test('concurrent callers share one successful request', () async {
    final pending = Completer<Object?>();
    final functions = _Functions((_) => pending.future);
    final auth = _Auth();
    final service = BackendReleaseIdentityService(
      functions: functions,
      appCheckEnabled: true,
      useEmulators: false,
      auth: auth,
    );
    final first = service.fetch();
    final second = service.fetch();
    expect(identical(first, second), isTrue);
    pending.complete(_identity);
    expect((await first).releaseId, 'backend-current');
    expect((await second).releaseId, 'backend-current');
    expect(functions.calls, 1);
    expect(auth.user!.refreshes, 0);
    expect(functions.timeouts.single, lessThanOrEqualTo(service.timeout));
  });

  test('concurrent 401 failures share one refresh and one retry', () async {
    final retry = Completer<Object?>();
    final functions = _Functions((call) async {
      if (call == 1) {
        throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Unauthenticated',
        );
      }
      return retry.future;
    });
    final auth = _Auth();
    final service = BackendReleaseIdentityService(
      functions: functions,
      appCheckEnabled: true,
      useEmulators: false,
      auth: auth,
    );
    final first = service.fetch();
    final second = service.fetch();
    expect(identical(first, second), isTrue);
    final checked = expectLater(first, throwsA(_code('unauthenticated')));
    await Future<void>.delayed(Duration.zero);
    expect(auth.user!.refreshes, 1);
    expect(functions.calls, 2);
    retry.completeError(
      FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Unauthenticated',
      ),
    );
    await checked;
    await Future<void>.delayed(Duration.zero);
    expect(functions.calls, 2);
    expect(auth.user!.refreshes, 1);
  });

  test('refresh timeout cannot launch a late retry', () async {
    final auth = _Auth();
    auth.user!.refresh = Completer<String?>();
    final functions = _Functions((_) async {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Unauthenticated',
      );
    });
    final service = BackendReleaseIdentityService(
      functions: functions,
      appCheckEnabled: true,
      useEmulators: false,
      auth: auth,
      timeout: const Duration(milliseconds: 40),
    );
    await expectLater(service.fetch(), throwsA(_code('deadline-exceeded')));
    auth.user!.refresh!.complete('test-only');
    await Future<void>.delayed(Duration.zero);
    expect(functions.calls, 1);
    expect(auth.user!.refreshes, 1);
  });

  test(
    'late failure after request timeout cannot refresh authentication',
    () async {
      final pending = Completer<Object?>();
      final auth = _Auth();
      final functions = _Functions((_) => pending.future);
      final service = BackendReleaseIdentityService(
        functions: functions,
        appCheckEnabled: true,
        useEmulators: false,
        auth: auth,
        timeout: const Duration(milliseconds: 40),
      );
      await expectLater(service.fetch(), throwsA(_code('deadline-exceeded')));
      pending.completeError(
        FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Unauthenticated',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(functions.calls, 1);
      expect(auth.user!.refreshes, 0);
    },
  );

  test(
    'a new account never consumes or coalesces an old account result',
    () async {
      final requests = [Completer<Object?>(), Completer<Object?>()];
      final auth = _Auth();
      final functions = _Functions((call) => requests[call - 1].future);
      final service = BackendReleaseIdentityService(
        functions: functions,
        appCheckEnabled: true,
        useEmulators: false,
        auth: auth,
      );
      final previous = service.fetch();
      final rejected = expectLater(previous, throwsA(_code('session-changed')));
      auth.user = _User('other');
      final current = service.fetch();
      expect(identical(previous, current), isFalse);
      requests.first.complete(_identity);
      await rejected;
      requests.last.complete(_identity);
      expect((await current).releaseId, 'backend-current');
      expect(functions.calls, 2);
      expect(auth.user!.refreshes, 0);
    },
  );

  test('permission failure does not refresh or retry', () async {
    final auth = _Auth();
    final functions = _Functions((_) async {
      throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Permission denied',
      );
    });
    final service = BackendReleaseIdentityService(
      functions: functions,
      appCheckEnabled: true,
      useEmulators: false,
      auth: auth,
    );
    await expectLater(service.fetch(), throwsA(_code('permission-denied')));
    expect(functions.calls, 1);
    expect(auth.user!.refreshes, 0);
  });
}

TypeMatcher<BackendReleaseIdentityException> _code(String code) =>
    isA<BackendReleaseIdentityException>().having(
      (error) => error.code,
      'code',
      code,
    );

const _identity = <String, Object>{
  'releaseId': 'backend-current',
  'firebaseProjectId': 'crm3-baf-ops-b8638',
  'environment': 'production',
};

class _Auth extends Fake implements FirebaseAuth {
  _User? user = _User('owner');
  @override
  User? get currentUser => user;
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  int refreshes = 0;
  Completer<String?>? refresh;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    expect(forceRefresh, isTrue);
    refreshes++;
    return refresh == null ? 'test-only' : refresh!.future;
  }
}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.respond, {this.projectId = 'crm3-baf-ops-b8638'});
  final String projectId;
  @override
  FirebaseApp get app => _App(projectId);
  final Future<Object?> Function(int call) respond;
  int calls = 0;
  final timeouts = <Duration>[];
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, backendReleaseIdentityCallableName);
    timeouts.add(options!.timeout);
    return _Callable(this);
  }
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.functions);
  final _Functions functions;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    expect(parameters, isEmpty);
    return _Result<T>((await functions.respond(++functions.calls)) as T);
  }
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}

class _App extends Fake implements FirebaseApp {
  _App(this.projectId);
  final String projectId;
  @override
  FirebaseOptions get options => FirebaseOptions(
    apiKey: 'test-only',
    appId: 'test-only',
    messagingSenderId: 'test-only',
    projectId: projectId,
  );
}
