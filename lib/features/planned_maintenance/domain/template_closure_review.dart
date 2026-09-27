import 'dart:convert';

import '../data/template_governance_model.dart';

/// A new record cannot inherit a review performed before that record existed.
/// The predecessor retains the original attestation and is linked separately.
void clearTemplateClosureReview(TemplateVersion version) {
  final job = Map<String, dynamic>.from(
    jsonDecode(version.jobTemplateSnapshotJson) as Map,
  );
  final composer = Map<String, dynamic>.from(job['composer'] as Map? ?? {});
  composer['closureReviewConfirmed'] = false;
  for (final key in [
    'closureReviewConfirmedByUid',
    'closureReviewConfirmedByName',
    'closureReviewConfirmedAt',
  ]) {
    composer.remove(key);
  }
  job['composer'] = composer;
  version.jobTemplateSnapshotJson = jsonEncode(job);
  version.refreshContentHash();
}

void confirmTemplateClosureReview(
  TemplateVersion version, {
  required String actorUid,
  required String actorName,
  required DateTime confirmedAt,
}) {
  if (confirmedAt.isBefore(version.createdAt) ||
      actorUid.trim().isEmpty ||
      actorName.trim().isEmpty) {
    throw StateError(
      'The closure review must identify its reviewer and follow draft creation.',
    );
  }
  final job = Map<String, dynamic>.from(
    jsonDecode(version.jobTemplateSnapshotJson) as Map,
  );
  final composer = Map<String, dynamic>.from(job['composer'] as Map? ?? {});
  composer.addAll({
    'closureReviewConfirmed': true,
    'closureReviewConfirmedByUid': actorUid,
    'closureReviewConfirmedByName': actorName,
    'closureReviewConfirmedAt': confirmedAt.toUtc().toIso8601String(),
  });
  job['composer'] = composer;
  version
    ..jobTemplateSnapshotJson = jsonEncode(job)
    ..updatedAt = confirmedAt;
  version.refreshContentHash();
}
