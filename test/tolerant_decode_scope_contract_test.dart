import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tolerant decoding was rolled out to every live Firestore read at once. Two
/// separate consequences followed, and both were decisions taken on a list
/// that could not say it was short.
///
/// The paginated pull readers page on the decoded count, so dropping one
/// document from a full page ended the loop early, later valid pages were
/// never fetched, and the domain still completed - advancing its cursor past
/// records never read.
///
/// Worse, an identity read used during synchronization returned nothing for a
/// document that existed but could not be decoded. The caller reads that as
/// absence: a pending local deletion was counted converged and marked
/// synchronized without the server ever being asked to delete anything.
///
/// The real rule is what the consumer infers from absence, and no syntactic
/// check can establish that. `Future` versus `Stream` is a containment
/// heuristic that happens to catch the one-shot reads which drive decisions -
/// create, update, delete, converge, resolve an identity, assemble evidence -
/// and it is not a semantic boundary. Streams feed decisions too: the plant
/// summary computes its totals from a watched asset population, so those reads
/// are strict as well despite being streams.
///
/// This guard therefore prevents one specific coding pattern from returning.
/// It is not a consumer inventory and cannot show that every surviving
/// tolerant stream is safe.
void main() {
  final offenders = <String>[];

  setUpAll(() {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('.g.dart') ||
          path.contains('core/serialization/tolerant_snapshot_decode')) {
        continue;
      }
      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('decodeSnapshotDocuments')) continue;
        String? kind;
        for (var j = i; j >= 0 && j > i - 60; j--) {
          final match = RegExp(r'^  (Future|Stream)<').firstMatch(lines[j]);
          if (match != null) {
            kind = match.group(1);
            break;
          }
        }
        if (kind == 'Future') offenders.add('$path:${i + 1}');
      }
    }
  });

  test('no one-shot read decodes tolerantly', () {
    expect(
      offenders,
      isEmpty,
      reason:
          'a Future read answers a question that drives a decision; an '
          'undecodable record must not be reported as an absent one',
    );
  });

  test('an unreadable remote record cannot look like an absent one', () {
    // The consumer that made this concrete: absence on a deleted local record
    // is treated as convergence, so the deletion is marked synchronized
    // without a remote delete ever being requested.
    final consumer =
        File(
          'lib/core/services/sync_service.directives_abnormalities.dart',
        ).readAsStringSync();
    expect(consumer, contains('convergedRecords.add(record)'));

    final reader =
        File(
          'lib/features/abnormalities/providers/abnormality_provider.remote.dart',
        ).readAsStringSync();
    final identityRead = reader.substring(
      reader.indexOf('getAbnormalitiesByFirestoreIds'),
    );
    final body = identityRead.substring(0, identityRead.indexOf('\n  }'));
    expect(
      body,
      contains('ChargeAbnormality.fromMap(doc.data(), doc.id)'),
      reason: 'the read feeding that convergence decision must be strict',
    );
  });

  test('the pull still paginates on a count it can trust', () {
    final source =
        File(
          'lib/core/services/global_pull_service.abnormalities.dart',
        ).readAsStringSync();
    expect(source, contains('records.length < GlobalPullService._pageSize'));
  });
}
