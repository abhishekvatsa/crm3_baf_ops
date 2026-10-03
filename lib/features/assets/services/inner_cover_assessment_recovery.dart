import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../auth/data/user_model.dart';
import '../../maintenance_workflow/data/workflow_command_record.dart';
import '../../maintenance_workflow/repositories/workflow_repository.dart';

class InnerCoverRecoveryException implements Exception {
  const InnerCoverRecoveryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Exact immutable command inputs. Retry state and attempt counters are neither
/// authorization nor part of command identity. The original row is never edited.
class InnerCoverRecoveryEvidence {
  InnerCoverRecoveryEvidence._(this.fields, this.actorUid);
  final Map<String, Object?> fields;
  final String actorUid;
  String get commandId => fields['commandId']! as String;
  String get caseId => fields['aggregateId']! as String;
  int get expectedVersion => fields['expectedVersion']! as int;
  String get sha256Hex =>
      sha256.convert(utf8.encode(jsonEncode(fields))).toString();

  factory InnerCoverRecoveryEvidence.from(WorkflowCommandRecord row) {
    bool id(String value) =>
        value.isNotEmpty &&
        value == value.trim() &&
        value.length <= 160 &&
        !RegExp(r'[/\x00-\x1f\x7f]').hasMatch(value);
    try {
      final saved = jsonDecode(row.payloadJson);
      if (!id(row.commandId) ||
          !id(row.aggregateId) ||
          row.commandTypeKey != 'settleInnerCoverAssessment' ||
          row.expectedVersion < 1 ||
          saved is! Map<String, dynamic> ||
          saved.length != 2 ||
          saved['__workflowOriginBoundV1'] is! String ||
          saved['payload'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final actor = saved['__workflowOriginBoundV1'] as String;
      if (!id(actor) || actor.length > 128) throw const FormatException();
      return InnerCoverRecoveryEvidence._(
        Map.unmodifiable({
          'commandId': row.commandId,
          'aggregateId': row.aggregateId,
          'commandTypeKey': row.commandTypeKey,
          'expectedVersion': row.expectedVersion,
          'payloadJson': row.payloadJson,
        }),
        actor,
      );
    } on Object {
      throw const InnerCoverRecoveryException(
        'The original request and account cannot be identified safely. Keep this saved action for specialist review.',
      );
    }
  }
}

class InnerCoverRecoveryObservation {
  const InnerCoverRecoveryObservation({
    required this.evidence,
    required this.reviewerUid,
    required this.reason,
    required this.response,
  });
  final InnerCoverRecoveryEvidence evidence;
  final String reviewerUid;
  final String reason;
  final Map<String, dynamic> response;
  bool get cancelled => response['outcome'] == 'cancelled';
  bool get accepted => response['outcome'] == 'reviewedExisting';
  bool get resolved => cancelled || accepted;
  bool get receiptPresent => response['observation'] == 'receiptPresent';
}

/// Reuses the server's permanent transactional workflow fence. No local state,
/// receipt absence or error category can release a retained assessment request.
class InnerCoverAssessmentRecovery {
  const InnerCoverAssessmentRecovery({
    required this.repository,
    required this.actor,
    required this.requireCapability,
    required this.invoke,
  });
  final WorkflowRepository repository;
  final AppUser Function() actor;
  final Future<void> Function(String uid) requireCapability;
  final Future<Object?> Function(Map<String, Object?> request) invoke;

  AppUser _actor({bool admin = false, String? expected}) {
    final value = actor();
    if (!value.isApproved ||
        !value.canAdjudicateFurnaceStuckup ||
        (admin && !value.isAdmin) ||
        (expected != null && value.uid != expected)) {
      throw const InnerCoverRecoveryException(
        'The approved account changed or cannot review this request. Original work remains saved.',
      );
    }
    return value;
  }

  Future<void> _unchanged(InnerCoverRecoveryEvidence evidence) async {
    final row = await repository.getRetryCommand(evidence.commandId);
    if (row == null ||
        row.stateKey == 'applied' ||
        InnerCoverRecoveryEvidence.from(row).sha256Hex != evidence.sha256Hex) {
      throw const InnerCoverRecoveryException(
        'The saved request changed during review. Check the current assessment and inspect the saved action again.',
      );
    }
  }

  Map<String, Object?> _request(
    InnerCoverRecoveryEvidence evidence,
    String phase,
    String reason,
    String uid, {
    String? token,
  }) => {
    'protocolVersion': 2,
    'originActorUid': uid,
    'recovery': {
      'schemaVersion': 1,
      'phase': phase,
      'domain':
          'inspectionCampaign', // Existing shared workflow fence namespace.
      'requestId': evidence.commandId,
      'evidenceSha256': evidence.sha256Hex,
      'originalActorUid': evidence.actorUid,
      'reason': reason,
      'assessmentEvidence': evidence.fields,
      if (token != null) 'reviewToken': token,
    },
  };

  Future<InnerCoverRecoveryObservation> status(WorkflowCommandRecord row) =>
      _read(row, 'status', 'Check the existing saved assessment decision.');

  Future<InnerCoverRecoveryObservation> inspect(
    WorkflowCommandRecord row,
    String reason,
  ) => _read(row, 'inspect', reason.trim());

  Future<InnerCoverRecoveryObservation> _read(
    WorkflowCommandRecord row,
    String phase,
    String reason,
  ) async {
    final evidence = InnerCoverRecoveryEvidence.from(row);
    final admin = phase != 'status';
    final uid = _actor(admin: admin).uid;
    if (reason.length < 10 || reason.length > 1600) {
      throw const InnerCoverRecoveryException(
        'Describe the review in 10–1600 characters.',
      );
    }
    await _unchanged(evidence);
    _actor(admin: admin, expected: uid);
    await requireCapability(uid);
    _actor(admin: admin, expected: uid);
    final response = _object(
      await invoke(_request(evidence, phase, reason, uid)),
    );
    _actor(admin: admin, expected: uid);
    await _unchanged(evidence);
    _actor(admin: admin, expected: uid);
    _validate(response, evidence, uid, status: phase == 'status');
    return InnerCoverRecoveryObservation(
      evidence: evidence,
      reviewerUid: uid,
      reason: response['reason'] as String? ?? reason,
      response: Map.unmodifiable(response),
    );
  }

  Future<InnerCoverRecoveryObservation> finalize(
    InnerCoverRecoveryObservation inspected,
  ) async {
    final uid = inspected.reviewerUid;
    _actor(admin: true, expected: uid);
    await _unchanged(inspected.evidence);
    _actor(admin: true, expected: uid);
    _validate(inspected.response, inspected.evidence, uid);
    if (inspected.resolved) {
      // Observation objects are not authority: recover the immutable decision
      // from the server again, even when inspect already returned a decision.
      final row = await repository.getRetryCommand(
        inspected.evidence.commandId,
      );
      if (row == null) _invalid();
      return status(row);
    }
    if (inspected.response['reviewToken'] is! String) _invalid();
    await requireCapability(uid);
    _actor(admin: true, expected: uid);
    final response = _object(
      await invoke(
        _request(
          inspected.evidence,
          'finalize',
          inspected.reason,
          uid,
          token: inspected.response['reviewToken'] as String,
        ),
      ),
    );
    _actor(admin: true, expected: uid);
    await _unchanged(inspected.evidence);
    _actor(admin: true, expected: uid);
    _validate(response, inspected.evidence, uid, decisionRequired: true);
    if (response['reviewerUid'] != uid ||
        response['reason'] != inspected.reason ||
        response['receiptSha256'] != inspected.response['receiptSha256'] ||
        (response['outcome'] == 'reviewedExisting') !=
            inspected.receiptPresent) {
      _invalid();
    }
    return InnerCoverRecoveryObservation(
      evidence: inspected.evidence,
      reviewerUid: uid,
      reason: inspected.reason,
      response: Map.unmodifiable(response),
    );
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) _invalid();
    return Map<String, dynamic>.from(value);
  }

  static void _validate(
    Map<String, dynamic> data,
    InnerCoverRecoveryEvidence evidence,
    String uid, {
    bool status = false,
    bool decisionRequired = false,
  }) {
    bool hash(Object? value) =>
        value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
    bool iso(Object? value) =>
        value is String &&
        RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$').hasMatch(value) &&
        DateTime.tryParse(value)?.toUtc().toIso8601String() == value;
    const binding = {
      'schemaVersion',
      'domain',
      'requestId',
      'evidenceSha256',
      'originalActorUid',
      'reviewerUid',
    };
    final decision = data.containsKey('outcome');
    final unresolved = status && data['observation'] == 'unresolved';
    final expected = {
      ...binding,
      if (decision) ...{
        'outcome',
        'decisionId',
        'decidedAt',
        'receiptSha256',
        'receiptSummary',
        'reason',
      } else if (unresolved)
        'observation'
      else ...{
        'reviewToken',
        'observation',
        'receiptSha256',
        'receiptSummary',
      },
    };
    if (data.length != expected.length ||
        !data.keys.toSet().containsAll(expected) ||
        data['schemaVersion'] != 1 ||
        data['domain'] != 'inspectionCampaign' ||
        data['requestId'] != evidence.commandId ||
        data['evidenceSha256'] != evidence.sha256Hex ||
        data['originalActorUid'] != evidence.actorUid ||
        data['reviewerUid'] is! String ||
        (data['reviewerUid'] as String).isEmpty ||
        (!decision && data['reviewerUid'] != uid) ||
        (decisionRequired && !decision)) {
      _invalid();
    }
    if (unresolved) return;
    if (decision) {
      if (!const {'cancelled', 'reviewedExisting'}.contains(data['outcome']) ||
          !hash(data['decisionId']) ||
          !iso(data['decidedAt']) ||
          data['reason'] is! String ||
          (data['reason'] as String).trim().length < 8 ||
          (data['reason'] as String).length > 2000) {
        _invalid();
      }
    } else if (!hash(data['reviewToken']) ||
        !const {
          'receiptAbsent',
          'receiptPresent',
        }.contains(data['observation'])) {
      _invalid();
    }
    final accepted = decision
        ? data['outcome'] == 'reviewedExisting'
        : data['observation'] == 'receiptPresent';
    if (!accepted) {
      if (data['receiptSha256'] != null || data['receiptSummary'] != null) {
        _invalid();
      }
      return;
    }
    final summary = data['receiptSummary'];
    if (!hash(data['receiptSha256']) ||
        summary is! Map ||
        summary.length != 6 ||
        !summary.keys.toSet().containsAll(const {
          'actorUid',
          'operation',
          'entityId',
          'version',
          'committedAt',
          'status',
        }) ||
        summary['actorUid'] != evidence.actorUid ||
        summary['operation'] != 'settleInnerCoverAssessment' ||
        summary['entityId'] != evidence.caseId ||
        summary['version'] != evidence.expectedVersion + 1 ||
        summary['status'] != null ||
        !iso(summary['committedAt'])) {
      _invalid();
    }
  }

  static Never _invalid() => throw const InnerCoverRecoveryException(
    'The server result does not match this exact saved request. Its hold remains; inspect it again.',
  );
}
