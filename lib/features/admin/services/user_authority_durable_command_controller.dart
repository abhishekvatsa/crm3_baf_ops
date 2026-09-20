import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/serialization/persisted_json_equality.dart';
import '../../auth/data/user_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import 'user_authority_command_service.dart';

const userAuthorityDurableProtocol = 'userAuthority.v1';

/// The exact authority request retained before network dispatch.
class UserAuthorityDurableCommand {
  const UserAuthorityDurableCommand({
    required this.originActorUid,
    required this.requestId,
    required this.targetUid,
    required this.operation,
    required this.expectedAuthorityDigest,
    required this.expectedAuthorityRevision,
    required this.reason,
    required this.roles,
  });

  final String originActorUid;
  final String requestId;
  final String targetUid;
  final UserAuthorityOperation operation;
  final String expectedAuthorityDigest;
  final int expectedAuthorityRevision;
  final String reason;
  final List<AppRole>? roles;

  Map<String, dynamic> get requestMap => <String, dynamic>{
    'requestId': requestId,
    'targetUid': targetUid,
    'operation': operation.wireName,
    'expectedAuthorityDigest': expectedAuthorityDigest,
    'expectedAuthorityRevision': expectedAuthorityRevision,
    if (roles != null)
      'roles': roles!.map((role) => role.name).toList(growable: false),
    'reason': reason,
  };

  String get envelopeJson => jsonEncode(<String, dynamic>{
    'protocolVersion': 2,
    'originActorUid': originActorUid,
    'request': requestMap,
  });

  factory UserAuthorityDurableCommand.fromSubmission(DurableSubmission saved) {
    if (saved.protocol != userAuthorityDurableProtocol ||
        saved.actorUid == null ||
        saved.actorUid!.trim().isEmpty) {
      throw const DurableSubmissionException(
        'invalid-protocol',
        'The saved authority decision does not prove its originating account.',
      );
    }
    final envelope = durableSubmissionJsonObject(saved.envelopeJson);
    if (envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != saved.actorUid ||
        envelope['request'] is! Map<String, dynamic>) {
      throw const DurableSubmissionException(
        'invalid-protocol',
        'The saved authority decision envelope is malformed.',
      );
    }
    final raw = envelope['request'] as Map<String, dynamic>;
    final operation = switch (raw['operation']) {
      'APPROVE' => UserAuthorityOperation.approve,
      'REVOKE' => UserAuthorityOperation.revoke,
      'REPLACE_ROLES' => UserAuthorityOperation.replaceRoles,
      _ => throw const DurableSubmissionException(
        'invalid-protocol',
        'The saved authority decision operation is unknown.',
      ),
    };
    final requestId = raw['requestId'];
    final targetUid = raw['targetUid'];
    final digest = raw['expectedAuthorityDigest'];
    final revision = raw['expectedAuthorityRevision'];
    final reason = raw['reason'];
    if (requestId is! String ||
        targetUid is! String ||
        digest is! String ||
        revision is! int ||
        reason is! String ||
        requestId != saved.requestId ||
        targetUid != saved.aggregateId ||
        revision < 0 ||
        reason.trim().isEmpty) {
      throw const DurableSubmissionException(
        'invalid-protocol',
        'The saved authority decision identities are inconsistent.',
      );
    }
    List<AppRole>? roles;
    if (operation == UserAuthorityOperation.replaceRoles) {
      final rawRoles = raw['roles'];
      if (rawRoles is! List || rawRoles.isEmpty) {
        throw const DurableSubmissionException(
          'invalid-protocol',
          'The saved role decision is incomplete.',
        );
      }
      roles = normalizeAuthorityRoles(
        rawRoles.map((value) {
          for (final role in AppRole.values) {
            if (role.name == value) return role;
          }
          throw const DurableSubmissionException(
            'invalid-protocol',
            'The saved role decision contains an unknown role.',
          );
        }),
      );
    }
    return UserAuthorityDurableCommand(
      originActorUid: saved.actorUid!,
      requestId: requestId,
      targetUid: targetUid,
      operation: operation,
      expectedAuthorityDigest: digest,
      expectedAuthorityRevision: revision,
      reason: reason,
      roles: roles,
    );
  }
}

/// Persists authority intent before dispatch and replays the same request ID
/// after an uncertain response. It never restores authority from local data.
class UserAuthorityDurableCommandController {
  UserAuthorityDurableCommandController({
    required this.store,
    required this.service,
    required this.requireActor,
    this.verifyFreshActor,
    Uuid uuid = const Uuid(),
  }) : _uuid = uuid;

  final DurableSubmissionRepository store;
  final UserAuthorityCommandService service;
  final AppUser? Function() requireActor;
  final Uuid _uuid;
  final Future<void> Function(String uid)? verifyFreshActor;

  AppUser _actor({bool requireCurrentAdmin = false}) {
    final actor = requireActor();
    if (actor == null || actor.uid.trim().isEmpty) {
      throw const DurableSubmissionException(
        'account-unavailable',
        'The originating account is not available. The saved decision remains retained.',
      );
    }
    if (requireCurrentAdmin && !actor.canManageUsers) {
      throw const DurableSubmissionException(
        'permission-denied',
        'An approved Admin account is required for a new authority decision.',
      );
    }
    return actor;
  }

