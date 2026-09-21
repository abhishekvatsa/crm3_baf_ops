import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../data/uv_detector_installation_correction.dart';
import '../data/uv_detector_lifecycle_event.dart';
import '../services/uv_detector_correction_command_service.dart';

class UvDetectorCorrectionReview {
  const UvDetectorCorrectionReview({
    required this.original,
    required this.current,
    required this.corrections,
    required this.effectiveCorrection,
  });
  final UvDetectorLifecycleEvent original, current;
  final List<UvDetectorInstallationCorrection> corrections;
  final UvDetectorInstallationCorrection? effectiveCorrection;
  DateTime get effectiveAt =>
      effectiveCorrection?.effectiveAt ?? original.actionPerformedAt;

  List<UvDetectorInstallationCorrection> get correctionHistory {
    final byId = {for (final row in corrections) row.id: row};
    final history = <UvDetectorInstallationCorrection>[];
    var cursor = effectiveCorrection;
    while (cursor != null) {
      history.add(cursor);
      cursor = byId[cursor.supersedesId];
    }
    return List.unmodifiable(history.reversed);
  }
}

class UvDetectorCorrectionRepository {
  const UvDetectorCorrectionRepository({required this.firestore});
  final FirebaseFirestore firestore;

  Future<UvDetectorCorrectionReview> review(String eventId) async {
    final originalSnapshot = await firestore
        .collection('uv_detector_lifecycle_events')
        .doc(eventId)
        .get(const GetOptions(source: Source.server));
    if (!originalSnapshot.exists ||
        originalSnapshot.data() == null ||
        originalSnapshot.metadata.isFromCache ||
        originalSnapshot.metadata.hasPendingWrites) {
      throw StateError(
        'The original installation could not be verified from the server.',
      );
    }
    final original = UvDetectorLifecycleEvent.fromMap(
      originalSnapshot.data()!,
      eventId,
    );
    final snapshots = await firestore
        .collection('uv_detector_lifecycle_corrections')
        .where('correctsEventId', isEqualTo: eventId)
        .get(const GetOptions(source: Source.server));
    if (snapshots.metadata.isFromCache || snapshots.metadata.hasPendingWrites) {
      throw StateError(
        'The complete correction history could not be verified.',
      );
    }
    final corrections = snapshots.docs
        .map(
          (doc) => UvDetectorInstallationCorrection.fromMap(doc.data(), doc.id),
        )
        .toList();
    if (corrections.any(
      (row) =>
          row.assetInstanceId != original.assetInstanceId ||
          row.assetClassId != original.assetClassId ||
          row.assetNumber != original.assetNumber ||
          row.componentTag != original.componentTag ||
          row.burnerPosition != original.burnerPosition ||
          !row.originalAt.isAtSameMomentAs(original.actionPerformedAt),
    )) {
      throw StateError(
        'Correction history disagrees with the original physical subject.',
      );
    }
    final effective = effectiveUvDetectorCorrection(corrections, eventId);
    final current = await _current(
      original.assetInstanceId,
      original.burnerPosition,
    );
    return UvDetectorCorrectionReview(
      original: original,
      current: current,
      corrections: List.unmodifiable(corrections),
      effectiveCorrection: effective,
    );
  }

