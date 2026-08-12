import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../repositories/firestore_workflow_read_repository.dart';
import '../repositories/workflow_repository.dart';

typedef WorkflowPullPreferenceStringReader =
    String? Function(SharedPreferences preferences, String key);
typedef WorkflowPullPreferenceStringWriter =
    Future<bool> Function(
      SharedPreferences preferences,
      String key,
      String value,
    );

String? _readPreferenceString(SharedPreferences preferences, String key) =>
    preferences.getString(key);

Future<bool> _writePreferenceString(
  SharedPreferences preferences,
  String key,
  String value,
) => preferences.setString(key, value);

class WorkflowPullStateException extends FormatException {
  final String reasonCode;

  WorkflowPullStateException({
    required this.reasonCode,
    required String message,
    Object? source,
  }) : super(message, source);

  @override
  String toString() =>
      'WorkflowPullStateException(reason=$reasonCode, message=$message)';
}

class WorkflowPullQuarantineRecord {
  final String collection;
  final String documentId;
  final String stage;
  final String error;
  final DateTime? observedAt;
  final DateTime quarantinedAt;

  const WorkflowPullQuarantineRecord({
    required this.collection,
    required this.documentId,
    required this.stage,
    required this.error,
    required this.observedAt,
    required this.quarantinedAt,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'collection': collection,
    'documentId': documentId,
    'stage': stage,
    'error': error,
    'observedAt': observedAt?.toUtc().toIso8601String(),
    'quarantinedAt': quarantinedAt.toUtc().toIso8601String(),
  };

  factory WorkflowPullQuarantineRecord.fromJson(Map<String, dynamic> json) {
    const source = 'workflow pull quarantine record';
    return WorkflowPullQuarantineRecord(
      collection: readRequiredPersistedString(
        json['collection'],
        field: 'collection',
        source: source,
      ),
      documentId: readRequiredPersistedString(
        json['documentId'],
        field: 'documentId',
        source: source,
      ),
      stage: readRequiredPersistedString(
        json['stage'],
        field: 'stage',
        source: source,
      ),
      error: readRequiredPersistedString(
        json['error'],
        field: 'error',
        source: source,
      ),
      observedAt:
          readOptionalPersistedDateTime(
            json['observedAt'],
            field: 'observedAt',
            source: source,
          )?.toUtc(),
      quarantinedAt:
          readRequiredPersistedDateTime(
            json['quarantinedAt'],
            field: 'quarantinedAt',
            source: source,
          ).toUtc(),
    );
  }
}

class WorkflowPullSummary {
  final int workflows;
  final int lanes;
  final int compliance;
  final int attempts;
  final int equipment;
  final int prompts;
  final int events;
  final Map<String, String> failures;
  final List<WorkflowPullQuarantineRecord> quarantinedRecords;

  const WorkflowPullSummary({
    required this.workflows,
    required this.lanes,
    required this.compliance,
    required this.attempts,
    required this.equipment,
    required this.prompts,
    required this.events,
    this.failures = const <String, String>{},
    this.quarantinedRecords = const <WorkflowPullQuarantineRecord>[],
  });

  bool get hasFailures => failures.isNotEmpty || quarantinedRecords.isNotEmpty;
}

class WorkflowPullService {
  static const _prefix = 'last_maintenance_workflow_pull_v2';
  static const _workflowKey = '${_prefix}_workflows';
  static const _laneKey = '${_prefix}_lanes';
  static const _complianceKey = '${_prefix}_compliance';
  static const _attemptKey = '${_prefix}_attempts';
  static const _equipmentKey = '${_prefix}_equipment';
  static const _promptKey = '${_prefix}_prompts';
  static const _eventKey = '${_prefix}_events';
  static const _quarantineKey = '${_prefix}_quarantine';
  static const _maxQuarantineRecords = 100;

  final WorkflowRemoteReadRepository remote;
  final WorkflowRepository local;
  final WorkflowPullPreferenceStringReader _preferenceReader;
  final WorkflowPullPreferenceStringWriter _preferenceWriter;

