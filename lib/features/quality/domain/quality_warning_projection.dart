import '../../abnormalities/data/abnormality_model.dart';
import '../../../core/validation/charge_number.dart';
import '../../maintenance/data/maintenance_model.dart';

const qualityWarningSchemaVersion = 1;

String qualityWarningIdForIssue(String sourceId) => 'issue_$sourceId';

String qualityWarningIdForAbnormality(String sourceId) =>
    'abnormality_$sourceId';

Map<String, dynamic>? qualityWarningProjectionForIssue(
  MaintenanceRecord ticket,
) {
  final id = ticket.firestoreId?.trim();
  final intent = ticket.qualityIntent;
  if (id == null || id.isEmpty || intent == null || !intent.isSuspected) {
    return null;
  }
  final chargeNo = ticket.chargeNoAtEvent;
  final actorUid = ticket.loggedByUid?.trim();
  final reason = intent.warningReason?.trim();
  if (chargeNo == null ||
      !isValidChargeNumber(chargeNo) ||
      actorUid == null ||
      actorUid.isEmpty ||
      reason == null ||
      reason.length < 8) {
    throw StateError(
      'A suspected issue quality warning requires charge, actor and reason evidence.',
    );
  }
  final timestamp = ticket.createdAt.toIso8601String();
  return _newWarning(
    warningId: qualityWarningIdForIssue(id),
    sourceType: 'issue',
    sourceId: id,
    sourceVersion: ticket.version,
    sourceChargeNo: chargeNo,
    sourceSummary: ticket.description.trim(),
    sourceSeverity: ticket.isCritical ? 'critical' : 'standard',
    warningReason: reason,
    affectedAssets: <Map<String, dynamic>>[
      <String, dynamic>{
        'assetType': ticket.assetType.name,
        'assetNumber': ticket.assetNumber,
      },
    ],
    component:
        ticket.component?.trim().isEmpty ?? true
            ? null
            : ticket.component!.trim(),
    createdAt: timestamp,
    createdByUid: actorUid,
    createdByName: _clean(ticket.loggedByName),
  );
}

Map<String, dynamic>? qualityWarningProjectionForIssueMap(
  Map<String, dynamic> ticket,
  String documentId,
) {
  if (ticket['qualityImpactAssessment'] != 'suspected') return null;
  final chargeNo = ticket['chargeNoAtEvent'];
  final version = ticket['version'];
  final actorUid = _cleanDynamic(ticket['loggedByUid']);
  final reason = _cleanDynamic(ticket['qualityWarningReason']);
  final description = _cleanDynamic(ticket['description']);
  final assetType = _cleanDynamic(ticket['assetType']);
  final assetNumber = ticket['assetNumber'];
  final createdAt = _cleanDynamic(ticket['createdAt']);
  if (ticket['qualityIntentSchemaVersion'] != 1 ||
      chargeNo is! int ||
      !isValidChargeNumber(chargeNo) ||
      version is! int ||
      version <= 0 ||
      actorUid == null ||
      reason == null ||
      reason.length < 8 ||
      description == null ||
      assetType == null ||
      assetNumber is! int ||
      assetNumber <= 0 ||
      createdAt == null) {
    throw StateError('The synchronized issue quality intent is malformed.');
  }
  return _newWarning(
    warningId: qualityWarningIdForIssue(documentId),
    sourceType: 'issue',
    sourceId: documentId,
    sourceVersion: version,
    sourceChargeNo: chargeNo,
    sourceSummary: description,
    sourceSeverity: ticket['isCritical'] == true ? 'critical' : 'standard',
    warningReason: reason,
    affectedAssets: <Map<String, dynamic>>[
      <String, dynamic>{'assetType': assetType, 'assetNumber': assetNumber},
    ],
    component: _cleanDynamic(ticket['component']),
    createdAt: createdAt,
    createdByUid: actorUid,
    createdByName: _cleanDynamic(ticket['loggedByName']),
  );
}

Map<String, dynamic> qualityWarningProjectionForAbnormality(
  ChargeAbnormality abnormality,
) {
  final id = abnormality.firestoreId?.trim();
  final actorUid = abnormality.loggedByUid?.trim();
  if (id == null || id.isEmpty || actorUid == null || actorUid.isEmpty) {
    throw StateError(
      'A charge abnormality quality warning requires source and actor identity.',
    );
  }
  return _newWarning(
    warningId: qualityWarningIdForAbnormality(id),
    sourceType: 'abnormality',
    sourceId: id,
    sourceVersion: abnormality.version,
    sourceChargeNo: abnormality.sourceChargeNo,
    sourceSummary: abnormality.abnormalityTypeTitle.trim(),
    sourceSeverity: abnormality.severity.name,
    warningReason: abnormality.observedReason.trim(),
    affectedAssets:
        abnormality.affectedAssets.map((asset) => asset.toMap()).toList(),
    component: _clean(abnormality.component),
    createdAt: abnormality.loggedAt.toIso8601String(),
    createdByUid: actorUid,
    createdByName: _clean(abnormality.loggedByName),
  );
}

Map<String, dynamic> _newWarning({
  required String warningId,
  required String sourceType,
  required String sourceId,
  required int sourceVersion,
  required int sourceChargeNo,
  required String sourceSummary,
  required String sourceSeverity,
  required String warningReason,
  required List<Map<String, dynamic>> affectedAssets,
  required String? component,
  required String createdAt,
  required String createdByUid,
  required String? createdByName,
}) => <String, dynamic>{
  'schemaVersion': qualityWarningSchemaVersion,
  'warningId': warningId,
  'sourceType': sourceType,
  'sourceId': sourceId,
  'sourceVersion': sourceVersion,
  'sourceChargeNo': sourceChargeNo,
  'sourceSummary': sourceSummary,
  'sourceSeverity': sourceSeverity,
  'warningReason': warningReason,
  'affectedAssets': affectedAssets,
  'component': component,
  'status': 'open',
  'closureRequestReason': null,
  'closureRequestedAt': null,
  'closureRequestedByUid': null,
  'closureRequestedByName': null,
  'closedAt': null,
  'closedByUid': null,
  'closedByName': null,
  'closureDisposition': null,
  'linkedReannealingChargeNos': const <int>[],
  'decisionReason': null,
  'createdAt': createdAt,
  'createdByUid': createdByUid,
  'createdByName': createdByName,
  'updatedAt': createdAt,
  'updatedByUid': createdByUid,
  'updatedByName': createdByName,
  'version': 1,
};

String? _clean(String? value) => _cleanDynamic(value);

String? _cleanDynamic(Object? value) {
  if (value is! String) return null;
  final cleaned = value.trim();
  return cleaned.isEmpty ? null : cleaned;
}
