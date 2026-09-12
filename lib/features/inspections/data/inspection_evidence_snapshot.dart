import 'inspection_campaign.dart';

final class InspectionEvidenceSnapshot<T> {
  const InspectionEvidenceSnapshot({
    required this.records,
    required this.isServerVerified,
  });

  final List<T> records;
  final bool isServerVerified;
}

final class InspectionCampaignReportEvidence {
  const InspectionCampaignReportEvidence({
    required this.campaign,
    required this.observations,
    required this.findings,
  });

  final InspectionCampaign campaign;
  final List<InspectionObservation> observations;
  final List<InspectionFinding> findings;

  bool get isInternallyComplete {
    if (observations.length != campaign.observationCount ||
        observations.any((row) => row.campaignId != campaign.id) ||
        findings.any((row) => row.campaignId != campaign.id)) {
      return false;
    }

    final targetsByKey = <String, InspectionCampaignTarget>{
      for (final target in campaign.targets) target.targetKey: target,
    };
    final observationsById = <String, InspectionObservation>{
      for (final observation in observations) observation.id: observation,
    };
    if (targetsByKey.length != campaign.targets.length ||
        observationsById.length != observations.length ||
        observations.any((row) => !targetsByKey.containsKey(row.targetKey)) ||
        !_sameStringSet(
          observations.map((row) => row.targetKey),
          campaign.distinctTargetKeys,
        )) {
      return false;
    }

    final latestObservationAt = observations.isEmpty
        ? null
        : observations
              .map((row) => row.observedAt.toUtc())
              .reduce((left, right) => left.isAfter(right) ? left : right);
    if (!_sameInstant(latestObservationAt, campaign.latestObservationAt)) {
      return false;
    }

    for (final target in campaign.targets) {
      final observationId = target.lastObservationId;
      if ((observationId == null) != (target.lastObservedAt == null)) {
        return false;
      }
      if (observationId == null) continue;
      final observation = observationsById[observationId];
      if (observation == null ||
          observation.targetKey != target.targetKey ||
          !_sameInstant(observation.observedAt, target.lastObservedAt)) {
        return false;
      }
    }

    for (final observation in observations) {
      final target = targetsByKey[observation.targetKey]!;
      if (observation.targetContextRevision > target.contextRevision ||
          (observation.targetContextRevision > 0 &&
              (observation.assetClassId != target.assetClassId ||
                  observation.assetInstanceId != target.assetInstanceId ||
                  observation.subjectSerialNumber !=
                      target.subjectSerialNumber ||
                  observation.targetContextOriginalLinkageId !=
                      target.linkageId ||
                  (observation.targetContextRevision ==
                          target.contextRevision &&
                      observation.targetContextAuditId !=
                          target.contextReview!.auditId)))) {
        return false;
      }
      final supersededId = observation.supersedesObservationId;
      final superseded = supersededId == null
          ? null
          : observationsById[supersededId];
      if (supersededId != null &&
          (superseded == null ||
              superseded.targetKey != observation.targetKey)) {
        return false;
      }
    }

    for (final finding in findings) {
      final target = targetsByKey[finding.targetKey];
      final first = observationsById[finding.firstObservationId];
      final current = observationsById[finding.currentObservationId];
      if (target == null ||
          first == null ||
          current == null ||
          first.targetKey != finding.targetKey ||
          current.targetKey != finding.targetKey ||
          finding.assetClassId != target.assetClassId ||
          finding.assetInstanceId != target.assetInstanceId ||
          !_sameInstant(first.observedAt, finding.firstObservedAt) ||
          !_sameInstant(current.observedAt, finding.latestObservedAt)) {
        return false;
      }
    }
    return true;
  }

  bool hasSameRevisionAs(InspectionCampaignReportEvidence other) {
    if (campaign.id != other.campaign.id ||
        campaign.version != other.campaign.version) {
      return false;
    }

    final observationRevisions =
        observations
            .map(
              (row) => (
                id: row.id,
                targetKey: row.targetKey,
                observedAt: row.observedAt.toUtc().microsecondsSinceEpoch,
                recordedAt: row.recordedAt.toUtc().microsecondsSinceEpoch,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.id.compareTo(right.id));
    final otherObservationRevisions =
        other.observations
            .map(
              (row) => (
                id: row.id,
                targetKey: row.targetKey,
                observedAt: row.observedAt.toUtc().microsecondsSinceEpoch,
                recordedAt: row.recordedAt.toUtc().microsecondsSinceEpoch,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.id.compareTo(right.id));
    if (!_sameRevisionRows(observationRevisions, otherObservationRevisions)) {
      return false;
    }

    final findingRevisions =
        findings
            .map(
              (row) => (
                id: row.id,
                version: row.version,
                updatedAt: row.updatedAt.toUtc().microsecondsSinceEpoch,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.id.compareTo(right.id));
    final otherFindingRevisions =
        other.findings
            .map(
              (row) => (
                id: row.id,
                version: row.version,
                updatedAt: row.updatedAt.toUtc().microsecondsSinceEpoch,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.id.compareTo(right.id));
    return _sameRevisionRows(findingRevisions, otherFindingRevisions);
  }
}

bool _sameStringSet(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

bool _sameInstant(DateTime? left, DateTime? right) {
  if (left == null || right == null) return left == right;
  return left.toUtc() == right.toUtc();
}

bool _sameRevisionRows<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
