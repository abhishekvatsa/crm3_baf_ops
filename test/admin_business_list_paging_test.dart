import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/incremental_list_footer.dart';
import 'package:crm3_baf_ops/features/admin/presentation/admin_data_browser/admin_directives_browser.dart';
import 'package:crm3_baf_ops/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart';
import 'package:crm3_baf_ops/features/admin/providers/admin_stream_providers.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OperationalDirective _directive(int i, {bool closed = false}) {
  final at = DateTime.utc(2026, 9, 1).subtract(Duration(minutes: i));
  return OperationalDirective()
    ..firestoreId =
        '${closed ? 'closed' : 'open'}-${i.toString().padLeft(3, '0')}'
    ..title = '${i.isEven ? 'Seal' : 'Noise'} instruction $i'
    ..description = 'Retained instruction evidence'
    ..directedTo = AppRole.operations
    ..createdByUid = 'issuer'
    ..createdByName = 'Issuer'
    ..createdAt = at
    ..updatedAt = at
    ..status = closed ? DirectiveStatus.closed : DirectiveStatus.acknowledged;
}

MaintenanceRecord _ticket(int i, {bool closed = false}) {
  final at = DateTime.utc(2026, 9, 1).subtract(Duration(minutes: i));
  return MaintenanceRecord()
    ..firestoreId =
        '${closed ? 'closed' : 'open'}-${i.toString().padLeft(3, '0')}'
    ..description = '${i.isEven ? 'Seal' : 'Noise'} observation $i'
    ..assetType = AssetType.furnace
    ..assetNumber = i + 1
    ..maintenanceType = MaintenanceType.breakdown
    ..routedTo = RoutedTo.mechanical
    ..status = closed ? TicketStatus.resolved : TicketStatus.inProgress
    ..isResolved = closed
    ..startDate = at
    ..endDate = closed ? at : null
    ..createdAt = at
    ..updatedAt = at;
}

