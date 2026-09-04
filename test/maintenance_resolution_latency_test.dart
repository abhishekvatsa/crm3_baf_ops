import 'dart:async';

import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/resolve_form.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_command_reconciler.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'admin-latency';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _Sync extends Fake implements SyncCoordinator {
  final pending = Completer<void>();
  int requests = 0;
  @override
  Future<void> runFullSync({String reason = 'unknown', bool force = false}) {
    expect(reason, 'ticket_resolved');
    expect(force, isTrue);
    requests++;
    return pending.future;
  }
}

class _Readback extends Fake implements MaintenanceIssueCommandReconciler {
  final pending = Completer<MaintenanceRecord>();
  int reads = 0;
  @override
  Future<MaintenanceRecord> adoptServerMutation({
    required String firestoreId,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
    required int minimumServerVersion,
  }) {
    expect(firestoreId, 'latency-ticket');
    expect(expectedLocalVersion, 3);
    expect(minimumServerVersion, 4);
    reads++;
    return pending.future;
  }
}

void main() {
  for (final converged in [true, false]) {
    testWidgets(
      'accepted resolution does not wait for full sync (readback $converged)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final sync = _Sync();
        final readback = _Readback();
        final server = Completer<WorkflowCommandReceipt>();
        WorkflowCommand? submitted;
        var calls = 0;
        var projectionPulls = 0;
        final now = DateTime.now();
        final ticket =
            MaintenanceRecord()
              ..firestoreId = 'latency-ticket'
              ..assetType = AssetType.base
              ..assetNumber = 101
              ..maintenanceType = MaintenanceType.breakdown
              ..routedTo = RoutedTo.mechanical
              ..description = 'Seal inspection'
              ..startDate = now.subtract(const Duration(hours: 1))
              ..createdAt = now.subtract(const Duration(hours: 1))
              ..updatedAt = now
              ..version = 3
              ..isSynced = true;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firebaseAuthProvider.overrideWithValue(_Auth()),
              currentAppUserProvider.overrideWith(
                (ref) => Stream.value(
                  AppUser(
                    uid: 'admin-latency',
                    name: 'Test Admin',
                    email: 'test@example.invalid',
                    roles: [AppRole.admin],
                    isApproved: true,
                    createdAt: now,
                  ),
                ),
              ),
              syncCoordinatorProvider.overrideWithValue(sync),
              maintenanceIssueCommandReconcilerProvider.overrideWithValue(
                readback,
              ),
              workflowCommandControllerProvider.overrideWith(
                (ref) => WorkflowCommandController.forTesting(
                  executeCommand: (command) {
                    calls++;
                    submitted = command;
                    return server.future;
                  },
                  pullProjections: () async {
                    projectionPulls++;
                  },
                ),
              ),
            ],
            child: MaterialApp(
              theme: BafAppTheme.light,
              home: Builder(
                builder:
                    (context) => Scaffold(
                      body: TextButton(
                        onPressed:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ResolveForm(ticket: ticket),
                              ),
                            ),
                        child: const Text('Open resolution'),
                      ),
                    ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open resolution'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byType(TextFormField), 250);
        await tester.enterText(
          find.byType(TextFormField).last,
          'Seal checked and repaired',
        );
        await tester.tap(find.text('Mark as Resolved'));
        await tester.pump();
        expect(calls, 1);
        expect(readback.reads, 0);
        expect(find.byType(ResolveForm), findsOneWidget);
        final command = submitted!;
        server.complete(
          WorkflowCommandReceipt(
            commandId: command.commandId,
            resultKey: 'maintenance-ticket-resolved',
            aggregateVersion: 4,
            appliedAt: now.toUtc(),
            result: {
              'ticketId': command.aggregateId,
              'auditId': 'server_maintenance_ticket_${command.commandId}',
              'completedLanes': ['mechanical'],
            },
          ),
        );
        await tester.pump();
        expect(readback.reads, 1);
        expect(projectionPulls, 0);
        expect(sync.requests, 0);
        expect(find.byType(ResolveForm), findsOneWidget);
        if (converged) {
          readback.pending.complete(ticket);
        } else {
          readback.pending.completeError(
            const MaintenanceIssueCommandConvergenceException(
              'Refresh pending',
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.byType(ResolveForm), findsNothing);
        expect(sync.requests, 1);
        expect(sync.pending.isCompleted, isFalse);
        expect(calls, 1);
        expect(
          find.textContaining(
            converged
                ? 'resolved and verified'
                : 'Exact device refresh is pending',
          ),
          findsOneWidget,
        );
        sync.pending.completeError(
          StateError('Unrelated sync failed after page disposal'),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(calls, 1);
      },
    );
  }
}
