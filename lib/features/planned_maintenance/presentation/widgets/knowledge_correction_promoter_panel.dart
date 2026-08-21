// FILE: lib/features/planned_maintenance/presentation/widgets/knowledge_correction_promoter_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../auth/data/user_model.dart';
import '../../domain/baf_knowledge_layer.dart';
import '../../domain/knowledge_correction_promoter.dart';
import '../../domain/knowledge_governance_models.dart';
import '../../providers/knowledge_correction_source_provider.dart';
import '../../providers/knowledge_governance_provider.dart';

class KnowledgeCorrectionPromoterPanel extends ConsumerStatefulWidget {
  final AppUser appUser;

  const KnowledgeCorrectionPromoterPanel({super.key, required this.appUser});

  @override
  ConsumerState<KnowledgeCorrectionPromoterPanel> createState() =>
      _KnowledgeCorrectionPromoterPanelState();
}

class _KnowledgeCorrectionPromoterPanelState
    extends ConsumerState<KnowledgeCorrectionPromoterPanel> {
  final Set<String> _promotingKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    final correctionsProvider = knowledgePromotableCorrectionsProvider(
      widget.appUser,
    );
    final correctionsAsync = ref.watch(correctionsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(correctionsProvider);
        await ref.read(correctionsProvider.future);
      },
      child: correctionsAsync.when(
        loading:
            () => const BafLoadingPanel(
              label: 'Loading tag corrections',
              color: BafColors.planned,
            ),
        error:
            (e, _) => ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(BafSpacing.lg),
                  child: Text('Harvest failed:\n$e'),
                ),
              ],
            ),
        data: (corrections) {
          if (corrections.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(BafSpacing.xl),
                  child: Text(
                    'No tag-resolver corrections found in published template versions yet.\n\nCorrections appear here when an Admin/SI uses the Composer to manually map an unrecognised tag during template authoring. Once promoted, the tag becomes a governed knowledge row available to every future composition.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BafColors.textSecondary),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(BafSpacing.md),
            itemBuilder:
                (_, i) => _PromotableCard(
                  correction: corrections[i],
                  isPromoting: _promotingKeys.contains(
                    _promotionKey(corrections[i]),
                  ),
                  onPromote: () => _promote(context, corrections[i]),
                ),
            separatorBuilder: (_, __) => const SizedBox(height: BafSpacing.sm),
            itemCount: corrections.length,
          );
        },
      ),
    );
  }

  Future<void> _promote(
    BuildContext context,
    PromotableTagCorrection correction,
  ) async {
    if (correction.isAlreadyPromoted) {
      return;
    }
    final key = _promotionKey(correction);
    if (_promotingKeys.contains(key)) {
      return;
    }

    final draftPreview = KnowledgeCorrectionPromoter.buildDraft(
      correction,
      defaultMatrixVersion: BafKnowledgeLayer.matrixVersion,
    );

    final reason = await showDialog<String>(
      context: context,
      builder:
          (_) => _PromotionReasonDialog(
            correction: correction,
            draftPreview: draftPreview,
          ),
    );
    if (!mounted || reason == null) {
      return;
    }

    setState(() => _promotingKeys.add(key));
    final controller = ref.read(knowledgeGovernanceControllerProvider);
    try {
      final result = await controller.promoteCorrection(
        correction: correction,
        actor: widget.appUser,
        reason: reason,
      );
      if (!mounted) {
        return;
      }
      ref.invalidate(knowledgePromotableCorrectionsProvider(widget.appUser));
      ref.invalidate(knowledgeRowsViewProvider);
      ref.invalidate(knowledgeGovernanceAuditFeedProvider);
      if (!context.mounted) {
        return;
      }
      _showPromotionSnack(
        context,
        'Promoted to ${result.rowCode} v${result.versionAfter}.',
      );
    } catch (e) {
      if (!mounted || !context.mounted) {
        return;
      }
      _showPromotionSnack(context, 'Promotion failed: $e');
    } finally {
      if (mounted) {
        setState(() => _promotingKeys.remove(key));
      }
    }
  }

  String _promotionKey(PromotableTagCorrection correction) {
    return '${correction.sourceTemplateVersionId}:${correction.normalizedTag}';
  }
}

