import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/template_content_hash_precision.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final base = fixture['version'] as Map<String, dynamic>;
  for (final raw in fixture['cases'] as List) {
    final row = raw as Map<String, dynamic>;
    test('Dart governed hash preserves ${row['name']}', () {
      final snapshot =
          jsonDecode(base['jobTemplateSnapshotJson'] as String)
              as Map<String, dynamic>;
      (snapshot['composer']
              as Map<String, dynamic>)['closureReviewConfirmedAt'] =
          row['reviewAt'];
      final version = TemplateVersion()
        ..jobTemplateSnapshotJson = jsonEncode(snapshot)
        ..moduleSnapshotsJson = base['moduleSnapshotsJson'] as String
        ..fieldDefinitionsJson = base['fieldDefinitionsJson'] as String
        ..checklistJson = base['checklistJson'] as String
        ..metadataJson = base['metadataJson'] as String?
        ..schemaVersion = base['schemaVersion'] as int;
      expect(version.computeContentHash(), row['expectedHash']);
    });
  }
}
