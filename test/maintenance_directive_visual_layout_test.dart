import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/presentation/directives_screen.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/ticket_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _actor = AppUser(
  uid: 'visual-admin',
  name: 'Visual administrator',
  email: 'visual@example.invalid',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026, 9, 1),
);

const _component =
    'Main Furnace seal pressure monitoring and feedback assembly';

Future<void> _smallPhone(
  WidgetTester tester,
  Widget screen, {
  MaintenanceRecord? ticket,
  OperationalDirective? directive,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(_actor)),
        openTicketsProvider.overrideWith(
          (ref) => Stream.value([if (ticket != null) ticket]),
        ),
        openDirectivesProvider.overrideWith(
          (ref) => Stream.value([if (directive != null) directive]),
        ),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    280,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 50,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Issues controls and complete component text stay readable on a small enlarged-text phone',
    (tester) async {
      final at = DateTime.utc(2026, 9, 1);
      final ticket = MaintenanceRecord()
        ..firestoreId = 'visual-ticket'
        ..assetType = AssetType.furnace
        ..assetNumber = 12
        ..maintenanceType = MaintenanceType.breakdown
        ..routedTo = RoutedTo.mechanical
        ..description =
            'Inspect the seal assembly and record the observed pressure.'
        ..component = _component
        ..loggedByName = 'Maintenance reporter with a long displayed name'
        ..createdAt = at
        ..updatedAt = at
        ..startDate = at;
      await _smallPhone(
        tester,
        const Scaffold(body: TicketScreen()),
        ticket: ticket,
      );
      for (final key in [
        'issues-raise-issue',
        'issues-view-resolved',
        'issues-sync-now',
      ]) {
        final finder = find.byKey(ValueKey(key));
        await _reveal(tester, finder);
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.height, greaterThanOrEqualTo(48));
        final texts = tester.renderObjectList<RenderParagraph>(
          find.descendant(of: finder, matching: find.byType(RichText)),
        );
        expect(
          texts.every((paragraph) => !paragraph.didExceedMaxLines),
          isTrue,
        );
      }
      final component = find.text('Component: $_component');
      await _reveal(tester, component);
      expect(tester.widget<Text>(component).maxLines, isNull);
      expect(tester.getSize(component).height, greaterThan(40));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Directive title, status and component wrap without crowding; recovery remains available',
    (tester) async {
      final at = DateTime.utc(2026, 9, 1);
      const title =
          'Verify Furnace seal pressure before the next operational release';
      final directive = OperationalDirective()
        ..firestoreId = 'visual-directive'
        ..title = title
        ..description =
            'Record the actual pressure and confirm the field observation.'
        ..component = _component
        ..tag = 'FR-12-MAIN-SEAL-PRESSURE-FEEDBACK'
        ..directedTo = AppRole.seniorMechanical
        ..createdByUid = _actor.uid
        ..createdByName = _actor.name
        ..createdAt = at
        ..updatedAt = at
        ..status = DirectiveStatus.acknowledged;
      await _smallPhone(tester, const DirectivesScreen(), directive: directive);
      expect(find.text('Check saved directive changes'), findsNothing);
      await _reveal(tester, find.text('Saved changes'));
      await tester.tap(find.text('Saved changes'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Check saved directive changes'));
      expect(find.text('Check saved directive changes'), findsOneWidget);
      expect(find.text('Review held saved changes'), findsOneWidget);
      await _reveal(tester, find.text(title));
      final status = find.text('ACKNOWLEDGED');
      expect(
        tester.getTopLeft(status).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text(title)).dy),
      );
      await _reveal(tester, find.text(_component));
      expect(tester.widget<Text>(find.text(_component)).maxLines, isNull);
      expect(tester.getSize(find.text(_component)).height, greaterThan(40));
      expect(tester.takeException(), isNull);
    },
  );
}
