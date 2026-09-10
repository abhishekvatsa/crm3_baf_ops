import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/asset_availability_record.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';

final assetAvailabilityProvider = StreamProvider<List<AssetAvailabilityRecord>>(
  (ref) {
    return FirebaseFirestore.instance
        .collection('asset_availability_current')
        .snapshots()
        .map(
          (snapshot) => List<AssetAvailabilityRecord>.unmodifiable(
            decodeSnapshotDocuments(snapshot, AssetAvailabilityRecord.fromMap, source: 'AssetAvailabilityRecord'),
          ),
        );
  },
);
