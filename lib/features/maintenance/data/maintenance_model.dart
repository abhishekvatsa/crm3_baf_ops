import 'dart:convert';
import 'package:isar/isar.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../quality/domain/issue_quality_intent.dart';
import '../domain/burner_lockout_case.dart';
import '../domain/furnace_stuckup_case.dart';
import '../domain/frequent_issue_selection.dart';
import '../domain/issue_administrative_closure.dart';
import '../domain/issue_lane_plan.dart';

part 'maintenance_model.g.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AssetType { base, furnace, forceCooler, innerCover, governedCustom }

enum MaintenanceType { scheduled, breakdown, performance, inspection, overhaul }

enum TicketStatus {
  open,
  acknowledged,
  inProgress,
  resolved,
  closedWithoutResolution,
}

enum MaintenanceIssuePlantConditionEffect { none, unfit, unavailable, stuckUp }

const baseInnerCoverUnavailableClassification = 'baseInnerCoverUnavailable';
const baseInnerCoverAvailabilityComponent = 'Inner Cover availability';
const baseInnerCoverAvailabilitySubsystem = 'Base / Inner Cover association';

String maintenanceIssueClassificationLabel(
  String classification,
) => switch (classification) {
  burnerLockoutClassification => 'Furnace burner lockout',
  furnaceStuckupClassification => 'Furnace stuck-up',
  baseInnerCoverUnavailableClassification => 'Base unavailable: no Inner Cover',
  _ => classification,
};

