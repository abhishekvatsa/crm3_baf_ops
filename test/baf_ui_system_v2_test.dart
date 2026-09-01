import 'dart:io';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/baf_ui.dart';
import 'package:crm3_baf_ops/core/widgets/dashboard/dashboard_widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BAF UI system v2', () {
    test('every modal sheet declares route-level safe-area behavior', () {
      final failures = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final call = RegExp(r'showModalBottomSheet(?:<[^>]+>)?\s*\(');
      final safeArea = RegExp(r'useSafeArea\s*:\s*true');

      for (final file in files) {
        final source = file.readAsStringSync();
        for (final match in call.allMatches(source)) {
          final end = (match.start + 360).clamp(0, source.length);
          if (!safeArea.hasMatch(source.substring(match.start, end))) {
            final line =
                '\n'.allMatches(source.substring(0, match.start)).length + 1;
            failures.add('${file.path}:$line');
          }
        }
      }

      expect(
        failures,
        isEmpty,
        reason:
            'Modal sheets missing useSafeArea: true: ${failures.join(', ')}',
      );
    });

    test('form dropdowns use their available width', () {
      final failures = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final dropdown = RegExp(r'DropdownButtonFormField(?:<[^>]+>)?\s*\(');
      final expanded = RegExp(r'isExpanded\s*:\s*true');

      for (final file in files) {
        final source = file.readAsStringSync();
        for (final match in dropdown.allMatches(source)) {
          final end = (match.start + 650).clamp(0, source.length);
          if (!expanded.hasMatch(source.substring(match.start, end))) {
            final line =
                '\n'.allMatches(source.substring(0, match.start)).length + 1;
            failures.add('${file.path}:$line');
          }
        }
      }

      expect(
        failures,
        isEmpty,
        reason:
            'Form dropdowns missing isExpanded: true: ${failures.join(', ')}',
      );
    });

    test('large dialog bodies use responsive height constraints', () {
      final failures = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final dialog = RegExp(r'AlertDialog\s*\(');
      final fixedHeight = RegExp(r'height\s*:\s*([2-9]\d{2,})');

      for (final file in files) {
        final source = file.readAsStringSync();
        for (final match in dialog.allMatches(source)) {
          final end = (match.start + 2400).clamp(0, source.length);
          if (fixedHeight.hasMatch(source.substring(match.start, end))) {
            final line =
                '\n'.allMatches(source.substring(0, match.start)).length + 1;
            failures.add('${file.path}:$line');
          }
        }
      }

      expect(
        failures,
        isEmpty,
        reason:
            'Dialog bodies with fixed phone-unsafe heights: ${failures.join(', ')}',
      );
    });

    for (final size in <Size>[
      const Size(320, 700),
      const Size(412, 915),
      const Size(900, 700),
    ]) {
      testWidgets('shared page primitives remain stable at ${size.width}px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: BafAppTheme.light,
            home: Scaffold(
              body: BafContentFrame(
                child: ListView(
                  children: [
                    const BafScreenIntro(
                      title: 'Equipment availability and maintenance state',
                      subtitle:
                          'Authoritative workflow facts, operational readiness and accountable recovery.',
                      icon: Icons.precision_manufacturing_outlined,
                      accent: BafColors.assets,
                      trailing: Chip(label: Text('47 assets')),
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    BafSearchField(
                      hintText: 'Search asset, component or responsibility',
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    const BafRecordSurface(
                      accent: BafColors.warning,
                      child: Text(
                        'Base 201 requires operational support before maintenance can continue.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('47 assets'), findsOneWidget);
        expect(find.byType(BafSearchField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('state panel exposes a clear recovery action', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: Scaffold(
            body: BafStatePanel.error(
              title: 'Workflow state is unavailable',
              message: 'The latest governed projection could not be loaded.',
              onPrimary: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'long segmented controls scroll instead of squeezing at phone width',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: BafAppTheme.light,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(BafSpacing.md),
                child: BafHorizontalControlRail(
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 1, label: Text('Numeric reading')),
                      ButtonSegment(value: 2, label: Text('Boolean result')),
                      ButtonSegment(value: 3, label: Text('Narrative text')),
                      ButtonSegment(value: 4, label: Text('Governed choice')),
                    ],
                    selected: const {1},
                    onSelectionChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(BafHorizontalControlRail),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('dialog bodies surrender height to the keyboard', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      double? measured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              measured = bafDialogBodyHeight(
                context,
                preferred: 420,
                minimum: 120,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(measured, 160);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dialog bodies fit below the readability floor', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 320);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      double? measured;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              measured = bafDialogBodyHeight(
                context,
                preferred: 420,
                minimum: 180,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(measured, 100);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shared surfaces tolerate enlarged text on a narrow phone', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: BafStatePanel(
                icon: Icons.fact_check_outlined,
                color: BafColors.directives,
                title: 'No actionable compliance obligations',
                message:
                    'Nothing currently needs acknowledgement, completion or supervisory review in this lane.',
                primaryLabel: 'Refresh obligations',
                primaryIcon: Icons.refresh_rounded,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Refresh obligations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('state panels scroll instead of overflowing short viewports', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 230));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
          home: Scaffold(
            body: BafStatePanel.error(
              title: 'Workflow state requires attention',
              message:
                  'The governed projection could not be loaded. Review the connection and retry without losing the recorded evidence.',
              onPrimary: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.ensureVisible(find.text('Try again'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    for (final size in <Size>[
      const Size(320, 700),
      const Size(412, 915),
      const Size(1024, 768),
    ]) {
      testWidgets('screen shell and all governed states fit at ${size.width}px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: BafAppTheme.light,
            home: BafScreenScaffold(
              title: 'Maintenance intelligence',
              subtitle: 'Due state, governed plans and completion history',
              icon: Icons.event_repeat_rounded,
              accent: BafColors.planned,
              actions: [
                IconButton(
                  tooltip: 'Refresh maintenance intelligence',
                  onPressed: () {},
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
              body: ListView(
                children: const [
                  BafLoadingPanel(label: 'Loading governed maintenance state'),
                  BafStatePanel(
                    icon: Icons.lock_outline_rounded,
                    color: BafColors.danger,
                    title: 'Approved authority required',
                    message:
                        'An approved maintenance role is required to continue.',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Maintenance intelligence'), findsOneWidget);
        expect(
          find.byTooltip('Refresh maintenance intelligence'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('app-bar identity remains stable at 200 percent text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 700),
                  textScaler: TextScaler.linear(2),
                ),
                child: child!,
              ),
          home: const BafScreenScaffold(
            title: 'Inspection programmes',
            subtitle: 'Component evidence across selected assets',
            icon: Icons.fact_check_outlined,
            accent: BafColors.instrument,
            body: BafStatePanel(
              icon: Icons.inbox_outlined,
              color: BafColors.instrument,
              title: 'No active programmes',
              message: 'There are no inspection campaigns in this view.',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Inspection programmes'), findsOneWidget);
      expect(
        find.text('Component evidence across selected assets'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    test('surface depth and text contrast remain materially distinct', () {
      expect(BafColors.background, isNot(BafColors.surfaceTint));
      expect(BafColors.surfaceTint, isNot(BafColors.surfaceRaised));
      expect(
        BafShadows.raised.single.blurRadius,
        greaterThan(BafShadows.soft.single.blurRadius),
      );
      expect(
        BafShadows.soft.single.blurRadius,
        greaterThan(BafShadows.subtle.single.blurRadius),
      );
      expect(
        _contrastRatio(BafColors.textPrimary, BafColors.surfaceRaised),
        greaterThanOrEqualTo(7),
      );
      expect(
        _contrastRatio(BafColors.textSecondary, BafColors.surfaceRaised),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(Colors.white, BafColors.graphite),
        greaterThanOrEqualTo(7),
      );
      for (final statusColor in <Color>[
        BafColors.sync,
        BafColors.warning,
        BafColors.danger,
      ]) {
        expect(
          _contrastRatio(
            Color.lerp(statusColor, Colors.white, 0.48)!,
            BafColors.graphite,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    testWidgets('filled icon actions retain high-contrast foregrounds', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: Scaffold(
            body: Row(
              children: [
                IconButton.filled(
                  key: const ValueKey('filled-icon-action'),
                  onPressed: () {},
                  icon: const Icon(Icons.add_rounded),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('tonal-icon-action'),
                  onPressed: () {},
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
          ),
        ),
      );

      Color iconColorFor(Key key) {
        final iconFinder = find.descendant(
          of: find.byKey(key),
          matching: find.byType(Icon),
        );
        return IconTheme.of(tester.element(iconFinder)).color!;
      }

      final filledColor = iconColorFor(const ValueKey('filled-icon-action'));
      final tonalColor = iconColorFor(const ValueKey('tonal-icon-action'));

      expect(filledColor, isNot(BafColors.textSecondary));
      expect(tonalColor, isNot(BafColors.textSecondary));
      expect(tester.takeException(), isNull);
    });

    test('filled feature actions declare an explicit contrast pair', () {
      const paths = <String>[
        'lib/features/inspections/presentation/'
            'inspection_programmes_screen.dart',
        'lib/features/morning_review/presentation/morning_review_screen.dart',
        'lib/features/maintenance/presentation/'
            'maintenance_ticket_detail_screen.dart',
      ];

      for (final path in paths) {
        final source = File(path).readAsStringSync();
        final matches = RegExp(r'IconButton\.filledTonal\(').allMatches(source);
        expect(matches, isNotEmpty, reason: path);
        for (final match in matches) {
          final candidateEnd = match.start + 700;
          final declaration = source.substring(
            match.start,
            candidateEnd < source.length ? candidateEnd : source.length,
          );
          expect(declaration, contains('backgroundColor:'), reason: path);
          expect(
            declaration,
            contains('foregroundColor: Colors.white'),
            reason: path,
          );
        }
      }
    });

    testWidgets('screen context rail and solid canvas have stable geometry', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: const BafScreenScaffold(
            title: 'Asset condition',
            subtitle: 'Operational readiness by equipment class',
            icon: Icons.precision_manufacturing_outlined,
            accent: BafColors.assets,
            body: SizedBox.expand(),
          ),
        ),
      );

      expect(tester.getSize(find.byType(BafContextRail)).height, 3);
      expect(tester.getSize(find.byType(BafContextRail)).width, 320);
      expect(find.byType(BafPageCanvas), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('full-screen states scroll at accessibility text sizes', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(640, 260));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
          home: BafScreenStateScaffold.error(
            appBarTitle: 'Maintenance intelligence',
            appBarSubtitle: 'Governed evidence and recommendations',
            appBarIcon: Icons.analytics_outlined,
            message:
                'The current evidence could not be opened safely. '
                'Review the connection and try the governed read again.',
            onRetry: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.ensureVisible(find.text('Try again'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('interactive records gain depth without changing geometry', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: BafRecordSurface(
                  accent: BafColors.assets,
                  onTap: () {},
                  child: const Text('Furnace 12 - ready for operation'),
                ),
              ),
            ),
          ),
        ),
      );

      final surface = find.byType(BafRecordSurface);
      final initialRect = tester.getRect(surface);
      final initial = tester.widget<AnimatedContainer>(
        find.descendant(of: surface, matching: find.byType(AnimatedContainer)),
      );
      final initialDecoration = initial.decoration! as BoxDecoration;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(initialRect.center);
      await tester.pump(BafMotion.standard);

      final highlighted = tester.widget<AnimatedContainer>(
        find.descendant(of: surface, matching: find.byType(AnimatedContainer)),
      );
      final highlightedDecoration = highlighted.decoration! as BoxDecoration;

      expect(tester.getRect(surface), initialRect);
      expect(
        highlightedDecoration.boxShadow!.single.blurRadius,
        greaterThan(initialDecoration.boxShadow!.single.blurRadius),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('industrial header treatment remains quiet at phone width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(BafSpacing.md),
              child: BafDarkHeaderSurface(
                child: Row(
                  children: [
                    Icon(Icons.factory_outlined, color: Colors.white),
                    SizedBox(width: BafSpacing.md),
                    Expanded(
                      child: Text(
                        'Shift overview',
                        style: TextStyle(color: Colors.white, fontSize: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Shift overview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dashboard identity and actions occupy two stable phone rows', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 260));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(BafSpacing.md),
              child: DashboardHeader(
                userName: 'Abhishek Vatsa',
                avatar: const CircleAvatar(child: Text('A')),
                syncIndicator: Container(
                  width: 96,
                  height: 30,
                  alignment: Alignment.center,
                  child: const Text('Sync now'),
                ),
                onProfileTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final header = tester.getRect(find.byType(DashboardHeader));
      final profile = tester.getRect(
        find.byKey(const ValueKey('dashboard-profile-action')),
      );
      final brand = tester.getRect(
        find.byKey(const ValueKey('dashboard-brand-lockup')),
      );
      final sync = tester.getRect(
        find.byKey(const ValueKey('dashboard-sync-action')),
      );
      final title = tester.getRect(
        find.byKey(const ValueKey('dashboard-shift-title')),
      );
      final productName = tester.renderObject<RenderParagraph>(
        find.text(BafBrand.productName),
      );
      final makerName = tester.renderObject<RenderParagraph>(
        find.text(BafBrand.makerLabel),
      );

      expect(
        header.right - profile.right,
        lessThanOrEqualTo(BafSpacing.lg + 1.1),
      );
      expect(sync.top, greaterThan(profile.bottom));
      expect(sync.right, closeTo(profile.right, 0.1));
      expect((sync.center.dy - title.center.dy).abs(), lessThan(8));
      expect(
        productName.didExceedMaxLines,
        isFalse,
        reason:
            'product=${productName.size}, constraints=${productName.constraints}, brand=$brand',
      );
      expect(makerName.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });

    test('migrated operational surfaces use the shared page language', () {
      const paths = <String>[
        'lib/features/maintenance_workflow/presentation/screens/'
            'equipment_status_board.dart',
        'lib/features/maintenance_workflow/presentation/screens/'
            'lane_classification_screen.dart',
        'lib/features/maintenance_workflow/presentation/screens/'
            'compliance_inbox_screen.dart',
        'lib/features/maintenance_workflow/presentation/screens/'
            'compliance_detail_screen.dart',
        'lib/features/maintenance_workflow/presentation/screens/'
            'workflow_diagnostics_screen.dart',
      ];

      for (final path in paths) {
        final source = File(path).readAsStringSync();
        expect(source, contains('BafAppBarTitle('), reason: path);
        expect(source, contains('BafContentFrame('), reason: path);
      }
    });

    test('primary creation does not float over directive records', () {
      final source =
          File(
            'lib/features/directives/presentation/directives_screen.dart',
          ).readAsStringSync();

      expect(source, contains("label: const Text('New Directive')"));
      expect(source, contains('onCreate:'));
      expect(source, isNot(contains('FloatingActionButton')));
      expect(source, isNot(contains('Positioned(')));
    });

    test('operational events exposes one stable creation control', () {
      final source =
          File(
            'lib/features/operational_events/presentation/'
            'operational_events_screen.dart',
          ).readAsStringSync();

      expect(source, contains("ValueKey('operational-events-add')"));
      expect(source, contains("label: const Text('Add event')"));
      expect(source, isNot(contains("tooltip: 'Record event'")));
      expect(source, isNot(contains('FloatingActionButton')));
    });

    test('user-facing screens cannot regress to legacy shell states', () {
      final files = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('_screen.dart') ||
                file.path.endsWith('_form.dart'),
          );
      final plainAppBarTitle = RegExp(
        r'appBar\s*:\s*AppBar\([\s\S]{0,180}?title\s*:\s*(?:const\s+)?Text\(',
      );
      final bareStateScaffold = RegExp(
        r'Scaffold\([\s\S]{0,220}?body\s*:\s*(?:const\s+)?Center\('
        r'[\s\S]{0,120}?(?:CircularProgressIndicator|Text)\(',
      );

      for (final file in files) {
        final source = file.readAsStringSync();
        expect(
          plainAppBarTitle.hasMatch(source),
          isFalse,
          reason: '${file.path} uses a plain text app-bar identity',
        );
        expect(
          bareStateScaffold.hasMatch(source),
          isFalse,
          reason: '${file.path} uses a bare full-screen state',
        );
      }
    });

    test('display typography does not use ad-hoc letter spacing', () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final expression = RegExp(r'letterSpacing\s*:\s*(-?\d+(?:\.\d+)?)');

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        for (final match in expression.allMatches(source)) {
          expect(
            double.parse(match.group(1)!),
            0,
            reason: '${file.path} uses non-system letter spacing',
          );
        }
      }
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter =
      first.computeLuminance() > second.computeLuminance()
          ? first.computeLuminance()
          : second.computeLuminance();
  final darker =
      first.computeLuminance() > second.computeLuminance()
          ? second.computeLuminance()
          : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
