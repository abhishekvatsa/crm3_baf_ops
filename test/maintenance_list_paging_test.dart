import 'dart:async';

import 'package:crm3_baf_ops/core/providers/refresh_providers.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/incremental_list_footer.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/closed_tickets_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/ticket_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/services/closed_ticket_history_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _actor({AppRole role = AppRole.si, bool approved = true}) => AppUser(
  uid: 'list-reader',
  name: 'List reader',
  email: 'reader@example.invalid',
  roles: [role],
  isApproved: approved,
  createdAt: DateTime.utc(2026, 9, 1),
);

MaintenanceRecord _ticket(int index, {bool closed = false}) {
  final at = DateTime.utc(2026, 9, 1).subtract(Duration(minutes: index));
  final id =
      '${closed ? 'closed' : 'open'}-${index.toString().padLeft(3, '0')}';
  return MaintenanceRecord()
    ..firestoreId = id
    ..version = 1
    ..isSynced = true
    ..assetType = AssetType.furnace
    ..assetNumber = index + 1
    ..maintenanceType = MaintenanceType.breakdown
    ..routedTo = RoutedTo.mechanical
    ..description = '${index.isEven ? 'Seal' : 'Noise'} observation $id'
    ..loggedByUid = 'list-reader'
    ..loggedByName = 'List reader'
    ..status = closed ? TicketStatus.resolved : TicketStatus.open
    ..isResolved = closed
    ..startDate = at
    ..createdAt = at
    ..updatedAt = at.add(const Duration(minutes: 1))
    ..endDate = closed ? at.add(const Duration(minutes: 1)) : null;
}

class _History extends Fake implements ClosedTicketHistoryService {
  _History(this.records, {this.reportedTotal});

  final List<MaintenanceRecord> records;
  final int? reportedTotal;
  final List<({int limit, int offset})> reads = [];
  Completer<void>? nextPageGate;

  @override
  Future<int> count({required AppUser? actor}) async =>
      reportedTotal ?? records.length;

  @override
  Future<ClosedTicketPage> loadPage({
    required AppUser? actor,
    required int limit,
    required int offset,
    ClosedTicketPageCursor? cursor,
  }) async {
    reads.add((limit: limit, offset: offset));
    if (offset > 0) await nextPageGate?.future;
    return ClosedTicketPage(records: records.skip(offset).take(limit).toList());
  }
}

