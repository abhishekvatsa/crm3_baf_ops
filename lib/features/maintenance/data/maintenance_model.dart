import 'dart:convert';
import 'package:isar/isar.dart';
import '../../planned_maintenance/models/component_action_model.dart';

part 'maintenance_model.g.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AssetType { base, furnace, forceCooler, innerCover }

enum MaintenanceType { scheduled, breakdown, performance, inspection, overhaul }

enum TicketStatus { open, acknowledged, inProgress, resolved }

enum RoutedTo {
  operations,
  electrical,
  mechanical,
  instrumentation,
  refractory,
  emd,
  shiftInCharge,
  others
}

enum AppRole {
  admin,
  si,
  contractSupervisor,
  shiftSupervisor,
  seniorElectrical,
  seniorMechanical,
  seniorInstrumentation,
  seniorRefractory,
  refractory,
  operations,
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOLUTION HISTORY (for tracking past resolutions after reopen)
// ─────────────────────────────────────────────────────────────────────────────

@embedded
class ResolutionHistory {
  String? resolvedByUid;
  String? resolvedByName;
  DateTime? resolvedAt;
  String? actionsJson;
  String? remarks;
  double? downtimeHours;
  List<String> teamsInvolved;

  ResolutionHistory({
    this.resolvedByUid,
    this.resolvedByName,
    DateTime? resolvedAt,
    String? actionsJson,
    this.remarks,
    this.downtimeHours,
    this.teamsInvolved = const [],
  })  : resolvedAt = resolvedAt ?? DateTime.now(),
        actionsJson = actionsJson ?? '[]';

  Map<String, dynamic> toMap() => {
    'resolvedByUid': resolvedByUid,
    'resolvedByName': resolvedByName,
    'resolvedAt': resolvedAt?.toIso8601String(),
    'actionsJson': actionsJson ?? '[]',
    'remarks': remarks,
    'downtimeHours': downtimeHours,
    'teamsInvolved': teamsInvolved,
  };

  factory ResolutionHistory.fromMap(Map<String, dynamic> map) => ResolutionHistory(
    resolvedByUid: map['resolvedByUid'],
    resolvedByName: map['resolvedByName'],
    resolvedAt: map['resolvedAt'] != null ? DateTime.parse(map['resolvedAt']) : null,
    actionsJson: map['actionsJson'] ?? '[]',
    remarks: map['remarks'],
    downtimeHours: map['downtimeHours'],
    teamsInvolved: List<String>.from(map['teamsInvolved'] ?? []),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN MODEL
// ─────────────────────────────────────────────────────────────────────────────

@Collection()
class MaintenanceRecord {
  Id id = Isar.autoIncrement;

  // ── Sync Identity ─────────────────────────────────────────────────────────
  @Index()
  String? firestoreId;

  int version = 1;

  @Index()
  bool isSynced = false;

  // ── Tombstone fields (soft delete) ────────────────────────────────────────
  bool isDeleted = false;
  DateTime? deletedAt;

  // 🔥 AUDIT FIELDS (who deleted, why)
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  // ── Asset Identification ──────────────────────────────────────────────────
  @Enumerated(EnumType.name)
  late AssetType assetType;

  late int assetNumber;

  String? component;
  String? subsystem;
  String? tag;
  List<String>? hierarchyPath;

  // ── Fault Classification ─────────────────────────────────────────────────
  @Enumerated(EnumType.name)
  late MaintenanceType maintenanceType;

  String? classification;
  late String description;

  @Enumerated(EnumType.name)
  late RoutedTo routedTo;

  String? otherDepartment;

  // ── Operational Criticality ───────────────────────────────────────────────
  // Operator-selected safety flag. Critical raised issues are pushed immediately
  // and highlighted on receiving devices. Normal raised issues are queued for
  // the 5-minute issue sync SLA.
  @Index()
  bool isCritical = false;

  // ── Status & Lifecycle ────────────────────────────────────────────────────
  @Enumerated(EnumType.name)
  TicketStatus status = TicketStatus.open;

  @Index()
  bool isResolved = false;

  // ── Personnel & Accountability ────────────────────────────────────────────
  @Index()
  String? loggedByUid;

  String? loggedByName;
  String? reportedBy;

  String? acknowledgedByUid;
  String? acknowledgedByName;
  DateTime? acknowledgedAt;

  String? closedByUid;
  String? closedByName;

  List<String> teamsInvolved = [];

  String? performedBy;
  String? remarks;

  // ── Time Tracking ─────────────────────────────────────────────────────────
  late DateTime startDate;

  DateTime? endDate;

  double? downtimeHours;

  int? chargeNoAtEvent;

  // ── Audit & Metadata ──────────────────────────────────────────────────────
  @Index()
  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  String? metadataJson;

  // ── Actions (structured work done) ───────────────────────────────────────
  String actionsJson = '[]';

  @ignore
  List<ComponentAction> get actions => ComponentAction.decode(actionsJson);

  set actions(List<ComponentAction> value) {
    actionsJson = ComponentAction.encode(value);
  }

  // ── Resolution History (for reopened tickets) ────────────────────────────
  String resolutionHistoryJson = '[]';

  @ignore
  List<ResolutionHistory> get resolutionHistory {
    try {
      final list = jsonDecode(resolutionHistoryJson) as List;
      return list.map((e) => ResolutionHistory.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  set resolutionHistory(List<ResolutionHistory> value) {
    resolutionHistoryJson = jsonEncode(value.map((e) => e.toMap()).toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 🧠 HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  bool get isOpen => !isResolved;

  bool get isClosed => isResolved;

  @ignore
  Duration? get totalDowntime {
    if (endDate == null) return null;
    return endDate!.difference(startDate);
  }

  bool get hasComponentContext =>
      (component != null && component!.trim().isNotEmpty) ||
          (tag != null && tag!.trim().isNotEmpty);

  String get debugLabel =>
      '${assetType.name.toUpperCase()}-$assetNumber | ${status.name}';

  // ─── AUDIT SNAPSHOT ──────────────────────────────────────────────────────
  Map<String, dynamic> toAuditMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'assetType': assetType.name,
    'assetNumber': assetNumber,
    'description': description,
    'status': status.name,
    'isResolved': isResolved,
    'isCritical': isCritical,
    'isDeleted': isDeleted,
    'component': component,
    'tag': tag,
  };
}