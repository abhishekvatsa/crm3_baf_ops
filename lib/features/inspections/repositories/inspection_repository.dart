import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/inspection_campaign.dart';
import '../data/inspection_evidence_snapshot.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../../core/serialization/persisted_data_reader.dart';

part 'inspection_target_context_reader.dart';

/// The independently stored create events retain the expected population even
/// after a finding becomes terminal or its original reading is amended.
List<String> readInspectionFindingCreationIds(
  Iterable<({String id, Map<String, dynamic> data})> documents,
  String campaignId, {
  Object? expectedManifest,
}) {
  final ids = <String>[];
  final eventIds = <String>{};
  for (final document in documents) {
    final data = document.data;
    final source = 'inspection_finding_events/${document.id}';
    final findingId = readRequiredPersistedString(
      data['findingId'],
      field: 'findingId',
      source: source,
    );
    if (data['schemaVersion'] != 1 ||
        data['eventId'] != document.id ||
        data['campaignId'] != campaignId ||
        !eventIds.add(document.id) ||
        findingId.contains('/') ||
        !const {
          'create',
          'record-follow-up-observation',
          'reopen-after-observation-correction',
          'link-corrective-action',
          'verify',
          'adjudicate',
        }.contains(data['operation'])) {
      throw StateError(
        'Inspection finding history could not be verified: $source',
      );
    }
    if (data['operation'] == 'create') {
      final observationId = readRequiredPersistedString(
        data['effectiveObservationId'] ?? data['observationId'],
        field: 'effectiveObservationId',
        source: source,
      );
      if (findingId != 'inspection-finding-$observationId' ||
          data['previousStatus'] != null ||
          ids.contains(findingId)) {
        throw StateError(
          'Inspection finding creation evidence is inconsistent: $source',
        );
      }
      ids.add(findingId);
    }
  }
  if (expectedManifest != null &&
      (expectedManifest is! List ||
          expectedManifest.any((id) => id is! String) ||
          expectedManifest.length != ids.length ||
          expectedManifest.toSet().length != ids.length ||
          !ids.toSet().containsAll(expectedManifest))) {
    throw StateError(
      'The finding population differs from its original creation manifest.',
    );
  }
  return List.unmodifiable(ids);
}

class InspectionRepository {
  InspectionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _serverRead = GetOptions(source: Source.server);
  static const _reportReadAttempts = 3;

  Future<Map<String, Object?>> readCorrectiveTicket(String ticketId) async {
    if (ticketId.trim() != ticketId ||
        ticketId.isEmpty ||
        ticketId.contains('/')) {
      throw StateError('Enter a valid maintenance issue ID.');
    }
    final snapshot = await _firestore
        .collection('maintenance_records')
        .doc(ticketId)
        .get(_serverRead);
    final data = snapshot.data();
    if (!snapshot.exists ||
        snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites ||
        data == null ||
        data['firestoreId'] != ticketId ||
        data['isDeleted'] != false ||
        data['version'] is! int ||
        (data['version'] as int) < 1 ||
        data['assetNumber'] is! int ||
        data['assetType'] is! String ||
        data['component'] is! String ||
        data['description'] is! String) {
      throw StateError(
        'The maintenance issue could not be verified from the server.',
      );
    }
    return Map<String, Object?>.unmodifiable(data);
  }

  Future<Map<String, Object?>> readTargetContext(
    InspectionCampaignTarget target,
  ) => _readInspectionTargetContext(_firestore, target);

  Stream<List<InspectionDefinition>> watchDefinitions() => _firestore
      .collection('inspection_definitions')
      .snapshots()
      .map((snapshot) {
        final rows =
            decodeSnapshotDocuments(
              snapshot,
              InspectionDefinition.fromMap,
              source: 'InspectionDefinition',
            ).toList(growable: false)..sort((left, right) {
              final status = left.status.index.compareTo(right.status.index);
              return status != 0
                  ? status
                  : left.frozen.title.compareTo(right.frozen.title);
            });
        return List<InspectionDefinition>.unmodifiable(rows);
      });

  Stream<InspectionEvidenceSnapshot<InspectionCampaign>> watchCampaigns() =>
      _firestore
          .collection('inspection_campaigns')
          .snapshots(includeMetadataChanges: true)
          .map((snapshot) {
            final batch = decodeSnapshotBatch(
              snapshot,
              InspectionCampaign.fromMap,
              source: 'InspectionCampaign',
            );
            final rows = batch.records.toList(growable: false)
              ..sort((left, right) {
                final status = left.status.index.compareTo(right.status.index);
                return status != 0
                    ? status
                    : right.createdAt.compareTo(left.createdAt);
              });
            return InspectionEvidenceSnapshot<InspectionCampaign>(
              records: List<InspectionCampaign>.unmodifiable(rows),
              rejectedDocumentIds: batch.rejectedDocumentIds,
              isServerVerified:
                  !snapshot.metadata.isFromCache &&
                  !snapshot.metadata.hasPendingWrites,
            );
          });

