import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/inspections/domain/inspection_campaign_submission.dart';
import 'package:crm3_baf_ops/features/inspections/repositories/inspection_campaign_creation_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final flags in [(true, false), (false, true), (false, false)]) {
    test(
      'read uses exact server source and rejects unverified metadata $flags',
      () async {
        final database = _Firestore(flags.$1, flags.$2);
        final reader = InspectionCampaignCreationReader(firestore: database);
        if (flags.$1 || flags.$2) {
          await expectLater(
            reader.read('campaign-1'),
            throwsA(isA<InspectionCampaignSubmissionException>()),
          );
        } else {
          expect(await reader.read('campaign-1'), {'campaignId': 'campaign-1'});
        }
        expect(database.source, Source.server);
      },
    );
  }
  test('server absence is not successful adoption', () async {
    final database = _Firestore(false, false)..exists = false;
    await expectLater(
      InspectionCampaignCreationReader(firestore: database).read('campaign-1'),
      throwsA(isA<InspectionCampaignSubmissionException>()),
    );
  });
}

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.cached, this.pending);
  final bool cached, pending;
  bool exists = true;
  Source? source;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'inspection_campaigns');
    return _Collection(this);
  }
}

// Metadata/source probe only; no production implementation of this sealed SDK type.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.owner);
  final _Firestore owner;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'campaign-1');
    return _Document(owner);
  }
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.owner);
  final _Firestore owner;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    owner.source = options?.source;
    return _Snapshot(owner);
  }
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.owner);
  final _Firestore owner;
  @override
  bool get exists => owner.exists;
  @override
  Map<String, dynamic>? data() =>
      owner.exists ? {'campaignId': 'campaign-1'} : null;
  @override
  SnapshotMetadata get metadata => _Metadata(owner);
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.owner);
  final _Firestore owner;
  @override
  bool get isFromCache => owner.cached;
  @override
  bool get hasPendingWrites => owner.pending;
}
