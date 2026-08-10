import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../serialization/persisted_data_reader.dart';
import 'global_pull_protocol.dart';

enum GlobalPullRunState {
  prepared('PREPARED'),
  committed('COMMITTED');

  final String wireName;

  const GlobalPullRunState(this.wireName);

  static GlobalPullRunState fromWireName(String value) {
    return values.firstWhere(
      (state) => state.wireName == value,
      orElse:
          () =>
              throw const GlobalPullCursorException(
                'The global pull run state is invalid.',
                reasonCode: 'cursor-state-invalid',
              ),
    );
  }
}

enum GlobalPullCursorOrigin {
  freshScope('FRESH_SCOPE'),
  legacyReset('LEGACY_RESET'),
  authorityChanged('AUTHORITY_CHANGED'),
  continuation('CONTINUATION');

  final String wireName;

  const GlobalPullCursorOrigin(this.wireName);

  static GlobalPullCursorOrigin fromWireName(String value) {
    return values.firstWhere(
      (origin) => origin.wireName == value,
      orElse:
          () =>
              throw const GlobalPullCursorException(
                'The global pull cursor origin is invalid.',
                reasonCode: 'cursor-origin-invalid',
              ),
    );
  }
}

class GlobalPullCursorException implements Exception {
  final String message;
  final String reasonCode;

  const GlobalPullCursorException(this.message, {required this.reasonCode});

  @override
  String toString() =>
      'GlobalPullCursorException(reason=$reasonCode, message=$message)';
}

class GlobalPullDomainCursor {
  static const Set<String> _exactKeys = <String>{'cursor', 'completedInRun'};

  final DateTime? cursor;
  final bool completedInRun;

  const GlobalPullDomainCursor({
    required this.cursor,
    required this.completedInRun,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'cursor': cursor?.toUtc().toIso8601String(),
    'completedInRun': completedInRun,
  };

  factory GlobalPullDomainCursor.fromJson(Object? value) {
    if (value is! Map) {
      throw const GlobalPullCursorException(
        'A global pull domain cursor is not an object.',
        reasonCode: 'domain-cursor-not-object',
      );
    }
    final data = Map<String, Object?>.from(value);
    if (data.keys.toSet().difference(_exactKeys).isNotEmpty ||
        _exactKeys.difference(data.keys.toSet()).isNotEmpty) {
      throw const GlobalPullCursorException(
        'A global pull domain cursor has an unsupported shape.',
        reasonCode: 'domain-cursor-invalid-shape',
      );
    }
    final completed = data['completedInRun'];
    if (completed is! bool) {
      throw const GlobalPullCursorException(
        'A global pull domain completion flag is invalid.',
        reasonCode: 'domain-cursor-completion-invalid',
      );
    }
    final rawCursor = data['cursor'];
    DateTime? cursor;
    if (rawCursor != null) {
      if (rawCursor is! String || !rawCursor.endsWith('Z')) {
        throw const GlobalPullCursorException(
          'A global pull domain cursor is not a canonical UTC instant.',
          reasonCode: 'domain-cursor-timestamp-invalid',
        );
      }
      try {
        cursor =
            readOptionalPersistedDateTime(
              data['cursor'],
              field: 'cursor',
              source: 'global pull domain cursor',
            )?.toUtc();
      } on PersistedDataFormatException {
        throw const GlobalPullCursorException(
          'A global pull domain cursor cannot be parsed.',
          reasonCode: 'domain-cursor-timestamp-invalid',
        );
      }
      if (cursor == null || cursor.toIso8601String() != rawCursor) {
        throw const GlobalPullCursorException(
          'A global pull domain cursor is not a canonical UTC instant.',
          reasonCode: 'domain-cursor-timestamp-invalid',
        );
      }
    }
    if (completed && cursor == null) {
      throw const GlobalPullCursorException(
        'A completed global pull domain has no server cursor.',
        reasonCode: 'domain-cursor-completed-without-value',
      );
    }
    return GlobalPullDomainCursor(cursor: cursor, completedInRun: completed);
  }

  GlobalPullDomainCursor prepare() =>
      GlobalPullDomainCursor(cursor: cursor, completedInRun: false);

  GlobalPullDomainCursor complete(DateTime serverAnchor) {
    final normalized = serverAnchor.toUtc();
    if (cursor != null && normalized.isBefore(cursor!)) {
      throw const GlobalPullCursorException(
        'A global pull cursor attempted to regress.',
        reasonCode: 'domain-cursor-regression',
      );
    }
    return GlobalPullDomainCursor(cursor: normalized, completedInRun: true);
  }
}

class GlobalPullRunEnvelope {
  static const int formatVersion = 1;
  static const Set<String> _exactKeys = <String>{
    'formatVersion',
    'state',
    'origin',
    'actorUid',
    'authorityDigest',
    'databaseGenerationId',
    'protocolVersion',
    'protocolFingerprint',
    'runId',
    'serverAnchor',
    'domains',
  };
  static final RegExp _uidPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final GlobalPullRunState state;
  final GlobalPullCursorOrigin origin;
  final String actorUid;
  final String authorityDigest;
  final String databaseGenerationId;
  final int protocolVersion;
  final String protocolFingerprint;
  final String runId;
  final DateTime serverAnchor;
  final Map<GlobalPullDomain, GlobalPullDomainCursor> domains;