  const WorkflowPullService({
    required this.remote,
    required this.local,
    WorkflowPullPreferenceStringReader preferenceReader = _readPreferenceString,
    WorkflowPullPreferenceStringWriter preferenceWriter =
        _writePreferenceString,
  }) : _preferenceReader = preferenceReader,
       _preferenceWriter = preferenceWriter;

  /// Pulls each projection independently and quarantines malformed records.
  ///
  /// A bad document must not block valid siblings. Mapping and local-upsert
  /// failures are retained as capped local diagnostics. Remote mapping failures
  /// with a valid timestamp are retried after the server document changes. Any
  /// local-upsert failure holds the watermark so the unchanged record is retried.
  Future<WorkflowPullSummary> pull() async {
    final prefs = await SharedPreferences.getInstance();
    final failures = <String, String>{};
    final quarantined = <WorkflowPullQuarantineRecord>[];

    final workflows = await _pullCollection(
      prefs: prefs,
      key: _workflowKey,
      name: 'workflows',
      fetch: remote.fetchWorkflowsUpdatedSince,
      upsert: local.upsertWorkflowFromRemote,
      identity: (record) => record.firestoreId,
      timestamp: (record) => record.updatedAt,
      failures: failures,
      quarantined: quarantined,
    );
    final lanes = await _pullCollection(
      prefs: prefs,
      key: _laneKey,
      name: 'lanes',
      fetch: remote.fetchLanesUpdatedSince,
      upsert: local.upsertLaneFromRemote,
      identity: (record) => record.firestoreId ?? 'unknown-lane',
      timestamp: (record) => record.updatedAt,
      failures: failures,
      quarantined: quarantined,
    );
    final compliance = await _pullCollection(
      prefs: prefs,
      key: _complianceKey,
      name: 'compliance',
      fetch: remote.fetchComplianceUpdatedSince,
      upsert: local.upsertComplianceFromRemote,
      identity: (record) => record.firestoreId ?? 'unknown-compliance',
      timestamp: (record) => record.updatedAt,
      failures: failures,
      quarantined: quarantined,
    );
    final attempts = await _pullCollection(
      prefs: prefs,
      key: _attemptKey,
      name: 'attempts',
      fetch: remote.fetchAttemptsAfter,
      upsert: local.upsertComplianceAttemptFromRemote,
      identity: (record) => record.firestoreId,
      timestamp: (record) => record.attemptedAt,
      failures: failures,
      quarantined: quarantined,
    );
    final equipment = await _pullCollection(
      prefs: prefs,
      key: _equipmentKey,
      name: 'equipment',
      fetch: remote.fetchEquipmentUpdatedSince,
      upsert: local.upsertEquipmentFromRemote,
      identity: (record) => record.firestoreId ?? 'unknown-equipment',
      timestamp: (record) => record.updatedAt,
      failures: failures,
      quarantined: quarantined,
    );
    final prompts = await _pullCollection(
      prefs: prefs,
      key: _promptKey,
      name: 'prompts',
      fetch: remote.fetchPromptsUpdatedSince,
      upsert: local.upsertPromptFromRemote,
      identity: (record) => record.firestoreId ?? 'unknown-prompt',
      timestamp: (record) => record.updatedAt,
      failures: failures,
      quarantined: quarantined,
    );
    final events = await _pullCollection(
      prefs: prefs,
      key: _eventKey,
      name: 'events',
      fetch: remote.fetchEventsAfter,
      upsert: local.upsertEventFromRemote,
      identity: (record) => record.firestoreId ?? 'unknown-event',
      timestamp: (record) => record.occurredAt,
      failures: failures,
      quarantined: quarantined,
    );

    return WorkflowPullSummary(
      workflows: workflows,
      lanes: lanes,
      compliance: compliance,
      attempts: attempts,
      equipment: equipment,
      prompts: prompts,
      events: events,
      failures: Map<String, String>.unmodifiable(failures),
      quarantinedRecords: List<WorkflowPullQuarantineRecord>.unmodifiable(
        quarantined,
      ),
    );
  }

  static Future<List<WorkflowPullQuarantineRecord>> readQuarantine() async {
    final prefs = await SharedPreferences.getInstance();
    return _readStoredQuarantine(prefs, _readPreferenceString);
  }

