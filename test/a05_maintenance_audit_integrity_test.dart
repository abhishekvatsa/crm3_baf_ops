import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/admin/utils/admin_ticket_helpers.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/resolve_form.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A-05 maintenance and audit integrity', () {
    test(
      'required persisted timestamps reject absent and malformed values',
      () {
        final expected = DateTime.utc(2026, 8, 5, 6, 30);

        expect(
          readRequiredPersistedDateTime(
            expected.toIso8601String(),
            field: 'timestamp',
            source: 'audit_logs/a-1',
          ),
          expected,
        );
        final epochDecoded = readRequiredPersistedDateTime(
          expected.millisecondsSinceEpoch,
          field: 'timestamp',
          source: 'audit_logs/a-1',
          allowEpochMilliseconds: true,
        );
        expect(epochDecoded.isAtSameMomentAs(expected), isTrue);
        expect(
          () => readRequiredPersistedDateTime(
            null,
            field: 'timestamp',
            source: 'audit_logs/a-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
        expect(
          () => readRequiredPersistedDateTime(
            'not-a-date',
            field: 'timestamp',
            source: 'audit_logs/a-1',
          ),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );

    test(
      'serialized timestamp maps require one complete integer field pair',
      () {
        final decoded = readRequiredPersistedDateTime(
          const <String, Object>{
            '_seconds': 1785911400,
            '_nanoseconds': 123456000,
          },
          field: 'deployedAt',
          source: 'callable response',
          allowSerializedTimestampMap: true,
        );

        expect(decoded, DateTime.utc(2026, 8, 5, 6, 30, 0, 123, 456));
        expect(
          readRequiredPersistedDateTime(
            const <String, Object>{'seconds': -62135596800, 'nanoseconds': 0},
            field: 'deployedAt',
            source: 'callable response',
            allowSerializedTimestampMap: true,
          ),
          DateTime.utc(1),
        );
        expect(
          readRequiredPersistedDateTime(
            const <String, Object>{
              'seconds': 253402300799,
              'nanoseconds': 999999999,
            },
            field: 'deployedAt',
            source: 'callable response',
            allowSerializedTimestampMap: true,
          ),
          DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999),
        );
        for (final malformed in <Object>[
          const <String, Object>{'_seconds': 1785911400},
          const <String, Object>{
            '_seconds': 1785911400,
            '_nanoseconds': 0,
            'seconds': 1785911400,
            'nanoseconds': 0,
          },
          const <String, Object>{'seconds': 1785911400.0, 'nanoseconds': 0},
          const <String, Object>{
            'seconds': 1785911400,
            'nanoseconds': 1000000000,
          },
          const <String, Object>{'seconds': -62135596801, 'nanoseconds': 0},
          const <String, Object>{'seconds': 253402300800, 'nanoseconds': 0},
        ]) {
          expect(
            () => readRequiredPersistedDateTime(
              malformed,
              field: 'deployedAt',
              source: 'callable response',
              allowSerializedTimestampMap: true,
            ),
            throwsA(isA<PersistedDataFormatException>()),
          );
        }
      },
    );

    test('resolution history preserves valid serialized entries', () {
      final resolvedAt = DateTime.utc(2026, 8, 5, 5, 45);
      final encoded = jsonEncode([
        {
          'resolvedByUid': 'approved-user',
          'resolvedByName': 'Approved User',
          'resolvedAt': resolvedAt.toIso8601String(),
          'actionsJson': '[]',
          'remarks': 'Checked and restored',
          'downtimeHours': 1.25,
          'teamsInvolved': ['operations'],
          'legacyExtension': {'retained': true},
        },
      ]);
      final payload = readValidatedResolutionHistoryPayload(
        encoded,
        source: 'maintenance/ticket-1',
      );
      final decoded = payload.entries;

      expect(decoded, hasLength(1));
      expect(decoded.single.resolvedAt, resolvedAt);
      expect(decoded.single.remarks, 'Checked and restored');
      expect(decoded.single.teamsInvolved, ['operations']);
      expect(payload.rows.single['legacyExtension'], {'retained': true});

      payload.rows.add(ResolutionHistory(resolvedAt: resolvedAt).toMap());
      final rewritten = jsonDecode(jsonEncode(payload.rows)) as List<dynamic>;
      expect((rewritten.first as Map<String, dynamic>)['legacyExtension'], {
        'retained': true,
      });
    });

    test('malformed or incomplete resolution history fails closed', () {
      expect(readEncodedResolutionHistoryPayload(null), '[]');
      for (final wrongType in <dynamic>[
        <dynamic>[],
        <String, dynamic>{},
        3,
        true,
      ]) {
        expect(
          () => readEncodedResolutionHistoryPayload(
            wrongType,
            source: 'maintenance/ticket-2',
          ),
          throwsA(isA<PersistedDataFormatException>()),
          reason: wrongType.runtimeType.toString(),
        );
      }
      for (final raw in <String>[
        '{not-json',
        '{}',
        '["not-an-object"]',
        '[{"resolvedByUid":"approved-user"}]',
        '[{"resolvedAt":"not-a-date"}]',
        '[{"resolvedAt":"2026-08-05T05:45:00Z","downtimeHours":"one"}]',
        '[{"resolvedAt":"2026-08-05T05:45:00Z","teamsInvolved":[3]}]',
      ]) {
        expect(
          () =>
              decodeResolutionHistoryJson(raw, source: 'maintenance/ticket-2'),
          throwsA(isA<FormatException>()),
          reason: raw,
        );
      }
    });

    test(
      'model exposes corruption without inventing or discarding history',
      () {
        final record =
            MaintenanceRecord()
              ..firestoreId = 'ticket-3'
              ..resolutionHistoryJson = '{not-json';

        expect(() => record.resolutionHistory, throwsA(isA<FormatException>()));
        expect(record.resolutionHistoryReadResult.isValid, isFalse);
        expect(record.resolutionHistoryReadResult.entries, isEmpty);
        expect(ResolutionHistory().resolvedAt, isNull);
      },
    );

    test('admin reopen preserves extensions and requires closure time', () {
      final resolvedAt = DateTime.utc(2026, 8, 5, 6);
      final source =
          MaintenanceRecord()
            ..firestoreId = 'ticket-admin'
            ..assetType = AssetType.base
            ..assetNumber = 2
            ..maintenanceType = MaintenanceType.breakdown
            ..description = 'Resolved ticket'
            ..routedTo = RoutedTo.operations
            ..status = TicketStatus.resolved
            ..isResolved = true
            ..startDate = resolvedAt.subtract(const Duration(hours: 2))
            ..endDate = resolvedAt
            ..createdAt = resolvedAt.subtract(const Duration(days: 1))
            ..updatedAt = resolvedAt
            ..resolutionHistoryJson = jsonEncode([
              {
                'resolvedAt':
                    resolvedAt
                        .subtract(const Duration(days: 1))
                        .toIso8601String(),
                'legacyExtension': {'retained': true},
              },
            ]);

      final reopened = copyTicketForAdminEdit(
        source: source,
        assetType: source.assetType,
        assetNumber: source.assetNumber,
        description: source.description,
        routedTo: source.routedTo,
        maintenanceType: source.maintenanceType,
        status: TicketStatus.open,
        component: source.component,
        tag: source.tag,
        remarks: 'Reopened for inspection',
        editedByUid: 'admin-user',
        editedByName: 'Admin User',
      );
      final rows = jsonDecode(reopened.resolutionHistoryJson) as List<dynamic>;
      expect(rows, hasLength(2));
      expect((rows.first as Map<String, dynamic>)['legacyExtension'], {
        'retained': true,
      });

      source.endDate = null;
      expect(
        () => copyTicketForAdminEdit(
          source: source,
          assetType: source.assetType,
          assetNumber: source.assetNumber,
          description: source.description,
          routedTo: source.routedTo,
          maintenanceType: source.maintenanceType,
          status: TicketStatus.open,
          component: source.component,
          tag: source.tag,
          remarks: source.remarks,
          editedByUid: 'admin-user',
          editedByName: 'Admin User',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('admin edits preserve open actions and reject malformed evidence', () {
      final now = DateTime.utc(2026, 8, 5, 7, 30);
      final source =
          MaintenanceRecord()
            ..firestoreId = 'ticket-admin-open'
            ..assetType = AssetType.base
            ..assetNumber = 3
            ..maintenanceType = MaintenanceType.inspection
            ..description = 'Inspection in progress'
            ..routedTo = RoutedTo.operations
            ..status = TicketStatus.open
            ..isResolved = false
            ..startDate = now.subtract(const Duration(hours: 1))
            ..createdAt = now.subtract(const Duration(days: 1))
            ..updatedAt = now
            ..actions = <ComponentAction>[
              ComponentAction(
                asset: 'Base 3',
                component: 'Cooling pump',
                actionType: ActionType.inspection,
                issue: 'Temperature trend under review',
                createdAt: now,
              ),
            ];

      final edited = copyTicketForAdminEdit(
        source: source,
        assetType: source.assetType,
        assetNumber: source.assetNumber,
        description: source.description,
        routedTo: source.routedTo,
        maintenanceType: source.maintenanceType,
        status: TicketStatus.open,
        component: source.component,
        tag: source.tag,
        remarks: 'Continue observation',
        editedByUid: 'admin-user',
        editedByName: 'Admin User',
      );

      expect(edited.actionsJson, source.actionsJson);
      expect(edited.actions, hasLength(1));
      expect(edited.actions.single.component, 'Cooling pump');

      source.actionsJson = '[{"asset":"Base 3"}]';
      expect(
        () => copyTicketForAdminEdit(
          source: source,
          assetType: source.assetType,
          assetNumber: source.assetNumber,
          description: source.description,
          routedTo: source.routedTo,
          maintenanceType: source.maintenanceType,
          status: TicketStatus.open,
          component: source.component,
          tag: source.tag,
          remarks: source.remarks,
          editedByUid: 'admin-user',
          editedByName: 'Admin User',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );

      source.actionsJson = '[]';
      source.resolutionHistoryJson = '{not-json';
      expect(
        () => copyTicketForAdminEdit(
          source: source,
          assetType: source.assetType,
          assetNumber: source.assetNumber,
          description: source.description,
          routedTo: source.routedTo,
          maintenanceType: source.maintenanceType,
          status: TicketStatus.open,
          component: source.component,
          tag: source.tag,
          remarks: source.remarks,
          editedByUid: 'admin-user',
          editedByName: 'Admin User',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('remote audit records require their persisted authority fields', () {
      final timestamp = DateTime.utc(2026, 8, 5, 7);
      final valid = <String, dynamic>{
        'entityType': 'maintenance',
        'entityId': 'ticket-4',
        'action': 'resolve',
        'performedByUid': 'approved-user',
        'performedByName': 'Approved User',
        'timestamp': timestamp.toIso8601String(),
        'reason': null,
        'reasonNotes': null,
        'summary': 'Resolved after inspection',
        'severity': 'low',
        'beforeJson': '{"isResolved":false}',
        'afterJson': '{"isResolved":true}',
      };

      final decoded = decodePersistedAuditEvent(valid, documentId: 'audit-1');
      expect(decoded.entityType, 'maintenance');
      expect(decoded.action, AuditAction.resolve);
      expect(decoded.timestamp, timestamp);
      expect(decoded.before, {'isResolved': false});
      expect(decoded.after, {'isResolved': true});
      expect(decoded.isSynced, isTrue);

      for (final malformed in <Map<String, dynamic>>[
        {...valid}..remove('timestamp'),
        {...valid, 'entityType': ''},
        {...valid, 'action': 'invented'},
        {...valid, 'performedByUid': 3},
        {...valid, 'severity': null},
        {...valid, 'beforeJson': '[]'},
      ]) {
        expect(
          () =>
              decodePersistedAuditEvent(malformed, documentId: 'audit-invalid'),
          throwsA(isA<PersistedDataFormatException>()),
          reason: malformed.toString(),
        );
      }
    });

    test('local audit snapshots do not erase malformed state', () {
      final event = AuditEvent(
        entityType: 'maintenance',
        entityId: 'ticket-5',
        action: AuditAction.update,
        performedByUid: 'approved-user',
      )..beforeJson = '{not-json';

      expect(() => event.before, throwsA(isA<PersistedDataFormatException>()));
      expect(
        () => event.after = <String, dynamic>{'unsupported': Object()},
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    testWidgets('resolve UI exposes corruption and blocks the command', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final record =
          MaintenanceRecord()
            ..firestoreId = 'ticket-ui'
            ..assetType = AssetType.base
            ..assetNumber = 1
            ..maintenanceType = MaintenanceType.breakdown
            ..description = 'Malformed history witness'
            ..routedTo = RoutedTo.operations
            ..startDate = now.subtract(const Duration(hours: 1))
            ..createdAt = now.subtract(const Duration(hours: 1))
            ..updatedAt = now
            ..resolutionHistoryJson = '{not-json';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(null),
            ),
          ],
          child: MaterialApp(home: ResolveForm(ticket: record)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resolution history needs repair'), findsOneWidget);
      expect(
        find.text('No history entries were discarded or replaced.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Mark as Resolved'));
      await tester.pump();

      expect(
        find.text('Cannot resolve: previous resolution history needs repair.'),
        findsOneWidget,
      );
      expect(record.isResolved, isFalse);
    });

    test('source paths reject silent replacement and surface the UI state', () {
      final maintenanceProvider =
          File(
            'lib/features/maintenance/providers/maintenance_provider.dart',
          ).readAsStringSync();
      final auditRepository =
          File(
            'lib/features/audit/repositories/audit_repository.dart',
          ).readAsStringSync();
      final auditModel =
          File(
            'lib/features/audit/models/audit_event_model.dart',
          ).readAsStringSync();
      final authProvider =
          File(
            'lib/features/auth/providers/auth_provider.dart',
          ).readAsStringSync();
      final resolveForm =
          File(
            'lib/features/maintenance/presentation/resolve_form.dart',
          ).readAsStringSync();
      final adminHelpers =
          File(
            'lib/features/admin/utils/admin_ticket_helpers.dart',
          ).readAsStringSync();
      final adminBrowser =
          File(
            'lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart',
          ).readAsStringSync();
      final liveRemoteSync =
          File(
            'lib/core/services/live_remote_sync_service.dart',
          ).readAsStringSync();
      final remoteMaintenanceReader =
          File(
            'lib/features/maintenance/data/remote_maintenance_reader.dart',
          ).readAsStringSync();
      final ticketSync =
          File(
            'lib/core/services/sync_service.tickets_templates.dart',
          ).readAsStringSync();

      expect(maintenanceProvider, isNot(contains('catch (_) {}')));
      expect(
        maintenanceProvider,
        contains('readValidatedResolutionHistoryPayload('),
      );
      expect(maintenanceProvider, contains('historyPayload.rows.add('));
      expect(auditRepository, contains('readRequiredPersistedDateTime('));
      expect(auditRepository, isNot(contains('return DateTime.now();')));
      expect(auditRepository, isNot(contains('_safeDecode')));
      expect(auditRepository, contains('on PersistedDataFormatException'));
      expect(auditModel, isNot(contains('catch (_)')));
      expect(auditModel, contains('readOptionalJsonObject('));
      expect(authProvider, isNot(contains('catch (_) {}')));
      expect(resolveForm, contains('Resolution history needs repair'));
      expect(
        resolveForm,
        contains('No history entries were discarded or replaced.'),
      );
      expect(
        maintenanceProvider,
        contains("'actionsJson': record.actionsJson,"),
      );
      expect(
        maintenanceProvider,
        contains("'resolutionHistoryJson': record.resolutionHistoryJson,"),
      );
      expect(
        maintenanceProvider,
        contains('_requireValidMaintenanceEvidence(_mapTicket(current));'),
      );
      expect(
        adminHelpers,
        contains(
          'wasResolved && !willBeResolved ? \'[]\' : source.actionsJson',
        ),
      );
      expect(
        adminBrowser,
        contains('Saved evidence needs repair before editing'),
      );
      expect(liveRemoteSync, isNot(contains("d['actionsJson']?.toString()")));
      expect(
        liveRemoteSync,
        isNot(contains("d['resolutionHistoryJson']?.toString()")),
      );
      expect(liveRemoteSync, contains('readRemoteMaintenanceRecord('));
      expect(
        remoteMaintenanceReader,
        contains('ComponentAction.readEncodedPayload('),
      );
      expect(
        remoteMaintenanceReader,
        contains('readEncodedResolutionHistoryPayload('),
      );
      final applyStart = liveRemoteSync.indexOf(
        'Future<void> _applyMaintenanceDoc(',
      );
      final errorBoundary = liveRemoteSync.indexOf('try {', applyStart);
      final mapCall = liveRemoteSync.indexOf(
        'final remote = _mapTicket(doc, data);',
        applyStart,
      );
      expect(applyStart, greaterThanOrEqualTo(0));
      expect(errorBoundary, greaterThan(applyStart));
      expect(mapCall, greaterThan(errorBoundary));
      expect(
        ticketSync,
        contains('_maintenanceEvidenceIntegrityError(record)'),
      );
      expect(
        ticketSync,
        contains('Saved action evidence needs repair before synchronization.'),
      );
      expect(
        ticketSync,
        contains(
          'Saved resolution history needs repair before synchronization.',
        ),
      );
    });
  });
}
