part of 'morning_review_command_service.dart';

extension _MorningReviewDurableCommands on MorningReviewCommandService {
  DurableSubmissionRepository get _store =>
      _durableStore ??
      (throw const MorningReviewCommandException(
        'Saved submissions are unavailable. Nothing was sent.',
        code: 'local-state',
      ));
  String get _resource => 'morningReview:$_actorScope';

  AppUser _actor() {
    final actor = _requireActor?.call();
    if (actor == null ||
        !actor.canViewMorningReview ||
        actor.uid != _actorScope) {
      throw const MorningReviewCommandException(
        'Return to the approved account that started this change. Your saved entries are retained.',
        code: 'origin-account-unverified',
      );
    }
    return actor;
  }

  void _commandActor(Map<String, dynamic> request) {
    final actor = _actor();
    final operation = _operation(request);
    if ((const {
              MorningReviewCommand.start,
              MorningReviewCommand.recordNotHeld,
              MorningReviewCommand.takeOver,
              MorningReviewCommand.finalize,
              MorningReviewCommand.amendAction,
              MorningReviewCommand.resolveStandingConcern,
              MorningReviewCommand.addAddendum,
            }.contains(operation) &&
            !actor.canFacilitateMorningReview) ||
        (operation == MorningReviewCommand.addEntry &&
            const {
              'maintenanceUpdate',
              'currentCompliance',
            }.contains((request['entryDraft'] as Map?)?['kind']) &&
            !actor.canProvideMorningReviewMaintenanceUpdate)) {
      throw const MorningReviewCommandException(
        'Your current account permissions do not allow this saved change. Its entries are retained.',
        code: 'current-permission-required',
      );
    }
  }

  Future<DurableSubmission?> _restoreDurable() async {
    _actor();
    // Older stores have no durable acceptance state. Keep exact source bytes;
    // do not infer acceptance, reactivate an old row, or delete the old journal.
    final legacy = await _idempotencyStore.retainedEvidence(_actorScope);
    _actor();
    for (final source in legacy) {
      await _store.importLegacyNeedsReview(
        submissionId:
            'morning-review-legacy-${durableSubmissionSha256(source.key)}',
        resourceKey: _resource,
        sourceKey: source.key,
        sourceBytes: source.bytes,
      );
      _actor();
    }
    final saved = await _store.findUnresolvedForResource(_resource);
    _actor();
    if (saved != null && !saved.isLegacy) _request(saved);
    return saved;
  }

  Map<String, dynamic> _request(DurableSubmission saved) {
    final envelope = saved.envelope;
    if (saved.protocol != 'assetHierarchy.v2' ||
        saved.actorUid != _actorScope ||
        saved.resourceKey != _resource ||
        saved.submissionId != saved.requestId ||
        envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != saved.actorUid ||
        envelope['request'] is! Map<String, dynamic>) {
      throw const MorningReviewCommandException(
        'Saved Morning Review ownership needs review.',
        code: 'local-state',
      );
    }
    final request = envelope['request'] as Map<String, dynamic>;
    _operation(request);
    if (request['requestId'] != saved.requestId ||
        (request['sessionId'] ?? request['requestId']) != saved.aggregateId) {
      throw const MorningReviewCommandException(
        'Saved Morning Review identities disagree.',
        code: 'local-state',
      );
    }
    return request;
  }

  MorningReviewCommand _operation(Map<String, dynamic> request) =>
      MorningReviewCommand.values.singleWhere(
        (value) => value.wireName == request['operation'],
        orElse: () => throw const MorningReviewCommandException(
          'The saved Morning Review operation needs review.',
          code: 'local-state',
        ),
      );

