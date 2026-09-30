import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dev/dev_environment.dart';
import '../security/app_check_bootstrap.dart';
import '../serialization/persisted_data_reader.dart';

const backendReleaseIdentityCallableName = 'getBackendReleaseIdentity';
const backendReleaseIdentityCallableRegion = 'asia-south1';

class BackendReleaseIdentity {
  final String releaseId;
  final String firebaseProjectId;
  final String environment;
  final String? gitCommit;
  final String? functionsRevision;
  final String? functionsDigest;
  final String? firestoreRulesReleaseId;
  final String? firestoreRulesDigest;
  final String? firestoreIndexesDigest;
  final DateTime? deployedAt;

  const BackendReleaseIdentity({
    required this.releaseId,
    required this.firebaseProjectId,
    required this.environment,
    this.gitCommit,
    this.functionsRevision,
    this.functionsDigest,
    this.firestoreRulesReleaseId,
    this.firestoreRulesDigest,
    this.firestoreIndexesDigest,
    this.deployedAt,
  });

  factory BackendReleaseIdentity.fromCallableData(Object? raw) {
    if (raw is! Map) {
      throw const FormatException(
        'Backend release identity callable returned an invalid response.',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    final releaseId = _required(map['releaseId'], 'releaseId');
    final projectId = _required(map['firebaseProjectId'], 'firebaseProjectId');
    final environment = _required(map['environment'], 'environment');

    return BackendReleaseIdentity(
      releaseId: releaseId,
      firebaseProjectId: projectId,
      environment: environment,
      gitCommit: _clean(map['gitCommit']),
      functionsRevision: _clean(map['functionsRevision']),
      functionsDigest: _clean(map['functionsDigest']),
      firestoreRulesReleaseId: _clean(map['firestoreRulesReleaseId']),
      firestoreRulesDigest: _clean(map['firestoreRulesDigest']),
      firestoreIndexesDigest: _clean(map['firestoreIndexesDigest']),
      deployedAt: readOptionalPersistedDateTime(
        map['deployedAt'],
        field: 'deployedAt',
        source: 'backend release identity callable',
        allowSerializedTimestampMap: true,
      )?.toUtc(),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'releaseId': releaseId,
    'firebaseProjectId': firebaseProjectId,
    'environment': environment,
    'gitCommit': gitCommit,
    'functionsRevision': functionsRevision,
    'functionsDigest': functionsDigest,
    'firestoreRulesReleaseId': firestoreRulesReleaseId,
    'firestoreRulesDigest': firestoreRulesDigest,
    'firestoreIndexesDigest': firestoreIndexesDigest,
    'deployedAt': deployedAt?.toIso8601String(),
  };
}

class BackendReleaseIdentityService {
  final FirebaseFunctions? _functions;
  final FirebaseAuth? _auth;
  final bool _appCheckEnabled;
  final bool _useEmulators;
  final Duration timeout;
  Future<BackendReleaseIdentity>? _inFlight;
  String? _inFlightUid;

  BackendReleaseIdentityService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    // Injectable for service tests; production uses the compiled build flags.
    bool appCheckEnabled = crm3AppCheckEnabled,
    bool useEmulators = crm3UseEmulators,
    this.timeout = const Duration(seconds: 20),
  }) : _functions = functions,
       _auth = auth,
       _appCheckEnabled = appCheckEnabled,
       _useEmulators = useEmulators;

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(
        region: backendReleaseIdentityCallableRegion,
      );

  FirebaseAuth get _authClient => _auth ?? FirebaseAuth.instance;

  Future<BackendReleaseIdentity> fetch() {
    final uid = _authClient.currentUser?.uid;
    if (uid == null) {
      return Future.error(
        const BackendReleaseIdentityException(
          code: 'unauthenticated',
          message: 'Sign in before checking backend access.',
        ),
      );
    }
    // The production identity callable enforces App Check independently of
    // mutating callables. An ID-token refresh cannot enable this build feature.
    // Demo-only emulator wiring is separately guarded during app startup.
    final demoEmulator =
        _useEmulators &&
        !kReleaseMode &&
        _client.app.options.projectId.startsWith('demo-');
    if (!_appCheckEnabled && !demoEmulator) {
      return Future.error(
        const BackendReleaseIdentityException(
          code: 'app-check-disabled',
          message:
              'Backend identity verification is not available in this build because app verification (App Check) is disabled. Local diagnostics remain available.',
        ),
      );
    }
    if (_inFlightUid == uid && _inFlight != null) return _inFlight!;

    final elapsed = Stopwatch()..start();
    var expired = false;
    Duration remaining() {
      if (expired || elapsed.elapsed >= timeout) {
        throw const BackendReleaseIdentityException(
          code: 'deadline-exceeded',
          message: 'Backend access verification timed out.',
        );
      }
      if (_authClient.currentUser?.uid != uid) {
        throw const BackendReleaseIdentityException(
          code: 'session-changed',
          message: 'The signed-in account changed during backend verification.',
        );
      }
      return timeout - elapsed.elapsed;
    }

    late final Future<BackendReleaseIdentity> operation;
    operation = _fetchWithAuthRetry(remaining)
        .timeout(
          timeout,
          onTimeout: () {
            expired = true;
            throw const BackendReleaseIdentityException(
              code: 'deadline-exceeded',
              message: 'Backend access verification timed out.',
            );
          },
        )
        .whenComplete(() {
          expired = true;
          elapsed.stop();
          if (identical(_inFlight, operation)) {
            _inFlight = null;
            _inFlightUid = null;
          }
        });
    _inFlightUid = uid;
    _inFlight = operation;
    return operation;
  }

  Future<BackendReleaseIdentity> _fetchWithAuthRetry(
    Duration Function() remaining,
  ) async {
    Future<BackendReleaseIdentity> attempt() async {
      final callable = _client.httpsCallable(
        backendReleaseIdentityCallableName,
        options: HttpsCallableOptions(timeout: remaining()),
      );
      final result = await _fetch(callable);
      remaining(); // Reject late results and results from a previous account.
      return result;
    }

    try {
      return await attempt();
    } on FirebaseFunctionsException catch (firstError) {
      remaining();
      final currentUser = _authClient.currentUser;
      if (firstError.code != 'unauthenticated' || currentUser == null) {
        throw _identityException(firstError);
      }
      try {
        await currentUser.getIdToken(true).timeout(remaining());
      } on FirebaseAuthException {
        throw _identityException(firstError);
      } on TimeoutException {
        throw const BackendReleaseIdentityException(
          code: 'deadline-exceeded',
          message: 'Backend access verification timed out.',
        );
      }
      remaining();
      try {
        return await attempt();
      } on FirebaseFunctionsException catch (retryError) {
        throw _identityException(retryError);
      }
    }
  }

  Future<BackendReleaseIdentity> _fetch(HttpsCallable callable) async {
    try {
      final result = await callable.call(const <String, dynamic>{});
      return BackendReleaseIdentity.fromCallableData(result.data);
    } on FormatException catch (error) {
      throw BackendReleaseIdentityException(
        code: 'invalid-response',
        message: error.message,
      );
    }
  }
}

class BackendReleaseIdentityException implements Exception {
  final String code;
  final String message;
  final Object? details;

