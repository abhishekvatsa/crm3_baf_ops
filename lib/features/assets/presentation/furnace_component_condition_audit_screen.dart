import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_registry_model.dart';
import '../data/burner_condition_round.dart';
import '../providers/asset_hierarchy_provider.dart';
import '../providers/burner_condition_round_provider.dart';
import '../services/burner_condition_round_service.dart';

class FurnaceComponentConditionAuditScreen extends ConsumerStatefulWidget {
  const FurnaceComponentConditionAuditScreen({super.key});

  @override
  ConsumerState<FurnaceComponentConditionAuditScreen> createState() =>
      _FurnaceComponentConditionAuditScreenState();
}

class _FurnaceComponentConditionAuditScreenState
    extends ConsumerState<FurnaceComponentConditionAuditScreen> {
  final Map<String, _FurnaceAuditDraft> _drafts = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Furnace condition audit',
        appBarSubtitle: 'Verifying governed access',
        appBarIcon: Icons.grid_on_rounded,
        accent: BafColors.maintenance,
        label: 'Checking audit access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Furnace condition audit',
        appBarSubtitle: 'Verifying governed access',
        appBarIcon: Icons.grid_on_rounded,
        accent: BafColors.maintenance,
        message: 'Furnace audit access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canRecordBurnerConditionRound) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Furnace condition audit',
        appBarSubtitle: 'Burner blocks, draft seals and UV condition',
        appBarIcon: Icons.grid_on_rounded,
        accent: BafColors.maintenance,
        title: 'Audit access required',
        message: 'Approved Operations or I&A access is required.',
      );
    }

    final classesAsync = ref.watch(assetClassesProvider);
    final assetsAsync = ref.watch(allAssetInstancesProvider);
    final latestAsync = ref.watch(
      latestBurnerConditionRoundsProvider(actor.uid),
    );
    final ticketsAsync = ref.watch(openTicketsProvider);
    final loading = <AsyncValue<Object?>>[
      classesAsync,
      assetsAsync,
      latestAsync,
      ticketsAsync,
    ].any((value) => value.isLoading && !value.hasValue);
    final error =
        <AsyncValue<Object?>>[
          classesAsync,
          assetsAsync,
          latestAsync,
          ticketsAsync,
        ].where((value) => value.hasError && !value.hasValue).firstOrNull;
    if (loading) {
      return _shell(
        const BafLoadingPanel(label: 'Loading furnace condition authority'),
      );
    }
    if (error != null) {
      return _shell(
        BafStatePanel.error(
          message: 'The complete furnace condition view could not be verified.',
          onPrimary: () {
            ref.invalidate(assetClassesProvider);
            ref.invalidate(allAssetInstancesProvider);
            ref.invalidate(latestBurnerConditionRoundsProvider(actor.uid));
            ref.invalidate(openTicketsProvider);
          },
        ),
      );
    }

    final classes = classesAsync.value ?? const <AssetClassRecord>[];
    final furnaceClasses = classes
        .where(
          (item) =>
              item.isActive &&
              item.legacyAssetTypeKey == AssetType.furnace.name,
        )
        .toList(growable: false);
    if (furnaceClasses.length != 1) {
      return _shell(
        const Center(
          child: Text('Exactly one active Furnace class is required.'),
        ),
      );
    }
    final furnaceClass = furnaceClasses.single;
    final furnaces =
        (assetsAsync.value ?? const <AssetInstanceRecord>[])
            .where(
              (asset) =>
                  asset.assetClassId == furnaceClass.id &&
                  asset.isActive &&
                  asset.assetNumber >= 1 &&
                  asset.assetNumber <= 26,
            )
            .toList()
          ..sort(
            (left, right) => left.assetNumber.compareTo(right.assetNumber),
          );
    final latest = latestAsync.value ?? const <String, BurnerConditionRound>{};
    final tickets = ticketsAsync.value ?? const <MaintenanceRecord>[];

    try {
      for (final furnace in furnaces) {
        final round = latest[furnace.id];
        final newerRedHot = _newerOpenIssueRedHotPositions(
          tickets: tickets,
          furnaceNumber: furnace.assetNumber,
          after: round?.observedAt,
        );
        final sourceKey = <String>[
          round?.roundId ?? 'none',
          newerRedHot.join(','),
        ].join('|');
        final current = _drafts[furnace.id];
        if (current == null ||
            (!current.dirty && current.sourceKey != sourceKey)) {
          _drafts[furnace.id] = _FurnaceAuditDraft.fromSources(
            round: round,
            newerRedHotPositions: newerRedHot,
            sourceKey: sourceKey,
          );
        }
      }
    } on FormatException catch (formatError) {
      return _shell(
        BafStatePanel.error(
          message:
              'Burner-lockout evidence needs repair: ${formatError.message}',
          onPrimary: () => ref.invalidate(openTicketsProvider),
        ),
      );
    }

    final dirtyCount =
        furnaces.where((furnace) => _drafts[furnace.id]?.dirty == true).length;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: BafColors.background,
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Furnace condition audit',
            subtitle: 'Burner blocks, draft seals and UV condition',
            icon: Icons.grid_on_rounded,
            accent: BafColors.maintenance,
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Burner blocks'),
              Tab(text: 'Draft seal'),
              Tab(text: 'UV melted'),
              Tab(text: 'UV missing'),
              Tab(text: 'UV hung'),
            ],
          ),
        ),
        body: Column(
          children: [
            _AuditStatusBand(
              furnaceCount: furnaces.length,
              dirtyCount: dirtyCount,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BurnerBlockMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    onChanged: _markChanged,
                  ),
                  _DraftSealMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    onChanged: _markChanged,
                  ),
                  _UvConditionMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    condition: BurnerUvCondition.melted,
                    onChanged: _markChanged,
                  ),
                  _UvConditionMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    condition: BurnerUvCondition.missing,
                    onChanged: _markChanged,
                  ),
                  _UvConditionMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    condition: BurnerUvCondition.hanging,
                    onChanged: _markChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            BafSpacing.lg,
            BafSpacing.sm,
            BafSpacing.lg,
            BafSpacing.md,
          ),
          child: FilledButton.icon(
            onPressed:
                _saving || dirtyCount == 0
                    ? null
                    : () => _save(furnaces, actor),
            icon:
                _saving
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.verified_outlined),
            label: Text(
              _saving
                  ? 'Recording governed audit...'
                  : 'Record $dirtyCount changed furnace${dirtyCount == 1 ? '' : 's'}',
            ),
          ),
        ),
      ),
    );
  }

  Scaffold _shell(Widget body) => Scaffold(
    backgroundColor: BafColors.background,
    appBar: AppBar(
      title: const BafAppBarTitle(
        title: 'Furnace condition audit',
        subtitle: 'Burner blocks, draft seals and UV condition',
        icon: Icons.grid_on_rounded,
        accent: BafColors.maintenance,
      ),
    ),
    body: body,
  );

  void _markChanged(String assetId, void Function(_FurnaceAuditDraft) change) {
    final draft = _drafts[assetId];
    if (draft == null) return;
    setState(() {
      change(draft);
      draft.dirty = true;
    });
  }

  Future<void> _save(List<AssetInstanceRecord> furnaces, AppUser actor) async {
    final changed = furnaces
        .where((furnace) => _drafts[furnace.id]?.dirty == true)
        .toList(growable: false);
    if (changed.isEmpty) return;
    setState(() => _saving = true);
    var saved = 0;
    var directives = 0;
    try {
      final service = ref.read(burnerConditionRoundServiceProvider);
      for (final furnace in changed) {
        if (furnace.serviceState == AssetServiceState.outOfService) {
          throw BurnerConditionRoundException(
            '${furnace.name} is administratively out of service and cannot accept a new audit.',
            code: 'failed-precondition',
          );
        }
        final draft = _drafts[furnace.id]!;
        final result = await service.record(
          furnace: furnace,
          observations: draft.burnerObservations,
          draftSealRedHotObserved: draft.draftSealRedHotObserved,
          hotAirAtDraftSealObserved: draft.hotAirAtDraftSealObserved,
          uvObservations: draft.uvObservations,
          actor: actor,
          roundNote: 'Cross-furnace component condition audit.',
        );
        saved++;
        if (result.directiveId != null) directives++;
        draft.dirty = false;
      }
      ref.invalidate(latestBurnerConditionRoundsProvider(actor.uid));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$saved furnace audit${saved == 1 ? '' : 's'} recorded. '
            '$directives I&A directive${directives == 1 ? '' : 's'} created.',
          ),
          backgroundColor: BafColors.success,
        ),
      );
      setState(() {});
    } on BurnerConditionRoundException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$saved of ${changed.length} audits were committed before the next item stopped: ${error.message}',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FurnaceAuditDraft {
  _FurnaceAuditDraft({
    required this.sourceKey,
    required this.sourceAt,
    required this.redHotPositions,
    required this.draftSealRedHotObserved,
    required this.hotAirAtDraftSealObserved,
    required this.uvByPosition,
    required this.burnerObservations,
  });

  factory _FurnaceAuditDraft.fromSources({
    required BurnerConditionRound? round,
    required Set<int> newerRedHotPositions,
    required String sourceKey,
  }) {
    final redHot = <int>{...?round?.redHotPositions, ...newerRedHotPositions};
    final uv = <int, BurnerUvCondition>{
      for (var position = 1; position <= 8; position++)
        position: BurnerUvCondition.serviceable,
    };
    for (final observation
        in round?.uvObservations ?? const <BurnerUvObservation>[]) {
      uv[observation.position] = observation.condition;
    }
    final prior = round?.observations;
    return _FurnaceAuditDraft(
      sourceKey: sourceKey,
      sourceAt: round?.observedAt,
      redHotPositions: redHot,
      draftSealRedHotObserved: round?.draftSealRedHotObserved ?? false,
      hotAirAtDraftSealObserved: round?.hotAirAtDraftSealObserved ?? false,
      uvByPosition: uv,
      burnerObservations: <BurnerConditionObservation>[
        for (var position = 1; position <= 8; position++)
          BurnerConditionObservation(
            position: position,
            flameObservation:
                prior == null
                    ? BurnerRoundFlameObservation.notChecked
                    : prior[position - 1].flameObservation,
            redHotObserved: redHot.contains(position),
            microampReading:
                prior == null ? null : prior[position - 1].microampReading,
            remarks:
                prior == null
                    ? 'Condition matrix audit did not assess flame signal.'
                    : prior[position - 1].remarks,
          ),
      ],
    );
  }

  final String sourceKey;
  final DateTime? sourceAt;
  final Set<int> redHotPositions;
  bool draftSealRedHotObserved;
  bool hotAirAtDraftSealObserved;
  final Map<int, BurnerUvCondition> uvByPosition;
  List<BurnerConditionObservation> burnerObservations;
  bool dirty = false;

  List<BurnerUvObservation> get uvObservations => <BurnerUvObservation>[
    for (var position = 1; position <= 8; position++)
      BurnerUvObservation(
        position: position,
        condition: uvByPosition[position]!,
      ),
  ];

  void setRedHot(int position, bool value) {
    value ? redHotPositions.add(position) : redHotPositions.remove(position);
    burnerObservations = <BurnerConditionObservation>[
      for (final observation in burnerObservations)
        BurnerConditionObservation(
          position: observation.position,
          flameObservation: observation.flameObservation,
          redHotObserved:
              observation.position == position
                  ? value
                  : observation.redHotObserved,
          microampReading: observation.microampReading,
          remarks: observation.remarks,
        ),
    ];
  }
}