  Stream<InspectionEvidenceSnapshot<InspectionObservation>> watchObservations(
    String campaignId,
  ) => _firestore
      .collection('inspection_observations')
      .where('campaignId', isEqualTo: campaignId)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        return InspectionEvidenceSnapshot<InspectionObservation>(
          records: _decodeObservations(snapshot),
          isServerVerified:
              !snapshot.metadata.isFromCache &&
              !snapshot.metadata.hasPendingWrites,
        );
      });

  Stream<InspectionEvidenceSnapshot<InspectionFinding>> watchFindings(
    String campaignId,
  ) => _firestore
      .collection('inspection_findings')
      .where('campaignId', isEqualTo: campaignId)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => InspectionEvidenceSnapshot<InspectionFinding>(
          records: _decodeFindings(snapshot),
          isServerVerified:
              !snapshot.metadata.isFromCache &&
              !snapshot.metadata.hasPendingWrites,
        ),
      );

  Stream<List<InspectionFinding>> watchAllFindings() => _firestore
      .collection('inspection_findings')
      .snapshots()
      .map(_decodeFindings);

  Future<InspectionCampaignReportEvidence> readCampaignReportEvidence(
    String campaignId,
  ) async {
    InspectionCampaignReportEvidence? previous;
    for (var attempt = 0; attempt < _reportReadAttempts; attempt += 1) {
      final current = await _readCampaignReportEvidenceOnce(campaignId);
      if (previous != null &&
          current.hasSameRevisionAs(previous) &&
          current.isInternallyComplete) {
        return current;
      }
      previous = current;
    }
    throw StateError(
      'Complete inspection evidence could not be held stable while the report '
      'was being prepared. '
      'Please try again.',
    );
  }

  Future<InspectionCampaignReportEvidence> _readCampaignReportEvidenceOnce(
    String campaignId,
  ) async {
    final reads = await Future.wait<Object>(<Future<Object>>[
      _firestore
          .collection('inspection_campaigns')
          .doc(campaignId)
          .get(_serverRead),
      _firestore
          .collection('inspection_observations')
          .where('campaignId', isEqualTo: campaignId)
          .get(_serverRead),
      _firestore
          .collection('inspection_findings')
          .where('campaignId', isEqualTo: campaignId)
          .get(_serverRead),
      _firestore
          .collection('inspection_finding_events')
          .where('campaignId', isEqualTo: campaignId)
          .get(_serverRead),
    ]);
    final campaignSnapshot = reads[0] as DocumentSnapshot<Map<String, dynamic>>;
    final observationSnapshot = reads[1] as QuerySnapshot<Map<String, dynamic>>;
    final findingSnapshot = reads[2] as QuerySnapshot<Map<String, dynamic>>;
    final eventSnapshot = reads[3] as QuerySnapshot<Map<String, dynamic>>;
    final campaignData = campaignSnapshot.data();
    if (!campaignSnapshot.exists || campaignData == null) {
      throw StateError('The inspection campaign is no longer available.');
    }
    return InspectionCampaignReportEvidence(
      campaign: InspectionCampaign.fromMap(campaignData, campaignSnapshot.id),
      createdFindingIds: readInspectionFindingCreationIds(
        eventSnapshot.docs.map((doc) => (id: doc.id, data: doc.data())),
        campaignId,
        expectedManifest: campaignData['findingCreationManifest'],
      ),
      // Strict on purpose. A browse list can show what decoded and say it is
      // incomplete; report evidence claiming a complete campaign cannot. The
      // completeness check validates only the findings that survived
      // decoding, so a dropped finding would be absent from both reads, the
      // revisions would match, and an incomplete population would pass as
      // complete.
      observations: observationSnapshot.docs
          .map((doc) => InspectionObservation.fromMap(doc.data(), doc.id))
          .toList(growable: false),
      findings: findingSnapshot.docs
          .map((doc) => InspectionFinding.fromMap(doc.data(), doc.id))
          .toList(growable: false),
    );
  }

  List<InspectionObservation> _decodeObservations(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final rows =
        snapshot.docs
            .map((doc) => InspectionObservation.fromMap(doc.data(), doc.id))
            .toList(growable: false)
          ..sort((left, right) {
            final observed = right.observedAt.compareTo(left.observedAt);
            return observed != 0 ? observed : left.id.compareTo(right.id);
          });
    return List<InspectionObservation>.unmodifiable(rows);
  }

  List<InspectionFinding> _decodeFindings(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final rows =
        snapshot.docs
            .map((doc) => InspectionFinding.fromMap(doc.data(), doc.id))
            .toList(growable: false)
          ..sort((left, right) {
            final blocking = right.blocksCampaignClosure ? 1 : 0;
            final leftBlocking = left.blocksCampaignClosure ? 1 : 0;
            final order = blocking.compareTo(leftBlocking);
            if (order != 0) return order;
            final updatedAt = right.updatedAt.compareTo(left.updatedAt);
            return updatedAt != 0 ? updatedAt : left.id.compareTo(right.id);
          });
    return List<InspectionFinding>.unmodifiable(rows);
  }
}