  static Future<void> clearQuarantine() async {
    final prefs = await SharedPreferences.getInstance();
    final removed = await prefs.remove(_quarantineKey);
    if (!removed || prefs.containsKey(_quarantineKey)) {
      throw WorkflowPullStateException(
        reasonCode: 'workflow-pull-quarantine-clear-failed',
        message: 'Stored workflow pull quarantine could not be cleared.',
      );
    }
  }

  Future<int> _pullCollection<T>({
    required SharedPreferences prefs,
    required String key,
    required String name,
    required Future<WorkflowRemoteBatch<T>> Function(DateTime? since) fetch,
    required Future<void> Function(T record) upsert,
    required String Function(T record) identity,
    required DateTime Function(T record) timestamp,
    required Map<String, String> failures,
    required List<WorkflowPullQuarantineRecord> quarantined,
  }) async {
    try {
      final quarantineStart = quarantined.length;
      final storedQuarantine = _readStoredQuarantine(prefs, _preferenceReader);
      final hasStoredCollectionQuarantine = storedQuarantine.any(
        (record) => record.collection == name,
      );
      final batch = await fetch(_since(prefs, key));
      final now = DateTime.now().toUtc();
      for (final failure in batch.failures) {
        quarantined.add(
          WorkflowPullQuarantineRecord(
            collection: name,
            documentId: failure.documentId,
            stage: 'remote-map',
            error: failure.error,
            observedAt: failure.observedAt,
            quarantinedAt: now,
          ),
        );
      }

      var saved = 0;
      final observed = <DateTime>[...batch.observedTimestamps];
      final unknownFailureTimestamp = batch.failures.any(
        (failure) => failure.observedAt == null,
      );
      var localUpsertFailed = false;
      for (final record in batch.records) {
        final recordTimestamp = timestamp(record).toUtc();
        if (!observed.contains(recordTimestamp)) observed.add(recordTimestamp);
        try {
          await upsert(record);
          saved += 1;
        } catch (error) {
          localUpsertFailed = true;
          quarantined.add(
            WorkflowPullQuarantineRecord(
              collection: name,
              documentId: identity(record),
              stage: 'local-upsert',
              error: '$error',
              observedAt: recordTimestamp,
              quarantinedAt: now,
            ),
          );
        }
      }

      final collectionRecords = quarantined.sublist(quarantineStart);
      final collectionQuarantine = collectionRecords.length;
      if (collectionQuarantine > 0) {
        failures[name] = '$collectionQuarantine record(s) quarantined';
        await _appendQuarantine(prefs, collectionRecords);
      }
      final cursorBlocked =
          hasStoredCollectionQuarantine ||
          collectionQuarantine > 0 ||
          unknownFailureTimestamp ||
          localUpsertFailed;
      if (!cursorBlocked) {
        await _advance(prefs, key, observed);
      } else {
        final reasons = <String>[
          if (hasStoredCollectionQuarantine)
            'an existing quarantine requires explicit repair and clearance',
          if (collectionQuarantine > 0)
            'the current batch contains quarantined records',
          if (unknownFailureTimestamp)
            'a failed record had no valid server timestamp',
          if (localUpsertFailed) 'a local upsert failed',
        ];
        failures[name] =
            '${failures[name] ?? 'Record quarantine'}; watermark held because ${reasons.join(' and ')}';
      }
      return saved;
    } catch (error) {
      failures[name] = '$error';
      return 0;
    }
  }

  DateTime? _since(SharedPreferences prefs, String key) {
    try {
      final raw = _preferenceReader(prefs, key);
      if (raw == null) return null;
      final data = <String, Object?>{'cursor': raw};
      return readRequiredPersistedDateTime(
        data['cursor'],
        field: 'cursor',
        source: 'workflow pull cursor',
      ).toUtc();
    } catch (error) {
      throw WorkflowPullStateException(
        reasonCode: 'workflow-pull-cursor-invalid',
        message: 'Stored workflow pull cursor needs repair.',
        source: error,
      );
    }
  }