Future<void> _pumpIssues(
  WidgetTester tester, {
  required List<MaintenanceRecord> open,
  required List<MaintenanceRecord> all,
  AppUser? actor,
  void Function()? onAllRead,
  MaintenanceFeedDiagnostics? diagnostics,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(actor ?? _actor()),
        ),
        openTicketsProvider.overrideWith((ref) => Stream.value(open)),
        allTicketsProvider.overrideWith((ref) {
          onAllRead?.call();
          return Stream.value(all);
        }),
        if (diagnostics != null)
          maintenanceFeedDiagnosticsProvider(
            'all',
          ).overrideWith((ref) => diagnostics),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: const Scaffold(body: TicketScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _footer(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byType(IncrementalListFooter),
    650,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

Future<void> _top(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String status) async {
  await _top(tester);
  await tester.tap(find.byKey(ValueKey('issues-status-$status')));
  await tester.pumpAndSettle();
}

Future<void> _pumpHistory(WidgetTester tester, _History history) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(_actor())),
        closedTicketHistoryServiceProvider.overrideWithValue(history),
        maintenanceClassDefinitionsProvider.overrideWith(
          (ref) => Stream.value(
            const DecodedSnapshotBatch<MaintenanceClassDefinition>(
              records: [],
              rejectedDocumentIds: [],
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: const ClosedTicketsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'open default uses full count but only 15 rows until explicit Show more',
    (tester) async {
      final open = List.generate(32, _ticket);
      var allReads = 0;
      await _pumpIssues(
        tester,
        open: open,
        all: [...open, _ticket(33, closed: true)],
        onAllRead: () => allReads++,
      );
      expect(find.text('Open issues'), findsOneWidget);
      expect(find.text('32 open'), findsOneWidget);
      expect(allReads, 0);
      await _footer(tester);
      expect(find.text('Showing 15 of 32'), findsOneWidget);
      expect(find.byKey(const ValueKey('issue-row-open-014')), findsOneWidget);
      expect(find.byKey(const ValueKey('issue-row-open-015')), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.text('Showing 15 of 32'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await _footer(tester);
      expect(find.text('Showing 30 of 32'), findsOneWidget);
      expect(find.byKey(const ValueKey('issue-row-open-029')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await _footer(tester);
      expect(find.text('Showing 32 of 32'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('business-list-show-more')),
        findsNothing,
      );
      expect(open.length, 32);
      expect(allReads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'status and search reset the limit and search beyond the first page',
    (tester) async {
      final open = List.generate(34, _ticket);
      final closed = List.generate(33, (i) => _ticket(i, closed: true));
      await _pumpIssues(tester, open: open, all: [...closed, ...open]);
      await _footer(tester);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await _select(tester, 'all');
      await _footer(tester);
      expect(find.text('Showing 15 of 67'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await _select(tester, 'closed');
      await _footer(tester);
      expect(find.text('Showing 15 of 33'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await _top(tester);
      await tester.enterText(
        find.byKey(const ValueKey('issues-search')),
        'Seal',
      );
      await tester.pumpAndSettle();
      await _footer(tester);
      expect(find.text('Showing 15 of 17'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await _footer(tester);
      expect(find.text('Showing 17 of 17'), findsOneWidget);
      await _top(tester);
      await tester.enterText(
        find.byKey(const ValueKey('issues-search')),
        'closed-032',
      );
      await tester.pumpAndSettle();
      expect(find.text(closed.last.description), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('issues-search')), '');
      await tester.pumpAndSettle();
      await _footer(tester);
      expect(find.text('Showing 15 of 33'), findsOneWidget);
      await _select(tester, 'open');
      await _footer(tester);
      expect(find.text('Showing 15 of 34'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search survives loading another status feed and tied dates stay stable',
    (tester) async {
      final open = List.generate(17, _ticket);
      for (final ticket in open) {
        ticket.createdAt = DateTime.utc(2026, 9, 1);
      }
      final originalIds = open.reversed
          .map((ticket) => ticket.firestoreId)
          .toList();
      final source = open.reversed.toList();
      await _pumpIssues(tester, open: source, all: source);
      expect(find.text(open.first.description), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('issues-search')),
        'Noise',
      );
      await _select(tester, 'all');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('issues-search')))
            .controller!
            .text,
        'Noise',
      );
      await _footer(tester);
      expect(find.text('Showing 8 of 8'), findsOneWidget);
      expect(source.map((ticket) => ticket.firestoreId), originalIds);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closed rows retain unreadable evidence and never expose open actions',
    (tester) async {
      final closed = _ticket(0, closed: true);
      final bad = _ticket(1, closed: true)
        ..status = TicketStatus.closedWithoutResolution;
      await _pumpIssues(
        tester,
        open: [],
        all: [closed, bad],
        diagnostics: const MaintenanceFeedDiagnostics(
          malformedDocumentIds: {'withheld-record'},
        ),
      );
      await _select(tester, 'closed');
      expect(find.text('Closed issues'), findsOneWidget);
      expect(
        find.byKey(const Key('maintenance-incomplete-feed-notice')),
        findsOneWidget,
      );
      await _footer(tester);
      expect(find.text('Closure evidence needs review'), findsOneWidget);
      for (final label in [
        'Acknowledge',
        'Complete accountable lane',
        'Resolve',
        'Close without resolution',
        'Defer / request Operations',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.byTooltip('Issue record and actions'), findsNothing);
      expect(find.text('View record'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All preserves open role scope and the approved history boundary',
    (tester) async {
      final hidden = _ticket(0)..loggedByUid = 'another-operator';
      final own = _ticket(1);
      final historical = _ticket(2, closed: true)
        ..loggedByUid = 'another-operator';
      await _pumpIssues(
        tester,
        actor: _actor(role: AppRole.operations),
        open: [hidden, own],
        all: [hidden, own, historical],
      );
      expect(find.text(hidden.description), findsNothing);
      expect(find.text(own.description), findsOneWidget);
      await _select(tester, 'all');
      await _footer(tester);
      expect(find.text('Showing 2 of 2'), findsOneWidget);
      expect(find.text(hidden.description), findsNothing);
      expect(find.text(historical.description), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      var allReads = 0;
      await _pumpIssues(
        tester,
        actor: _actor(approved: false),
        open: [own],
        all: [historical],
        onAllRead: () => allReads++,
      );
      expect(find.byKey(const ValueKey('issues-status-all')), findsNothing);
      expect(allReads, 0);
      expect(find.text(historical.description), findsNothing);
    },
  );

  testWidgets(
    'history loads 15 only on explicit Show more and refresh resets the page',
    (tester) async {
      final history = _History(
        List.generate(32, (i) => _ticket(i, closed: true)),
      );
      await _pumpHistory(tester, history);
      expect(history.reads, [(limit: 15, offset: 0)]);
      await _footer(tester);
      expect(find.text('Showing 15 of 32'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(history.reads.length, 1);
      history.nextPageGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await tester.pump();
      expect(history.reads.last, (limit: 15, offset: 15));
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('business-list-show-more')),
            )
            .onPressed,
        isNull,
      );
      history.nextPageGate!.complete();
      await tester.pumpAndSettle();
      await _footer(tester);
      expect(find.text('Showing 30 of 32'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await _footer(tester);
      expect(history.reads.last, (limit: 15, offset: 30));
      expect(find.text('Showing 32 of 32'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('business-list-show-more')),
        findsNothing,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ClosedTicketsScreen)),
      );
      container.read(refreshClosedTicketsProvider.notifier).state++;
      await tester.pumpAndSettle();
      await _footer(tester);
      expect(history.reads.last, (limit: 15, offset: 0));
      expect(find.text('Showing 15 of 32'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short history page does not pretend the full source is loaded', (
    tester,
  ) async {
    final history = _History([_ticket(0, closed: true)], reportedTotal: 20);
    await _pumpHistory(tester, history);
    expect(find.text('History incomplete'), findsOneWidget);
    await _footer(tester);
    expect(find.text('Showing 1 of 20'), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
    await tester.pumpAndSettle();
    expect(history.reads, [(limit: 15, offset: 0), (limit: 15, offset: 0)]);
    expect(tester.takeException(), isNull);
  });
}
