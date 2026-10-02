import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event_issue_link.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_event_issue_links_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_issue_link_service.dart';
import 'operational_event_issue_link_test.dart' as fixtures;

AppUser _actor([String uid = 'ops']) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

class _Links extends Fake implements OperationalEventIssueLinkService {
  int calls = 0;
  String? reasonSent;
  int? eventVersionSent;
  int? issueVersionSent;
  @override
  Future<OperationalEventIssueLinkCommandResult> link({
    required OperationalEvent event,
    required MaintenanceRecord issue,
    required OperationalEventIssueRelationship relationship,
    required String reason,
  }) async {
    calls++;
    reasonSent = reason;
    eventVersionSent = event.version;
    issueVersionSent = issue.version;
    return OperationalEventIssueLinkCommandResult(
      requestId: fixtures.requestId,
      eventId: event.eventId,
      issueId: issue.firestoreId!,
      linkId: fixtures.linkId,
      eventVersion: event.version + 1,
      issueVersion: issue.version + 1,
      auditId: 'operational_event_issue_${fixtures.requestId}',
      committedAt: DateTime.utc(2026, 9, 30),
      idempotentReplay: false,
    );
  }
}

void _large(WidgetTester tester) {
  tester.view.physicalSize = const Size(1100, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final interruption in ['account switch', 'refresh', 'unchanged']) {
    testWidgets(
      'held event-link confirmation handles $interruption without changing intent',
      (tester) async {
        _large(tester);
        final accounts = StreamController<AppUser?>.broadcast();
        final links = _Links();
        final event = fixtures.scopedEvent();
        final issue = fixtures.issueForAsset('asset-furnace-7');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith((ref) => accounts.stream),
              operationalEventsProvider.overrideWith(
                (ref, uid) => Stream.value([event]),
              ),
              operationalEventIssueLinksProvider.overrideWith(
                (ref, scope) => Stream.value(<OperationalEventIssueLink>[]),
              ),
              allTicketsProvider.overrideWith((ref) => Stream.value([issue])),
              operationalEventIssueLinkServiceProvider.overrideWithValue(links),
            ],
            child: MaterialApp(
              home: OperationalEventIssueLinksScreen(event: event),
            ),
          ),
        );
        accounts.add(_actor());
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OperationalEventIssueLinksScreen)),
        );
        await container.read(allTicketsProvider.future);
        await tester.tap(find.text('Link issue'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Original relationship evidence',
        );
        await tester.pump();
        final confirm = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Link'))
            .onPressed!;
        if (interruption == 'account switch') {
          accounts.add(_actor('other-admin'));
        } else if (interruption == 'refresh') {
          container.invalidate(currentAppUserProvider);
        }
        await tester.pump();
        await tester.pump();
        if (interruption != 'unchanged') {
          expect(find.text('Account verification required'), findsOneWidget);
          expect(find.widgetWithText(FilledButton, 'Link'), findsNothing);
        }
        // Exercise an already queued confirmation even after its form is hidden.
        confirm();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(links.calls, interruption == 'unchanged' ? 1 : 0);
        if (interruption == 'unchanged') {
          expect(links.reasonSent, 'Original relationship evidence');
          expect(links.eventVersionSent, event.version);
          expect(links.issueVersionSent, issue.version);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await accounts.close();
      },
    );
  }
  testWidgets(
    'readable event links stay visible alongside missing projected evidence',
    (tester) async {
      _large(tester);
      final issue = fixtures.issueForAsset('asset-furnace-7')
        ..operationalEventIssueLinkIds = [fixtures.linkId, 'missing-link'];
      final link = OperationalEventIssueLink.fromMap(
        fixtures.linkRecord(),
        fixtures.linkId,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_actor()),
            ),
            operationalIssueEventLinksProvider.overrideWith(
              (ref, scope) => Stream.value([link]),
            ),
          ],
          child: MaterialApp(
            home: MaintenanceIssueEventLinksScreen(issue: issue),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Link evidence incomplete'), findsOneWidget);
      expect(find.textContaining('1 projected event link is'), findsOneWidget);
      expect(find.text(link.eventTitle), findsOneWidget);
      expect(find.text(link.reason), findsOneWidget);
      expect(find.text('No operational event link'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
