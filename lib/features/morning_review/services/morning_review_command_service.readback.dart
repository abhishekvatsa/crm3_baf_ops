part of 'morning_review_command_service.dart';

extension _MorningReviewReadback on MorningReviewCommandService {
  Future<void> _verifyMorningReviewReadback(
    DurableSubmission saved,
    MorningReviewCommandResult receipt,
    Future<Map<String, dynamic>> Function(String, String) read,
  ) async {
    final request = _request(saved);
    final operation = receipt.operation;
    final sessionId = receipt.sessionId!;
    final collection = switch (operation) {
      MorningReviewCommand.join => 'morning_review_participants',
      MorningReviewCommand.addEntry ||
      MorningReviewCommand.addAddendum => 'morning_review_entries',
      MorningReviewCommand.createAction ||
      MorningReviewCommand.acceptAction ||
      MorningReviewCommand.completeAction => 'morning_review_actions',
      MorningReviewCommand.createStandingConcern ||
      MorningReviewCommand.resolveStandingConcern =>
        'morning_review_standing_concerns',
      MorningReviewCommand.checkStandingConcern =>
        'morning_review_concern_checks',
      MorningReviewCommand.finalize => 'morning_review_documents',
      _ => 'morning_review_sessions',
    };
    final data = await read(collection, receipt.entityId);
    _actor();
    Never fail() => throw const MorningReviewCommandException(
      'The server accepted this change, but the corresponding record is not yet verified. The receipt is saved; checking again will not resend the change.',
      code: 'readback-pending',
    );
    void require(bool value) {
      if (!value) fail();
    }

    bool at(Object? value, DateTime expected) {
      try {
        return readRequiredPersistedDateTime(
          value,
          field: 'acceptedAt',
          source: collection,
        ).isAtSameMomentAs(expected);
      } catch (_) {
        return false;
      }
    }

    bool same(Object? left, Object? right) =>
        jsonEncode(left) == jsonEncode(right);
    void version() => require(
      data['version'] is int && (data['version'] as int) >= receipt.version,
    );
    void immutableDraft(String key, Iterable<String> fields) {
      final draft = request[key] as Map<String, dynamic>;
      for (final field in fields) {
        require(same(data[field], draft[field]));
      }
    }

    switch (operation) {
      case MorningReviewCommand.start:
      case MorningReviewCommand.recordNotHeld:
      case MorningReviewCommand.takeOver:
        MorningReviewSession.fromMap(data, receipt.entityId);
        require(data['sessionId'] == sessionId);
        version();
        if (operation == MorningReviewCommand.start) {
          require(
            data['openedByUid'] == saved.actorUid &&
                at(data['openedAt'], receipt.committedAt),
          );
        } else if (operation == MorningReviewCommand.recordNotHeld) {
          require(
            data['status'] == 'notHeld' &&
                data['finalSummary'] == request['reason'] &&
                data['finalizedByUid'] == saved.actorUid &&
                at(data['finalizedAt'], receipt.committedAt),
          );
        } else {
          require(
            (data['facilitatorHistory'] as List).any(
              (raw) =>
                  raw is Map &&
                  raw['takenOverByUid'] == saved.actorUid &&
                  raw['reason'] == request['reason'] &&
                  at(raw['takenOverAt'], receipt.committedAt),
            ),
          );
        }
      case MorningReviewCommand.join:
        MorningReviewParticipant.fromMap(data, receipt.entityId);
        require(
          data['participantId'] == receipt.entityId &&
              data['sessionId'] == sessionId &&
              data['userUid'] == saved.actorUid &&
              data['state'] == 'joined',
        );
      // Join is also a legitimate no-op when attendance already existed.
      case MorningReviewCommand.addEntry:
      case MorningReviewCommand.addAddendum:
        MorningReviewEntry.fromMap(data, receipt.entityId);
        require(
          data['entryId'] == saved.requestId &&
              data['sessionId'] == sessionId &&
              data['authorUid'] == saved.actorUid &&
              at(data['createdAt'], receipt.committedAt),
        );
        immutableDraft('entryDraft', const [
          'section',
          'kind',
          'text',
          'assetClassId',
          'assetClassName',
          'assetInstanceId',
          'assetNumber',
          'sourceReferences',
        ]);
        if (operation == MorningReviewCommand.addAddendum) {
          require(data['addendumReason'] == request['reason']);
        }
      case MorningReviewCommand.createAction:
      case MorningReviewCommand.acceptAction:
      case MorningReviewCommand.completeAction:
        MorningReviewAction.fromMap(data, receipt.entityId);
        require(
          data['actionId'] == receipt.entityId &&
              data['sessionId'] == sessionId,
        );
        version();
        if (operation == MorningReviewCommand.createAction) {
          require(
            data['createdByUid'] == saved.actorUid &&
                at(data['createdAt'], receipt.committedAt),
          );
          immutableDraft('actionDraft', const [
            'section',
            'text',
            'assetClassId',
            'assetClassName',
            'assetInstanceId',
            'assetNumber',
            'assigneeUid',
            'assigneeRole',
          ]);
          final due = (request['actionDraft'] as Map)['dueAt'];
          require(
            due == null
                ? data['dueAt'] == null
                : at(data['dueAt'], DateTime.parse(due as String)),
          );
        } else if (operation == MorningReviewCommand.acceptAction) {
          require(
            data['acceptedByUid'] == saved.actorUid &&
                at(data['acceptedAt'], receipt.committedAt) &&
                const {'accepted', 'completed'}.contains(data['status']),
          );
        } else {
          require(
            data['status'] == 'completed' &&
                data['completedByUid'] == saved.actorUid &&
                at(data['completedAt'], receipt.committedAt) &&
                data['completionNote'] == request['reason'],
          );
        }
      case MorningReviewCommand.createStandingConcern:
      case MorningReviewCommand.resolveStandingConcern:
        MorningReviewStandingConcern.fromMap(data, receipt.entityId);
        require(data['concernId'] == receipt.entityId);
        version();
        if (operation == MorningReviewCommand.createStandingConcern) {
          require(
            data['originSessionId'] == sessionId &&
                data['createdByUid'] == saved.actorUid &&
                at(data['createdAt'], receipt.committedAt),
          );
          immutableDraft('concernDraft', const [
            'title',
            'detail',
            'criticality',
          ]);
        } else {
          require(
            data['status'] == 'resolved' &&
                data['resolvedByUid'] == saved.actorUid &&
                at(data['resolvedAt'], receipt.committedAt) &&
                data['resolutionReason'] == request['reason'],
          );
        }
      case MorningReviewCommand.checkStandingConcern:
        MorningReviewConcernCheck.fromMap(data, receipt.entityId);
        require(
          data['checkId'] == receipt.entityId &&
              data['sessionId'] == sessionId &&
              data['concernId'] == request['concernId'] &&
              data['state'] == request['checkState'] &&
              receipt.status == request['checkState'] &&
              data['note'] == request['reason'] &&
              data['checkedByUid'] == saved.actorUid &&
              at(data['checkedAt'], receipt.committedAt),
        );
      case MorningReviewCommand.finalize:
        MorningReviewDocument.fromMap(data, receipt.entityId);
        require(
          data['sessionId'] == sessionId &&
              data['status'] == 'finalized' &&
              data['finalSummary'] == request['summary'] &&
              data['finalizedByUid'] == saved.actorUid &&
              at(data['finalizedAt'], receipt.committedAt),
        );
    }
  }
}
