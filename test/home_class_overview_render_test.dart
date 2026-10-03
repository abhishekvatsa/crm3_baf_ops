import 'dart:io';
import 'dart:ui' as ui;
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/test_support/home_class_overview_fixture.dart';

const _evidenceDirectory = String.fromEnvironment('HOME_CLASS_EVIDENCE_DIR');

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
  for (final viewport in [
    (320.0, 1.0),
    (393.0, 1.0),
    (800.0, 1.0),
    (320.0, 2.5),
    (393.0, 2.5),
  ]) {
    testWidgets(
      'real Home widgets render collapsed and expanded at $viewport',
      (tester) async {
        tester.view.physicalSize = Size(viewport.$1, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        final overview = homeClassOverviewFixture();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _renderTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(viewport.$2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: capture,
                  child: ColoredBox(
                    color: BafColors.background,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Home',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Synthetic inventory · actual Flutter widgets',
                            style: TextStyle(
                              fontSize: 11,
                              color: BafColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          HomeCommandBar(
                            onRaiseIssue: () {},
                            onPlantCondition: () {},
                            onReports: () {},
                            onControl: () {},
                            onMorningReview: () {},
                          ),
                          const SizedBox(height: 16),
                          PlantOverviewPanel(
                            overview: AsyncData(overview),
                            onOpen: () {},
                            onOpenClass: (_) {},
                          ),
                          const SizedBox(height: 16),
                          HomeManagementPulsePanel(
                            plantOverview: AsyncData(overview),
                            dataUnavailable: false,
                            onOpenReports: () {},
                            onPlantCondition: () {},
                            onOpenClass: (_) {},
                            onIssues: () {},
                            onWork: () {},
                            onControl: () {},
                            onQualityMonitoring: () {},
                            onRetry: () {},
                            onMaintenanceRhythm: () {},
                            onInspectionProgrammes: () {},
                            ticketCount: 4,
                            executionCount: 2,
                            directiveCount: 0,
                            workflowAttentionCount: 0,
                            openOperationalEventCount: 0,
                            openQualityWarningCount: 0,
                            activeQualityMonitoringCount: 2,
                            overdueMaintenanceCount: 0,
                            activeInspectionFindingCount: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plant-inner-cover-details-covers')),
          findsNothing,
        );
        _checkParagraphs(tester);
        _checkReadableWords(tester);
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          capture,
          'home-${viewport.$1.toInt()}-scale-${viewport.$2}-collapsed',
        );
        final classRow = find.byKey(const ValueKey('plant-class-row-bases'));
        await tester.ensureVisible(classRow);
        await tester.pumpAndSettle();
        await tester.tap(classRow);
        await tester.pumpAndSettle();
        final covers = find.byKey(
          const ValueKey('plant-inner-cover-toggle-covers'),
        );
        await tester.ensureVisible(covers);
        await tester.pumpAndSettle();
        await tester.tap(covers);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plant-inner-cover-details-covers')),
          findsOneWidget,
        );
        expect(
          find.text('Candidates need a physical check before use.'),
          findsOneWidget,
        );
        _checkParagraphs(tester);
        _checkReadableWords(tester);
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          capture,
          'home-${viewport.$1.toInt()}-scale-${viewport.$2}-expanded',
        );
      },
    );
  }
}

void _checkParagraphs(WidgetTester tester) {
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: paragraph.text.toPlainText(),
    );
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (_evidenceDirectory.isEmpty) return;
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_evidenceDirectory).create(recursive: true);
    await File(
      '$_evidenceDirectory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

// Flutter tests replace the platform default font with Ahem. Explicit button
// styles in the app deliberately inherit that platform default; substitute the
// bundled Android font here while preserving every button layout/style value.
ThemeData _renderTheme() {
  final base = BafAppTheme.light;
  ButtonStyle buttonFont(ButtonStyle? style) =>
      (style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) => (style?.textStyle?.resolve(states) ?? const TextStyle())
              .copyWith(fontFamily: 'Roboto'),
        ),
      );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    filledButtonTheme: FilledButtonThemeData(
      style: buttonFont(base.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonFont(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: buttonFont(base.textButtonTheme.style),
    ),
  );
}

void _checkReadableWords(WidgetTester tester) {
  // Wrapping at spaces is useful at large text; splitting a heading's word
  // because an adjacent count consumed its width is not a readable layout.
  for (final (label, word) in [
    ('Plant condition', 'condition'),
    ('Management pulse', 'Management'),
    ('Furnaces', 'Furnaces'),
    ('Forced coolers', 'Forced'),
    ('Forced coolers', 'coolers'),
    ('47 registered', 'registered'),
  ]) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
    final start = label.indexOf(word);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + word.length),
    );
    expect(
      boxes.map((box) => box.top).toSet(),
      hasLength(1),
      reason: '$label must wrap between words, not split $word',
    );
  }
}
