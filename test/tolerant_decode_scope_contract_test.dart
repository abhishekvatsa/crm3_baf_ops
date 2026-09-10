import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tolerant decoding was rolled out to every live Firestore read at once,
/// including the paginated delta readers that feed the global pull. That was a
/// mistake with real consequences.
///
/// Those readers page on the decoded record count:
///
/// ```dart
/// if (records.length < GlobalPullService._pageSize) break;
/// ```
///
/// So dropping one malformed document from a full 500-document page yields
/// 499, the loop stops, valid later pages are never fetched, and the domain
/// still completes - advancing its cursor past records that were never read.
/// Silent coverage loss, which is precisely what the synchronization work
/// exists to prevent.
///
/// A browse list can show what decoded and say it is incomplete. An
/// authoritative read cannot, until its page contract can carry the raw
/// document count and the rejected identities. Until then it stays strict.
void main() {
  Iterable<File> dartSources() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.g.dart')) {
        yield entity;
      }
    }
  }

  test('no authoritative pull read decodes tolerantly', () {
    final offenders = <String>[];

    for (final file in dartSources()) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('decodeSnapshotDocuments')) continue;
        final start = i - 25 < 0 ? 0 : i - 25;
        final window = lines.sublist(start, i + 1).join('\n');
        if (window.contains('authoritativeGlobalPullReadOptions')) {
          offenders.add('${file.path.replaceAll(r'\', '/')}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a dropped document shortens the page, ends pagination early and '
          'lets the cursor advance past records that were never fetched',
    );
  });

  test('the pull still paginates on a count it can trust', () {
    // If this ever pages on a decoded count while any reader is tolerant, the
    // two halves of the contract have drifted apart again.
    final source =
        File(
          'lib/core/services/global_pull_service.abnormalities.dart',
        ).readAsStringSync();

    expect(source, contains('records.length < GlobalPullService._pageSize'));
  });
}
