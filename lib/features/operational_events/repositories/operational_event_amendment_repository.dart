import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../data/operational_event.dart';
import '../data/operational_event_interval_amendment.dart';
import '../services/operational_event_amendment_service.dart';

/// Canonical evidence uses sorted object keys and exact UTC milliseconds.
String operationalAmendmentCanonicalJson(Object? value) {
  Object? canonical(Object? item) {
    if (item is DateTime || item is Timestamp) {
      return readOperationalAmendmentInstant(
        item,
        field: 'timestamp',
      ).toIso8601String();
    }
    if (item is List) return item.map(canonical).toList();
    if (item is Map<String, dynamic>) {
      final keys = item.keys.toList()..sort();
      return {for (final key in keys) key: canonical(item[key])};
    }
    return item;
  }

  return jsonEncode(canonical(value));
}

class OperationalEventAmendmentRepository {
  const OperationalEventAmendmentRepository({required this.firestore});
  final FirebaseFirestore firestore;

  static const _intervalFields = {
    'eventType',
    'title',
    'description',
    'severity',
    'startedAt',
    'resolvedAt',
    'scope',
    'affectedAssetClassIds',
    'affectedAssetInstanceIds',
    'issueLinkIds',
    'linkedIssueIds',
    'resolvedByUid',
    'resolvedByName',
    'resolutionNote',
  };

  static OperationalEventAmendmentReview decodeReview(
    Map<String, dynamic> raw,
    String id,
    int index,
  ) {
    final event = OperationalEvent.fromMap(raw, id);
    if (!event.isEffective || event.closedOccurrence(index) == null) {
      throw StateError('Select an effective, closed occurrence to amend.');
    }
    final interval = index < event.currentOccurrenceIndex
        ? Map<String, dynamic>.from(
            (raw['completedIntervals'] as List)[index] as Map,
          )
        : <String, dynamic>{
            for (final field in _intervalFields)
              if (raw.containsKey(field)) field: raw[field],
          };
    for (final field in ['startedAt', 'resolvedAt']) {
      interval[field] = readOperationalAmendmentInstant(
        interval[field],
        field: field,
      ).toIso8601String();
    }
    return OperationalEventAmendmentReview(
      event: event,
      occurrenceIndex: index,
      originalIntervalJson: operationalAmendmentCanonicalJson(interval),
    );
  }

  Future<OperationalEventAmendmentReview> review(
    String eventId,
    int index,
  ) async {
    final raw = await _serverDocument('operational_events', eventId);
    final review = decodeReview(raw, eventId, index);
    final history = await firestore
        .collection('operational_event_interval_amendments')
        .where('eventId', isEqualTo: eventId)
        .where('occurrenceIndex', isEqualTo: index)
        .get(const GetOptions(source: Source.server));
    if (history.metadata.isFromCache ||
        history.metadata.hasPendingWrites ||
        history.docs.any(
          (doc) => doc.metadata.isFromCache || doc.metadata.hasPendingWrites,
        )) {
      throw StateError(
        'The complete amendment history could not be confirmed from the server.',
      );
    }
    return OperationalEventAmendmentReview(
      event: review.event,
      occurrenceIndex: index,
      originalIntervalJson: review.originalIntervalJson,
      history: verifyHistory(review, {
        for (final doc in history.docs) doc.id: doc.data(),
      }),
    );
  }

