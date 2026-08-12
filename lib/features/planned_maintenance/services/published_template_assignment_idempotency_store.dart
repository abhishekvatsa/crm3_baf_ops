import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/serialization/persisted_data_reader.dart';
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
class PublishedTemplateAssignmentIdempotencyStore {
  static const _keyPrefix = 'PENDING_GOVERNED_ASSIGNMENT::';

  final Future<SharedPreferences> Function() _preferencesLoader;

  PublishedTemplateAssignmentIdempotencyStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  Future<PublishedTemplateAssignmentPendingIdentity> resolve({
    required String actorUid,
    required String payloadFingerprint,
  }) async {
    final normalizedActorUid = _required(actorUid, 'actorUid');
    final normalizedFingerprint = _required(
      payloadFingerprint,
      'payloadFingerprint',
    );
    final preferences = await _preferencesLoader();
    final key = _key(normalizedActorUid);
    final existing = _decode(preferences.getString(key));
    if (existing != null &&
        existing.payloadFingerprint == normalizedFingerprint) {
      return existing;
    }

    final next = PublishedTemplateAssignmentPendingIdentity(
      requestId: newPublishedTemplateAssignmentRequestId(),
      payloadFingerprint: normalizedFingerprint,
    );
    final written = await preferences.setString(key, jsonEncode(next.toMap()));
    if (!written) {
      throw StateError(
        'The assignment retry identity could not be persisted safely.',
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
    if (existing == null || existing.requestId != normalizedRequestId) {
      return;
    }
    await preferences.remove(key);
  }

  Future<PublishedTemplateAssignmentPendingIdentity?> read({
    required String actorUid,
  }) async {
    final normalizedActorUid = _required(actorUid, 'actorUid');
    final preferences = await _preferencesLoader();
    return _decode(preferences.getString(_key(normalizedActorUid)));
  }

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
