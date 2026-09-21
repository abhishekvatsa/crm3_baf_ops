import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../domain/knowledge_import_journal.dart';
import '../../providers/knowledge_governance_provider.dart';
import '../../repositories/knowledge_import_journal_repository.dart';

/// Local import evidence stays visible even while the live catalogue is offline.
class KnowledgeImportRecoveryPanel extends ConsumerStatefulWidget {
  const KnowledgeImportRecoveryPanel({super.key});

  @override
  ConsumerState<KnowledgeImportRecoveryPanel> createState() =>
      _KnowledgeImportRecoveryPanelState();
}

class _KnowledgeImportRecoveryPanelState
    extends ConsumerState<KnowledgeImportRecoveryPanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(currentAppUserProvider).valueOrNull;
    final state = ref.watch(knowledgeImportRecoveryProvider);
    return state.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.warning_amber_rounded),
        title: const Text('Saved import evidence needs attention'),
        subtitle: Text('$error\nThe saved evidence has been retained.'),
        trailing: IconButton(
          onPressed: () => ref.invalidate(knowledgeImportRecoveryProvider),
          icon: const Icon(Icons.refresh),
          tooltip: 'Read saved imports again',
        ),
      ),
      data: (imports) {
        if (imports.isEmpty) {
          return const SizedBox.shrink();
        }
        final pending = imports.where((value) => value.needsRecovery).length;
        return ExpansionTile(
          key: const PageStorageKey('knowledge-import-recovery'),
          title: Text('Saved imports: $pending need review'),
          subtitle: const Text(
            'Each row has its own outcome. These records remain on this device.',
          ),
          children: [
            SizedBox(
              height: 220,
              child: ListView(
                key: const PageStorageKey('knowledge-import-recovery-scroll'),
                children: [
                  for (final saved in imports.reversed)
                    ExpansionTile(
                      key: PageStorageKey(
                        'knowledge-import-${saved.intent.requestId}',
                      ),
                      title: Text(
                        '${saved.intent.rows.length} rows · ${saved.intent.actorName}',
                      ),
                      subtitle: Text(
                        saved.needsRecovery
                            ? 'Interrupted or awaiting local adoption'
                            : 'All row outcomes recorded',
                      ),
                      children: [
                        for (final row in saved.intent.rows)
                          ListTile(
                            dense: true,
                            title: Text(
                              '${row.rowCode} · v${row.versionAfter}',
                            ),
                            subtitle: Text(
                              _outcomeLabel(saved.outcomes[row.rowCode]),
                            ),
                          ),
                        if (saved.needsRecovery)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child:
                                actor?.uid == saved.intent.actorUid &&
                                    canManageKnowledgeBase(actor)
                                ? FilledButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _resume(saved),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Resume saved import'),
                                  )
                                : Text(
                                    'Sign in as ${saved.intent.actorName} (${saved.intent.actorUid}) to resume.',
                                  ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _outcomeLabel(KnowledgeImportOutcome? outcome) {
    if (outcome == null) {
      return 'Not confirmed. Original reviewed content is saved.';
    }
    return switch (outcome.state) {
      KnowledgeImportOutcomeState.pending =>
        'Not confirmed. ${outcome.message}',
      KnowledgeImportOutcomeState.rejected => 'Rejected. ${outcome.message}',
      KnowledgeImportOutcomeState.accepted =>
        outcome.adopted
            ? 'Accepted and verified on this device.'
            : 'Accepted; local adoption needs review. Newer local drafts are retained.',
    };
  }

  Future<void> _resume(KnowledgeImportRecovery saved) async {
    final actor = ref.read(currentAppUserProvider).valueOrNull;
    if (actor == null ||
        actor.uid != saved.intent.actorUid ||
        !canManageKnowledgeBase(actor)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(knowledgeGovernanceControllerProvider)
          .resumeImport(importId: saved.intent.requestId, actor: actor);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      ref.invalidate(knowledgeImportRecoveryProvider);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
