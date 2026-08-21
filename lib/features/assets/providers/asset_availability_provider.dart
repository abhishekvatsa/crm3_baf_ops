import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/asset_availability_record.dart';

final assetAvailabilityProvider = StreamProvider<List<AssetAvailabilityRecord>>(
  (ref) {
    return FirebaseFirestore.instance
        .collection('asset_availability_current')
        .snapshots()
        .map(
          (snapshot) => List<AssetAvailabilityRecord>.unmodifiable(
            snapshot.docs.map(
              (doc) => AssetAvailabilityRecord.fromMap(doc.data(), doc.id),
            ),
          ),
        );
  },
);
