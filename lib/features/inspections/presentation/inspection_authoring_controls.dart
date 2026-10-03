part of 'inspection_programmes_screen.dart';

/// Failed availability never clears a form or creates a replacement request.
Future<bool> _requireNewInspectionV2Authoring(
  BuildContext context,
  WidgetRef ref,
) async {
  final access = CurrentActorAccess.resolve(ref.read(currentAppUserProvider));
  if (!access.isReady) {
    _showEditorError(context, access.message);
    return false;
  }
  try {
    await ref.read(inspectionV2AuthoringCapabilityProvider)(access.actor!.uid);
    return context.mounted;
  } catch (error) {
    if (context.mounted) {
      ref.invalidate(inspectionV2AuthoringAvailabilityProvider);
      _showEditorError(context, error.toString());
    }
    return false;
  }
}

class _InspectionAuthoringNotice extends ConsumerWidget {
  const _InspectionAuthoringNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        inspectionV2AuthoringStatusMessage(
          ref.watch(inspectionV2AuthoringAvailabilityProvider),
        ),
      ),
      TextButton.icon(
        onPressed: () =>
            ref.invalidate(inspectionV2AuthoringAvailabilityProvider),
        icon: const Icon(Icons.refresh),
        label: const Text('Check availability'),
      ),
    ],
  );
}