Set<int> _newerOpenIssueRedHotPositions({
  required List<MaintenanceRecord> tickets,
  required int furnaceNumber,
  required DateTime? after,
}) {
  final positions = <int>{};
  for (final ticket in tickets) {
    if (ticket.isDeleted ||
        ticket.isResolved ||
        ticket.assetType != AssetType.furnace ||
        ticket.assetNumber != furnaceNumber ||
        (after != null && !ticket.createdAt.isAfter(after))) {
      continue;
    }
    positions.addAll(
      ticket.burnerLockoutCase?.redHotPositions ?? const <int>[],
    );
  }
  return positions;
}

class _AuditStatusBand extends StatelessWidget {
  const _AuditStatusBand({
    required this.furnaceCount,
    required this.dirtyCount,
  });

  final int furnaceCount;
  final int dirtyCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: BafColors.surfaceTint,
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.lg,
        vertical: BafSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              '$furnaceCount governed Furnaces · $dirtyCount changed. '
              'A new audit supersedes earlier condition observations.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _DraftChange =
    void Function(String assetId, void Function(_FurnaceAuditDraft) change);

class _BurnerBlockMatrix extends StatelessWidget {
  const _BurnerBlockMatrix({
    required this.furnaces,
    required this.drafts,
    required this.onChanged,
  });