  /// Standalone admission for immutable evidence, shared with the device
  /// integrity decoder. Parent linkage is checked separately by [verifyHistory].
  static OperationalEventIntervalAmendment validateRetainedRecord(
    Map<String, dynamic> data,
    String documentId,
  ) {
    const fields = {
      'schemaVersion',
      'amendmentId',
      'eventId',
      'occurrenceIndex',
      'expectedEventVersion',
      'resultVersion',
      'originalIntervalJson',
      'priorEffectiveResolvedAt',
      'correctedResolvedAt',
      'supersedesAmendmentId',
      'reason',
      'amendedAt',
      'amendedByUid',
      'amendedByName',
      'evidenceDigest',
    };
    if (data.length != fields.length || !fields.every(data.containsKey)) {
      throw const FormatException(
        'The immutable amendment requires its exact evidence fields.',
      );
    }
    final schema = readRequiredPersistedInt(
      data['schemaVersion'],
      field: 'schemaVersion',
    );
    final ordinal = readRequiredPersistedInt(
      data['occurrenceIndex'],
      field: 'occurrenceIndex',
      minimum: 0,
    );
    final expected = readRequiredPersistedInt(
      data['expectedEventVersion'],
      field: 'expectedEventVersion',
      minimum: 1,
    );
    final result = readRequiredPersistedInt(
      data['resultVersion'],
      field: 'resultVersion',
      minimum: 2,
    );
    final eventId = readRequiredPersistedString(
      data['eventId'],
      field: 'eventId',
    );
    final originalJson = readRequiredPersistedString(
      data['originalIntervalJson'],
      field: 'originalIntervalJson',
    );
    final original = durableSubmissionJsonObject(originalJson);
    if ((original.length != 12 && original.length != 14) ||
        original.keys.any((key) => !_intervalFields.contains(key)) ||
        (original.containsKey('issueLinkIds') !=
            original.containsKey('linkedIssueIds')) ||
        originalJson != operationalAmendmentCanonicalJson(original)) {
      throw const FormatException('The original interval shape is invalid.');
    }
    readRequiredPersistedEnum(
      OperationalEventType.values,
      original['eventType'],
      field: 'eventType',
    );
    readRequiredPersistedEnum(
      OperationalEventSeverity.values,
      original['severity'],
      field: 'severity',
    );
    final scope = readRequiredPersistedEnum(
      OperationalEventScope.values,
      original['scope'],
      field: 'scope',
    );
    for (final field in {
      'title': 120,
      'description': 2000,
      'resolvedByUid': 128,
      'resolvedByName': 200,
      'resolutionNote': 1000,
    }.entries) {
      if (readRequiredPersistedString(
            original[field.key],
            field: field.key,
          ).length >
          field.value) {
        throw const FormatException(
          'The original interval text exceeds its bounds.',
        );
      }
    }
    List<String> list(String field, int maximum, {bool optional = false}) {
      if ((!optional || original.containsKey(field)) &&
          original[field] is! List) {
        throw const FormatException(
          'The original interval requires complete scope and link arrays.',
        );
      }
      final values = readOptionalPersistedStringList(
        original[field],
        field: field,
      );
      if (values.length > maximum || values.toSet().length != values.length) {
        throw const FormatException(
          'The original interval array exceeds its bounds or repeats identities.',
        );
      }
      return values;
    }

    final classes = list('affectedAssetClassIds', 20);
    final assets = list('affectedAssetInstanceIds', 50);
    final links = list('issueLinkIds', 100, optional: true);
    final issues = list('linkedIssueIds', 100, optional: true);
    final validScope = switch (scope) {
      OperationalEventScope.plantWide => classes.isEmpty && assets.isEmpty,
      OperationalEventScope.assetClasses =>
        classes.isNotEmpty && assets.isEmpty,
      OperationalEventScope.assets => assets.isNotEmpty,
    };
    final start = readOperationalAmendmentInstant(
      original['startedAt'],
      field: 'startedAt',
    );
    final originalEnd = readOperationalAmendmentInstant(
      original['resolvedAt'],
      field: 'resolvedAt',
    );
    final priorEnd = readOperationalAmendmentInstant(
      data['priorEffectiveResolvedAt'],
      field: 'priorEffectiveResolvedAt',
    );
    final head = OperationalEventIntervalAmendment.fromMap({
      'amendmentId': data['amendmentId'],
      'originalResolvedAt': original['resolvedAt'],
      'correctedResolvedAt': data['correctedResolvedAt'],
      'amendedAt': data['amendedAt'],
      'amendedByUid': data['amendedByUid'],
      'amendedByName': data['amendedByName'],
      'reason': data['reason'],
      'supersedesAmendmentId': data['supersedesAmendmentId'],
    }, 'operational_event_interval_amendments/$documentId');
    final withoutDigest = Map<String, dynamic>.from(data)
      ..remove('evidenceDigest');
    final digest =
        'operational-interval-amendment-v1-sha256:${sha256.convert(utf8.encode(operationalAmendmentCanonicalJson(withoutDigest)))}';
    if (schema != 1 ||
        ordinal > 100 ||
        result != expected + 1 ||
        documentId != head.amendmentId ||
        !operationalEventAmendmentIdPattern.hasMatch(eventId) ||
        !validScope ||
        links.length != issues.length ||
        originalEnd.isBefore(start) ||
        priorEnd.isBefore(start) ||
        priorEnd.isAfter(head.amendedAt) ||
        head.correctedResolvedAt.isBefore(start) ||
        head.correctedResolvedAt.isAtSameMomentAs(priorEnd) ||
        (head.supersedesAmendmentId == null &&
            !priorEnd.isAtSameMomentAs(originalEnd)) ||
        data['evidenceDigest'] != digest) {
      throw const FormatException(
        'The immutable amendment identity, chronology or complete-record digest is invalid.',
      );
    }
    return head;
  }

