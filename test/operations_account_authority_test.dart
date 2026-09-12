import 'dart:async';

import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_types_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/directives/presentation/create_directive_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _actor({String uid = 'origin', bool admin = true}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [admin ? AppRole.admin : AppRole.refractory],
  isApproved: true,
  createdAt: DateTime.utc(2026, 9, 1),
);

class _Repository extends Fake implements AbnormalityRepository {
  final saved = <AbnormalityType>[];
  @override
  Future<void> saveType(
    AbnormalityType type, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    expect(actor.uid, 'origin');
    expect(auditContext?.performedByUid, 'origin');
    saved.add(type);
  }
}

class _Sync extends Fake implements SyncCoordinator {
  @override
  Future<SyncRequestOutcome> runFullSyncWithResult({
    String reason = 'unknown',
    bool force = false,
  }) async => SyncRequestOutcome.queued;
}

void main() {
  testWidgets(
    'directive draft survives unavailable authority and cannot move to another account',
    (tester) async {
      final actors = StreamController<AppUser?>();
      addTearDown(actors.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
          ],
          child: const MaterialApp(home: CreateDirectiveScreen()),
        ),
      );
      FilledButton submit() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Issue Directive'),
      );
      expect(submit().onPressed, isNull);
      actors.addError(StateError('first lookup failed'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(submit().onPressed, isNull);
      actors.add(_actor());
      await tester.pumpAndSettle();
      final title = find.widgetWithText(TextFormField, 'Title / Subject');
      await tester.enterText(title, 'Isolate the line before inspection');
      final controller = tester.widget<TextFormField>(title).controller!;
      final staleSubmit = submit().onPressed!;
      actors.addError(StateError('refresh failed'));
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNull);
      staleSubmit();
      await tester.pumpAndSettle();
      expect(controller.text, 'Isolate the line before inspection');
      expect(tester.takeException(), isNull);
      actors.add(_actor(uid: 'different-admin'));
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNull);
      actors.add(_actor(admin: false));
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNull);
      actors.add(_actor());
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNotNull);
      expect(controller.text, 'Isolate the line before inspection');
    },
  );

  testWidgets(
    'master editor blocks a previously captured save callback until original admin recovers',
    (tester) async {
      final actors = StreamController<AppUser?>();
      addTearDown(actors.close);
      final repository = _Repository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            allAbnormalityTypesProvider.overrideWith((ref) => Stream.value([])),
            abnormalityRepositoryProvider.overrideWithValue(repository),
            syncCoordinatorProvider.overrideWithValue(_Sync()),
          ],
          child: const MaterialApp(home: AbnormalityTypesScreen()),
        ),
      );
      actors.addError(StateError('first lookup failed'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      actors.add(_actor());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('abnormality-types-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Code'),
        'SEAL_LEAK',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Seal leak',
      );
      final save = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
          .onPressed!;
      actors.addError(StateError('refresh failed'));
      await tester.pumpAndSettle();
      expect(find.text('Account verification required'), findsWidgets);
      save();
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);
      actors.add(_actor(uid: 'different-admin'));
      await tester.pumpAndSettle();
      save();
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);
      actors.add(_actor(admin: false));
      await tester.pumpAndSettle();
      save();
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);
      actors.add(_actor());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Title'))
            .controller!
            .text,
        'Seal leak',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      expect(repository.saved.single.code, 'SEAL_LEAK');
      expect(repository.saved.single.createdByUid, 'origin');
      expect(tester.takeException(), isNull);
    },
  );
}