  final List<AssetInstanceRecord> furnaces;
  final Map<String, _FurnaceAuditDraft> drafts;
  final _DraftChange onChanged;

  @override
  Widget build(BuildContext context) => _MatrixFrame(
    headers: const <String>['B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8'],
    furnaces: furnaces,
    drafts: drafts,
    onConfirm: (furnace) => onChanged(furnace.id, (_) {}),
    cellBuilder: (furnace, draft, position) {
      final selected = draft.redHotPositions.contains(position);
      return _ConditionCell(
        selected: selected,
        color: BafColors.danger,
        tooltip: selected ? 'Red hot observed' : 'No red-hot observation',
        onChanged:
            furnace.serviceState == AssetServiceState.outOfService
                ? null
                : (value) => onChanged(
                  furnace.id,
                  (current) => current.setRedHot(position, value),
                ),
      );
    },
  );
}

class _DraftSealMatrix extends StatelessWidget {
  const _DraftSealMatrix({
    required this.furnaces,
    required this.drafts,
    required this.onChanged,
  });

  final List<AssetInstanceRecord> furnaces;
  final Map<String, _FurnaceAuditDraft> drafts;
  final _DraftChange onChanged;

  @override
  Widget build(BuildContext context) => _MatrixFrame(
    headers: const <String>['Red hot', 'Hot air'],
    cellWidth: 132,
    furnaces: furnaces,
    drafts: drafts,
    onConfirm: (furnace) => onChanged(furnace.id, (_) {}),
    cellBuilder: (furnace, draft, position) {
      final selected =
          position == 1
              ? draft.draftSealRedHotObserved
              : draft.hotAirAtDraftSealObserved;
      return _ConditionCell(
        selected: selected,
        color: position == 1 ? BafColors.danger : BafColors.warning,
        tooltip: position == 1 ? 'Draft seal red hot' : 'Hot air at draft seal',
        onChanged:
            furnace.serviceState == AssetServiceState.outOfService
                ? null
                : (value) => onChanged(furnace.id, (current) {
                  if (position == 1) {
                    current.draftSealRedHotObserved = value;
                  } else {
                    current.hotAirAtDraftSealObserved = value;
                  }
                }),
      );
    },
  );
}

class _UvConditionMatrix extends StatelessWidget {
  const _UvConditionMatrix({
    required this.furnaces,
    required this.drafts,
    required this.condition,
    required this.onChanged,
  });