  /// Complete immutable history is admitted only when it forms the exact chain
  /// named by the current event. Link projections may grow after an amendment.
  static List<OperationalEventIntervalAmendment> verifyHistory(
    OperationalEventAmendmentReview review,
    Map<String, Map<String, dynamic>> records,
  ) {
    String physicalEvidence(String raw) {
      final data = durableSubmissionJsonObject(raw)
        ..remove('issueLinkIds')
        ..remove('linkedIssueIds');
      return operationalAmendmentCanonicalJson(data);
    }

    final rows = <String, OperationalEventIntervalAmendment>{};
    final priorEnds = <String, DateTime>{};
    final resultVersions = <String, int>{};
    final expectedVersions = <String, int>{};
    final successorByPrior = <String?, String>{};
    for (final entry in records.entries) {
      final data = entry.value;
      final row = validateRetainedRecord(data, entry.key);
      final expected = data['expectedEventVersion'] as int;
      final version = data['resultVersion'] as int;
      final originalJson = data['originalIntervalJson'] as String;
      final priorEnd = readOperationalAmendmentInstant(
        data['priorEffectiveResolvedAt'],
        field: 'priorEffectiveResolvedAt',
      );
      if (data['schemaVersion'] != 1 ||
          entry.key != row.amendmentId ||
          data['eventId'] != review.event.eventId ||
          data['occurrenceIndex'] != review.occurrenceIndex ||
          expected < 1 ||
          version != expected + 1 ||
          version > review.event.version ||
          physicalEvidence(originalJson) !=
              physicalEvidence(review.originalIntervalJson) ||
          !row.originalResolvedAt.isAtSameMomentAs(
            review.original.resolvedAt,
          ) ||
          row.correctedResolvedAt.isBefore(review.original.startedAt) ||
          (review.nextStart != null &&
              row.correctedResolvedAt.isAfter(review.nextStart!)) ||
          row.amendedAt.isAfter(review.event.updatedAt) ||
          priorEnd.isBefore(review.original.startedAt) ||
          priorEnd.isAfter(row.amendedAt) ||
          row.correctedResolvedAt.isAtSameMomentAs(priorEnd) ||
          successorByPrior.containsKey(row.supersedesAmendmentId)) {
        throw StateError(
          'The retained amendment history disagrees with the occurrence or branches.',
        );
      }
      rows[row.amendmentId] = row;
      priorEnds[row.amendmentId] = priorEnd;
      resultVersions[row.amendmentId] = version;
      expectedVersions[row.amendmentId] = expected;
      successorByPrior[row.supersedesAmendmentId] = row.amendmentId;
    }
    final chain = <OperationalEventIntervalAmendment>[];
    final visited = <String>{};
    var id = successorByPrior[null];
    while (id != null) {
      if (!visited.add(id)) {
        throw StateError('The amendment history contains a cycle.');
      }
      final row = rows[id]!;
      final previous = chain.isEmpty ? null : chain.last;
      if (!priorEnds[id]!.isAtSameMomentAs(
            previous?.correctedResolvedAt ?? review.original.resolvedAt,
          ) ||
          (previous != null &&
              (row.amendedAt.isBefore(previous.amendedAt) ||
                  expectedVersions[id]! <
                      resultVersions[previous.amendmentId]!))) {
        throw StateError(
          'The retained amendment predecessor or chronology disagrees.',
        );
      }
      chain.add(row);
      id = successorByPrior[id];
    }
    final head = review.amendment;
    final last = chain.isEmpty ? null : chain.last;
    if (chain.length != records.length ||
        (head == null) != (last == null) ||
        (head != null &&
            last != null &&
            (head.amendmentId != last.amendmentId ||
                head.supersedesAmendmentId != last.supersedesAmendmentId ||
                head.reason != last.reason ||
                head.amendedByUid != last.amendedByUid ||
                head.amendedByName != last.amendedByName ||
                !head.amendedAt.isAtSameMomentAs(last.amendedAt) ||
                !head.correctedResolvedAt.isAtSameMomentAs(
                  last.correctedResolvedAt,
                )))) {
      throw StateError(
        'The complete amendment history does not match the reviewed current end.',
      );
    }
    return List.unmodifiable(chain);
  }

