import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../../../core/persistence/durable_submission.dart';
import '../../maintenance_workflow/data/workflow_command_receipt_record.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../data/maintenance_model.dart';
import '../services/maintenance_issue_create_command.dart';
import 'maintenance_ticket_correction.dart';

String maintenanceReviewJson(Object? value) {
  Object? ordered(Object? item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: ordered(item[key])};
    }
    if (item is List) return item.map(ordered).toList();
    return item;
  }

  return jsonEncode(ordered(value));
}

Map<String, Object?> maintenanceCorrectionValues(MaintenanceRecord row) => {
  'description': row.description,
  'routedTo': row.routedTo.name,
  'maintenanceType': row.maintenanceType.name,
  'isCritical': row.isCritical,
  'plantConditionEffect': row.effectivePlantConditionEffect.name,
  'component': cleanMaintenanceOptionalText(row.component ?? ''),
  'subsystem': cleanMaintenanceOptionalText(row.subsystem ?? ''),
  'tag': cleanMaintenanceTagText(row.tag ?? ''),
  'classification': cleanMaintenanceOptionalText(row.classification ?? ''),
  'otherDepartment': cleanMaintenanceOptionalText(row.otherDepartment ?? ''),
  'remarks': cleanMaintenanceOptionalText(row.remarks ?? ''),
};

/// Only device transport identity/state is excluded. Business identity,
/// chronology, provenance, workflow fields and generated projections remain.
const maintenanceReviewLocalFieldExclusions = {
  'id': 'Device-only Isar primary key; server identity is firestoreId.',
  'isSynced': 'Device-only transport flag; it grants no business authority.',
};

/// Uses the very serializer that writes native records, rather than maintaining
/// another field list. New supported schema fields participate automatically;
/// an unsupported generated writer method or incomplete schema fails closed.
Map<String, Object?> maintenancePersistedReviewValues(MaintenanceRecord row) {
  final writer = _MaintenanceReviewWriter();
  final offsets = List<int>.generate(
    MaintenanceRecordSchema.properties.length,
    (index) => index,
  );
  // Intentional read-only use of the generated codec; no database is written.
  // ignore: invalid_use_of_protected_member
  MaintenanceRecordSchema.serialize(row, writer, offsets, {});
  if (writer.values.length != MaintenanceRecordSchema.properties.length ||
      !writer.values.keys.toSet().containsAll(
        MaintenanceRecordSchema.properties.keys,
      )) {
    throw StateError(
      'The complete persisted maintenance review could not be constructed.',
    );
  }
  return Map.unmodifiable({
    for (final entry in writer.values.entries)
      if (!maintenanceReviewLocalFieldExclusions.containsKey(entry.key))
        entry.key: entry.value,
  });
}

class _MaintenanceReviewWriter implements IsarWriter {
  final values = <String, Object?>{};
  final _properties = {
    for (final property in MaintenanceRecordSchema.properties.values)
      property.id: property,
  };

  void _write(int offset, IsarType type, Object? value) {
    final property = _properties[offset];
    if (property == null ||
        property.type != type ||
        values.containsKey(property.name)) {
      throw StateError(
        'The persisted maintenance schema disagrees with its generated serializer.',
      );
    }
    values[property.name] = value;
  }

  @override
  void writeBool(int offset, bool? value) =>
      _write(offset, IsarType.bool, value);
  @override
  void writeLong(int offset, int? value) =>
      _write(offset, IsarType.long, value);
  @override
  void writeDouble(int offset, double? value) {
    if (value != null && !value.isFinite) {
      throw StateError(
        'A non-finite persisted maintenance number cannot be reviewed as valid evidence.',
      );
    }
    _write(offset, IsarType.double, value);
  }

  @override
  void writeString(int offset, String? value) =>
      _write(offset, IsarType.string, value);
  @override
  void writeDateTime(int offset, DateTime? value) =>
      _write(offset, IsarType.dateTime, value?.toUtc().toIso8601String());
  @override
  void writeStringList(int offset, List<String?>? values) => _write(
    offset,
    IsarType.stringList,
    values == null ? null : List<String?>.unmodifiable(values),
  );

