import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/persistence/request_identity_journal.dart';

class MorningReviewPendingCommandIdentity {
  const MorningReviewPendingCommandIdentity({
    required this.requestId,
    required this.payloadFingerprint,
    required this.operation,
    required this.sessionId,
    required this.extra,
  });

  final String requestId;
  final String payloadFingerprint;
  final String operation;
  final String? sessionId;
  final Map<String, dynamic> extra;
}

class MorningReviewCommandIdempotencyException implements Exception {
  const MorningReviewCommandIdempotencyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Retains submitted commands per actor for exact replay. The oldest unresolved
/// command is discovered first, including commands saved by concurrent runtimes.
class MorningReviewCommandIdempotencyStore {
  MorningReviewCommandIdempotencyStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _load = preferencesLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _load;
  static Future<void> _tail = Future<void>.value();
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final _fingerprintPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _operationPattern = RegExp(r'^[A-Z][A-Z_]{0,79}$');
  static final _plantDayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static String fingerprintFor({
    required String actorUid,
    required String operation,
    required String? sessionId,
    required Map<String, dynamic> extra,
  }) => sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'actorScope': actorUid,
            'operation': operation,
            'sessionId': sessionId,
            'extra': extra,
          }),
        ),
      )
      .toString();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  String _key(String actorUid) {
    final normalized = actorUid.trim();
    if (normalized.isEmpty || normalized == 'unresolved-actor') {
      throw const MorningReviewCommandIdempotencyException(
        'Sign in again before changing the Morning Review.',
      );
    }
    final actorDigest = sha256.convert(utf8.encode(normalized)).toString();
    return 'PENDING_MORNING_REVIEW_COMMAND::$actorDigest';
  }

  RequestIdentityJournal<MorningReviewPendingCommandIdentity> _journal(
    String actorUid,
  ) => RequestIdentityJournal(
    legacyKey: _key(actorUid),
    decode: (raw) => _decode(raw, actorUid),
    requestIdOf: (record) => record.requestId,
    failure: MorningReviewCommandIdempotencyException.new,
  );

  MorningReviewPendingCommandIdentity _decode(String raw, String actorUid) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 6 ||
          decoded['schemaVersion'] != 1 ||
          decoded['requestId'] is! String ||
          !_uuidPattern.hasMatch(decoded['requestId'] as String) ||
          decoded['payloadFingerprint'] is! String ||
          !_fingerprintPattern.hasMatch(
            decoded['payloadFingerprint'] as String,
          ) ||
          decoded['operation'] is! String ||
          !_operationPattern.hasMatch(decoded['operation'] as String) ||
          (decoded['sessionId'] != null &&
              (decoded['sessionId'] is! String ||
                  !_plantDayPattern.hasMatch(
                    decoded['sessionId'] as String,
                  ))) ||
          decoded['extra'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final extra = Map<String, dynamic>.from(
        decoded['extra'] as Map<String, dynamic>,
      );
      if (extra.keys.any(
        const {'requestId', 'operation', 'sessionId'}.contains,
      )) {
        throw const FormatException();
      }
      final operation = decoded['operation'] as String;
      final sessionId = decoded['sessionId'] as String?;
      final payloadFingerprint = decoded['payloadFingerprint'] as String;
      if (payloadFingerprint !=
          fingerprintFor(
            actorUid: actorUid,
            operation: operation,
            sessionId: sessionId,
            extra: extra,
          )) {
        throw const FormatException();
      }
      return MorningReviewPendingCommandIdentity(
        requestId: decoded['requestId'] as String,
        payloadFingerprint: payloadFingerprint,
        operation: operation,
        sessionId: sessionId,
        extra: Map.unmodifiable(extra),
      );
    } on FormatException {
      throw const MorningReviewCommandIdempotencyException(
        'Saved Morning Review retry evidence needs recovery and was not replaced.',
      );
    }
  }

  Future<MorningReviewPendingCommandIdentity> resolve({
    required String actorUid,
    required String operation,
    required String? sessionId,
    required Map<String, dynamic> extra,
  }) => _serial(() async {
    if (!_operationPattern.hasMatch(operation) ||
        (sessionId != null && !_plantDayPattern.hasMatch(sessionId)) ||
        extra.keys.any(
          const {'requestId', 'operation', 'sessionId'}.contains,
        )) {
      throw const MorningReviewCommandIdempotencyException(
        'The Morning Review command cannot be retained safely.',
      );
    }
    final payloadFingerprint = fingerprintFor(
      actorUid: actorUid,
      operation: operation,
      sessionId: sessionId,
      extra: extra,
    );
    final preferences = await _load();
    await preferences.reload();
    final journal = _journal(actorUid);
    final records = journal.readAll(preferences);
    final existing = records.isEmpty ? null : records.first.value;
    if (existing != null) {
      if (existing.payloadFingerprint != payloadFingerprint) {
        throw const MorningReviewCommandIdempotencyException(
          'Confirm the previous Morning Review command before sending a different change.',
        );
      }
      return existing;
    }

    final identity = MorningReviewPendingCommandIdentity(
      requestId: _uuid.v4(),
      payloadFingerprint: payloadFingerprint,
      operation: operation,
      sessionId: sessionId,
      extra: Map.unmodifiable(Map<String, dynamic>.from(extra)),
    );
    return journal.append(preferences, <String, dynamic>{
      'schemaVersion': 1,
      'requestId': identity.requestId,
      'payloadFingerprint': identity.payloadFingerprint,
      'operation': identity.operation,
      'sessionId': identity.sessionId,
      'extra': identity.extra,
    });
  });

  Future<MorningReviewPendingCommandIdentity?> pending(String actorUid) =>
      _serial(() async {
        final preferences = await _load();
        await preferences.reload();
        final records = _journal(actorUid).readAll(preferences);
        return records.isEmpty ? null : records.first.value;
      });

  Future<void> clearIfMatches({
    required String actorUid,
    required String requestId,
    required String payloadFingerprint,
  }) => _serial(() async {
    final preferences = await _load();
    await preferences.reload();
    await _journal(actorUid).clearMatching(
      preferences,
      (record) =>
          record.requestId == requestId &&
          record.payloadFingerprint == payloadFingerprint,
    );
  });
}
