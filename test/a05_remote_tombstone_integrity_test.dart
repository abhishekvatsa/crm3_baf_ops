import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/services/remote_tombstone_apply_result.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';

void main() {
  group('A-05 remote tombstone authority', () {
    test('all deletedAt-bearing remote model decoders fail closed', () {
      const createdAt = '2026-08-05T10:00:00.000Z';
      const updatedAt = '2026-08-05T11:00:00.000Z';
      final decoders = <String, Object? Function()>{
        'abnormality type':
            () => AbnormalityType.fromMap(const <String, dynamic>{
              'firestoreId': 'type-1',
              'isDeleted': true,
              'isActive': false,
              'deletedByUid': 'admin-1',
              'createdAt': createdAt,
              'updatedAt': updatedAt,
            }, 'type-1'),
        'charge abnormality':
            () => ChargeAbnormality.fromMap(const <String, dynamic>{
              'firestoreId': 'abnormality-1',
              'sourceChargeNo': 12001,
              'isDeleted': true,
              'reannealingStatus': 'notApplicable',
              'deletedByUid': 'admin-1',
              'deletedByName': 'Admin One',
              'deleteReason': 'Duplicate record confirmed',
              'loggedByUid': 'operations-1',
              'updatedByUid': 'admin-1',
              'loggedAt': createdAt,
              'updatedAt': updatedAt,
            }, 'abnormality-1'),
        'job template':
            () => JobTemplate.fromMap(const <String, dynamic>{
              'isDeleted': true,
              'createdAt': createdAt,
              'updatedAt': updatedAt,
            }, 'template-1'),
        'job execution':
            () => JobExecution.fromMap(const <String, dynamic>{
              'isDeleted': true,
              'createdAt': createdAt,
              'updatedAt': updatedAt,
            }, 'execution-1'),
        'job module':
            () => JobModuleInstance.fromMap(const <String, dynamic>{
              'isDeleted': true,
              'createdAt': createdAt,
              'updatedAt': updatedAt,
            }, 'module-1'),
        'job diary entry':
            () => JobDiaryEntry.fromMap(const <String, dynamic>{
              'isDeleted': true,
              'createdAt': createdAt,
              'updatedAt': updatedAt,
            }, 'diary-1'),
        'template package':
            () => TemplatePackage.fromMap(const <String, dynamic>{
              'firestoreId': 'package-1',
              'isDeleted': true,
            }, 'package-1'),
        'template version':
            () => TemplateVersion.fromMap(const <String, dynamic>{
              'firestoreId': 'version-1',
              'isDeleted': true,
            }, 'version-1'),
      };

      for (final MapEntry(key: label, value: decode) in decoders.entries) {
        expect(
          decode,
          throwsA(
            isA<RemoteTombstoneIntegrityException>()
                .having((error) => error.entityLabel, 'entityLabel', label)
                .having(
                  (error) => error.message,
                  'message',
                  contains('no authoritative deletedAt timestamp'),
                ),
          ),
          reason: '$label must not manufacture a deletion time',
        );
      }
    });

    test('an authoritative deletion time is retained exactly', () {
      final deletedAt = DateTime.utc(2026, 8, 5, 12, 30);
      expect(
        requireRemoteTombstoneDeletedAt(
          deletedAt,
          entityLabel: 'job execution',
          firestoreId: 'execution-1',
        ),
        same(deletedAt),
      );
    });

    test('provider source contains no remote deletion-time substitution', () {
      const paths = <String>[
        'lib/features/abnormalities/providers/abnormality_provider.dart',
        'lib/features/directives/providers/operational_directive_provider.dart',
        'lib/features/maintenance/providers/maintenance_provider.dart',
        'lib/features/planned_maintenance/providers/job_diary_provider.dart',
        'lib/features/planned_maintenance/providers/job_module_provider.dart',
        'lib/features/planned_maintenance/providers/planned_maintenance_provider.dart',
        'lib/features/planned_maintenance/providers/template_governance_provider.dart',
      ];

      for (final path in paths) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('remote.deletedAt ??')), reason: path);
        expect(
          source,
          contains('requireRemoteTombstoneDeletedAt'),
          reason: path,
        );
      }
    });
  });
}
