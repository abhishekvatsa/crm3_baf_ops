import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/governed_issue_asset_selection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Operators reported that after choosing an asset type and an asset number,
/// submitting a ticket answered "Choose an active governed asset before
/// submitting" - with the selection still visible on screen.
///
/// The form kept only the ids and re-derived the records at submit from
/// `assetClassesProvider` and `assetInstancesProvider`. Both are live Firestore
/// snapshot streams and the instances one is `StreamProvider.autoDispose`, so
/// `AsyncValue.value` is null while a stream is re-subscribing and null when it
/// has errored. During the 2026-09-09 background-network block those streams
/// could not refresh at all, which is why it became frequent.
void main() {
  final now = DateTime.utc(2026, 9, 10, 9);

  AssetInstanceRecord asset({
    String id = 'asset-base-205',
    String classId = 'class-base',
    AssetHierarchyStatus status = AssetHierarchyStatus.active,
  }) {
    return AssetInstanceRecord(
      id: id,
      assetClassId: classId,
      assetClassCode: 'BASE',
      assetClassName: 'Base',
      assetNumber: 205,
      name: 'BASE 205',
      serviceState: AssetServiceState.inService,
      ownershipStatus: AssetOwnershipStatus.confirmed,
      status: status,
      activeComponentCount: 0,
      version: 1,
      createdAt: now,
      updatedAt: now,
      lastMutationId: 'seed',
    );
  }

  group('resolving the physical asset a submit should act on', () {
    test('the live register wins when it has a value', () {
      final live = asset();

      expect(
        resolveSelectedPhysicalAsset(
          assetId: live.id,
          physicalClassId: live.assetClassId,
          liveAssets: <AssetInstanceRecord>[live],
          retained: null,
        ),
        same(live),
      );
    });

    test('a stream with no value falls back to the chosen record', () {
      // This is the reported failure: the operator picked it, the stream was
      // re-subscribing, and the submit refused the selection on screen.
      final chosen = asset();

      expect(
        resolveSelectedPhysicalAsset(
          assetId: chosen.id,
          physicalClassId: chosen.assetClassId,
          liveAssets: null,
          retained: chosen,
        ),
        same(chosen),
      );
    });

    test('a loaded register still rejects an asset it no longer lists', () {
      // Freshness must survive the fallback: a deactivated asset is caught
      // whenever the register can actually speak.
      final chosen = asset();

      expect(
        resolveSelectedPhysicalAsset(
          assetId: chosen.id,
          physicalClassId: chosen.assetClassId,
          liveAssets: const <AssetInstanceRecord>[],
          retained: chosen,
        ),
        isNull,
      );
    });

    test('a loaded register rejects an asset that became inactive', () {
      final retired = asset(status: AssetHierarchyStatus.retired);

      expect(
        resolveSelectedPhysicalAsset(
          assetId: retired.id,
          physicalClassId: retired.assetClassId,
          liveAssets: <AssetInstanceRecord>[retired],
          retained: null,
        ),
        isNull,
      );
    });

    test('the fallback re-checks what made the record eligible', () {
      // A retained record is not a licence to submit anything: it must still
      // be the asset that was asked for, active, and in the right class.
      final retired = asset(status: AssetHierarchyStatus.retired);

      expect(
        resolveSelectedPhysicalAsset(
          assetId: retired.id,
          physicalClassId: retired.assetClassId,
          liveAssets: null,
          retained: retired,
        ),
        isNull,
      );
      expect(
        resolveSelectedPhysicalAsset(
          assetId: 'a-different-asset',
          physicalClassId: 'class-base',
          liveAssets: null,
          retained: asset(),
        ),
        isNull,
      );
      expect(
        resolveSelectedPhysicalAsset(
          assetId: 'asset-base-205',
          physicalClassId: 'a-different-class',
          liveAssets: null,
          retained: asset(),
        ),
        isNull,
      );
    });

    test('no retained record and no live value resolves to nothing', () {
      expect(
        resolveSelectedPhysicalAsset(
          assetId: 'asset-base-205',
          physicalClassId: 'class-base',
          liveAssets: null,
          retained: null,
        ),
        isNull,
      );
    });
  });

  group('resolving the issue asset route', () {
    test('a retained route is used only for the class that was chosen', () {
      expect(
        resolveSelectedIssueAssetRoute(
          classId: 'class-base',
          liveClasses: null,
          retained: null,
        ),
        isNull,
      );
    });

    test('a loaded register that no longer lists the class rejects it', () {
      expect(
        resolveSelectedIssueAssetRoute(
          classId: 'class-base',
          liveClasses: const <AssetClassRecord>[],
          retained: null,
        ),
        isNull,
      );
    });
  });
}