  Future<MorningReviewCommandResult> _submitDurable(
    MorningReviewCommand operation, {
    String? sessionId,
    Map<String, dynamic> extra = const {},
  }) async {
    _actor();
    final pending = await _restoreDurable();
    if (pending != null) {
      // A new click never silently dispatches older, possibly different work.
      // Explicit Check uses its complete original envelope and original ID.
      throw const MorningReviewCommandException(
        'An earlier Morning Review change is saved. Check that change before submitting another.',
        code: 'prior-command-pending',
      );
    }
    final requestId = const Uuid().v4();
    final request = buildMorningReviewCommandRequest(
      operation: operation,
      requestId: requestId,
      sessionId: sessionId,
      extra: extra,
    );
    if (_verifyAcceptanceEvidence) request['recoveryVersion'] = 1;
    if (operation == MorningReviewCommand.start ||
        operation == MorningReviewCommand.recordNotHeld) {
      request['expectedPlantDay'] = currentIndiaPlantDay(_now());
    }
    _commandActor(request);
    final saved = await _store.prepare(
      DurableSubmissionDraft(
        submissionId: requestId,
        actorUid: _actorScope,
        requestId: requestId,
        aggregateId: sessionId ?? requestId,
        resourceKey: _resource,
        protocol: 'assetHierarchy.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': _actorScope,
          'request': request,
        }),
      ),
    );
    _actor();
    return _checkDurable(saved);
  }

  MorningReviewCommandResult _receipt(
    DurableSubmission saved,
    Map<String, dynamic> raw,
  ) {
    final request = _request(saved);
    final operation = _operation(request);
    final result = MorningReviewCommandResult.fromMap(
      raw,
      expectedRequestId: saved.requestId,
      expectedOperation: operation,
      expectedSessionId: request['sessionId'] as String?,
    );
    final session = result.sessionId!;
    final expectedEntity = switch (operation) {
      MorningReviewCommand.join => '${session}_${saved.actorUid}',
      MorningReviewCommand.addEntry ||
      MorningReviewCommand.addAddendum ||
      MorningReviewCommand.createAction ||
      MorningReviewCommand.createStandingConcern => saved.requestId,
      MorningReviewCommand.acceptAction ||
      MorningReviewCommand.completeAction ||
      MorningReviewCommand.amendAction => request['actionId'],
      MorningReviewCommand.resolveStandingConcern => request['concernId'],
      MorningReviewCommand.checkStandingConcern =>
        '${session}_${request['concernId']}',
      _ => session,
    };
    if ((operation == MorningReviewCommand.amendAction &&
            result.status !=
                ((request['actionCorrection'] as Map)['kind'] == 'cancel'
                    ? 'cancelled'
                    : 'open')) ||
        result.entityId != expectedEntity ||
        (request['sessionId'] == null &&
            session != currentIndiaPlantDay(result.committedAt)) ||
        (request['expectedPlantDay'] != null &&
            session != request['expectedPlantDay']) ||
        (request['expectedVersion'] != null &&
            result.version != (request['expectedVersion'] as int) + 1) ||
        (const {
              MorningReviewCommand.start,
              MorningReviewCommand.recordNotHeld,
              MorningReviewCommand.createAction,
              MorningReviewCommand.createStandingConcern,
            }.contains(operation) &&
            result.version != 1)) {
      throw const MorningReviewCommandException(
        'The receipt does not identify this exact saved change.',
        code: 'data-loss',
      );
    }
    return result;
  }

  Future<MorningReviewCommandResult> _checkDurable(
    DurableSubmission saved,
  ) async {
    _actor();
    if (saved.isLegacy || saved.state == DurableSubmissionState.needsReview) {
      throw const MorningReviewCommandException(
        'Older Morning Review retry evidence is preserved for review. It will not be sent automatically.',
        code: 'legacy-needs-review',
      );
    }
    _request(saved);
    if (saved.state.isAccepted) return _adoptDurable(saved);
    final request = _request(saved);
    // Older envelopes do not bind an intended day. Even a same-day check can
    // cross midnight while awaiting the server, so it may only read a receipt.
    final unpinnedSessionless =
        request['sessionId'] == null && request['expectedPlantDay'] is! String;
    var receiptOnly =
        unpinnedSessionless ||
        (request['sessionId'] == null &&
            request['expectedPlantDay'] != currentIndiaPlantDay(_now()));
    if (receiptOnly && saved.attemptCount == 0) {
      throw MorningReviewCommandException(
        unpinnedSessionless
            ? 'This older saved change has no verified intended meeting date. Review or cancel it before entering a new change; nothing was sent.'
            : 'This saved opening or not-held change belongs to an earlier day. Its outcome needs review before any new meeting is created; nothing was resent.',
        code: 'sessionless-day-changed',
      );
    }
    try {
      _commandActor(request);
    } on MorningReviewCommandException catch (error) {
      if (error.code != 'current-permission-required') rethrow;
      // An approved original actor may retrieve history after a role change.
      // This path never executes the original operation.
      receiptOnly = true;
    }
    final capability = _requireCapability;
    if (capability == null) {
      throw const MorningReviewCommandException(
        'Server support cannot be verified. The change remains saved.',
        code: 'capability-unavailable',
      );
    }
    if (receiptOnly) {
      _actor();
    } else {
      _commandActor(request);
    }
    await capability(_actorScope);
    if (receiptOnly) {
      _actor();
    } else {
      _commandActor(request);
    }
    final claim = await _store.claim(
      submissionId: saved.submissionId,
      actorUid: _actorScope,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _adoptDurable(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw const MorningReviewCommandException(
        'This change is already being checked or needs review. Its original entries remain saved.',
        code: 'not-dispatched',
      );
    }
    final String receiptJson;
    try {
      if (receiptOnly) {
        _actor();
      } else {
        _commandActor(request);
      }
      final raw = _stringMap(
        await _invoke(
          receiptOnly
              ? {
                  'protocolVersion': 2,
                  'originActorUid': saved.actorUid,
                  'receiptLookup': request,
                }
              : saved.envelope,
        ),
      );
      _receipt(saved, raw);
      // Replay is an observation of the same acceptance, not a changed result.
      // Preserve every authoritative field; normalize only this transport flag.
      receiptJson = jsonEncode({...raw, 'idempotentReplay': false});
    } catch (error) {
      final details = error is FirebaseFunctionsException
          ? error.details
          : null;
      final proof = details is Map ? details['morningReviewRefusal'] : null;
      if (proof is Map &&
          proof['schemaVersion'] == 1 &&
          proof['actorUid'] == saved.actorUid &&
          proof['code'] == (error as FirebaseFunctionsException).code &&
          const {
            'aborted',
            'failed-precondition',
            'already-exists',
            'not-found',
          }.contains(proof['code']) &&
          proof['refusedAt'] is String &&
          DateTime.tryParse(proof['refusedAt'] as String) != null &&
          _morningCanonicalJson(proof['request']) ==
              _morningCanonicalJson(request)) {
        final outcome = await _store.recordOutcome(
          claim,
          state: DurableSubmissionState.rejected,
          errorCode: 'morning-review-refused-fenced',
          message: jsonEncode(proof),
        );
        if (outcome == DurableSubmissionOutcome.recorded) {
          _actor();
          throw MorningReviewCommandException(
            '${proof['message']} The server has preserved a refusal for this exact request. Your entries are retained; refresh and review before submitting again.',
            code: 'business-refused',
          );
        }
      }
      // Unknown/late refusal may follow an accepted earlier attempt. This
      // controller never clears its original identity or allocates a retry ID.
      await _store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        errorCode: 'morning-review-outcome-uncertain',
        message:
            'The outcome is not confirmed. Check the saved change to retry its exact original request.',
      );
      throw const MorningReviewCommandException(
        'The outcome is not confirmed. Your exact change is saved; use Check saved change when ready.',
        code: 'outcome-uncertain',
      );
    }
    // Retain a valid late receipt even if authentication changes during the call.
    final accepted = await _store.settleAccepted(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: receiptJson,
      validateReceipt: (row, raw) {
        _receipt(row, raw);
        return true;
      },
    );
    return _adoptDurable(accepted);
  }

  Future<MorningReviewCommandResult> _adoptDurable(
    DurableSubmission saved,
  ) async {
    _actor();
    final raw = saved.receiptJson;
    final hash = saved.receiptSha256;
    if (!saved.state.isAccepted || raw == null || hash == null) {
      throw const MorningReviewCommandException(
        'Saved acceptance evidence needs review.',
        code: 'local-state',
      );
    }
    final receipt = _receipt(saved, durableSubmissionJsonObject(raw));
    if (_verifyAcceptanceEvidence) {
      final proof = _stringMap(
        await _invoke({
          'protocolVersion': 2,
          'originActorUid': saved.actorUid,
          'receiptLookup': {
            'acceptanceEvidence': true,
            'request': _request(saved),
          },
        }),
      );
      _actor();
      if (proof['schemaVersion'] != 1 ||
          proof.length != 3 ||
          proof['receipt'] is! Map) {
        throw const MorningReviewCommandException(
          'The retained acceptance could not be verified.',
          code: 'data-loss',
        );
      }
      final actualReceipt = _stringMap(proof['receipt']);
      _receipt(saved, actualReceipt);
      if (_morningCanonicalJson({
            ...actualReceipt,
            'idempotentReplay': false,
          }) !=
          _morningCanonicalJson(durableSubmissionJsonObject(raw))) {
        throw const MorningReviewCommandException(
          'Acceptance differs from the saved receipt.',
          code: 'data-loss',
        );
      }
      final basis = proof['acceptanceBasis'];
      if (basis != null) {
        final expectedResult = Map<String, dynamic>.from(actualReceipt)
          ..remove('ok')
          ..remove('idempotentReplay');
        if (basis is! Map ||
            basis['schemaVersion'] != 1 ||
            basis['actorUid'] != saved.actorUid ||
            _morningCanonicalJson(basis['request']) !=
                _morningCanonicalJson(_request(saved)) ||
            _morningCanonicalJson(basis['result']) !=
                _morningCanonicalJson(expectedResult)) {
          throw const MorningReviewCommandException(
            'Acceptance is not bound to this exact request.',
            code: 'data-loss',
          );
        }
        await _store.markReconciled(
          submissionId: saved.submissionId,
          envelopeSha256: saved.envelopeSha256,
          receiptSha256: hash,
        );
        _actor();
        return receipt;
      }
      // Historical receipts without retained request evidence still need the
      // original strict subject readback; do not manufacture a missing proof.
    }
    final read = _readSubject;
    if (read == null) {
      throw const MorningReviewCommandException(
        'The server accepted this change. Its saved receipt is retained until the record can be checked.',
        code: 'readback-pending',
      );
    }
    await _verifyMorningReviewReadback(saved, receipt, read);
    _actor();
    await _store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: hash,
    );
    _actor();
    return receipt;
  }
}

String _morningCanonicalJson(Object? value) {
  Object? canonical(Object? item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(item[key])};
    }
    if (item is List) return item.map(canonical).toList();
    return item;
  }

  return jsonEncode(canonical(value));
}
