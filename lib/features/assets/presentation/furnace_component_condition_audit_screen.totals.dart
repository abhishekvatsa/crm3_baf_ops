part of 'furnace_component_condition_audit_screen.dart';

class _FurnaceAuditTotals {
  _FurnaceAuditTotals(Iterable<_FurnaceAuditDraft> drafts)
    : rows = List.unmodifiable(drafts);

  final List<_FurnaceAuditDraft> rows;

  int get redHotBlocks =>
      rows.fold(0, (total, row) => total + row.redHotPositions.length);
  int get redHotFurnaces =>
      rows.where((row) => row.redHotPositions.isNotEmpty).length;
  int get draftSealRedHot =>
      rows.where((row) => row.draftSealRedHotObserved).length;
  int get draftSealHotAir =>
      rows.where((row) => row.hotAirAtDraftSealObserved).length;
  int get draftSealFindings => draftSealRedHot + draftSealHotAir;
  int get affectedFurnaces =>
      rows
          .where(
            (row) =>
                row.redHotPositions.isNotEmpty ||
                row.draftSealRedHotObserved ||
                row.hotAirAtDraftSealObserved ||
                row.uvByPosition.values.any(
                  (value) => value != BurnerUvCondition.serviceable,
                ),
          )
          .length;
  int get withoutEvidence => rows.where((row) => row.sourceAt == null).length;
  int get dirtyCount => rows.where((row) => row.dirty).length;
  int uvCount(BurnerUvCondition condition) => rows.fold(
    0,
    (total, row) =>
        total +
        row.uvByPosition.values.where((value) => value == condition).length,
  );
  int uvFurnaces(BurnerUvCondition condition) =>
      rows.where((row) => row.uvByPosition.values.contains(condition)).length;

  String get status =>
      dirtyCount == 0
          ? 'Recorded condition findings'
          : 'Draft totals - includes unsaved changes on $dirtyCount furnace${dirtyCount == 1 ? '' : 's'}';

  List<({String label, int findings, int furnaces})> get categories => [
    (
      label: 'Red-hot burner blocks',
      findings: redHotBlocks,
      furnaces: redHotFurnaces,
    ),
    (
      label: 'Draft seal red hot',
      findings: draftSealRedHot,
      furnaces: draftSealRedHot,
    ),
    (
      label: 'Draft seal hot air',
      findings: draftSealHotAir,
      furnaces: draftSealHotAir,
    ),
    for (final condition in [
      BurnerUvCondition.melted,
      BurnerUvCondition.missing,
      BurnerUvCondition.hanging,
    ])
      (
        label: 'UV ${condition.label.toLowerCase()}',
        findings: uvCount(condition),
        furnaces: uvFurnaces(condition),
      ),
  ];

  String copyText(DateTime capturedAt) => [
    'CRM-III BAF Ops - Furnace condition totals',
    'Captured: ${DateFormat('dd MMM yyyy, HH:mm').format(capturedAt)}',
    status,
    '${rows.length} registered furnaces in scope; $affectedFurnaces with marked faults.',
    '$withoutEvidence furnaces without prior condition evidence.',
    for (final category in categories)
      '${category.label}: ${category.findings} finding${category.findings == 1 ? '' : 's'} on ${category.furnaces} furnace${category.furnaces == 1 ? '' : 's'}.',
    'Counts are marked findings, not a declaration that unmarked positions are healthy.',
  ].join('\n');
}

Future<void> _showConditionTotals(
  BuildContext context,
  _FurnaceAuditTotals totals,
) => showDialog<void>(
  context: context,
  builder:
      (dialogContext) => AlertDialog(
        title: const Text('Condition totals'),
        titleTextStyle: Theme.of(dialogContext).textTheme.titleLarge,
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                totals.status,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: BafSpacing.sm),
              Text(
                '${totals.rows.length} Furnaces / ${totals.affectedFurnaces} with marked faults',
              ),
              Text(
                '${totals.withoutEvidence} without prior condition evidence',
              ),
              const SizedBox(height: BafSpacing.md),
              for (final category in totals.categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                  child: Builder(
                    builder: (context) {
                      final compact =
                          MediaQuery.sizeOf(context).width < 520 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3;
                      final value = Text(
                        '${category.findings} finding${category.findings == 1 ? '' : 's'} / ${category.furnaces} furnace${category.furnaces == 1 ? '' : 's'}',
                        textAlign: compact ? TextAlign.start : TextAlign.end,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [Text(category.label), value],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(category.label)),
                          const SizedBox(width: BafSpacing.sm),
                          Flexible(child: value),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          IconButton(
            tooltip: 'Copy condition totals',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await Clipboard.setData(
                  ClipboardData(text: totals.copyText(DateTime.now())),
                );
                if (!context.mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Condition totals copied.')),
                );
              } catch (_) {
                if (!context.mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not copy condition totals.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
);