  Future<UvDetectorLifecycleEvent> _current(
    String assetId,
    int position,
  ) async {
    final snapshot = await firestore
        .collection('uv_detector_lifecycle_current')
        .where('assetInstanceId', isEqualTo: assetId)
        .get(const GetOptions(source: Source.server));
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw StateError('Current installations could not be confirmed.');
    }
    final rows = snapshot.docs
        .map(
          (doc) => UvDetectorLifecycleEvent.fromCurrentMap(doc.data(), doc.id),
        )
        .where((row) => row.burnerPosition == position)
        .toList();
    if (rows.length != 1 || rows.single.assetInstanceId != assetId) {
      throw StateError(
        'The position has missing or conflicting current installation evidence.',
      );
    }
    return rows.single;
  }

  Future<void> confirmReadback(
    WorkflowCommandReceipt receipt,
    String originalEnvelopeJson,
  ) async {
    final result = receipt.result;
    final id = result['correctionId'];
    if (id is! String || id.isEmpty) {
      throw StateError('The accepted correction has no identity.');
    }
    final snapshot = await firestore
        .collection('uv_detector_lifecycle_corrections')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists ||
        snapshot.data() == null ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites) {
      throw StateError(
        'The correction was accepted; its server readback remains pending.',
      );
    }
    final originalId = result['correctsEventId'];
    final auditId = result['auditId'];
    if (originalId is! String ||
        auditId != 'server_uv_detector_correction_${receipt.commandId}') {
      throw StateError(
        'The accepted correction does not identify its original installation and audit.',
      );
    }
    final evidence = await Future.wait([
      firestore
          .collection('uv_detector_lifecycle_events')
          .doc(originalId)
          .get(const GetOptions(source: Source.server)),
      firestore
          .collection('audit_logs')
          .doc(auditId as String)
          .get(const GetOptions(source: Source.server)),
    ]);
    if (evidence.any(
      (doc) =>
          !doc.exists ||
          doc.data() == null ||
          doc.metadata.isFromCache ||
          doc.metadata.hasPendingWrites,
    )) {
      throw StateError(
        'The correction was accepted; its original installation and retained audit still need server confirmation.',
      );
    }
    final correction = verifyRetainedEvidence(
      snapshot.data()!,
      id,
      receipt,
      originalEnvelopeJson,
      originalData: evidence[0].data()!,
      auditData: evidence[1].data()!,
    );
    // A newer legitimate installation may now be current. Validate the current
    // subject, never require it to equal an earlier correction's after-image.
    await _current(correction.assetInstanceId, correction.burnerPosition);
  }

  static String retainedAuditFingerprint(Map<String, dynamic> data) =>
      'sha256:${sha256.convert(utf8.encode(_canonicalEvidence(data)))}';

  static UvDetectorInstallationCorrection verifyRetainedEvidence(
    Map<String, dynamic> data,
    String id,
    WorkflowCommandReceipt receipt,
    String originalEnvelopeJson, {
    required Map<String, dynamic> originalData,
    required Map<String, dynamic> auditData,
  }) {
    UvDetectorCorrectionCommandService.validateReceiptEvidence(receipt);
    final correction = verifyCorrectionReadback(
      data,
      id,
      receipt,
      originalEnvelopeJson,
    );
    final original = UvDetectorLifecycleEvent.fromMap(
      originalData,
      correction.eventId,
    );
    final envelope = durableSubmissionJsonObject(originalEnvelopeJson);
    final command = envelope['command'] as Map<String, dynamic>;
    final before = durableSubmissionJsonObject(
      auditData['beforeJson'] is String
          ? auditData['beforeJson'] as String
          : '{}',
    );
    final after = durableSubmissionJsonObject(
      auditData['afterJson'] is String
          ? auditData['afterJson'] as String
          : '{}',
    );
    final current = after['currentInstallation'];
    if (original.assetClassId != correction.assetClassId ||
        original.assetInstanceId != correction.assetInstanceId ||
        original.assetNumber != correction.assetNumber ||
        original.componentTag != correction.componentTag ||
        original.burnerPosition != correction.burnerPosition ||
        !original.actionPerformedAt.isAtSameMomentAs(correction.originalAt) ||
        auditData['schemaVersion'] != 2 ||
        receipt.result['auditSchemaVersion'] != 2 ||
        auditData['auditId'] !=
            'server_uv_detector_correction_${receipt.commandId}' ||
        receipt.result['auditId'] != auditData['auditId'] ||
        auditData['entityId'] != id ||
        auditData['entityType'] != 'uvDetectorInstallationCorrection' ||
        auditData['operation'] != 'correctUvDetectorInstallation' ||
        auditData['operation'] != command['commandType'] ||
        auditData['requestId'] != receipt.commandId ||
        auditData['resultVersion'] != 1 ||
        auditData['performedByUid'] != correction.reviewerUid ||
        auditData['performedByName'] != correction.reviewerName ||
        auditData['reasonNotes'] != correction.reason ||
        _canonicalEvidence(auditData['timestamp']) !=
            jsonEncode(receipt.appliedAt.toUtc().toIso8601String()) ||
        auditData['commandFingerprint'] != retainedAuditFingerprint(command) ||
        receipt.result['auditFingerprint'] !=
            retainedAuditFingerprint(auditData) ||
        _canonicalEvidence(after['correction']) != _canonicalEvidence(data) ||
        _canonicalEvidence(before['correctedEvent']) !=
            _canonicalEvidence(originalData) ||
        current is! Map<String, dynamic> ||
        current['currentEventId'] != receipt.result['currentEventId'] ||
        _canonicalEvidence(current['actionPerformedAt']) !=
            _canonicalEvidence(receipt.result['currentActionPerformedAt'])) {
      throw StateError(
        'The retained correction, original installation and accepted audit disagree. Keep the saved request for review.',
      );
    }
    return correction;
  }

  /// Shared by the actual server read and contract tests with persisted timestamps.
  static UvDetectorInstallationCorrection verifyCorrectionReadback(
    Map<String, dynamic> data,
    String id,
    WorkflowCommandReceipt receipt,
    String originalEnvelopeJson,
  ) {
    final envelope = durableSubmissionJsonObject(originalEnvelopeJson);
    final command = envelope['command'] as Map<String, dynamic>;
    final payload = command['payload'] as Map<String, dynamic>;
    final result = receipt.result;
    final correction = UvDetectorInstallationCorrection.fromMap(data, id);
    if (correction.eventId != result['correctsEventId'] ||
        correction.expectedCurrentEventId != result['expectedCurrentEventId'] ||
        correction.expectedCurrentEventId !=
            payload['expectedCurrentEventId'] ||
        !correction.expectedCurrentActionPerformedAt.isAtSameMomentAs(
          readRequiredPersistedDateTime(
            result['expectedCurrentActionPerformedAt'],
            field: 'expectedCurrentActionPerformedAt',
            source: 'correction receipt',
          ),
        ) ||
        !correction.expectedCurrentActionPerformedAt.isAtSameMomentAs(
          readRequiredPersistedDateTime(
            payload['expectedCurrentActionPerformedAt'],
            field: 'expectedCurrentActionPerformedAt',
            source: 'saved correction',
          ),
        ) ||
        correction.reason != (payload['reason'] as String).trim() ||
        correction.reviewerUid != envelope['originActorUid'] ||
        !correction.correctedAt.isAtSameMomentAs(receipt.appliedAt) ||
        !correction.originalAt.isAtSameMomentAs(
          readRequiredPersistedDateTime(
            result['recordedActionPerformedAt'],
            field: 'recordedActionPerformedAt',
            source: 'correction receipt',
          ),
        ) ||
        correction.assetInstanceId != result['assetInstanceId'] ||
        correction.burnerPosition != result['burnerPosition'] ||
        correction.supersedesId != result['supersedesCorrectionId'] ||
        correction.effectiveAt !=
            readRequiredPersistedDateTime(
              result['correctedActionPerformedAt'],
              field: 'correctedActionPerformedAt',
              source: 'correction receipt',
            ).toUtc()) {
      throw StateError(
        'The correction is accepted but its retained server evidence disagrees.',
      );
    }
    return correction;
  }
}

