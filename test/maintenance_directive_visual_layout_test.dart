import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/presentation/directives_screen.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/ticket_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  double width = 320,
  double textScale = 1.8,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final theme = BafAppTheme.light;
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
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
          primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
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

MaintenanceRecord _compactTicket({
  bool critical = false,
  AssetType assetType = AssetType.furnace,
}) {
  final at = DateTime.now().subtract(
    const Duration(days: 2, hours: 3, minutes: 5),
  );
  return MaintenanceRecord()
    ..firestoreId = 'compact-ticket'
    ..assetType = assetType
    ..assetNumber = 12
    ..maintenanceType = MaintenanceType.breakdown
    ..routedTo = RoutedTo.mechanical
    ..description = 'Inspect the seal condition.'
    ..loggedByName = _actor.name
    ..isCritical = critical
    ..isSynced = true
    ..createdAt = at
    ..updatedAt = at
    ..startDate = at;
}

Finder _inTicket(Finder matching) => find.descendant(
  of: find.byKey(const ValueKey('issue-row-compact-ticket')),
  matching: matching,
);

void _expectReadable(WidgetTester tester, Finder text, double width) {
  expect(text, findsOneWidget);
  final rect = tester.getRect(text);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(width));
  final paragraphs = tester.renderObjectList<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  expect(paragraphs, isNotEmpty);
  expect(paragraphs.every((paragraph) => !paragraph.didExceedMaxLines), isTrue);
}

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

  for (final scenario in [
    (width: 360.0, critical: true, asset: AssetType.furnace),
    (width: 393.0, critical: false, asset: AssetType.furnace),
    (width: 360.0, critical: true, asset: AssetType.innerCover),
  ]) {
    testWidgets('Issue header has two readable lines at ${scenario.width}: '
        '${scenario.asset.name}, critical=${scenario.critical}', (
      tester,
    ) async {
      final ticket = _compactTicket(
        critical: scenario.critical,
        assetType: scenario.asset,
      );
      await _smallPhone(
        tester,
        const Scaffold(body: TicketScreen()),
        ticket: ticket,
        width: scenario.width,
        textScale: 1,
      );
      final asset = _inTicket(
        find.text('${scenario.asset.name.toUpperCase()} 12'),
      );
      await _reveal(tester, asset);
      final lane = _inTicket(find.text('MECHANICAL'));
      final age = _inTicket(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.data?.startsWith('Open 2 d 3h ') == true,
        ),
      );
      for (final text in [asset, lane, age]) {
        _expectReadable(tester, text, scenario.width);
      }
      expect(tester.getCenter(lane).dy, closeTo(tester.getCenter(age).dy, 1));
      expect(
        tester.getTopLeft(lane).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(asset).dy),
      );
      final criticalLabel = _inTicket(find.text('CRITICAL'));
      if (scenario.critical) {
        _expectReadable(tester, criticalLabel, scenario.width);
        expect(
          tester.getCenter(asset).dy,
          closeTo(tester.getCenter(criticalLabel).dy, 1),
        );
      } else {
        expect(criticalLabel, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Enlarged narrow issue summary preserves every lane and its progress without clipping',
    (tester) async {
      final ticket = _compactTicket(critical: true);
      ticket
        ..status = TicketStatus.inProgress
        ..acknowledgedByUid = _actor.uid
        ..acknowledgedByName = _actor.name
        ..acknowledgedAt = ticket.createdAt.add(const Duration(minutes: 15))
        ..updatedAt = ticket.createdAt.add(const Duration(hours: 1))
        ..issueLanePlan =
            IssueLanePlan.initial([
                  'mechanical',
                  'electrical',
                  'instrumentation',
                ])
                .acknowledge('mechanical')
                .acknowledge('electrical')
                .complete(
                  'mechanical',
                  evidence: IssueLaneCompletionEvidence(
                    completedAt: ticket.createdAt.add(const Duration(hours: 1)),
                    completedByUid: _actor.uid,
                    completedByName: _actor.name,
                  ),
                );
      expect(ticket.issueLanePlanReadResult.isValid, isTrue);
      await _smallPhone(
        tester,
        const Scaffold(body: TicketScreen()),
        ticket: ticket,
      );
      await _reveal(tester, _inTicket(find.text('FURNACE 12')));
      for (final label in ['FURNACE 12', 'CRITICAL', 'In progress']) {
        _expectReadable(tester, _inTicket(find.text(label)), 320);
      }
      for (final entry in {
        'MECHANICAL': Icons.task_alt_rounded,
        'ELECTRICAL': Icons.verified_rounded,
        'I&A': Icons.schedule_rounded,
      }.entries) {
        final lane = _inTicket(find.text(entry.key));
        _expectReadable(tester, lane, 320);
        final summary = find
            .ancestor(of: lane, matching: find.byType(Row))
            .first;
        expect(
          find.descendant(of: summary, matching: find.byIcon(entry.value)),
          findsOneWidget,
        );
      }
      expect(_inTicket(find.text('LANE DATA ERROR')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
