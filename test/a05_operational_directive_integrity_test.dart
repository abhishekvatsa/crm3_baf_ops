import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/data/remote_operational_directive_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A-05 operational directive persisted integrity', () {
    test('a complete governed directive retains exact authority', () {
      final directive = readRemoteOperationalDirective(
        _validDirective(),
        documentId: 'directive-1',
      );

      expect(directive.firestoreId, 'directive-1');
      expect(directive.title, 'Inspect furnace interlocks');
      expect(directive.directedTo, AppRole.operations);
      expect(directive.status, DirectiveStatus.open);
      expect(directive.priority, DirectivePriority.high);
      expect(directive.assetType, AssetType.furnace);
      expect(directive.assetNumber, 4);
      expect(directive.createdByUid, 'admin-1');
      expect(directive.issuedByUid, 'admin-1');
      expect(directive.version, 3);
      expect(directive.isSynced, isTrue);
    });

    test('every authority-bearing field is required', () {
      const requiredFields = <String>[
        'firestoreId',
        'title',
        'description',
        'directedTo',
        'status',
        'priority',
        'createdByUid',
        'issuedByUid',
        'isActive',
        'closedWithoutAcknowledgement',
        'isDeleted',
        'createdAt',
        'updatedAt',
        'version',
      ];

      for (final field in requiredFields) {
        final map = _validDirective()..remove(field);
        expect(
          () => readRemoteOperationalDirective(map, documentId: 'directive-1'),
          _invalidField(field),
          reason: field,
        );
      }
    });

    test('unknown enums and scalar coercions fail closed', () {
      final cases = <String, Object?>{
        'directedTo': 'not-a-role',
        'status': 'pending',
        'priority': 'urgent',
        'assetType': 'oven',
        'assetNumber': '4',
        'isActive': 1,
        'closedWithoutAcknowledgement': 'false',
        'isDeleted': 0,
        'version': '3',
        'component': 17,
        'metadataJson': <String, Object?>{},
      };

      for (final entry in cases.entries) {
        expect(
          () => readRemoteOperationalDirective(<String, dynamic>{
            ..._validDirective(),
            entry.key: entry.value,
          }, documentId: 'directive-1'),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });

    test('malformed present metadata JSON fails closed', () {
      expect(
        () => readRemoteOperationalDirective(<String, dynamic>{
          ..._validDirective(),
          'metadataJson': '{not-json}',
        }, documentId: 'directive-1'),
        _invalidField('metadataJson'),
      );
      expect(
        () => readRemoteOperationalDirective(<String, dynamic>{
          ..._validDirective(),
          'metadataJson': '["not", "an", "object"]',
        }, documentId: 'directive-1'),
        _invalidField('metadataJson'),
      );
    });

    test('identity, asset, and timeline drift fail closed', () {
      final cases = <String, Map<String, dynamic>>{
        'firestoreId': <String, dynamic>{
          ..._validDirective(),
          'firestoreId': 'directive-2',
        },
        'issuedByUid': <String, dynamic>{
          ..._validDirective(),
          'issuedByUid': 'different-user',
        },
        'assetNumber': <String, dynamic>{
          ..._validDirective(),
          'assetNumber': 99,
        },
        'assetType': <String, dynamic>{..._validDirective(), 'assetType': null},
        'updatedAt': <String, dynamic>{
          ..._validDirective(),
          'updatedAt': '2026-08-10T09:59:59.000Z',
        },
        'issuedAt': <String, dynamic>{
          ..._validDirective(),
          'issuedAt': '2026-08-10T11:00:01.000Z',
        },
      };

      for (final entry in cases.entries) {
        expect(
          () => readRemoteOperationalDirective(
            entry.value,
            documentId: 'directive-1',
          ),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });

    test('malformed optional lists fail instead of disappearing', () {
      expect(
        () => readRemoteOperationalDirective(<String, dynamic>{
          ..._validDirective(),
          'hierarchyPath': <Object?>['Furnace', 4],
        }, documentId: 'directive-1'),
        _invalidField('hierarchyPath[1]'),
      );
    });

    test('acknowledged, closed, and deleted lifecycles are exact', () {
      final acknowledged = readRemoteOperationalDirective(<String, dynamic>{
        ..._validDirective(),
        'status': 'acknowledged',
        'acknowledgedByUid': 'operations-1',
        'acknowledgedAt': '2026-08-10T10:30:00.000Z',
      }, documentId: 'directive-1');
      expect(acknowledged.acknowledgedByUid, 'operations-1');

      final closed = readRemoteOperationalDirective(<String, dynamic>{
        ..._validDirective(),
        'status': 'closed',
        'isActive': false,
        'closedByUid': 'admin-1',
        'closedAt': '2026-08-10T10:45:00.000Z',
        'closedWithoutAcknowledgement': true,
      }, documentId: 'directive-1');
      expect(closed.isClosed, isTrue);
      expect(closed.closedWithoutAcknowledgement, isTrue);

      final deleted = readRemoteOperationalDirective(<String, dynamic>{
        ..._validDirective(),
        'isDeleted': true,
        'deletedAt': '2026-08-10T10:50:00.000Z',
        'deletedByUid': 'admin-1',
      }, documentId: 'directive-1');
      expect(deleted.deletedAt, DateTime.utc(2026, 8, 10, 10, 50));
    });

    test('incomplete or contradictory lifecycle state fails closed', () {
      final cases = <String, Map<String, dynamic>>{
        'isActive': <String, dynamic>{..._validDirective(), 'isActive': false},
        'acknowledgedAt': <String, dynamic>{
          ..._validDirective(),
          'status': 'acknowledged',
        },
        'acknowledgedByUid': <String, dynamic>{
          ..._validDirective(),
          'acknowledgedAt': '2026-08-10T10:30:00.000Z',
        },
        'closedAt': <String, dynamic>{
          ..._validDirective(),
          'status': 'closed',
          'isActive': false,
        },
        'closedWithoutAcknowledgement': <String, dynamic>{
          ..._validDirective(),
          'closedWithoutAcknowledgement': true,
        },
        'deletedAt': <String, dynamic>{..._validDirective(), 'isDeleted': true},
        'deletedByUid': <String, dynamic>{
          ..._validDirective(),
          'deletedByUid': 'admin-1',
        },
        'acknowledgedByName': <String, dynamic>{
          ..._validDirective(),
          'acknowledgedByName': 'Operations One',
        },
        'closedByName': <String, dynamic>{
          ..._validDirective(),
          'closedByName': 'Admin One',
        },
      };

      for (final entry in cases.entries) {
        expect(
          () => readRemoteOperationalDirective(
            entry.value,
            documentId: 'directive-1',
          ),
          _invalidField(entry.key),
          reason: entry.key,
        );
      }
    });

    test('provider delegates reads and persists document identity', () {
      final source = <String>[
        'lib/features/directives/providers/operational_directive_provider.dart',
        'lib/features/directives/providers/operational_directive_provider.local.dart',
        'lib/features/directives/providers/operational_directive_provider.remote.dart',
        'lib/features/directives/data/operational_directive_model.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final mapper = source.substring(
        source.indexOf('OperationalDirective _mapDirective'),
      );

      expect(mapper, contains('readRemoteOperationalDirective('));
      expect(source, contains("'firestoreId': firestoreId"));
      expect(source, contains('return d.toMap();'));
      expect(source, isNot(contains('_normalizeDirectiveFromRemote')));
      expect(source, isNot(contains('_enumByNameOr')));
      expect(source, isNot(contains('_directiveIntOrNull')));
      expect(mapper, isNot(contains("data['status'] ??")));
      expect(mapper, isNot(contains("data['version'] ??")));
    });
  });
}

Map<String, dynamic> _validDirective() => <String, dynamic>{
  'firestoreId': 'directive-1',
  'title': 'Inspect furnace interlocks',
  'description': 'Verify permissives and record the shift observation.',
  'assetType': 'furnace',
  'assetNumber': 4,
  'component': 'Interlock panel',
  'subsystem': 'Safety circuit',
  'tag': 'F04-ILK',
  'hierarchyPath': <String>['Furnace 4', 'Safety circuit'],
  'directedTo': 'operations',
  'status': 'open',
  'priority': 'high',
  'createdByUid': 'admin-1',
  'createdByName': 'Admin One',
  'issuedByUid': 'admin-1',
  'issuedByName': 'Admin One',
  'issuedAt': '2026-08-10T10:00:00.000Z',
  'isActive': true,
  'acknowledgedByUid': null,
  'acknowledgedByName': null,
  'acknowledgedAt': null,
  'closedByUid': null,
  'closedByName': null,
  'closedAt': null,
  'closedWithoutAcknowledgement': false,
  'remarks': null,
  'linkedMaintenanceFirestoreId': null,
  'linkedExecutionFirestoreId': null,
  'metadataJson': null,
  'isDeleted': false,
  'deletedAt': null,
  'deletedByUid': null,
  'deletedByName': null,
  'deleteReason': null,
  'createdAt': '2026-08-10T10:00:00.000Z',
  'updatedAt': '2026-08-10T11:00:00.000Z',
  'version': 3,
};

Matcher _invalidField(String field) => throwsA(
  isA<PersistedDataFormatException>().having(
    (error) => error.fieldName,
    'fieldName',
    field,
  ),
);
