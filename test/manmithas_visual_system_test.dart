import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/brand/brand_widgets.dart';
import 'package:crm3_baf_ops/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand identity and operational geometry remain intentional', () {
    expect(BafBrand.productName, 'CRM-III BAF Ops');
    expect(BafBrand.makerName, 'A ManMithas Productions');
    expect(BafBrand.markAsset, 'assets/brand/manmithas_mark.png');
    expect(BafRadius.small, lessThanOrEqualTo(8));
    expect(BafRadius.medium, lessThanOrEqualTo(8));
    expect(BafRadius.large, lessThanOrEqualTo(8));
    expect(BafRadius.xLarge, lessThanOrEqualTo(8));
  });

  testWidgets('login identity fits a narrow phone without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: BafAppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ManmithasMark), findsOneWidget);
    expect(find.text(BafBrand.productName), findsOneWidget);
    expect(find.text(BafBrand.plantName), findsOneWidget);
    expect(find.text(BafBrand.makerLabel), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    final systemStyle =
        tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .value;
    expect(systemStyle.statusBarIconBrightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feature title and brand lockup adapt at phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(
          appBar: AppBar(
            title: const BafAppBarTitle(
              title: 'Operational events',
              subtitle: 'Utilities, cranes, transfer cars and delays',
              icon: Icons.crisis_alert_outlined,
              accent: BafColors.warning,
            ),
          ),
          body: const Padding(
            padding: EdgeInsets.all(BafSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BafBrandLockup(compact: true),
                SizedBox(height: BafSpacing.lg),
                BafPageHeader(
                  title: 'Plant condition',
                  subtitle: 'Live availability and maintenance state',
                  icon: Icons.precision_manufacturing_outlined,
                  accent: BafColors.assets,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operational events'), findsOneWidget);
    expect(find.text('Plant condition'), findsOneWidget);
    expect(find.byType(ManmithasMark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
