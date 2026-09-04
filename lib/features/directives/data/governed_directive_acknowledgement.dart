import 'dart:convert';

import 'operational_directive_model.dart';

bool isGovernedBurnerRoundDirectiveId(String? id) =>
    id != null && RegExp(r'^burner_round_red_hot_[A-Za-z0-9_-]+$').hasMatch(id);

const _acknowledgementFields = {
  'status',
  'isActive',
  'acknowledgedByUid',
  'acknowledgedByName',
  'acknowledgedAt',
  'closedByUid',
  'closedByName',
  'closedAt',
  'closedWithoutAcknowledgement',
  'updatedAt',
  'version',
};

Map<String, dynamic> _comparable(Map<String, dynamic> source) {
  final result = Map<String, dynamic>.from(source);
  for (final field in [
    'createdAt',
    'issuedAt',
    'updatedAt',
    'acknowledgedAt',
    'closedAt',
    'deletedAt',
  ]) {
    final value = result[field];
    if (value is String) {
      result[field] = DateTime.parse(value).toUtc().toIso8601String();
    }
  }
  return result;
}

/// Produces a field-only write, never re-serializing server-owned timestamps.
/// An empty patch means this exact version/evidence was already committed.
Map<String, dynamic> governedDirectiveAcknowledgementPatch({
  required OperationalDirective local,
  required OperationalDirective remote,
}) {
  if (!isGovernedBurnerRoundDirectiveId(local.firestoreId) ||
      local.firestoreId != remote.firestoreId ||
      !local.isAcknowledged ||
      !local.isActive ||
      local.isDeleted ||
      local.acknowledgedByUid?.trim().isNotEmpty != true ||
      local.acknowledgedByName?.trim().isNotEmpty != true ||
      local.acknowledgedAt == null ||
      local.closedByUid != null ||
      local.closedByName != null ||
      local.closedAt != null ||
      local.closedWithoutAcknowledgement) {
    throw StateError('Invalid governed burner directive acknowledgement.');
  }
  final localMap = _comparable(local.toMap());
  final remoteMap = _comparable(remote.toMap());
  // Both maps come from the same typed model serializer with stable key order.
  if (jsonEncode(localMap) == jsonEncode(remoteMap)) return {};
  if (!remote.isOpen ||
      remote.isDeleted ||
      local.version != remote.version + 1) {
    throw StateError(
      'The directive changed on the server. Refresh before acknowledging.',
    );
  }
  final localSource = Map<String, dynamic>.from(localMap)
    ..removeWhere((key, _) => _acknowledgementFields.contains(key));
  final remoteSource = Map<String, dynamic>.from(remoteMap)
    ..removeWhere((key, _) => _acknowledgementFields.contains(key));
  if (jsonEncode(localSource) != jsonEncode(remoteSource)) {
    throw StateError(
      'The directive source changed. Refresh before acknowledging.',
    );
  }
  return Map<String, dynamic>.from(local.toMap())
    ..removeWhere((key, _) => !_acknowledgementFields.contains(key));
}
