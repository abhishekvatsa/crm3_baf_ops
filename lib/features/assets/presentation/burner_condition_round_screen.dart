import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_registry_model.dart';
import '../data/burner_condition_round.dart';
import '../providers/asset_hierarchy_provider.dart';
import '../providers/burner_condition_round_provider.dart';
import '../services/burner_condition_round_service.dart';

class BurnerConditionRoundScreen extends ConsumerStatefulWidget {
  const BurnerConditionRoundScreen({super.key, this.initialAssetInstanceId});

  final String? initialAssetInstanceId;

  @override
  ConsumerState<BurnerConditionRoundScreen> createState() =>
      _BurnerConditionRoundScreenState();
}

class _BurnerConditionRoundScreenState
    extends ConsumerState<BurnerConditionRoundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roundNoteController = TextEditingController();
  late final List<_BurnerObservationDraft> _observations;
  String? _assetInstanceId;
  bool _submitting = false;
  bool _draftSealRedHotObserved = false;
  bool _hotAirAtDraftSealObserved = false;

  @override
  void initState() {
    super.initState();
    _assetInstanceId = widget.initialAssetInstanceId;
    _observations = List<_BurnerObservationDraft>.generate(
      8,
      (index) => _BurnerObservationDraft(position: index + 1),
    );
  }

  @override
  void dispose() {
    _roundNoteController.dispose();
    for (final observation in _observations) {
      observation.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return _shell(const Center(child: CircularProgressIndicator()));
    }
    if (actorAsync.hasError) {
      return _shell(
        const Center(child: Text('Could not verify burner-round access.')),
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canRecordBurnerConditionRound) {
      return _shell(
        const Center(
          child: Text('Approved Operations or I&A access is required.'),
        ),
      );
    }
    final classesAsync = ref.watch(assetClassesProvider);
    final assetsAsync = ref.watch(allAssetInstancesProvider);
    final loading =
        (classesAsync.isLoading && !classesAsync.hasValue) ||
        (assetsAsync.isLoading && !assetsAsync.hasValue);
    final error =
        (classesAsync.hasError && !classesAsync.hasValue) ||
        (assetsAsync.hasError && !assetsAsync.hasValue);
    if (loading) {
      return _shell(const Center(child: CircularProgressIndicator()));
    }
    if (error) {
      return _shell(
        const Center(child: Text('Could not load governed Furnace records.')),
      );
    }
    final furnaceClasses = (classesAsync.value ?? const <AssetClassRecord>[])
        .where(
          (item) =>
              item.status == AssetHierarchyStatus.active &&
              item.legacyAssetTypeKey == 'furnace',
        )
        .toList(growable: false);
    if (furnaceClasses.length != 1) {
      return _shell(
        const Center(
          child: Text('Furnace asset authority needs reconciliation.'),
        ),
      );
    }
    final furnaceClass = furnaceClasses.single;
    final furnaces =
        (assetsAsync.value ?? const <AssetInstanceRecord>[])
            .where(
              (item) =>
                  item.assetClassId == furnaceClass.id &&
                  item.isActive &&
                  item.serviceState != AssetServiceState.outOfService,
            )
            .toList()
          ..sort(
            (left, right) => left.assetNumber.compareTo(right.assetNumber),
          );
    final selected = _selectedFurnace(furnaces);
    if (_assetInstanceId != null && selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _assetInstanceId != null) {
          setState(() => _assetInstanceId = null);
        }
      });
    }

    return _shell(
      Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.lg,
            BafSpacing.lg,
            BafSpacing.lg,
            104,
          ),
          children: [
            DropdownButtonFormField<String>(
              initialValue: selected?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Furnace',
                prefixIcon: Icon(Icons.precision_manufacturing_outlined),
              ),
              items: [
                for (final furnace in furnaces)
                  DropdownMenuItem(
                    value: furnace.id,
                    child: Text(
                      '${furnace.name} (${furnace.assetNumber})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              validator: (value) => value == null ? 'Select a Furnace.' : null,
              onChanged:
                  _submitting
                      ? null
                      : (value) => setState(() => _assetInstanceId = value),
            ),
            const SizedBox(height: BafSpacing.xl),
            _DraftSealConditionPanel(
              draftSealRedHotObserved: _draftSealRedHotObserved,
              hotAirAtDraftSealObserved: _hotAirAtDraftSealObserved,
              enabled: !_submitting,
              onDraftSealRedHotChanged:
                  (value) => setState(() => _draftSealRedHotObserved = value),
              onHotAirChanged:
                  (value) => setState(() => _hotAirAtDraftSealObserved = value),
            ),
            const SizedBox(height: BafSpacing.xl),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Burner observations',
                    style: TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<BurnerRoundFlameObservation>(
                  tooltip: 'Apply flame observation to all burners',
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  onSelected:
                      _submitting
                          ? null
                          : (value) {
                            setState(() {
                              for (final observation in _observations) {
                                observation.flameObservation = value;
                                if (value ==
                                        BurnerRoundFlameObservation
                                            .notChecked ||
                                    value ==
                                        BurnerRoundFlameObservation
                                            .notOperating) {
                                  observation._microampController.clear();
                                }
                              }
                            });
                          },
                  itemBuilder:
                      (context) => [
                        for (final value in BurnerRoundFlameObservation.values)
                          PopupMenuItem(value: value, child: Text(value.label)),
                      ],
                ),
                PopupMenuButton<BurnerUvCondition>(
                  tooltip: 'Apply UV condition to all burners',
                  icon: const Icon(Icons.sensors_rounded),
                  onSelected:
                      _submitting
                          ? null
                          : (value) {
                            setState(() {
                              for (final observation in _observations) {
                                observation.uvCondition = value;
                              }
                            });
                          },
                  itemBuilder:
                      (context) => [
                        for (final value in BurnerUvCondition.values)
                          PopupMenuItem(value: value, child: Text(value.label)),
                      ],
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.sm),
            for (final observation in _observations) ...[
              _BurnerObservationEditor(
                key: ValueKey(observation.position),
                furnaceNumber: selected?.assetNumber,
                draft: observation,
                enabled: !_submitting,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: BafSpacing.sm),
            ],
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              controller: _roundNoteController,
              enabled: !_submitting,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Round note (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      bottom: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.sm,
          BafSpacing.lg,
          BafSpacing.md,
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _submitting || selected == null
                    ? null
                    : () => _submit(selected, actor),
            icon:
                _submitting
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.fact_check_outlined),
            label: Text(_submitting ? 'Recording...' : 'Record round'),
          ),
        ),
      ),
    );
  }

  Scaffold _shell(Widget body, {Widget? bottom}) => Scaffold(
    backgroundColor: BafColors.background,
    appBar: AppBar(
      title: const BafAppBarTitle(
        title: 'Record burner round',
        subtitle: 'Block condition, flame signal and evidence',
        icon: Icons.fact_check_outlined,
        accent: BafColors.maintenance,
      ),
    ),
    body: body,
    bottomNavigationBar: bottom,
  );

  AssetInstanceRecord? _selectedFurnace(List<AssetInstanceRecord> furnaces) {
    final id = _assetInstanceId;
    if (id == null) return null;
    for (final furnace in furnaces) {
      if (furnace.id == id) return furnace;
    }
    return null;
  }

  Future<void> _submit(AssetInstanceRecord furnace, AppUser actor) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final observations = <BurnerConditionObservation>[];
    try {
      for (final draft in _observations) {
        observations.add(draft.toObservation());
      }
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(burnerConditionRoundServiceProvider)
          .record(
            furnace: furnace,
            observations: observations,
            draftSealRedHotObserved: _draftSealRedHotObserved,
            hotAirAtDraftSealObserved: _hotAirAtDraftSealObserved,
            uvObservations: _observations
                .map((draft) => draft.toUvObservation())
                .toList(growable: false),
            actor: actor,
            roundNote: _roundNoteController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on BurnerConditionRoundException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BurnerObservationEditor extends StatelessWidget {
  const _BurnerObservationEditor({
    super.key,
    required this.furnaceNumber,
    required this.draft,
    required this.enabled,
    required this.onChanged,
  });

  final int? furnaceNumber;
  final _BurnerObservationDraft draft;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tag =
        furnaceNumber == null
            ? 'Burner ${draft.position}'
            : 'FR-${furnaceNumber.toString().padLeft(2, '0')}-B${draft.position.toString().padLeft(2, '0')}';
    return Material(
      color: BafColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: BorderSide(
          color:
              draft.redHotObserved
                  ? BafColors.danger.withValues(alpha: 0.5)
                  : BafColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tag,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<BurnerRoundFlameObservation>(
              key: ValueKey(
                'flame-${draft.position}-${draft.flameObservation?.name}',
              ),
              initialValue: draft.flameObservation,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Flame observation',
                prefixIcon: Icon(Icons.local_fire_department_outlined),
              ),
              items: [
                for (final value in BurnerRoundFlameObservation.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              validator:
                  (value) => value == null ? 'Select an observation.' : null,
              onChanged:
                  enabled
                      ? (value) {
                        if (value == null) return;
                        draft.flameObservation = value;
                        if (value == BurnerRoundFlameObservation.notChecked ||
                            value == BurnerRoundFlameObservation.notOperating) {
                          draft._microampController.clear();
                        }
                        onChanged();
                      }
                      : null,
            ),
            const SizedBox(height: BafSpacing.sm),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Red-hot burner block observed'),
              subtitle:
                  draft.redHotObserved
                      ? const Text('A critical I&A directive will be created.')
                      : null,
              value: draft.redHotObserved,
              activeTrackColor: BafColors.danger,
              onChanged:
                  enabled
                      ? (value) {
                        draft.redHotObserved = value;
                        onChanged();
                      }
                      : null,
            ),
            const SizedBox(height: BafSpacing.xs),
            DropdownButtonFormField<BurnerUvCondition>(
              initialValue: draft.uvCondition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'UV condition',
                prefixIcon: Icon(Icons.sensors_outlined),
              ),
              items: [
                for (final condition in BurnerUvCondition.values)
                  DropdownMenuItem(
                    value: condition,
                    child: Text(condition.label),
                  ),
              ],
              validator:
                  (value) => value == null ? 'Select the UV condition.' : null,
              onChanged:
                  enabled
                      ? (value) {
                        if (value == null) return;
                        draft.uvCondition = value;
                        onChanged();
                      }
                      : null,
            ),
            const SizedBox(height: BafSpacing.sm),
            TextFormField(
              controller: draft._microampController,
              enabled:
                  enabled &&
                  draft.flameObservation != null &&
                  draft.flameObservation !=
                      BurnerRoundFlameObservation.notChecked &&
                  draft.flameObservation !=
                      BurnerRoundFlameObservation.notOperating,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Flame signal (optional)',
                suffixText: 'microamp',
                prefixIcon: Icon(Icons.speed_outlined),
              ),
              validator: (value) => draft.validateMicroamp(value),
            ),
            const SizedBox(height: BafSpacing.sm),
            TextFormField(
              controller: draft._remarksController,
              enabled: enabled,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observation note (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              validator: (value) {
                if (draft.flameObservation ==
                        BurnerRoundFlameObservation.notChecked &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Explain why this burner was not checked.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BurnerObservationDraft {
  _BurnerObservationDraft({required this.position});

  final int position;
  BurnerRoundFlameObservation? flameObservation;
  BurnerUvCondition? uvCondition;
  bool redHotObserved = false;
  final _microampController = TextEditingController();
  final _remarksController = TextEditingController();

  String? validateMicroamp(String? value) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty) return null;
    final reading = double.tryParse(cleaned);
    if (reading == null ||
        !reading.isFinite ||
        reading < 0 ||
        reading > maximumBurnerMicroampReading) {
      return 'Enter a valid non-negative reading.';
    }
    if (flameObservation == BurnerRoundFlameObservation.notChecked ||
        flameObservation == BurnerRoundFlameObservation.notOperating) {
      return 'Select a flame observation first.';
    }
    return null;
  }

  BurnerConditionObservation toObservation() {
    final observation = flameObservation;
    if (observation == null) {
      throw const FormatException('Select every burner flame observation.');
    }
    final cleaned = _microampController.text.trim();
    final reading = cleaned.isEmpty ? null : double.tryParse(cleaned);
    final validation = validateMicroamp(cleaned);
    if (validation != null) throw FormatException(validation);
    return BurnerConditionObservation(
      position: position,
      flameObservation: observation,
      redHotObserved: redHotObserved,
      microampReading: reading,
      remarks:
          _remarksController.text.trim().isEmpty
              ? null
              : _remarksController.text.trim(),
    );
  }

  BurnerUvObservation toUvObservation() {
    final condition = uvCondition;
    if (condition == null) {
      throw const FormatException('Select every burner UV condition.');
    }
    return BurnerUvObservation(
      position: position,
      condition: condition,
      remarks:
          _remarksController.text.trim().isEmpty
              ? null
              : _remarksController.text.trim(),
    );
  }

  void dispose() {
    _microampController.dispose();
    _remarksController.dispose();
  }
}

class _DraftSealConditionPanel extends StatelessWidget {
  const _DraftSealConditionPanel({
    required this.draftSealRedHotObserved,
    required this.hotAirAtDraftSealObserved,
    required this.enabled,
    required this.onDraftSealRedHotChanged,
    required this.onHotAirChanged,
  });

  final bool draftSealRedHotObserved;
  final bool hotAirAtDraftSealObserved;
  final bool enabled;
  final ValueChanged<bool> onDraftSealRedHotChanged;
  final ValueChanged<bool> onHotAirChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BafColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Draft seal red hot'),
            subtitle: const Text('Visible red-hot condition at the draft seal'),
            value: draftSealRedHotObserved,
            onChanged: enabled ? onDraftSealRedHotChanged : null,
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('Hot air at draft seal'),
            subtitle: const Text('Abnormal hot-air escape observed'),
            value: hotAirAtDraftSealObserved,
            onChanged: enabled ? onHotAirChanged : null,
          ),
        ],
      ),
    );
  }
}