  final List<AssetInstanceRecord> furnaces;
  final Map<String, _FurnaceAuditDraft> drafts;
  final BurnerUvCondition condition;
  final _DraftChange onChanged;

  @override
  Widget build(BuildContext context) => _MatrixFrame(
    headers: const <String>[
      'UV1',
      'UV2',
      'UV3',
      'UV4',
      'UV5',
      'UV6',
      'UV7',
      'UV8',
    ],
    furnaces: furnaces,
    drafts: drafts,
    onConfirm: (furnace) => onChanged(furnace.id, (_) {}),
    cellBuilder: (furnace, draft, position) {
      final selected = draft.uvByPosition[position] == condition;
      return _ConditionCell(
        selected: selected,
        color: _uvColor(condition),
        tooltip: '${condition.label} at UV$position',
        onChanged:
            furnace.serviceState == AssetServiceState.outOfService
                ? null
                : (value) => onChanged(
                  furnace.id,
                  (current) =>
                      current.uvByPosition[position] =
                          value ? condition : BurnerUvCondition.serviceable,
                ),
      );
    },
  );
}

typedef _MatrixCellBuilder =
    Widget Function(
      AssetInstanceRecord furnace,
      _FurnaceAuditDraft draft,
      int position,
    );

class _MatrixFrame extends StatelessWidget {
  const _MatrixFrame({
    required this.headers,
    required this.furnaces,
    required this.drafts,
    required this.cellBuilder,
    required this.onConfirm,
    this.cellWidth = 68,
  });

