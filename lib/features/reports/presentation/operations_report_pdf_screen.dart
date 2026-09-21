import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/burner_condition_round.dart';
import '../../assets/providers/burner_condition_round_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/operations_report_provider.dart';
import '../domain/operations_report_asset_inventory.dart';
import '../domain/operations_report_document.dart';
import '../domain/report_provenance.dart';
import '../models/operations_report.dart';
import '../services/operations_report_pdf_service.dart';
import 'zoomable_pdf_preview.dart';

Future<OperationsReportDocumentRequest?> showOperationsReportComposer({
  required BuildContext context,
  required String generatedByName,
  required String generatedByEmail,
  required bool hasFurnaceScope,
  required ReportProvenance provenance,
  OperationsReportDocumentPreset initialPreset =
      OperationsReportDocumentPreset.executive,
}) => showModalBottomSheet<OperationsReportDocumentRequest>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: BafColors.card,
  showDragHandle: true,
  builder: (context) => AnimatedPadding(
    duration: BafMotion.quick,
    curve: Curves.easeOutCubic,
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: 0.92,
      child: _OperationsReportComposer(
        generatedByName: generatedByName,
        generatedByEmail: generatedByEmail,
        hasFurnaceScope: hasFurnaceScope,
        provenance: provenance,
        initialPreset: initialPreset,
      ),
    ),
  ),
);

/// Watches only the families required by the selected report, even when the
/// integrated dashboard cannot load an unrelated family. Authority is rechecked
/// by the actor-scoped provider throughout preparation and preview.
class OperationsReportPreparationScreen extends ConsumerStatefulWidget {
  const OperationsReportPreparationScreen({
    super.key,
    required this.actorUid,
    required this.filter,
    required this.request,
  });

  final String actorUid;
  final OperationsReportFilter filter;
  final OperationsReportDocumentRequest request;

  @override
  ConsumerState<OperationsReportPreparationScreen> createState() =>
      _OperationsReportPreparationState();
}

class _OperationsReportPreparationState
    extends ConsumerState<OperationsReportPreparationScreen> {
  OperationsReportPdfPreviewScreen? _prepared;
  Future<Uint8List>? _preparedBytes;
  bool _accessLost = false;

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(currentAppUserProvider);
    if (actor.asData != null &&
        (actor.value?.uid != widget.actorUid ||
            actor.value?.canViewReports != true)) {
      _accessLost = true;
    }
    if (_accessLost ||
        actor.isLoading ||
        actor.hasError ||
        actor.value?.uid != widget.actorUid ||
        actor.value?.canViewReports != true) {
      return BafScreenStateScaffold(
        appBarTitle: 'Prepare report',
        appBarSubtitle: 'Checking access to the selected information',
        appBarIcon: Icons.picture_as_pdf_outlined,
        accent: BafColors.maintenance,
        state: actor.isLoading
            ? const BafLoadingPanel(label: 'Checking report access')
            : const BafStatePanel(
                icon: Icons.lock_outline_rounded,
                color: BafColors.danger,
                title: 'Report access required',
                message:
                    'Close this preview and create a new report after signing in with approved report access.',
              ),
      );
    }
    // A document identity always refers to the initially prepared bytes.
    // New live emissions require creating a new report, not changing this one.
    if (_prepared != null) return _prepared!;
    final source = ref.watch(
      operationsReportProvider((
        actorUid: widget.actorUid,
        filter: widget.filter,
      )),
    );
    final sourceReport = source.asData?.value;
    final furnaceAssets = sourceReport == null
        ? <AssetInstanceRecord>[]
        : furnaceAssetsForOperationsReport(
            assetClasses: sourceReport.sourceAssetClasses,
            assets: sourceReport.sourceAssetInstances,
            selectedAssetClassId: widget.filter.assetClassId,
            selectedAssetInstanceId: widget.filter.assetInstanceId,
          );
    final needsBurner =
        widget.request.sections.contains(
          OperationsReportSection.burnerUvCondition,
        ) &&
        furnaceAssets.isNotEmpty;
    final rounds =
        needsBurner && source.hasValue && !source.hasError && !source.isLoading
        ? ref.watch(
            latestBurnerConditionRoundsProvider(
              LatestBurnerConditionRoundsQuery(
                actorUid: widget.actorUid,
                assetInstanceIds: furnaceAssets.map((asset) => asset.id),
              ),
            ),
          )
        : const AsyncData<Map<String, BurnerConditionRound>>({});
    if (source.hasError || rounds.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Prepare report',
        appBarSubtitle: 'The selected information needs attention',
        appBarIcon: Icons.picture_as_pdf_outlined,
        accent: BafColors.maintenance,
        title: 'Report could not be prepared',
        message: '${source.error ?? rounds.error}',
      );
    }
    if (source.isLoading || rounds.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Prepare report',
        appBarSubtitle: 'Verifying the selected information',
        appBarIcon: Icons.picture_as_pdf_outlined,
        accent: BafColors.maintenance,
        label: 'Preparing selected report sections',
      );
    }
    final report = source.requireValue;
    final assetClassLabel = _preparedClassLabel(report);
    final assetLabel = _preparedAssetLabel(report);
    // Authority placeholders dispose the preview subtree. Keep its single PDF
    // future here so the same document identity still means the same bytes when
    // this account's temporary access check completes.
    _preparedBytes = OperationsReportPdfService.build(
      report: report,
      request: widget.request,
      assetClassLabel: assetClassLabel,
      assetLabel: assetLabel,
      furnaceAssets: List.unmodifiable(furnaceAssets),
      currentBurnerRounds: Map.fromEntries(
        rounds.requireValue.entries.where(
          (entry) => !entry.value.observedAt.isAfter(report.asOf),
        ),
      ),
    );
    _prepared = OperationsReportPdfPreviewScreen(
      bytes: _preparedBytes!,
      request: widget.request,
      assetClassLabel: assetClassLabel,
      assetLabel: assetLabel,
    );
    return _prepared!;
  }
}

