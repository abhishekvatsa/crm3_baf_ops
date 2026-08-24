part of 'closed_tickets_screen.dart';

extension _ClosedTicketCorrections on _ClosedTicketsScreenState {
  Future<void> _openTicketDetails(
    MaintenanceRecord ticket, {
    required bool canCorrect,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder:
            (detailContext) => MaintenanceTicketDetailScreen(
              ticket: ticket,
              onCorrect:
                  canCorrect
                      ? () {
                        Navigator.pop(detailContext);
                        Future<void>.microtask(() => _correctTicket(ticket));
                      }
                      : null,
            ),
      ),
    );
  }

  Future<void> _correctTicket(MaintenanceRecord ticket) async {
    if (!ticket.isSynced) {
      _showSnack(
        message: 'Synchronize this issue before recording a correction.',
        color: BafColors.warning,
      );
      return;
    }
    final actor = ref.read(currentAppUserProvider).value;
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (actor == null ||
        firebaseUser == null ||
        firebaseUser.uid != actor.uid ||
        !actor.canCorrectMaintenanceTicket) {
      _showSnack(
        message: 'Admin or SI authority is required for audited correction.',
        color: BafColors.danger,
      );
      return;
    }
    final ticketId = ticket.firestoreId?.trim();
    if (ticketId == null || ticketId.isEmpty) {
      _showSnack(
        message: 'This issue has no governed server identity.',
        color: BafColors.danger,
      );
      return;
    }
    final draft = await showDialog<MaintenanceTicketCorrectionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MaintenanceTicketCorrectionDialog(ticket: ticket),
    );
    if (!mounted || draft == null) return;

    final ticketKey = _ClosedTicketsScreenState._ticketKey(ticket);
    if (_correctingTicketKeys.contains(ticketKey)) return;
    _setCorrectionBusy(ticketKey, true);
    try {
      final expectedLocalVersion = ticket.version;
      final expectedLocalUpdatedAt = ticket.updatedAt.toUtc();
      final command = WorkflowCommandFactory.create(
        type: WorkflowCommandType.correctMaintenanceTicket,
        aggregateId: ticketId,
        expectedVersion: expectedLocalVersion,
        payload: <String, Object?>{
          'reason': draft.reason,
          'corrections': draft.corrections,
        },
      );
      final receipt = await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      if (receipt.resultKey != 'maintenance-ticket-corrected' ||
          receipt.aggregateVersion <= expectedLocalVersion ||
          receipt.result['ticketId'] != ticketId) {
        throw StateError('The correction receipt did not match this issue.');
      }
      var converged = false;
      if (kIsWeb) {
        final remote = await ref
            .read(firestoreMaintenanceRepo)
            .readMaintenanceIssueCommandServerState(ticketId);
        converged =
            remote != null &&
            !remote.isDeleted &&
            remote.version >= receipt.aggregateVersion;
      } else {
        try {
          await ref
              .read(maintenanceIssueCommandReconcilerProvider)
              .adoptServerMutation(
                firestoreId: ticketId,
                expectedLocalVersion: expectedLocalVersion,
                expectedLocalUpdatedAt: expectedLocalUpdatedAt,
                minimumServerVersion: receipt.aggregateVersion,
              );
          converged = true;
        } on MaintenanceIssueCommandConvergenceException {
          converged = false;
        }
      }
      try {
        await ref
            .read(syncCoordinatorProvider)
            .runFullSync(reason: 'maintenance_ticket_corrected', force: true);
      } catch (_) {
        // The authoritative receipt is retained; adoption and sync can retry.
      }
      await _loadInitial();
      _showSnack(
        message:
            converged
                ? 'Audited correction recorded and refreshed.'
                : 'Audited correction accepted. Exact device refresh is pending and will retry during sync.',
        color: converged ? BafColors.success : BafColors.warning,
      );
    } catch (error) {
      _showSnack(
        message: 'Could not record correction: $error',
        color: BafColors.danger,
      );
    } finally {
      _setCorrectionBusy(ticketKey, false);
    }
  }
}
