import 'dart:convert';

import 'package:crm3_baf_ops/features/maintenance/domain/frequent_issue_selection.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/furnace_stuckup_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mergers = <String, String Function(String?)>{
    'frequent issue': (raw) =>
        mergeFrequentIssueSelectionIntoMaintenanceMetadata(raw, null),
    'furnace stuck-up': (raw) =>
        mergeFurnaceStuckupIntoMaintenanceMetadata(raw, null),
  };
  for (final merger in mergers.entries) {
    for (final entry in <String, String>{
      'list': '[1, {"legacy":"evidence"}]',
      'string': '"Original operator note"',
      'number': '42',
      'true': 'true',
      'false': 'false',
      'null': 'null',
      'surrounding whitespace': ' \n[1,2]\t',
      'malformed JSON': '{retained original text',
    }.entries) {
      test('${merger.key} preserves exact ${entry.key} source bytes', () {
        final merged = merger.value(entry.value);
        expect(jsonDecode(merged), {'legacyMetadata': entry.value});
        expect(
          jsonDecode(merger.value(merged)),
          {'legacyMetadata': entry.value},
          reason: 'A later merge must retain the same original evidence.',
        );
      });
    }

    test('${merger.key} preserves an ordinary metadata object', () {
      final original = {
        'qualityIntent': {'schemaVersion': 1, 'assessment': 'notSuspected'},
        'note': 'Original operator note',
        'legacyMetadata': 'Even earlier retained bytes',
      };
      expect(jsonDecode(merger.value(jsonEncode(original))), original);
    });

    for (final absent in <String?>[null, '', '  ']) {
      test('${merger.key} keeps absent metadata absent: $absent', () {
        expect(jsonDecode(merger.value(absent)), isEmpty);
      });
    }
  }
}
