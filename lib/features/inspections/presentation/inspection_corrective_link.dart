part of 'inspection_programmes_screen.dart';

bool _inspectionFindingIsTerminal(InspectionFinding finding) => const {
  InspectionFindingStatus.verifiedResolved,
  InspectionFindingStatus.acceptedCondition,
  InspectionFindingStatus.invalidated,
}.contains(finding.status);

Future<void> _linkIssue(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  InspectionObservation observation, {
  InspectionFinding? finding,
}) async {
  final actor = ref.read(currentAppUserProvider).value;
  if (actor == null) return;
  final ticketId = await showDialog<String>(
    context: context,
    builder: (_) => const _LinkInspectionIssueDialog(),
  );
  if (ticketId == null || ticketId.isEmpty || !context.mounted) return;
  try {
    final ticket = await ref
        .read(inspectionRepositoryProvider)
        .readCorrectiveTicket(ticketId);
    if (!context.mounted ||
        ref.read(currentAppUserProvider).value?.uid != actor.uid) {
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _InspectionReasonDialog(
        title: 'Review repair coverage',
        message:
            'Inspection: ${observation.rowLabel} · ${observation.componentName ?? "Asset"} · ${observation.physicalPosition ?? "No position specified"}\n\n'
            'Maintenance: ${ticket['assetType']} ${ticket['assetNumber']} · ${ticket['component']}\n${ticket['description']}\n\n'
            'Explain how this work covers this inspected component and position. Linking work does not verify that the finding is resolved.',
        actionLabel: 'Confirm repair coverage',
      ),
    );
    if (reason == null || !context.mounted) return;
    await _runInspectionCommand(
      context,
      ref,
      WorkflowCommand(
        commandId: 'linkInspectionObservationIssue_${const Uuid().v4()}',
        type: WorkflowCommandType.linkInspectionObservationIssue,
        aggregateId: campaign.id,
        expectedVersion: campaign.version,
        payload: {
          'observationId': observation.id,
          'ticketId': ticketId,
          'reason': reason,
          if (finding != null) 'expectedFindingVersion': finding.version,
          if (actor.canSuperviseInspectionObservations)
            'scopeReview': {
              'expectedTicketVersion': ticket['version'],
              'reason': reason,
            },
        },
      ),
      'Corrective work linked with its reviewed scope.',
      originUid: actor.uid,
    );
  } on Object catch (error) {
    if (context.mounted &&
        ref.read(currentAppUserProvider).value?.uid == actor.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Repair could not be reviewed: $error')),
      );
    }
  }
}
