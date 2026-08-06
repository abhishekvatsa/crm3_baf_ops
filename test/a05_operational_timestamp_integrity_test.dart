import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/remote_abnormality_timestamps.dart';
import 'package:crm3_baf_ops/features/directives/data/remote_operational_directive_timestamps.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/remote_job_timestamps.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _TimestampReader = Object Function(Map<String, dynamic> map);

class _DecoderCase {
  const _DecoderCase({
    required this.id,
    required this.requiredFields,
    required this.optionalFields,
    required this.read,
  });

  final String id;
  final List<String> requiredFields;
  final List<String> optionalFields;
  final _TimestampReader read;
}

void main() {
  final cases = <_DecoderCase>[
    _DecoderCase(
      id: 'abnormality-type',
      requiredFields: const ['createdAt', 'updatedAt'],
      optionalFields: const ['deletedAt'],
      read:
          (map) => readRemoteAbnormalityTypeTimestamps(
            map,
            source: 'abnormality type test',
          ),
    ),
    _DecoderCase(
      id: 'charge-abnormality',
      requiredFields: const ['loggedAt', 'updatedAt'],
      optionalFields: const ['deletedAt'],
      read:
          (map) => readRemoteChargeAbnormalityTimestamps(
            map,
            source: 'charge abnormality test',
          ),
    ),
    _DecoderCase(
      id: 'job-template',
      requiredFields: const ['createdAt', 'updatedAt'],
      optionalFields: const ['deletedAt'],
      read:
          (map) =>
              readRemoteJobTemplateTimestamps(map, source: 'job template test'),
    ),
    _DecoderCase(
      id: 'job-execution',
      requiredFields: const ['createdAt', 'updatedAt'],
      optionalFields: const [
        'cancelledAt',
        'laneSetFinalizedAt',
        'completedAt',
        'deletedAt',
      ],
      read:
          (map) => readRemoteJobExecutionTimestamps(
            map,
            source: 'job execution test',
          ),
    ),
    _DecoderCase(
      id: 'operational-directive',
      requiredFields: const ['createdAt', 'updatedAt'],
      optionalFields: const [
        'issuedAt',
        'acknowledgedAt',
        'closedAt',
        'deletedAt',
      ],
      read:
          (map) => readRemoteOperationalDirectiveTimestamps(
            map,
            source: 'operational directive test',
          ),
    ),
    _DecoderCase(
      id: 'job-diary-entry',
      requiredFields: const ['createdAt', 'updatedAt'],
      optionalFields: const ['deletedAt'],
      read:
          (map) => readRemoteJobDiaryTimestamps(map, source: 'job diary test'),
    ),
    _DecoderCase(
      id: 'job-module-instance',
      requiredFields: const ['createdAt', 'updatedAt'],
      optionalFields: const [
        'addedAt',
        'submittedAt',
        'acceptedAt',
        'reopenedAt',
        'notApplicableAt',
        'deletedAt',
      ],
      read:
          (map) =>
              readRemoteJobModuleTimestamps(map, source: 'job module test'),
    ),
  ];

  group('A-05 operational timestamp integrity', () {
    test('inventory covers seven value-object decoders and 32 fields', () {
      expect(cases, hasLength(7));
      expect(
        cases.fold<int>(0, (total, item) => total + item.requiredFields.length),
        14,
      );
      expect(
        cases.fold<int>(0, (total, item) => total + item.optionalFields.length),
        18,
      );
    });

    test('governed timestamp representations retain their exact instant', () {
      final first = DateTime.utc(2026, 8, 6, 1);
      final second = DateTime.utc(2026, 8, 6, 2);
      final third = DateTime.utc(2026, 8, 6, 3);

      for (final item in cases) {
        final map = <String, dynamic>{};
        for (var index = 0; index < item.requiredFields.length; index++) {
          map[item.requiredFields[index]] =
              index.isEven
                  ? Timestamp.fromDate(first)
                  : second.toIso8601String();
        }
        for (final field in item.optionalFields) {
          map[field] = third;
        }
        expect(item.read(map), isNotNull, reason: item.id);
      }
    });

    test('missing or malformed required timestamps fail closed', () {
      for (final item in cases) {
        final valid = _validRequiredMap(item);
        for (final field in item.requiredFields) {
          final missing = Map<String, dynamic>.from(valid)..remove(field);
          expect(
            () => item.read(missing),
            _invalidField(field),
            reason: '${item.id} missing $field',
          );

          final malformed = Map<String, dynamic>.from(valid)
            ..[field] = 'not-a-timestamp';
          expect(
            () => item.read(malformed),
            _invalidField(field),
            reason: '${item.id} malformed $field',
          );
        }
      }
    });

    test('malformed present optional timestamps fail closed', () {
      for (final item in cases) {
        final valid = _validRequiredMap(item);
        for (final field in item.optionalFields) {
          final malformed = Map<String, dynamic>.from(valid)
            ..[field] = _TimestampLike();
          expect(
            () => item.read(malformed),
            _invalidField(field),
            reason: '${item.id} malformed $field',
          );
        }
      }
    });

    test('workflow receipts require their persisted application time', () {
      final valid = <String, dynamic>{
        'commandId': 'command-1',
        'resultKey': 'result-1',
        'aggregateVersion': 1,
        'result': <String, Object?>{},
        'appliedAt': '2026-08-06T01:00:00.000Z',
      };
      expect(
        WorkflowCommandReceipt.fromMap(valid).appliedAt,
        DateTime.utc(2026, 8, 6, 1),
      );
      expect(
        () => WorkflowCommandReceipt.fromMap(
          Map<String, dynamic>.from(valid)..remove('appliedAt'),
        ),
        _invalidField('appliedAt'),
      );
      expect(
        () => WorkflowCommandReceipt.fromMap(<String, dynamic>{
          ...valid,
          'appliedAt': 'not-a-time',
        }),
        _invalidField('appliedAt'),
      );
    });
  });
}

Map<String, dynamic> _validRequiredMap(_DecoderCase item) => <String, dynamic>{
  for (final field in item.requiredFields) field: '2026-08-06T01:00:00.000Z',
};

Matcher _invalidField(String field) => throwsA(
  isA<PersistedDataFormatException>().having(
    (error) => error.fieldName,
    'fieldName',
    field,
  ),
);

class _TimestampLike {
  DateTime toDate() => DateTime.utc(2026, 8, 6);
}
