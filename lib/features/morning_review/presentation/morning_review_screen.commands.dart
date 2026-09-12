part of 'morning_review_screen.dart';

extension _MorningReviewScreenCommands on _MorningReviewScreenState {
  Future<void> _startReview() => _runCommand(
    () => ref.read(morningReviewCommandServiceProvider).start(),
    success: 'Morning Review opened. You are the facilitator.',
  );

  Future<void> _joinReview(String sessionId) => _runCommand(
    () => ref.read(morningReviewCommandServiceProvider).join(sessionId),
    success: 'Attendance recorded. You can now contribute.',
    sessionId: sessionId,
  );

  Future<void> _recordNotHeld() async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final reason = await showMorningReviewTextPrompt(
      context,
      guard: guard,
      title: 'Record review not held',
      label: 'Reason',
      actionLabel: 'Record not held',
      supportingText:
          'This creates the single governed record for today and a viewable PDF record.',
      maximum: 1600,
    );
    if (reason == null) return;
    await _runCommand(
      () => service.recordNotHeld(reason),
      success: 'Today has been recorded as not held.',
    );
  }

  Future<void> _addEntry({
    required AppUser actor,
    required MorningReviewSession session,
    required List<AssetInstanceRecord> assets,
    MorningReviewSourceFact? sourceFact,
  }) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final kinds = <MorningReviewEntryKind>[
      MorningReviewEntryKind.update,
      MorningReviewEntryKind.observation,
      MorningReviewEntryKind.plan,
      MorningReviewEntryKind.blocker,
      MorningReviewEntryKind.decision,
      MorningReviewEntryKind.idea,
      MorningReviewEntryKind.remainingCompliance,
      MorningReviewEntryKind.safetyConcern,
      if (actor.canProvideMorningReviewMaintenanceUpdate) ...[
        MorningReviewEntryKind.currentCompliance,
        MorningReviewEntryKind.maintenanceUpdate,
      ],
      if (session.facilitatorUid == actor.uid || actor.isAdmin)
        MorningReviewEntryKind.conclusion,
    ];
    final entry = await showMorningReviewEntryEditor(
      context,
      guard: guard,
      assets: assets,
      allowedKinds: kinds,
      sourceFact: sourceFact,
      initialKind: sourceFact?.section == MorningReviewSection.safety
          ? MorningReviewEntryKind.safetyConcern
          : null,
    );
    if (entry == null) return;
    await _runCommand(
      () => service.addEntry(sessionId: session.sessionId, entry: entry),
      success: 'Contribution added under your name.',
      sessionId: session.sessionId,
    );
  }

  Future<void> _addAddendum({
    required MorningReviewSession session,
    required List<AssetInstanceRecord> assets,
  }) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final entry = await showMorningReviewEntryEditor(
      context,
      guard: guard,
      assets: assets,
      allowedKinds: const [MorningReviewEntryKind.addendum],
      initialKind: MorningReviewEntryKind.addendum,
    );
    if (entry == null || !mounted) return;
    final reason = await showMorningReviewTextPrompt(
      context,
      guard: guard,
      title: 'Reason for addendum',
      label: 'Why the frozen record needs this clarification',
      actionLabel: 'Append addendum',
      maximum: 1600,
    );
    if (reason == null) return;
    await _runCommand(
      () => service.addAddendum(
        sessionId: session.sessionId,
        entry: entry,
        reason: reason,
      ),
      success:
          'Attributed addendum appended without changing the frozen record.',
      sessionId: session.sessionId,
    );
  }

  Future<void> _createAction({
    required MorningReviewSession session,
    required List<AssetInstanceRecord> assets,
    required List<MorningReviewParticipant> participants,
  }) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final action = await showMorningReviewActionEditor(
      context,
      guard: guard,
      assets: assets,
      participants: participants,
    );
    if (action == null) return;
    await _runCommand(
      () => service.createAction(sessionId: session.sessionId, action: action),
      success: 'Owned action created.',
      sessionId: session.sessionId,
    );
  }

  Future<void> _acceptAction(MorningReviewAction action) => _runCommand(
    () => ref
        .read(morningReviewCommandServiceProvider)
        .acceptAction(sessionId: action.sessionId, action: action),
    success: 'Action accepted.',
    sessionId: action.sessionId,
  );

  Future<void> _completeAction(MorningReviewAction action) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final note = await showMorningReviewTextPrompt(
      context,
      guard: guard,
      title: 'Complete action',
      label: 'Completion evidence or outcome',
      actionLabel: 'Mark completed',
      maximum: 1600,
    );
    if (note == null) return;
    await _runCommand(
      () => service.completeAction(
        sessionId: action.sessionId,
        action: action,
        note: note,
      ),
      success: 'Action completed with attributed evidence.',
      sessionId: action.sessionId,
    );
  }

  Future<void> _addStandingConcern(MorningReviewSession session) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final concern = await showMorningReviewStandingConcernEditor(
      context,
      guard: guard,
    );
    if (concern == null) return;
    await _runCommand(
      () => service.createStandingConcern(
        sessionId: session.sessionId,
        concern: concern,
      ),
      success: 'Standing concern will carry until formally resolved.',
      sessionId: session.sessionId,
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
      ),
      success: 'Today\'s standing-concern check recorded.',
      sessionId: session.sessionId,
    );
  }

  Future<void> _resolveStandingConcern(
    MorningReviewSession session,
    MorningReviewStandingConcern concern,
  ) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final reason = await showMorningReviewTextPrompt(
      context,
      guard: guard,
      title: 'Resolve standing concern',
      label: 'Resolution evidence',
      actionLabel: 'Resolve concern',
      maximum: 1600,
    );
    if (reason == null) return;
    await _runCommand(
      () => service.resolveStandingConcern(
        sessionId: session.sessionId,
        concern: concern,
        reason: reason,
      ),
      success: 'Standing concern resolved.',
      sessionId: session.sessionId,
    );
  }

  Future<void> _takeOver(MorningReviewSession session) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final reason = await showMorningReviewTextPrompt(
      context,
      guard: guard,
      title: 'Take over facilitation',
      label: 'Reason for controlled takeover',
      actionLabel: 'Take over',
      maximum: 1600,
    );
    if (reason == null) return;
    await _runCommand(
      () => service.takeOver(session: session, reason: reason),
      success: 'You are now the recorded facilitator.',
      sessionId: session.sessionId,
    );
  }

  Future<void> _finalize(MorningReviewSession session) async {
    if (!_canBeginChange()) return;
    final service = _editorCommandService();
    if (service == null) return;
    final guard = _morningEditorGuard();
    final summary = await showMorningReviewTextPrompt(
      context,
      guard: guard,
      title: 'Finalize Morning Review',
      label: 'Room conclusion and forward plan',
      actionLabel: 'Finalize meeting',
      supportingText:
          'This freezes the source snapshot, contributions, attendance and current action register into the meeting document.',
    );
    if (summary == null) return;
    await _runCommand(
      () => service.finalize(session: session, summary: summary),
      success: 'Meeting finalized. The PDF record is now available.',
      sessionId: session.sessionId,
    );
  }

  Future<void> _runCommand(
    Future<MorningReviewCommandResult> Function() command, {
    required String success,
    String? sessionId,
    bool resuming = false,
  }) async {
    if (!mounted || _busy || (!resuming && !_canBeginChange())) return;
    _update(() => _busy = true);
    try {
      final result = await command();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: BafColors.success),
      );
      _refreshSession(result.sessionId ?? sessionId);
    } on MorningReviewCommandException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: BafColors.danger,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Morning Review could not be updated: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        _update(() => _busy = false);
        await _loadPendingChange();
      }
    }
  }

  void _refresh() {
    final actorUid = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor?.uid;
    _refreshSession(
      ref.read(currentMorningReviewSessionProvider).value?.sessionId,
    );
    if (actorUid != null) unawaited(_loadPendingChange());
  }

  void _refreshSession(String? sessionId) {
    ref.invalidate(morningReviewPlantDayProvider);
    ref.invalidate(currentMorningReviewSessionProvider);
    ref.invalidate(recentMorningReviewSessionsProvider);
    ref.invalidate(activeMorningReviewActionsProvider);
    ref.invalidate(morningReviewStandingConcernsProvider);
    if (sessionId != null) {
      ref.invalidate(morningReviewParticipantsProvider(sessionId));
      ref.invalidate(morningReviewEntriesProvider(sessionId));
      ref.invalidate(morningReviewActionsProvider(sessionId));
      ref.invalidate(morningReviewConcernChecksProvider(sessionId));
      ref.invalidate(morningReviewDocumentProvider(sessionId));
    }
  }

  Widget Function(Widget) _morningEditorGuard() {
    final origin =
        CurrentActorAccess.resolve(
          ref.read(currentAppUserProvider),
        ).actor?.uid ??
        '';
    return (child) => CurrentActorDialogGuard(
      originUid: origin,
      permission: (actor) => actor.canContributeMorningReview,
      child: child,
    );
  }

  void _schedulePendingReconciliation(AppUser actor) {
    if (_reconciliationScheduledFor == actor.uid) return;
    _reconciliationScheduledFor = actor.uid;
    _savedChange = null;
    _savedChangeError = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadPendingChange());
    });
  }

  Future<void> _loadPendingChange() async {
    final actor = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor;
    if (actor == null) return;
    try {
      final service = ref.read(morningReviewCommandServiceProvider);
      final saved = await service.pendingSubmission();
      if (!mounted ||
          CurrentActorAccess.resolve(
                ref.read(currentAppUserProvider),
              ).actor?.uid !=
              actor.uid) {
        return;
      }
      _update(() {
        _savedChange = saved;
        _savedChangeError = null;
      });
    } catch (error) {
      if (!mounted ||
          CurrentActorAccess.resolve(
                ref.read(currentAppUserProvider),
              ).actor?.uid !=
              actor.uid) {
        return;
      }
      _update(() => _savedChangeError = '$error');
    }
  }

  Future<void> _reconcilePending(String actorUid) async {
    if (!mounted || _busy) return;
    final actor = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor;
    if (actor?.uid != actorUid) return;
    await _runCommand(
      () async {
        final result = await ref
            .read(morningReviewCommandServiceProvider)
            .reconcilePending();
        if (result == null) {
          throw const MorningReviewCommandException(
            'No saved change remains to check.',
          );
        }
        return result;
      },
      success: 'The original Morning Review change is confirmed.',
      resuming: true,
    );
  }

  Future<void> _cancelUnsentChange() async {
    if (!mounted || _busy) return;
    _update(() => _busy = true);
    try {
      await ref.read(morningReviewCommandServiceProvider).cancelNeverSent();
    } catch (error) {
      if (mounted) _update(() => _savedChangeError = '$error');
    } finally {
      if (mounted) {
        _update(() => _busy = false);
        await _loadPendingChange();
      }
    }
  }

  bool _canBeginChange() {
    if (!mounted || _busy) return false;
    if (_savedChange == null && _savedChangeError == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Check the saved Morning Review change before starting another.',
        ),
      ),
    );
    return false;
  }

  MorningReviewCommandService? _editorCommandService() {
    try {
      return ref.read(morningReviewCommandServiceProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
      return null;
    }
  }
}