  GlobalPullRunEnvelope({
    required this.state,
    required this.origin,
    required this.actorUid,
    required this.authorityDigest,
    required this.databaseGenerationId,
    required this.protocolVersion,
    required this.protocolFingerprint,
    required this.runId,
    required this.serverAnchor,
    required Map<GlobalPullDomain, GlobalPullDomainCursor> domains,
  }) : domains = Map<GlobalPullDomain, GlobalPullDomainCursor>.unmodifiable(
         domains,
       ) {
    _validate();
  }

  bool get isComplete =>
      domains.values.every((cursor) => cursor.completedInRun);

  GlobalPullDomainCursor cursorFor(GlobalPullDomain domain) => domains[domain]!;

  Map<String, Object?> toJson() => <String, Object?>{
    'formatVersion': formatVersion,
    'state': state.wireName,
    'origin': origin.wireName,
    'actorUid': actorUid,
    'authorityDigest': authorityDigest,
    'databaseGenerationId': databaseGenerationId,
    'protocolVersion': protocolVersion,
    'protocolFingerprint': protocolFingerprint,
    'runId': runId,
    'serverAnchor': serverAnchor.toUtc().toIso8601String(),
    'domains': <String, Object?>{
      for (final domain in GlobalPullDomain.values)
        domain.wireName: domains[domain]!.toJson(),
    },
  };

  String encode() => jsonEncode(toJson());

