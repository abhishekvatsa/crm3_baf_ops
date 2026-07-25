// GENERATED FILE. Source: governance/maintenance_workflow_policy_v1.json
// Do not edit manually.
abstract final class WorkflowPolicyGenerated {
  static const int schemaVersion = 2;
  static const String policyId = 'crm3-maintenance-workflow-v2';
  static const bool onlineOnlyLifecycleCommands = true;
  static const Set<String> laneSetFinalizerRoles = <String>{'admin', 'si', 'contractSupervisor'};
  static const Set<String> moduleLifecycleModeratorRoles = <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'};
  static const Map<String, Set<String>> commandAuthorityRoles = <String, Set<String>>{
    'finalizeLaneSet': <String>{'admin', 'si', 'contractSupervisor'},
    'manageLanePopulation': <String>{'admin', 'si', 'contractSupervisor'},
    'cancelWorkflow': <String>{'admin', 'si', 'contractSupervisor'},
    'finalizeJob': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
    'markConditionDue': <String>{'admin', 'si', 'operations', 'shiftSupervisor'},
    'deployEquipment': <String>{'admin', 'si', 'operations', 'shiftSupervisor'},
    'reconcileEquipment': <String>{'admin', 'si'},
    'prepareRedLane': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorElectrical', 'seniorMechanical', 'seniorInstrumentation', 'seniorRefractory'},
    'reopenWorkflowModule': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
  };
  static const Set<String> workflowRoleUniverse = <String>{'admin', 'si', 'contractSupervisor', 'seniorElectrical', 'seniorMechanical', 'seniorInstrumentation', 'operations', 'shiftSupervisor', 'refractory', 'seniorRefractory'};
  static const Set<String> redApplicableAssetTypes = <String>{'base', 'furnace'};
  static const Set<String> standPreparationAssetTypes = <String>{'furnace'};
  static const int criticalAcknowledgementMinutes = 30;
  static const int normalAcknowledgementMinutes = 240;
  static const int complianceAcknowledgementMinutes = 240;
  static const int complianceAfterConditionMinutes = 480;
  static const Map<String, WorkflowLanePolicyGenerated> lanes = <String, WorkflowLanePolicyGenerated>{
    'elec': WorkflowLanePolicyGenerated(
      key: 'elec', code: 'ELEC', name: 'Electrical',
      acknowledgementRoles: <String>{'admin', 'si', 'seniorElectrical'},
      workRoles: <String>{'admin', 'si', 'seniorElectrical'},
      closureRoles: <String>{'admin', 'si', 'seniorElectrical'},
      delegated: false,
      delegationBasis: null,
    ),
    'mech': WorkflowLanePolicyGenerated(
      key: 'mech', code: 'MECH', name: 'Mechanical',
      acknowledgementRoles: <String>{'admin', 'si', 'seniorMechanical'},
      workRoles: <String>{'admin', 'si', 'seniorMechanical'},
      closureRoles: <String>{'admin', 'si', 'seniorMechanical'},
      delegated: false,
      delegationBasis: null,
    ),
    'inst': WorkflowLanePolicyGenerated(
      key: 'inst', code: 'I&A', name: 'Instrumentation & Automation',
      acknowledgementRoles: <String>{'admin', 'si', 'seniorInstrumentation'},
      workRoles: <String>{'admin', 'si', 'seniorInstrumentation'},
      closureRoles: <String>{'admin', 'si', 'seniorInstrumentation'},
      delegated: false,
      delegationBasis: null,
    ),
    'oprn': WorkflowLanePolicyGenerated(
      key: 'oprn', code: 'OPRN', name: 'Operations',
      acknowledgementRoles: <String>{'admin', 'si', 'operations', 'shiftSupervisor'},
      workRoles: <String>{'admin', 'si', 'operations', 'shiftSupervisor'},
      closureRoles: <String>{'admin', 'si', 'shiftSupervisor'},
      delegated: false,
      delegationBasis: null,
    ),
    'emd': WorkflowLanePolicyGenerated(
      key: 'emd', code: 'EMD', name: 'EMD',
      acknowledgementRoles: <String>{'admin', 'si'},
      workRoles: <String>{'admin', 'si'},
      closureRoles: <String>{'admin', 'si'},
      delegated: true,
      delegationBasis: 'plant-v1-emd-admin-si-coordination',
    ),
    'red': WorkflowLanePolicyGenerated(
      key: 'red', code: 'RED', name: 'Refractory Engineering Department',
      acknowledgementRoles: <String>{'admin', 'si', 'refractory', 'seniorRefractory'},
      workRoles: <String>{'admin', 'si', 'refractory', 'seniorRefractory'},
      closureRoles: <String>{'admin', 'si', 'seniorRefractory'},
      delegated: false,
      delegationBasis: null,
    ),
    'shared': WorkflowLanePolicyGenerated(
      key: 'shared', code: 'SHARED', name: 'Shared / Safety / Administration',
      acknowledgementRoles: <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
      workRoles: <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
      closureRoles: <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
      delegated: true,
      delegationBasis: 'plant-v2-shared-coordination',
    ),
  };
  static const Map<String, String> moduleDisciplineLaneMap = <String, String>{
    'electrical': 'elec',
    'mechanical': 'mech',
    'instrumentation': 'inst',
    'operations': 'oprn',
    'shiftInCharge': 'oprn',
    'emd': 'emd',
    'refractory': 'red',
    'safety': 'shared',
    'admin': 'shared',
    'shared': 'shared',
    'others': 'shared',
  };
  static const Map<String, Set<String>> moduleDisciplineWorkRoles = <String, Set<String>>{
    'electrical': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorElectrical'},
    'mechanical': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorMechanical'},
    'instrumentation': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorInstrumentation'},
    'operations': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'operations'},
    'shiftInCharge': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
    'emd': <String>{'admin', 'si'},
    'refractory': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'refractory', 'seniorRefractory'},
    'safety': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
    'admin': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
    'shared': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
    'others': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorRefractory'},
  };
  static const Map<String, Set<String>> moduleDisciplineSubmitRoles = <String, Set<String>>{
    'electrical': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorElectrical'},
    'mechanical': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorMechanical'},
    'instrumentation': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorInstrumentation'},
    'operations': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'operations'},
    'shiftInCharge': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
    'emd': <String>{'admin', 'si'},
    'refractory': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'refractory', 'seniorRefractory'},
    'safety': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
    'admin': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
    'shared': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor'},
    'others': <String>{'admin', 'si', 'contractSupervisor', 'shiftSupervisor', 'seniorRefractory'},
  };
}

class WorkflowLanePolicyGenerated {
  final String key;
  final String code;
  final String name;
  final Set<String> acknowledgementRoles;
  final Set<String> workRoles;
  final Set<String> closureRoles;
  final bool delegated;
  final String? delegationBasis;
  const WorkflowLanePolicyGenerated({required this.key, required this.code, required this.name, required this.acknowledgementRoles, required this.workRoles, required this.closureRoles, required this.delegated, required this.delegationBasis});
}