  Future<Map<String, dynamic>> _serverDocument(
    String collection,
    String id,
  ) async {
    final snapshot = await firestore
        .collection(collection)
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists ||
        snapshot.data() == null ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites) {
      throw StateError(
        'The retained closure evidence could not be confirmed from the server. The saved request remains available.',
      );
    }
    return snapshot.data()!;
  }

  Future<void> confirmReadback(
    DurableSubmission saved,
    OperationalEventAmendmentReceipt receipt,
  ) async {
    final data = await _serverDocument(
      'operational_event_interval_amendments',
      receipt.amendmentId,
    );
    verifyReadback(data, saved, receipt);
    // Acceptance is bound to immutable evidence, not a mutable after-image.
    // A later amendment or recurrence can legitimately advance this event.
  }

  static void verifyReadback(
    Map<String, dynamic> data,
    DurableSubmission saved,
    OperationalEventAmendmentReceipt receipt,
  ) {
    validateRetainedRecord(data, saved.requestId);
    const fields = {
      'schemaVersion',
      'amendmentId',
      'eventId',
      'occurrenceIndex',
      'expectedEventVersion',
      'resultVersion',
      'originalIntervalJson',
      'priorEffectiveResolvedAt',
      'correctedResolvedAt',
      'supersedesAmendmentId',
      'reason',
      'amendedAt',
      'amendedByUid',
      'amendedByName',
      'evidenceDigest',
    };
    readBoundedPersistedExtensionBag(
      data,
      knownFields: fields,
      allowedFields: const <String, PersistedExtensionValueKind>{},
      field: 'extensions',
      source: 'operational event amendment',
    );
    if (data.length != fields.length || !fields.every(data.containsKey)) {
      throw StateError(
        'The retained amendment has missing or unsupported fields.',
      );
    }
    for (final field in [
      'schemaVersion',
      'occurrenceIndex',
      'expectedEventVersion',
      'resultVersion',
    ]) {
      readRequiredPersistedInt(data[field], field: field);
    }
    final request = OperationalEventAmendmentService.requestFor(saved);
    final amendment = request['intervalAmendment'] as Map<String, dynamic>;
    final metadata = durableSubmissionJsonObject(saved.displayMetadataJson!);
    final original = durableSubmissionJsonObject(
      data['originalIntervalJson'] is String
          ? data['originalIntervalJson'] as String
          : '{}',
    );
    final start = readOperationalAmendmentInstant(
      original['startedAt'],
      field: 'original.startedAt',
    );
    final originalEnd = readOperationalAmendmentInstant(
      original['resolvedAt'],
      field: 'original.resolvedAt',
    );
    final prior = readOperationalAmendmentInstant(
      data['priorEffectiveResolvedAt'],
      field: 'priorEffectiveResolvedAt',
    );
    final corrected = readOperationalAmendmentInstant(
      data['correctedResolvedAt'],
      field: 'correctedResolvedAt',
    );
    final amendedAt = readOperationalAmendmentInstant(
      data['amendedAt'],
      field: 'amendedAt',
    );
    final name = readRequiredPersistedString(
      data['amendedByName'],
      field: 'amendedByName',
    );
    final withoutDigest = Map<String, dynamic>.from(data)
      ..remove('evidenceDigest');
    final digest =
        'operational-interval-amendment-v1-sha256:${sha256.convert(utf8.encode(operationalAmendmentCanonicalJson(withoutDigest)))}';
    if (data['schemaVersion'] != 1 ||
        data['amendmentId'] != saved.requestId ||
        data['eventId'] != saved.aggregateId ||
        data['occurrenceIndex'] != amendment['occurrenceIndex'] ||
        data['expectedEventVersion'] != request['expectedVersion'] ||
        data['resultVersion'] != receipt.result.version ||
        data['originalIntervalJson'] != metadata['originalIntervalJson'] ||
        data['originalIntervalJson'] !=
            operationalAmendmentCanonicalJson(original) ||
        data['supersedesAmendmentId'] != amendment['supersedesAmendmentId'] ||
        data['reason'] != request['reason'] ||
        data['amendedByUid'] != saved.actorUid ||
        name.length > 200 ||
        !prior.isAtSameMomentAs(
          readOperationalAmendmentInstant(
            amendment['expectedEffectiveResolvedAt'],
            field: 'expectedEffectiveResolvedAt',
          ),
        ) ||
        !corrected.isAtSameMomentAs(
          readOperationalAmendmentInstant(
            amendment['correctedResolvedAt'],
            field: 'correctedResolvedAt',
          ),
        ) ||
        !amendedAt.isAtSameMomentAs(receipt.result.committedAt) ||
        originalEnd.isBefore(start) ||
        corrected.isBefore(start) ||
        corrected.isAfter(amendedAt) ||
        prior.isBefore(start) ||
        prior.isAfter(amendedAt) ||
        (data['supersedesAmendmentId'] == null &&
            !prior.isAtSameMomentAs(originalEnd)) ||
        data['evidenceDigest'] != digest ||
        receipt.data['amendmentEvidenceDigest'] != digest) {
      throw StateError(
        'The accepted amendment disagrees with its original request or retained evidence. Keep the saved request for review.',
      );
    }
  }
}
