import 'dart:collection';

import 'workflow_actor.dart';
import 'workflow_error.dart';
import 'workflow_policy_generated.dart';

class MaintenanceLaneId implements Comparable<MaintenanceLaneId> {
  final String value;
  const MaintenanceLaneId._(this.value);

  static const electrical = MaintenanceLaneId._('elec');
  static const mechanical = MaintenanceLaneId._('mech');
  static const instrumentation = MaintenanceLaneId._('inst');
  static const operations = MaintenanceLaneId._('oprn');
  static const emd = MaintenanceLaneId._('emd');
  static const refractory = MaintenanceLaneId._('red');
  static const shared = MaintenanceLaneId._('shared');

  static const values = <MaintenanceLaneId>[
    electrical,
    mechanical,
    instrumentation,
    operations,
    emd,
    refractory,
    shared,
  ];

  static MaintenanceLaneId? tryParse(String? raw) {
    final key = raw?.trim().toLowerCase();
    for (final lane in values) {
      if (lane.value == key) return lane;
    }
    return null;
  }

  static MaintenanceLaneId parse(String raw) {
    final result = tryParse(raw);
    if (result == null) {
      throw WorkflowException(
        WorkflowErrorCode.invalidArgument,
        'Unknown maintenance lane "$raw".',
      );
    }
    return result;
  }

  @override
  int compareTo(MaintenanceLaneId other) => value.compareTo(other.value);
  @override
  bool operator ==(Object other) => other is MaintenanceLaneId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

class MaintenanceLaneDefinition {
  final MaintenanceLaneId id;
  final String code;
  final String displayName;
  final Set<String> acknowledgementRoles;
  final Set<String> workRoles;
  final Set<String> closureRoles;
  final bool delegated;
  final String? delegationBasis;

  const MaintenanceLaneDefinition({
    required this.id,
    required this.code,
    required this.displayName,
    required this.acknowledgementRoles,
    required this.workRoles,
    required this.closureRoles,
    required this.delegated,
    required this.delegationBasis,
  });

  bool mayAcknowledge(WorkflowActorContext actor) => actor.hasAnyRole(acknowledgementRoles);
  bool mayWork(WorkflowActorContext actor) => actor.hasAnyRole(workRoles);
  bool mayClose(WorkflowActorContext actor) => actor.hasAnyRole(closureRoles);
}

class MaintenanceLaneCatalog {
  final Map<MaintenanceLaneId, MaintenanceLaneDefinition> _definitions;

  MaintenanceLaneCatalog._(this._definitions);

  static final MaintenanceLaneCatalog crm3 = MaintenanceLaneCatalog._(
    Map.unmodifiable(<MaintenanceLaneId, MaintenanceLaneDefinition>{
      for (final lane in MaintenanceLaneId.values)
        lane: _fromGenerated(lane),
    }),
  );

  static MaintenanceLaneDefinition _fromGenerated(MaintenanceLaneId lane) {
    final generated = WorkflowPolicyGenerated.lanes[lane.value];
    if (generated == null) {
      throw StateError('No generated policy for lane ${lane.value}.');
    }
    return MaintenanceLaneDefinition(
      id: lane,
      code: generated.code,
      displayName: generated.name,
      acknowledgementRoles: generated.acknowledgementRoles,
      workRoles: generated.workRoles,
      closureRoles: generated.closureRoles,
      delegated: generated.delegated,
      delegationBasis: generated.delegationBasis,
    );
  }

  UnmodifiableListView<MaintenanceLaneDefinition> get definitions =>
      UnmodifiableListView(_definitions.values.toList(growable: false));

  MaintenanceLaneDefinition definition(MaintenanceLaneId lane) {
    final result = _definitions[lane];
    if (result == null) throw StateError('Lane ${lane.value} is not configured.');
    return result;
  }
}