  const BackendReleaseIdentityException({
    required this.code,
    required this.message,
    this.details,
  });

  String get operatorMessage {
    switch (code) {
      case 'unauthenticated':
        return 'This installation or sign-in could not be verified for backend access. The response does not identify which verification failed. Local diagnostics remain available; contact support if this continues.';
      case 'permission-denied':
        return 'Backend release identity is not visible to this account.';
      case 'unavailable':
        return 'Backend release identity is unavailable while offline or while the callable is unreachable.';
      case 'deadline-exceeded':
        return 'Backend access verification timed out. Local diagnostics remain available.';
      case 'not-found':
        return 'Backend release identity has not been deployed.';
      default:
        return message;
    }
  }

  @override
  String toString() => operatorMessage;
}

final backendReleaseIdentityServiceProvider =
    Provider<BackendReleaseIdentityService>((ref) {
      return BackendReleaseIdentityService();
    });

String _required(Object? value, String field) {
  final cleaned = _clean(value);
  if (cleaned == null) {
    throw FormatException('Backend release identity is missing $field.');
  }
  return cleaned;
}

String? _clean(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

BackendReleaseIdentityException _identityException(
  FirebaseFunctionsException error,
) => BackendReleaseIdentityException(
  code: error.code,
  message:
      _clean(error.message) ?? 'Backend release identity could not be loaded.',
  details: error.details,
);
