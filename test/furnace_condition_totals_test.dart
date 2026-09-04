import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/assets/presentation/furnace_component_condition_audit_screen.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/burner_block_lifecycle_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/burner_condition_round_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/uv_detector_lifecycle_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 4, 8);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Medium.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'tab totals count positions and summary distinguishes affected furnaces',
    (tester) async {
      await _pump(tester);
      expect(find.text('Burner blocks (3)'), findsOneWidget);
      expect(find.text('Draft seal (2)'), findsOneWidget);
      expect(find.text('UV melted (1)'), findsOneWidget);
      expect(find.text('UV missing (2)'), findsOneWidget);
      expect(find.text('UV hung (1)'), findsOneWidget);
      await tester.tap(find.byTooltip('Condition totals'));
      await tester.pumpAndSettle();
      expect(find.text('3 Furnaces / 2 with marked faults'), findsOneWidget);
      expect(find.text('1 without prior condition evidence'), findsOneWidget);
      expect(find.text('3 findings / 2 furnaces'), findsOneWidget);
      final copied = await _copy(tester);
      expect(copied, contains('Recorded condition findings'));
      expect(
        copied,
        contains('Red-hot burner blocks: 3 findings on 2 furnaces.'),
      );
      expect(copied, contains('UV missing: 2 findings on 2 furnaces.'));
      expect(
        copied,
        contains('not a declaration that unmarked positions are healthy'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ticking and unticking updates totals without recording the draft',
    (tester) async {
      await _pump(tester);
      await _tick(tester, 'block-furnace-1-1');
      expect(find.text('Burner blocks (2)'), findsOneWidget);
      await _tick(tester, 'block-furnace-1-1');
      expect(find.text('Burner blocks (3)'), findsOneWidget);
      await _tick(tester, 'block-furnace-1-3');
      expect(find.text('Burner blocks (4)'), findsOneWidget);
      expect(find.text('1 unsaved furnace'), findsOneWidget);
      await tester.tap(find.byTooltip('Condition totals'));
      await tester.pumpAndSettle();
      final copied = await _copy(tester);
      expect(
        copied,
        contains('Draft totals - includes unsaved changes on 1 furnace'),
      );
      expect(
        copied,
        contains('Red-hot burner blocks: 4 findings on 2 furnaces.'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UV totals transfer between mutually exclusive faulty cases', (
    tester,
  ) async {
    await _pump(tester);
    await _tab(tester, 'UV missing (2)');
    await _tick(tester, 'uv-missing-furnace-1-1');
    expect(find.text('UV melted (0)'), findsOneWidget);
    expect(find.text('UV missing (3)'), findsOneWidget);
    await _tab(tester, 'UV hung (1)');
    await _tick(tester, 'uv-hanging-furnace-1-1');
    expect(find.text('UV missing (2)'), findsOneWidget);
    expect(find.text('UV hung (2)'), findsOneWidget);
    await _tick(tester, 'uv-hanging-furnace-1-1');
    expect(find.text('UV hung (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft seal total counts both findings on the same furnace', (
    tester,
  ) async {
    await _pump(tester);
    await _tab(tester, 'Draft seal (2)');
    await _tick(tester, 'seal-furnace-1-1');
    expect(find.text('Draft seal (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('Condition totals'));
    await tester.pumpAndSettle();
    final copied = await _copy(tester);
    expect(copied, contains('Draft seal red hot: 0 findings on 0 furnaces.'));
    expect(copied, contains('Draft seal hot air: 1 finding on 1 furnace.'));
  });

  testWidgets(
    'new source evidence refreshes totals but retains unsaved selections',
    (tester) async {
      final rounds = StreamController<Map<String, BurnerConditionRound>>();
      addTearDown(rounds.close);
      rounds.add(_initialRounds());
      await _pump(tester, rounds: rounds.stream);
      await tester.pumpAndSettle();
      await _tick(tester, 'block-furnace-1-3');
      rounds.add({
        'furnace-1': _round(1, healthy: true),
        'furnace-2': _round(2, healthy: true),
      });
      await tester.pumpAndSettle();
      expect(find.text('Burner blocks (3)'), findsOneWidget);
      expect(find.text('UV missing (1)'), findsOneWidget);
      expect(find.text('1 unsaved furnace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source failure does not publish fabricated zero totals', (
    tester,
  ) async {
    await _pump(tester, rounds: Stream.error(StateError('unavailable')));
    expect(
      find.text('Current furnace condition authority could not be verified.'),
      findsOneWidget,
    );
    expect(find.text('Burner blocks (0)'), findsNothing);
    expect(find.byTooltip('Condition totals'), findsNothing);
  });

  for (final viewport in [
    (size: const Size(320, 720), scale: 2.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(900, 800), scale: 1.0),
  ]) {
    testWidgets('condition totals and matrix remain usable at $viewport', (
      tester,
    ) async {
      final boundary = GlobalKey();
      await _pump(
        tester,
        size: viewport.size,
        scale: viewport.scale,
        boundary: boundary,
      );
      expect(find.byTooltip('Condition totals').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('block-furnace-1-1')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_SCREEN_EVIDENCE')) {
        await _capture(
          tester,
          boundary,
          'matrix-${viewport.size.width.toInt()}-${viewport.scale}',
        );
      }
      await tester.tap(find.byTooltip('Condition totals'));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Copy condition totals').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_SCREEN_EVIDENCE')) {
        await _capture(
          tester,
          boundary,
          'totals-${viewport.size.width.toInt()}-${viewport.scale}',
        );
      }
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(800, 900),
  double scale = 1,
  Stream<Map<String, BurnerConditionRound>>? rounds,
  GlobalKey? boundary,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = BafAppTheme.light;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              uid: 'operations',
              name: 'Operations',
              email: 'test@example.com',
              roles: const [AppRole.operations],
              isApproved: true,
              createdAt: _now,
            ),
          ),
        ),
        assetClassesProvider.overrideWith(
          (ref) => Stream.value([
            AssetClassRecord(
              id: 'furnace-class',
              code: 'FURNACE',
              name: 'Furnace',
              majorArea: 'BAF',
              legacyAssetTypeKey: 'furnace',
              status: AssetHierarchyStatus.active,
              version: 1,
              createdAt: _now,
              createdByUid: 'admin',
              updatedAt: _now,
              updatedByUid: 'admin',
              lastMutationId: 'class',
            ),
          ]),
        ),
        allAssetInstancesProvider.overrideWith(
          (ref) => Stream.value([
            for (final number in [1, 2, 3, 27])
              AssetInstanceRecord(
                id: 'furnace-$number',
                assetClassId: 'furnace-class',
                assetClassCode: 'FURNACE',
                assetClassName: 'Furnace',
                assetNumber: number,
                name: 'Furnace $number',
                serviceState: AssetServiceState.inService,
                ownershipStatus: AssetOwnershipStatus.confirmed,
                ownerDiscipline: 'Operations',
                accountableRoleKeys: const ['operations'],
                status: AssetHierarchyStatus.active,
                activeComponentCount: 8,
                version: 1,
                createdAt: _now,
                updatedAt: _now,
                lastMutationId: 'asset-$number',
              ),
          ]),
        ),
        burnerBlockLifecycleEventsProvider.overrideWith(
          (ref, actor) => Stream.value([]),
        ),
        burnerBlockLifecycleCurrentProvider.overrideWith(
          (ref, actor) => Stream.value([]),
        ),
        uvDetectorLifecycleEventsProvider.overrideWith(
          (ref, actor) => Stream.value([]),
        ),
        uvDetectorLifecycleCurrentProvider.overrideWith(
          (ref, actor) => Stream.value([]),
        ),
        openTicketsProvider.overrideWith((ref) => Stream.value([])),
        latestBurnerConditionRoundsProvider.overrideWith(
          (ref, query) => rounds ?? Stream.value(_initialRounds()),
        ),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
            appBarTheme: theme.appBarTheme.copyWith(
              titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: 'Roboto',
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: theme.filledButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: theme.textButtonTheme.style?.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 24, bottom: 32),
                ),
                child: child!,
              ),
          home: const Scaffold(),
          initialRoute: '/audit',
          routes: {
            '/audit': (context) => const FurnaceComponentConditionAuditScreen(),
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> _tick(WidgetTester tester, String key) async {
  final checkbox = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(Checkbox),
  );
  await tester.ensureVisible(checkbox);
  await tester.tap(checkbox);
  await tester.pumpAndSettle();
}

Future<String> _copy(WidgetTester tester) async {
  String? copied;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.tap(find.byTooltip('Copy condition totals'));
  await tester.pumpAndSettle();
  return copied!;
}

Map<String, BurnerConditionRound> _initialRounds() => {
  'furnace-1': _round(1),
  'furnace-2': _round(2),
  'furnace-27': _round(27),
};

BurnerConditionRound _round(int number, {bool healthy = false}) =>
    BurnerConditionRound(
      roundId: 'round-$number-$healthy',
      assetClassId: 'furnace-class',
      assetClassCode: 'FURNACE',
      assetClassName: 'Furnace',
      assetInstanceId: 'furnace-$number',
      assetInstanceVersion: 1,
      assetNumber: number,
      assetName: 'Furnace $number',
      redHotPositions:
          healthy
              ? []
              : number == 1
              ? [1, 2]
              : [1],
      observations: [
        for (var position = 1; position <= 8; position++)
          BurnerConditionObservation(
            position: position,
            flameObservation: BurnerRoundFlameObservation.seen,
            redHotObserved:
                !healthy && (position == 1 || (number == 1 && position == 2)),
          ),
      ],
      microampPositions: [],
      draftSealRedHotObserved: !healthy && number == 1,
      hotAirAtDraftSealObserved: !healthy && number == 1,
      uvObservations: [
        for (var position = 1; position <= 8; position++)
          BurnerUvObservation(
            position: position,
            condition:
                healthy
                    ? BurnerUvCondition.serviceable
                    : switch ((number, position)) {
                      (1, 1) => BurnerUvCondition.melted,
                      (1, 2) || (2, 1) => BurnerUvCondition.missing,
                      (1, 3) => BurnerUvCondition.hanging,
                      _ => BurnerUvCondition.serviceable,
                    },
          ),
      ],
      observedAt: healthy ? _now.add(const Duration(hours: 1)) : _now,
      recordedByUid: 'operations',
      recordedByName: 'Operations',
      fingerprint: 'test',
    );

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('output/condition-totals-review-2026-09-04');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
