import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_types_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets(
    'status summaries select their exact matching types and Total clears only status',
    (tester) async {
      await _pump(tester, types: _types());
      _expectMetric(tester, 'Total', 3, selected: true);
      _expectMetric(tester, 'Active', 2);
      _expectMetric(tester, 'Inactive', 1);
      await _tap(tester, 'Inactive');
      _expectMetric(tester, 'Inactive', 1, selected: true);
      expect(find.text('Alpha retired'), findsOneWidget);
      expect(find.text('Alpha current'), findsNothing);
      expect(find.text('Beta current'), findsNothing);
      await _tap(tester, 'Active');
      _expectMetric(tester, 'Active', 2, selected: true);
      expect(find.text('Alpha current'), findsOneWidget);
      expect(find.text('Beta current'), findsOneWidget);
      expect(find.text('Alpha retired'), findsNothing);
      await _tap(tester, 'Active');
      _expectMetric(tester, 'Active', 2, selected: true);
      await _tap(tester, 'Total');
      _expectMetric(tester, 'Total', 3, selected: true);
      expect(find.text('Alpha retired'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'counts follow search and search/status can be cleared independently',
    (tester) async {
      await _pump(tester, types: _types());
      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pumpAndSettle();
      _expectMetric(tester, 'Total', 2, selected: true);
      _expectMetric(tester, 'Active', 1);
      _expectMetric(tester, 'Inactive', 1);
      await _tap(tester, 'Inactive');
      expect(find.text('Alpha retired'), findsOneWidget);
      expect(find.text('Alpha current'), findsNothing);
      await _tap(tester, 'Total');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text ??
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
        'Alpha',
      );
      expect(find.text('Beta current'), findsNothing);
      expect(find.text('Alpha current'), findsOneWidget);
      await _tap(tester, 'Inactive');
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      _expectMetric(tester, 'Total', 3);
      _expectMetric(tester, 'Inactive', 1, selected: true);
      expect(find.text('Alpha current'), findsNothing);
      expect(find.text('Alpha retired'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zero status remains selectable and explains an empty filtered result',
    (tester) async {
      await _pump(tester, types: [_type(1, 'Only current', active: true)]);
      _expectMetric(tester, 'Inactive', 0);
      await _tap(tester, 'Inactive');
      _expectMetric(tester, 'Inactive', 0, selected: true);
      expect(find.text('Only current'), findsNothing);
      expect(
        find.text(
          'No types match this search and status. Select Total to show all statuses, or change the search.',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'Total');
      expect(find.text('Only current'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty master keeps all zero counters interactive and retains its setup guidance',
    (tester) async {
      await _pump(tester, types: []);
      for (final label in ['Active', 'Inactive', 'Total']) {
        await _tap(tester, label);
        _expectMetric(tester, label, 0, selected: true);
      }
      expect(
        find.text(
          'Create master data first. Operators will later select from this list while logging abnormalities.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('non-admin cannot read master data or see summary actions', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_actor(admin: false)),
          ),
          allAbnormalityTypesProvider.overrideWith((ref) {
            reads++;
            return Stream.value(_types());
          }),
        ],
        child: const MaterialApp(home: AbnormalityTypesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Admin access required'), findsOneWidget);
    expect(_metric('Total'), findsNothing);
    expect(reads, 0);
  });

  testWidgets('revoked current role removes summary and master rows', (
    tester,
  ) async {
    final actor = StreamController<AppUser?>();
    addTearDown(actor.close);
    await _pump(tester, types: _types(), actors: actor.stream);
    actor.add(_actor());
    await tester.pumpAndSettle();
    await _tap(tester, 'Inactive');
    actor.add(_actor(admin: false));
    await tester.pumpAndSettle();
    expect(find.text('Admin access required'), findsOneWidget);
    expect(_metric('Inactive'), findsNothing);
    expect(find.text('Alpha retired'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 900), const Size(1100, 900)]) {
    testWidgets(
      'status buttons retain accessible selection and complete labels at $size /2x',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await _pump(tester, types: _types(), size: size, scale: 2);
          for (final label in ['Inactive', 'Active', 'Total']) {
            await _tap(tester, label);
            final metric = _metric(label);
            expect(tester.getSize(metric).height, greaterThanOrEqualTo(48));
            expect(tester.widget<Semantics>(metric).properties.button, isTrue);
            expect(
              tester.widget<Semantics>(metric).properties.selected,
              isTrue,
            );
            final text = tester.widget<Text>(
              find.descendant(of: metric, matching: find.text(label)),
            );
            expect(text.maxLines, isNull);
            expect(text.overflow, isNot(TextOverflow.ellipsis));
            expect(tester.takeException(), isNull);
          }
          await _tap(tester, 'Inactive');
          await tester.scrollUntilVisible(
            find.text('Alpha retired'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Alpha retired'), findsOneWidget);
          expect(find.text('Alpha current'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          handle.dispose();
        }
      },
    );
  }
}

Finder _metric(String label) =>
    find.byKey(ValueKey('abnormality-type-filter-${label.toLowerCase()}'));

void _expectMetric(
  WidgetTester tester,
  String label,
  int value, {
  bool selected = false,
}) {
  final metric = _metric(label);
  expect(
    find.descendant(of: metric, matching: find.text('$value')),
    findsOneWidget,
  );
  expect(tester.widget<Semantics>(metric).properties.selected, selected);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final metric = _metric(label);
  await tester.scrollUntilVisible(
    metric,
    -180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(metric);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required List<AbnormalityType> types,
  Size size = const Size(1000, 1700),
  double scale = 1,
  Stream<AppUser?>? actors,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => actors ?? Stream.value(_actor()),
        ),
        allAbnormalityTypesProvider.overrideWith((ref) => Stream.value(types)),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AbnormalityTypesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppUser _actor({bool admin = true}) => AppUser(
  uid: 'summary-actor',
  name: 'Synthetic admin',
  email: 'admin@example.invalid',
  roles: [admin ? AppRole.admin : AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

List<AbnormalityType> _types() => [
  _type(1, 'Alpha current', active: true),
  _type(2, 'Beta current', active: true),
  _type(3, 'Alpha retired', active: false),
];

AbnormalityType _type(int id, String title, {required bool active}) =>
    AbnormalityType()
      ..id = id
      ..firestoreId = 'type-$id'
      ..code = 'TYPE_$id'
      ..title = title
      ..category = AbnormalityCategory.process
      ..severity = AbnormalitySeverity.medium
      ..applicableAssetTypes = [AssetType.furnace]
      ..isActive = active
      ..isSynced = true
      ..createdAt = DateTime.utc(2026)
      ..updatedAt = DateTime.utc(2026);
