import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/audit/providers/audit_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/closed_tickets_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_ticket_detail_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/services/closed_ticket_history_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _actor() => AppUser(
  uid: 'reviewer',
  name: 'Reviewer',
  email: 'reviewer@example.test',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026, 9, 1),
);

MaintenanceRecord _ticket(String id) => MaintenanceRecord()
  ..firestoreId = id
  ..version = 3
  ..isSynced = true
  ..assetType = AssetType.base
  ..assetNumber = 101
  ..maintenanceType = MaintenanceType.breakdown
  ..routedTo = RoutedTo.mechanical
  ..description = 'Retained observation $id'
  ..status = TicketStatus.resolved
  ..isResolved = true
  ..startDate = DateTime.now().subtract(const Duration(hours: 1))
  ..createdAt = DateTime.now().subtract(const Duration(hours: 1))
  ..updatedAt = DateTime.now()
  ..endDate = DateTime.now()
  ..closedByUid = 'reviewer'
  ..closedByName = 'Reviewer'
  ..actionsJson = '[]'
  ..resolutionHistoryJson = '[]';

class _History extends Fake implements ClosedTicketHistoryService {
  _History(this.records);
  final List<MaintenanceRecord> records;
  @override
  Future<int> count({required AppUser? actor}) async => records.length;
  @override
  Future<ClosedTicketPage> loadPage({
    required AppUser? actor,
    required int limit,
    required int offset,
    ClosedTicketPageCursor? cursor,
  }) async => ClosedTicketPage(records: records);
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    List<MaintenanceRecord>? records,
  }) async {
    await tester.binding.setSurfaceSize(const Size(700, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => Stream.value(_actor())),
          maintenanceTicketCorrectionAuditProvider.overrideWith(
            (ref, id) async => [],
          ),
          if (records != null)
            closedTicketHistoryServiceProvider.overrideWithValue(
              _History(records),
            ),
          maintenanceClassDefinitionsProvider.overrideWith(
            (ref) => Stream.value(
              const DecodedSnapshotBatch<MaintenanceClassDefinition>(
                records: [],
                rejectedDocumentIds: [],
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: BafAppTheme.light, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final kind in ['missing', 'malformed', 'contradictory']) {
    testWidgets(
      '$kind closure detail preserves evidence and withholds ordinary actions/export',
      (tester) async {
        final ticket = _ticket(kind);
        if (kind == 'contradictory') {
          ticket.administrativeClosure = const IssueAdministrativeClosure(
            disposition: IssueAdministrativeClosureDisposition.stillRelevant,
            reason: 'Retained unresolved concern',
          );
        } else {
          ticket.status = TicketStatus.closedWithoutResolution;
          if (kind == 'malformed') ticket.metadataJson = '{unreadable';
        }
        final originalMetadata = ticket.metadataJson;
        var corrections = 0;
        await pump(
          tester,
          MaintenanceTicketDetailScreen(
            ticket: ticket,
            onCorrect: () => corrections++,
          ),
        );
        expect(
          find.textContaining('Closure evidence needs review.'),
          findsOneWidget,
        );
        expect(find.text('Closure needs review'), findsOneWidget);
        expect(find.text('Server verified'), findsNothing);
        expect(find.text('Technically resolved'), findsNothing);
        expect(find.text(ticket.description), findsOneWidget);
        for (final key in ['ticket-detail-pdf', 'ticket-detail-correct']) {
          expect(
            tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed,
            isNull,
          );
        }
        expect(find.byTooltip('Start linked new work'), findsNothing);
        expect(corrections, 0);
        expect(ticket.metadataJson, originalMetadata);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('legacy resolved detail with absent closure remains actionable', (
    tester,
  ) async {
    final ticket = _ticket('verified');
    await pump(
      tester,
      MaintenanceTicketDetailScreen(ticket: ticket, onCorrect: () {}),
    );
    expect(find.textContaining('Closure evidence needs review'), findsNothing);
    expect(find.text('Server verified'), findsOneWidget);
    for (final key in ['ticket-detail-pdf', 'ticket-detail-correct']) {
      expect(
        tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed,
        isNotNull,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closed history retains bad row and verified neighbours with distinct actions',
    (tester) async {
      final bad = _ticket('bad')..status = TicketStatus.closedWithoutResolution;
      final good = _ticket('good');
      await pump(tester, const ClosedTicketsScreen(), records: [bad, good]);
      final card = find.byKey(const ValueKey('closed-ticket-unreadable-bad'));
      expect(card, findsOneWidget);
      expect(find.text(bad.description), findsOneWidget);
      expect(find.text(good.description), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byType(TextButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Reopen Ticket')),
        findsNothing,
      );
      expect(find.text('Reopen Ticket'), findsOneWidget);
      await tester.tap(find.text('View retained record'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Closure evidence needs review.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('ticket-detail-pdf')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
