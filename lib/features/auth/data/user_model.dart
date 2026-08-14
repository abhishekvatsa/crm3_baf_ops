// FILE: lib/features/auth/data/user_model.dart

import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance_workflow/domain/workflow_policy_generated.dart';

AppRole? _parseAppRole(dynamic value) {
  if (value is! String) return null;
  for (final role in AppRole.values) {
    if (role.name == value) return role;
  }
  return null;
}

List<AppRole> _parseRoles(dynamic value) {
  if (value is! List || value.isEmpty) return const <AppRole>[];

  final roles = <AppRole>{};
  for (final raw in value) {
    final parsed = _parseAppRole(raw);
    // Authority data fails closed. Unknown/non-string roles must never be
    // reinterpreted as Operations or any other valid permission.
    if (parsed == null) return const <AppRole>[];
    roles.add(parsed);
  }

  return List<AppRole>.unmodifiable(roles);
}

String _normalisePermissionKey(String? value) {
  return value
          ?.trim()
          .toLowerCase()
          .replaceAll('&', 'and')
          .replaceAll(RegExp(r'[^a-z0-9]+'), '') ??
      '';
}

String _canonicalModuleDisciplinePermissionKey(String? value) {
  switch (_normalisePermissionKey(value)) {
    case 'mechanical':
      return 'mechanical';
    case 'electrical':
      return 'electrical';
    case 'instrumentation':
    case 'instrument':
    case 'ia':
    case 'ianda':
    case 'instrumentationandautomation':
    case 'instrumentationautomation':
      return 'instrumentation';
    case 'operations':
    case 'operation':
      return 'operations';
    case 'shiftincharge':
    case 'shift':
    case 'shiftcharge':
    case 'shiftlead':
      return 'shiftInCharge';
    case 'emd':
      return 'emd';
    case 'refractory':
      return 'refractory';
    case 'safety':
      return 'safety';
    case 'admin':
    case 'administration':
      return 'admin';
    case 'others':
    case 'other':
      return 'others';
    case 'shared':
    case 'multi':
    case 'multidiscipline':
    default:
      return 'shared';
  }
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final List<AppRole> roles;
  final bool isApproved;
  final String? fcmToken;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.roles,
    required this.isApproved,
    this.fcmToken,
    required this.createdAt,
  });

  // ───────────────────────────────────────────────────────────
  // ROLE CHECKS
  // ───────────────────────────────────────────────────────────

  bool get isAdmin => roles.contains(AppRole.admin);
  bool get isSI => roles.contains(AppRole.si);
  bool get isContractSupervisor => roles.contains(AppRole.contractSupervisor);
  bool get isShiftSupervisor => roles.contains(AppRole.shiftSupervisor);
  bool get isOperations => roles.contains(AppRole.operations);

  bool get isRefractory =>
      roles.contains(AppRole.refractory) ||
      roles.contains(AppRole.seniorRefractory);

  bool get isElectrical => roles.contains(AppRole.seniorElectrical);

  bool get isMechanical => roles.contains(AppRole.seniorMechanical);

  bool get isInstrumentation => roles.contains(AppRole.seniorInstrumentation);

  bool get isSeniorRole => roles.any(
    (r) => [
      AppRole.seniorElectrical,
      AppRole.seniorMechanical,
      AppRole.seniorInstrumentation,
      AppRole.seniorRefractory,
    ].contains(r),
  );

  // ───────────────────────────────────────────────────────────
  // TICKET PERMISSIONS
  // ───────────────────────────────────────────────────────────

  /// Maintenance-ticket closure is a senior/supervisory authority event.
  /// The same authority applies to ordinary and red/refractory tickets.
  bool get canCloseMaintenanceTicket =>
      isApproved &&
      (isAdmin ||
          isSI ||
          isContractSupervisor ||
          isShiftSupervisor ||
          isSeniorRole);

  bool get canCloseAnyTicket => canCloseMaintenanceTicket;

  bool get canCloseRedTicket => canCloseMaintenanceTicket;

  /// Ticket acknowledgement is receiving-lane acceptance. Plant supervisors
  /// may triage every route; discipline actors may accept only their route.
  bool canAcknowledgeMaintenanceTicket(RoutedTo routedTo) {
    if (!isApproved) return false;
    if (isAdmin || isSI || isContractSupervisor || isShiftSupervisor) {
      return true;
    }
    return switch (routedTo) {
      RoutedTo.electrical => isElectrical,
      RoutedTo.mechanical => isMechanical,
      RoutedTo.instrumentation => isInstrumentation,
      RoutedTo.operations => isOperations,
      RoutedTo.shiftInCharge => isOperations,
      RoutedTo.refractory => isRefractory,
      RoutedTo.emd => false,
      RoutedTo.others => false,
    };
  }

  /// Reopening is deliberately plant/operations-side: Admin/SI may reopen,
  /// and Operations may challenge/revive a closed issue.
  bool get canReopenMaintenanceTicket =>
      isApproved && (isAdmin || isSI || isOperations);

  /// Historical correction and deletion are Admin-only audit actions.
  bool get canCorrectMaintenanceTicket => isApproved && isAdmin;

  bool get canSoftDeleteMaintenanceTicket => isApproved && isAdmin;

  bool get canLogRedRequest => roles.any(
    (r) => [
      AppRole.admin,
      AppRole.si,
      AppRole.operations,
      AppRole.seniorElectrical,
      AppRole.seniorMechanical,
      AppRole.seniorInstrumentation,
      AppRole.seniorRefractory,
    ].contains(r),
  );

  bool get canSeeAllTickets => roles.any((r) => r != AppRole.operations);

  bool get canSeeAssignedMaintenanceTickets =>
      isApproved && RoutedTo.values.any(canAcknowledgeMaintenanceTicket);

  bool canViewMaintenanceTicket({
    required String? loggedByUid,
    required RoutedTo routedTo,
  }) =>
      isApproved &&
      (canSeeAllTickets ||
          loggedByUid == uid ||
          canAcknowledgeMaintenanceTicket(routedTo));

  /// Every approved user may inspect the cross-record equipment timeline.
  /// Ticket visibility within that timeline remains repository/rules governed.
  bool get canViewOperationalAssets => isApproved;

  /// Closed-ticket history is operational reference data. Mutation controls
  /// such as reopen and admin correction remain separately role-gated.
  bool get canViewClosedMaintenanceTickets => isApproved;

  bool get canManageUsers => isApproved && isAdmin;

  bool get canViewAuditLogs => isApproved && isAdmin;

  bool get canReviewSyncConflicts => isApproved && isAdmin;

  bool get canResolveSyncConflicts => canReviewSyncConflicts;

  bool get canViewReports => isApproved;

  bool get canViewQuality => isApproved;

  bool get canRequestQualityWarningClosure =>
      isApproved && (isAdmin || isSI || isShiftSupervisor || isOperations);

  bool get canCloseQualityWarning => isApproved && (isAdmin || isSI);

  bool get canManageQualityMonitoring => canCloseQualityWarning;

  bool get canOpenAdminDataBrowser => isApproved && isAdmin;

  /// Asset-class and component hierarchy is an authoritative master-data
  /// surface. Only Admin may restructure it; approved users receive read-only
  /// access through the operational selectors that consume this master.
  bool get canManageAssetHierarchy => isApproved && isAdmin;

  /// Operations may declare loss of availability. Restoring availability is
  /// a supervisory assurance decision and therefore has a narrower boundary.
  bool get canDeclareAssetOperationalCondition =>
      isApproved && (isAdmin || isSI || isShiftSupervisor || isOperations);

  bool get canRestoreAssetOperationalCondition =>
      isApproved && (isAdmin || isSI || isShiftSupervisor);

  bool get canRecordOperationalEvent =>
      isApproved &&
      (isAdmin ||
          isSI ||
          isShiftSupervisor ||
          isOperations ||
          isContractSupervisor);

  bool get canResolveOperationalEvent =>
      isApproved && (isAdmin || isSI || isShiftSupervisor || isOperations);

  // ───────────────────────────────────────────────────────────
  // LEGACY PLANNED-MAINTENANCE TEMPLATE / ASSIGNMENT PERMISSIONS
  // ───────────────────────────────────────────────────────────

  /// Legacy runtime JobTemplate creation/editing is still allowed for Admin/SI
  /// while the Template Governance publisher is being wired into assignment.
  bool get canCreateLegacyJobTemplate => isApproved && (isAdmin || isSI);

  bool get canEditLegacyJobTemplate => canCreateLegacyJobTemplate;

  /// Deleting/retiring a legacy runtime template is stricter than creating or
  /// editing because it removes the template from active operational use.
  bool get canDeleteLegacyJobTemplate => isApproved && isAdmin;

  bool get canViewPlannedMaintenance => isApproved;

  bool get canViewClosedJobDossiers => isApproved;

  /// Planned job assignment is an operational authority event. Senior
  /// discipline users can assign work, but ordinary Operations/plain
  /// Refractory users cannot.
  bool get canAssignJobExecution =>
      isApproved &&
      (isAdmin ||
          isSI ||
          isContractSupervisor ||
          isShiftSupervisor ||
          isSeniorRole);

  /// Manual module addition changes the scope of an active planned job, so it
  /// follows the same authority as planned-job assignment.
  bool get canAddJobModuleDuringExecution => canAssignJobExecution;

  /// Admin-only back-office deletion of planned job executions from the
  /// Admin Data Browser. Normal job closure remains governed separately.
  bool get canDeleteJobExecution => isApproved && isAdmin;

  // ───────────────────────────────────────────────────────────
  // DIRECTIVE PERMISSIONS
  // ───────────────────────────────────────────────────────────

  bool get canCreateDirective =>
      isApproved &&
      (isAdmin ||
          isSI ||
          isContractSupervisor ||
          isShiftSupervisor ||
          isOperations);

  /// Supervisory/Admin actors may close any directive. Creators and
  /// acknowledged recipients are handled by [canCloseDirectiveInstance].
  bool get canCloseDirective =>
      isApproved &&
      (isAdmin || isSI || isContractSupervisor || isShiftSupervisor);

  /// Supervisors are deliberately allowed to close/override directive
  /// lifecycle state. Editing/deleting directive records remains Admin-only
  /// because it is a back-office correction function, not a field closure.
  bool get canOverrideDirectiveClose => canCloseDirective;

  bool get canEditDirective => isApproved && isAdmin;
  bool get canDeleteDirective => isApproved && isAdmin;

  bool canBeTarget(AppRole role) {
    return isApproved && roles.contains(role);
  }

  bool canAcknowledgeDirective(AppRole directedTo) {
    return isApproved && roles.contains(directedTo);
  }

  bool canCloseDirectiveInstance({
    required String? createdByUid,
    AppRole? directedTo,
    String? acknowledgedByUid,
  }) {
    if (!isApproved) return false;

    if (canCloseDirective) return true;

    if (createdByUid == uid) return true;

    if (directedTo != null &&
        acknowledgedByUid == uid &&
        canAcknowledgeDirective(directedTo)) {
      return true;
    }

    return false;
  }

  List<AppRole> get directiveTargets {
    if (isAdmin) {
      return AppRole.values.where((r) => r != AppRole.admin).toList();
    }

    if (isSI) {
      return [
        AppRole.contractSupervisor,
        AppRole.shiftSupervisor,
        AppRole.operations,
        AppRole.seniorElectrical,
        AppRole.seniorMechanical,
        AppRole.seniorInstrumentation,
        AppRole.seniorRefractory,
      ];
    }

    if (isContractSupervisor) {
      return [
        AppRole.shiftSupervisor,
        AppRole.operations,
        AppRole.seniorElectrical,
        AppRole.seniorMechanical,
        AppRole.seniorInstrumentation,
        AppRole.seniorRefractory,
      ];
    }

    if (isShiftSupervisor) {
      return [
        AppRole.operations,
        AppRole.seniorElectrical,
        AppRole.seniorMechanical,
        AppRole.seniorInstrumentation,
        AppRole.seniorRefractory,
      ];
    }

    if (isOperations) {
      return [
        AppRole.contractSupervisor,
        AppRole.shiftSupervisor,
        AppRole.seniorElectrical,
        AppRole.seniorMechanical,
        AppRole.seniorInstrumentation,
        AppRole.seniorRefractory,
      ];
    }

    return [];
  }

  Set<String> get _workflowRoleNames => roles.map((role) => role.name).toSet();

  bool _hasAnyWorkflowRole(Iterable<String> allowedRoles) {
    final current = _workflowRoleNames;
    return allowedRoles.any(current.contains);
  }

  // ───────────────────────────────────────────────────────────
  // PLANNED-MAINTENANCE MODULE PERMISSIONS
  // ───────────────────────────────────────────────────────────

  /// Supervisory actors can review and govern module lifecycle transitions.
  /// This intentionally excludes ordinary operations/refractory users so that
  /// submit/accept/reopen/not-applicable decisions remain auditable authority
  /// events rather than casual edits.
  bool get isModuleLifecycleSupervisor =>
      isApproved &&
      _hasAnyWorkflowRole(
        WorkflowPolicyGenerated.moduleLifecycleModeratorRoles,
      );

  bool get canAcceptJobModule => isModuleLifecycleSupervisor;
  bool get canReopenJobModule => isModuleLifecycleSupervisor;
  bool get canMarkJobModuleNotApplicable => isModuleLifecycleSupervisor;

  /// Saving module responses/work is limited to Admin/SI, supervisors, and
  /// senior discipline users. Ordinary Operations/plain Refractory can view
  /// planned work, but cannot mutate planned-maintenance module responses.
  bool get canSaveJobModuleWork =>
      isApproved &&
      WorkflowPolicyGenerated.moduleDisciplineWorkRoles.values.any(
        _hasAnyWorkflowRole,
      );

  /// Supervisors/Admin/SI can submit any module. Senior discipline users can
  /// submit only their own discipline lane. Operations users cannot submit
  /// planned-maintenance modules, including operations-discipline modules.
  bool canSubmitJobModule(String? moduleDisciplineName) {
    if (!isApproved) return false;
    final discipline = _canonicalModuleDisciplinePermissionKey(
      moduleDisciplineName,
    );
    final allowed =
        WorkflowPolicyGenerated.moduleDisciplineSubmitRoles[discipline];
    return allowed != null && _hasAnyWorkflowRole(allowed);
  }

  bool _canExecuteWorkflowCommand(String command) {
    if (!isApproved) return false;
    final allowed = WorkflowPolicyGenerated.commandAuthorityRoles[command];
    return allowed != null && _hasAnyWorkflowRole(allowed);
  }

  bool get canFinalizeMaintenanceLaneSet =>
      _canExecuteWorkflowCommand('finalizeLaneSet');

  bool get canCancelMaintenanceWorkflow =>
      _canExecuteWorkflowCommand('cancelWorkflow');

  bool get canPrepareMaintenanceRedLane =>
      _canExecuteWorkflowCommand('prepareRedLane');

  bool get canReconcileMaintenanceEquipment =>
      _canExecuteWorkflowCommand('reconcileEquipment');

  bool get canMarkMaintenanceWorkflowConditionDue =>
      _canExecuteWorkflowCommand('markConditionDue');

  bool get canDeployMaintenanceEquipment =>
      _canExecuteWorkflowCommand('deployEquipment');

  bool get canCoordinateMaintenanceCompliance =>
      _canExecuteWorkflowCommand('raiseComplianceCoordination');

  bool canRaiseMaintenanceComplianceFromLane(String? laneName) =>
      canCoordinateMaintenanceCompliance ||
      canAcknowledgeOrWorkMaintenanceLane(laneName);

  bool canAcknowledgeOrWorkMaintenanceLane(String? laneName) {
    if (!isApproved) return false;
    final laneKey = switch (_normalisePermissionKey(laneName)) {
      'electrical' => 'elec',
      'mechanical' => 'mech',
      'instrumentation' => 'inst',
      'operations' || 'shiftincharge' => 'oprn',
      'refractory' => 'red',
      'safety' || 'admin' || 'others' => 'shared',
      final value => value,
    };
    final policy = WorkflowPolicyGenerated.lanes[laneKey];
    return policy != null && _hasAnyWorkflowRole(policy.workRoles);
  }

  bool canCloseMaintenanceLane(String? laneName) {
    if (!isApproved) return false;
    final laneKey = switch (_normalisePermissionKey(laneName)) {
      'electrical' => 'elec',
      'mechanical' => 'mech',
      'instrumentation' => 'inst',
      'operations' || 'shiftincharge' => 'oprn',
      'refractory' => 'red',
      'safety' || 'admin' || 'others' => 'shared',
      final value => value,
    };
    final policy = WorkflowPolicyGenerated.lanes[laneKey];
    return policy != null && _hasAnyWorkflowRole(policy.closureRoles);
  }

  bool canSaveJobModuleWorkFor(String? moduleDisciplineName) {
    if (!isApproved) return false;
    final discipline = _canonicalModuleDisciplinePermissionKey(
      moduleDisciplineName,
    );
    final allowed =
        WorkflowPolicyGenerated.moduleDisciplineWorkRoles[discipline];
    return allowed != null && _hasAnyWorkflowRole(allowed);
  }

  // ───────────────────────────────────────────────────────────
  // JOB DIARY PERMISSIONS
  // ───────────────────────────────────────────────────────────

  bool get canCreateJobDiaryEntry =>
      isApproved &&
      (isAdmin ||
          isSI ||
          isContractSupervisor ||
          isShiftSupervisor ||
          isSeniorRole);

  bool canEditJobDiaryEntry({required String? createdByUid}) {
    if (!isApproved) return false;
    if (isAdmin || isSI) return true;
    return createdByUid == uid;
  }

  // ───────────────────────────────────────────────────────────
  // ABNORMALITY PERMISSIONS
  // ───────────────────────────────────────────────────────────

  bool get canManageAbnormalityTypes => isApproved && isAdmin;

  bool get canLogChargeAbnormality =>
      isApproved &&
      (isAdmin ||
          isSI ||
          isContractSupervisor ||
          isShiftSupervisor ||
          isOperations);

  bool get canEditChargeAbnormality => isApproved && isAdmin;

  bool get canSoftDeleteChargeAbnormality => isApproved && isAdmin;

  // ───────────────────────────────────────────────────────────
  // TEMPLATE GOVERNANCE PERMISSIONS
  // ───────────────────────────────────────────────────────────

  /// Template governance is intentionally narrower than ordinary template
  /// editing. Admin/SI can create drafts, publish immutable versions, retire
  /// versions, and manage the governance audit trail. Runtime job execution
  /// and closed-job dossier flows remain separately governed.
  bool get canManageTemplateGovernance => isApproved && (isAdmin || isSI);

  bool get canViewMaintenanceWorkflowDiagnostics =>
      isApproved && (isAdmin || isSI);

  bool get canPublishTemplateVersion => canManageTemplateGovernance;
  bool get canRetireTemplateVersion => canManageTemplateGovernance;

  // ───────────────────────────────────────────────────────────
  // PLANNED-MAINTENANCE JOB COMPLETION PERMISSIONS
  // ───────────────────────────────────────────────────────────

  /// Final planned-job closure is a supervisory authority event.
  /// The module closure gate decides whether the dossier is ready; this
  /// predicate decides whether the actor may perform the final closure action.
  bool get canCompleteJobExecution => isModuleLifecycleSupervisor;

  // ───────────────────────────────────────────────────────────
  // SERIALIZATION
  // ───────────────────────────────────────────────────────────

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    final parsedRoles = _parseRoles(data['roles']);
    final source = 'users/$uid';
    return AppUser(
      uid: uid,
      name: readRequiredPersistedString(
        data['name'],
        field: 'name',
        source: source,
      ),
      email: readRequiredPersistedString(
        data['email'],
        field: 'email',
        source: source,
      ),
      photoUrl: readOptionalPersistedString(
        data['photoUrl'],
        field: 'photoUrl',
        source: source,
      ),
      roles: parsedRoles,
      // A malformed role payload cannot remain an approved local authority.
      isApproved: data['isApproved'] == true && parsedRoles.isNotEmpty,
      fcmToken: readOptionalPersistedString(
        data['fcmToken'],
        field: 'fcmToken',
        source: source,
      ),
      createdAt: readRequiredPersistedDateTime(
        data['createdAt'],
        field: 'createdAt',
        source: source,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'email': email.trim(),
      'photoUrl': photoUrl?.trim().isEmpty == true ? null : photoUrl,
      'roles': roles.map((r) => r.name).toList(),
      'isApproved': isApproved,
      'fcmToken': fcmToken,
      'createdAt': createdAt,
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? photoUrl,
    List<AppRole>? roles,
    bool? isApproved,
    String? fcmToken,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      roles: roles ?? this.roles,
      isApproved: isApproved ?? this.isApproved,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