String _preparedClassLabel(OperationsReport report) {
  final id = report.filter.assetClassId;
  if (id == null) return 'All asset classes';
  return report.sourceAssetClasses
          .where((value) => value.id == id)
          .firstOrNull
          ?.name ??
      'Selected asset class';
}

String _preparedAssetLabel(OperationsReport report) {
  final id = report.filter.assetInstanceId;
  if (id == null) return 'All assets in scope';
  if (report.filter.subjectKind == OperationsReportSubjectKind.innerCover) {
    final cover = report.innerCoverProfiles
        .where((value) => value.id == id)
        .firstOrNull;
    return cover == null
        ? 'Selected serial cover'
        : 'Inner Cover ${cover.serialNumber}';
  }
  return report.sourceAssetInstances
          .where((value) => value.id == id)
          .firstOrNull
          ?.name ??
      'Selected asset';
}

class OperationsReportPdfPreviewScreen extends StatelessWidget {
  const OperationsReportPdfPreviewScreen({
    super.key,
    required this.bytes,
    required this.request,
    required this.assetClassLabel,
    required this.assetLabel,
  });

  final Future<Uint8List> bytes;
  final OperationsReportDocumentRequest request;
  final String assetClassLabel;
  final String assetLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BafColors.background,
    appBar: AppBar(
      title: const BafAppBarTitle(
        title: 'PDF report preview',
        subtitle: 'Review, share, save or print the generated document',
        icon: Icons.picture_as_pdf_outlined,
        accent: BafColors.maintenance,
      ),
    ),
    body: ZoomablePdfPreview(
      pageFormat: PdfPageFormat.a4.landscape,
      fileName: request.fileName,
      documentKind: 'Operations report (${request.preset.label})',
      documentSubject: assetLabel.trim().isEmpty
          ? assetClassLabel
          : '$assetClassLabel / $assetLabel',
      documentBuilder: (_) => bytes,
    ),
  );
}

class _OperationsReportComposer extends StatefulWidget {
  const _OperationsReportComposer({
    required this.generatedByName,
    required this.generatedByEmail,
    required this.hasFurnaceScope,
    required this.provenance,
    required this.initialPreset,
  });

  final String generatedByName;
  final String generatedByEmail;
  final bool hasFurnaceScope;
  final ReportProvenance provenance;
  final OperationsReportDocumentPreset initialPreset;

  @override
  State<_OperationsReportComposer> createState() =>
      _OperationsReportComposerState();
}

