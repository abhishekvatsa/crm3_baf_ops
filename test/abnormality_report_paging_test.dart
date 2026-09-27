import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_list_filter.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_reports_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'open abnormality report grows 15 at a time and retains all matching totals',
    (tester) async {
      await _open(tester);
      await _bottom(tester);
      expect(find.text('Showing 15 of 32'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('abnormality-report-row-open-15')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('abnormality-report-row-open-16')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await tester.pumpAndSettle();
      await _bottom(tester);
      expect(find.text('Showing 30 of 32'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('abnormality-report-row-open-30')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('abnormality-report-row-open-31')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await tester.pumpAndSettle();
      await _bottom(tester);
      expect(find.text('Showing 32 of 32'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('abnormality-report-row-open-32')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('business-list-show-more')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All and RA history reset to 15; search and Clear reset the displayed rows and controls',
    (tester) async {
      await _open(tester);
      await _status(tester, 'All');
      await _bottom(tester);
      expect(find.text('Showing 15 of 52'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('abnormality-report-row-done-15')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('business-list-show-more')));
      await tester.pumpAndSettle();
      await _bottom(tester);
      expect(find.text('Showing 30 of 52'), findsOneWidget);
      await _status(tester, 'RA completed');
      await _bottom(tester);
      expect(find.text('Showing 15 of 20'), findsOneWidget);
      await _top(tester);
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'done event 20');
      await tester.pumpAndSettle();
      await _bottom(tester);
      expect(find.text('Showing 1 of 1'), findsOneWidget);
      expect(find.text('done event 20'), findsWidgets);
      await _top(tester);
      await tester.ensureVisible(find.text('Clear'));
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      final status = tester.state<FormFieldState<AbnormalityListFilter>>(
        find.byType(DropdownButtonFormField<AbnormalityListFilter>),
      );
      expect(status.value, AbnormalityListFilter.open);
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      await _bottom(tester);
      expect(find.text('Showing 15 of 32'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(WidgetTester tester) async {
  final records = <ChargeAbnormality>[
    for (var i = 1; i <= 20; i++)
      _record('done', i, ReannealingStatus.completed, i),
    for (var i = 1; i <= 32; i++)
      _record('open', i, ReannealingStatus.pendingDecision, 100 + i),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              uid: 'approved-reader',
              email: 'reader@example.invalid',
              name: 'Reader',
              roles: [AppRole.si],
              isApproved: true,
              createdAt: DateTime.utc(2026),
            ),
          ),
        ),
        abnormalityRepositoryProvider.overrideWithValue(_Repository(records)),
      ],
      child: const MaterialApp(home: AbnormalityReportsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

ChargeAbnormality _record(
  String prefix,
  int number,
  ReannealingStatus status,
  int minutes,
) =>
    ChargeAbnormality.createRaCoilColour(
        firestoreId: '$prefix-$number',
        sourceChargeNo: 12000 + number,
        affectedAssets: const [],
        observedReason: '$prefix event $number',
        loggedByUid: 'reader',
        loggedByName: 'Reader',
      )
      ..loggedAt = DateTime.utc(
        2026,
        9,
        27,
      ).subtract(Duration(minutes: minutes))
      ..reannealingStatus = status;

Future<void> _bottom(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 80; i++) {
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
  }
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
  final field = find.byType(DropdownButtonFormField<AbnormalityListFilter>);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class _Repository extends Fake implements AbnormalityRepository {
  _Repository(this.records);
  final List<ChargeAbnormality> records;
  @override
  Future<List<ChargeAbnormality>> getAllAbnormalities() async => records;
}