Future<void> _pump(
  WidgetTester tester, {
  required bool directives,
  List<MaintenanceRecord>? tickets,
  List<OperationalDirective>? instructions,
  Stream<List<MaintenanceRecord>>? ticketStream,
  Stream<List<OperationalDirective>>? directiveStream,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminTicketsStreamProvider.overrideWith(
          (ref) => ticketStream ?? Stream.value(tickets ?? []),
        ),
        adminDirectivesStreamProvider.overrideWith(
          (ref) => directiveStream ?? Stream.value(instructions ?? []),
        ),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(
          body: directives ? const DirectivesBrowser() : const TicketsBrowser(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _bottom(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byType(IncrementalListFooter),
    600,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String kind, String status) async {
  await tester.tap(find.byKey(ValueKey('admin-$kind-status-$status')));
  await tester.pumpAndSettle();
}

void main() {
  for (final directives in [false, true]) {
    final kind = directives ? 'directives' : 'tickets';
    testWidgets(
      'admin $kind starts open, grows manually and resets search/status to 15',
      (tester) async {
        final tickets = [
          for (var i = 0; i < 32; i++) _ticket(i),
          for (var i = 0; i < 32; i++) _ticket(i, closed: true),
          _ticket(90)..isDeleted = true,
        ].reversed.toList();
        final instructions = [
          for (var i = 0; i < 32; i++) _directive(i),
          for (var i = 0; i < 32; i++) _directive(i, closed: true),
          _directive(90)..isDeleted = true,
        ].reversed.toList();
        final originalTicketIds = tickets.map((t) => t.firestoreId).toList();
        final originalDirectiveIds = instructions
            .map((t) => t.firestoreId)
            .toList();
        await _pump(
          tester,
          directives: directives,
          tickets: tickets,
          instructions: instructions,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(ValueKey('admin-$kind-status-open')),
              )
              .selected,
          isTrue,
        );
        final firstRow = directives
            ? 'admin-directive-open-000'
            : 'admin-ticket-open-000';
        expect(find.byKey(ValueKey(firstRow)), findsOneWidget);
        await _bottom(tester);
        expect(find.text('Showing 15 of 32'), findsOneWidget);
        final sixteenth = directives
            ? 'admin-directive-open-015'
            : 'admin-ticket-open-015';
        expect(find.byKey(ValueKey(sixteenth)), findsNothing);
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(find.text('Showing 15 of 32'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
        await _bottom(tester);
        expect(find.text('Showing 30 of 32'), findsOneWidget);
        await _choose(tester, kind, 'all');
        expect(
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position
              .pixels,
          0,
        );
        await _bottom(tester);
        expect(find.text('Showing 15 of 65'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
        await _choose(tester, kind, 'closed');
        await _bottom(tester);
        expect(find.text('Showing 15 of 32'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
        await _bottom(tester);
        expect(find.text('Showing 30 of 32'), findsOneWidget);
        final search = find.byKey(ValueKey('admin-$kind-search'));
        await tester.enterText(search, 'Seal');
        await _bottom(tester);
        expect(find.text('Showing 15 of 16'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
        await _bottom(tester);
        expect(find.text('Showing 16 of 16'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('business-list-show-more')),
          findsNothing,
        );
        await tester.enterText(
          search,
          directives ? 'instruction 30' : 'observation 30',
        );
        await tester.pumpAndSettle();
        expect(find.text('Showing 1 of 1'), findsOneWidget);
        expect(
          find.byKey(
            ValueKey(
              directives
                  ? 'admin-directive-closed-030'
                  : 'admin-ticket-closed-030',
            ),
          ),
          findsOneWidget,
        );
        await tester.enterText(search, '');
        await _bottom(tester);
        expect(find.text('Showing 15 of 32'), findsOneWidget);
        expect(tickets.map((t) => t.firestoreId), originalTicketIds);
        expect(instructions.map((t) => t.firestoreId), originalDirectiveIds);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'admin $kind controls remain available during loading, empty and error states',
      (tester) async {
        final tickets = StreamController<List<MaintenanceRecord>>.broadcast();
        final instructions =
            StreamController<List<OperationalDirective>>.broadcast();
        addTearDown(tickets.close);
        addTearDown(instructions.close);
        await _pump(
          tester,
          directives: directives,
          ticketStream: tickets.stream,
          directiveStream: instructions.stream,
        );
        expect(find.byKey(ValueKey('admin-$kind-status-all')), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('admin-$kind-status-all')));
        await tester.pump();
        if (directives) {
          instructions.add([]);
        } else {
          tickets.add([]);
        }
        await tester.pumpAndSettle();
        expect(find.text('No $kind match.'), findsOneWidget);
        expect(find.byKey(ValueKey('admin-$kind-search')), findsOneWidget);
        await _choose(tester, kind, 'closed');
        if (directives) {
          instructions.addError(StateError('controlled source failure'));
        } else {
          tickets.addError(StateError('controlled source failure'));
        }
        await tester.pumpAndSettle();
        expect(
          find.textContaining('controlled source failure'),
          findsOneWidget,
        );
        expect(find.byKey(ValueKey('admin-$kind-status-open')), findsOneWidget);
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(ValueKey('admin-$kind-status-closed')),
              )
              .selected,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'admin All retains deleted tickets and malformed evidence without enabling correction',
    (tester) async {
      final bad = _ticket(0)..actionsJson = '{bad';
      final deleted = _ticket(1)..isDeleted = true;
      await _pump(tester, directives: false, tickets: [bad, deleted]);
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Repair saved evidence before correction'),
        findsOneWidget,
      );
      await _choose(tester, 'tickets', 'all');
      expect(
        find.byKey(const ValueKey('admin-ticket-open-001')),
        findsOneWidget,
      );
      expect(find.text('DELETED'), findsOneWidget);
      expect(find.byTooltip('Permanently remove pilot record'), findsOneWidget);
      final card = find.byKey(const ValueKey('admin-ticket-open-000'));
      final edit = find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == 'Repair saved evidence before correction',
        ),
      );
      expect(tester.widget<IconButton>(edit).onPressed, isNull);
      expect(find.text('Showing 2 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin closed directives keep closed identity and edit guard; All retains deleted rows',
    (tester) async {
      final closed = _directive(0, closed: true);
      final deleted = _directive(1)..isDeleted = true;
      await _pump(tester, directives: true, instructions: [closed, deleted]);
      await tester.pumpAndSettle();
      expect(find.text('No directives match.'), findsOneWidget);
      await _choose(tester, 'directives', 'closed');
      expect(find.text('DELETED'), findsNothing);
      expect(find.text('CLOSED'), findsWidgets);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Edit directive',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.byTooltip('Mark directive deleted'), findsNothing);
      await _choose(tester, 'directives', 'all');
      expect(
        find.byKey(const ValueKey('admin-directive-open-001')),
        findsOneWidget,
      );
      expect(find.text('DELETED'), findsOneWidget);
      expect(find.text('Showing 2 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
