import 'package:flutter/material.dart';
import '../../../core/persistence/durable_submission.dart';

/// A server-fenced refusal is terminal, but its original user-entered text is
/// still recoverable without resending the refused request identity.
class MorningReviewRefusedChangePanel extends StatelessWidget {
  const MorningReviewRefusedChangePanel({super.key, required this.saved});
  final DurableSubmission saved;
  @override
  Widget build(BuildContext context) {
    final request = saved.envelope['request'] as Map?;
    if (request == null) return const SizedBox.shrink();
    final text = <String>[
      for (final field in ['summary', 'reason', 'correctionReason'])
        if (request[field] is String) request[field] as String,
      for (final field in ['entryDraft', 'actionDraft', 'concernDraft'])
        if (request[field] is Map)
          for (final key in ['text', 'title', 'detail'])
            if ((request[field] as Map)[key] is String)
              (request[field] as Map)[key] as String,
    ];
    return ExpansionTile(
      title: const Text('Previous change was not applied; your text is saved'),
      subtitle: const Text(
        'Refresh the meeting, review the latest records, then use the appropriate editor for a new change.',
      ),
      children: [
        SizedBox(
          height: 180,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                text.isEmpty
                    ? 'The original request remains preserved in saved submissions.'
                    : text.join('\n\n'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
