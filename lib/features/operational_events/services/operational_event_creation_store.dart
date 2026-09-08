import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PendingOperationalEventCreation {
  const PendingOperationalEventCreation({
    required this.requestId,
    required this.eventId,
    required this.payloadFingerprint,
    required this.payload,
  });

  final String requestId;
  final String eventId;
  final String payloadFingerprint;
  final Map<String, dynamic> payload;

  /// The server hashes its parsed command, rather than the local storage record.
  /// Keep the normalization compatible with legacy CREATE receipt fingerprints.
  String get commandFingerprint {
    final draft = Map<String, dynamic>.from(payload['eventDraft'] as Map);
    for (final field in [
      'eventType',
      'title',
      'description',
      'severity',
      'scope',
    ]) {
      draft[field] = (draft[field] as String).trim();
    }
    for (final field in ['affectedAssetClassIds', 'affectedAssetInstanceIds']) {
      draft[field] =
          (draft[field] as List)
              .map((value) => (value as String).trim())
              .toList()
            ..sort();
    }
    draft['startedAtIso'] = (draft.remove('startedAt') as String).trim();
    final parsed = <String, dynamic>{
      'requestId': requestId,
      'eventId': eventId,
      'operation': 'CREATE_OPERATIONAL_EVENT',
      'expectedVersion': 0,
      'reason': (payload['reason'] as String).trim(),
      'eventDraft': draft,
      'resolutionNote': null,
    };
    return 'operationalevent1-sha256:${sha256.convert(utf8.encode(jsonEncode(OperationalEventCreationStore._canonical(parsed))))}';
  }

  Map<String, dynamic> toRequest() => <String, dynamic>{
    'requestId': requestId,
    'eventId': eventId,
    'operation': 'CREATE_OPERATIONAL_EVENT',
    'expectedVersion': 0,
    ...payload,
  };
}

/// One submitted creation per actor remains protected until its result is known.
/// Matching payloads resume that intent only while it remains unresolved.
class OperationalEventCreationStore {
  OperationalEventCreationStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _load = preferencesLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _load;
  static Future<void> _tail = Future<void>.value();
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  String _key(String actorUid) {
    if (actorUid.trim().isEmpty || actorUid != actorUid.trim()) {
      throw StateError('Sign in again before recording an operational event.');
    }
    return 'PENDING_OPERATIONAL_EVENT_CREATION::'
        '${sha256.convert(utf8.encode(actorUid))}';
  }

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonical(value[key]),
      };
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  String _fingerprint(String actorUid, Map<String, dynamic> payload) => sha256
      .convert(
        utf8.encode(
          jsonEncode(
            _canonical(<String, dynamic>{
              'actorUid': actorUid,
              'payload': payload,
            }),
          ),
        ),
      )
      .toString();

  PendingOperationalEventCreation? _read(
    SharedPreferences preferences,
    String key,
    String actorUid,
  ) {
    final raw = preferences.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 5 ||
          decoded['schemaVersion'] != 1 ||
          decoded['requestId'] is! String ||
          !_uuidPattern.hasMatch(decoded['requestId'] as String) ||
          decoded['eventId'] is! String ||
          !_uuidPattern.hasMatch(decoded['eventId'] as String) ||
          decoded['payload'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final payload = decoded['payload'] as Map<String, dynamic>;
      if (payload.length != 2 ||
          payload['reason'] is! String ||
          (payload['reason'] as String).trim().isEmpty ||
          payload['eventDraft'] is! Map<String, dynamic> ||
          decoded['payloadFingerprint'] != _fingerprint(actorUid, payload)) {
        throw const FormatException();
      }
      return PendingOperationalEventCreation(
        requestId: decoded['requestId'] as String,
        eventId: decoded['eventId'] as String,
        payloadFingerprint: decoded['payloadFingerprint'] as String,
        payload: Map.unmodifiable(payload),
      );
    } on FormatException {
      throw StateError(
        'Saved event retry information needs recovery and was not replaced.',
      );
    }
  }

  Future<PendingOperationalEventCreation?> pending(String actorUid) =>
      _serial(() async {
        final preferences = await _load();
        await preferences.reload();
        return _read(preferences, _key(actorUid), actorUid);
      });

  Future<PendingOperationalEventCreation> resolve({
    required String actorUid,
    required Map<String, dynamic> payload,
  }) => _serial(() async {
    final key = _key(actorUid);
    final snapshot =
        jsonDecode(jsonEncode(_canonical(payload))) as Map<String, dynamic>;
    if (snapshot.length != 2 ||
        snapshot['reason'] is! String ||
        (snapshot['reason'] as String).trim().isEmpty ||
        (snapshot['reason'] as String).length > 1000 ||
        snapshot['eventDraft'] is! Map<String, dynamic>) {
      throw ArgumentError(
        'The event creation payload is incomplete. Nothing was sent.',
      );
    }
    final fingerprint = _fingerprint(actorUid, snapshot);
    final preferences = await _load();
    await preferences.reload();
    final existing = _read(preferences, key, actorUid);
    if (existing != null) {
      if (existing.payloadFingerprint != fingerprint) {
        throw StateError(
          'Confirm the previous event before submitting a different event.',
        );
      }
      return existing;
    }
    final saved = await preferences.setString(
      key,
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'requestId': _uuid.v4(),
        'eventId': _uuid.v4(),
        'payloadFingerprint': fingerprint,
        'payload': snapshot,
      }),
    );
    if (!saved) {
      throw StateError(
        'Could not save event retry information. Nothing was sent.',
      );
    }
    // Read through the platform again before dispatch; never send an identity
    // that exists only in this process's preferences cache.
    await preferences.reload();
    final persisted = _read(preferences, key, actorUid);
    if (persisted == null || persisted.payloadFingerprint != fingerprint) {
      throw StateError(
        'Event retry information could not be verified. Nothing was sent.',
      );
    }
    return persisted;
  });

  Future<void> clearIfMatches({
    required String actorUid,
    required PendingOperationalEventCreation identity,
  }) => _serial(() async {
    final preferences = await _load();
    await preferences.reload();
    final key = _key(actorUid);
    final existing = _read(preferences, key, actorUid);
    if (existing == null ||
        existing.requestId != identity.requestId ||
        existing.eventId != identity.eventId ||
        existing.payloadFingerprint != identity.payloadFingerprint) {
      return;
    }
    if (!await preferences.remove(key)) {
      throw StateError(
        'The event outcome was confirmed; local retry information still needs clearing.',
      );
    }
  });
}
