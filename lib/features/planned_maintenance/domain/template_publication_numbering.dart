/// What number a template publication carries, and what the package says after
/// it.
///
/// A governed template package points at one active version, and the store
/// enforces that the active version is the package's latest one: the package's
/// `latestVersionNumber` must equal the `versionNumber` of the version its
/// `activeVersionFirestoreId` names.
///
/// A draft keeps its own number while it is a draft, which is right - resuming
/// it should not renumber it on every save. Publishing is different. A draft
/// resumed after another version was published still carries the older number,
/// and publishing under that number would leave the package pointing at a
/// version that is not the latest. The store refuses that package, so the
/// publication could never synchronize while the device went on showing it as
/// published.
///
/// Publication is therefore monotonic: a draft that is not already beyond the
/// latest published version is published under the next available number.
/// Nothing already published is renumbered, rewritten or deactivated to make
/// the counters agree.
library;

class TemplatePublicationNumbering {
  /// The number this publication is made under.
  final int versionNumber;

  /// What the package's `latestVersionNumber` reads once it is published.
  final int latestVersionNumber;

  /// Whether the draft was published under a number it did not already have.
  final bool renumbered;

  const TemplatePublicationNumbering({
    required this.versionNumber,
    required this.latestVersionNumber,
    required this.renumbered,
  });

  /// Whether the package this leaves behind satisfies the store's rule that a
  /// package's active version is its latest one.
  bool get hasCoherentActivePointer => versionNumber == latestVersionNumber;
}

/// The numbering a publication of [draftVersionNumber] must use.
///
/// [latestPublishedVersionNumber] is the package's current counter and
/// [nextAvailableVersionNumber] the first number no version in the package has
/// taken, which the caller resolves from the stored versions rather than from
/// the counter alone.
TemplatePublicationNumbering templatePublicationNumbering({
  required int draftVersionNumber,
  required int latestPublishedVersionNumber,
  required int nextAvailableVersionNumber,
}) {
  final renumbered = draftVersionNumber <= latestPublishedVersionNumber;
  final versionNumber =
      renumbered ? nextAvailableVersionNumber : draftVersionNumber;
  return TemplatePublicationNumbering(
    versionNumber: versionNumber,
    latestVersionNumber:
        versionNumber > latestPublishedVersionNumber
            ? versionNumber
            : latestPublishedVersionNumber,
    renumbered: renumbered,
  );
}
