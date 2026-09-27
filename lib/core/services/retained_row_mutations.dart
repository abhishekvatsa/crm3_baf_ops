import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';

import '../persistence/app_database.dart' as database;
import '../persistence/durable_submission_repository.dart';
import '../serialization/persisted_json_equality.dart';
import '../serialization/persisted_data_reader.dart';
import '../../features/abnormalities/data/abnormality_model.dart';
import '../../features/auth/data/user_model.dart';
import '../../features/planned_maintenance/data/job_template_model.dart';
import '../../features/maintenance_workflow/domain/workflow_command_contract.dart';
import '../../features/maintenance_workflow/domain/workflow_types.dart';
import '../../features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'sync_run_guard.dart';

enum RetainedRowKind {
  abnormalityType(
    'abnormality_types',
    WorkflowCommandType.upsertAbnormalityType,
  ),
  legacyTemplate('job_templates', WorkflowCommandType.upsertLegacyJobTemplate),
  executionWork('job_executions', WorkflowCommandType.updateJobExecutionWork);

  const RetainedRowKind(this.collection, this.commandType);
  final String collection;
  final WorkflowCommandType commandType;
}

/// Only these three former generic queues use this adapter. It never derives
/// mutation ownership from the account performing a later synchronization.
class RetainedRowMutations {
  RetainedRowMutations({
    DurableSubmissionRepository? store,
    String Function()? projectId,
    String? Function()? currentActorUid,
    OriginBoundWorkflowCommandGateway? gateway,
  }) : _store = store,
       _projectId = projectId ?? (() => Firebase.app().options.projectId),
       _currentActorUid =
           currentActorUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _gateway = gateway ?? const FirebaseWorkflowCommandGateway();

  final DurableSubmissionRepository? _store;
  DurableSubmissionRepository get store =>
      _store ?? DurableSubmissionRepository(database.isar);
  final String Function() _projectId;
  final String? Function() _currentActorUid;
  final OriginBoundWorkflowCommandGateway _gateway;

  String resourceKey(RetainedRowKind kind, String id, String project) =>
      'retainedRow:$project:${kind.collection}:$id';

  void _guard(String actor, String project, SyncRunGuard? runGuard) {
    runGuard?.checkCurrent();
    if (actor.isEmpty ||
        _currentActorUid() != actor ||
        project.isEmpty ||
        _projectId() != project) {
      throw const DurableSubmissionException(
        'origin-mismatch',
        'Return to the original account and project. Saved work was preserved.',
      );
    }
  }

  /// Called only from repository user-save methods, never remote pull replay.
  Future<void> save({
    required RetainedRowKind kind,
    required AppUser actor,
    required dynamic record,
    required void Function(dynamic existing) normalize,
  }) async {
    final project = _projectId();
    _guard(actor.uid, project, null);
    if (!actor.isApproved) throw StateError('An approved account is required.');
    record.firestoreId ??= const Uuid().v4();
    final id = record.firestoreId as String;
    final requestId = const Uuid().v4();
    late dynamic frozenProjection;
    await store.prepareAtomically(
      prepareDraft: () async {
        _guard(actor.uid, project, null);
        final localId = record.id as int;
        if (localId != Isar.autoIncrement) {
          final indexed = await _localById(kind, localId);
          if (indexed != null && indexed.firestoreId != id) {
            throw const DurableSubmissionException(
              'local-identity-conflict',
              'This local row belongs to another document. Saved work was not overwritten.',
            );
          }
        }
        final existing = await _local(kind, id);
        if (existing != null && !existing.isSynced) {
          throw const DurableSubmissionException(
            'pending-origin-review',
            'Earlier saved work must be confirmed or reviewed before another edit. Nothing was overwritten.',
          );
        }
        if (existing != null && record.version != existing.version) {
          throw const DurableSubmissionException(
            'local-version-conflict',
            'This item changed while editing. Saved work was preserved.',
          );
        }
        if (kind == RetainedRowKind.executionWork &&
            (existing == null ||
                existing.isCompleted ||
                existing.isCancelled ||
                existing.isDeleted ||
                record.isCompleted ||
                record.isCancelled ||
                record.isDeleted)) {
          throw StateError(
            'Only an existing open job can receive a retained work edit.',
          );
        }
        final baseline = existing == null ? 0 : existing.version as int;
        normalize(existing);
        record.version = baseline + 1;
        record.isSynced = false;
        if (existing != null) record.id = existing.id;
        final payload = wire(record);
        // Own a decoded copy: caller-owned lists or fields may change while
        // the journal awaits its resource checks within this transaction.
        frozenProjection = decode(
          kind,
          durableSubmissionJsonObject(jsonEncode(payload)),
          id,
        );
        frozenProjection.id = record.id;
        frozenProjection.isSynced = false;
        _guard(actor.uid, project, null);
        final command = WorkflowCommand(
          commandId: requestId,
          type: kind.commandType,
          aggregateId: id,
          expectedVersion: baseline,
          payload: {'projectId': project, 'record': payload},
        );
        return DurableSubmissionDraft(
          submissionId: requestId,
          actorUid: actor.uid,
          requestId: requestId,
          aggregateId: id,
          resourceKey: resourceKey(kind, id, project),
          protocol: 'maintenanceWorkflow.v2',
          envelopeJson: jsonEncode({
            'protocolVersion': 2,
            'originActorUid': actor.uid,
            'command': command.toMap(),
          }),
        );
      },
      persistProjection: () async {
        _guard(actor.uid, project, null);
        await _put(kind, frozenProjection);
        record.id = frozenProjection.id;
        _guard(actor.uid, project, null);
      },
    );
  }

