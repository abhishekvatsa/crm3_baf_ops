import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/services/global_pull_protocol.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_knowledge_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BafKnowledgeRow Firestore normalization', () {
    test(
      'accepts Timestamp values and excludes the server-owned watermark',
      () {
        final createdAt = DateTime.utc(2026, 8, 2, 14, 35);
        final updatedAt = DateTime.utc(2026, 8, 2, 14, 36);
        final serverStamp = DateTime.utc(2026, 8, 2, 14, 37);

        final row = BafKnowledgeRow.fromCloudMap(<String, dynamic>{
          ..._validKnowledgeRow('knowledge-1', createdAt),
          'createdAt': Timestamp.fromDate(createdAt),
          'updatedAt': Timestamp.fromDate(updatedAt),
          globalPullServerUpdatedAtField: Timestamp.fromDate(serverStamp),
          'nested': <String, dynamic>{
            'observedAt': Timestamp.fromDate(updatedAt),
          },
        }, 'knowledge-1');

        final raw = jsonDecode(row.rawJson) as Map<String, dynamic>;
        expect(raw, isNot(contains(globalPullServerUpdatedAtField)));
        expect(raw['createdAt'], createdAt.toIso8601String());
        expect(raw['updatedAt'], updatedAt.toIso8601String());
        expect(
          (raw['nested'] as Map<String, dynamic>)['observedAt'],
          updatedAt.toIso8601String(),
        );
        expect(row.createdAt.toUtc(), createdAt);
        expect(row.updatedAt.toUtc(), updatedAt);
      },
    );

    test('never reauthors a watermark retained by an older local cache', () {
      final now = DateTime.utc(2026, 8, 2, 14, 38);
      final row = BafKnowledgeRow.fromCloudMap(<String, dynamic>{
        ..._validKnowledgeRow('knowledge-2', now),
        'updatedAt': now,
      }, 'knowledge-2');
      row.rawJson = jsonEncode(<String, dynamic>{
        'rowCode': row.rowCode,
        globalPullServerUpdatedAtField: now.toIso8601String(),
      });

      expect(row.toEntryMap(), isNot(contains(globalPullServerUpdatedAtField)));
      expect(row.toCloudMap(), isNot(contains(globalPullServerUpdatedAtField)));
    });
  });
}

Map<String, dynamic> _validKnowledgeRow(String rowCode, DateTime timestamp) {
  return <String, dynamic>{
    'rowCode': rowCode,
    'schemaVersion': 1,
    'taskText': 'Inspect the governed BAF component and record evidence.',
    'moduleCandidateCode': '$rowCode-module',
    'ownerDisciplines': <String>['mechanical'],
    'safetyClasses': <String>['normal'],
    'procedureRefs': <String>[],
    'partRefs': <String>[],
    'deviceTags': <String>[],
    'targetRefs': <String>[],
    'suggestedFields': <String>['Observation'],
    'composerReadiness': 'readyPreset',
    'confidence': 'confirmedManual',
    'lifecycleStatus': 'active',
    'matrixVersion': 'baf-test-v1',
    'changeSummary': 'Created a governed BAF knowledge test row.',
    'updatedByUid': 'admin-1',
    'updatedAt': timestamp,
    'version': 1,
    'createdByUid': 'admin-1',
    'createdAt': timestamp,
    'isDeleted': false,
  };
}
