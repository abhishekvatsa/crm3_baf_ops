// Read-only checks through the real DEV app; no business records are created.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/core/widgets/dashboard/dashboard_widgets.dart';
import 'package:crm3_baf_ops/core/widgets/incremental_list_footer.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_list_filter.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart' show waitFor, goBack;
import 'dev_issue_quality_journey_test.dart'
    show showControl, tapControl, openMore, switchActor;

Future<Map<String, Object>> _checkList(
  WidgetTester tester,
  String name, {
  String? qualifiedEmptyLabel,
}) async {
  final footerFinder = find.byType(IncrementalListFooter);
  debugPrint('DEV_LIST_CHECK_START $name');
  if (qualifiedEmptyLabel != null &&
      find.text(qualifiedEmptyLabel).evaluate().isNotEmpty) {
    expect(find.byKey(const ValueKey('business-list-show-more')), findsNothing);
    final result = <String, Object>{
      'list': name,
      'total': 0,
      'initial': 0,
      'afterMore': 0,
    };
    debugPrint('DEV_LIST_CHECK_PASS ${jsonEncode(result)}');
    return result;
  }
  try {
    await showControl(tester, footerFinder);
  } catch (_) {
    debugPrint(
      'DEV_LIST_CHECK_VISIBLE $name ${tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data).join(' | ')}',
    );
    rethrow;
  }
  var footer = tester.widget<IncrementalListFooter>(footerFinder);
  expect(
    footer.visibleCount,
    math.min(15, footer.totalCount),
    reason: '$name starts with at most15.',
  );
  final total = footer.totalCount;
  final initial = footer.visibleCount;
  // Scrolling to the end must not reveal another batch automatically.
  await tester.pump(const Duration(seconds: 1));
  expect(
    tester.widget<IncrementalListFooter>(footerFinder).visibleCount,
    initial,
  );
  if (total > 15) {
    await tapControl(
      tester,
      find.byKey(const ValueKey('business-list-show-more')),
    );
    await showControl(tester, footerFinder);
    footer = tester.widget<IncrementalListFooter>(footerFinder);
    expect(footer.visibleCount, math.min(30, total));
    expect(footer.totalCount, total);
  }
  final result = <String, Object>{
    'list': name,
    'total': total,
    'initial': initial,
    'afterMore': footer.visibleCount,
  };
  debugPrint('DEV_LIST_CHECK_PASS ${jsonEncode(result)}');
  return result;
}

Future<void> _segment(WidgetTester tester, String key, String text) async {
  final selector = find.byKey(ValueKey(key));
  await showControl(tester, selector);
  await tapControl(
    tester,
    find.descendant(of: selector, matching: find.text(text)),
  );
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('DEV operational lists default open and expand only by15', (
    tester,
  ) async {
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
      () =>
          find.byType(HomeScreen).evaluate().isNotEmpty ||
          find.text('Sign in with Google').evaluate().isNotEmpty,
      'Normal DEV access gate',
    );
    if (find.text('Sign in with Google').evaluate().isNotEmpty) {
      await tester.tap(find.text('Sign in with Google'));
    }
    await waitFor(
      tester,
      () => find.byType(HomeScreen).evaluate().isNotEmpty,
      'Approved DEV home',
    );
    if (FirebaseAuth.instance.currentUser?.email !=
        'dev.usability-si@example.invalid') {
      await switchActor(tester, 'dev.usability-si@example.invalid');
    }
    final checks = <Map<String, Object>>[];

    await tester.tap(find.text('Issues'));
    await tester.pump(const Duration(seconds: 1));
    checks.add(await _checkList(tester, 'Issues Open'));
    await tapControl(tester, find.byKey(const ValueKey('issues-status-all')));
    checks.add(await _checkList(tester, 'Issues All'));
    await tapControl(tester, find.byKey(const ValueKey('issues-status-open')));
    checks.add(await _checkList(tester, 'Issues Open reset'));

    await openMore(tester, 'Directives');
    await waitFor(
      tester,
      () => find
          .byKey(const ValueKey('directives-status-filter'))
          .evaluate()
          .isNotEmpty,
      'Directives data and status controls must finish loading',
    );
    checks.add(
      await _checkList(
        tester,
        'Directives Open',
        qualifiedEmptyLabel: 'No directives found',
      ),
    );
    await _segment(tester, 'directives-status-filter', 'All');
    await waitFor(
      tester,
      () => find
          .byKey(const ValueKey('directives-status-filter'))
          .evaluate()
          .isNotEmpty,
      'Directive history must finish loading',
    );
    checks.add(
      await _checkList(
        tester,
        'Directives All',
        qualifiedEmptyLabel: 'No directives found',
      ),
    );
    await goBack(tester);

    await openMore(tester, 'Quality');
    checks.add(await _checkList(tester, 'Warnings Open'));
    await _segment(tester, 'quality-warning-status-filter', 'All');
    checks.add(await _checkList(tester, 'Warnings All'));
    await goBack(tester);

    await openMore(tester, 'Abnormalities');
    final reportCard = find.ancestor(
      of: find.text('Reports / Intelligence'),
      matching: find.byType(DashboardCard),
    );
    await showControl(tester, reportCard);
    await tapControl(
      tester,
      find.descendant(of: reportCard, matching: find.text('Open')),
    );
    checks.add(await _checkList(tester, 'Abnormalities Open / RA pending'));
    final status = find.byType(DropdownButtonFormField<AbnormalityListFilter>);
    await tapControl(tester, status);
    await tapControl(
      tester,
      find.descendant(
        of: find.byType(ListView).last,
        matching: find.text('All'),
      ),
    );
    checks.add(await _checkList(tester, 'Abnormalities All'));
    debugPrint('DEV_LIST_PAGING_PASS ${jsonEncode(checks)}');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
