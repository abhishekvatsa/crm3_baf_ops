import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/planned_job_module_set_resolver.dart';

JobModuleInstance _module({
  required int localId,
  required String firestoreId,
  required String? parentFirestoreId,
  required int? parentLocalId,
  JobModuleStatus status = JobModuleStatus.accepted,
  bool requiredForClosure = true,
}) {
  final now = DateTime.utc(2026, 6, 20);
  return JobModuleInstance()
    ..id = localId
    ..firestoreId = firestoreId
    ..jobExecutionFirestoreId = parentFirestoreId
    ..jobExecutionLocalId = parentLocalId
    ..moduleTitle = firestoreId
    ..moduleSnapshotJson = '{}'
    ..fieldDefinitionsJson = '[]'
    ..assetType = AssetType.base
    ..assetNumber = 209
    ..status = status
    ..discipline = JobModuleDiscipline.mechanical
    ..safetyClass = JobModuleSafetyClass.normal
    ..requiredForClosure = requiredForClosure
    ..responsesJson =
        status == JobModuleStatus.accepted ? '[{"key":"x","value":"ok"}]' : '[]'
    ..actionsJson = '[]'
    ..createdAt = now
    ..updatedAt = now
    ..isSynced = true
    ..isDeleted = false;
}

void main() {
  group('PlannedJobModuleSetResolver', () {
    test('ignores a foreign Firestore parent that collides on local id', () {
      final canonical = _module(
        localId: 10,
        firestoreId: 'canonical',
        parentFirestoreId: 'exec-current',
        parentLocalId: 7,
      );
      final foreign = _module(
        localId: 3,
        firestoreId: 'foreign',
        parentFirestoreId: 'exec-other',
        parentLocalId: 7,
        status: JobModuleStatus.notStarted,
      );

      final result = PlannedJobModuleSetResolver.resolve(
        executionFirestoreId: 'exec-current',
        executionLocalId: 7,
        firestoreLinkedModules: [canonical],
        localLinkedModules: [canonical, foreign],
      );

      expect(result.modules.map((item) => item.firestoreId), ['canonical']);
      expect(
        result.ignoredForeignParentCollisions.map((item) => item.firestoreId),
        ['foreign'],
      );
      expect(result.unresolvedLocalParentModules, isEmpty);
      expect(result.duplicateCanonicalModules, isEmpty);
    });

    test(
      'fails closed on a local-linked child missing the canonical remote parent',
      () {
        final canonical = _module(
          localId: 10,
          firestoreId: 'canonical',
          parentFirestoreId: 'exec-current',
          parentLocalId: 7,
        );
        final unresolved = _module(
          localId: 11,
          firestoreId: 'local-generated-id',
          parentFirestoreId: null,
          parentLocalId: 7,
        )..isSynced = false;

        final result = PlannedJobModuleSetResolver.resolve(
          executionFirestoreId: 'exec-current',
          executionLocalId: 7,
          firestoreLinkedModules: [canonical],
          localLinkedModules: [canonical, unresolved],
        );

        expect(result.modules.map((item) => item.firestoreId), ['canonical']);
        expect(result.ignoredForeignParentCollisions, isEmpty);
        expect(
          result.unresolvedLocalParentModules.map((item) => item.firestoreId),
          ['local-generated-id'],
        );
        expect(result.duplicateCanonicalModules, isEmpty);
        expect(result.hasUnresolvedIdentity, isTrue);
      },
    );

    test('uses the local parent only while the execution has no remote id', () {
      final local = _module(
        localId: 12,
        firestoreId: 'local-module',
        parentFirestoreId: null,
        parentLocalId: 7,
      );
      final unrelated = _module(
        localId: 13,
        firestoreId: 'unrelated',
        parentFirestoreId: null,
        parentLocalId: 8,
      );

      final result = PlannedJobModuleSetResolver.resolve(
        executionFirestoreId: null,
        executionLocalId: 7,
        firestoreLinkedModules: const [],
        localLinkedModules: [local, unrelated],
      );

      expect(result.modules.map((item) => item.firestoreId), ['local-module']);
      expect(result.ignoredForeignParentCollisions, isEmpty);
      expect(result.unresolvedLocalParentModules, isEmpty);
      expect(result.duplicateCanonicalModules, isEmpty);
    });

    test(
      'local-only execution ignores a remote-backed child with a colliding local id',
      () {
        final legitimateLocal = _module(
          localId: 12,
          firestoreId: 'local-module',
          parentFirestoreId: null,
          parentLocalId: 7,
        );
        final foreignRemote = _module(
          localId: 13,
          firestoreId: 'foreign-remote',
          parentFirestoreId: 'exec-other',
          parentLocalId: 7,
          status: JobModuleStatus.notStarted,
        );

        final result = PlannedJobModuleSetResolver.resolve(
          executionFirestoreId: null,
          executionLocalId: 7,
          firestoreLinkedModules: const [],
          localLinkedModules: [legitimateLocal, foreignRemote],
        );

        expect(result.modules.map((item) => item.firestoreId), [
          'local-module',
        ]);
        expect(
          result.ignoredForeignParentCollisions.map((item) => item.firestoreId),
          ['foreign-remote'],
        );
        expect(result.unresolvedLocalParentModules, isEmpty);
        expect(result.duplicateCanonicalModules, isEmpty);
      },
    );

    test('reports distinct local rows claiming one canonical Firestore id', () {
      final older =
          _module(
              localId: 10,
              firestoreId: 'canonical',
              parentFirestoreId: 'exec-current',
              parentLocalId: 7,
            )
            ..version = 1
            ..updatedAt = DateTime.utc(2026, 6, 20, 10);
      final newer =
          _module(
              localId: 11,
              firestoreId: 'canonical',
              parentFirestoreId: 'exec-current',
              parentLocalId: 7,
            )
            ..version = 2
            ..updatedAt = DateTime.utc(2026, 6, 20, 11);

      final result = PlannedJobModuleSetResolver.resolve(
        executionFirestoreId: 'exec-current',
        executionLocalId: 7,
        firestoreLinkedModules: [older, newer],
        localLinkedModules: [older, newer],
      );

      expect(result.modules, hasLength(1));
      expect(result.modules.single.version, 2);
      expect(result.modules.single.id, 11);
      expect(result.duplicateCanonicalModules.map((item) => item.id).toSet(), {
        10,
        11,
      });
      expect(result.hasUnresolvedIdentity, isTrue);
    });
  });
}