  Future<UserAuthorityMutationResult> approve(
    AppUser target, {
    required String reason,
  }) => _submit(
    target: target,
    operation: UserAuthorityOperation.approve,
    reason: reason,
  );

  Future<UserAuthorityMutationResult> revoke(
    AppUser target, {
    required String reason,
  }) => _submit(
    target: target,
    operation: UserAuthorityOperation.revoke,
    reason: reason,
  );

  Future<UserAuthorityMutationResult> replaceRoles(
    AppUser target, {
    required Iterable<AppRole> roles,
    required String reason,
  }) => _submit(
    target: target,
    operation: UserAuthorityOperation.replaceRoles,
    roles: roles,
    reason: reason,
  );

  Future<UserAuthorityMutationResult> _submit({
    required AppUser target,
    required UserAuthorityOperation operation,
    required String reason,
    Iterable<AppRole>? roles,
  }) async {
    final actor = _actor(requireCurrentAdmin: true);
    await verifyFreshActor?.call(actor.uid);
    if (_actor(requireCurrentAdmin: true).uid != actor.uid) {
      throw const DurableSubmissionException(
        "actor-mismatch",
        "The reviewing account changed. Reopen this decision.",
      );
    }
    final normalizedRoles = roles == null
        ? null
        : normalizeAuthorityRoles(roles);
    final command = UserAuthorityDurableCommand(
      originActorUid: actor.uid,
      requestId: _uuid.v4(),
      targetUid: target.uid,
      operation: operation,
      expectedAuthorityDigest: userAuthorityDigest(
        isApproved: target.isApproved,
        roles: target.roles,
      ),
      expectedAuthorityRevision: target.authorityRevision,
      reason: reason.trim(),
      roles: normalizedRoles,
    );
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: command.requestId,
        actorUid: command.originActorUid,
        requestId: command.requestId,
        aggregateId: command.targetUid,
        resourceKey: 'userAuthority:${command.targetUid}',
        protocol: userAuthorityDurableProtocol,
        envelopeJson: command.envelopeJson,
        displayMetadataJson: jsonEncode(<String, dynamic>{
          'schemaVersion': 1,
          'targetUid': command.targetUid,
          'operation': command.operation.wireName,
        }),
      ),
    );
    return check(saved.submissionId, dispatch: true);
  }

  Future<List<DurableSubmission>> listForCurrentActor() async {
    final actor = _actor();
    final rows = await store.listForActor(actor.uid, includeTerminal: true);
    return rows
        .where((row) => row.protocol == userAuthorityDurableProtocol)
        .where(
          (row) =>
              row.state.isUnresolved ||
              row.state == DurableSubmissionState.acceptedPendingAdoption,
        )
        .toList(growable: false);
  }

  Future<UserAuthorityMutationResult> check(
    String submissionId, {
    bool dispatch = false,
  }) async {
    final saved = await store.read(submissionId);
    if (saved == null || saved.protocol != userAuthorityDurableProtocol) {
      throw const DurableSubmissionException(
        'not-found',
        'The saved authority decision could not be found. Its evidence was not recreated.',
      );
    }
    final command = UserAuthorityDurableCommand.fromSubmission(saved);
    final actor = _actor();
    if (actor.uid != command.originActorUid) {
      throw const DurableSubmissionException(
        'actor-mismatch',
        'Return to the originating account to recover this authority decision.',
      );
    }
    if (saved.state.isAccepted && saved.receiptJson != null) {
      final result = _parseReceipt(saved, command, saved.receiptJson!);
      if (saved.state == DurableSubmissionState.acceptedPendingAdoption) {
        await store.markReconciled(
          submissionId: saved.submissionId,
          envelopeSha256: saved.envelopeSha256,
          receiptSha256: saved.receiptSha256!,
        );
      }
      return result;
    }

    if (dispatch) {
      _actor(requireCurrentAdmin: true);
      await verifyFreshActor?.call(actor.uid);
      if (_actor(requireCurrentAdmin: true).uid != command.originActorUid) {
        throw const DurableSubmissionException(
          'actor-mismatch',
          'Return to the reviewing account.',
        );
      }
    }
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: command.originActorUid,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      final accepted = await store.read(submissionId);
      if (accepted == null || accepted.receiptJson == null) {
        throw const DurableSubmissionException(
          'acceptance-missing',
          'The accepted authority evidence is incomplete and remains retained for review.',
        );
      }
      return _parseReceipt(accepted, command, accepted.receiptJson!);
    }
    if (!claim.mayDispatch) {
      throw DurableSubmissionException('not-dispatchable', switch (claim
          .disposition) {
        DurableSubmissionClaimDisposition.claimedElsewhere =>
          'This authority decision is already being checked. Its original request remains retained.',
        DurableSubmissionClaimDisposition.notDue =>
          'This authority decision is waiting for its next retry.',
        DurableSubmissionClaimDisposition.actorMismatch =>
          'Return to the originating account to recover this authority decision.',
        _ =>
          'This authority decision needs review before another request can be sent.',
      });
    }

    final UserAuthorityMutationResult result;
    try {
      result = await service.executeFrozen(
        requestId: command.requestId,
        originActorUid: command.originActorUid,
        confirmationOnly: !dispatch,
        targetUid: command.targetUid,
        operation: command.operation,
        expectedAuthorityDigest: command.expectedAuthorityDigest,
        expectedAuthorityRevision: command.expectedAuthorityRevision,
        roles: command.roles,
        reason: command.reason,
      );
    } catch (error) {
      // A transport refusal (including an older server rejecting this envelope)
      // cannot prove an earlier uncertain request was never accepted.
      final definite =
          error is UserAuthorityMutationException &&
          const {
            'authority-revision-mismatch',
            'authority-preimage-mismatch',
            'authority-no-op',
            'last-approved-admin-required',
            'authority-target-not-found',
            'approved-admin-required',
          }.contains(error.reasonCode);
      final outcome = await store.recordOutcome(
        claim,
        state: definite
            ? DurableSubmissionState.rejected
            : DurableSubmissionState.uncertain,
        message: definite
            ? '$error'
            : 'The authority decision outcome is not yet confirmed. Retry this saved decision.',
        errorCode: definite
            ? error.reasonCode ?? error.code
            : 'authority-outcome-uncertain',
      );
      final latest = await store.read(submissionId);
      if (latest != null &&
          latest.state.isAccepted &&
          latest.receiptJson != null) {
        return _parseReceipt(latest, command, latest.receiptJson!);
      }
      if (definite && outcome == DurableSubmissionOutcome.recorded) rethrow;
      throw const DurableSubmissionException(
        'uncertain',
        'The authority decision outcome is not yet confirmed. Its original request remains saved on this device.',
      );
    }

    final receiptJson = jsonEncode(_resultMap(result));
    final accepted = await store.settleAccepted(
      submissionId: submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: receiptJson,
      validateReceipt: (row, receipt) {
        final frozen = UserAuthorityDurableCommand.fromSubmission(row);
        _parseReceipt(row, frozen, jsonEncode(receipt));
        return true;
      },
      sameAcceptance: _sameOriginalAcceptance,
    );
    if (accepted.receiptJson == null || accepted.receiptSha256 == null) {
      throw const DurableSubmissionException(
        'acceptance-missing',
        'The accepted authority evidence could not be retained.',
      );
    }
    await store.markReconciled(
      submissionId: accepted.submissionId,
      envelopeSha256: accepted.envelopeSha256,
      receiptSha256: accepted.receiptSha256!,
    );
    final reconciled = await store.read(accepted.submissionId) ?? accepted;
    return _parseReceipt(reconciled, command, reconciled.receiptJson!);
  }

  UserAuthorityMutationResult _parseReceipt(
    DurableSubmission saved,
    UserAuthorityDurableCommand command,
    String receiptJson,
  ) {
    final receipt = durableSubmissionJsonObject(receiptJson);
    final result = service.parseSavedResult(
      receipt,
      requestId: command.requestId,
      targetUid: command.targetUid,
      operation: command.operation,
      expectedRoles: command.roles,
    );
    if (result.authorityRevision != command.expectedAuthorityRevision + 1) {
      throw const DurableSubmissionException(
        'invalid-receipt',
        'The authority result does not confirm the reviewed revision. The original decision remains saved for verification.',
      );
    }
    return result;
  }

  // A replay can observe a later directory state or reduced disclosure after
  // the original actor loses access. Those observations are not a new grant.
  // Both receipts are parsed before comparison; every original decision field
  // remains bound, including the committed revision, digest, audit and time.
  bool _sameOriginalAcceptance(
    Map<String, dynamic> retained,
    Map<String, dynamic> incoming,
  ) {
    const observations = {
      'currentAuthorityDigest',
      'currentAuthorityStatus',
      'currentAuthorityRevision',
      'supersededByLaterChange',
      'idempotentReplay',
    };
    Map<String, dynamic> original(Map<String, dynamic> receipt) => {
      for (final entry in receipt.entries)
        if (!observations.contains(entry.key)) entry.key: entry.value,
    };
    return persistedJsonEquivalent(
      jsonEncode(original(retained)),
      jsonEncode(original(incoming)),
    );
  }

  Map<String, dynamic> _resultMap(UserAuthorityMutationResult result) =>
      <String, dynamic>{
        'ok': true,
        'requestId': result.requestId,
        'targetUid': result.targetUid,
        'operation': result.operation.wireName,
        'isApproved': result.isApproved,
        'roles': result.roles.map((role) => role.name).toList(growable: false),
        'authorityDigest': result.authorityDigest,
        'authorityRevision': result.authorityRevision,
        'currentAuthorityDigest': result.currentAuthorityDigest,
        'currentAuthorityStatus': result.currentAuthorityStatus,
        'currentAuthorityRevision': result.currentAuthorityRevision,
        'supersededByLaterChange': result.supersededByLaterChange,
        'auditId': result.auditId,
        'committedAt': result.committedAt.toUtc().toIso8601String(),
        'idempotentReplay': result.idempotentReplay,
      };
}