  // A future schema using a new native type must be reviewed explicitly; never
  // omit that field and falsely certify a partial comparison as complete.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unsupported persisted maintenance review field type: ${invocation.memberName}.',
  );
}

/// Every persisted server field fences same-version contradictions.
String maintenanceReviewServerBoundary(MaintenanceRecord row) =>
    maintenanceReviewJson(maintenancePersistedReviewValues(row));

class MaintenanceRetainedFieldDifference {
  const MaintenanceRetainedFieldDifference(this.deviceValue, this.serverValue);
  final Object? deviceValue, serverValue;
  String get disposition => 'retainDeviceEvidenceKeepServer';
  Map<String, Object?> toMap() => {
    'deviceValue': deviceValue,
    'serverValue': serverValue,
    'disposition': disposition,
  };
}

Map<String, Object?> maintenanceReviewReceiptMap(
  WorkflowCommandReceipt receipt,
) => {
  'commandId': receipt.commandId,
  'resultKey': receipt.resultKey,
  'aggregateVersion': receipt.aggregateVersion,
  'result': receipt.result,
  'appliedAt': receipt.appliedAt.toUtc().toIso8601String(),
};

/// Read-only evidence of A. Reading an accepted envelope never dispatches A or
/// changes its original actor to the supervisor reviewing B.
class MaintenanceCreationAcceptance {
  const MaintenanceCreationAcceptance({
    required this.envelopeJson,
    required this.actorUid,
    required this.command,
    required this.receipt,
  });
  final String envelopeJson, actorUid;
  final WorkflowCommand command;
  final WorkflowCommandReceipt receipt;

  factory MaintenanceCreationAcceptance.fromRecord(
    WorkflowCommandReceiptRecord row,
    String ticketId,
  ) {
    final saved = durableSubmissionJsonObject(row.resultJson);
    final envelopeJson = saved['__workflowAcceptedEnvelopeV1'];
    if (saved.length != 2 ||
        envelopeJson is! String ||
        saved['result'] is! Map) {
      throw StateError(
        'The original acceptance has incomplete evidence. Nothing was replaced.',
      );
    }
    final envelope = durableSubmissionJsonObject(envelopeJson);
    final raw = envelope['command'];
    final actor = envelope['originActorUid'];
    if (envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        actor is! String ||
        actor.isEmpty ||
        actor.trim() != actor ||
        raw is! Map<String, dynamic> ||
        raw.length != 5 ||
        raw['commandType'] != 'createMaintenanceTicket' ||
        raw['commandId'] !=
            maintenanceIssueCreateCommandIdForTicket(ticketId) ||
        raw['aggregateId'] != ticketId ||
        raw['expectedVersion'] != 0 ||
        raw['payload'] is! Map<String, dynamic> ||
        row.commandId != raw['commandId'] ||
        row.aggregateId != ticketId) {
      throw StateError(
        'The original creation identity or account is inconsistent. Nothing was replaced.',
      );
    }
    final command = WorkflowCommand(
      commandId: row.commandId,
      type: WorkflowCommandType.createMaintenanceTicket,
      aggregateId: ticketId,
      expectedVersion: 0,
      payload: Map<String, Object?>.from(raw['payload'] as Map),
    );
    final receipt = WorkflowCommandReceipt.fromMap({
      'commandId': row.commandId,
      'resultKey': row.resultKey,
      'aggregateVersion': row.aggregateVersion,
      'result': saved['result'],
      'appliedAt': row.appliedAt.toUtc().toIso8601String(),
    });
    validateMaintenanceIssueCreateReceipt(
      command: command,
      receipt: receipt,
      createVersion: 1,
    );
    return MaintenanceCreationAcceptance(
      envelopeJson: envelopeJson,
      actorUid: actor,
      command: command,
      receipt: receipt,
    );
  }

