import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../auth/data/user_model.dart';
import '../../maintenance/data/maintenance_model.dart';

const userAuthorityCallableName = 'mutateUserAuthority';
const userAuthorityCallableRegion = 'asia-south1';

enum UserAuthorityOperation {
  approve('APPROVE'),
  revoke('REVOKE'),
  replaceRoles('REPLACE_ROLES');

  final String wireName;
  const UserAuthorityOperation(this.wireName);
}

class UserAuthorityMutationResult {
  final String requestId;
  final String targetUid;
  final UserAuthorityOperation operation;
  final bool isApproved;
  final List<AppRole> roles;
  final String authorityDigest;
  final String auditId;
  final DateTime committedAt;
  final bool idempotentReplay;

  const UserAuthorityMutationResult({
    required this.requestId,
    required this.targetUid,
    required this.operation,
    required this.isApproved,
    required this.roles,
    required this.authorityDigest,
    required this.auditId,
    required this.committedAt,
    required this.idempotentReplay,
  });
}

class UserAuthorityMutationException implements Exception {
  final String code;
  final String message;
  final String? reasonCode;
  final Object? details;

  const UserAuthorityMutationException({
    required this.code,
    required this.message,
    this.reasonCode,
    this.details,
  });

  factory UserAuthorityMutationException.fromFirebase(
    FirebaseFunctionsException error,
  ) {
    final details =
        error.details is Map
            ? Map<String, dynamic>.from(error.details as Map)
            : <String, dynamic>{};
    return UserAuthorityMutationException(
      code: error.code,
      message: error.message ?? 'User authority mutation failed.',
      reasonCode: details['reasonCode']?.toString(),
      details: error.details,
    );
  }

  @override
  String toString() => message;
}

abstract interface class UserAuthorityCommandTransport {
  Future<Object?> call(Map<String, dynamic> request);
}

class FirebaseUserAuthorityCommandTransport
    implements UserAuthorityCommandTransport {
  final FirebaseFunctions? functions;

  const FirebaseUserAuthorityCommandTransport({this.functions});

  FirebaseFunctions get _client =>
      functions ??
      FirebaseFunctions.instanceFor(region: userAuthorityCallableRegion);

  @override
  Future<Object?> call(Map<String, dynamic> request) async {
    final response = await _client
        .httpsCallable(userAuthorityCallableName)
        .call<Map<String, dynamic>>(request);
    return response.data;
  }
}

class UserAuthorityCommandService {
  final UserAuthorityCommandTransport _transport;
  final Uuid _uuid;

  UserAuthorityCommandService({
    UserAuthorityCommandTransport? transport,
    Uuid uuid = const Uuid(),
  }) : _transport = transport ?? const FirebaseUserAuthorityCommandTransport(),
       _uuid = uuid;

  Future<UserAuthorityMutationResult> approve(
    AppUser target, {
    required String reason,
    String? requestId,
  }) {
    return _execute(
      target: target,
      operation: UserAuthorityOperation.approve,
      reason: reason,
      requestId: requestId,
    );
  }

  Future<UserAuthorityMutationResult> revoke(
    AppUser target, {
    required String reason,
    String? requestId,
  }) {
    return _execute(
      target: target,
      operation: UserAuthorityOperation.revoke,
      reason: reason,
      requestId: requestId,
    );
  }

  Future<UserAuthorityMutationResult> replaceRoles(
    AppUser target, {
    required Iterable<AppRole> roles,
    required String reason,
    String? requestId,
  }) {
    return _execute(
      target: target,
      operation: UserAuthorityOperation.replaceRoles,
      roles: roles,
      reason: reason,
      requestId: requestId,
    );
  }

  Future<UserAuthorityMutationResult> _execute({
    required AppUser target,
    required UserAuthorityOperation operation,
    required String reason,
    Iterable<AppRole>? roles,
    String? requestId,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty || cleanReason.length > 500) {
      throw const UserAuthorityMutationException(
        code: 'invalid-argument',
        message: 'Enter a reason of no more than 500 characters.',
        reasonCode: 'authority-reason-invalid',
      );
    }
    final normalizedRoles =
        roles == null ? null : normalizeAuthorityRoles(roles);
    if (operation == UserAuthorityOperation.replaceRoles &&
        normalizedRoles == null) {
      throw const UserAuthorityMutationException(
        code: 'invalid-argument',
        message: 'Select at least one canonical role.',
        reasonCode: 'invalid-authority-roles',
      );
    }

    final effectiveRequestId = requestId?.trim() ?? _uuid.v4();
    final payload = <String, dynamic>{
      'requestId': effectiveRequestId,
      'targetUid': target.uid,
      'operation': operation.wireName,
      'expectedAuthorityDigest': userAuthorityDigest(
        isApproved: target.isApproved,
        roles: target.roles,
      ),
      if (normalizedRoles != null)
        'roles': normalizedRoles.map((role) => role.name).toList(),
      'reason': cleanReason,
    };

    try {
      final raw = await _transport.call(payload);
      return _parseResult(
        raw,
        expectedRequestId: effectiveRequestId,
        expectedTargetUid: target.uid,
        expectedOperation: operation,
      );
    } on FirebaseFunctionsException catch (error) {
      throw UserAuthorityMutationException.fromFirebase(error);
    } on UserAuthorityMutationException {
      rethrow;
    } catch (error) {
      throw UserAuthorityMutationException(
        code: 'internal',
        message: 'User authority response could not be verified: $error',
        reasonCode: 'authority-response-invalid',
        details: error,
      );
    }
  }