class _OperationsReportComposerState extends State<_OperationsReportComposer> {
  late OperationsReportDocumentPreset _preset;
  late Set<OperationsReportSection> _sections;
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _preset = widget.initialPreset;
    _sections = operationsReportSectionsForPreset(_preset);
    if (!widget.hasFurnaceScope) {
      _sections.remove(OperationsReportSection.burnerUvCondition);
    }
    _titleController = TextEditingController(text: _preset.label);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: BafColors.maintenance.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: BafColors.maintenance,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Report library',
                        style: TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choose a management question, then refine its evidence if needed.',
                        style: TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: <Widget>[
                Text('Report purpose', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth < 620
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: OperationsReportDocumentPreset.values
                          .where(
                            (preset) =>
                                preset != OperationsReportDocumentPreset.custom,
                          )
                          .map(
                            (preset) => SizedBox(
                              width: itemWidth,
                              child: _ReportPurposeTile(
                                preset: preset,
                                selected: _preset == preset,
                                onTap: () => _selectPreset(preset),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Document title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Included sections', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                ...operationsReportSectionOrder.map((section) {
                  final unavailable =
                      section == OperationsReportSection.burnerUvCondition &&
                      !widget.hasFurnaceScope;
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _sections.contains(section) && !unavailable,
                    onChanged: unavailable
                        ? null
                        : (selected) =>
                              _toggleSection(section, selected == true),
                    title: Text(section.label),
                    subtitle: Text(
                      unavailable
                          ? 'No active Furnace asset is present in this scope.'
                          : section.description,
                    ),
                  );
                }),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BafColors.teal.withValues(alpha: 0.07),
                    border: Border.all(
                      color: BafColors.teal.withValues(alpha: 0.25),
                    ),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 20,
                        color: BafColors.teal,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.provenance.evidenceStatement,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: BafColors.card,
              border: Border(top: BorderSide(color: BafColors.border)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cancelButton = TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                );
                final previewButton = FilledButton.icon(
                  onPressed: _sections.isEmpty ? null : _submit,
                  icon: const Icon(Icons.preview_outlined),
                  label: const Text('Build preview'),
                );
                if (constraints.maxWidth < 360) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      previewButton,
                      const SizedBox(height: 4),
                      cancelButton,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    cancelButton,
                    const Spacer(),
                    previewButton,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectPreset(OperationsReportDocumentPreset preset) {
    setState(() {
      _preset = preset;
      _sections = operationsReportSectionsForPreset(preset);
      if (!widget.hasFurnaceScope) {
        _sections.remove(OperationsReportSection.burnerUvCondition);
      }
      _titleController.text = preset.label;
    });
  }

  void _toggleSection(OperationsReportSection section, bool selected) {
    setState(() {
      _preset = OperationsReportDocumentPreset.custom;
      if (selected) {
        _sections.add(section);
      } else {
        _sections.remove(section);
      }
      if (_titleController.text.trim().isEmpty ||
          OperationsReportDocumentPreset.values
              .where(
                (preset) => preset != OperationsReportDocumentPreset.custom,
              )
              .any((preset) => _titleController.text == preset.label)) {
        _titleController.text = 'Custom operations report';
      }
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    final request =
        OperationsReportDocumentRequest.forPreset(
          preset: _preset,
          generatedAt: DateTime.now(),
          generatedByName: widget.generatedByName,
          generatedByEmail: widget.generatedByEmail,
          provenance: widget.provenance,
        ).copyWith(
          title: title.isEmpty ? _preset.label : title,
          sections: _sections,
        );
    Navigator.of(context).pop(request);
  }
}

class _ReportPurposeTile extends StatelessWidget {
  const _ReportPurposeTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final OperationsReportDocumentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? BafColors.planned.withValues(alpha: 0.08)
        : BafColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      side: BorderSide(
        color: selected ? BafColors.planned : BafColors.border,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: BafColors.planned.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BafRadius.medium),
              ),
              child: Icon(
                _presetIcon(preset),
                color: BafColors.planned,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    preset.label,
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preset.description,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? BafColors.planned : BafColors.textTertiary,
            ),
          ],
        ),
      ),
    ),
  );
}

IconData _presetIcon(OperationsReportDocumentPreset preset) => switch (preset) {
  OperationsReportDocumentPreset.executive => Icons.space_dashboard_outlined,
  OperationsReportDocumentPreset.assetCondition =>
    Icons.precision_manufacturing_outlined,
  OperationsReportDocumentPreset.maintenance => Icons.build_circle_outlined,
  OperationsReportDocumentPreset.reliability => Icons.monitor_heart_outlined,
  OperationsReportDocumentPreset.quality => Icons.fact_check_outlined,
  OperationsReportDocumentPreset.safetyAndDisruption =>
    Icons.crisis_alert_outlined,
  OperationsReportDocumentPreset.assurance => Icons.verified_user_outlined,
  OperationsReportDocumentPreset.complete => Icons.menu_book_outlined,
  OperationsReportDocumentPreset.custom => Icons.tune_rounded,
};
