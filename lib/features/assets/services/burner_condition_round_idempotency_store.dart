import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/persistence/request_identity_journal.dart';

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
/// app restart. Changed payloads keep separate identities without erasing older
/// uncertain requests. This store does not retain the form payload itself.
class BurnerConditionRoundIdempotencyStore {
  BurnerConditionRoundIdempotencyStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const _keyPrefix = 'PENDING_BURNER_CONDITION_ROUND::';
  final Future<SharedPreferences> Function() _preferencesLoader;
  static Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  RequestIdentityJournal<BurnerConditionRoundPendingIdentity> _journal(
    String actorUid,
  ) => RequestIdentityJournal(
    legacyKey: _key(actorUid),
    decode: (raw) =>
        _decode(raw) ??
        (throw StateError(
          'Saved burner retry evidence is empty and was preserved.',
        )),
    requestIdOf: (record) => record.requestId,
  );

  Future<BurnerConditionRoundPendingIdentity> resolve({
    required String actorUid,
    required String payloadFingerprint,
  }) => _serial(() async {
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
    await preferences.reload();
    final journal = _journal(normalizedActorUid);
    final records = journal.readAll(preferences);
    for (final record in records) {
      if (record.value.payloadFingerprint == normalizedFingerprint) {
        return record.value;
      }
    }
    final next = BurnerConditionRoundPendingIdentity(
      requestId: _requestUuid.v4(),
      payloadFingerprint: normalizedFingerprint,
    );
    return journal.append(preferences, next.toMap());
  });

  Future<void> clearIfMatches({
    required String actorUid,
    required String requestId,
  }) => _serial(() async {
    final normalizedActorUid = _required(actorUid, 'actorUid');
    final normalizedRequestId = _required(requestId, 'requestId');
    final preferences = await _preferencesLoader();
    await preferences.reload();
    await _journal(normalizedActorUid).clearMatching(
      preferences,
      (record) => record.requestId == normalizedRequestId,
    );
  });

  Future<BurnerConditionRoundPendingIdentity?> read({
    required String actorUid,
  }) => _serial(() async {
    final normalizedActorUid = _required(actorUid, 'actorUid');
    final preferences = await _preferencesLoader();
    await preferences.reload();
    final records = _journal(normalizedActorUid).readAll(preferences);
    return records.isEmpty ? null : records.first.value;
  });

  /// Native review imports exact old bytes; no decoder, rewrite, or pruning.
  Future<Map<String, Uint8List>> readRawEvidence(String actorUid) =>
      _serial(() async {
        final preferences = await _preferencesLoader();
        await preferences.reload();
        return {
          for (final row in _journal(
            _required(actorUid, 'actorUid'),
          ).rawEvidence(preferences))
            row.key: row.bytes,
        };
      });

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
