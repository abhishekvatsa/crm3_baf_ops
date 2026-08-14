import 'package:isar/isar.dart';

part 'equipment_status_record.g.dart';

@collection
class EquipmentStatusRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? firestoreId;
  @Index()
  bool isSynced = false;
  int version = 1;

  @Index()
  late String assetTypeKey;
  @Index()
  late int assetNumber;
  @Index()
  String? assetClassId;
  @Index()
  String? assetInstanceId;
  @Index()
  String stateKey = 'inService';

  @ignore
  String get projectionIdentityKey =>
      assetTypeKey == 'governedCustom'
          ? '$assetTypeKey:$assetClassId:$assetInstanceId'
          : '$assetTypeKey:$assetNumber';

  int openMaintenanceCount = 0;
  int openRedCount = 0;
  int awaitingPreparationCount = 0;
  String previousStateKey = 'inService';
  String? transitionTrigger;
  String? activeExecutionIdsJson;

  DateTime? availableSince;
  DateTime? inServiceSince;
  DateTime? lastTransitionAt;
  String? lastTransitionByUid;
  String? lastTransitionByName;
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  String? metadataJson;
}
