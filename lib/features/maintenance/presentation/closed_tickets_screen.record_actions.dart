part of 'closed_tickets_screen.dart';

class _ClosedTicketRecordActions extends StatelessWidget {
  const _ClosedTicketRecordActions({
    required this.onViewDetails,
    required this.canCorrect,
    required this.isCorrecting,
    required this.onCorrect,
  });

  final VoidCallback onViewDetails;
  final bool canCorrect;
  final bool isCorrecting;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: BafSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onViewDetails,
            icon: const Icon(Icons.article_outlined),
            label: const Text('View complete issue record'),
          ),
        ),
        if (canCorrect) ...[
          const SizedBox(height: BafSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isCorrecting ? null : onCorrect,
              style: OutlinedButton.styleFrom(
                foregroundColor: BafColors.warning,
              ),
              icon:
                  isCorrecting
                      ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.edit_note_rounded),
              label: Text(
                isCorrecting
                    ? 'Recording correction...'
                    : 'Correct audited record',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: BafColors.textSecondary),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
