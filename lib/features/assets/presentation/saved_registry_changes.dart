import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/persistence/durable_submission.dart';
import '../providers/asset_hierarchy_provider.dart';

class SavedRegistryChanges extends ConsumerStatefulWidget {
  const SavedRegistryChanges({super.key});
  @override
  ConsumerState<SavedRegistryChanges> createState() =>
      _SavedRegistryChangesState();
}

class _SavedRegistryChangesState extends ConsumerState<SavedRegistryChanges> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => ref
      .watch(savedRegistryChangesProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const ListTile(
          title: Text('Saved register changes could not be opened.'),
          subtitle: Text(
            'Register changes require saved recovery storage. Restart the app before sending a change.',
          ),
        ),
        data: (rows) => rows.isEmpty
            ? const SizedBox.shrink()
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: rows.map((row) {
                    final request = row.envelope['request'] as Map;
                    final refused =
                        row.state == DurableSubmissionState.rejected;
                    final details = <String>[
                      '${request['operation']}'.toLowerCase().replaceAll(
                        '_',
                        ' ',
                      ),
                      if (request['reason'] is String)
                        request['reason'] as String,
                      for (final key in [
                        'classDraft',
                        'nodeDraft',
                        'assetDraft',
                        'componentDraft',
                      ])
                        if (request[key] is Map)
                          for (final entry in (request[key] as Map).entries)
                            if (entry.value != null)
                              '${entry.key}: ${entry.value}',
                    ];
                    return ExpansionTile(
                      title: Text(
                        refused
                            ? 'Register change refused — details retained'
                            : 'A register change needs confirmation',
                      ),
                      subtitle: Text(
                        row.lastErrorMessage ??
                            'Check this saved change before starting another.',
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(details.join('\n')),
                        ),
                        if (!refused)
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Check saved change'),
                            onPressed: busy ? null : () => _check(row),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
      );

  Future<void> _check(DurableSubmission row) async {
    setState(() => busy = true);
    try {
      await ref
          .read(assetRegistrySubmissionControllerProvider)
          .check(row.submissionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The original register change was accepted. The register will show its current state.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
