import 'dart:convert';

T _enumByNameOr<T extends Enum>(
    List<T> values,
    dynamic value,
    T fallback,
    ) {
  if (value is! String) return fallback;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return fallback;
}

T? _enumByNameOrNull<T extends Enum>(List<T> values, dynamic value) {
  if (value is! String) return null;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────
// ACTION TYPE (WHAT WAS DONE)
// ─────────────────────────────────────────────────────────────

enum ActionType { issue, repair, replacement, inspection }

// ─────────────────────────────────────────────────────────────
// REPLACEMENT TYPE
// ─────────────────────────────────────────────────────────────

enum ReplacementType { newPart, repaired, revised }

// ─────────────────────────────────────────────────────────────
// SEVERITY (ALREADY PRESENT)
// ─────────────────────────────────────────────────────────────

enum ActionSeverity { low, medium, high, critical }

// ─────────────────────────────────────────────────────────────
// 🔥 NEW (NON-BREAKING): LIFECYCLE STATUS
// ─────────────────────────────────────────────────────────────

enum ActionStatus { issue, inProgress, resolved }

// ─────────────────────────────────────────────────────────────
// COMPONENT ACTION MODEL
// ─────────────────────────────────────────────────────────────

class ComponentAction {
  // ── Identity ───────────────────────────────────────────────
  final String? id;

  // ── Core ───────────────────────────────────────────────────
  final String asset;
  final String component;

  // ── Hierarchy ──────────────────────────────────────────────
  final List<String>? hierarchyPath;

  // ── Context ────────────────────────────────────────────────
  final String? system;
  final String? subsystem;
  final String? subComponent;
  final String? tag;
  final String? instance;

  // ── Action ─────────────────────────────────────────────────
  final ActionType actionType;
  final ReplacementType? replacement;

  // ── Description ────────────────────────────────────────────
  final String? issue;
  final String? resolution;
  final String? remarks;

  // ── Linkage ────────────────────────────────────────────────
  final String? templateFieldKey;

  // ── Intelligence ───────────────────────────────────────────
  final bool isAutoResolved;

  // ── Lifecycle ──────────────────────────────────────────────
  final ActionStatus? status; // 🔥 upgraded (was String?)

  final DateTime createdAt;

  // ── Extended (existing) ────────────────────────────────────
  final ActionSeverity severity;
  final String? performedBy;
  final DateTime? updatedAt;
  final int version;
  final String? metadataJson;

  ComponentAction({
    this.id,
    required this.asset,
    required this.component,
    this.hierarchyPath,
    this.system,
    this.subsystem,
    this.subComponent,
    this.tag,
    this.instance,
    required this.actionType,
    this.replacement,
    this.issue,
    this.resolution,
    this.remarks,
    this.templateFieldKey,
    this.isAutoResolved = false,
    this.status,
    DateTime? createdAt,
    this.severity = ActionSeverity.medium,
    this.performedBy,
    this.updatedAt,
    this.version = 1,
    this.metadataJson,
  }) : createdAt = createdAt ?? DateTime.now();

  // ─────────────────────────────────────────────
  // SERIALIZATION
  // ─────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id': id,
    'asset': asset,
    'component': component,
    'hierarchyPath': hierarchyPath,
    'system': system,
    'subsystem': subsystem,
    'subComponent': subComponent,
    'tag': tag,
    'instance': instance,
    'actionType': actionType.name,
    'replacement': replacement?.name,
    'issue': issue,
    'resolution': resolution,
    'remarks': remarks,
    'templateFieldKey': templateFieldKey,
    'isAutoResolved': isAutoResolved,

    // 🔥 NEW STRUCTURED STATUS
    'status': status?.name,

    'createdAt': createdAt.toIso8601String(),

    // existing extended fields
    'severity': severity.name,
    'performedBy': performedBy,
    'updatedAt': updatedAt?.toIso8601String(),
    'version': version,
    'metadataJson': metadataJson,
  };

  factory ComponentAction.fromMap(Map<String, dynamic> map) {
    return ComponentAction(
      id: map['id'],
      asset: map['asset'] ?? '',
      component: map['component'] ?? '',

      hierarchyPath: (map['hierarchyPath'] as List?)
          ?.map((e) => e.toString())
          .toList(),

      system: map['system'],
      subsystem: map['subsystem'],
      subComponent: map['subComponent'],
      tag: map['tag'],
      instance: map['instance'],

      actionType: _enumByNameOr(
        ActionType.values,
        map['actionType'],
        ActionType.issue,
      ),

      replacement: _enumByNameOrNull(
        ReplacementType.values,
        map['replacement'],
      ),

      issue: map['issue'],
      resolution: map['resolution'],
      remarks: map['remarks'],
      templateFieldKey: map['templateFieldKey'],
      isAutoResolved: map['isAutoResolved'] ?? false,

      // 🔥 SAFE STATUS PARSING
      status: _enumByNameOrNull(ActionStatus.values, map['status']),

      createdAt:
      DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),

      // existing safe parsing
      severity: _enumByNameOr(
        ActionSeverity.values,
        map['severity'],
        ActionSeverity.medium,
      ),

      performedBy: map['performedBy'],

      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,

      version: map['version'] ?? 1,
      metadataJson: map['metadataJson'],
    );
  }

  // ─────────────────────────────────────────────
  // JSON HELPERS
  // ─────────────────────────────────────────────

  static String encode(List<ComponentAction> actions) =>
      jsonEncode(actions.map((e) => e.toMap()).toList());

  static List<ComponentAction> decode(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List data = jsonDecode(jsonStr);
      return data
          .map((e) => ComponentAction.fromMap(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}