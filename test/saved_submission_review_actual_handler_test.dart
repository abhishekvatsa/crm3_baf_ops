import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/services/saved_submission_review_service.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  test(
    'actual server inspection and finalization replies pass the native consumer unchanged',
    () async {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/saved_submission_review_actual_handler.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final evidence = fixture['row'] as Map<String, dynamic>;
      final directory = await Directory.systemTemp.createTemp(
        'crm3_review_wire_',
      );
      Isar? database;
      try {
        database = await Isar.open(
          [DurableSubmissionRecordSchema],
          directory: directory.path,
          name: 'review_wire',
          inspector: false,
        );
        var store = DurableSubmissionRepository(database);
        final row = await store.importLegacyNeedsReview(
          submissionId: evidence['submissionId'] as String,
          resourceKey: evidence['resourceKey'] as String,
          sourceKey: evidence['legacySourceKey'] as String,
          sourceBytes: base64Decode(evidence['legacySourceBase64'] as String),
        );
        expect(row.reviewEvidenceSha256, fixture['evidenceSha256']);
        expect(
          utf8.decode(base64Decode(row.legacySourceBase64!)),
          fixture['sourceBytes'],
        );
        final calls = <Map<String, dynamic>>[];
        final service = SavedSubmissionReviewService(
          store: store,
          requireReviewer: () => AppUser(
            uid: fixture['actorUid'] as String,
            name: 'Administrator',
            email: 'admin@example.test',
            roles: [AppRole.admin],
            isApproved: true,
            createdAt: DateTime.utc(2026),
          ),
          requireCapability: (callable, uid) async {
            expect(callable, 'mutateAssetHierarchyV2');
            expect(uid, fixture['actorUid']);
          },
          invoke: (callable, envelope) async {
            expect(envelope.keys.toSet(), {
              'protocolVersion',
              'originActorUid',
              'recovery',
            });
            expect(envelope['originActorUid'], fixture['actorUid']);
            final recovery = Map<String, dynamic>.from(
              envelope['recovery'] as Map,
            );
            calls.add(recovery);
            expect(recovery['evidenceSha256'], fixture['evidenceSha256']);
            expect(recovery['originalActorUid'], isNull);
            expect(recovery['reason'], fixture['reason']);
            if (recovery['phase'] == 'inspect') return fixture['inspection'];
            expect(recovery['phase'], 'finalize');
            expect(
              recovery['reviewToken'],
              (fixture['inspection'] as Map)['reviewToken'],
            );
            return fixture['proof'];
          },
        );
        final inspection = await service.inspect(
          row,
          fixture['reason'] as String,
        );
        final settled = await service.finalize(inspection);
        expect(calls, hasLength(2));
        expect(settled.state, DurableSubmissionState.reviewResolved);
        expect(jsonDecode(settled.receiptJson!)['decisions'], [
          fixture['proof'],
        ]);
        expect(await store.findUnresolvedForResource(row.resourceKey), isNull);
        await database.close();
        database = await Isar.open(
          [DurableSubmissionRecordSchema],
          directory: directory.path,
          name: 'review_wire',
          inspector: false,
        );
        store = DurableSubmissionRepository(database);
        expect(
          (await store.read(row.submissionId))!.receiptJson,
          settled.receiptJson,
        );
      } finally {
        if (database?.isOpen == true) await database!.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