  final List<String> headers;
  final List<AssetInstanceRecord> furnaces;
  final Map<String, _FurnaceAuditDraft> drafts;
  final _MatrixCellBuilder cellBuilder;
  final ValueChanged<AssetInstanceRecord> onConfirm;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    const identityWidth = 168.0;
    final width = identityWidth + headers.length * cellWidth;
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: BafSpacing.xl),
            itemCount: furnaces.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  height: 48,
                  color: BafColors.surfaceStrong,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: identityWidth,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Furnace',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                      for (final header in headers)
                        SizedBox(
                          width: cellWidth,
                          child: Text(
                            header,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                );
              }
              final furnace = furnaces[index - 1];
              final draft = drafts[furnace.id]!;
              return Container(
                height: 58,
                decoration: const BoxDecoration(
                  color: BafColors.card,
                  border: Border(bottom: BorderSide(color: BafColors.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: identityWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Furnace ${furnace.assetNumber.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    draft.sourceAt == null
                                        ? 'No prior audit'
                                        : DateFormat(
                                          'dd MMM, HH:mm',
                                        ).format(draft.sourceAt!.toLocal()),
                                    style: const TextStyle(
                                      color: BafColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Tooltip(
                              message:
                                  draft.dirty
                                      ? 'This Furnace is ready to record'
                                      : 'Confirm this Furnace as reviewed',
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed:
                                    furnace.serviceState ==
                                            AssetServiceState.outOfService
                                        ? null
                                        : () => onConfirm(furnace),
                                icon: Icon(
                                  draft.dirty
                                      ? Icons.task_alt_rounded
                                      : Icons.fact_check_outlined,
                                  size: 19,
                                  color:
                                      draft.dirty
                                          ? BafColors.success
                                          : BafColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (
                      var position = 1;
                      position <= headers.length;
                      position++
                    )
                      SizedBox(
                        width: cellWidth,
                        child: cellBuilder(furnace, draft, position),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConditionCell extends StatelessWidget {
  const _ConditionCell({
    required this.selected,
    required this.color,
    required this.tooltip,
    required this.onChanged,
  });

  final bool selected;
  final Color color;
  final String tooltip;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Center(
        child: Checkbox(
          value: selected,
          activeColor: color,
          onChanged:
              onChanged == null ? null : (value) => onChanged!(value == true),
        ),
      ),
    );
  }
}

Color _uvColor(BurnerUvCondition condition) => switch (condition) {
  BurnerUvCondition.serviceable => BafColors.success,
  BurnerUvCondition.melted => BafColors.danger,
  BurnerUvCondition.missing => BafColors.warning,
  BurnerUvCondition.hanging => BafColors.instrument,
};
