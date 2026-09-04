import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/charge_abnormalities_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormalities_home_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_reports_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_types_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  for (final page in [
    (
      screen: const AbnormalitiesHomeScreen(),
      title: 'Operational abnormality memory',
    ),
    (
      screen: const AbnormalityTypesScreen(),
      title: 'Operational abnormality master',
    ),
    (
      screen: const AbnormalityReportsScreen(),
      title: 'Abnormality intelligence',
    ),
  ]) {
    testWidgets('${page.title} is readable and scrolls at large phone text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          boundary: GlobalKey(),
          scale: 2,
          records: Stream.value(List.generate(8, _record)),
          home: page.screen,
        ),
      );
      await tester.pumpAndSettle();
      final title = find.text(page.title);
      expect(
        tester.renderObject<RenderBox>(title).constraints.maxWidth,
        greaterThan(150),
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(title.hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in [
    (size: const Size(320, 640), scale: 1.0),
    (size: const Size(390, 844), scale: 1.6),
    (size: const Size(320, 720), scale: 2.0),
    (size: const Size(800, 720), scale: 1.0),
  ]) {
    testWidgets('charge record scroll and readable width at $viewport', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(viewport.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final boundary = GlobalKey();
      await tester.pumpWidget(
        _app(
          boundary: boundary,
          scale: viewport.scale,
          records: Stream.value(List.generate(8, _record)),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.text('Charge 51139');
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderBox>(title).constraints.maxWidth,
        greaterThan(150),
      );
      expect(
        tester.getSize(title).height,
        lessThanOrEqualTo(50 * viewport.scale),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('charge-abnormalities-summary')))
            .height,
        lessThan(250),
      );
      final scrollable = find.byType(Scrollable).first;
      final start = tester.getTopLeft(title).dy;
      await tester.drag(scrollable, const Offset(0, -420));
      await tester.pumpAndSettle();
      if (title.evaluate().isNotEmpty) {
        expect(tester.getTopLeft(title).dy, lessThan(start - 250));
      }
      expect(title.hitTestable(), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      final recordTitle = find.text('H2 ingress during cooling 0');
      expect(
        tester.renderObject<RenderBox>(recordTitle).constraints.maxWidth,
        greaterThan(200),
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_SCREEN_EVIDENCE')) {
        final state = tester.state<ScrollableState>(scrollable);
        state.position.jumpTo(0);
        await tester.pumpAndSettle();
        await _capture(
          tester,
          boundary,
          'charge-${viewport.size.width.toInt()}-${viewport.scale}',
        );
      }
    });
  }

  testWidgets('charge action remains reachable during loading and failure', (
    tester,
  ) async {
    final records = StreamController<List<ChargeAbnormality>>();
    addTearDown(records.close);
    await tester.pumpWidget(
      _app(boundary: GlobalKey(), scale: 1, records: records.stream),
    );
    await tester.pump();
    expect(find.text('Log Abnormality').hitTestable(), findsOneWidget);
    records.addError(StateError('Read temporarily unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load abnormalities'), findsOneWidget);
    expect(find.text('Log Abnormality').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required GlobalKey boundary,
  required double scale,
  required Stream<List<ChargeAbnormality>> records,
  Widget home = const ChargeAbnormalitiesScreen(sourceChargeNo: 51139),
}) => ProviderScope(
  overrides: [
    currentAppUserProvider.overrideWith(
      (ref) => Stream.value(
        AppUser(
          uid: 'layout-admin',
          name: 'Admin',
          email: 'admin@example.test',
          roles: const [AppRole.admin],
          isApproved: true,
          createdAt: DateTime(2026),
        ),
      ),
    ),
    abnormalitiesForChargeProvider.overrideWith((ref, charge) => records),
    activeAbnormalityTypesProvider.overrideWith(
      (ref) => Stream.value(_types()),
    ),
    allAbnormalityTypesProvider.overrideWith((ref) => Stream.value(_types())),
    abnormalityRepositoryProvider.overrideWithValue(_ReportRepository()),
  ],
  child: RepaintBoundary(
    key: boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BafAppTheme.light.copyWith(
        textTheme: BafAppTheme.light.textTheme.apply(fontFamily: 'Roboto'),
        filledButtonTheme: FilledButtonThemeData(
          style: BafAppTheme.light.filledButtonTheme.style?.copyWith(
            textStyle: WidgetStatePropertyAll(
              BafAppTheme.light.filledButtonTheme.style?.textStyle
                  ?.resolve({})
                  ?.copyWith(fontFamily: 'Roboto'),
            ),
          ),
        ),
        chipTheme: BafAppTheme.light.chipTheme.copyWith(
          labelStyle: BafAppTheme.light.chipTheme.labelStyle?.copyWith(
            fontFamily: 'Roboto',
          ),
        ),
        appBarTheme: BafAppTheme.light.appBarTheme.copyWith(
          titleTextStyle: BafAppTheme.light.appBarTheme.titleTextStyle
              ?.copyWith(fontFamily: 'Roboto'),
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
      home: const Scaffold(body: SizedBox()),
      initialRoute: '/reviewed-screen',
      routes: {'/reviewed-screen': (context) => home},
    ),
  ),
);

List<AbnormalityType> _types() => List.generate(
  6,
  (index) =>
      AbnormalityType()
        ..firestoreId = 'layout-type-$index'
        ..code = 'QC$index'
        ..title = 'Observed process condition $index'
        ..category = AbnormalityCategory.process
        ..severity = AbnormalitySeverity.high
        ..isActive = true
        ..createdAt = DateTime(2026)
        ..updatedAt = DateTime(2026),
);

class _ReportRepository extends Fake implements AbnormalityRepository {
  @override
  Future<List<ChargeAbnormality>> getAllAbnormalities() async =>
      List.generate(8, _record);
}

ChargeAbnormality _record(int index) =>
    ChargeAbnormality()
      ..firestoreId = 'layout-case-$index'
      ..sourceChargeNo = 51139
      ..abnormalityTypeCode = 'QC03'
      ..abnormalityTypeTitle = 'H2 ingress during cooling $index'
      ..observedReason =
          'Coil colour observed after unloading. Awaiting RA decision.'
      ..category = AbnormalityCategory.process
      ..severity = AbnormalitySeverity.high
      ..reannealingStatus = ReannealingStatus.required
      ..loggedAt = DateTime(2026, 9, 4, 8, 30)
      ..updatedAt = DateTime(2026, 9, 4, 8, 30);

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('output/charge-screen-review-2026-09-04');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
