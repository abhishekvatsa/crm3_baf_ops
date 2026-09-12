import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The A-05 manifest names, for every governed decoder surface, the test that
/// proves its malformed disposition. That reference was never resolved, so an
/// entry could name a test that did not exist and the gate stayed satisfied.
/// `workflow-uncertain-retry` carried exactly that: a declared regression with
/// no file behind it, and nothing covering the disposition it governs.
void main() {
  late Map<String, dynamic> manifest;

  setUpAll(() {
    manifest =
        jsonDecode(
              File(
                'governance/a05-persisted-decoder-surface-v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  Iterable<String> declaredReferences() sync* {
    for (final key in const <String>['surfaces', 'catchSites']) {
      for (final entry in (manifest[key] as List<dynamic>)) {
        final declared = (entry as Map<String, dynamic>)['regression'];
        if (declared is! String) continue;
        for (final raw in declared.split(RegExp(r'[;,\s]+'))) {
          if (raw.trim().isNotEmpty) yield raw.trim();
        }
      }
    }
  }

  test('the checker resolves declared regression references', () {
    final tool =
        File(
          'tools/v4/a05_persisted_decoder_inventory.py',
        ).readAsStringSync();

    expect(tool, contains('_check_regression'));
    expect(tool, contains('does not exist'));
    expect(
      tool,
      contains('staleRegressionReferences'),
      reason: 'known stale references must be enumerated, not ignored',
    );
  });

  test('every declared regression exists or is enumerated as stale', () {
    final stale =
        (manifest['staleRegressionReferences'] as List<dynamic>)
            .cast<String>()
            .toSet();

    final broken = <String>[];
    for (final reference in declaredReferences()) {
      if (File(reference).existsSync()) continue;
      if (stale.contains(reference)) continue;
      broken.add(reference);
    }

    expect(
      broken,
      isEmpty,
      reason:
          'a governed surface names a regression that does not exist and is '
          'not recorded as known debt',
    );
  });

  test('the stale list does not outlive the files it excuses', () {
    // Once a reference is re-mapped or its file written, the entry must go,
    // or the list quietly becomes permission to keep breaking references.
    final stale =
        (manifest['staleRegressionReferences'] as List<dynamic>)
            .cast<String>();

    for (final reference in stale) {
      expect(
        File(reference).existsSync(),
        isFalse,
        reason: '$reference now exists and should be removed from the list',
      );
    }
  });

  test('the debt is explained, not merely listed', () {
    expect(manifest['staleRegressionReferenceNote'], isA<String>());
    expect(
      manifest['staleRegressionReferenceNote'] as String,
      contains('disposition'),
    );
  });
}
