import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/job_module_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';

AppUser _actor([String uid = 'admin']) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
JobExecution _parent() => JobExecution()
  ..id = 7
  ..firestoreId = 'job-7'
  ..templateFirestoreId = 'template-7'
  ..assetType = AssetType.base
  ..assetNumber = 7
  ..createdAt = DateTime.utc(2026)
  ..updatedAt = DateTime.utc(2026);
JobModuleInstance _module(String action) => JobModuleInstance()
  ..id = 9
  ..firestoreId = 'module-9'
  ..jobExecutionFirestoreId = 'job-7'
  ..jobExecutionLocalId = 7
  ..moduleTitle = 'Seal inspection'
  ..moduleSnapshotJson = '{}'
  ..fieldDefinitionsJson = '[]'
  ..discipline = JobModuleDiscipline.mechanical
  ..createdAt = DateTime.utc(2026)
  ..updatedAt = DateTime.utc(2026)
  ..status = action == 'Accept'
      ? JobModuleStatus.submitted
      : JobModuleStatus.draftSaved
  ..version = 4
  ..isSynced = true;

class _Repository extends Fake implements JobModuleRepository {
  int calls = 0;
  String? uid;
  @override
  Future<void> submitModule(
    dynamic id, {
    required AppUser actor,
    String? submissionNote,
    AuditContext? auditContext,
  }) async {
    calls++;
    uid = actor.uid;
  }

  @override
  Future<void> acceptModule(
    dynamic id, {
    required AppUser actor,
    String? acceptanceNote,
    AuditContext? auditContext,
  }) async {
    calls++;
    uid = actor.uid;
  }

  @override
  Future<void> markModuleNotApplicable(
    dynamic id, {
    required AppUser actor,
    required String reason,
    AuditContext? auditContext,
  }) async {
    calls++;
    uid = actor.uid;
  }
}

void main() {
  for (final action in [
    'Submit',
    'Accept',
    'Mark not applicable with reason',
  ]) {
    for (final interruption in ['account switch', 'refresh', 'unchanged']) {
      testWidgets('$action confirmation rejects stale actor: $interruption', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1100, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final accounts = StreamController<AppUser?>.broadcast();
        final repository = _Repository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith((ref) => accounts.stream),
              jobModuleRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              home: JobModuleDetailScreen(
                execution: _parent(),
                module: _module(action),
              ),
            ),
          ),
        );
        accounts.add(_actor());
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(action),
          600,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text(action));
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'Reviewed original evidence',
        );
        final label = action == 'Submit'
            ? 'Submit Module'
            : action == 'Accept'
            ? 'Accept Module'
            : 'Mark N/A';
        final button = find.widgetWithText(FilledButton, label);
        final confirm = tester.widget<FilledButton>(button).onPressed!;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(JobModuleDetailScreen)),
        );
        if (interruption == 'account switch') {
          accounts.add(_actor('other-admin'));
        }
        if (interruption == 'refresh') {
          container.invalidate(currentAppUserProvider);
        }
        await tester.pump();
        await tester.pump();
        if (interruption != 'unchanged') {
          expect(find.text('Account verification required'), findsOneWidget);
          expect(button, findsNothing);
        }
        confirm();
        await tester.pumpAndSettle();
        expect(repository.calls, interruption == 'unchanged' ? 1 : 0);
        if (interruption == 'unchanged') expect(repository.uid, 'admin');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await accounts.close();
      });
    }
  }
}
