import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      deployedAt:
          readOptionalPersistedDateTime(
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

  BackendReleaseIdentityService({FirebaseFunctions? functions})
    : _functions = functions;

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(
        region: backendReleaseIdentityCallableRegion,
      );

  Future<BackendReleaseIdentity> fetch() async {
    final callable = _client.httpsCallable(backendReleaseIdentityCallableName);
    try {
      final result = await callable.call(const <String, dynamic>{});
      return BackendReleaseIdentity.fromCallableData(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw BackendReleaseIdentityException(
        code: error.code,
        message:
            _clean(error.message) ??
            'Backend release identity could not be loaded.',
        details: error.details,
      );
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
        return 'Sign in again to read backend release identity.';
      case 'permission-denied':
        return 'Backend release identity is not visible to this account.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Backend release identity is unavailable while offline or while the callable is unreachable.';
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
