import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';

const _requestUuid = Uuid();
final _canonicalUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _sha256Hex = RegExp(r'^[0-9a-f]{64}$');

class BurnerConditionRoundPendingIdentity {
  const BurnerConditionRoundPendingIdentity({
    required this.requestId,
    required this.payloadFingerprint,
  });

  final String requestId;
  final String payloadFingerprint;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'requestId': requestId,
    'payloadFingerprint': payloadFingerprint,
  };

  factory BurnerConditionRoundPendingIdentity.fromMap(
    Map<String, dynamic> map,
  ) {
    const expectedKeys = <String>{'requestId', 'payloadFingerprint'};
    if (map.keys.toSet().length != expectedKeys.length ||
        !map.keys.toSet().containsAll(expectedKeys)) {
      throw PersistedDataFormatException(
        field: 'pendingBurnerRoundIdentity',
        source: 'SharedPreferences',
        detail: 'must contain exactly requestId and payloadFingerprint',
      );
    }
    final requestId = readRequiredPersistedString(
      map['requestId'],
      field: 'requestId',
      source: 'pending burner-round identity',
    );
    final payloadFingerprint = readRequiredPersistedString(
      map['payloadFingerprint'],
      field: 'payloadFingerprint',
      source: 'pending burner-round identity',
    );
    if (!_canonicalUuid.hasMatch(requestId) ||
        !_sha256Hex.hasMatch(payloadFingerprint)) {
      throw PersistedDataFormatException(
        field: 'pendingBurnerRoundIdentity',
        source: 'SharedPreferences',
        detail: 'request ID or payload fingerprint is malformed',
      );
    }
    return BurnerConditionRoundPendingIdentity(
      requestId: requestId,
      payloadFingerprint: payloadFingerprint,
    );
  }
}

/// Retains a burner-round request identity across an ambiguous network result.
///
/// The same actor and exact payload reuse the same request ID after a timeout or
/// app restart. Any payload change rotates the identity before another write.
class BurnerConditionRoundIdempotencyStore {
  BurnerConditionRoundIdempotencyStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const _keyPrefix = 'PENDING_BURNER_CONDITION_ROUND::';
  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<BurnerConditionRoundPendingIdentity> resolve({
    required String actorUid,
    required String payloadFingerprint,
  }) async {
    final normalizedActorUid = _required(actorUid, 'actorUid');
    final normalizedFingerprint = _required(
      payloadFingerprint,
      'payloadFingerprint',
    );
    if (!_sha256Hex.hasMatch(normalizedFingerprint)) {
      throw ArgumentError.value(
        payloadFingerprint,
        'payloadFingerprint',
        'must be a lowercase SHA-256 digest',
      );
    }
    final preferences = await _preferencesLoader();
    final key = _key(normalizedActorUid);
    final existing = _decode(preferences.getString(key));
    if (existing != null &&
        existing.payloadFingerprint == normalizedFingerprint) {
      return existing;
    }
    final next = BurnerConditionRoundPendingIdentity(
      requestId: _requestUuid.v4(),
      payloadFingerprint: normalizedFingerprint,
    );
    final written = await preferences.setString(key, jsonEncode(next.toMap()));
    if (!written) {
      throw StateError(
        'The burner-round retry identity could not be persisted safely.',
      );
    }
    return next;
  }

  Future<void> clearIfMatches({
    required String actorUid,
    required String requestId,
  }) async {
    final normalizedActorUid = _required(actorUid, 'actorUid');
    final normalizedRequestId = _required(requestId, 'requestId');
    final preferences = await _preferencesLoader();
    final key = _key(normalizedActorUid);
    final existing = _decode(preferences.getString(key));
    if (existing == null || existing.requestId != normalizedRequestId) return;
    final removed = await preferences.remove(key);
    if (!removed) {
      throw StateError(
        'The completed burner-round retry identity could not be cleared.',
      );
    }
  }

  Future<BurnerConditionRoundPendingIdentity?> read({
    required String actorUid,
  }) async {
    final normalizedActorUid = _required(actorUid, 'actorUid');
    final preferences = await _preferencesLoader();
    return _decode(preferences.getString(_key(normalizedActorUid)));
  }

  String _key(String actorUid) => '$_keyPrefix$actorUid';

  BurnerConditionRoundPendingIdentity? _decode(String? raw) {
    final cleaned = raw?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return BurnerConditionRoundPendingIdentity.fromMap(
      readRequiredJsonObject(
        cleaned,
        field: 'pendingBurnerRoundIdentity',
        source: 'SharedPreferences',
      ),
    );
  }
}

final burnerConditionRoundIdempotencyStoreProvider =
    Provider<BurnerConditionRoundIdempotencyStore>((ref) {
      return BurnerConditionRoundIdempotencyStore();
    });

String _required(String value, String field) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) {
    throw ArgumentError.value(value, field, '$field must not be blank.');
  }
  return cleaned;
}
