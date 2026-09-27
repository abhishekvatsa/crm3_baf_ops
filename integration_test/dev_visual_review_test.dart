// Read-only visual tour of the actual DEV app and local emulator records.
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/core/widgets/dashboard/dashboard_widgets.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart' show waitFor, goBack;
import 'dev_issue_quality_journey_test.dart'
    show showControl, tapControl, openMore;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('DEV visual review across operational screens', (tester) async {
    expect(crm3UseEmulators, isTrue);
    final oldFlutter = FlutterError.onError;
    final oldPlatform = PlatformDispatcher.instance.onError;
    try {
      await tester.runAsync(app.startCrmBafApp);
    } finally {
      FlutterError.onError = oldFlutter;
      PlatformDispatcher.instance.onError = oldPlatform;
    }
    expect(Firebase.app().options.projectId, 'demo-crm3-baf-ops');
    await waitFor(
      tester,
      () => find.byType(HomeScreen).evaluate().isNotEmpty,
      'Existing approved DEV session must reach Home',
    );
    final destination = Directory(
      '${(await getApplicationSupportDirectory()).path}/visual_review_20260927',
    );
    await destination.create(recursive: true);
    await binding.convertFlutterSurfaceToImage();

    Future<void> capture(String name) async {
      await tester.pump(const Duration(seconds: 1));
      final bytes = await binding.takeScreenshot(name);
      await File('${destination.path}/$name.png').writeAsBytes(bytes);
      // Save images in the DEV sandbox, not in a very large test protocol reply.
      binding.reportData?.remove('screenshots');
      debugPrint('DEV_VISUAL_SCREEN ${destination.path}/$name.png');
      expect(
        tester.takeException(),
        isNull,
        reason: '$name must render cleanly',
      );
    }

    await tester.tap(find.text('Home'));
    await capture('01-home');
    await showControl(tester, find.text('Management pulse'));
    await capture('02-home-pulse');
    await tester.tap(find.text('Issues'));
    await capture('03-issues');

    await openMore(tester, 'Directives');
    await waitFor(
      tester,
      () => find
          .byKey(const ValueKey('directives-status-filter'))
          .evaluate()
          .isNotEmpty,
      'Directive controls must finish loading',
    );
    await capture('04-directives');
    await goBack(tester);

    await openMore(tester, 'Quality');
    await waitFor(
      tester,
      () => find
          .byKey(const ValueKey('quality-warning-status-filter'))
          .evaluate()
          .isNotEmpty,
      'Quality controls must finish loading',
    );
    await capture('05-quality');
    await goBack(tester);

    await openMore(tester, 'Abnormalities');
    final reportCard = find.ancestor(
      of: find.text('Reports / Intelligence'),
      matching: find.byType(DashboardCard),
    );
    await tapControl(
      tester,
      find.descendant(of: reportCard, matching: find.text('Open')),
    );
    await waitFor(
      tester,
      () => find.text('Matching').evaluate().isNotEmpty,
      'Abnormality browsing must finish loading',
    );
    await capture('06-abnormalities');
    await goBack(tester);
    await goBack(tester);

    await openMore(tester, 'Plant condition');
    await waitFor(
      tester,
      () => find.textContaining('recorded assets').evaluate().isNotEmpty,
      'Plant inventory must finish loading',
    );
    await capture('07-plant');
    await goBack(tester);

    await openMore(tester, 'Burner reliability');
    await waitFor(
      tester,
      () => find.text('Lockout reports').evaluate().isNotEmpty,
      'Burner report must finish loading',
    );
    await capture('08-burner');
    await goBack(tester);

    await openMore(tester, 'Operations intelligence');
    await waitFor(
      tester,
      () => find.text('Scope and period').evaluate().isNotEmpty,
      'Operations report must finish loading',
    );
    await capture('09-reports');
    await goBack(tester);
    await tester.tap(find.text('Work'));
    await capture('11-work');
    await tester.tap(find.text('More'));
    await capture('12-more');
    await openMore(tester, 'Raise issue');
    await capture('10-issue-form');
    debugPrint('DEV_VISUAL_REVIEW_PASS');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
