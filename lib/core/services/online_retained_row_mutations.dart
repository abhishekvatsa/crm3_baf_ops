import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../persistence/request_identity_journal.dart';
import '../serialization/persisted_json_equality.dart';
import '../../features/auth/data/user_model.dart';
import '../../features/maintenance_workflow/domain/workflow_command_contract.dart';
import '../../features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'retained_row_mutations.dart';

/// Web has no native row transaction. Retain the exact online request before
/// sending it, with a resource slot shared by all accounts in this browser.
class OnlineRetainedRowMutations {
  OnlineRetainedRowMutations({
    Future<SharedPreferences> Function()? preferences,
    String Function()? projectId,
    String? Function()? currentActorUid,
    OriginBoundWorkflowCommandGateway? gateway,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _projectId = projectId ?? (() => Firebase.app().options.projectId),
       _currentActorUid =
           currentActorUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _gateway = gateway ?? const FirebaseWorkflowCommandGateway();

  final Future<SharedPreferences> Function() _preferences;
  final String Function() _projectId;
  final String? Function() _currentActorUid;
  final OriginBoundWorkflowCommandGateway _gateway;

  void _guard(String uid, String project) {
    if (uid.isEmpty ||
        _currentActorUid() != uid ||
        project.isEmpty ||
        _projectId() != project) {
      throw StateError(
        'Return to the original account and project. Saved work was preserved.',
      );
    }
  }

  Future<void> save({
    required RetainedRowKind kind,
    required AppUser actor,
    required dynamic record,
    required Future<dynamic> Function() readRemote,
    required void Function(dynamic existing) normalize,
  }) async {
    final project = _projectId();
    _guard(actor.uid, project);
    if (!actor.isApproved) throw StateError('An approved account is required.');
    record.firestoreId ??= const Uuid().v4();
    final id = record.firestoreId as String;
    final journal = RequestIdentityJournal<Map<String, dynamic>>(
      legacyKey: 'retainedRow:$project:${kind.collection}:$id',
      decode: (raw) {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        final command = value['command'];
        if (value.length != 3 ||
            value['protocolVersion'] != 2 ||
            value['originActorUid'] is! String ||
            command is! Map<String, dynamic> ||
            command['commandId'] is! String ||
            command['commandType'] != kind.commandType.name ||
            command['aggregateId'] != id ||
            command['payload'] is! Map<String, dynamic>) {
          throw StateError(
            'Saved request identity is invalid. Its evidence was preserved.',
          );
        }
        final payload = command['payload'] as Map<String, dynamic>;
        if (payload.length != 2 ||
            payload['projectId'] != project ||
            payload['record'] is! Map<String, dynamic>) {
          throw StateError(
            'Saved request project is invalid. Its evidence was preserved.',
          );
        }
        RetainedRowMutations.decode(
          kind,
          payload['record'] as Map<String, dynamic>,
          id,
        );
        return value;
      },
      requestIdOf: (value) => (value['command'] as Map)['commandId'] as String,
    );
    final preferences = await _preferences();
    await preferences.reload();
    _guard(actor.uid, project);
    final pending = journal.readAll(preferences);
    if (pending.isNotEmpty) {
      if (pending.length != 1) {
        throw StateError(
          'More than one saved edit needs review. Nothing was overwritten.',
        );
      }
      final envelope = pending.single.value;
      if (envelope['originActorUid'] != actor.uid) {
        throw StateError(
          'Another account has saved work for this item. Nothing was sent or overwritten.',
        );
      }
      await _send(kind, id, actor.uid, project, envelope);
      _guard(actor.uid, project);
      await journal.clearMatching(
        preferences,
        (value) =>
            value['command']['commandId'] == envelope['command']['commandId'],
      );
      throw StateError(
        'The earlier saved edit is now confirmed. Reload this item before saving another edit.',
      );
    }
    final existing = await readRemote();
    _guard(actor.uid, project);
    if (existing != null && existing.version != record.version) {
      throw StateError(
        'This item changed while editing. Reload it before saving.',
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
      throw StateError('Only an existing open job can receive a work edit.');
    }
    final version = existing == null ? 0 : existing.version as int;
    normalize(existing);
    record.version = version + 1;
    record.isSynced = false;
    final payload = RetainedRowMutations.wire(record);
    RetainedRowMutations.decode(kind, payload, id);
    final command = WorkflowCommand(
      commandId: const Uuid().v4(),
      type: kind.commandType,
      aggregateId: id,
      expectedVersion: version,
      payload: {'projectId': project, 'record': payload},
    );
    final envelope = {
      'protocolVersion': 2,
      'originActorUid': actor.uid,
      'command': command.toMap(),
    };
    _guard(actor.uid, project);
    final frozen = await journal.append(preferences, envelope);
    if (journal.readAll(preferences).length != 1) {
      throw StateError(
        'Concurrent saved edits need review. Their evidence was preserved.',
      );
    }
    await _send(kind, id, actor.uid, project, frozen);
    _guard(actor.uid, project);
    await journal.clearMatching(
      preferences,
      (value) => value['command']['commandId'] == command.commandId,
    );
    _guard(actor.uid, project);
    record.isSynced = false;
    final acceptedPayload = frozen['command']['payload']['record'];
    if (!persistedJsonEquivalent(
      jsonEncode(RetainedRowMutations.wire(record)),
      jsonEncode(acceptedPayload),
    )) {
      record.isSynced = false;
      throw StateError(
        'The saved edit is confirmed, but newer unsent changes remain. Reload the confirmed item before saving those changes.',
      );
    }
    record.isSynced = true;
  }

  Future<void> _send(
    RetainedRowKind kind,
    String id,
    String uid,
    String project,
    Map<String, dynamic> envelope,
  ) async {
    _guard(uid, project);
    final receipt = await _gateway.executeOriginBoundEnvelope(
      jsonEncode(envelope),
    );
    final command = envelope['command'] as Map;
    final intended = command['payload']['record'] as Map<String, dynamic>;
    if (receipt.resultKey != 'retained-queue-mutation-applied' ||
        receipt.commandId != command['commandId'] ||
        receipt.aggregateVersion != intended['version'] ||
        receipt.result['collection'] != kind.collection ||
        receipt.result['recordId'] != id ||
        receipt.result['record'] is! Map) {
      throw StateError(
        'The server receipt does not match the saved edit. Evidence was preserved.',
      );
    }
    final accepted = RetainedRowMutations.decode(
      kind,
      Map<String, dynamic>.from(receipt.result['record'] as Map),
      id,
    );
    if (!persistedJsonEquivalent(
      jsonEncode(RetainedRowMutations.wire(accepted)),
      jsonEncode(intended),
    )) {
      throw StateError(
        'The accepted payload differs from the saved edit. Evidence was preserved.',
      );
    }
    _guard(uid, project);
  }
}
