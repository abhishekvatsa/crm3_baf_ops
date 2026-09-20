/// Local readback after the governed revision and its audit commit atomically.
library;

/// Whether this device is showing the exact revision it has just written.
enum KnowledgeRevisionAdoption {
  /// The local copy now holds the committed revision and content.
  adopted,

  /// The revision is committed and audited; adoption is still unverified.
  pending,
}

/// [adoptLocally] must verify the accepted row, revision and content. Completion
/// of a general pull alone supplies no adoption evidence. Readback failure is
/// separate from publication: the authoritative revision is already committed.
Future<KnowledgeRevisionAdoption> settleCommittedKnowledgeRevision({
  required Future<KnowledgeRevisionAdoption> Function() adoptLocally,
}) async {
  try {
    return await adoptLocally();
  } catch (_) {
    return KnowledgeRevisionAdoption.pending;
  }
}

String knowledgeRevisionAdoptionNote(
  KnowledgeRevisionAdoption adoption,
  String rowCode,
) => switch (adoption) {
  KnowledgeRevisionAdoption.adopted => 'Saved $rowCode.',
  KnowledgeRevisionAdoption.pending =>
    'Saved $rowCode. This device has not caught up with it yet. Refresh and '
        'review knowledge conflicts; retained local drafts or a later cloud '
        'revision may require review.',
};
