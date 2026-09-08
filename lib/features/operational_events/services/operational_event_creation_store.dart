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

class _StoredCreation {
  const _StoredCreation(this.key, this.identity, this.savedAtMicros);

  final String key;
  final PendingOperationalEventCreation identity;
  final int? savedAtMicros;
}

/// Every submitted creation has an actor/request slot until its result is known.
/// Matching payloads resume the earliest pending intent in this isolate. Separate
/// tabs may discover no pending work concurrently, but cannot overwrite each
/// other's distinct request identities.
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

  _StoredCreation? _read(
    SharedPreferences preferences,
    String key,
    String actorUid,
  ) {
    try {
      final raw = preferences.getString(key);
      if (raw == null) return null;
      final legacy = key == _key(actorUid);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != (legacy ? 5 : 6) ||
          decoded['schemaVersion'] != (legacy ? 1 : 2) ||
          decoded['requestId'] is! String ||
          !_uuidPattern.hasMatch(decoded['requestId'] as String) ||
          decoded['eventId'] is! String ||
          !_uuidPattern.hasMatch(decoded['eventId'] as String) ||
          decoded['payload'] is! Map<String, dynamic> ||
          (!legacy &&
              (decoded['savedAtMicros'] is! int ||
                  key != '${_key(actorUid)}::${decoded['requestId']}'))) {
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
      return _StoredCreation(
        key,
        PendingOperationalEventCreation(
          requestId: decoded['requestId'] as String,
          eventId: decoded['eventId'] as String,
          payloadFingerprint: decoded['payloadFingerprint'] as String,
          payload: Map.unmodifiable(payload),
        ),
        legacy ? null : decoded['savedAtMicros'] as int,
      );
    } on FormatException {
      throw StateError(
        'Saved event retry information needs recovery and was not replaced.',
      );
    } on TypeError {
      throw StateError(
        'Saved event retry information needs recovery and was not replaced.',
      );
    }
  }

  List<_StoredCreation> _readAll(
    SharedPreferences preferences,
    String actorUid,
  ) {
    final actorKey = _key(actorUid);
    final records = <_StoredCreation>[];
    for (final key in preferences.getKeys()) {
      if (key == actorKey || key.startsWith('$actorKey::')) {
        final record = _read(preferences, key, actorUid);
        if (record != null) records.add(record);
      }
    }
    records.sort((left, right) {
      // Legacy records predate the request-slot format and keep first priority.
      if (left.savedAtMicros == null && right.savedAtMicros != null) return -1;
      if (right.savedAtMicros == null && left.savedAtMicros != null) return 1;
      final chronology = (left.savedAtMicros ?? 0).compareTo(
        right.savedAtMicros ?? 0,
      );
      return chronology != 0 ? chronology : left.key.compareTo(right.key);
    });
    return records;
  }

  Future<PendingOperationalEventCreation?> pending(String actorUid) =>
      _serial(() async {
        final preferences = await _load();
        await preferences.reload();
        final records = _readAll(preferences, actorUid);
        return records.isEmpty ? null : records.first.identity;
      });

  Future<PendingOperationalEventCreation> resolve({
    required String actorUid,
    required Map<String, dynamic> payload,
  }) => _serial(() async {
    final actorKey = _key(actorUid);
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
    final records = _readAll(preferences, actorUid);
    if (records.isNotEmpty) {
      final existing = records.first.identity;
      if (existing.payloadFingerprint != fingerprint) {
        throw StateError(
          'Confirm the previous event before submitting a different event.',
        );
      }
      return existing;
    }
    final requestId = _uuid.v4();
    final eventId = _uuid.v4();
    final key = '$actorKey::$requestId';
    final saved = await preferences.setString(
      key,
      jsonEncode(<String, dynamic>{
        'schemaVersion': 2,
        'requestId': requestId,
        'eventId': eventId,
        'savedAtMicros': DateTime.now().microsecondsSinceEpoch,
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
    final persisted = _read(preferences, key, actorUid)?.identity;
    if (persisted == null ||
        persisted.requestId != requestId ||
        persisted.eventId != eventId ||
        persisted.payloadFingerprint != fingerprint) {
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
    final actorKey = _key(actorUid);
    // Never clear a shared actor prefix or another request's slot. The legacy
    // key remains readable/clearable without rewriting its pending identity.
    for (final key in ['$actorKey::${identity.requestId}', actorKey]) {
      final existing = _read(preferences, key, actorUid)?.identity;
      if (existing == null ||
          existing.requestId != identity.requestId ||
          existing.eventId != identity.eventId ||
          existing.payloadFingerprint != identity.payloadFingerprint) {
        continue;
      }
      if (!await preferences.remove(key)) {
        throw StateError(
          'The event outcome was confirmed; local retry information still needs clearing.',
        );
      }
      await preferences.reload();
      if (preferences.getKeys().contains(key)) {
        throw StateError(
          'The event outcome was confirmed; local retry information still needs clearing.',
        );
      }
    }
  });
}
