// Finish the already accepted phone-created cases from the September 26 run.
// Run with CRM_DEV_EMAIL=dev.quality-si@example.invalid after signed-out state.
// This does not replace or recreate any business record.
import 'dart:ui' show PlatformDispatcher;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;
import 'dev_abnormality_journey_test.dart' show waitFor, field;
import 'dev_issue_quality_journey_test.dart' as journey;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'SI adjudicates the exact previously phone-created cases',
    (tester) async {
      expect(crm3UseEmulators, isTrue);
      final error = FlutterError.onError;
      final platformError = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        FlutterError.onError = error;
        PlatformDispatcher.instance.onError = platformError;
      }
      expect(Firebase.app().options.projectId, 'demo-crm3-baf-ops');
      await waitFor(
        tester,
        () =>
            find.text('Sign in with Google').evaluate().isNotEmpty ||
            find.byType(HomeScreen).evaluate().isNotEmpty,
        'Reach approved home or sign-in',
      );
      if (find.text('Sign in with Google').evaluate().isNotEmpty) {
        await tester.tap(find.text('Sign in with Google'));
      }
      await waitFor(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'Approved SI home',
      );
      expect(
        FirebaseAuth.instance.currentUser?.email,
        'dev.quality-si@example.invalid',
      );
      const charge = 76575;
      const first = '19e0b4c9-cbf9-4d3d-84e7-3ecb56fcf694';
      const second = '64d59b55-954b-43f1-8be7-8d5843c3e168';
      const plain = '364f643a-c590-4faf-82b3-2c7267af28eb';
      const completed = '181c19c6-c2c7-4d13-80e7-e4e86a690b2d';
      expect(
        (await journey.read('quality_warnings/issue_$first'))['status'],
        'open',
      );
      expect(
        (await journey.read('quality_warnings/issue_$second'))['status'],
        'closureRequested',
      );
      expect(
        (await journey.read(
          'charge_abnormalities/issue_quality_$second',
        ))['reannealedToChargeNo'],
        76576,
      );
      await journey.openQuality(tester);
      await journey.warningAction(
        tester,
        'PHONE $charge maintenance acceptable',
        'Adjudicate',
      );
      expect(find.text('Coil found acceptable'), findsOneWidget);
      await journey.enter(
        tester,
        'Decision evidence',
        'PHONE $charge SI examination confirms acceptable coil; RA not required',
      );
      await journey.tapControl(tester, find.text('Close warning'));
      await journey.awaitRecord(
        tester,
        'quality_warnings/issue_$first',
        (d) => d['status'] == 'closed',
      );
      expect(
        (await journey.read(
          'charge_abnormalities/issue_quality_$first',
        ))['reannealingStatus'],
        'notRequired',
      );
      await journey.filter(tester, 'Review');
      await journey.warningAction(
        tester,
        'PHONE $charge maintenance RA',
        'Adjudicate',
      );
      expect(find.text('Re-annealing completed'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('RA charge number')).readOnly,
        isTrue,
      );
      expect(
        tester.widget<TextField>(field('RA charge number')).controller!.text,
        '76576',
      );
      await journey.enter(
        tester,
        'Decision evidence',
        'PHONE $charge SI verifies completed RA charge 76576',
      );
      await journey.tapControl(tester, find.text('Close warning'));
      await journey.awaitRecord(
        tester,
        'quality_warnings/issue_$second',
        (d) => d['status'] == 'closed',
      );
      await journey.filter(tester, 'Closed');
      await journey.showControl(
        tester,
        find.text('PHONE $charge maintenance acceptable'),
      );
      await journey.showControl(
        tester,
        find.text('PHONE $charge maintenance RA'),
      );
      for (final ticket in [first, second]) {
        expect(
          (await journey.read('maintenance_records/$ticket'))['isResolved'],
          isFalse,
        );
      }
      final cases = await FirebaseFirestore.instance
          .collection('charge_abnormalities')
          .where('sourceChargeNo', isEqualTo: charge)
          .get(const GetOptions(source: Source.server));
      expect(cases.docs.map((d) => d.id).toSet(), {
        'issue_quality_$first',
        'issue_quality_$second',
        plain,
        completed,
      });
      final warnings = await FirebaseFirestore.instance
          .collection('quality_warnings')
          .where('sourceChargeNo', isEqualTo: charge)
          .get(const GetOptions(source: Source.server));
      expect(warnings.docs, hasLength(4));
      expect(
        (await journey.read('quality_warnings/abnormality_$plain'))['status'],
        'open',
      );
      expect(
        (await journey.read(
          'quality_warnings/abnormality_$completed',
        ))['status'],
        'open',
      );
      expect(
        (await journey.read(
          'charge_abnormalities/$completed',
        ))['reannealedToChargeNo'],
        76577,
      );
      debugPrint(
        'DEV_QUALITY_ADJUDICATION_PASS charge=$charge cases=4 warnings=4 physicalIssuesRemainOpen=2',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
