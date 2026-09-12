import 'package:flutter/material.dart';

import '../../../core/persistence/durable_submission.dart';
import '../../../core/theme/baf_design_system.dart';
import '../services/morning_review_command_service.dart';

class SavedMorningReviewChangePanel extends StatelessWidget {
  const SavedMorningReviewChangePanel({
    super.key,
    required this.saved,
    required this.error,
    required this.busy,
    required this.onCheck,
    this.onCancelNeverSent,
  });
  final DurableSubmission? saved;
  final String? error;
  final bool busy;
  final VoidCallback onCheck;
  final VoidCallback? onCancelNeverSent;

  @override
  Widget build(BuildContext context) {
    final row = saved;
    final legacy =
        row?.isLegacy == true ||
        row?.state == DurableSubmissionState.needsReview;
    final request = row == null || legacy
        ? null
        : row.envelope['request'] as Map<String, dynamic>;
    final operation = request == null
        ? null
        : MorningReviewCommand.values
              .where((item) => item.wireName == request['operation'])
              .firstOrNull;
    final label = switch (operation) {
      MorningReviewCommand.start => 'Open Morning Review',
      MorningReviewCommand.join => 'Record attendance',
      MorningReviewCommand.addEntry => 'Meeting contribution',
      MorningReviewCommand.createAction => 'Create owned action',
      MorningReviewCommand.acceptAction => 'Accept action',
      MorningReviewCommand.completeAction => 'Complete action',
      MorningReviewCommand.takeOver => 'Take over facilitation',
      MorningReviewCommand.finalize => 'Finalize meeting',
      MorningReviewCommand.recordNotHeld => 'Record review not held',
      MorningReviewCommand.createStandingConcern => 'Create standing concern',
      MorningReviewCommand.resolveStandingConcern => 'Resolve standing concern',
      MorningReviewCommand.checkStandingConcern => 'Standing concern check',
      MorningReviewCommand.addAddendum => 'Meeting addendum',
      null => 'Saved Morning Review change',
    };
    final details = <String>[
      if (request?['sessionId'] != null) 'Meeting: ${request!['sessionId']}',
      for (final key in const ['entryDraft', 'actionDraft', 'concernDraft'])
        if (request?[key] is Map)
          for (final field in const [
            'title',
            'text',
            'detail',
            'assetClassName',
            'assetNumber',
          ])
            if ((request![key] as Map)[field] is String &&
                ((request[key] as Map)[field] as String).isNotEmpty)
              (request[key] as Map)[field] as String,
      for (final key in const ['reason', 'summary'])
        if (request?[key] is String) request![key] as String,
    ];
    return Card(
      margin: const EdgeInsets.all(BafSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            Text(
              legacy
                  ? 'Older saved evidence needs review. It will not be sent automatically.'
                  : row?.state.isAccepted == true
                  ? 'The server accepted this change. Check its record; acceptance will not be sent again.'
                  : 'Your original entries are saved. Check this change before starting another.',
            ),
            if (details.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: SelectableText(details.join('\n')),
                ),
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: BafColors.danger)),
            if (!legacy &&
                row?.state == DurableSubmissionState.intent &&
                row?.attemptCount == 0)
              TextButton(
                onPressed: busy ? null : onCancelNeverSent,
                child: const Text('Cancel unsent change'),
              ),
            if (!legacy)
              TextButton.icon(
                onPressed: busy ? null : onCheck,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(busy ? 'Checking…' : 'Check saved change'),
              ),
          ],
        ),
      ),
    );
  }
}
