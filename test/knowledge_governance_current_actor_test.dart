// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/domain/current_actor_access.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_knowledge_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_layer.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_governance_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/knowledge_row_editor.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/knowledge_governance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final interruption in [
    'account switch',
    'refresh',
    'error',
    'withdrawal',
  ]) {
    testWidgets('knowledge editor blocks $interruption and retains its draft', (
      tester,
    ) async {
      final actors = StreamController<AppUser?>.broadcast();
      addTearDown(actors.close);
      final writes = _RecordingController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            knowledgeGovernanceControllerProvider.overrideWithValue(writes),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        KnowledgeRowEditor.forCreate(actor: _actor()),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );
      actors.add(_actor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open editor'));
      await tester.pump();
      actors.add(_actor());
      await tester.pumpAndSettle();
      final rowCode = find.byType(TextField).first;
      await tester.enterText(rowCode, 'RETAINED-DRAFT');
      final save = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
          .onPressed!;
      final context = tester.element(find.byType(KnowledgeRowEditor));
      switch (interruption) {
        case 'account switch':
          actors.add(_actor(uid: 'other-admin'));
        case 'refresh':
          ProviderScope.containerOf(context).invalidate(currentAppUserProvider);
        case 'error':
          actors.addError(StateError('Authority unavailable'));
        case 'withdrawal':
          actors.add(_actor(approved: false));
      }
      await tester.pump();
      await tester.pump();
      expect(find.text('Account verification required'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create'), findsNothing);
      // An already queued button callback must also recheck the current actor.
      save();
      await tester.pumpAndSettle();
      expect(writes.calls, 0);
      actors.add(_actor());
      await tester.pumpAndSettle();
      expect(find.text('Account verification required'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'RETAINED-DRAFT',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      expect(writes.calls, 1);
      expect(writes.actorUid, 'admin');
      expect(tester.takeException(), isNull);
    });
  }

  for (final interruption in ['account switch', 'refresh']) {
    testWidgets('knowledge lifecycle confirmation rechecks $interruption', (
      tester,
    ) async {
      final actors = StreamController<AppUser?>.broadcast();
      addTearDown(actors.close);
      final writes = _RecordingController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            knowledgeGovernanceControllerProvider.overrideWithValue(writes),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => KnowledgeRowEditor.forUpdate(
                      actor: _actor(),
                      before: _row(),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pump();
      actors.add(_actor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retire'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        'Reviewed retirement reason',
      );
      await tester.pump();
      final confirm = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'retired'))
          .onPressed!;
      final context = tester.element(find.byType(KnowledgeRowEditor));
      if (interruption == 'account switch') {
        actors.add(_actor(uid: 'other-admin'));
      } else {
        ProviderScope.containerOf(context).invalidate(currentAppUserProvider);
      }
      await tester.pump();
      await tester.pump();
      expect(find.widgetWithText(FilledButton, 'retired'), findsNothing);
      confirm();
      await tester.pumpAndSettle();
      expect(writes.calls, 0);
      expect(find.text('Account verification required'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final operation in ['create', 'update']) {
    for (final interruption in ['account switch', 'refresh']) {
      test(
        'knowledge $operation rejects $interruption after the transaction read',
        () async {
          AsyncValue<AppUser?> authority = AsyncData(_actor());
          final cloud = _ReadGateCloud(() {
            authority = interruption == 'account switch'
                ? AsyncData(_actor(uid: 'other-admin'))
                : const AsyncLoading<AppUser?>().copyWithPrevious(
                    AsyncData(_actor()),
                  );
          });
          final controller = KnowledgeGovernanceController(
            firestore: cloud,
            knowledgeRepository: _UnusedRepository(),
            auditRepository: _UnusedAudit(),
            currentActor: () => CurrentActorAccess.resolve(authority).actor,
          );
          final draft = KnowledgeRowDraft.fromRow(_row())
            ..taskText = 'Reviewed new instruction'
            ..changeSummary = 'Reviewed new instruction reason';
          await expectLater(
            operation == 'create'
                ? controller.createRow(draft: draft, actor: _actor())
                : controller.updateRow(
                    before: _row(),
                    draft: draft,
                    actor: _actor(),
                  ),
            throwsA(
              isA<KnowledgeGovernanceException>().having(
                (e) => e.message,
                'message',
                contains('original account'),
              ),
            ),
          );
          expect(cloud.reads, 1);
          expect(cloud.writes, 0);
        },
      );
    }
  }
}

AppUser _actor({String uid = 'admin', bool approved = true}) => AppUser(
  uid: uid,
  name: 'Admin',
  email: 'admin@example.invalid',
  roles: [AppRole.admin],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);
BafKnowledgeRow _row() => BafKnowledgeRow.fromEntry(
  BafKnowledgeLayer.entries.first,
  actorUid: 'admin',
  actorName: 'Administrator',
  now: DateTime.utc(2026, 9, 1),
  changeSummary: 'Previously reviewed instruction',
);

class _RecordingController extends Fake
    implements KnowledgeGovernanceController {
  int calls = 0;
  String? actorUid;
  @override
  Future<KnowledgeGovernanceWriteResult> retireRow({
    required BafKnowledgeRow before,
    required AppUser actor,
    required String reason,
  }) async {
    calls++;
    actorUid = actor.uid;
    throw const KnowledgeGovernanceException(
      'Synthetic lifecycle stopped before persistence.',
    );
  }

  @override
  Future<KnowledgeGovernanceWriteResult> createRow({
    required KnowledgeRowDraft draft,
    required AppUser actor,
    KnowledgeGovernanceAction governanceAction =
        KnowledgeGovernanceAction.created,
  }) async {
    calls++;
    actorUid = actor.uid;
    throw const KnowledgeGovernanceException(
      'Synthetic write stopped before persistence.',
    );
  }
}

class _UnusedRepository extends Fake implements BafKnowledgeRepository {}

class _UnusedAudit extends Fake implements AuditRepository {}

class _ReadGateCloud extends Fake implements FirebaseFirestore {
  _ReadGateCloud(this.onRead);
  final void Function() onRead;
  int reads = 0;
  int writes = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection();
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => handler(_ReadGateTransaction(this));
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _Document();
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

class _ReadGateTransaction extends Fake implements Transaction {
  _ReadGateTransaction(this.cloud);
  final _ReadGateCloud cloud;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    cloud.reads++;
    cloud.onRead();
    return _Snapshot<T>();
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    cloud.writes++;
    throw StateError('Authority loss must block writes.');
  }
}

class _Snapshot<T> extends Fake implements DocumentSnapshot<T> {}
