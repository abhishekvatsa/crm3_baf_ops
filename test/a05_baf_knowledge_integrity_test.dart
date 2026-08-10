import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/core/services/global_pull_cursor_store.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_pull_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_knowledge_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A-05 BAF knowledge row integrity', () {
    test(
      'valid canonical and legacy-compatible fields retain exact authority',
      () {
        final createdAt = DateTime.utc(2026, 8, 10, 10);
        final updatedAt = DateTime.utc(2026, 8, 10, 11);
        final row = BafKnowledgeRow.fromCloudMap(<String, dynamic>{
          ...(_validRow(createdAt: createdAt, updatedAt: updatedAt)
            ..remove('safetyClasses')),
          'safetyClass': <String>['lotoRequired'],
          'suggestedFields': <Map<String, dynamic>>[
            <String, dynamic>{'label': 'Isolation proved'},
          ],
          'fieldPresets': '[{"key":"isolation","label":"Isolation proved"}]',
          'deviceTags': <String>['psl13'],
          'createdAt': Timestamp.fromDate(createdAt),
          'updatedAt': Timestamp.fromDate(updatedAt),
        }, 'KB-001');

        expect(row.rowCode, 'KB-001');
        expect(row.safetyClasses, <String>['lotoRequired']);
        expect(row.suggestedFields, <String>['Isolation proved']);
        expect(row.deviceTags, <String>['PSL13']);
        expect(row.createdAt.toUtc(), createdAt);
        expect(row.updatedAt.toUtc(), updatedAt);
        expect(row.frequency, 'unknown');
        expect(row.discipline, 'mechanical');
        expect(row.requiredForClosure, 'consult');
        expect(row.toEntryMap()['suggestedFieldPresets'], isNotEmpty);
      },
    );

    test(
      'every authority-critical field is required with its persisted type',
      () {
        final valid = _validRow();
        final requiredFields = <String>[
          'rowCode',
          'taskText',
          'moduleCandidateCode',
          'composerReadiness',
          'confidence',
          'lifecycleStatus',
          'matrixVersion',
          'schemaVersion',
          'version',
          'createdByUid',
          'createdAt',
          'updatedByUid',
          'updatedAt',
          'changeSummary',
          'isDeleted',
        ];

        for (final field in requiredFields) {
          final malformed = Map<String, dynamic>.from(valid)..remove(field);
          expect(
            () => BafKnowledgeRow.fromCloudMap(malformed, 'KB-001'),
            throwsA(
              isA<PersistedDataFormatException>().having(
                (error) => error.fieldName,
                'fieldName',
                field,
              ),
            ),
            reason: field,
          );
        }
      },
    );

    test(
      'wrong types, unknown vocabularies and identity drift fail closed',
      () {
        final cases = <String, Object?>{
          'rowCode': 'DIFFERENT',
          'schemaVersion': 1.0,
          'version': '1',
          'ownerDisciplines': 'mechanical',
          'suggestedFields': <Object?>[
            'Observation',
            <String, dynamic>{'label': 'Mixed'},
          ],
          'composerReadiness': 'almostReady',
          'confidence': 'probably',
          'lifecycleStatus': 'deleted',
          'frequency': 'sometimes',
          'discipline': 'unknown-discipline',
          'requiredForClosure': 'maybe',
          'changeSummary': 'too short',
          'isDeleted': 'false',
        };

        for (final entry in cases.entries) {
          final malformed = <String, dynamic>{
            ..._validRow(),
            entry.key: entry.value,
          };
          expect(
            () => BafKnowledgeRow.fromCloudMap(malformed, 'KB-001'),
            throwsA(isA<PersistedDataFormatException>()),
            reason: entry.key,
          );
        }
      },
    );

    test('timeline reversal and unsupported nested values fail closed', () {
      final createdAt = DateTime.utc(2026, 8, 10, 12);
      final older = DateTime.utc(2026, 8, 10, 11);
      expect(
        () => BafKnowledgeRow.fromCloudMap(
          _validRow(createdAt: createdAt, updatedAt: older),
          'KB-001',
        ),
        throwsA(
          isA<PersistedDataFormatException>().having(
            (error) => error.fieldName,
            'fieldName',
            'updatedAt',
          ),
        ),
      );

      for (final value in <Object>[double.nan, Object()]) {
        expect(
          () => BafKnowledgeRow.fromCloudMap(<String, dynamic>{
            ..._validRow(),
            'extension': <String, Object>{'unsafe': value},
          }, 'KB-001'),
          throwsA(isA<PersistedDataFormatException>()),
        );
      }
    });

    test('malformed presets and corrupt local raw JSON are not discarded', () {
      expect(
        () => BafKnowledgeRow.fromCloudMap(<String, dynamic>{
          ..._validRow(),
          'suggestedFieldPresets': '[{"label":',
        }, 'KB-001'),
        throwsA(isA<PersistedDataFormatException>()),
      );

      final row = BafKnowledgeRow.fromCloudMap(_validRow(), 'KB-001');
      row.rawJson = '{broken';
      expect(
        row.toEntryMap,
        throwsA(
          isA<PersistedDataFormatException>().having(
            (error) => error.fieldName,
            'fieldName',
            'rawJson',
          ),
        ),
      );
    });
  });

  group('A-05 BAF matrix metadata integrity', () {
    test(
      'valid metadata retains remote time and local receipt time separately',
      () {
        final updatedAt = DateTime.utc(2026, 8, 10, 13);
        final meta = BafKnowledgeMatrixMetaStore.fromCloudMap(
          _validMeta(updatedAt: Timestamp.fromDate(updatedAt)),
          localCachedAt: DateTime.utc(2026, 8, 10, 13, 1),
        );

        expect(meta.cloudUpdatedAt?.toUtc(), updatedAt);
        expect(meta.updatedAt.toUtc(), updatedAt);
        expect(meta.localCachedAt, isNotNull);
        expect(meta.source, 'cloud');
        expect(meta.knowledgeRowCount, 4);
        expect(meta.tagRowCount, 2);
      },
    );

    test('missing authority, wrong counts and unknown schema fail closed', () {
      final cases = <Map<String, dynamic>>[
        Map<String, dynamic>.from(_validMeta())..remove('updatedAt'),
        <String, dynamic>{..._validMeta(), 'knowledgeRowCount': '4'},
        <String, dynamic>{..._validMeta(), 'tagRowCount': 5},
        <String, dynamic>{..._validMeta(), 'schemaVersion': 2},
        <String, dynamic>{..._validMeta(), 'changeSummary': 'short'},
      ];
      for (final malformed in cases) {
        expect(
          () => BafKnowledgeMatrixMetaStore.fromCloudMap(
            malformed,
            localCachedAt: DateTime.utc(2026, 8, 10, 13, 1),
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
      }
    });
  });

  group('A-05 alternate persisted decoder names', () {
    test(
      'workflow quarantine requires identity and authoritative receipt time',
      () {
        final quarantinedAt = DateTime.utc(2026, 8, 10, 14);
        final record = WorkflowPullQuarantineRecord.fromJson(<String, dynamic>{
          'collection': 'maintenance_workflows',
          'documentId': 'workflow-1',
          'stage': 'decode',
          'error': 'Malformed persisted workflow projection.',
          'observedAt': null,
          'quarantinedAt': quarantinedAt.toIso8601String(),
        });
        expect(record.quarantinedAt, quarantinedAt);
        expect(record.observedAt, isNull);

        for (final malformed in <Map<String, dynamic>>[
          <String, dynamic>{
            'collection': 7,
            'documentId': 'workflow-1',
            'stage': 'decode',
            'error': 'Malformed persisted workflow projection.',
            'quarantinedAt': quarantinedAt.toIso8601String(),
          },
          <String, dynamic>{
            'collection': 'maintenance_workflows',
            'documentId': 'workflow-1',
            'stage': 'decode',
            'error': 'Malformed persisted workflow projection.',
          },
          <String, dynamic>{
            'collection': 'maintenance_workflows',
            'documentId': 'workflow-1',
            'stage': 'decode',
            'error': 'Malformed persisted workflow projection.',
            'observedAt': 'not-a-time',
            'quarantinedAt': quarantinedAt.toIso8601String(),
          },
        ]) {
          expect(
            () => WorkflowPullQuarantineRecord.fromJson(malformed),
            throwsA(isA<PersistedDataFormatException>()),
          );
        }
      },
    );

    test(
      'global pull cursor retains stable error mapping with shared reader',
      () {
        final instant = DateTime.utc(2026, 8, 10, 15);
        final cursor = GlobalPullDomainCursor.fromJson(<String, Object?>{
          'cursor': instant.toIso8601String(),
          'completedInRun': true,
        });
        expect(cursor.cursor, instant);
        expect(cursor.completedInRun, isTrue);

        expect(
          () => GlobalPullDomainCursor.fromJson(const <String, Object?>{
            'cursor': '2026-99-99T00:00:00.000Z',
            'completedInRun': true,
          }),
          throwsA(
            isA<GlobalPullCursorException>().having(
              (error) => error.reasonCode,
              'reasonCode',
              'domain-cursor-timestamp-invalid',
            ),
          ),
        );
      },
    );
  });

  test('repository and governance paths decode before mutation or comparison', () {
    final repository =
        File(
          'lib/features/planned_maintenance/domain/baf_knowledge_repository.dart',
        ).readAsStringSync();
    final provider =
        File(
          'lib/features/planned_maintenance/providers/knowledge_governance_provider.dart',
        ).readAsStringSync();

    expect(
      repository,
      contains('BafKnowledgeRow.fromCloudMap(doc.data(), doc.id).toEntry(i)'),
    );
    expect(repository, isNot(contains('.catchError((_) => null)')));
    expect(
      repository.indexOf('final metaDoc = await metaFuture;'),
      lessThan(
        repository.indexOf(
          'if (docs.isEmpty) return const BafKnowledgePullResult',
        ),
      ),
    );
    expect(
      repository.indexOf('final remotes = ['),
      lessThan(repository.indexOf('await _isar.writeTxn(() async {')),
    );
    expect(
      repository.indexOf('BafKnowledgeMatrixMetaStore.fromCloudMap'),
      lessThan(repository.indexOf('await _isar.writeTxn(() async {')),
    );
    expect(
      provider,
      contains('BafKnowledgeRow.fromCloudMap(data, before.rowCode)'),
    );
    expect(
      provider,
      contains('BafKnowledgeRow.fromCloudMap(data, local.rowCode)'),
    );
    expect(provider, contains('} on FirebaseException {'));
    expect(provider, isNot(contains('int _cloudVersionFrom(')));
  });
}

Map<String, dynamic> _validRow({DateTime? createdAt, DateTime? updatedAt}) {
  final created = createdAt ?? DateTime.utc(2026, 8, 10, 10);
  return <String, dynamic>{
    'rowCode': 'KB-001',
    'schemaVersion': 1,
    'taskText': 'Inspect the governed BAF component and record evidence.',
    'moduleCandidateCode': 'KB-MOD-001',
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
    'updatedAt': updatedAt ?? created,
    'version': 1,
    'createdByUid': 'admin-1',
    'createdAt': created,
    'isDeleted': false,
  };
}

Map<String, dynamic> _validMeta({Object? updatedAt}) {
  return <String, dynamic>{
    'matrixVersion': 'baf-test-v1',
    'sourceLabel': 'Governed BAF knowledge test matrix',
    'knowledgeRowCount': 4,
    'tagRowCount': 2,
    'schemaVersion': 1,
    'version': 1,
    'updatedByUid': 'admin-1',
    'updatedAt': updatedAt ?? DateTime.utc(2026, 8, 10, 13),
    'changeSummary': 'Updated the governed BAF knowledge metadata.',
    'isDeleted': false,
  };
}
