import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RetainedRequest<T> {
  const RetainedRequest(this.key, this.value, this.savedAtMicros);

  final String key;
  final T value;
  final int? savedAtMicros;
}

/// Immutable request slots prevent independently cached runtimes from replacing
/// submitted work. Domain decoders retain ownership of each record's contract.
/// The exact legacy slot remains readable; current writers never replace it.
class RequestIdentityJournal<T> {
  RequestIdentityJournal({
    required this.legacyKey,
    required this.decode,
    required this.requestIdOf,
    this.failure = StateError.new,
  });

  final String legacyKey;
  final T Function(String raw) decode;
  final String Function(T value) requestIdOf;
  final Object Function(String message) failure;

  String get _prefix =>
      'PENDING_REQUEST_JOURNAL::'
      '${sha256.convert(utf8.encode(legacyKey))}::';

  Never _fail(String message) => throw failure(message);

  RetainedRequest<T>? _read(SharedPreferences preferences, String key) {
    final String? raw;
    try {
      raw = preferences.getString(key);
    } on TypeError {
      _fail(
        'Saved retry evidence has an invalid storage type and was preserved.',
      );
    }
    if (raw == null) return null;
    if (key == legacyKey) return RetainedRequest(key, decode(raw), null);

    final dynamic envelope;
    try {
      envelope = jsonDecode(raw);
    } on FormatException {
      _fail('Saved retry evidence is damaged and was preserved.');
    }
    if (envelope is! Map<String, dynamic> ||
        envelope.length != 3 ||
        envelope['journalVersion'] != 1 ||
        envelope['savedAtMicros'] is! int ||
        (envelope['savedAtMicros'] as int) <= 0 ||
        (envelope['savedAtMicros'] as int) > 9007199254740991 ||
        envelope['record'] is! Map<String, dynamic>) {
      _fail('Saved retry evidence has an invalid envelope and was preserved.');
    }
    final value = decode(jsonEncode(envelope['record']));
    if (key != '$_prefix${requestIdOf(value)}') {
      _fail(
        'Saved retry evidence does not match its request slot and was preserved.',
      );
    }
    return RetainedRequest(key, value, envelope['savedAtMicros'] as int);
  }

  List<RetainedRequest<T>> readAll(SharedPreferences preferences) {
    final records = <RetainedRequest<T>>[];
    final requestIds = <String>{};
    for (final key in preferences.getKeys()) {
      if (key != legacyKey && !key.startsWith(_prefix)) continue;
      final record = _read(preferences, key);
      if (record == null) continue;
      if (!requestIds.add(requestIdOf(record.value))) {
        _fail(
          'More than one saved record claims the same request. Evidence was preserved.',
        );
      }
      records.add(record);
    }
    records.sort((left, right) {
      if (left.savedAtMicros == null && right.savedAtMicros != null) return -1;
      if (right.savedAtMicros == null && left.savedAtMicros != null) return 1;
      final chronology = (left.savedAtMicros ?? 0).compareTo(
        right.savedAtMicros ?? 0,
      );
      return chronology != 0 ? chronology : left.key.compareTo(right.key);
    });
    return records;
  }

  Future<T> append(
    SharedPreferences preferences,
    Map<String, dynamic> record,
  ) async {
    final value = decode(jsonEncode(record));
    final key = '$_prefix${requestIdOf(value)}';
    if (preferences.getKeys().contains(key)) {
      _fail('A saved request already owns this slot. Nothing was sent.');
    }
    final serialized = jsonEncode({
      'journalVersion': 1,
      'savedAtMicros': DateTime.now().microsecondsSinceEpoch,
      'record': record,
    });
    if (!await preferences.setString(key, serialized)) {
      _fail('Could not retain retry evidence. Nothing was sent.');
    }
    await preferences.reload();
    if (preferences.getString(key) != serialized) {
      _fail('Stored retry evidence could not be verified. Nothing was sent.');
    }
    final retained = _read(preferences, key);
    if (retained == null) {
      _fail('Stored retry evidence disappeared. Nothing was sent.');
    }
    return retained.value;
  }

  Future<void> clearMatching(
    SharedPreferences preferences,
    bool Function(T) matches,
  ) async {
    final records = readAll(preferences);
    for (final record in records.where((record) => matches(record.value))) {
      if (!await preferences.remove(record.key)) {
        _fail(
          'The result was confirmed, but its local retry evidence still needs clearing.',
        );
      }
      await preferences.reload();
      if (preferences.getKeys().contains(record.key)) {
        _fail(
          'The result was confirmed, but its local retry evidence still needs clearing.',
        );
      }
    }
  }
}
