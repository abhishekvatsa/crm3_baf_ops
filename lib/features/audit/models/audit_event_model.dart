import 'dart:convert';
import 'package:isar/isar.dart';

import '../../../core/serialization/persisted_data_reader.dart';

part 'audit_event_model.g.dart';

// ─────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────

enum AuditAction { create, update, resolve, reopen, delete }

enum AuditReason {
  duplicate,
  incorrectEntry,
  merged,
  invalid,
  manualOverride,
  other,
}

enum AuditSeverity { low, medium, high }

// ─────────────────────────────────────────────────────────────
// AUDIT CONTEXT (INPUT → NOT STORED)
// ─────────────────────────────────────────────────────────────

class AuditContext {
  final String performedByUid;
  final String? performedByName;

  final AuditReason? reason;
  final String? reasonNotes;

  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  final String? summary;
  final AuditSeverity severity;

  const AuditContext({
    required this.performedByUid,
    this.performedByName,
    this.reason,
    this.reasonNotes,
    this.before,
    this.after,
    this.summary,
    this.severity = AuditSeverity.low,
  });

  AuditContext copyWith({
    String? performedByUid,
    String? performedByName,
    AuditReason? reason,
    String? reasonNotes,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    String? summary,
    AuditSeverity? severity,
  }) {
    return AuditContext(
      performedByUid: performedByUid ?? this.performedByUid,
      performedByName: performedByName ?? this.performedByName,
      reason: reason ?? this.reason,
      reasonNotes: reasonNotes ?? this.reasonNotes,
      before: before ?? this.before,
      after: after ?? this.after,
      summary: summary ?? this.summary,
      severity: severity ?? this.severity,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AUDIT EVENT (PERSISTED COLLECTION)
// ─────────────────────────────────────────────────────────────

@Collection()
class AuditEvent {
  Id id = Isar.autoIncrement;

  // ───────── Core identity ─────────

  @Index()
  late String entityType;

  @Index()
  late String entityId;

  // ───────── Action ─────────

  @Enumerated(EnumType.name)
  late AuditAction action;

  @Enumerated(EnumType.name)
  AuditSeverity severity = AuditSeverity.low;

  // ───────── Actor ─────────

  @Index()
  late String performedByUid;

  String? performedByName;

  // ───────── Time ─────────

  @Index()
  DateTime timestamp = DateTime.now();

  // ───────── Reason ─────────

  @Enumerated(EnumType.name)
  AuditReason? reason;

  String? reasonNotes;

  // ───────── Fast UI field ─────────

  String? summary;

  // ───────── Snapshot storage (JSON) ─────────

  String? beforeJson;
  String? afterJson;

  // ───────── Sync flag ─────────

  bool isSynced = false;

  // ─────────────────────────────────────────────
  // CONSTRUCTOR
  // ─────────────────────────────────────────────

  AuditEvent({
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.performedByUid,
    this.performedByName,
    // Note: timestamp removed from constructor to satisfy strict isar_generator types
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    this.reason,
    this.reasonNotes,
    this.summary,
    this.severity = AuditSeverity.low,
  }) {
    this.before = before;
    this.after = after;
  }

  // ─────────────────────────────────────────────
  // STRICT JSON SNAPSHOT ACCESS
  // ─────────────────────────────────────────────

  @ignore
  Map<String, dynamic>? get before => readOptionalJsonObject(
    beforeJson,
    field: 'beforeJson',
    source: 'local audit event $id',
  );

  set before(Map<String, dynamic>? value) {
    beforeJson = value == null ? null : jsonEncode(value);
  }

  @ignore
  Map<String, dynamic>? get after => readOptionalJsonObject(
    afterJson,
    field: 'afterJson',
    source: 'local audit event $id',
  );

  set after(Map<String, dynamic>? value) {
    afterJson = value == null ? null : jsonEncode(value);
  }

  // ─────────────────────────────────────────────
  // FACTORY FROM CONTEXT (CLEAN CREATION)
  // ─────────────────────────────────────────────

  factory AuditEvent.fromContext({
    required String entityType,
    required String entityId,
    required AuditAction action,
    required AuditContext context,
  }) {
    return AuditEvent(
      entityType: entityType,
      entityId: entityId,
      action: action,
      performedByUid: context.performedByUid,
      performedByName: context.performedByName,
      reason: context.reason,
      reasonNotes: context.reasonNotes,
      summary: context.summary,
      severity: context.severity,
      before: context.before,
      after: context.after,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SYNC REJECTION (LOCAL-ONLY DURABLE SYNC DIAGNOSTIC)
// ─────────────────────────────────────────────────────────────

@Collection()
class SyncRejection {
  Id id = Isar.autoIncrement;

  @Index()
  late String entityType;

  @Index()
  late String entityId;

  String? firestoreId;
  String? errorCode;
  late String message;

  /// Authenticated user whose rejected write produced this evidence.
  /// Legacy rows remain null and cannot be self-discarded.
  @Index()
  String? originatingUid;

  @Index()
  DateTime firstSeenAt = DateTime.now();

  @Index()
  DateTime lastSeenAt = DateTime.now();

  int attemptCount = 1;
  bool isLikelyPermanent = false;

  @Index()
  bool isResolved = false;

  DateTime? resolvedAt;
  String? resolvedByUid;
  String? resolvedByName;
  String? resolutionNotes;

  @ignore
  String get shortLabel => '$entityType/$entityId';

  @ignore
  String get displayMessage {
    final code = errorCode == null ? '' : '[$errorCode] ';
    return '$code$message';
  }

  void markSeenAgain({
    required String message,
    String? errorCode,
    String? firestoreId,
    String? originatingUid,
    required bool isLikelyPermanent,
    DateTime? at,
  }) {
    this.message = message;
    this.errorCode = errorCode;
    this.firestoreId = firestoreId ?? this.firestoreId;
    this.originatingUid ??= originatingUid;
    this.isLikelyPermanent = isLikelyPermanent;
    lastSeenAt = at ?? DateTime.now();
    attemptCount += 1;
    isResolved = false;
    resolvedAt = null;
    resolvedByUid = null;
    resolvedByName = null;
    resolutionNotes = null;
  }

  void markResolved({
    String? resolvedByUid,
    String? resolvedByName,
    String? notes,
    DateTime? at,
  }) {
    isResolved = true;
    resolvedAt = at ?? DateTime.now();
    this.resolvedByUid = resolvedByUid;
    this.resolvedByName = resolvedByName;
    resolutionNotes = notes;
  }
}
