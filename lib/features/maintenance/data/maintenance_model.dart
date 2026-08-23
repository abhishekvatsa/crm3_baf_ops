import 'dart:convert';
import 'package:isar/isar.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../quality/domain/issue_quality_intent.dart';
import '../domain/burner_lockout_case.dart';
import '../domain/furnace_stuckup_case.dart';
import '../domain/frequent_issue_selection.dart';
import '../domain/issue_lane_plan.dart';

part 'maintenance_model.g.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AssetType { base, furnace, forceCooler, innerCover, governedCustom }

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
  others,
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
    this.resolvedAt,
    String? actionsJson,
    this.remarks,
    this.downtimeHours,
    this.teamsInvolved = const [],
  }) : actionsJson = actionsJson ?? '[]';

  Map<String, dynamic> toMap() => {
    'resolvedByUid': resolvedByUid,
    'resolvedByName': resolvedByName,
    'resolvedAt': resolvedAt?.toIso8601String(),
    'actionsJson': actionsJson ?? '[]',
    'remarks': remarks,
    'downtimeHours': downtimeHours,
    'teamsInvolved': teamsInvolved,
  };

  factory ResolutionHistory.fromMap(
    Map<String, dynamic> map, {
    String? source,
  }) {
    final actionsJson = ComponentAction.readEncodedPayload(
      map['actionsJson'],
      field: 'actionsJson',
      source: source,
      allowMissing: !map.containsKey('actionsJson'),
    );
    ComponentAction.decode(actionsJson, source: source);

    return ResolutionHistory(
      resolvedByUid: readOptionalPersistedString(
        map['resolvedByUid'],
        field: 'resolvedByUid',
        source: source,
      ),
      resolvedByName: readOptionalPersistedString(
        map['resolvedByName'],
        field: 'resolvedByName',
        source: source,
      ),
      resolvedAt: readRequiredPersistedDateTime(
        map['resolvedAt'],
        field: 'resolvedAt',
        source: source,
      ),
      actionsJson: actionsJson,
      remarks: readOptionalPersistedString(
        map['remarks'],
        field: 'remarks',
        source: source,
        emptyAsNull: false,
      ),
      downtimeHours: readOptionalPersistedDouble(
        map['downtimeHours'],
        field: 'downtimeHours',
        source: source,
      ),
      teamsInvolved: readOptionalPersistedStringList(
        map['teamsInvolved'],
        field: 'teamsInvolved',
        source: source,
      ),
    );
  }
}

class ResolutionHistoryReadResult {
  final List<ResolutionHistory> entries;
  final FormatException? error;

  const ResolutionHistoryReadResult._({
    required this.entries,
    required this.error,
  });

  bool get isValid => error == null;
}

class ValidatedResolutionHistoryPayload {
  final List<Map<String, dynamic>> rows;
  final List<ResolutionHistory> entries;

  const ValidatedResolutionHistoryPayload({
    required this.rows,
    required this.entries,
  });
}

ValidatedResolutionHistoryPayload readValidatedResolutionHistoryPayload(
  String value, {
  String? source,
}) {
  final rows = readRequiredJsonObjectList(
    value,
    field: 'resolutionHistoryJson',
    source: source,
  );
  final entries = <ResolutionHistory>[
    for (var index = 0; index < rows.length; index++)
      ResolutionHistory.fromMap(
        rows[index],
        source:
            source == null
                ? 'resolutionHistoryJson[$index]'
                : '$source resolutionHistoryJson[$index]',
      ),
  ];
  return ValidatedResolutionHistoryPayload(rows: rows, entries: entries);
}

String readEncodedResolutionHistoryPayload(dynamic value, {String? source}) {
  if (value == null) return '[]';
  if (value is! String) {
    throw PersistedDataFormatException(
      field: 'resolutionHistoryJson',
      source: source,
      detail: 'expected a JSON string (${value.runtimeType})',
    );
  }
  readValidatedResolutionHistoryPayload(value, source: source);
  return value;
}