  Future<bool> hasRetained(RetainedRowKind kind, String id) async =>
      await store.findUnresolvedForResource(
        resourceKey(kind, id, _projectId()),
      ) !=
      null;

  /// Unknown origins remain dirty and review-only, even when a remote row happens
  /// to look identical. Identity must predate the attempted dispatch.
  Future<void> synchronize(
    RetainedRowKind kind,
    dynamic local, {
    SyncRunGuard? runGuard,
  }) async {
    runGuard?.checkCurrent();
    final project = _projectId();
    final id = local.firestoreId as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Saved work has no document identity.');
    }
    final key = resourceKey(kind, id, project);
    final row = await store.findUnresolvedForResource(key);
    runGuard?.checkCurrent();
    if (row == null) {
      final raw = utf8.encode(jsonEncode(wire(local)));
      final source =
          '$key:${local.version}:${durableSubmissionSha256(utf8.decode(raw))}';
      await store.importLegacyNeedsReview(
        submissionId: 'legacy-${durableSubmissionSha256(source)}',
        resourceKey: key,
        sourceKey: source,
        sourceBytes: Uint8List.fromList(raw),
        aggregateId: id,
      );
      throw const DurableSubmissionException(
        'legacy-origin-unknown',
        'The original account for this saved work is unknown. It remains saved for review.',
      );
    }
    await check(row.submissionId, kind: kind, runGuard: runGuard);
  }

  Future<void> check(
    String submissionId, {
    required RetainedRowKind kind,
    SyncRunGuard? runGuard,
  }) async {
    var row = await store.read(submissionId);
    if (row == null) throw StateError('Saved mutation evidence is missing.');
    if (row.isLegacy) {
      throw const DurableSubmissionException(
        'legacy-origin-unknown',
        'This saved work requires review; no mutation was sent.',
      );
    }
    final envelope = row.envelope;
    final command = Map<String, dynamic>.from(envelope['command'] as Map);
    final payload = Map<String, dynamic>.from(command['payload'] as Map);
    final project = payload['projectId'];
    if (project is! String ||
        payload.length != 2 ||
        command['commandType'] != kind.commandType.name ||
        row.resourceKey != resourceKey(kind, row.aggregateId, project)) {
      throw StateError(
        'Saved mutation scope is invalid; evidence was preserved.',
      );
    }
    final intended = Map<String, dynamic>.from(payload['record'] as Map);
    final actor = row.actorUid!;
    _guard(actor, project, runGuard);
    if (!row.state.isAccepted) {
      final claim = await store.claim(
        submissionId: row.submissionId,
        actorUid: actor,
      );
      if (!claim.mayDispatch) {
        if (!claim.submission.state.isAccepted) {
          throw StateError(
            'Saved work is already being checked or requires review.',
          );
        }
        row = claim.submission;
      } else {
        try {
          _guard(actor, project, runGuard);
          final receipt = await _gateway.executeOriginBoundEnvelope(
            row.envelopeJson,
          );
          final raw = _receiptMap(receipt);
          _accepted(kind, row, intended, raw);
          row = await store.settleAccepted(
            submissionId: row.submissionId,
            envelopeSha256: row.envelopeSha256,
            receiptJson: jsonEncode(raw),
            validateReceipt: (saved, value) {
              _accepted(kind, saved, intended, value);
              return true;
            },
          );
        } catch (error) {
          await store.recordOutcome(
            claim,
            state: DurableSubmissionState.uncertain,
            message: '$error',
            errorCode: 'retained-row-unconfirmed',
          );
          rethrow;
        }
      }
    }
    _guard(actor, project, runGuard);
    final accepted = _accepted(
      kind,
      row,
      intended,
      durableSubmissionJsonObject(row.receiptJson!),
    );
    final acceptedRow = row;
    await store.markReconciled(
      submissionId: row.submissionId,
      envelopeSha256: row.envelopeSha256,
      receiptSha256: row.receiptSha256!,
      adoptInTransaction: (_) async {
        _guard(actor, project, runGuard);
        final current = await _local(kind, acceptedRow.aggregateId);
        if (current == null || !_same(wire(current), intended)) {
          throw const DurableSubmissionException(
            'projection-conflict',
            'Acceptance is retained; newer local work was not overwritten or acknowledged.',
          );
        }
        accepted.id = current.id;
        accepted.isSynced = true;
        await _put(kind, accepted);
        _guard(actor, project, runGuard);
      },
    );
  }

  dynamic _accepted(
    RetainedRowKind kind,
    DurableSubmission saved,
    Map<String, dynamic> intended,
    Map<String, dynamic> receipt,
  ) {
    final value = WorkflowCommandReceipt.fromMap(receipt);
    final result = value.result;
    if (value.resultKey != 'retained-queue-mutation-applied' ||
        value.commandId != saved.requestId ||
        result['collection'] != kind.collection ||
        result['recordId'] != saved.aggregateId ||
        value.aggregateVersion != intended['version'] ||
        result['record'] is! Map) {
      throw StateError(
        'The accepted receipt does not match the retained mutation.',
      );
    }
    final record = Map<String, dynamic>.from(result['record']! as Map);
    final accepted = decode(kind, record, saved.aggregateId);
    if (!_same(wire(accepted), intended)) {
      throw StateError('Accepted payload differs from the saved mutation.');
    }
    return accepted;
  }

  static Map<String, dynamic> _receiptMap(WorkflowCommandReceipt value) => {
    'commandId': value.commandId,
    'resultKey': value.resultKey,
    'aggregateVersion': value.aggregateVersion,
    'result': value.result,
    'appliedAt': value.appliedAt.toUtc().toIso8601String(),
  };

  static bool _same(Map<String, dynamic> a, Map<String, dynamic> b) =>
      persistedJsonEquivalent(jsonEncode(a), jsonEncode(b));

  static Map<String, dynamic> wire(dynamic record) {
    final map = Map<String, dynamic>.from(record.toMap() as Map);
    for (final key in [
      'createdAt',
      'updatedAt',
      'deletedAt',
      'completedAt',
      'cancelledAt',
      'laneSetFinalizedAt',
    ]) {
      final value = map[key];
      if (value is String) {
        map[key] = readRequiredPersistedDateTime(
          value,
          field: key,
          source: 'retained row mutation',
        ).toUtc().toIso8601String();
      }
    }
    return map;
  }

  static dynamic decode(
    RetainedRowKind kind,
    Map<String, dynamic> map,
    String id,
  ) => switch (kind) {
    RetainedRowKind.abnormalityType => AbnormalityType.fromMap(map, id),
    RetainedRowKind.legacyTemplate => JobTemplate.fromMap(map, id),
    RetainedRowKind.executionWork => JobExecution.fromMap(map, id),
  };

  Future<dynamic> _localById(RetainedRowKind kind, int id) => switch (kind) {
    RetainedRowKind.abnormalityType => store.isar.abnormalityTypes.get(id),
    RetainedRowKind.legacyTemplate => store.isar.jobTemplates.get(id),
    RetainedRowKind.executionWork => store.isar.jobExecutions.get(id),
  };

  Future<dynamic> _local(RetainedRowKind kind, String id) async {
    final List<dynamic> rows = switch (kind) {
      RetainedRowKind.abnormalityType =>
        await store.isar.abnormalityTypes
            .filter()
            .firestoreIdEqualTo(id)
            .findAll(),
      RetainedRowKind.legacyTemplate =>
        await store.isar.jobTemplates.filter().firestoreIdEqualTo(id).findAll(),
      RetainedRowKind.executionWork =>
        await store.isar.jobExecutions
            .filter()
            .firestoreIdEqualTo(id)
            .findAll(),
    };
    if (rows.length > 1) {
      throw StateError('Duplicate local identity requires review.');
    }
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> _put(RetainedRowKind kind, dynamic record) async {
    switch (kind) {
      case RetainedRowKind.abnormalityType:
        await store.isar.abnormalityTypes.put(record as AbnormalityType);
      case RetainedRowKind.legacyTemplate:
        await store.isar.jobTemplates.put(record as JobTemplate);
      case RetainedRowKind.executionWork:
        await store.isar.jobExecutions.put(record as JobExecution);
    }
  }
}
