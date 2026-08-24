part of 'ticket_screen.dart';

extension _TicketGovernedActions on _TicketScreenState {
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
    if (!ticket.isSynced || _busyTicketId != null) return;
    final actor = ref.read(currentAppUserProvider).value;
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (actor == null ||
        firebaseUser == null ||
        firebaseUser.uid != actor.uid ||
        !actor.canCorrectMaintenanceTicket) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Admin or SI authority is required for audited correction.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    final ticketId = ticket.firestoreId?.trim();
    if (ticketId == null || ticketId.isEmpty) return;
    final draft = await showDialog<MaintenanceTicketCorrectionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MaintenanceTicketCorrectionDialog(ticket: ticket),
    );
    if (!mounted || draft == null || _busyTicketId != null) return;

    final expectedLocalVersion = ticket.version;
    final expectedLocalUpdatedAt = ticket.updatedAt.toUtc();
    _setBusyTicketId(ticketId);
    try {
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
      validateMaintenanceTicketCorrectionReceipt(
        command: command,
        receipt: receipt,
      );
      final converged = await _adoptAcceptedIssueCommand(
        ticketId: ticketId,
        expectedLocalVersion: expectedLocalVersion,
        expectedLocalUpdatedAt: expectedLocalUpdatedAt,
        minimumServerVersion: receipt.aggregateVersion,
        syncReason: 'maintenance_ticket_corrected',
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            converged
                ? 'Audited correction recorded and refreshed.'
                : 'Audited correction accepted. Exact device refresh is pending and will retry during sync.',
          ),
          backgroundColor: converged ? BafColors.success : BafColors.warning,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not record correction: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) _setBusyTicketId(null);
    }
  }

  Future<void> _closeWithoutResolution(MaintenanceRecord ticket) async {
    final ticketId = ticket.firestoreId?.trim();
    if (ticketId == null || ticketId.isEmpty || _busyTicketId != null) return;
    final actor = ref.read(currentAppUserProvider).value;
    if (actor?.canCloseMaintenanceIssueWithoutResolution != true) return;
    final draft = await showIssueAdministrativeClosureDialog(
      context,
      ticket: ticket,
    );
    if (draft == null || !mounted) return;
    final expectedLocalVersion = ticket.version;
    final expectedLocalUpdatedAt = ticket.updatedAt.toUtc();
    _setBusyTicketId(ticketId);
    try {
      final command = buildMaintenanceIssueAdministrativeClosureCommand(
        ticket: ticket,
        disposition: draft.disposition,
        reason: draft.reason,
      );
      final receipt = await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      validateMaintenanceIssueAdministrativeClosureReceipt(
        command: command,
        receipt: receipt,
        disposition: draft.disposition,
      );
      final converged = await _adoptAcceptedIssueCommand(
        ticketId: ticketId,
        expectedLocalVersion: expectedLocalVersion,
        expectedLocalUpdatedAt: expectedLocalUpdatedAt,
        minimumServerVersion: receipt.aggregateVersion,
        syncReason: 'maintenance_ticket_closed_without_resolution',
      );
      if (!mounted) return;
      final coordinationCancelled =
          receipt.result['cancelledCoordination'] == true;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            converged
                ? coordinationCancelled
                    ? 'Issue closed without resolution; linked Operations obligation cancelled'
                    : 'Issue closed without resolution'
                : 'Closure accepted. Exact device refresh is pending and will retry during sync.',
          ),
          backgroundColor: converged ? BafColors.warning : BafColors.audit,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not close issue: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) _setBusyTicketId(null);
    }
  }

  Future<void> _openIssueCoordination(MaintenanceRecord ticket) async {
    final complianceId = ticket.workflowComplianceId?.trim();
    if (complianceId == null || complianceId.isEmpty) return;
    try {
      final actorAsync = ref.read(currentAppUserProvider);
      final actor = actorAsync.asData?.value;
      if (actorAsync.isLoading ||
          actorAsync.hasError ||
          actor == null ||
          !actor.isApproved) {
        throw StateError('Approved compliance access is required.');
      }
      final record = await ref.read(
        workflowComplianceRecordProvider((
          actorUid: actor.uid,
          complianceId: complianceId,
        )).future,
      );
      if (!mounted) return;
      if (record == null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Coordination record is not available yet.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ComplianceDetailScreen(record: record),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not open coordination: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }
}
