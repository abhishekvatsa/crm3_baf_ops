// Test-only remote transport; repository decoding and native storage stay real.
// ignore_for_file: subtype_of_sealed_class
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/audit/presentation/audit_timeline_screen.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart' hide Query;

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);

  for (final method in ['entity', 'recent', 'conflicts']) {
    for (final hasLocal in [false, true]) {
      test(
        '$method remote failure preserves local=$hasLocal as incomplete',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'audit_history_',
          );
          final db = await Isar.open([
            AuditEventSchema,
          ], directory: directory.path);
          app.isar = db;
          try {
            if (hasLocal) await db.writeTxn(() => db.auditEvents.put(_event()));
            final cloud = _Cloud();
            final repo = AuditRepository(firestore: cloud);
            Future<List<AuditEvent>> load() => switch (method) {
              'entity' => repo.getLocalEventsForEntity(
                'maintenance',
                'ticket-1',
              ),
              'recent' => repo.getRecentLocalEvents(),
              _ => repo.getRecentSyncConflictEvents(),
            };
            await expectLater(
              load(),
              throwsA(
                isA<AuditHistoryUnavailable>().having(
                  (e) => e.localEvents.length,
                  'saved rows',
                  hasLocal ? 1 : 0,
                ),
              ),
            );
            expect(await db.auditEvents.count(), hasLocal ? 1 : 0);
            cloud.fail = false;
            expect(await load(), hasLength(hasLocal ? 1 : 0));
            expect(cloud.serverReads, 2);
          } finally {
            await db.close(deleteFromDisk: true);
          await directory.delete(recursive: true);
          }
        },
      );
    }
  }

  for (final kind in ['entity', 'recent', 'conflicts']) {
    for (final hasLocal in [false, true]) {
      testWidgets(
        '$kind never calls unavailable history empty; saved=$hasLocal',
        (tester) async {
          final actor = AppUser(
            uid: 'audit-reviewer',
            name: 'Reviewer',
            email: 'reviewer@example.invalid',
            roles: const [AppRole.admin],
            isApproved: true,
            createdAt: DateTime.utc(2026),
          );
          var attempts = 0;
          Future<List<AuditEvent>> load() async {
            if (attempts++ == 0) {
              throw AuditHistoryUnavailable(
                hasLocal ? [_event()] : [],
                StateError('offline'),
              );
            }
            return [];
          }

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentAppUserProvider.overrideWith(
                  (ref) => Stream.value(actor),
                ),
                auditTimelineProvider.overrideWith((ref, scope) => load()),
                recentAuditEventsProvider.overrideWith((ref, uid) => load()),
                syncConflictAuditProvider.overrideWith((ref, uid) => load()),
              ],
              child: MaterialApp(
                theme: BafAppTheme.light,
                home: switch (kind) {
                  'entity' => const AuditTimelineScreen(
                    entityType: 'maintenance',
                    entityId: 'ticket-1',
                  ),
                  'recent' => const RecentAuditLogScreen(),
                  _ => const SyncConflictReviewScreen(),
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('No recorded history'), findsNothing);
          expect(find.text('No audit activity available'), findsNothing);
          expect(find.textContaining('could not be verified'), findsOneWidget);
          if (hasLocal) {
            expect(find.text('History incomplete'), findsOneWidget);
            expect(find.text('Saved sync conflict evidence'), findsOneWidget);
          }
          await tester.tap(find.text('Retry').first);
          await tester.pumpAndSettle();
          expect(attempts, 2);
          expect(find.text('History incomplete'), findsNothing);
          expect(find.textContaining('could not be verified'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

AuditEvent _event() => AuditEvent(
  entityType: 'maintenance',
  entityId: 'ticket-1',
  action: AuditAction.update,
  performedByUid: 'sync_engine',
  summary: 'Saved sync conflict evidence',
);

class _Cloud extends Fake implements FirebaseFirestore {
  bool fail = true;
  int serverReads = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Query(this);
}

class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(this.cloud);
  final _Cloud cloud;
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => this;
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Query<Map<String, dynamic>> limit(int limit) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    expect(options?.source, Source.server);
    cloud.serverReads++;
    if (cloud.fail) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return _Snapshot();
  }
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}
