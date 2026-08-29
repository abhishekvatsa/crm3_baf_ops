import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/burner_condition_round.dart';
import '../domain/operations_report_document.dart';
import '../domain/report_provenance.dart';
import '../models/operations_report.dart';
import '../services/operations_report_pdf_service.dart';

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
  backgroundColor: BafColors.card,
  showDragHandle: true,
  builder:
      (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _OperationsReportComposer(
          generatedByName: generatedByName,
          generatedByEmail: generatedByEmail,
          hasFurnaceScope: hasFurnaceScope,
          provenance: provenance,
          initialPreset: initialPreset,
        ),
      ),
);

class OperationsReportPdfPreviewScreen extends StatelessWidget {
  const OperationsReportPdfPreviewScreen({
    super.key,
    required this.report,
    required this.request,
    required this.assetClassLabel,
    required this.assetLabel,
    required this.furnaceAssets,
    required this.currentBurnerRounds,
  });

  final OperationsReport report;
  final OperationsReportDocumentRequest request;
  final String assetClassLabel;
  final String assetLabel;
  final List<AssetInstanceRecord> furnaceAssets;
  final Map<String, BurnerConditionRound> currentBurnerRounds;

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
    body: PdfPreview(
      initialPageFormat: PdfPageFormat.a4.landscape,
      canChangePageFormat: false,
      canChangeOrientation: false,
      allowPrinting: true,
      allowSharing: true,
      pdfFileName: request.fileName,
      build:
          (_) => OperationsReportPdfService.build(
            report: report,
            request: request,
            assetClassLabel: assetClassLabel,
            assetLabel: assetLabel,
            furnaceAssets: furnaceAssets,
            currentBurnerRounds: currentBurnerRounds,
          ),
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
                    final itemWidth =
                        constraints.maxWidth < 620
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
                    onChanged:
                        unavailable
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
    final request = OperationsReportDocumentRequest.forPreset(
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
    color:
        selected ? BafColors.planned.withValues(alpha: 0.08) : BafColors.card,
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