  void validateServer(MaintenanceRecord server) {
    if (server.firestoreId != command.aggregateId ||
        server.isDeleted ||
        server.version < 1 ||
        server.loggedByUid != actorUid ||
        !server.createdAt.isAtSameMomentAs(receipt.appliedAt)) {
      throw StateError(
        'The confirmed server issue does not match the original accepted creation. Both records are retained.',
      );
    }
  }
}

class MaintenanceCreationSuccessorReview {
  MaintenanceCreationSuccessorReview({
    required this.acceptance,
    required this.local,
    required this.server,
    required this.localSnapshotJson,
  }) : _localPersisted = maintenancePersistedReviewValues(local),
       _serverPersisted = maintenancePersistedReviewValues(server) {
    acceptance.validateServer(server);
    if (local.firestoreId != server.firestoreId ||
        local.isSynced ||
        local.isDeleted) {
      throw StateError(
        'This device no longer holds the pending draft selected for review.',
      );
    }
  }
  final MaintenanceCreationAcceptance acceptance;
  final MaintenanceRecord local, server;

  /// Complete native Isar export, including every persisted property and raw
  /// JSON string. Never substitute MaintenanceRecord.toAuditMap for this.
  final String localSnapshotJson;
  final Map<String, Object?> _localPersisted, _serverPersisted;
  String get serverBoundaryJson => maintenanceReviewJson(_serverPersisted);
  String get ticketId => acceptance.command.aggregateId;
  String get originalActorUid => acceptance.actorUid;
  String get originalEnvelopeJson => acceptance.envelopeJson;
  Map<String, Object?> get originalValues {
    final ticket = acceptance.command.payload['ticket'] as Map;
    return {
      for (final key in maintenanceCorrectionValues(local).keys)
        key: key == 'remarks' ? null : ticket[key],
    };
  }

  Map<String, Object?> get localValues => maintenanceCorrectionValues(local);
  Map<String, Object?> get serverValues => maintenanceCorrectionValues(server);
  List<String> get changedFields => [
    for (final key in localValues.keys)
      if (maintenanceReviewJson(originalValues[key]) !=
          maintenanceReviewJson(localValues[key]))
        key,
  ];

  /// B-versus-C differences are not proof that the user edited B: C may have
  /// advanced since A. Every unsupported persisted difference is disclosed
  /// with both values and its retained-evidence/keep-server disposition.
  Map<String, MaintenanceRetainedFieldDifference> get unsupportedDifferences =>
      Map.unmodifiable({
        for (final field in _localPersisted.keys)
          if (!localValues.containsKey(field) &&
              maintenanceReviewJson(_localPersisted[field]) !=
                  maintenanceReviewJson(_serverPersisted[field]))
            field: MaintenanceRetainedFieldDifference(
              _localPersisted[field],
              _serverPersisted[field],
            ),
      });

  List<String> get unsupportedChanges =>
      List.unmodifiable(unsupportedDifferences.keys);

  bool get hasDifferences =>
      changedFields.isNotEmpty || unsupportedChanges.isNotEmpty;

  Map<String, Object?> evidence({
    required String reason,
    required Map<String, Object?> corrections,
    required String disposition,
    String? targetReferenceJson,
  }) => {
    'schemaVersion': 1,
    'kind': 'maintenanceCreationSuccessorReview',
    'ticketId': ticketId,
    'originalEnvelopeJson': originalEnvelopeJson,
    'originalReceipt': maintenanceReviewReceiptMap(acceptance.receipt),
    'localSnapshotJson': localSnapshotJson,
    'serverBoundaryJson': serverBoundaryJson,
    'originalValues': originalValues,
    'localValues': localValues,
    'serverValues': serverValues,
    'selectedCorrections': corrections,
    'retainedCorrectableFields': [
      for (final field in changedFields)
        if (!corrections.containsKey(field)) field,
    ],
    'targetReferenceJson': targetReferenceJson,
    'retainedUnsupportedChanges': unsupportedChanges,
    'retainedUnsupportedDifferences': {
      for (final entry in unsupportedDifferences.entries)
        entry.key: entry.value.toMap(),
    },
    'reason': reason,
    'disposition': disposition,
  };
}