List<ResolutionHistory> decodeResolutionHistoryJson(
  String value, {
  String? source,
}) => readValidatedResolutionHistoryPayload(value, source: source).entries;

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
  String? assetHierarchyRefJson;

  @ignore
  AssetHierarchyReference? get assetHierarchyReference =>
      assetHierarchyRefJson == null
          ? null
          : AssetHierarchyReference.decode(
            assetHierarchyRefJson!,
            source:
                firestoreId == null
                    ? 'local maintenance record $id'
                    : 'maintenance record $firestoreId',
          );

  // ── Fault Classification ─────────────────────────────────────────────────
  @Enumerated(EnumType.name)
  late MaintenanceType maintenanceType;

  String? classification;
  late String description;

  @Enumerated(EnumType.name)
  late RoutedTo routedTo;

  String? otherDepartment;

  @ignore
  IssueLanePlan get issueLanePlan {
    final synchronized = IssueLanePlan.tryDecodeLocal(metadataJson);
    final plan =
        synchronized ??
        IssueLanePlan.legacy(primaryLane: routedTo.name, status: status.name);
    _validateIssueLanePlan(plan, isCanonical: synchronized != null);
    return plan;
  }

  @ignore
  IssueLanePlanReadResult get issueLanePlanReadResult {
    try {
      return IssueLanePlanReadResult(value: issueLanePlan);
    } on FormatException catch (error) {
      return IssueLanePlanReadResult(value: null, error: error);
    }
  }

  set issueLanePlan(IssueLanePlan value) {
    metadataJson = mergeIssueLanePlanIntoMaintenanceMetadata(
      metadataJson,
      value,
    );
  }

  @ignore
  Map<String, dynamic> get issueLaneSynchronizedFields =>
      issueLanePlan.toSynchronizedFields();

  void _validateIssueLanePlan(IssueLanePlan plan, {required bool isCanonical}) {
    final source =
        firestoreId == null
            ? 'local maintenance record $id'
            : 'maintenance record $firestoreId';
    final cleanOtherDepartment = otherDepartment?.trim();
    final hasValidOtherDepartment =
        cleanOtherDepartment != null &&
        cleanOtherDepartment.length >= 2 &&
        cleanOtherDepartment.length <= 80;
    if (plan.primaryLane != routedTo.name ||
        plan.assignedLanes.contains(RoutedTo.others.name) !=
            hasValidOtherDepartment) {
      throw PersistedDataFormatException(
        field: 'issueAssignedLanes',
        source: source,
        detail: 'primary routing or Other-department evidence is inconsistent',
      );
    }

    final statusIsOpen = status == TicketStatus.open;
    final statusHasWork =
        status == TicketStatus.acknowledged ||
        status == TicketStatus.inProgress;
    if ((status == TicketStatus.resolved) != isResolved ||
        (statusIsOpen &&
            (plan.acknowledgedLanes.isNotEmpty ||
                plan.completedLanes.isNotEmpty)) ||
        (statusHasWork && plan.acknowledgedLanes.isEmpty) ||
        (status == TicketStatus.acknowledged &&
            (plan.acknowledgedLanes.length != plan.assignedLanes.length ||
                plan.completedLanes.isNotEmpty)) ||
        (status == TicketStatus.resolved && !plan.isFullyCompleted)) {
      throw PersistedDataFormatException(
        field: 'issueAcknowledgedLanes',
        source: source,
        detail: 'lane lifecycle must agree with ticket status',
      );
    }

    final hasAcknowledgement = plan.acknowledgedLanes.isNotEmpty;
    final acknowledgementComplete =
        acknowledgedByUid?.trim().isNotEmpty == true &&
        acknowledgedByName?.trim().isNotEmpty == true &&
        acknowledgedAt != null;
    final acknowledgementAbsent =
        acknowledgedByUid == null &&
        acknowledgedByName == null &&
        acknowledgedAt == null;
    final legacyResolvedWithoutAcknowledgement =
        !isCanonical &&
        status == TicketStatus.resolved &&
        acknowledgementAbsent;
    if (!legacyResolvedWithoutAcknowledgement &&
        ((hasAcknowledgement && !acknowledgementComplete) ||
            (!hasAcknowledgement && !acknowledgementAbsent))) {
      throw PersistedDataFormatException(
        field: 'acknowledgedByUid',
        source: source,
        detail: 'acknowledgement evidence must match issue lane progress',
      );
    }
  }

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

  // ── Workflow bridge (server-authoritative projection) ───────────────────
  // These fields mirror maintenance-workflow compliance state into the
  // original ticket system. Client Firestore serializers deliberately omit
  // them; Cloud Functions is the only remote author.
  @Index()
  bool workflowDeferred = false;

  @Index()
  String workflowQueueState = 'independent';

  @Index()
  String? workflowAggregateId;

  @Index()
  String? workflowComplianceId;

  String? workflowOriginLaneKey;
  String? workflowTargetLaneKey;
  String? workflowConditionTypeKey;
  String? workflowConditionRef;
  DateTime? workflowDeferredAt;
  String? workflowDeferredByUid;
  String? workflowDeferredByName;
  DateTime? workflowReactivatedAt;
  String? workflowReactivatedByUid;
  String? workflowReactivatedByName;
  DateTime? workflowReleasedAt;
  String? workflowReleasedByUid;
  String? workflowReleasedByName;
  String? workflowCorrectionReason;
  DateTime? workflowUpdatedAt;

  // Server-maintained projection of immutable disruption/issue link records.
  // Client Firestore serializers omit this field; local storage retains it so
  // issue lists can represent the relationship without additional queries.
  List<String> operationalEventIssueLinkIds = [];

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

  @ignore
  IssueQualityIntent? get qualityIntent =>
      IssueQualityIntent.tryDecodeLocal(metadataJson);

  set qualityIntent(IssueQualityIntent? value) {
    metadataJson = mergeQualityIntentIntoMaintenanceMetadata(
      metadataJson,
      value?.toMap(),
    );
  }

  @ignore
  Map<String, dynamic> get qualityIntentSynchronizedFields =>
      qualityIntent?.toSynchronizedFields() ?? const <String, dynamic>{};

  @ignore
  BurnerLockoutCase? get burnerLockoutCase {
    final value = BurnerLockoutCase.tryDecodeLocal(metadataJson);
    final isBurnerLockout = classification == burnerLockoutClassification;
    if (isBurnerLockout && value == null) {
      throw PersistedDataFormatException(
        field: 'burnerLockout',
        source:
            firestoreId == null
                ? 'local maintenance $id'
                : 'maintenance $firestoreId',
        detail: 'classified burner-lockout record requires complete evidence',
      );
    }
    if (!isBurnerLockout && value != null) {
      throw PersistedDataFormatException(
        field: 'classification',
        source:
            firestoreId == null
                ? 'local maintenance $id'
                : 'maintenance $firestoreId',
        detail: 'burner-lockout evidence requires its governed classification',
      );
    }
    return value;
  }

  @ignore
  BurnerLockoutCaseReadResult get burnerLockoutReadResult {
    try {
      return BurnerLockoutCaseReadResult(value: burnerLockoutCase);
    } on FormatException catch (error) {
      return BurnerLockoutCaseReadResult(value: null, error: error);
    }
  }

  set burnerLockoutCase(BurnerLockoutCase? value) {
    metadataJson = mergeBurnerLockoutIntoMaintenanceMetadata(
      metadataJson,
      value,
    );
  }

  @ignore
  Map<String, dynamic> get burnerLockoutSynchronizedFields =>
      burnerLockoutCase?.toSynchronizedFields() ?? const <String, dynamic>{};

  @ignore
  FurnaceStuckupCase? get furnaceStuckupCase {
    final value = FurnaceStuckupCase.tryDecodeLocal(metadataJson);
    final isStuckup = classification == furnaceStuckupClassification;
    if (isStuckup != (value != null)) {
      throw PersistedDataFormatException(
        field: 'furnaceStuckup',
        source:
            firestoreId == null
                ? 'local maintenance $id'
                : 'maintenance $firestoreId',
        detail:
            'Furnace stuck-up classification and evidence must be present together',
      );
    }
    return value;
  }

  set furnaceStuckupCase(FurnaceStuckupCase? value) {
    metadataJson = mergeFurnaceStuckupIntoMaintenanceMetadata(
      metadataJson,
      value,
    );
  }

  @ignore
  Map<String, dynamic> get furnaceStuckupSynchronizedFields =>
      furnaceStuckupCase?.toSynchronizedFields() ?? const <String, dynamic>{};

  @ignore
  FrequentIssueSelection? get frequentIssueSelection =>
      FrequentIssueSelection.tryDecodeLocal(metadataJson);

  set frequentIssueSelection(FrequentIssueSelection? value) {
    metadataJson = mergeFrequentIssueSelectionIntoMaintenanceMetadata(
      metadataJson,
      value,
    );
  }

  // ── Actions (structured work done) ───────────────────────────────────────
  String actionsJson = '[]';

  @ignore
  List<ComponentAction> get actions => ComponentAction.decode(
    actionsJson,
    source:
        firestoreId == null
            ? 'local maintenance $id'
            : 'maintenance $firestoreId',
  );

  @ignore
  ComponentActionReadResult get actionsReadResult => ComponentAction.tryDecode(
    actionsJson,
    source:
        firestoreId == null
            ? 'local maintenance $id'
            : 'maintenance $firestoreId',
  );

  set actions(List<ComponentAction> value) {
    actionsJson = ComponentAction.encode(value);
  }

  // ── Resolution History (for reopened tickets) ────────────────────────────
  String resolutionHistoryJson = '[]';

  @ignore
  List<ResolutionHistory> get resolutionHistory => decodeResolutionHistoryJson(
    resolutionHistoryJson,
    source:
        firestoreId == null
            ? 'local maintenance $id'
            : 'maintenance $firestoreId',
  );

  @ignore
  ResolutionHistoryReadResult get resolutionHistoryReadResult {
    try {
      return ResolutionHistoryReadResult._(
        entries: resolutionHistory,
        error: null,
      );
    } on FormatException catch (error) {
      return ResolutionHistoryReadResult._(
        entries: const <ResolutionHistory>[],
        error: error,
      );
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
  bool get isWorkflowLinked =>
      workflowAggregateId != null && workflowAggregateId!.trim().isNotEmpty;

  @ignore
  bool get isWorkflowActionBlocked => workflowDeferred;

  @ignore
  String get workflowStateLabel {
    switch (workflowQueueState) {
      case 'deferred':
        return 'Workflow deferred';
      case 'correctionRequired':
        return 'Correction required';
      case 'actionable':
        return 'Workflow actionable';
      case 'awaitingConfirmation':
        return 'Awaiting workflow confirmation';
      case 'released':
        return 'Released from workflow';
      default:
        return 'Independent';
    }
  }

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
    'workflowDeferred': workflowDeferred,
    'workflowQueueState': workflowQueueState,
    'workflowAggregateId': workflowAggregateId,
    'workflowComplianceId': workflowComplianceId,
    'workflowTargetLaneKey': workflowTargetLaneKey,
    'operationalEventIssueLinkIds': operationalEventIssueLinkIds,
    'isDeleted': isDeleted,
    'component': component,
    'tag': tag,
    'frequentIssueDefinitionId': frequentIssueSelection?.definitionId,
  };
}
