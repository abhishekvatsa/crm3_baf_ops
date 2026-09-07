import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_correction_promoter.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/repositories/knowledge_correction_source_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retains canonical publication time across persisted representations',
    () {
      final expected = DateTime.utc(2026, 9, 1, 4, 30);
      final timestamp = Timestamp.fromDate(expected);

      for (final value in <dynamic>[
        expected,
        timestamp,
        expected.toIso8601String(),
        {'_seconds': timestamp.seconds, '_nanoseconds': timestamp.nanoseconds},
      ]) {
        expect(
          readKnowledgeCorrectionPublicationTime(value, source: 'test'),
          expected,
        );
      }
      expect(
        () => readKnowledgeCorrectionPublicationTime(
          'not-a-publication-time',
          source: 'test',
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'an older snapshot processed later cannot replace a newer correction',
    () {
      String snapshot(String component) => jsonEncode({
        'composer': {
          'tagResolverCorrections': [
            {
              'rawInput': 'PT-101',
              'normalizedTag': 'PT-101',
              'resolvedComponent': component,
              'status': 'approvedForThisVersion',
            },
          ],
        },
      });

      final newerAt = readKnowledgeCorrectionPublicationTime(
        '2026-09-02T04:30:00.000Z',
        source: 'newer',
      );
      final olderAt = readKnowledgeCorrectionPublicationTime(
        '2026-09-01T04:30:00.000Z',
        source: 'older',
      );
      final corrections = KnowledgeCorrectionPromoter.harvestMany(
        snapshots: [
          HarvestableTemplateSnapshot(
            versionFirestoreId: 'newer-version',
            packageCode: 'PKG',
            versionNumber: 2,
            jobTemplateSnapshotJson: snapshot('New governed component'),
            harvestedAt: newerAt,
          ),
          HarvestableTemplateSnapshot(
            versionFirestoreId: 'older-version',
            packageCode: 'PKG',
            versionNumber: 1,
            jobTemplateSnapshotJson: snapshot('Old component'),
            harvestedAt: olderAt,
          ),
        ],
      );

      expect(corrections, hasLength(1));
      expect(corrections.single.sourceTemplateVersionId, 'newer-version');
      expect(corrections.single.resolvedComponent, 'New governed component');
    },
  );
}
