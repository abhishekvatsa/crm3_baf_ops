/// What happens once a knowledge revision has committed in cloud.
///
/// The revision exists from the moment its transaction commits. Two things
/// follow, and they are not the same kind of thing:
///
///  - the audit entry that says who changed an authoritative instruction and
///    why. It belongs with the revision. Support reading a changed rule
///    without it has no account of the change at all;
///  - adopting the new revision into this device's local copy. That is this
///    device catching up, and it can fail on its own - a dropped connection
///    while the pull runs - without anything being wrong with the revision.
///
/// The adoption used to run first and throw, which skipped the audit entirely
/// and told the author their change had failed while the cloud already held
/// it. So the audit is settled first, and a failed adoption is reported as
/// what it is: a delay in what this device shows.
library;

/// Whether this device is showing the revision it has just written.
enum KnowledgeRevisionAdoption {
  /// The local copy now holds the committed revision.
  adopted,

  /// The revision is committed and audited; this device has not caught up.
  pending,
}

/// Settles a committed revision: records it, then tries to adopt it locally.
///
/// [recordAudit] is awaited before adoption is attempted. [adoptLocally] may
/// fail, and its failure is returned rather than thrown, because by the time
/// it runs the revision is already a fact.
Future<KnowledgeRevisionAdoption> settleCommittedKnowledgeRevision({
  required Future<void> Function() recordAudit,
  required Future<void> Function() adoptLocally,
}) async {
  await recordAudit();
  try {
    await adoptLocally();
    return KnowledgeRevisionAdoption.adopted;
  } catch (_) {
    return KnowledgeRevisionAdoption.pending;
  }
}

/// What to tell the author, given how the revision settled.
String knowledgeRevisionAdoptionNote(
  KnowledgeRevisionAdoption adoption,
  String rowCode,
) => switch (adoption) {
  KnowledgeRevisionAdoption.adopted => 'Saved $rowCode.',
  KnowledgeRevisionAdoption.pending =>
    'Saved $rowCode. This device has not caught up with it yet; it will '
        'appear here after the next successful sync.',
};
