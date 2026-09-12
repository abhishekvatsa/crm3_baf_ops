import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/persistence/request_identity_journal.dart';
import 'published_template_assignment_server_service.dart';

class PublishedTemplateAssignmentPendingIdentity {
  final String requestId;
  final String payloadFingerprint;

  const PublishedTemplateAssignmentPendingIdentity({
    required this.requestId,
    required this.payloadFingerprint,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'requestId': requestId,
    'payloadFingerprint': payloadFingerprint,
  };

  factory PublishedTemplateAssignmentPendingIdentity.fromMap(
    Map<String, dynamic> map,
  ) {
    return PublishedTemplateAssignmentPendingIdentity(
      requestId: readRequiredPersistedString(
        map['requestId'],
        field: 'requestId',
        source: 'pending governed assignment identity',
      ),
      payloadFingerprint: readRequiredPersistedString(
        map['payloadFingerprint'],
        field: 'payloadFingerprint',
        source: 'pending governed assignment identity',
      ),
    );
  }
}

/// Persists the idempotency identity used for a governed assignment request.
///
/// A callable may commit successfully while the client loses the response. By
/// keeping the request identity outside widget memory, an app restart can retry
/// unchanged assignment content without creating a second JobExecution.
/// Each changed fingerprint retains its own request; earlier uncertain identities
/// remain available. The form payload itself is not stored here.
class PublishedTemplateAssignmentIdempotencyStore {
  static const _keyPrefix = 'PENDING_GOVERNED_ASSIGNMENT::';

  final Future<SharedPreferences> Function() _preferencesLoader;
  static Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  RequestIdentityJournal<PublishedTemplateAssignmentPendingIdentity> _journal(
    String actorUid,
  ) => RequestIdentityJournal(
    legacyKey: _key(actorUid),
    decode: (raw) =>
        _decode(raw) ??
        (throw StateError(
          'Saved assignment retry evidence is empty and was preserved.',
        )),
    requestIdOf: (record) => record.requestId,
  );

  PublishedTemplateAssignmentIdempotencyStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  /// Migration reads preserve the old hash-only evidence exactly. It cannot be
  /// reconstructed into a dispatchable full assignment by the current account.
  Future<List<RetainedRequestBytes>> rawEvidence(String actorUid) =>
      _serial(() async {
        final actor = _required(actorUid, 'actorUid');
        final preferences = await _preferencesLoader();
        await preferences.reload();
        return _journal(actor).rawEvidence(preferences);
      });

  Future<PublishedTemplateAssignmentPendingIdentity> resolve({
    required String actorUid,
    required String payloadFingerprint,
  }) => _serial(() async {
    final normalizedActorUid = _required(actorUid, 'actorUid');
    final normalizedFingerprint = _required(
      payloadFingerprint,
      'payloadFingerprint',
    );
    final preferences = await _preferencesLoader();
    await preferences.reload();
    final journal = _journal(normalizedActorUid);
    final records = journal.readAll(preferences);
    for (final record in records) {
      if (record.value.payloadFingerprint == normalizedFingerprint) {
        return record.value;
      }
    }

    final next = PublishedTemplateAssignmentPendingIdentity(
      requestId: newPublishedTemplateAssignmentRequestId(),
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

  Future<PublishedTemplateAssignmentPendingIdentity?> read({
    required String actorUid,
  }) => _serial(() async {
    final normalizedActorUid = _required(actorUid, 'actorUid');
    final preferences = await _preferencesLoader();
    await preferences.reload();
    final records = _journal(normalizedActorUid).readAll(preferences);
    return records.isEmpty ? null : records.first.value;
  });

  String _key(String actorUid) => '$_keyPrefix$actorUid';

  PublishedTemplateAssignmentPendingIdentity? _decode(String? raw) {
    final cleaned = _clean(raw);
    if (cleaned == null) return null;
    final decoded = readRequiredJsonObject(
      cleaned,
      field: 'pendingAssignmentIdentity',
      source: 'SharedPreferences',
    );
    return PublishedTemplateAssignmentPendingIdentity.fromMap(decoded);
  }
}

final publishedTemplateAssignmentIdempotencyStoreProvider =
    Provider<PublishedTemplateAssignmentIdempotencyStore>((ref) {
      return PublishedTemplateAssignmentIdempotencyStore();
    });

String _required(String value, String field) {
  final cleaned = _clean(value);
  if (cleaned == null) {
    throw ArgumentError.value(value, field, '$field must not be blank.');
  }
  return cleaned;
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
