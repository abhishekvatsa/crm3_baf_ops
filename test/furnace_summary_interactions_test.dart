import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/data/furnace_stuckup_record.dart';
import 'package:crm3_baf_ops/features/assets/presentation/furnace_stuckup_board.dart';
import 'package:crm3_baf_ops/features/assets/providers/furnace_stuckup_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/furnace_stuckup_case.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 9, 30);
final _user = AppUser(
  uid: 'summary-operator',
  name: 'Summary operator',
  email: 'summary@example.invalid',
  roles: const [AppRole.operations],
  isApproved: true,
  createdAt: _now,
);
FurnaceStuckupRecord _record(
  int number, {
  bool active = true,
  bool pending = true,
}) => FurnaceStuckupRecord(
  id: 'case-$number',
  ticketId: 'case-$number',
  version: 1,
  obstructionStatus: active
      ? FurnaceStuckupObstructionStatus.active
      : FurnaceStuckupObstructionStatus.released,
  adjudicationStatus: pending
      ? FurnaceStuckupAdjudicationStatus.pending
      : FurnaceStuckupAdjudicationStatus.confirmed,
  suspectedCause: FurnaceStuckupCause.innerCoverBulging,
  confirmedCause: pending ? null : FurnaceStuckupCause.innerCoverBulging,
  furnaceAssetInstanceId: 'furnace-$number',
  furnaceAssetNumber: number,
  baseAssetInstanceId: 'base-$number',
  baseAssetNumber: 100 + number,
  innerCoverId: 'cover-$number',
  innerCoverSerialNumber: 'SYN-$number',
  operatingContext: FurnaceStuckupOperatingContext.postAnnealingRemoval,
  chargeNoAtEvent: 70000 + number,
  reportedAt: _now,
  reportedByName: 'Synthetic',
  releasedAt: active ? null : _now,
  releaseNotes: active ? null : 'Removed',
  adjudicatedAt: pending ? null : _now,
  adjudicationNotes: pending ? null : 'Confirmed',
  conditionDeclarationId: pending ? null : 'declaration-$number',
  updatedAt: _now,
);
final _declaration = AssetConditionDeclarationRecord(
  id: 'declaration-3',
  assetId: 'cover-3',
  assetSerialNumber: 'SYN-3',
  evidenceCount: 2,
  firstConfirmedAt: _now.subtract(const Duration(days: 10)),
  latestEvidenceAt: _now.subtract(const Duration(days: 2)),
);
Finder _metric(String label) => find.byKey(ValueKey('furnace-summary-$label'));
Future<void> _pump(
  WidgetTester tester, {
  List<FurnaceStuckupRecord>? records,
  Stream<List<AssetConditionDeclarationRecord>>? declarations,
  double width = 390,
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(_user)),
        furnaceStuckupCasesProvider.overrideWith(
          (ref) => Stream.value(
            records ??
                [
                  _record(1, pending: false),
                  _record(2, active: false),
                  _record(3, active: false, pending: false),
                ],
          ),
        ),
        assetConditionDeclarationsProvider.overrideWith(
          (ref) => declarations ?? Stream.value([_declaration]),
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
        home: const FurnaceStuckupBoard(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(_metric(label));
  await tester.tap(_metric(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'summary cards select matching active, pending and recorded evidence',
    (tester) async {
      await _pump(tester);
      expect(find.text('Furnace 01 on Base 101'), findsOneWidget);
      expect(find.text('Furnace 02 on Base 102'), findsNothing);
      await _tap(tester, 'Cause pending');
      expect(find.text('Furnace 02 on Base 102'), findsOneWidget);
      expect(find.text('Furnace 01 on Base 101'), findsNothing);
      await _tap(tester, 'Bulge records');
      expect(find.textContaining('Furnace 0'), findsNothing);
      expect(find.text('Inner Cover SYN-3 · Bulge recorded'), findsOneWidget);
      expect(
        find.textContaining('Past confirmations do not establish'),
        findsOneWidget,
      );
      await _tap(tester, 'Blocked');
      expect(find.text('Furnace 01 on Base 101'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zero summary cards remain usable and show exact empty results', (
    tester,
  ) async {
    await _pump(tester, records: [], declarations: Stream.value([]));
    for (final entry in [
      ('Cause pending', 'No stuck-up cause is awaiting adjudication.'),
      ('Bulge records', 'No confirmed Inner Cover bulge evidence is recorded.'),
      ('Blocked', 'No Furnace is currently blocked by a stuck-up.'),
    ]) {
      expect(
        find.descendant(of: _metric(entry.$1), matching: find.text('0')),
        findsOneWidget,
      );
      await _tap(tester, entry.$1);
      expect(find.text(entry.$2), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading declaration evidence never becomes a zero bulge claim', (
    tester,
  ) async {
    final stream = StreamController<List<AssetConditionDeclarationRecord>>();
    addTearDown(stream.close);
    await _pump(tester, declarations: stream.stream);
    expect(
      find.descendant(of: _metric('Bulge records'), matching: find.text('--')),
      findsOneWidget,
    );
    await tester.tap(_metric('Bulge records'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Loading recorded bulge evidence'), findsOneWidget);
    expect(
      find.text('No confirmed Inner Cover bulge evidence is recorded.'),
      findsNothing,
    );
    stream.add([_declaration]);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _metric('Bulge records'), matching: find.text('1')),
      findsOneWidget,
    );
    expect(find.text('Inner Cover SYN-3 · Bulge recorded'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed declaration refresh hides stale numeric certainty and offers retry',
    (tester) async {
      final stream = StreamController<List<AssetConditionDeclarationRecord>>();
      addTearDown(stream.close);
      await _pump(tester, declarations: stream.stream);
      stream.add([_declaration]);
      await tester.pumpAndSettle();
      await _tap(tester, 'Bulge records');
      stream.addError(StateError('Synthetic read unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _metric('Bulge records'),
          matching: find.text('--'),
        ),
        findsOneWidget,
      );
      expect(find.text('Bulge evidence unavailable'), findsOneWidget);
      expect(find.text('Refresh bulge evidence'), findsOneWidget);
      expect(find.text('Inner Cover SYN-3 · Bulge recorded'), findsNothing);
      expect(
        find.text('No confirmed Inner Cover bulge evidence is recorded.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scenario in [(320.0, 1.6), (390.0, 1.0)]) {
    testWidgets(
      'Furnace summary actions fit ${scenario.$1}px at ${scenario.$2} text',
      (tester) async {
        await _pump(tester, width: scenario.$1, scale: scenario.$2);
        for (final label in ['Blocked', 'Cause pending', 'Bulge records']) {
          final button = _metric(label);
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
