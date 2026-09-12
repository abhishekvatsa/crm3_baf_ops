import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/presentation/current_actor_gate.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/maintenance_ticket_correction.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/closed_tickets_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_ticket_correction_dialog.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/resolve_form.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/services/closed_ticket_history_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _actor({
  String uid = 'origin',
  bool approved = true,
  bool admin = true,
}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [admin ? AppRole.admin : AppRole.operations],
  isApproved: approved,
  createdAt: DateTime.utc(2026, 9, 1),
);

MaintenanceRecord _ticket() => MaintenanceRecord()
  ..firestoreId = 'authority-ticket'
  ..version = 3
  ..isSynced = true
  ..assetType = AssetType.base
  ..assetNumber = 101
  ..maintenanceType = MaintenanceType.breakdown
  ..routedTo = RoutedTo.mechanical
  ..description = 'Seal inspection'
  ..startDate = DateTime.now().subtract(const Duration(hours: 1))
  ..createdAt = DateTime.now().subtract(const Duration(hours: 1))
  ..updatedAt = DateTime.now();

class _History extends Fake implements ClosedTicketHistoryService {
  int reads = 0;
  final ticket = _ticket()
    ..status = TicketStatus.resolved
    ..isResolved = true
    ..endDate = DateTime.now();

  @override
  Future<int> count({required AppUser? actor}) async => 1;

  @override
  Future<ClosedTicketPage> loadPage({
    required AppUser? actor,
    required int limit,
    required int offset,
    ClosedTicketPageCursor? cursor,
  }) async {
    reads++;
    return ClosedTicketPage(records: [ticket]);
  }
}

void main() {
  testWidgets(
    'resolve form keeps work through first error, retained error and account switch',
    (tester) async {
      final actors = StreamController<AppUser?>();
      addTearDown(actors.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: ResolveForm(ticket: _ticket()),
          ),
        ),
      );
      FilledButton submit() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mark as Resolved'),
      );
      expect(submit().onPressed, isNull);
      actors.addError(StateError('first lookup failed'));
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNull);
      expect(tester.takeException(), isNull);
      actors.add(_actor());
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNotNull);
      final form = find.byType(TextFormField).last;
      await tester.scrollUntilVisible(find.byType(TextFormField), 300,
        scrollable: find.byType(Scrollable).first);
      await tester.enterText(form, 'Inspected seal; measurements retained');
      final controller = tester.widget<TextFormField>(form).controller!;
      actors.addError(StateError('refresh failed'));
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNull);
      expect(controller.text, 'Inspected seal; measurements retained');
      actors.add(_actor(uid: 'another-admin'));
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNull);
      actors.add(_actor(admin: false));
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNull);
      actors.add(_actor());
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNotNull);
      expect(controller.text, 'Inspected seal; measurements retained');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'correction dialog survives disposal of its launching consumer and retains input',
    (tester) async {
      final actors = StreamController<AppUser?>();
      addTearDown(actors.close);
      MaintenanceTicketCorrectionDraft? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: Consumer(
              builder: (context, ref, _) {
                final account = ref.watch(currentAppUserProvider);
                if (account.hasError || account.isLoading) {
                  return const Scaffold(body: Text('Account unavailable'));
                }
                return Scaffold(
                  body: Builder(
                    builder: (launchContext) => TextButton(
                      onPressed: () async {
                        result =
                            await showDialog<MaintenanceTicketCorrectionDraft>(
                              context: launchContext,
                              builder: (_) => CurrentActorDialogGuard(
                                originUid: 'origin',
                                permission: (actor) =>
                                    actor.canCorrectMaintenanceTicket,
                                child: MaintenanceTicketCorrectionDialog(
                                  ticket: _ticket(),
                                ),
                              ),
                            );
                      },
                      child: const Text('Open correction'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      actors.add(_actor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open correction'));
      await tester.pumpAndSettle();
      final reason = find.byKey(const ValueKey('ticket-correction-reason'));
      final description = find.widgetWithText(TextFormField, 'Description');
      await tester.enterText(description, 'Corrected seal inspection evidence');
      await tester.ensureVisible(reason);
      await tester.enterText(reason, 'Original description contained an error');
      actors.addError(StateError('refresh failed'));
      await tester.pumpAndSettle();
      expect(find.text('Account verification required'), findsOneWidget);
      expect(reason, findsNothing);
      expect(result, isNull);
      actors.add(_actor(uid: 'another-admin'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Return to the account'), findsOneWidget);
      actors.add(_actor(admin: false));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not currently have permission'),
        findsOneWidget,
      );
      actors.add(_actor());
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(reason).controller!.text,
        'Original description contained an error',
      );
      await tester.tap(find.text('Record correction'));
      await tester.pumpAndSettle();
      expect(result?.reason, 'Original description contained an error');
      expect(
        result?.corrections['description'],
        'Corrected seal inspection evidence',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closed history keeps its reopen dialog and loaded records through account error',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final actors = StreamController<AppUser?>();
      addTearDown(actors.close);
      final history = _History();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            closedTicketHistoryServiceProvider.overrideWithValue(history),
            maintenanceClassDefinitionsProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: BafAppTheme.light,
            home: const ClosedTicketsScreen(),
          ),
        ),
      );
      actors.add(_actor());
      await tester.pumpAndSettle();
      final reopen = find.text('Reopen Ticket');
      await tester.ensureVisible(reopen);
      await tester.tap(reopen);
      await tester.pumpAndSettle();
      final field = find.byType(TextField).last;
      await tester.enterText(field, 'Failure returned during operation');
      final controller = tester.widget<TextField>(field).controller!;
      actors.addError(StateError('refresh failed'));
      await tester.pumpAndSettle();
      expect(find.text('Account verification required'), findsOneWidget);
      expect(controller.text, 'Failure returned during operation');
      expect(history.reads, 1);
      actors.add(_actor(uid: 'another-admin'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Return to the account that started'), findsOneWidget);
      expect(history.reads, 1);
      actors.add(_actor());
      await tester.pumpAndSettle();
      expect(controller.text, 'Failure returned during operation');
      expect(find.text('Account verification required'), findsNothing);
      expect(history.reads, 1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
