import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tools/testing/dart_library_source.dart';

void main() {
  group('A-05 abnormality-type persisted integrity', () {
    test('a complete type retains exact persisted authority', () {
      final type = AbnormalityType.fromMap(_validType(), 'type-1');

      expect(type.firestoreId, 'type-1');
      expect(type.code, 'FURNACE_STUCK');
      expect(type.category, AbnormalityCategory.equipment);
      expect(type.severity, AbnormalitySeverity.high);
      expect(type.applicableAssetTypes, <AssetType>[AssetType.furnace]);
      expect(type.version, 2);
      expect(type.isSynced, isTrue);
    });

    test('every authority-bearing type field is required', () {
      const fields = <String>[
        'firestoreId',
        'code',
        'title',
        'category',
        'severity',
        'applicableAssetTypes',
        'suggestsReannealing',
        'isActive',
        'isDeleted',
        'createdAt',
        'updatedAt',
        'version',
      ];

      for (final field in fields) {
        final map = _validType()..remove(field);
        expect(
          () => AbnormalityType.fromMap(map, 'type-1'),
          _invalidField(field),
          reason: field,
        );
      }
    });

    test('unknown type enums and scalar coercions fail closed', () {
      final cases = <String, Object?>{
        'category': 'unclassified',
        'severity': 2,
        'applicableAssetTypes': 'furnace',
        'suggestsReannealing': 0,
        'isActive': 'true',
        'isDeleted': 0,
        'version': '2',
        'description': 7,
      };

      for (final entry in cases.entries) {
        expect(
          () => AbnormalityType.fromMap(<String, dynamic>{
            ..._validType(),
            entry.key: entry.value,
          }, 'type-1'),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });

    test('type identity, assets, actors, and timeline cannot drift', () {
      final cases = <String, Map<String, dynamic>>{
        'firestoreId': <String, dynamic>{
          ..._validType(),
          'firestoreId': 'type-2',
        },
        'applicableAssetTypes': <String, dynamic>{
          ..._validType(),
          'applicableAssetTypes': <String>['furnace', 'furnace'],
        },
        'createdByName': <String, dynamic>{
          ..._validType(),
          'createdByUid': null,
        },
        'updatedAt': <String, dynamic>{
          ..._validType(),
          'updatedAt': '2026-08-10T09:59:59.000Z',
        },
      };

      for (final entry in cases.entries) {
        expect(
          () => AbnormalityType.fromMap(entry.value, 'type-1'),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });

    test('type deletion state is retained rather than repaired', () {
      final deleted = AbnormalityType.fromMap(<String, dynamic>{
        ..._validType(),
        'isActive': false,
        'isDeleted': true,
        'deletedAt': '2026-08-10T10:45:00.000Z',
        'deletedByUid': 'admin-1',
        'deletedByName': 'Admin One',
        'deleteReason': 'Duplicate governed type',
      }, 'type-1');
      expect(deleted.isDeleted, isTrue);
      expect(deleted.deletedByUid, 'admin-1');

      final cases = <String, Map<String, dynamic>>{
        'isActive': <String, dynamic>{
          ..._validType(),
          'isDeleted': true,
          'deletedAt': '2026-08-10T10:45:00.000Z',
          'deletedByUid': 'admin-1',
        },
        'isDeleted-state': <String, dynamic>{
          ..._validType(),
          'deletedAt': '2026-08-10T10:45:00.000Z',
        },
        'deletedByUid': <String, dynamic>{
          ..._validType(),
          'isActive': false,
          'isDeleted': true,
          'deletedAt': '2026-08-10T10:45:00.000Z',
        },
        'deletedByName-state': <String, dynamic>{
          ..._validType(),
          'deletedByName': 'Admin One',
        },
      };

      for (final entry in cases.entries) {
        final expectedField =
            entry.key == 'isDeleted-state' || entry.key == 'deletedByName-state'
                ? 'isDeleted'
                : entry.key;
        expect(
          () => AbnormalityType.fromMap(entry.value, 'type-1'),
          _invalidField(expectedField),
          reason: entry.key,
        );
      }
    });
  });

  group('A-05 charge-abnormality persisted integrity', () {
    test('a complete charge abnormality retains exact authority', () {
      final abnormality = ChargeAbnormality.fromMap(_validCharge(), 'abn-1');

      expect(abnormality.firestoreId, 'abn-1');
      expect(abnormality.sourceChargeNo, 12001);
      expect(abnormality.abnormalityTypeCode, 'FURNACE_STUCK');
      expect(abnormality.severity, AbnormalitySeverity.critical);
      expect(abnormality.affectedAssets, hasLength(2));
      expect(abnormality.version, 4);
      expect(abnormality.isSynced, isTrue);
    });

    test('every authority-bearing charge field is required', () {
      const fields = <String>[
        'firestoreId',
        'sourceChargeNo',
        'abnormalityTypeId',
        'abnormalityTypeTitle',
        'abnormalityTypeCode',
        'category',
        'severity',
        'affectedAssets',
        'observedReason',
        'possibleRootReasonCategory',
        'reannealingStatus',
        'loggedAt',
        'updatedAt',
        'loggedByUid',
        'updatedByUid',
        'version',
        'isDeleted',
      ];

      for (final field in fields) {
        final map = _validCharge()..remove(field);
        expect(
          () => ChargeAbnormality.fromMap(map, 'abn-1'),
          _invalidField(field),
          reason: field,
        );
      }
    });

    test('unknown charge enums and scalar coercions fail closed', () {
      final cases = <String, Object?>{
        'sourceChargeNo': '12001',
        'category': 'unclassified',
        'severity': 3,
        'affectedAssets': '[]',
        'component': 7,
        'possibleRootReasonCategory': 'unknown_reason',
        'reannealingStatus': 0,
        'reannealedToChargeNo': '12002',
        'isDeleted': 0,
        'version': '4',
      };

      for (final entry in cases.entries) {
        expect(
          () => ChargeAbnormality.fromMap(<String, dynamic>{
            ..._validCharge(),
            entry.key: entry.value,
          }, 'abn-1'),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });

    test('malformed, aliased, duplicate, or oversized assets fail closed', () {
      final oversized = List<Map<String, dynamic>>.generate(
        51,
        (index) => <String, dynamic>{
          'assetType': 'innerCover',
          'assetNumber': index + 1,
        },
      );
      final cases = <String, Object?>{
        'affectedAssets[0]': <Object?>['not-an-object'],
        'assetType': <Map<String, dynamic>>[
          <String, dynamic>{'assetType': 'force_cooler', 'assetNumber': 4},
        ],
        'assetNumber': <Map<String, dynamic>>[
          <String, dynamic>{'assetType': 'furnace', 'assetNumber': '4'},
        ],
        'affectedAssets-extra': <Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'furnace',
            'assetNumber': 4,
            'label': 'Furnace 4',
          },
        ],
        'affectedAssets-duplicate': <Map<String, dynamic>>[
          <String, dynamic>{'assetType': 'furnace', 'assetNumber': 4},
          <String, dynamic>{'assetType': 'furnace', 'assetNumber': 4},
        ],
        'affectedAssets-oversized': oversized,
      };

      for (final entry in cases.entries) {
        final expectedField = switch (entry.key) {
          'affectedAssets[0]' => 'affectedAssets[0]',
          'assetType' => 'assetType',
          'assetNumber' => 'assetNumber',
          _ => 'affectedAssets',
        };
        expect(
          () => ChargeAbnormality.fromMap(<String, dynamic>{
            ..._validCharge(),
            'affectedAssets': entry.value,
          }, 'abn-1'),
          _invalidField(expectedField),
          reason: entry.key,
        );
      }
    });

    test('timeline and re-annealing contradictions fail closed', () {
      final cases = <String, Map<String, dynamic>>{
        'updatedAt': <String, dynamic>{
          ..._validCharge(),
          'updatedAt': '2026-08-10T09:59:59.000Z',
        },
        'reannealingStatus': <String, dynamic>{
          ..._validCharge(),
          'reannealingStatus': 'completed',
        },
        'target-without-completion': <String, dynamic>{
          ..._validCharge(),
          'reannealedToChargeNo': 12002,
        },
        'reannealedToChargeNo': <String, dynamic>{
          ..._validCharge(),
          'reannealingStatus': 'completed',
          'reannealedToChargeNo': 12001,
        },
      };

      for (final entry in cases.entries) {
        final expectedField =
            entry.key == 'target-without-completion'
                ? 'reannealingStatus'
                : entry.key;
        expect(
          () => ChargeAbnormality.fromMap(entry.value, 'abn-1'),
          _invalidField(expectedField),
          reason: entry.key,
        );
      }
    });

    test('charge deletion state is complete or absent', () {
      final deleted = ChargeAbnormality.fromMap(<String, dynamic>{
        ..._validCharge(),
        'isDeleted': true,
        'deletedAt': '2026-08-10T10:45:00.000Z',
        'deletedByUid': 'admin-1',
        'deletedByName': 'Admin One',
        'deleteReason': 'Duplicate record confirmed',
      }, 'abn-1');
      expect(deleted.isDeleted, isTrue);
      expect(deleted.deleteReason, 'Duplicate record confirmed');

      final cases = <String, Map<String, dynamic>>{
        'isDeleted': <String, dynamic>{
          ..._validCharge(),
          'deletedAt': '2026-08-10T10:45:00.000Z',
        },
        'deletedByUid': <String, dynamic>{
          ..._validCharge(),
          'isDeleted': true,
          'deletedAt': '2026-08-10T10:45:00.000Z',
          'deletedByName': 'Admin One',
          'deleteReason': 'Duplicate record confirmed',
        },
        'deletedByName': <String, dynamic>{
          ..._validCharge(),
          'isDeleted': true,
          'deletedAt': '2026-08-10T10:45:00.000Z',
          'deletedByUid': 'admin-1',
          'deleteReason': 'Duplicate record confirmed',
        },
        'deleteReason': <String, dynamic>{
          ..._validCharge(),
          'isDeleted': true,
          'deletedAt': '2026-08-10T10:45:00.000Z',
          'deletedByUid': 'admin-1',
          'deletedByName': 'Admin One',
        },
      };

      for (final entry in cases.entries) {
        expect(
          () => ChargeAbnormality.fromMap(entry.value, 'abn-1'),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });

    test('malformed local asset JSON is not rewritten as empty state', () {
      expect(decodeAffectedAssets(null), isEmpty);
      expect(decodeAffectedAssets('[]'), isEmpty);
      expect(
        () => decodeAffectedAssets('{broken'),
        _invalidField('affectedAssetsJson'),
      );
      expect(
        () => decodeAffectedAssets('{}'),
        _invalidField('affectedAssetsJson'),
      );
      expect(
        () => decodeAffectedAssets('[{"assetType":"furnace"}]'),
        _invalidField('affectedAssets'),
      );
    });

    test('factories delegate and global-pull pages decode before return', () {
      final model =
          File(
            'lib/features/abnormalities/data/abnormality_model.dart',
          ).readAsStringSync();
      final reader =
          File(
            'lib/features/abnormalities/data/remote_abnormality_reader.dart',
          ).readAsStringSync();
      final provider = readDartLibrarySource(
        'lib/features/abnormalities/providers/abnormality_provider.dart',
      );

      expect(model, contains('readRemoteAbnormalityType('));
      expect(model, contains('readRemoteChargeAbnormality('));
      expect(model, isNot(contains('_safeString')));
      expect(model, isNot(contains('_enumByNameOr')));
      expect(reader, contains('must match the document ID'));
      expect(reader, contains('must not contain duplicate asset'));
      expect(provider, contains('AbnormalityType.fromMap(doc.data(), doc.id)'));
      expect(
        provider,
        contains('ChargeAbnormality.fromMap(doc.data(), doc.id)'),
      );
      expect(provider, contains('_validateTypeForSave(type)'));
      expect(provider, contains('_validateAbnormalityForSave(abnormality)'));
      expect(provider, isNot(contains('_ensureTypeDefaults')));
      expect(provider, isNot(contains('_ensureAbnormalityDefaults')));
      expect(provider, isNot(contains('Untitled Abnormality')));
      expect(provider, isNot(contains('Unknown Abnormality')));
      expect(provider, isNot(contains('No reason recorded')));
      expect(provider, isNot(contains('_normalizeTypeFromRemote')));
      expect(provider, isNot(contains('_normalizeAbnormalityFromRemote')));
    });
  });
}

Map<String, dynamic> _validType() => <String, dynamic>{
  'firestoreId': 'type-1',
  'code': 'FURNACE_STUCK',
  'title': 'Furnace movement obstruction',
  'description': 'Furnace travel cannot complete normally.',
  'category': 'equipment',
  'severity': 'high',
  'applicableAssetTypes': <String>['furnace'],
  'suggestsReannealing': false,
  'isActive': true,
  'isDeleted': false,
  'deletedAt': null,
  'deletedByUid': null,
  'deletedByName': null,
  'deleteReason': null,
  'version': 2,
  'createdAt': '2026-08-10T10:00:00.000Z',
  'updatedAt': '2026-08-10T11:00:00.000Z',
  'createdByUid': 'admin-1',
  'createdByName': 'Admin One',
  'lastEditedByUid': 'admin-1',
  'lastEditedByName': 'Admin One',
};

Map<String, dynamic> _validCharge() => <String, dynamic>{
  'firestoreId': 'abn-1',
  'sourceChargeNo': 12001,
  'abnormalityTypeId': 'type-1',
  'abnormalityTypeTitle': 'Furnace movement obstruction',
  'abnormalityTypeCode': 'FURNACE_STUCK',
  'category': 'equipment',
  'severity': 'critical',
  'affectedAssets': <Map<String, dynamic>>[
    <String, dynamic>{'assetType': 'furnace', 'assetNumber': 4},
    <String, dynamic>{'assetType': 'innerCover', 'assetNumber': 19},
  ],
  'component': 'Travel assembly',
  'observedReason': 'Furnace stopped before reaching the parked position.',
  'description': 'Movement was isolated pending mechanical inspection.',
  'possibleRootReasonCategory': 'furnaceRelated',
  'possibleRootReasonNotes': 'Travel wheel alignment requires inspection.',
  'reannealingStatus': 'notApplicable',
  'reannealedToChargeNo': null,
  'loggedAt': '2026-08-10T10:00:00.000Z',
  'updatedAt': '2026-08-10T11:00:00.000Z',
  'loggedByUid': 'operations-1',
  'loggedByName': 'Operations One',
  'updatedByUid': 'admin-1',
  'updatedByName': 'Admin One',
  'linkedTicketFirestoreId': null,
  'linkedExecutionFirestoreId': null,
  'version': 4,
  'isDeleted': false,
  'deletedAt': null,
  'deletedByUid': null,
  'deletedByName': null,
  'deleteReason': null,
};

Matcher _invalidField(String field) => throwsA(
  isA<PersistedDataFormatException>().having(
    (error) => error.fieldName,
    'fieldName',
    field,
  ),
);
