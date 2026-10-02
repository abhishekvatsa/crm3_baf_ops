import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'plant_asset_overview_test.dart' as f;
import '../tool/test_support/home_class_overview_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Medium.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'Home exposes independent class availability instead of pooled tiles',
    (tester) async {
      final overview = homeClassOverviewFixture();
      await _pump(tester, AsyncData(overview));
      _expectCount(tester, 'available', 'bases', 35);
      _expectCount(tester, 'unavailable', 'bases', 12);
      _expectCount(tester, 'available', 'furnaces', 25);
      _expectCount(tester, 'unavailable', 'furnaces', 0);
      _expectCount(tester, 'available', 'coolers', 24);
      _expectCount(tester, 'unavailable', 'coolers', 0);
      expect(
        find.byKey(const ValueKey('plant-class-row-covers')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plant-condition-available')),
        findsNothing,
      );
      expect(find.textContaining(RegExp(r'^\d+%$')), findsNothing);
      expect(find.text('Condition counts can overlap.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'known Down and unknown-only status remain distinct when evidence overlaps',
    (tester) async {
      final cls = f.assetClass(
        id: 'bases',
        code: 'BASE',
        name: 'Base',
        legacyKey: 'base',
      );
      final assets = [
        for (var i = 1; i <= 3; i++)
          f.asset(id: 'base-$i', assetClass: cls, number: i),
      ];
      final rows = [
        PlantAssetState(
          asset: assets[0],
          operationalCondition: f.condition(
            asset: assets[0],
            condition: AssetOperationalCondition.down,
          ),
          availability: null,
          workflowStatus: null,
        ),
        PlantAssetState(
          asset: assets[1],
          operationalCondition: null,
          availability: null,
          workflowStatus: null,
        ),
        PlantAssetState(
          asset: assets[2],
          operationalCondition: null,
          availability: null,
          workflowStatus: f.workflow(key: 'base', number: 3),
        ),
      ];
      await _pump(
        tester,
        AsyncData(
          PlantAssetOverview(
            classes: [PlantAssetClassSummary(assetClass: cls, assets: rows)],
            assets: rows,
          ),
        ),
      );
      _expectCount(tester, 'available', 'bases', 1);
      _expectCount(tester, 'unavailable', 'bases', 1);
      _expectCount(tester, 'unverified', 'bases', 1);
      expect(
        find.textContaining(
          RegExp('evidence incomplete', caseSensitive: false),
        ),
        findsWidgets,
      );
      expect(find.textContaining(RegExp(r'^\d+%$')), findsNothing);
      final row = find.byKey(const ValueKey('plant-class-row-bases'));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.textContaining('Down 1: Base 1'), findsOneWidget);
      expect(
        find.textContaining('Evidence unverified 2: Base 1, Base 2'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expansion preserves other class positions and class navigation keeps its identity',
    (tester) async {
      final opens = <String>[];
      var wholeBoard = 0;
      await _pump(
        tester,
        AsyncData(homeClassOverviewFixture()),
        onOpen: () => wholeBoard++,
        onOpenClass: opens.add,
      );
      final row = find.byKey(const ValueKey('plant-class-row-bases'));
      final cooler = find.byKey(const ValueKey('plant-class-row-coolers'));
      final coolerTop = tester.getTopLeft(cooler).dy;
      expect(
        find.byKey(const ValueKey('plant-class-details-bases')),
        findsNothing,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plant-class-details-bases')),
        findsOneWidget,
      );
      expect(tester.getTopLeft(cooler).dy, coolerTop);
      expect(opens, isEmpty);
      expect(wholeBoard, 0);
      final openClass = find.byKey(const ValueKey('plant-class-open-bases'));
      await tester.ensureVisible(openClass);
      await tester.pumpAndSettle();
      await tester.tap(openClass);
      expect(opens, ['bases']);
      expect(wholeBoard, 0);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plant-class-details-bases')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'class details retain all canonical identities and original status reasons',
    (tester) async {
      final cls = f.assetClass(
        id: 'furnaces',
        code: 'FURNACE',
        name: 'Furnace',
        legacyKey: 'furnace',
      );
      final assets = [
        for (var i = 1; i <= 4; i++)
          f.asset(id: 'furnace-$i', assetClass: cls, number: i),
      ];
      final overview = PlantAssetOverview.build(
        assetClasses: [cls],
        assetInstances: assets,
        operationalConditions: [
          for (final asset in assets)
            f.condition(
              asset: asset,
              condition: AssetOperationalCondition.down,
            ),
        ],
        workflowStatuses: const [],
      );
      await _pump(tester, AsyncData(overview));
      expect(find.textContaining('Down 4: Furnace'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('plant-class-row-furnaces')));
      await tester.pumpAndSettle();
      expect(
        find.text('Down 4: Furnace 1, Furnace 2, Furnace 3, Furnace 4'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'whole Inner Cover detail is initially collapsed and independently toggles',
    (tester) async {
      var opens = 0;
      await _pump(
        tester,
        AsyncData(homeClassOverviewFixture()),
        onOpen: () => opens++,
      );
      final toggle = find.byKey(
        const ValueKey('plant-inner-cover-toggle-covers'),
      );
      expect(toggle, findsOneWidget);
      expect(
        find.byKey(const ValueKey('plant-inner-cover-details-covers')),
        findsNothing,
      );
      expect(
        find.text('Candidates need a physical check before use.'),
        findsNothing,
      );
      expect(find.text('Spare candidates 3'), findsNothing);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plant-inner-cover-details-covers')),
        findsOneWidget,
      );
      expect(find.text('Spare candidates 3'), findsOneWidget);
      expect(
        find.text('Candidates need a physical check before use.'),
        findsOneWidget,
      );
      expect(find.textContaining('Inner Cover DEMO-51:'), findsNothing);
      expect(opens, 0);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plant-inner-cover-details-covers')),
        findsNothing,
      );
      expect(opens, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in [
    (320.0, 1.0),
    (393.0, 1.0),
    (800.0, 1.0),
    (320.0, 2.5),
    (393.0, 2.5),
  ]) {
    testWidgets(
      'class overview and expanded details fit without truncation at $viewport',
      (tester) async {
        tester.view.physicalSize = Size(viewport.$1, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(
          tester,
          AsyncData(homeClassOverviewFixture(unverified: true)),
          scale: viewport.$2,
        );
        for (final id in ['bases', 'furnaces', 'coolers']) {
          final row = find.byKey(ValueKey('plant-class-row-$id'));
          final rect = tester.getRect(row);
          expect(rect.left, greaterThanOrEqualTo(16));
          expect(rect.right, lessThanOrEqualTo(viewport.$1 - 16));
          expect(rect.height, greaterThanOrEqualTo(48));
        }
        for (final key in [
          'plant-class-row-bases',
          'plant-inner-cover-toggle-covers',
        ]) {
          final control = find.byKey(ValueKey(key));
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          await tester.tap(control);
          await tester.pumpAndSettle();
        }
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.byType(RichText),
        )) {
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        expect(find.textContaining('Down 4:'), findsOneWidget);
        expect(find.text('Spare candidates 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'loading and unavailable data never manufacture zero availability',
    (tester) async {
      await _pump(tester, const AsyncLoading());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('plant-class-row-bases')), findsNothing);
      var opens = 0;
      await _pump(
        tester,
        AsyncError(StateError('malformed'), StackTrace.empty),
        onOpen: () => opens++,
      );
      final error = find.text(
        'Plant condition data needs attention. Open the board for details.',
      );
      expect(error, findsOneWidget);
      await tester.tap(error);
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<PlantAssetOverview> overview, {
  double scale = 1,
  VoidCallback? onOpen,
  ValueChanged<String>? onOpenClass,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: BafAppTheme.light.copyWith(
        textTheme: BafAppTheme.light.textTheme.apply(fontFamily: 'Roboto'),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PlantOverviewPanel(
            overview: overview,
            onOpen: onOpen ?? () {},
            onOpenClass: onOpenClass,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectCount(WidgetTester tester, String metric, String id, int value) {
  final keyed = find.byKey(ValueKey('plant-class-$metric-$id'));
  expect(keyed, findsOneWidget);
  final text = tester
      .widgetList<Text>(
        find.descendant(
          of: keyed,
          matching: find.byType(Text),
          matchRoot: true,
        ),
      )
      .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
      .join(' ');
  expect(text, matches(RegExp('(^|[^0-9])$value([^0-9]|\$)')));
}