void _showPromotionSnack(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

class _PromotionReasonDialog extends StatefulWidget {
  final PromotableTagCorrection correction;
  final KnowledgeRowDraft draftPreview;

  const _PromotionReasonDialog({
    required this.correction,
    required this.draftPreview,
  });

  @override
  State<_PromotionReasonDialog> createState() => _PromotionReasonDialogState();
}

class _PromotionReasonDialogState extends State<_PromotionReasonDialog> {
  static const int _minReasonLength = 15;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(
      text:
          'Promote tag ${widget.correction.normalizedTag} from template version ${widget.correction.sourceTemplatePackageCode} v${widget.correction.sourceTemplateVersionNumber}.',
    );
    _reasonController.addListener(_handleReasonChanged);
  }

  void _handleReasonChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _reasonController.removeListener(_handleReasonChanged);
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draftPreview = widget.draftPreview;
    final reason = _reasonController.text.trim();
    final canPromote = reason.length >= _minReasonLength;

    return AlertDialog(
      title: Text('Promote ${widget.correction.normalizedTag}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Row code: ${draftPreview.rowCode}'),
              Text('Module candidate: ${draftPreview.moduleCandidateCode}'),
              if (draftPreview.componentGroup.isNotEmpty)
                Text('Component: ${draftPreview.componentGroup}'),
              if (draftPreview.safetyClasses.isNotEmpty)
                Text('Safety: ${draftPreview.safetyClasses.join(', ')}'),
              const SizedBox(height: BafSpacing.sm),
              const Text(
                'The new row starts at readiness=tagOnly, confidence=inferredNeedsReview, requiredForClosure=consult. Edit it after promotion to mature it.',
                style: TextStyle(fontSize: 12, color: BafColors.textSecondary),
              ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: 'Promotion reason',
                  helperText: 'Minimum $_minReasonLength characters.',
                  errorText:
                      reason.isEmpty || canPromote
                          ? null
                          : 'Enter at least $_minReasonLength characters.',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canPromote ? () => Navigator.pop(context, reason) : null,
          child: const Text('Promote'),
        ),
      ],
    );
  }
}

class _PromotableCard extends StatelessWidget {
  final PromotableTagCorrection correction;
  final bool isPromoting;
  final VoidCallback onPromote;

  const _PromotableCard({
    required this.correction,
    required this.isPromoting,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd');
    final hint = correction.resolverHint;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    correction.normalizedTag.isEmpty
                        ? '(blank tag)'
                        : correction.normalizedTag,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (correction.isAlreadyPromoted)
                  const StatusBadge(
                    label: 'already promoted',
                    color: BafColors.textSecondary,
                  )
                else
                  StatusBadge(
                    label: correction.correctionStatus,
                    color: BafColors.audit,
                  ),
              ],
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              correction.resolvedComponent.isNotEmpty
                  ? correction.resolvedComponent
                  : 'No component name supplied',
              style: const TextStyle(color: BafColors.textPrimary),
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              'From ${correction.sourceTemplatePackageCode} v${correction.sourceTemplateVersionNumber} · ${formatter.format(correction.harvestedAt.toLocal())}',
              style: const TextStyle(
                fontSize: 12,
                color: BafColors.textSecondary,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: BafSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (hint.assetType != null)
                    StatusBadge(
                      label: hint.assetType!.name,
                      color: BafColors.assets,
                    ),
                  if (hint.discipline != null)
                    StatusBadge(
                      label: hint.discipline!.name,
                      color: BafColors.planned,
                    ),
                  for (final cls in hint.safetyClasses.take(3))
                    StatusBadge(label: cls, color: BafColors.warning),
                  StatusBadge(
                    label: 'resolver: ${hint.resolutionSource}',
                    color: BafColors.audit,
                  ),
                ],
              ),
            ],
            if (correction.alreadyPromotedTo != null) ...[
              const SizedBox(height: BafSpacing.xs),
              Text(
                'Live row: ${correction.alreadyPromotedTo!.rowCode} (v${correction.alreadyPromotedTo!.version}, ${correction.alreadyPromotedTo!.lifecycleStatus})',
                style: const TextStyle(
                  fontSize: 12,
                  color: BafColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: BafSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    correction.isAlreadyPromoted || isPromoting
                        ? null
                        : onPromote,
                icon:
                    isPromoting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.upgrade_rounded),
                label: Text(isPromoting ? 'Promoting…' : 'Promote'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
