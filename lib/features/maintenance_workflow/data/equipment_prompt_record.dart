import 'package:isar/isar.dart';

part 'equipment_prompt_record.g.dart';

@collection
class EquipmentPromptRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? firestoreId;
  @Index()
  bool isSynced = false;
  int version = 1;

  @Index()
  late String assetTypeKey;
  @Index()
  late String promptKey;
  String promptTypeKey = 'question'; // question | applicabilityMarker
  String? question;
  String? appliesWhenLaneKey;
  String? complianceTargetLaneKey;
  String? complianceTitleTemplate;
  String? successorTemplatePackageId;
  String? successorTemplateVersionId;
  String? successorTemplateContentHash;
  bool active = true;
  DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  String? metadataJson;
}
