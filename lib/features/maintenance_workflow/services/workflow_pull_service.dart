import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/firestore_workflow_read_repository.dart';
import '../repositories/workflow_repository.dart';

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
    return WorkflowPullQuarantineRecord(
      collection: json['collection']?.toString() ?? 'unknown',
      documentId: json['documentId']?.toString() ?? 'unknown',
      stage: json['stage']?.toString() ?? 'unknown',
      error: json['error']?.toString() ?? 'Unknown workflow pull failure',
      observedAt: DateTime.tryParse(json['observedAt']?.toString() ?? '')?.toUtc(),
      quarantinedAt: DateTime.tryParse(json['quarantinedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
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

  final FirestoreWorkflowReadRepository remote;
  final WorkflowRepository local;

  const WorkflowPullService({required this.remote, required this.local});

  /// Pulls each projection independently and quarantines malformed records.
  ///
  /// A bad document must not block valid siblings. Mapping and local-upsert
  /// failures are retained as capped local diagnostics. A failed document with
  /// a valid server timestamp is skipped by the current watermark but will be
  /// fetched again if corrected because its `updatedAt`/event timestamp changes.
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

    await _appendQuarantine(prefs, quarantined);
    return WorkflowPullSummary(
      workflows: workflows,
      lanes: lanes,
      compliance: compliance,
      attempts: attempts,
      equipment: equipment,
      prompts: prompts,
      events: events,
      failures: Map<String, String>.unmodifiable(failures),
      quarantinedRecords: List<WorkflowPullQuarantineRecord>.unmodifiable(quarantined),
    );
  }

  static Future<List<WorkflowPullQuarantineRecord>> readQuarantine() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeQuarantine(prefs.getString(_quarantineKey));
  }

  static Future<void> clearQuarantine() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_quarantineKey);
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
      final unknownFailureTimestamp =
          batch.failures.any((failure) => failure.observedAt == null);
      for (final record in batch.records) {
        final recordTimestamp = timestamp(record).toUtc();
        if (!observed.contains(recordTimestamp)) observed.add(recordTimestamp);
        try {
          await upsert(record);
          saved += 1;
        } catch (error) {
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

      final collectionQuarantine = quarantined.where((record) => record.collection == name).length;
      if (collectionQuarantine > 0) {
        failures[name] = '$collectionQuarantine record(s) quarantined';
      }
      if (!unknownFailureTimestamp) {
        await _advance(prefs, key, observed);
      } else {
        failures[name] = '${failures[name] ?? 'Record quarantine'}; watermark held because a failed record had no valid server timestamp';
      }
      return saved;
    } catch (error) {
      failures[name] = '$error';
      return 0;
    }
  }

  DateTime? _since(SharedPreferences prefs, String key) =>
      DateTime.tryParse(prefs.getString(key) ?? '')?.toUtc();

  Future<void> _advance(
    SharedPreferences prefs,
    String key,
    Iterable<DateTime> timestamps,
  ) async {
    final values = timestamps.map((value) => value.toUtc()).toList(growable: false);
    if (values.isEmpty) return;
    values.sort();
    await prefs.setString(key, values.last.toIso8601String());
  }

  Future<void> _appendQuarantine(
    SharedPreferences prefs,
    List<WorkflowPullQuarantineRecord> newRecords,
  ) async {
    if (newRecords.isEmpty) return;
    final existing = _decodeQuarantine(prefs.getString(_quarantineKey));
    final combined = <WorkflowPullQuarantineRecord>[...existing, ...newRecords]
      ..sort((a, b) => a.quarantinedAt.compareTo(b.quarantinedAt));
    final retained = combined.length <= _maxQuarantineRecords
        ? combined
        : combined.sublist(combined.length - _maxQuarantineRecords);
    await prefs.setString(
      _quarantineKey,
      jsonEncode(retained.map((record) => record.toJson()).toList(growable: false)),
    );
  }

  static List<WorkflowPullQuarantineRecord> _decodeQuarantine(String? raw) {
    if (raw == null || raw.isEmpty) return const <WorkflowPullQuarantineRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <WorkflowPullQuarantineRecord>[];
      return decoded
          .whereType<Map>()
          .map((entry) => WorkflowPullQuarantineRecord.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false);
    } catch (_) {
      return const <WorkflowPullQuarantineRecord>[];
    }
  }
}