  factory GlobalPullRunEnvelope.decode(String encoded) {
    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw const GlobalPullCursorException(
        'The global pull cursor envelope is not valid JSON.',
        reasonCode: 'cursor-invalid-json',
      );
    }
    if (decoded is! Map) {
      throw const GlobalPullCursorException(
        'The global pull cursor envelope is not an object.',
        reasonCode: 'cursor-not-object',
      );
    }
    final data = Map<String, Object?>.from(decoded);
    if (data.keys.toSet().difference(_exactKeys).isNotEmpty ||
        _exactKeys.difference(data.keys.toSet()).isNotEmpty) {
      throw const GlobalPullCursorException(
        'The global pull cursor envelope has an unsupported shape.',
        reasonCode: 'cursor-invalid-shape',
      );
    }
    if (data['formatVersion'] != formatVersion) {
      throw const GlobalPullCursorException(
        'The global pull cursor format is unsupported.',
        reasonCode: 'cursor-format-unsupported',
      );
    }
    for (final field in <String>[
      'state',
      'origin',
      'actorUid',
      'authorityDigest',
      'databaseGenerationId',
      'protocolFingerprint',
      'runId',
    ]) {
      if (data[field] is! String) {
        throw const GlobalPullCursorException(
          'The global pull cursor contains a wrong-typed scalar.',
          reasonCode: 'cursor-field-type-invalid',
        );
      }
    }
    if (data['protocolVersion'] is! int) {
      throw const GlobalPullCursorException(
        'The global pull cursor protocol version has the wrong type.',
        reasonCode: 'cursor-field-type-invalid',
      );
    }
    final rawDomains = data['domains'];
    if (rawDomains is! Map) {
      throw const GlobalPullCursorException(
        'The global pull domain cursor set is not an object.',
        reasonCode: 'cursor-domains-not-object',
      );
    }
    final domainData = Map<String, Object?>.from(rawDomains);
    final expectedDomainKeys =
        GlobalPullDomain.values.map((domain) => domain.wireName).toSet();
    if (domainData.keys.toSet().difference(expectedDomainKeys).isNotEmpty ||
        expectedDomainKeys.difference(domainData.keys.toSet()).isNotEmpty) {
      throw const GlobalPullCursorException(
        'The global pull domain cursor set is incomplete.',
        reasonCode: 'cursor-domain-set-mismatch',
      );
    }

    final rawAnchor = data['serverAnchor'];
    if (rawAnchor is! String || !rawAnchor.endsWith('Z')) {
      throw const GlobalPullCursorException(
        'The global pull run anchor is not a canonical UTC instant.',
        reasonCode: 'cursor-server-anchor-invalid',
      );
    }
    final serverAnchor = DateTime.tryParse(rawAnchor)?.toUtc();
    if (serverAnchor == null) {
      throw const GlobalPullCursorException(
        'The global pull run anchor cannot be parsed.',
        reasonCode: 'cursor-server-anchor-invalid',
      );
    }

    return GlobalPullRunEnvelope(
      state: GlobalPullRunState.fromWireName(data['state']! as String),
      origin: GlobalPullCursorOrigin.fromWireName(data['origin']! as String),
      actorUid: data['actorUid']! as String,
      authorityDigest: data['authorityDigest']! as String,
      databaseGenerationId: data['databaseGenerationId']! as String,
      protocolVersion: data['protocolVersion']! as int,
      protocolFingerprint: data['protocolFingerprint']! as String,
      runId: data['runId']! as String,
      serverAnchor: serverAnchor,
      domains: <GlobalPullDomain, GlobalPullDomainCursor>{
        for (final domain in GlobalPullDomain.values)
          domain: GlobalPullDomainCursor.fromJson(domainData[domain.wireName]),
      },
    );
  }

  GlobalPullRunEnvelope prepareNext({
    required String nextRunId,
    required DateTime nextServerAnchor,
  }) {
    return GlobalPullRunEnvelope(
      state: GlobalPullRunState.prepared,
      origin: GlobalPullCursorOrigin.continuation,
      actorUid: actorUid,
      authorityDigest: authorityDigest,
      databaseGenerationId: databaseGenerationId,
      protocolVersion: protocolVersion,
      protocolFingerprint: protocolFingerprint,
      runId: nextRunId,
      serverAnchor: nextServerAnchor.toUtc(),
      domains: <GlobalPullDomain, GlobalPullDomainCursor>{
        for (final entry in domains.entries) entry.key: entry.value.prepare(),
      },
    );
  }

  GlobalPullRunEnvelope completeDomain(GlobalPullDomain domain) {
    return GlobalPullRunEnvelope(
      state: GlobalPullRunState.prepared,
      origin: origin,
      actorUid: actorUid,
      authorityDigest: authorityDigest,
      databaseGenerationId: databaseGenerationId,
      protocolVersion: protocolVersion,
      protocolFingerprint: protocolFingerprint,
      runId: runId,
      serverAnchor: serverAnchor,
      domains: <GlobalPullDomain, GlobalPullDomainCursor>{
        for (final entry in domains.entries)
          entry.key:
              entry.key == domain
                  ? entry.value.complete(serverAnchor)
                  : entry.value,
      },
    );
  }