extension MaintenanceIssuePlantConditionEffectLabel
    on MaintenanceIssuePlantConditionEffect {
  String get label => switch (this) {
    MaintenanceIssuePlantConditionEffect.none => 'No automatic effect',
    MaintenanceIssuePlantConditionEffect.unfit => 'Unfit',
    MaintenanceIssuePlantConditionEffect.unavailable => 'Unavailable',
    MaintenanceIssuePlantConditionEffect.stuckUp => 'Stuck-up',
  };
}

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
  @ignore
  IssueLanePlan? lanePlan;
  @ignore
  String? reopenedByUid;
  @ignore
  String? reopenedByName;
  @ignore
  DateTime? reopenedAt;
  @ignore
  String? reopenReason;
  @ignore
  bool reopenedByWorkflow;

  ResolutionHistory({
    this.resolvedByUid,
    this.resolvedByName,
    this.resolvedAt,
    String? actionsJson,
    this.remarks,
    this.downtimeHours,
    this.teamsInvolved = const [],
    this.lanePlan,
    this.reopenedByUid,
    this.reopenedByName,
    this.reopenedAt,
    this.reopenReason,
    this.reopenedByWorkflow = false,
  }) : actionsJson = actionsJson ?? '[]';

  Map<String, dynamic> toMap() => {
    'resolvedByUid': resolvedByUid,
    'resolvedByName': resolvedByName,
    'resolvedAt': resolvedAt?.toIso8601String(),
    'actionsJson': actionsJson ?? '[]',
    'remarks': remarks,
    'downtimeHours': downtimeHours,
    'teamsInvolved': teamsInvolved,
    ...?lanePlan?.toSynchronizedFields(),
    if (reopenedByUid != null) 'reopenedByUid': reopenedByUid,
    if (reopenedByName != null) 'reopenedByName': reopenedByName,
    if (reopenedAt != null) 'reopenedAt': reopenedAt!.toIso8601String(),
    if (reopenReason != null) 'reopenReason': reopenReason,
    if (reopenedByWorkflow) 'reopenedByWorkflow': true,
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
    final resolvedAt = readRequiredPersistedDateTime(
      map['resolvedAt'],
      field: 'resolvedAt',
      source: source,
    );
    final reopenedByUid = readOptionalPersistedString(
      map['reopenedByUid'],
      field: 'reopenedByUid',
      source: source,
    );
    final reopenedByName = readOptionalPersistedString(
      map['reopenedByName'],
      field: 'reopenedByName',
      source: source,
    );
    final reopenedAt = readOptionalPersistedDateTime(
      map['reopenedAt'],
      field: 'reopenedAt',
      source: source,
    );
    final reopenReason = readOptionalPersistedString(
      map['reopenReason'],
      field: 'reopenReason',
      source: source,
    );
    final reopenedByWorkflow =
        readOptionalPersistedBool(
          map['reopenedByWorkflow'],
          field: 'reopenedByWorkflow',
          source: source,
        ) ??
        false;
    final hasReopeningEvidence =
        reopenedByUid != null ||
        reopenedByName != null ||
        reopenedAt != null ||
        reopenReason != null;
    if (hasReopeningEvidence &&
        (reopenedByUid == null ||
            reopenedByName == null ||
            reopenedAt == null)) {
      throw PersistedDataFormatException(
        field: 'reopenedAt',
        source: source,
        detail: 'reopening actor and time must be recorded together',
      );
    }
    if (reopenedAt != null && reopenedAt.isBefore(resolvedAt)) {
      throw PersistedDataFormatException(
        field: 'reopenedAt',
        source: source,
        detail: 'reopening cannot precede the closure it follows',
      );
    }
    final lanePlan = IssueLanePlan.readOptionalSynchronizedFields(
      map,
      source: source ?? 'maintenance resolution history',
    );

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
      resolvedAt: resolvedAt,
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
      lanePlan: lanePlan,
      reopenedByUid: reopenedByUid,
      reopenedByName: reopenedByName,
      reopenedAt: reopenedAt,
      reopenReason: reopenReason,
      reopenedByWorkflow: reopenedByWorkflow,
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
  MaintenanceIssuePlantConditionEffect plantConditionEffect =
      MaintenanceIssuePlantConditionEffect.none;

  @ignore
  MaintenanceIssuePlantConditionEffect get effectivePlantConditionEffect {
    if (plantConditionEffect != MaintenanceIssuePlantConditionEffect.none) {
      return plantConditionEffect;
    }
    if (classification == furnaceStuckupClassification) {
      return MaintenanceIssuePlantConditionEffect.stuckUp;
    }
    // A pre-upgrade locally queued issue still needs the conservative default
    // that the compatible server command will persist on first acceptance.
    if (!isSynced && !isResolved && !isDeleted) {
      return MaintenanceIssuePlantConditionEffect.unfit;
    }
    return MaintenanceIssuePlantConditionEffect.none;
  }

  @Enumerated(EnumType.name)
  late RoutedTo routedTo;

  String? otherDepartment;

  @ignore
  IssueLanePlan get issueLanePlan => _readIssueLanePlan();

  @ignore
  IssueLanePlan get issueLanePlanForOtherDepartmentRepair =>
      _readIssueLanePlan(allowOtherDepartmentRepair: true);

  IssueLanePlan _readIssueLanePlan({bool allowOtherDepartmentRepair = false}) {
    final synchronized = IssueLanePlan.tryDecodeLocal(metadataJson);
    final plan =
        synchronized ??
        IssueLanePlan.legacy(primaryLane: routedTo.name, status: status.name);
    _validateIssueLanePlan(
      plan,
      isCanonical: synchronized != null,
      allowOtherDepartmentRepair: allowOtherDepartmentRepair,
    );
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

  void _validateIssueLanePlan(
    IssueLanePlan plan, {
    required bool isCanonical,
    bool allowOtherDepartmentRepair = false,
  }) {
    final source =
        firestoreId == null
            ? 'local maintenance record $id'
            : 'maintenance record $firestoreId';
    final cleanOtherDepartment = otherDepartment?.trim();
    final hasValidOtherDepartment =
        cleanOtherDepartment != null &&
        cleanOtherDepartment.isNotEmpty &&
        cleanOtherDepartment.length <= 80;
    final otherDepartmentMatches =
        plan.assignedLanes.contains(RoutedTo.others.name)
            ? hasValidOtherDepartment
            : otherDepartment == null;
    if (plan.primaryLane != routedTo.name ||
        (!allowOtherDepartmentRepair && !otherDepartmentMatches)) {
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
    if (status.isTerminal != isResolved ||
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

    final closure = administrativeClosure;
    if ((status == TicketStatus.closedWithoutResolution) != (closure != null)) {
      throw PersistedDataFormatException(
        field: 'administrativeClosure',
        source: source,
        detail:
            'closed-without-resolution status and disposition must be present together',
      );
    }
    if (status == TicketStatus.closedWithoutResolution &&
        (endDate == null ||
            closedByUid?.trim().isNotEmpty != true ||
            closedByName?.trim().isNotEmpty != true)) {
      throw PersistedDataFormatException(
        field: 'closedByUid',
        source: source,
        detail:
            'administrative closure requires complete closure authority and time',
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

    final hasAnyReopenEvidence =
        reopenedByUid != null ||
        reopenedByName != null ||
        reopenedAt != null ||
        reopenReason != null;
    final cleanReopenedByUid = reopenedByUid?.trim();
    final cleanReopenedByName = reopenedByName?.trim();
    final hasCompleteReopenAuthority =
        cleanReopenedByUid != null &&
        cleanReopenedByUid.isNotEmpty &&
        cleanReopenedByName != null &&
        cleanReopenedByName.isNotEmpty &&
        reopenedAt != null;
    if (hasAnyReopenEvidence && !hasCompleteReopenAuthority) {
      throw PersistedDataFormatException(
        field: 'reopenedByUid',
        source: source,
        detail:
            'reopening actor and time evidence must be complete when present',
      );
    }
  }

  // ── Operational Criticality ───────────────────────────────────────────────
  // Operator-selected safety flag. Critical issues are highlighted on receiving
  // devices; every governed issue mutation is pushed immediately.
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

  String? reopenedByUid;
  String? reopenedByName;
  DateTime? reopenedAt;
  String? reopenReason;

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
  IssueAdministrativeClosure? get administrativeClosure =>
      IssueAdministrativeClosure.tryDecodeLocal(metadataJson);

  set administrativeClosure(IssueAdministrativeClosure? value) {
    metadataJson = mergeIssueAdministrativeClosureIntoMaintenanceMetadata(
      metadataJson,
      value,
    );
  }

  @ignore
  Map<String, dynamic> get administrativeClosureSynchronizedFields =>
      administrativeClosure?.toSynchronizedFields() ??
      const <String, dynamic>{};

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

  bool get isOpen => !status.isTerminal;

  bool get isClosed => status.isTerminal;

  @ignore
  bool get canStillAffectPlantCondition {
    if (!isSynced) return true;
    if (isDeleted) return false;
    if (!isResolved) return true;
    return status == TicketStatus.closedWithoutResolution &&
        administrativeClosure?.disposition ==
            IssueAdministrativeClosureDisposition.stillRelevant;
  }

  @Index()
  bool get plantConditionContributionActive => canStillAffectPlantCondition;

  set plantConditionContributionActive(bool _) {
    // Isar must deserialize the persisted projection, but the authoritative
    // value is always derived from the ticket's current lifecycle fields.
  }

  @ignore
  bool get wasTechnicallyResolved => status == TicketStatus.resolved;

  @ignore
  bool get wasClosedWithoutResolution =>
      status == TicketStatus.closedWithoutResolution;

  @ignore
  String get lifecycleSummaryLabel {
    if (wasClosedWithoutResolution) return 'Closed unresolved';
    if (wasTechnicallyResolved) return 'Resolved';
    return 'Open';
  }

  @ignore
  bool get isWorkflowLinked =>
      workflowAggregateId != null && workflowAggregateId!.trim().isNotEmpty;

  @ignore
  bool get isWorkflowActionBlocked =>
      workflowDeferred ||
      (workflowQueueState != 'independent' && workflowQueueState != 'released');

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
    return endDate!.difference(currentWorkEpisodeStartedAt);
  }

  @ignore
  DateTime get currentWorkEpisodeStartedAt => reopenedAt ?? startDate;

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
    'plantConditionEffect': plantConditionEffect.name,
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
    'issueClosureDisposition': administrativeClosure?.disposition.name,
    'issueClosureReason': administrativeClosure?.reason,
  };
}

extension TicketStatusLifecycle on TicketStatus {
  bool get isTerminal =>
      this == TicketStatus.resolved ||
      this == TicketStatus.closedWithoutResolution;
}
