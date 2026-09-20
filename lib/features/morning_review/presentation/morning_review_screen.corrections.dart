part of 'morning_review_screen.dart';

extension _MorningReviewCorrections on _MorningReviewScreenState {
  Future<void> _amendAction(MorningReviewAction action) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final input = await showMorningReviewActionCorrectionEditor(
      context,
      action: action,
      guard: _morningEditorGuard(),
    );
    if (input == null) return;
    await _runCommand(
      () => service.amendAction(
        action: action,
        kind: input['kind']!,
        reason: input['reason']!,
        assigneeRole: input['assigneeRole'],
      ),
      success: 'Action corrected; previous state and reason preserved.',
      sessionId: action.sessionId,
    );
  }

  Future<void> _checkStandingConcern(
    MorningReviewSession session,
    MorningReviewStandingConcern concern,
  ) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final previous =
        ref
            .read(morningReviewConcernChecksProvider(session.sessionId))
            .valueOrNull
            ?.any((check) => check.concernId == concern.concernId) ??
        false;
    String? correctionReason;
    if (previous) {
      correctionReason = await showMorningReviewTextPrompt(
        context,
        guard: guard,
        title: 'Correct previous check',
        label: 'Reason for changing the recorded outcome',
        actionLabel: 'Continue',
        maximum: 1600,
      );
      if (correctionReason == null || !mounted) return;
    }
    final input = await showMorningReviewConcernCheckEditor(
      context,
      guard: guard,
      concern: concern,
    );
    if (input == null) return;
    await _runCommand(
      () => service.checkStandingConcern(
        sessionId: session.sessionId,
        concern: concern,
        state: input.state,
        note: input.note,
        expectedVersion: previous ? session.version : null,
        correctionReason: correctionReason,
      ),
      success: 'Today\'s standing-concern check recorded.',
      sessionId: session.sessionId,
    );
  }
}