  GlobalPullRunEnvelope commit() {
    if (!isComplete) {
      throw const GlobalPullCursorException(
        'The global pull run cannot commit before every domain completes.',
        reasonCode: 'cursor-commit-incomplete',
      );
    }
    return GlobalPullRunEnvelope(
      state: GlobalPullRunState.committed,
      origin: origin,
      actorUid: actorUid,
      authorityDigest: authorityDigest,
      databaseGenerationId: databaseGenerationId,
      protocolVersion: protocolVersion,
      protocolFingerprint: protocolFingerprint,
      runId: runId,
      serverAnchor: serverAnchor,
      domains: domains,
    );
  }

  void _validate() {
    if (!_uidPattern.hasMatch(actorUid)) {
      throw const GlobalPullCursorException(
        'The global pull cursor actor UID is invalid.',
        reasonCode: 'cursor-actor-invalid',
      );
    }
    if (!RegExp(r'^auth1-sha256:[0-9a-f]{64}$').hasMatch(authorityDigest)) {
      throw const GlobalPullCursorException(
        'The global pull cursor authority digest is invalid.',
        reasonCode: 'cursor-authority-digest-invalid',
      );
    }
    if (!_uuidPattern.hasMatch(databaseGenerationId)) {
      throw const GlobalPullCursorException(
        'The global pull cursor database generation is invalid.',
        reasonCode: 'cursor-generation-invalid',
      );
    }
    if (!_uuidPattern.hasMatch(runId)) {
      throw const GlobalPullCursorException(
        'The global pull run identity is invalid.',
        reasonCode: 'cursor-run-id-invalid',
      );
    }
    if (protocolVersion != globalPullProtocolVersion ||
        protocolFingerprint != globalPullProtocolFingerprint) {
      throw const GlobalPullCursorException(
        'The global pull cursor protocol is incompatible.',
        reasonCode: 'cursor-protocol-mismatch',
      );
    }
    if (domains.length != GlobalPullDomain.values.length ||
        !domains.keys.toSet().containsAll(GlobalPullDomain.values)) {
      throw const GlobalPullCursorException(
        'The global pull domain cursor set is incomplete.',
        reasonCode: 'cursor-domain-set-mismatch',
      );
    }
    for (final cursor in domains.values) {
      if (cursor.cursor != null && cursor.cursor!.isAfter(serverAnchor)) {
        throw const GlobalPullCursorException(
          'A global pull domain cursor exceeds its run anchor.',
          reasonCode: 'domain-cursor-after-anchor',
        );
      }
    }
    if (state == GlobalPullRunState.committed && !isComplete) {
      throw const GlobalPullCursorException(
        'A committed global pull run is incomplete.',
        reasonCode: 'cursor-committed-incomplete',
      );
    }
  }
}

class SharedPreferencesGlobalPullCursorStore {
  static const String keyPrefix = 'baf_global_pull_cursor_v1';
  static const String legacyGlobalCursorKey = 'last_global_pull';

  final SharedPreferences preferences;

  const SharedPreferencesGlobalPullCursorStore(this.preferences);

  String keyFor({
    required String actorUid,
    required String databaseGenerationId,
  }) => '$keyPrefix:$actorUid:$databaseGenerationId';

  GlobalPullRunEnvelope? read({
    required String actorUid,
    required String databaseGenerationId,
  }) {
    final key = keyFor(
      actorUid: actorUid,
      databaseGenerationId: databaseGenerationId,
    );
    final value = preferences.get(key);
    if (value == null) return null;
    if (value is! String) {
      throw const GlobalPullCursorException(
        'The global pull cursor has an invalid stored type.',
        reasonCode: 'cursor-storage-type-invalid',
      );
    }
    final envelope = GlobalPullRunEnvelope.decode(value);
    if (envelope.actorUid != actorUid ||
        envelope.databaseGenerationId != databaseGenerationId) {
      throw const GlobalPullCursorException(
        'The global pull cursor is stored under the wrong scope.',
        reasonCode: 'cursor-scope-mismatch',
      );
    }
    return envelope;
  }

