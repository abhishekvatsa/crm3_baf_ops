import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/base_inner_cover_register.dart';

/// Each prepared document obtains fresh complete server reads. An offline read
/// fails visibly; it must never turn a missing cached assignment into vacancy.
final baseInnerCoverRegisterProvider = FutureProvider.autoDispose
    .family<
      BaseInnerCoverRegister,
      ({String actorUid, String? classId, String? assetId})
    >((ref, scope) async {
      final actor = ref.watch(currentAppUserProvider).asData?.value;
      if (actor?.uid != scope.actorUid || actor?.canViewReports != true) {
        throw StateError('Approved report access is required.');
      }
      final db = FirebaseFirestore.instance;
      const server = GetOptions(source: Source.server);
      final snapshots = await Future.wait([
        db.collection('asset_classes').get(server),
        db.collection('asset_instances').get(server),
        db.collection('base_inner_cover_assignments').get(server),
        db.collection('inner_cover_profiles').get(server),
        db
            .collection('inner_cover_linkages')
            .where('active', isEqualTo: true)
            .get(server),
      ]);
      return buildBaseInnerCoverRegister(
        classes: decodeSnapshotBatch(
          snapshots[0],
          AssetClassRecord.fromMap,
          source: 'Report asset class',
        ),
        assets: decodeSnapshotBatch(
          snapshots[1],
          AssetInstanceRecord.fromMap,
          source: 'Report asset',
        ),
        assignments: decodeSnapshotBatch(
          snapshots[2],
          BaseInnerCoverAssignment.fromMap,
          source: 'Report Base assignment',
        ),
        covers: decodeSnapshotBatch(
          snapshots[3],
          InnerCoverProfile.fromMap,
          source: 'Report Inner Cover',
        ),
        linkages: decodeSnapshotBatch(
          snapshots[4],
          InnerCoverLinkage.fromMap,
          source: 'Report active linkage',
        ),
        capturedAt: DateTime.now(),
        selectedClassId: scope.classId,
        selectedAssetId: scope.assetId,
      );
    });
