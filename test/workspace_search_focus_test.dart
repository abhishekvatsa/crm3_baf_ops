import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'workspace search types in its route and returns without an editable anchor',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final navigator = GlobalKey<NavigatorState>();
      final actor = AppUser(
        uid: 'synthetic',
        name: 'Synthetic',
        email: 'local@example.invalid',
        roles: const [AppRole.operations],
        isApproved: true,
        createdAt: DateTime.utc(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: _more(
              actor,
              () => navigator.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('Quality destination')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final anchor = find.byType(SearchBar);
      await tester.ensureVisible(anchor);
      await tester.tap(anchor);
      await tester.pumpAndSettle();
      final editable = find.byWidgetPredicate(
        (widget) => widget is EditableText && !widget.readOnly,
      );
      expect(editable, findsOneWidget);
      await tester.enterText(editable, 'Quality');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Quality'));
      await tester.pumpAndSettle();
      expect(find.text('Quality destination'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      final restored = tester.widget<SearchBar>(find.byType(SearchBar));
      expect(restored.readOnly, isTrue);
      final restoredEditor = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(restoredEditor.readOnly, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing directory search leaves ordinary navigation free of keyboard input',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final actor = AppUser(
        uid: 'synthetic',
        name: 'Synthetic',
        email: 'local@example.invalid',
        roles: const [AppRole.operations],
        isApproved: true,
        createdAt: DateTime.utc(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(body: _more(actor, () {})),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SearchBar));
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      final editable = find.byWidgetPredicate(
        (widget) => widget is EditableText && !widget.readOnly,
      );
      await tester.enterText(editable, 'Furnace');
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.widget<SearchBar>(find.byType(SearchBar)).readOnly, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

HomeMoreScreen _more(AppUser actor, VoidCallback onQuality) => HomeMoreScreen(
  appUser: actor,
  onRaiseIssue: () {},
  onIssues: () {},
  onWork: () {},
  onControl: () {},
  onDirectives: () {},
  onMorningReview: () {},
  onWorkflow: () {},
  onAssetRegistry: () {},
  onPlantCondition: () {},
  onAssets: () {},
  onInnerCovers: () {},
  onFurnaceStuckup: () {},
  onClosed: () {},
  onClosedJobs: () {},
  onMaintenanceRhythm: () {},
  onInspectionProgrammes: () {},
  onReports: () {},
  onBurnerReliability: () {},
  onAdmin: () {},
  onAuditLog: () {},
  onAbnormalities: () {},
  onQuality: onQuality,
  onQualityMonitoring: () {},
  onOperationalEvents: () {},
  onTemplateAuthoring: () {},
  onTemplatePublisher: () {},
  onKnowledgeGovernance: () {},
  onFrequentIssues: () {},
  onLocalDiagnostics: () {},
);
