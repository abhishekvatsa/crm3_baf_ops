import 'package:crm3_baf_ops/features/planned_maintenance/domain/template_publication_numbering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule the governed store enforces on a template package: the version the
/// package points at is the package's latest one.
void expectStoreWouldAccept(TemplatePublicationNumbering numbering) {
  expect(
    numbering.hasCoherentActivePointer,
    isTrue,
    reason:
        'a package whose active version is not its latest is refused by the '
        'store, so the publication could never be synchronized',
  );
}

void main() {
  group('publishing a template version', () {
    test('a draft resumed after another version was published takes a new '
        'number', () {
      // The package is on v2. A draft saved before that, still numbered 1, is
      // resumed and published. Published under its own number it would leave
      // the package active on v1 while the counter said 2.
      final numbering = templatePublicationNumbering(
        draftVersionNumber: 1,
        latestPublishedVersionNumber: 2,
        nextAvailableVersionNumber: 3,
      );

      expect(numbering.versionNumber, 3);
      expect(numbering.latestVersionNumber, 3);
      expect(numbering.renumbered, isTrue);
      expectStoreWouldAccept(numbering);
    });

    test('a draft already beyond the published history keeps its number', () {
      final numbering = templatePublicationNumbering(
        draftVersionNumber: 3,
        latestPublishedVersionNumber: 2,
        nextAvailableVersionNumber: 3,
      );

      expect(numbering.versionNumber, 3);
      expect(numbering.latestVersionNumber, 3);
      expect(numbering.renumbered, isFalse);
      expectStoreWouldAccept(numbering);
    });

    test('the first publication of a package keeps its number', () {
      final numbering = templatePublicationNumbering(
        draftVersionNumber: 1,
        latestPublishedVersionNumber: 0,
        nextAvailableVersionNumber: 1,
      );

      expect(numbering.versionNumber, 1);
      expect(numbering.latestVersionNumber, 1);
      expect(numbering.renumbered, isFalse);
      expectStoreWouldAccept(numbering);
    });

    test('a draft carrying the number of the published version does not '
        'republish over it', () {
      final numbering = templatePublicationNumbering(
        draftVersionNumber: 2,
        latestPublishedVersionNumber: 2,
        nextAvailableVersionNumber: 3,
      );

      expect(numbering.versionNumber, 3);
      expect(numbering.renumbered, isTrue);
      expectStoreWouldAccept(numbering);
    });

    test('the next available number is used even when it is beyond the '
        'counter', () {
      // Another draft already holds v3 without being published, so the counter
      // alone would collide with it.
      final numbering = templatePublicationNumbering(
        draftVersionNumber: 1,
        latestPublishedVersionNumber: 2,
        nextAvailableVersionNumber: 4,
      );

      expect(numbering.versionNumber, 4);
      expect(numbering.latestVersionNumber, 4);
      expectStoreWouldAccept(numbering);
    });

    test('every resumed draft in a published package leaves an acceptable '
        'package', () {
      for (var latest = 1; latest <= 6; latest++) {
        for (var draft = 1; draft <= 8; draft++) {
          final numbering = templatePublicationNumbering(
            draftVersionNumber: draft,
            latestPublishedVersionNumber: latest,
            nextAvailableVersionNumber: latest + 1,
          );
          expectStoreWouldAccept(numbering);
          expect(
            numbering.versionNumber,
            greaterThan(latest - 1),
            reason: 'a publication never goes backwards',
          );
        }
      }
    });
  });
}