  UserAuthorityMutationResult _parseResult(
    Object? raw, {
    required String expectedRequestId,
    required String expectedTargetUid,
    required UserAuthorityOperation expectedOperation,
  }) {
    if (raw is! Map || raw['ok'] != true) {
      throw const UserAuthorityMutationException(
        code: 'internal',
        message: 'User authority response was malformed.',
        reasonCode: 'authority-response-invalid',
      );
    }
    final data = Map<String, dynamic>.from(raw);
    if (data['requestId'] != expectedRequestId ||
        data['targetUid'] != expectedTargetUid ||
        data['operation'] != expectedOperation.wireName) {
      throw const UserAuthorityMutationException(
        code: 'internal',
        message: 'User authority response identity did not match the request.',
        reasonCode: 'authority-response-identity-mismatch',
      );
    }
    if (data['isApproved'] is! bool ||
        data['idempotentReplay'] is! bool ||
        data['roles'] is! List) {
      throw const UserAuthorityMutationException(
        code: 'internal',
        message: 'User authority response capsule was malformed.',
        reasonCode: 'authority-response-invalid',
      );
    }
    final roles = _parseResultRoles(data['roles'] as List);
    final digest = data['authorityDigest'];
    final auditId = data['auditId'];
    final committedAt = readRequiredPersistedDateTime(
      data['committedAt'],
      field: 'committedAt',
      source: 'mutateUserAuthority/$expectedRequestId',
    );
    if ((data['committedAt'] as String).trim() !=
        committedAt.toUtc().toIso8601String()) {
      throw PersistedDataFormatException(
        field: 'committedAt',
        source: 'mutateUserAuthority/$expectedRequestId',
        detail: 'must be a canonical UTC ISO instant',
      );
    }
    if (digest is! String || auditId is! String || auditId.trim().isEmpty) {
      throw const UserAuthorityMutationException(
        code: 'internal',
        message: 'User authority response evidence was malformed.',
        reasonCode: 'authority-response-invalid',
      );
    }
    final expectedDigest = userAuthorityDigest(
      isApproved: data['isApproved'] as bool,
      roles: roles,
    );
    if (digest != expectedDigest) {
      throw const UserAuthorityMutationException(
        code: 'internal',
        message: 'User authority response digest did not match its capsule.',
        reasonCode: 'authority-response-digest-mismatch',
      );
    }

    return UserAuthorityMutationResult(
      requestId: expectedRequestId,
      targetUid: expectedTargetUid,
      operation: expectedOperation,
      isApproved: data['isApproved'] as bool,
      roles: roles,
      authorityDigest: digest,
      auditId: auditId,
      committedAt: committedAt,
      idempotentReplay: data['idempotentReplay'] as bool,
    );
  }

  List<AppRole> _parseResultRoles(List<dynamic> raw) {
    final roles = <AppRole>{};
    for (final value in raw) {
      if (value is! String) {
        throw const UserAuthorityMutationException(
          code: 'internal',
          message: 'User authority response contained a non-string role.',
          reasonCode: 'authority-response-invalid',
        );
      }
      AppRole? parsed;
      for (final role in AppRole.values) {
        if (role.name == value) {
          parsed = role;
          break;
        }
      }
      if (parsed == null) {
        throw const UserAuthorityMutationException(
          code: 'internal',
          message: 'User authority response contained an unknown role.',
          reasonCode: 'authority-response-invalid',
        );
      }
      roles.add(parsed);
    }
    if (roles.isEmpty) {
      throw const UserAuthorityMutationException(
        code: 'internal',
        message: 'User authority response contained no roles.',
        reasonCode: 'authority-response-invalid',
      );
    }
    return normalizeAuthorityRoles(roles);
  }
}

List<AppRole> normalizeAuthorityRoles(Iterable<AppRole> roles) {
  final normalized =
      roles.toSet().toList()..sort((a, b) => a.name.compareTo(b.name));
  if (normalized.isEmpty) {
    throw const UserAuthorityMutationException(
      code: 'invalid-argument',
      message: 'Select at least one canonical role.',
      reasonCode: 'invalid-authority-roles',
    );
  }
  return List<AppRole>.unmodifiable(normalized);
}

String userAuthorityDigest({
  required bool isApproved,
  required Iterable<AppRole> roles,
}) {
  final normalized =
      normalizeAuthorityRoles(roles).map((role) => role.name).toList();
  final canonical = jsonEncode(<String, dynamic>{
    'isApproved': isApproved,
    'roles': normalized,
  });
  return 'auth1-sha256:${sha256.convert(utf8.encode(canonical))}';
}