  Future<void> _advance(
    SharedPreferences prefs,
    String key,
    Iterable<DateTime> timestamps,
  ) async {
    final values = timestamps
        .map((value) => value.toUtc())
        .toList(growable: false);
    if (values.isEmpty) return;
    values.sort();
    await _writeExactly(
      prefs,
      key,
      values.last.toIso8601String(),
      reasonCode: 'workflow-pull-cursor-write-failed',
      message: 'Workflow pull cursor could not be written and read back.',
    );
  }

  Future<void> _appendQuarantine(
    SharedPreferences prefs,
    List<WorkflowPullQuarantineRecord> newRecords,
  ) async {
    if (newRecords.isEmpty) return;
    final existing = _readStoredQuarantine(prefs, _preferenceReader);
    final byIdentity = <String, WorkflowPullQuarantineRecord>{};
    for (final record in <WorkflowPullQuarantineRecord>[
      ...existing,
      ...newRecords,
    ]) {
      final identity = <String>[
        record.collection,
        record.documentId,
        record.stage,
        record.observedAt?.toUtc().toIso8601String() ?? 'unknown-time',
      ].join('|');
      byIdentity[identity] = record;
    }
    final combined =
        byIdentity.values.toList()
          ..sort((a, b) => a.quarantinedAt.compareTo(b.quarantinedAt));
    final retained =
        combined.length <= _maxQuarantineRecords
            ? combined
            : combined.sublist(combined.length - _maxQuarantineRecords);
    final encoded = jsonEncode(
      retained.map((record) => record.toJson()).toList(growable: false),
    );
    await _writeExactly(
      prefs,
      _quarantineKey,
      encoded,
      reasonCode: 'workflow-pull-quarantine-write-failed',
      message: 'Workflow pull quarantine could not be written and read back.',
    );
  }

  Future<void> _writeExactly(
    SharedPreferences prefs,
    String key,
    String value, {
    required String reasonCode,
    required String message,
  }) async {
    String? previousValue;
    var writeAttempted = false;
    try {
      previousValue = _preferenceReader(prefs, key);
      writeAttempted = true;
      final written = await _preferenceWriter(prefs, key, value);
      if (!written || _preferenceReader(prefs, key) != value) {
        throw WorkflowPullStateException(
          reasonCode: reasonCode,
          message: message,
        );
      }
    } catch (error) {
      if (writeAttempted) {
        await _restorePreferenceAfterFailedWrite(prefs, key, previousValue);
      }
      if (error is WorkflowPullStateException) rethrow;
      throw WorkflowPullStateException(
        reasonCode: reasonCode,
        message: message,
        source: error,
      );
    }
  }

  static Future<void> _restorePreferenceAfterFailedWrite(
    SharedPreferences prefs,
    String key,
    String? previousValue,
  ) async {
    try {
      if (previousValue == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, previousValue);
      }
    } catch (_) {
      // The original exact-write failure remains authoritative.
    }
  }

  static List<WorkflowPullQuarantineRecord> _readStoredQuarantine(
    SharedPreferences prefs,
    WorkflowPullPreferenceStringReader reader,
  ) {
    try {
      return _decodeQuarantine(reader(prefs, _quarantineKey));
    } on WorkflowPullStateException {
      rethrow;
    } catch (error) {
      throw WorkflowPullStateException(
        reasonCode: 'workflow-pull-quarantine-invalid',
        message: 'Stored workflow pull quarantine needs repair.',
        source: error,
      );
    }
  }

  static List<WorkflowPullQuarantineRecord> _decodeQuarantine(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <WorkflowPullQuarantineRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Expected a quarantine array.');
      }
      return <WorkflowPullQuarantineRecord>[
        for (var index = 0; index < decoded.length; index++)
          if (decoded[index] is Map)
            WorkflowPullQuarantineRecord.fromJson(
              Map<String, dynamic>.from(decoded[index] as Map),
            )
          else
            throw FormatException(
              'Expected a quarantine object at index $index.',
            ),
      ];
    } catch (error) {
      throw WorkflowPullStateException(
        reasonCode: 'workflow-pull-quarantine-invalid',
        message: 'Stored workflow pull quarantine needs repair.',
        source: error,
      );
    }
  }
}
