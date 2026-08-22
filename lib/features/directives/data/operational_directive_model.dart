// FILE: lib/features/directives/data/operational_directive_model.dart
import 'package:isar/isar.dart';
import '../../maintenance/data/maintenance_model.dart';

part 'operational_directive_model.g.dart';

// ─────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────

enum DirectiveStatus { open, acknowledged, closed }

enum DirectivePriority { low, medium, high, critical }

bool _hasMeaningfulDirectiveText(String? value) =>
    value != null && value.trim().isNotEmpty;

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────

@Collection()
class OperationalDirective {
  Id id = Isar.autoIncrement;

  // ── Sync Identity ───────────────────────────────────────────
  @Index()
  String? firestoreId;

  @Index()
  bool isSynced = false;

  int version = 1;

  // ── Tombstone fields (soft delete) ─────────────────────────
  bool isDeleted = false;
  DateTime? deletedAt;

  // 🔥 AUDIT FIELDS (who deleted, why)
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  // ── Content ─────────────────────────────────────────────────
  late String title;
  late String description;

  // ── Asset Context ───────────────────────────────────────────
  @Enumerated(EnumType.name)
  AssetType? assetType;

  int? assetNumber;

  String? component;
  String? subsystem;
  String? tag;
  List<String>? hierarchyPath;

  // ── Routing ─────────────────────────────────────────────────
  @Index()
  @Enumerated(EnumType.name)
  late AppRole directedTo;

  // ── Status ──────────────────────────────────────────────────
  @Index()
  @Enumerated(EnumType.name)
  DirectiveStatus status = DirectiveStatus.open;

  @Enumerated(EnumType.name)
  DirectivePriority priority = DirectivePriority.medium;

  // ── Personnel (LEGACY) ──────────────────────────────────────
  String? createdByUid;
  String? createdByName;

  // ── New UI fields ───────────────────────────────────────────
  String? issuedByUid;
  String? issuedByName;
  DateTime? issuedAt;
  bool isActive = true;

  // ── Acknowledgement ─────────────────────────────────────────
  String? acknowledgedByUid;
  String? acknowledgedByName;
  DateTime? acknowledgedAt;

  // ── Closure ─────────────────────────────────────────────────
  String? closedByUid;
  String? closedByName;
  DateTime? closedAt;

  bool closedWithoutAcknowledgement = false;

  // ── Comments ────────────────────────────────────────────────
  String? remarks;

  // ── Future Linking ──────────────────────────────────────────
  String? linkedMaintenanceFirestoreId;
  String? linkedExecutionFirestoreId;

  // ── Audit & Sync ────────────────────────────────────────────
  @Index()
  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  String? metadataJson;

  // ───────────────────────────────────────────────────────────
  // HELPERS
  // ───────────────────────────────────────────────────────────

  bool get isOpen => status == DirectiveStatus.open;

  bool get isAcknowledged => status == DirectiveStatus.acknowledged;

  bool get isClosed => status == DirectiveStatus.closed;

  bool get hasAssetContext => assetType != null && assetNumber != null;

  bool get hasComponentContext =>
      _hasMeaningfulDirectiveText(component) ||
      _hasMeaningfulDirectiveText(tag) ||
      _hasMeaningfulDirectiveText(subsystem) ||
      (hierarchyPath?.isNotEmpty ?? false);

  String get debugLabel => '$title → ${directedTo.name} (${status.name})';

  Map<String, dynamic> toMap() => {
    'firestoreId': firestoreId,
    'title': title,
    'description': description,
    'assetType': assetType?.name,
    'assetNumber': assetNumber,
    'component': component,
    'subsystem': subsystem,
    'tag': tag,
    'hierarchyPath': hierarchyPath,
    'directedTo': directedTo.name,
    'status': status.name,
    'priority': priority.name,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
    'issuedByUid': issuedByUid,
    'issuedByName': issuedByName,
    'issuedAt': issuedAt?.toIso8601String(),
    'isActive': isActive,
    'acknowledgedByUid': acknowledgedByUid,
    'acknowledgedByName': acknowledgedByName,
    'acknowledgedAt': acknowledgedAt?.toIso8601String(),
    'closedByUid': closedByUid,
    'closedByName': closedByName,
    'closedAt': closedAt?.toIso8601String(),
    'closedWithoutAcknowledgement': closedWithoutAcknowledgement,
    'remarks': remarks,
    'linkedMaintenanceFirestoreId': linkedMaintenanceFirestoreId,
    'linkedExecutionFirestoreId': linkedExecutionFirestoreId,
    'metadataJson': metadataJson,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'deletedByUid': deletedByUid,
    'deletedByName': deletedByName,
    'deleteReason': deleteReason,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
  };

  // ─── AUDIT SNAPSHOT ────────────────────────────────────────
  Map<String, dynamic> toAuditMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'title': title,
    'description': description,
    'directedTo': directedTo.name,
    'status': status.name,
    'isDeleted': isDeleted,
    'assetType': assetType?.name,
    'assetNumber': assetNumber,
    'component': component,
    'subsystem': subsystem,
    'tag': tag,
    'hierarchyPath': hierarchyPath,
    'priority': priority.name,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
    'issuedByUid': issuedByUid,
    'issuedByName': issuedByName,
    'issuedAt': issuedAt?.toIso8601String(),
    'closedByUid': closedByUid,
    'closedByName': closedByName,
    'closedAt': closedAt?.toIso8601String(),
  };
}
