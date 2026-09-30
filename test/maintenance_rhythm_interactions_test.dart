import 'dart:async';

import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/maintenance_intelligence_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _asOf = DateTime.utc(2040, 9, 30, 12);

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  for (final metric in [
    (label: 'Tracked', ids: ['overdue', 'soon', 'later', 'monitoring']),
    (label: 'Overdue', ids: ['overdue']),
    (label: 'Due soon', ids: ['soon']),
  ]) {
    testWidgets(
      '${metric.label} cadence metric opens exactly its counted records',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _open(tester);
        await _tap(tester, metric.label);
        final expected = metric.ids.toSet();
        for (final id in ['overdue', 'soon', 'later', 'monitoring']) {
          expect(
            find.byKey(ValueKey('maintenance-due-row-$id')),
            expected.contains(id) ? findsOneWidget : findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'filtered zero preserves incomplete population disclosure at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(
        tester,
        scale: 2,
        rows: [_row('later', days: 20)],
        rejected: ['bad-row'],
      );
      await _tap(tester, 'Overdue');
      expect(find.text('No matching due-state records'), findsOneWidget);
      expect(
        find.textContaining('could not be read; these counts cover the rest'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected cadence filter and colour use the emitted clock', (
    tester,
  ) async {
    final clock = StreamController<DateTime>();
    addTearDown(clock.close);
    await _open(tester, rows: [_row('soon', days: 1)], clock: clock.stream);
    clock.add(_asOf);
    await tester.pumpAndSettle();
    final card = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('maintenance-due-row-soon')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      ((card.decoration! as BoxDecoration).border! as Border).left.color,
      BafColors.warning,
    );
    await _tap(tester, 'Overdue');
    expect(
      find.byKey(const ValueKey('maintenance-due-row-soon')),
      findsNothing,
    );
    clock.add(_asOf.add(const Duration(days: 2)));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('maintenance-due-row-soon')),
      findsOneWidget,
    );
    expect(find.text('1 days overdue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long asset identity keeps its width and status wraps below at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(
        tester,
        scale: 2,
        rows: [
          _row(
            'long',
            days: 27,
            displayName:
                'Furnace 104 maintenance example with complete governed identity',
          ),
        ],
      );
      final row = find.byKey(const ValueKey('maintenance-due-row-long'));
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final title = find.byKey(const ValueKey('maintenance-due-title-long'));
      final status = find.byKey(const ValueKey('maintenance-due-status-long'));
      expect(
        tester.getRect(status).top,
        greaterThan(tester.getRect(title).bottom),
      );
      expect(tester.getSize(title).width, greaterThan(180));
      final text = tester.widget<Text>(title);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(find.text('27 days remaining'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unapproved actor cannot start maintenance evidence reads', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_actor(approved: false)),
          ),
          maintenanceDueStatesProvider.overrideWith((ref) {
            reads++;
            throw StateError('Forbidden read');
          }),
        ],
        child: const MaterialApp(home: MaintenanceIntelligenceScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.textContaining('approved account'), findsOneWidget);
  });
}

Future<void> _open(
  WidgetTester tester, {
  List<MaintenanceDueState>? rows,
  List<String> rejected = const [],
  double scale = 1,
  Stream<DateTime>? clock,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(_actor())),
        maintenanceCadenceClockProvider.overrideWith(
          (ref) => clock ?? Stream.value(_asOf),
        ),
        maintenanceDueStatesProvider.overrideWith(
          (ref) => Stream.value(
            DecodedSnapshotBatch(
              records:
                  rows ??
                  [
                    _row('overdue', days: -2),
                    _row('soon', days: 3),
                    _row('later', days: 20),
                    _row('monitoring'),
                  ],
              rejectedDocumentIds: rejected,
            ),
          ),
        ),
        maintenanceCompletionEventsProvider.overrideWith(
          (ref) => Stream.value(
            const DecodedSnapshotBatch<MaintenanceCompletionEvent>(
              records: [],
              rejectedDocumentIds: [],
            ),
          ),
        ),
        maintenancePlansProvider.overrideWith(
          (ref) => Stream.value(
            const DecodedSnapshotBatch<MaintenancePlan>(
              records: [],
              rejectedDocumentIds: [],
            ),
          ),
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
      child: MaterialApp(
        theme: BafAppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const MaintenanceIntelligenceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final metric = find.byKey(ValueKey('maintenance-due-metric-$label'));
  await tester.ensureVisible(metric);
  await tester.pumpAndSettle();
  await tester.tap(metric);
  await tester.pumpAndSettle();
}

AppUser _actor({bool approved = true}) => AppUser(
  uid: 'cadence-reader',
  name: 'Reader',
  email: 'cadence@example.invalid',
  roles: [AppRole.operations],
  isApproved: approved,
  createdAt: _asOf,
);
MaintenanceDueState _row(String id, {int? days, String? displayName}) =>
    MaintenanceDueState(
      id: id,
      assetIdentityKey: 'class-furnace:$id',
      assetTypeKey: 'furnace',
      assetNumber: 1,
      assetClassId: 'class-furnace',
      assetInstanceId: id,
      assetDisplayName: displayName ?? 'Furnace $id',
      counterKey: 'FURNACE_ANY',
      counterLabel: 'Any maintenance',
      thresholdDays: 30,
      lastCompletionAt: _asOf.subtract(const Duration(days: 30)),
      nextDueAt: days == null ? null : _asOf.add(Duration(days: days)),
      lastMaintenanceClassCode: 'GENERAL',
      classificationPending: false,
    );