String _canonicalEvidence(Object? value) {
  Object? normalize(Object? item) {
    if (item is DateTime || item is Timestamp) {
      final date = readRequiredPersistedDateTime(
        item,
        field: 'evidenceTimestamp',
      ).toUtc();
      if (date.microsecond != 0 ||
          (item is Timestamp && item.nanoseconds % 1000000 != 0)) {
        throw StateError(
          'Retained audit evidence requires exact milliseconds.',
        );
      }
      return date.toIso8601String();
    }
    if (item is List) return item.map(normalize).toList();
    if (item is Map<String, dynamic> &&
        (item.containsKey('_seconds') ||
            item.containsKey('_nanoseconds') ||
            item.containsKey('seconds') ||
            item.containsKey('nanoseconds'))) {
      final seconds = item['_seconds'] ?? item['seconds'];
      final nanos = item['_nanoseconds'] ?? item['nanoseconds'];
      final supportedKeys = item.keys.toSet();
      final supportedShape =
          item.length == 2 &&
          (supportedKeys.containsAll({'_seconds', '_nanoseconds'}) ||
              supportedKeys.containsAll({'seconds', 'nanoseconds'}));
      if (!supportedShape ||
          seconds is! int ||
          nanos is! int ||
          seconds < -62135596800 ||
          seconds > 253402300799 ||
          nanos < 0 ||
          nanos >= 1000000000 ||
          nanos % 1000000 != 0) {
        throw StateError(
          'Retained native timestamp evidence is malformed or loses precision.',
        );
      }
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + nanos ~/ 1000000,
        isUtc: true,
      ).toIso8601String();
    }
    if (item is Map<String, dynamic>) {
      final keys = item.keys.toList()..sort();
      return {for (final key in keys) key: normalize(item[key])};
    }
    return item;
  }

  return jsonEncode(normalize(value));
}
