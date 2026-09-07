part of 'maintenance_ticket_detail_screen.dart';

class _LinkedWorkflowEvidence extends StatelessWidget {
  const _LinkedWorkflowEvidence({
    required this.ticket,
    required this.compliance,
  });

  final MaintenanceRecord ticket;
  final AsyncValue<List<ComplianceRequestRecord>> compliance;

  @override
  Widget build(BuildContext context) {
    return compliance.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: BafSpacing.sm),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => _EvidenceWarning(
        text:
            'Linked workflow completion evidence is temporarily unavailable: $error',
      ),
      data: (records) {
        final ticketId = ticket.firestoreId?.trim();
        final complianceId = ticket.workflowComplianceId?.trim();
        final linked =
            records
                .where(
                  (record) =>
                      !record.isDeleted &&
                      ((complianceId != null &&
                              complianceId.isNotEmpty &&
                              record.firestoreId == complianceId) ||
                          (ticketId != null &&
                              ticketId.isNotEmpty &&
                              record.linkedMaintenanceFirestoreId == ticketId)),
                )
                .toList()
              ..sort((a, b) {
                final aTime = a.raisedAt ?? a.createdAt;
                final bTime = b.raisedAt ?? b.createdAt;
                return aTime.compareTo(bTime);
              });
        if (linked.isEmpty) {
          return const _EmptyEvidence(
            text:
                'No linked compliance detail is present in the local workflow projection. Synchronize to check for current server evidence.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workflow completion evidence',
              style: TextStyle(
                color: BafColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            for (var index = 0; index < linked.length; index++) ...[
              if (index > 0) const Divider(height: BafSpacing.xl),
              _LinkedComplianceEvidence(record: linked[index]),
            ],
          ],
        );
      },
    );
  }
}

class _LinkedComplianceEvidence extends StatelessWidget {
  const _LinkedComplianceEvidence({required this.record});

  final ComplianceRequestRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                record.title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: BafSpacing.sm),
            StatusBadge(
              label: _enumLabel(record.statusKey),
              color: record.statusKey == 'confirmedClosed'
                  ? BafColors.success
                  : record.statusKey == 'complied'
                  ? BafColors.audit
                  : BafColors.warning,
            ),
          ],
        ),
        if (MaintenanceTicketDetailScreen._hasText(record.description)) ...[
          const SizedBox(height: BafSpacing.xs),
          Text(
            record.description,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: BafSpacing.md),
        ComplianceProgressRoute(record: record),
      ],
    );
  }
}
