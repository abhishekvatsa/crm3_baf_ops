import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/incremental_list_footer.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/presentation/directives_screen.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _actor = AppUser(
  uid: 'operator',
  name: 'Operator',
  email: 'operator@example.invalid',
  roles: [AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026, 9, 27),
);

OperationalDirective _directive(int index, {bool closed = false}) {
  final at = DateTime.utc(
    2026,
    9,
    27,
  ).add(Duration(minutes: index + (closed ? 100 : 0)));
  return OperationalDirective()
    ..firestoreId = '${closed ? 'closed' : 'open'}-$index'
    ..title =
        '${closed ? 'Closed' : 'Open'} item ${index.toString().padLeft(2, '0')}'
    ..description = 'Recorded instruction'
    ..directedTo = AppRole.operations
    ..createdByUid = 'issuer'
    ..createdByName = 'Issuer'
    ..createdAt = at
    ..updatedAt = at
    ..status = closed
        ? DirectiveStatus.closed
        : index == 30
        ? DirectiveStatus.acknowledged
        : DirectiveStatus.open
    ..isSynced = true;
}

class _HistoryRepository extends Fake implements DirectiveRepository {
  _HistoryRepository(this.rows, {this.historyStream});
  final List<OperationalDirective> rows;
  final Stream<List<OperationalDirective>>? historyStream;
  int reads = 0;
  int? requestedLimit;
  @override
  Stream<List<OperationalDirective>> watchAllDirectives({int? limit}) {
    reads++;
    requestedLimit = limit;
    return historyStream ?? Stream.value(rows);
  }
}

Future<_HistoryRepository> _pump(
  WidgetTester tester, {
  Stream<List<OperationalDirective>>? historyStream,
  List<OperationalDirective>? records,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final rows =
      records ??
      <OperationalDirective>[
        for (var index = 0; index < 31; index++) _directive(index),
        for (var index = 0; index < 31; index++)
          _directive(index, closed: true),
        _directive(99)..directedTo = AppRole.si,
      ];
  final repository = _HistoryRepository(rows, historyStream: historyStream);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(_actor)),
        openDirectivesProvider.overrideWith(
          (ref) => Stream.value(
            rows.where((row) => row.status != DirectiveStatus.closed).toList(),
          ),
        ),
        directiveRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: const DirectivesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<IncrementalListFooter> _bottom(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(IncrementalListFooter),
    700,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
  return tester.widget<IncrementalListFooter>(
    find.byType(IncrementalListFooter),
  );
}

Future<void> _top(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> _status(WidgetTester tester, String label) async {
  await _top(tester);
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('directives-status-filter')),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('equal-time local records use local identity for stable order', (
    tester,
  ) async {
    final at = DateTime.utc(2026, 9, 27);
    final first = _directive(1)
      ..firestoreId = null
      ..id = 1
      ..createdAt = at
      ..title = 'Local first';
    final second = _directive(2)
      ..firestoreId = null
      ..id = 2
      ..createdAt = at
      ..title = 'Local second';
    await _pump(tester, records: [second, first]);
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Local first')).dy,
      lessThan(tester.getTopLeft(find.text('Local second')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'typed search survives delayed history loading and status changes',
    (tester) async {
      final history = Completer<List<OperationalDirective>>();
      final repository = await _pump(
        tester,
        historyStream: history.future.asStream(),
      );
      final field = find.byKey(const ValueKey('directives-search'));
      await tester.enterText(field, 'item 00');
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('directives-status-filter')),
          matching: find.text('All'),
        ),
      );
      await tester.pump();
      expect(
        field,
        findsNothing,
        reason: 'The history-loading state removes the header.',
      );
      history.complete(repository.rows);
      await tester.pumpAndSettle();
      String visibleQuery() => tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .controller
          .text;
      expect(visibleQuery(), 'item 00');
      expect((await _bottom(tester)).totalCount, 2);
      await _status(tester, 'Closed');
      expect(visibleQuery(), 'item 00');
      expect((await _bottom(tester)).totalCount, 1);
      await _status(tester, 'Open');
      expect(visibleQuery(), 'item 00');
      expect((await _bottom(tester)).totalCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Open retains acknowledged work and expands only by explicit batches of 15',
    (tester) async {
      final repository = await _pump(tester);
      expect(find.text('Open item 30'), findsOneWidget);
      expect(find.text('Closed item 30'), findsNothing);
      expect(repository.reads, 0, reason: 'History is not fetched on entry.');
      var footer = await _bottom(tester);
      expect(footer.visibleCount, 15);
      expect(
        footer.totalCount,
        31,
        reason: 'Role-excluded records do not count.',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(
        (await _bottom(tester)).visibleCount,
        15,
        reason: 'Reaching the bottom must not auto-expand.',
      );
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await tester.pumpAndSettle();
      footer = await _bottom(tester);
      expect(footer.visibleCount, 30);
      expect(footer.totalCount, 31);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await tester.pumpAndSettle();
      footer = await _bottom(tester);
      expect(footer.visibleCount, 31);
      expect(
        find.byKey(const ValueKey('business-list-show-more')),
        findsNothing,
      );
      expect(
        repository.rows.length,
        63,
        reason: 'Canonical records stay complete.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All and Closed reset to 15 and closed cards have no live actions',
    (tester) async {
      final repository = await _pump(tester);
      await _bottom(tester);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await tester.pumpAndSettle();
      expect((await _bottom(tester)).visibleCount, 30);
      await _status(tester, 'All');
      expect(
        find.text('Closed item 30'),
        findsOneWidget,
        reason: 'Full matching list is sorted before slicing.',
      );
      var footer = await _bottom(tester);
      expect(footer.visibleCount, 15);
      expect(footer.totalCount, 62);
      expect(repository.requestedLimit, isNull);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await tester.pumpAndSettle();
      expect((await _bottom(tester)).visibleCount, 30);
      await _status(tester, 'Closed');
      expect(find.text('Acknowledge'), findsNothing);
      expect(find.text('Close Directive'), findsNothing);
      footer = await _bottom(tester);
      expect(footer.visibleCount, 15);
      expect(footer.totalCount, 31);
      await _status(tester, 'Open');
      expect((await _bottom(tester)).visibleCount, 15);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search filters the whole population and resets an expanded view',
    (tester) async {
      await _pump(tester);
      await _status(tester, 'All');
      await _bottom(tester);
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await tester.pumpAndSettle();
      expect((await _bottom(tester)).visibleCount, 30);
      await _top(tester);
      await tester.enterText(
        find.byKey(const ValueKey('directives-search')),
        'item 00',
      );
      await tester.pumpAndSettle();
      var footer = await _bottom(tester);
      expect(footer.visibleCount, 2);
      expect(
        footer.totalCount,
        2,
        reason: 'Search must find older records beyond the initial batch.',
      );
      await _top(tester);
      await tester.enterText(
        find.byKey(const ValueKey('directives-search')),
        '',
      );
      await tester.pumpAndSettle();
      footer = await _bottom(tester);
      expect(footer.visibleCount, 15);
      expect(footer.totalCount, 62);
      expect(tester.takeException(), isNull);
    },
  );
}
