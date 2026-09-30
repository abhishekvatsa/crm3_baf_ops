import 'dart:async';

import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_list_filter.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_reports_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final shortcut in [
    (
      label: 'Total',
      count: 7,
      status: AbnormalityListFilter.all,
      severity: null,
    ),
    (
      label: 'RA Pending',
      count: 2,
      status: AbnormalityListFilter.open,
      severity: null,
    ),
    (
      label: 'RA Done',
      count: 4,
      status: AbnormalityListFilter.completed,
      severity: null,
    ),
    (
      label: 'Critical',
      count: 2,
      status: AbnormalityListFilter.all,
      severity: AbnormalitySeverity.critical,
    ),
  ]) {
    testWidgets(
      '${shortcut.label} opens its global count despite conflicting filters',
      (tester) async {
        final semantics = tester.ensureSemantics();

        await _open(tester);
        await _select<AbnormalityCategory?>(tester, 'Equipment');
        await _select<AbnormalitySeverity?>(tester, 'Low');
        await _select<AbnormalityListFilter>(tester, 'RA not applicable');
        await _search(tester, 'does not match anything');
        await _tapMetric(tester, shortcut.label);
        expect(
          find.text('${shortcut.count} matching abnormalities').hitTestable(),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(_fieldValue<AbnormalityCategory?>(tester), isNull);
        expect(_fieldValue<AbnormalitySeverity?>(tester), shortcut.severity);
        expect(_fieldValue<AbnormalityListFilter>(tester), shortcut.status);
        final metric = find.byKey(
          ValueKey('abnormality-metric-${shortcut.label}'),
        );
        await _top(tester);
        await tester.ensureVisible(metric);
        expect(
          tester.getSemantics(metric),
          matchesSemantics(
            label: '${shortcut.label}: ${shortcut.count}. View records',
            isButton: true,
            hasTapAction: true,
            hasSelectedState: true,
            isSelected: true,
          ),
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('Matching navigates without changing current filters', (
    tester,
  ) async {
    await _open(tester);
    await _tapMetric(tester, 'Total');
    await _select<AbnormalityCategory?>(tester, 'Re-annealing');
    await _search(tester, 'second finding');
    await _tapMetric(tester, 'Matching');
    expect(find.text('1 matching abnormalities').hitTestable(), findsOneWidget);
    expect(
      _fieldValue<AbnormalityCategory?>(tester),
      AbnormalityCategory.reannealing,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'second finding',
    );
    await _bottom(tester);
    expect(
      find.byKey(const ValueKey('abnormality-report-row-second')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('abnormality-report-row-third')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero Critical is an actionable honest empty result', (
    tester,
  ) async {
    await _open(tester, records: [_record('plain', 52000)]);
    await _tapMetric(tester, 'Critical');
    expect(find.text('0 matching abnormalities').hitTestable(), findsOneWidget);
    await _bottom(tester);
    expect(find.text('No matching abnormalities'), findsOneWidget);
    expect(find.byKey(const ValueKey('business-list-show-more')), findsNothing);
    expect(
      _fieldValue<AbnormalitySeverity?>(tester),
      AbnormalitySeverity.critical,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'charge history joins all recorded stages outside filters and keeps pending terminal entry',
    (tester) async {
      await _open(tester);
      await _tapMetric(tester, 'RA Done');
      await _search(tester, 'second finding');
      await _bottom(tester);
      final row = find.byKey(const ValueKey('abnormality-report-row-second'));
      final charge = find.descendant(
        of: row,
        matching: find.byKey(
          const ValueKey('abnormality-history-charge-50200'),
        ),
      );
      await _reveal(tester, charge);
      await tester.tap(charge);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('abnormality-charge-history')),
        findsOneWidget,
      );
      expect(
        find.text('3 recorded RA links · 4 abnormality entries'),
        findsOneWidget,
      );
      expect(
        find.text('Repeated RA is recorded across these linked charges.'),
        findsOneWidget,
      );
      for (final number in [50100, 50200, 50300, 50400]) {
        expect(
          find.byKey(ValueKey('abnormality-charge-stage-$number')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('abnormality-charge-stage-50500')),
        findsNothing,
      );
      expect(
        find.text('RA decision or action remains pending on charge 50400.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        _fieldValue<AbnormalityListFilter>(tester),
        AbnormalityListFilter.all,
      );
      await tester.ensureVisible(
        find.text('4 abnormalities in this charge history'),
      );
      await tester.pumpAndSettle();
      // Actual RA time is separate from the log time; no missing date is filled in.
      await _reveal(tester, find.text('RA date: 28 Sep 2026, 10:00'));
      expect(find.text('RA date: 28 Sep 2026, 10:00'), findsOneWidget);
      await _bottom(tester);
      expect(find.text('terminal finding'), findsOneWidget);
      expect(find.text('RA date: not recorded'), findsWidgets);
      expect(find.text('unrelated finding'), findsNothing);
      await _top(tester);
      final close = find.byKey(const ValueKey('abnormality-history-close'));
      await tester.ensureVisible(close);
      await tester.pumpAndSettle();
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('abnormality-charge-history')),
        findsNothing,
      );
      expect(
        find.text('7 matching abnormalities').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'branch retains recorded links and warns rather than drawing one sequence',
    (tester) async {
      await _open(
        tester,
        records: [
          _record('left', 53000, target: 53001),
          _record('right', 53000, target: 53002),
        ],
      );
      await _tapMetric(tester, 'RA Done');
      await _bottom(tester);
      final charge = find.descendant(
        of: find.byKey(const ValueKey('abnormality-report-row-left')),
        matching: find.byKey(
          const ValueKey('abnormality-history-charge-53000'),
        ),
      );
      await _reveal(tester, charge);
      await tester.tap(charge);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('abnormality-charge-sequence')),
        findsNothing,
      );
      expect(find.text('53000 → 53001'), findsOneWidget);
      expect(find.text('53000 → 53002'), findsOneWidget);
      expect(
        find.textContaining('multiple new charges', findRichText: true),
        findsWidgets,
      );
      expect(
        find.text('Repeated RA is recorded across these linked charges.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'revocation closes history and next approved actor loads a fresh report',
    (tester) async {
      final actors = StreamController<AppUser?>();
      addTearDown(actors.close);
      final repo = _Repository(_records());
      await _open(tester, actors: actors.stream, repository: repo);
      actors.add(_actor());
      await tester.pumpAndSettle();
      await _tapMetric(tester, 'RA Done');
      await _bottom(tester);
      final charge = find.byKey(
        const ValueKey('abnormality-history-charge-50100'),
      );
      await _reveal(tester, charge);
      await tester.tap(charge);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('abnormality-charge-history')),
        findsOneWidget,
      );
      actors.add(_actor(approved: false));
      await tester.pumpAndSettle();
      expect(find.text('Abnormality-report access required'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('abnormality-charge-history')),
        findsNothing,
      );
      repo.records = [_record('new actor finding', 54000)];
      actors.add(_actor(uid: 'other'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('abnormality-charge-history')),
        findsNothing,
      );
      await _tapMetric(tester, 'Total');
      await _bottom(tester);
      expect(find.text('new actor finding'), findsOneWidget);
      expect(find.text('second finding'), findsNothing);
      expect(repo.loads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'summary and a long history wrap on narrow screens at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(
        tester,
        scale: 2,
        records: [
          for (var i = 0; i < 6; i++)
            _record('stage $i', 55000 + i, target: 55001 + i),
        ],
      );
      await _tapMetric(tester, 'RA Done');
      await _bottom(tester);
      final charge = find.byKey(
        const ValueKey('abnormality-history-charge-55000'),
      );
      await _reveal(tester, charge);
      await tester.tap(charge);
      await tester.pumpAndSettle();
      expect(
        find.text('6 recorded RA links · 6 abnormality entries'),
        findsOneWidget,
      );
      for (var i = 0; i <= 6; i++) {
        expect(
          find.byKey(ValueKey('abnormality-charge-stage-${55000 + i}')),
          findsOneWidget,
        );
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('abnormality-history-close')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('abnormality-history-close')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

AppUser _actor({String uid = 'reader', bool approved = true}) => AppUser(
  uid: uid,
  email: 'reader@example.invalid',
  name: 'Reader',
  roles: [AppRole.si],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

List<ChargeAbnormality> _records() => [
  _record('third finding', 50300, target: 50400, id: 'third'),
  _record(
      'first finding',
      50100,
      target: 50200,
      id: 'first',
      category: AbnormalityCategory.process,
    )
    ..assessment = AbnormalityAssessment(
      observationKind: AbnormalityObservationKind.resultFinding,
      raPerformedAt: DateTime(2026, 9, 28, 10),
    ),
  _record(
    'unrelated finding',
    50500,
    target: 50600,
    id: 'unrelated',
    category: AbnormalityCategory.equipment,
    severity: AbnormalitySeverity.critical,
  ),
  _record('second finding', 50200, target: 50300, id: 'second'),
  _record(
    'terminal finding',
    50400,
    id: 'terminal',
    status: ReannealingStatus.required,
  ),
  _record(
    'other pending',
    50700,
    id: 'pending',
    status: ReannealingStatus.pendingDecision,
    severity: AbnormalitySeverity.critical,
  ),
  _record(
    'ordinary finding',
    50800,
    id: 'ordinary',
    status: ReannealingStatus.notApplicable,
  ),
];

ChargeAbnormality _record(
  String reason,
  int source, {
  String? id,
  int? target,
  ReannealingStatus status = ReannealingStatus.notApplicable,
  AbnormalityCategory category = AbnormalityCategory.reannealing,
  AbnormalitySeverity severity = AbnormalitySeverity.low,
}) =>
    ChargeAbnormality.createRaCoilColour(
        firestoreId: id ?? reason,
        sourceChargeNo: source,
        affectedAssets: const [
          AffectedAssetRef(assetType: AssetType.base, assetNumber: 220),
        ],
        observedReason: reason,
        loggedByUid: 'reader',
        loggedByName: 'Reader',
      )
      ..reannealedToChargeNo = target
      ..reannealingStatus = target == null
          ? status
          : ReannealingStatus.completed
      ..category = category
      ..severity = severity
      ..loggedAt = DateTime(2026, 9, 30, 9)
      ..updatedAt = DateTime(2026, 9, 30, 9);

Future<void> _open(
  WidgetTester tester, {
  List<ChargeAbnormality>? records,
  Stream<AppUser?>? actors,
  _Repository? repository,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => actors ?? Stream.value(_actor()),
        ),
        abnormalityRepositoryProvider.overrideWithValue(
          repository ?? _Repository(records ?? _records()),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AbnormalityReportsScreen(),
      ),
    ),
  );
  if (actors == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _top(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> _bottom(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    final pos = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    if (pos.pixels >= pos.maxScrollExtent) break;
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapMetric(WidgetTester tester, String label) async {
  await _top(tester);
  final metric = find.byKey(ValueKey('abnormality-metric-$label'));
  await tester.ensureVisible(metric);
  await tester.pumpAndSettle();
  await tester.tap(metric);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await _top(tester);
  await tester.scrollUntilVisible(
    finder,
    400,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String text) async {
  await _top(tester);
  final field = find.byType(TextField);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _select<T>(WidgetTester tester, String label) async {
  await _top(tester);
  final field = find.byType(DropdownButtonFormField<T>);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

T? _fieldValue<T>(WidgetTester tester) => tester
    .state<FormFieldState<T>>(find.byType(DropdownButtonFormField<T>))
    .value;

class _Repository extends Fake implements AbnormalityRepository {
  _Repository(this.records);
  List<ChargeAbnormality> records;
  int loads = 0;
  @override
  Future<List<ChargeAbnormality>> getAllAbnormalities() async {
    loads++;
    return records;
  }
}