  Future<GlobalPullRunEnvelope> begin({
    required String actorUid,
    required String databaseGenerationId,
    required GlobalPullRunAuthority authority,
    required String runId,
  }) async {
    if (authority.actorUid != actorUid) {
      throw const GlobalPullCursorException(
        'The global pull authority belongs to another actor.',
        reasonCode: 'cursor-authority-actor-mismatch',
      );
    }
    final existing = read(
      actorUid: actorUid,
      databaseGenerationId: databaseGenerationId,
    );
    if (existing != null &&
        existing.state == GlobalPullRunState.prepared &&
        existing.authorityDigest == authority.authorityDigest) {
      if (existing.serverAnchor.isAfter(authority.serverAnchor)) {
        throw const GlobalPullCursorException(
          'The prepared global pull run is ahead of the backend clock.',
          reasonCode: 'cursor-prepared-anchor-in-future',
        );
      }
      return existing;
    }

    final authorityChanged =
        existing != null &&
        existing.authorityDigest != authority.authorityDigest;
    final prepared =
        existing == null || authorityChanged
            ? GlobalPullRunEnvelope(
              state: GlobalPullRunState.prepared,
              origin:
                  authorityChanged
                      ? GlobalPullCursorOrigin.authorityChanged
                      : preferences.containsKey(legacyGlobalCursorKey)
                      ? GlobalPullCursorOrigin.legacyReset
                      : GlobalPullCursorOrigin.freshScope,
              actorUid: actorUid,
              authorityDigest: authority.authorityDigest,
              databaseGenerationId: databaseGenerationId,
              protocolVersion: globalPullProtocolVersion,
              protocolFingerprint: globalPullProtocolFingerprint,
              runId: runId,
              serverAnchor: authority.serverAnchor,
              domains: <GlobalPullDomain, GlobalPullDomainCursor>{
                for (final domain in GlobalPullDomain.values)
                  domain: const GlobalPullDomainCursor(
                    cursor: null,
                    completedInRun: false,
                  ),
              },
            )
            : existing.prepareNext(
              nextRunId: runId,
              nextServerAnchor: authority.serverAnchor,
            );
    await write(prepared);
    return prepared;
  }

  Future<GlobalPullRunEnvelope> completeDomain(
    GlobalPullRunEnvelope envelope,
    GlobalPullDomain domain,
  ) async {
    final completed = envelope.completeDomain(domain);
    await write(completed);
    return completed;
  }

  Future<GlobalPullRunEnvelope> commit(GlobalPullRunEnvelope envelope) async {
    final committed = envelope.commit();
    await write(committed);
    if (preferences.containsKey(legacyGlobalCursorKey)) {
      final removed = await preferences.remove(legacyGlobalCursorKey);
      if (!removed || preferences.containsKey(legacyGlobalCursorKey)) {
        throw const GlobalPullCursorException(
          'The legacy client-time global cursor could not be retired.',
          reasonCode: 'legacy-cursor-clear-failed',
        );
      }
    }
    return committed;
  }

  Future<void> write(GlobalPullRunEnvelope envelope) async {
    final key = keyFor(
      actorUid: envelope.actorUid,
      databaseGenerationId: envelope.databaseGenerationId,
    );
    final encoded = envelope.encode();
    final written = await preferences.setString(key, encoded);
    if (!written || preferences.getString(key) != encoded) {
      throw const GlobalPullCursorException(
        'The global pull cursor could not be written and read back exactly.',
        reasonCode: 'cursor-write-failed',
      );
    }
  }
}
