// FILE: lib/features/abnormalities/presentation/charge_abnormalities_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/dashboard_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../audit/models/audit_event_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/abnormality_model.dart';
import '../providers/abnormality_provider.dart';

class ChargeAbnormalitiesScreen extends ConsumerStatefulWidget {
  final int sourceChargeNo;
  final String? title;
  final String? subtitle;

  const ChargeAbnormalitiesScreen({
    super.key,
    required this.sourceChargeNo,
    this.title,
    this.subtitle,
  });

  @override
  ConsumerState<ChargeAbnormalitiesScreen> createState() =>
      _ChargeAbnormalitiesScreenState();
}

class _ChargeAbnormalitiesScreenState
    extends ConsumerState<ChargeAbnormalitiesScreen> {
  @override
  Widget build(BuildContext context) {
    final abnormalitiesAsync =
    ref.watch(abnormalitiesForChargeProvider(widget.sourceChargeNo));

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: Text(
          widget.title ?? 'Charge Abnormalities',
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_charge_abnormality_fab_${widget.sourceChargeNo}',
        backgroundColor: BafColors.charges,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Abnormality'),
        onPressed: () => _showAbnormalityForm(),
      ),
      body: abnormalitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _StateCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load abnormalities',
          message: '$err',
          color: BafColors.danger,
        ),
        data: (records) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BafSpacing.lg,
                  BafSpacing.lg,
                  BafSpacing.lg,
                  BafSpacing.sm,
                ),
                child: _HeaderCard(
                  sourceChargeNo: widget.sourceChargeNo,
                  subtitle: widget.subtitle,
                  total: records.length,
                  raCount: records
                      .where((record) => record.requiresReannealing)
                      .length,
                  completedRaCount: records
                      .where((record) => record.hasCompletedReannealing)
                      .length,
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? const _StateCard(
                  icon: Icons.fact_check_outlined,
                  title: 'No abnormalities logged',
                  message:
                  'Use “Log Abnormality” to record process, equipment, result-quality or RA observations for this charge.',
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.lg,
                    BafSpacing.sm,
                    BafSpacing.lg,
                    96,
                  ),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];

                    return _ChargeAbnormalityCard(
                      record: record,
                      onEdit: () =>
                          _showAbnormalityForm(existing: record),
                      onDelete: () => _confirmDelete(record),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAbnormalityForm({
    ChargeAbnormality? existing,
  }) async {
    final actor = ref.read(currentAppUserProvider).value;

    final allowed = existing == null
        ? actor?.canLogChargeAbnormality == true
        : actor?.canEditChargeAbnormality == true;

    if (actor == null || !allowed) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'You are not authorized to log charge abnormalities.'
                : 'Only Admin can edit charge abnormalities.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final repository = ref.read(abnormalityRepositoryProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider);

    final activeTypes = await repository.getActiveTypes();

    if (activeTypes.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'No active abnormality types found. Seed or create master data first.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    final draft = await showDialog<_ChargeAbnormalityDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _ChargeAbnormalityFormDialog(
          sourceChargeNo: widget.sourceChargeNo,
          activeTypes: activeTypes,
          existing: existing,
        );
      },
    );

    if (!mounted || draft == null) return;

    try {
      final now = DateTime.now();

      final record = existing == null
          ? ChargeAbnormality()
          : copyChargeAbnormality(existing);

      if (existing == null) {
        record
          ..firestoreId = const Uuid().v4()
          ..sourceChargeNo = widget.sourceChargeNo
          ..loggedAt = now
          ..loggedByUid = actor.uid
          ..loggedByName = actor.name
          ..version = 1;
      }

      record
        ..abnormalityTypeId =
            draft.selectedType.firestoreId ?? draft.selectedType.code
        ..abnormalityTypeCode = draft.selectedType.code
        ..abnormalityTypeTitle = draft.selectedType.title
        ..category = draft.selectedType.category
        ..severity = draft.severity
        ..affectedAssets = draft.affectedAssets
        ..component = draft.component
        ..observedReason = draft.observedReason
        ..description = draft.description
        ..possibleRootReasonCategory = draft.rootReasonCategory
        ..possibleRootReasonNotes = draft.rootReasonNotes
        ..reannealingStatus = draft.reannealingStatus
        ..reannealedToChargeNo = draft.reannealedToChargeNo
        ..updatedAt = now
        ..updatedByUid = actor.uid
        ..updatedByName = actor.name
        ..isDeleted = false
        ..isSynced = false;

      record.normalizeReannealingState();

      if (existing == null) {
        await repository.saveAbnormality(
          record,
          actor: actor,
          auditContext: AuditContext(
            performedByUid: actor.uid,
            performedByName: actor.name,
            reasonNotes: 'Logged charge abnormality',
          ),
        );
      } else {
        final result = await ref
            .read(chargeAbnormalityCommandServiceProvider)
            .update(
              abnormality: record,
              expectedVersion: existing.version,
              reason: 'Updated charge abnormality',
            );
        await repository.updateAbnormalityFromRemote(
          result.abnormality,
        );
      }

      unawaited(
        syncCoordinator.runFullSync(
          reason:
              existing == null
                  ? 'charge_abnormality_created'
                  : 'charge_abnormality_edited',
          force: true,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Charge abnormality logged'
                : 'Charge abnormality updated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDelete(ChargeAbnormality record) async {
    final actor = ref.read(currentAppUserProvider).value;

    if (actor == null || !actor.canSoftDeleteChargeAbnormality) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Only Admin can delete charge abnormalities.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final decision = await showDialog<_DeleteDecision>(
      context: context,
      builder: (_) => const _DeleteAbnormalityDialog(),
    );

    if (!mounted || decision == null) return;

    try {
      if (record.firestoreId == null) {
        if (!mounted) return;

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Abnormality ID is missing')),
        );
        return;
      }

      final repository = ref.read(abnormalityRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      final deleteReason = <String>[
        if (decision.reason != null) _auditReasonLabel(decision.reason!),
        if (decision.notes?.trim().isNotEmpty == true) decision.notes!.trim(),
      ].join(': ');
      final result = await ref
          .read(chargeAbnormalityCommandServiceProvider)
          .softDelete(
            abnormality: record,
            expectedVersion: record.version,
            reason: deleteReason,
          );
      await repository.applyTombstoneFromAbnormalityRemote(
        result.abnormality,
      );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'charge_abnormality_deleted',
          force: true,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Charge abnormality deleted')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// FORM DIALOGS
// ─────────────────────────────────────────────────────────────

class _ChargeAbnormalityFormDialog extends StatefulWidget {
  final int sourceChargeNo;
  final List<AbnormalityType> activeTypes;
  final ChargeAbnormality? existing;

  const _ChargeAbnormalityFormDialog({
    required this.sourceChargeNo,
    required this.activeTypes,
    required this.existing,
  });

  @override
  State<_ChargeAbnormalityFormDialog> createState() =>
      _ChargeAbnormalityFormDialogState();
}

class _ChargeAbnormalityFormDialogState
    extends State<_ChargeAbnormalityFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late AbnormalityType _selectedType;
  late AbnormalitySeverity _selectedSeverity;
  late RootReasonCategory _selectedRootReason;
  late ReannealingStatus _selectedReannealingStatus;
  late AssetType _selectedAssetType;

  late final TextEditingController _componentController;
  late final TextEditingController _observedReasonController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _rootReasonNotesController;
  late final TextEditingController _reannealedToChargeController;
  late final TextEditingController _assetNumberController;

  late final List<AffectedAssetRef> _affectedAssets;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _selectedType = _initialSelectedType(
      activeTypes: widget.activeTypes,
      existing: existing,
    );

    _selectedSeverity = existing?.severity ?? _selectedType.severity;
    _selectedRootReason =
        existing?.possibleRootReasonCategory ?? RootReasonCategory.unknown;

    _selectedReannealingStatus = existing?.reannealingStatus ??
        _defaultRaStatusForType(_selectedType);

    _selectedAssetType = _selectedType.applicableAssetTypes.isNotEmpty
        ? _selectedType.applicableAssetTypes.first
        : AssetType.base;

    _componentController = TextEditingController(
      text: existing?.component ?? '',
    );
    _observedReasonController = TextEditingController(
      text: existing?.observedReason ?? '',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _rootReasonNotesController = TextEditingController(
      text: existing?.possibleRootReasonNotes ?? '',
    );
    _reannealedToChargeController = TextEditingController(
      text: existing?.reannealedToChargeNo?.toString() ?? '',
    );
    _assetNumberController = TextEditingController();

    _affectedAssets = [
      ...(existing?.affectedAssets ?? const <AffectedAssetRef>[]),
    ];
  }

  @override
  void dispose() {
    _componentController.dispose();
    _observedReasonController.dispose();
    _descriptionController.dispose();
    _rootReasonNotesController.dispose();
    _reannealedToChargeController.dispose();
    _assetNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applicableAssetTypes = _selectedType.applicableAssetTypes.isEmpty
        ? AssetType.values
        : _selectedType.applicableAssetTypes;

    if (!applicableAssetTypes.contains(_selectedAssetType)) {
      _selectedAssetType = applicableAssetTypes.first;
    }

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Log Charge Abnormality'
            : 'Edit Charge Abnormality',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChargeContextStrip(
                  sourceChargeNo: widget.sourceChargeNo,
                ),
                const SizedBox(height: BafSpacing.md),
                DropdownButtonFormField<AbnormalityType>(
                  initialValue: _selectedType,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Abnormality Type',
                  ),
                  selectedItemBuilder: (context) {
                    return widget.activeTypes.map((type) {
                      return Text(
                        '${type.code} — ${type.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }).toList();
                  },
                  items: widget.activeTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        '${type.code} — ${type.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedType = value;
                      _selectedSeverity = value.severity;

                      if (widget.existing == null) {
                        _selectedReannealingStatus =
                            _defaultRaStatusForType(value);
                      }

                      if (value.applicableAssetTypes.isNotEmpty &&
                          !value.applicableAssetTypes
                              .contains(_selectedAssetType)) {
                        _selectedAssetType = value.applicableAssetTypes.first;
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.sm,
                  children: [
                    StatusBadge(
                      label: _categoryLabel(_selectedType.category),
                      color: _categoryColor(_selectedType.category),
                      icon: Icons.category_rounded,
                    ),
                    StatusBadge(
                      label: _severityLabel(_selectedSeverity),
                      color: _severityColor(_selectedSeverity),
                      icon: Icons.priority_high_rounded,
                    ),
                    if (_selectedType.suggestsReannealing)
                      const StatusBadge(
                        label: 'RA Suggested',
                        color: BafColors.audit,
                        icon: Icons.repeat_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: BafSpacing.md),
                DropdownButtonFormField<AbnormalitySeverity>(
                  initialValue: _selectedSeverity,
                  decoration: _inputDecoration(
                    label: 'Severity',
                  ),
                  items: AbnormalitySeverity.values.map((severity) {
                    return DropdownMenuItem(
                      value: severity,
                      child: Text(_severityLabel(severity)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedSeverity = value);
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _componentController,
                  decoration: _inputDecoration(
                    label: 'Component / area',
                    hint: 'Optional: burner, movement, coil, etc.',
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _observedReasonController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    label: 'Observed reason',
                    hint:
                    'Example: Cycle completed but coil colour indicated RA required',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Observed reason is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    label: 'Additional description',
                    hint: 'Optional details',
                  ),
                ),
                const SizedBox(height: BafSpacing.lg),
                const _SectionTitle(
                  icon: Icons.precision_manufacturing_rounded,
                  title: 'Affected Assets',
                  subtitle: 'Add all assets involved in this abnormality.',
                ),
                const SizedBox(height: BafSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<AssetType>(
                        initialValue: _selectedAssetType,
                        isExpanded: true,
                        decoration: _inputDecoration(
                          label: 'Asset',
                        ),
                        items: applicableAssetTypes.map((assetType) {
                          return DropdownMenuItem(
                            value: assetType,
                            child: Text(
                              _assetTypeLabel(assetType),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedAssetType = value);
                        },
                      ),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _assetNumberController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: 'No.',
                          hint: '105',
                        ),
                      ),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    IconButton.filled(
                      tooltip: 'Add asset',
                      style: IconButton.styleFrom(
                        backgroundColor: BafColors.assets,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _addAsset,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: BafSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _affectedAssets.isEmpty
                      ? const Text(
                    'No affected asset added yet.',
                    style: TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                    ),
                  )
                      : Wrap(
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.sm,
                    children: _affectedAssets.map((asset) {
                      return InputChip(
                        avatar: Icon(
                          _assetIcon(asset.assetType),
                          color: BafColors.assets,
                          size: 16,
                        ),
                        label: Text(asset.label),
                        onDeleted: () {
                          setState(() {
                            _affectedAssets.removeWhere((candidate) {
                              return candidate.assetType ==
                                  asset.assetType &&
                                  candidate.assetNumber ==
                                      asset.assetNumber;
                            });
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: BafSpacing.lg),
                const _SectionTitle(
                  icon: Icons.search_rounded,
                  title: 'Possible Root Reason',
                  subtitle: 'This can be refined later after investigation.',
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<RootReasonCategory>(
                  initialValue: _selectedRootReason,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Root reason category',
                  ),
                  items: RootReasonCategory.values.map((rootCategory) {
                    return DropdownMenuItem(
                      value: rootCategory,
                      child: Text(
                        _rootReasonCategoryLabel(rootCategory),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedRootReason = value);
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _rootReasonNotesController,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    label: 'Root reason notes',
                    hint: 'Optional',
                  ),
                ),
                const SizedBox(height: BafSpacing.lg),
                const _SectionTitle(
                  icon: Icons.repeat_rounded,
                  title: 'Re-annealing / RA Traceability',
                  subtitle:
                  'Use this when the abnormality results in RA or RA decision tracking.',
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<ReannealingStatus>(
                  initialValue: _selectedReannealingStatus,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'RA status',
                  ),
                  items: ReannealingStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        _raStatusLabel(status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedReannealingStatus = value);
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _reannealedToChargeController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    label: 'New / RA charge no.',
                    hint: 'Optional. Filling this marks RA completed.',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;

                    final number = int.tryParse(text);
                    if (number == null || number <= 0) {
                      return 'Enter a valid charge number';
                    }

                    if (number == widget.sourceChargeNo) {
                      return 'New charge cannot be same as source charge';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.charges,
          ),
          onPressed: _submit,
          child: Text(widget.existing == null ? 'Log' : 'Save'),
        ),
      ],
    );
  }

  void _addAsset() {
    final number = int.tryParse(_assetNumberController.text.trim());

    if (number == null || number <= 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Enter a valid asset number'),
        ),
      );
      return;
    }

    final refToAdd = AffectedAssetRef(
      assetType: _selectedAssetType,
      assetNumber: number,
    );

    final alreadyExists = _affectedAssets.any((asset) {
      return asset.assetType == refToAdd.assetType &&
          asset.assetNumber == refToAdd.assetNumber;
    });

    if (!alreadyExists) {
      setState(() {
        _affectedAssets.add(refToAdd);
        _assetNumberController.clear();
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final reannealedToChargeNo = int.tryParse(
      _reannealedToChargeController.text.trim(),
    );

    Navigator.pop(
      context,
      _ChargeAbnormalityDraft(
        selectedType: _selectedType,
        severity: _selectedSeverity,
        affectedAssets: List<AffectedAssetRef>.from(_affectedAssets),
        component: _emptyToNull(_componentController.text),
        observedReason: _observedReasonController.text.trim(),
        description: _emptyToNull(_descriptionController.text),
        rootReasonCategory: _selectedRootReason,
        rootReasonNotes: _emptyToNull(_rootReasonNotesController.text),
        reannealingStatus: _selectedReannealingStatus,
        reannealedToChargeNo: reannealedToChargeNo,
      ),
    );
  }
}

class _DeleteAbnormalityDialog extends StatefulWidget {
  const _DeleteAbnormalityDialog();

  @override
  State<_DeleteAbnormalityDialog> createState() =>
      _DeleteAbnormalityDialogState();
}

class _DeleteAbnormalityDialogState extends State<_DeleteAbnormalityDialog> {
  final TextEditingController _reasonController = TextEditingController();

  AuditReason? _selectedReason;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Charge Abnormality'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This abnormality will be hidden but retained for audit and sync traceability.',
              style: TextStyle(
                color: BafColors.textSecondary,
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<AuditReason>(
              initialValue: _selectedReason,
              isExpanded: true,
              decoration: _inputDecoration(
                label: 'Reason',
                hint: 'Optional',
              ),
              items: AuditReason.values.map((reason) {
                return DropdownMenuItem(
                  value: reason,
                  child: Text(
                    _auditReasonLabel(reason),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
            ),
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              controller: _reasonController,
              maxLines: 2,
              decoration: _inputDecoration(
                label: 'Additional notes',
                hint: 'Optional',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.danger,
          ),
          onPressed: () {
            Navigator.pop(
              context,
              _DeleteDecision(
                reason: _selectedReason,
                notes: _emptyToNull(_reasonController.text),
              ),
            );
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _ChargeAbnormalityDraft {
  final AbnormalityType selectedType;
  final AbnormalitySeverity severity;
  final List<AffectedAssetRef> affectedAssets;
  final String? component;
  final String observedReason;
  final String? description;
  final RootReasonCategory rootReasonCategory;
  final String? rootReasonNotes;
  final ReannealingStatus reannealingStatus;
  final int? reannealedToChargeNo;

  const _ChargeAbnormalityDraft({
    required this.selectedType,
    required this.severity,
    required this.affectedAssets,
    required this.component,
    required this.observedReason,
    required this.description,
    required this.rootReasonCategory,
    required this.rootReasonNotes,
    required this.reannealingStatus,
    required this.reannealedToChargeNo,
  });
}

class _DeleteDecision {
  final AuditReason? reason;
  final String? notes;

  const _DeleteDecision({
    required this.reason,
    required this.notes,
  });
}

// ─────────────────────────────────────────────────────────────
// UI WIDGETS
// ─────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final int sourceChargeNo;
  final String? subtitle;
  final int total;
  final int raCount;
  final int completedRaCount;

  const _HeaderCard({
    required this.sourceChargeNo,
    required this.subtitle,
    required this.total,
    required this.raCount,
    required this.completedRaCount,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      backgroundColor: BafColors.charges,
      borderColor: BafColors.charges.withValues(alpha: 0.28),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Charge $sourceChargeNo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  subtitle ??
                      'Operational memory for abnormalities, RA decision and recurrence analysis.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          _MetricPill(label: 'Total', value: total),
          const SizedBox(width: BafSpacing.sm),
          _MetricPill(label: 'RA', value: raCount),
          const SizedBox(width: BafSpacing.sm),
          _MetricPill(label: 'Done', value: completedRaCount),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final int value;

  const _MetricPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.sm,
        vertical: BafSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeAbnormalityCard extends StatelessWidget {
  final ChargeAbnormality record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChargeAbnormalityCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(record.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.md),
      child: DashboardCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(BafRadius.large),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.md,
                    BafSpacing.md,
                    BafSpacing.sm,
                    BafSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children: [
                          StatusBadge(
                            label: record.abnormalityTypeCode,
                            color: BafColors.admin,
                            icon: Icons.tag_rounded,
                          ),
                          StatusBadge(
                            label: _categoryLabel(record.category),
                            color: categoryColor,
                            icon: Icons.category_rounded,
                          ),
                          StatusBadge(
                            label: _severityLabel(record.severity),
                            color: _severityColor(record.severity),
                            icon: Icons.priority_high_rounded,
                          ),
                          StatusBadge(
                            label: _raStatusLabel(record.reannealingStatus),
                            color: _raStatusColor(record.reannealingStatus),
                            icon: Icons.repeat_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: BafSpacing.md),
                      Text(
                        record.abnormalityTypeTitle,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: BafSpacing.xs),
                      Text(
                        record.observedReason,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 13,
                          height: 1.28,
                        ),
                      ),
                      if ((record.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: BafSpacing.xs),
                        Text(
                          record.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const SizedBox(height: BafSpacing.md),
                      Wrap(
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children: [
                          _SoftChip(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Old charge ${record.sourceChargeNo}',
                          ),
                          if (record.reannealedToChargeNo != null)
                            _SoftChip(
                              icon: Icons.repeat_rounded,
                              label:
                              'New charge ${record.reannealedToChargeNo}',
                            ),
                          _SoftChip(
                            icon: Icons.precision_manufacturing_rounded,
                            label: record.affectedAssetsLabel,
                          ),
                          _SoftChip(
                            icon: Icons.manage_search_rounded,
                            label: _rootReasonCategoryLabel(
                              record.possibleRootReasonCategory,
                            ),
                          ),
                        ],
                      ),
                      if ((record.possibleRootReasonNotes ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: BafSpacing.sm),
                        Text(
                          'Root note: ${record.possibleRootReasonNotes}',
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: BafSpacing.md),
                      Text(
                        'Logged ${DateFormat('dd MMM yyyy, HH:mm').format(record.loggedAt)}'
                            '${record.loggedByName == null ? '' : ' by ${record.loggedByName}'}',
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    color: BafColors.planned,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: BafColors.danger,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(width: BafSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChargeContextStrip extends StatelessWidget {
  final int sourceChargeNo;

  const _ChargeContextStrip({
    required this.sourceChargeNo,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      backgroundColor: BafColors.charges.withValues(alpha: 0.08),
      borderColor: BafColors.charges.withValues(alpha: 0.18),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            color: BafColors.charges,
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              'Source / old charge no: $sourceChargeNo',
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: BafColors.navySoft, size: 20),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        icon,
        size: 16,
        color: BafColors.assets,
      ),
      label: Text(label),
      labelStyle: const TextStyle(
        color: BafColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: BafColors.assets.withValues(alpha: 0.08),
      side: BorderSide(
        color: BafColors.assets.withValues(alpha: 0.16),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? color;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? BafColors.charges;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: DashboardCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: effectiveColor),
              const SizedBox(height: BafSpacing.md),
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BafSpacing.sm),
              Text(
                message,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

InputDecoration _inputDecoration({
  required String label,
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: BafColors.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(
        color: BafColors.navySoft,
        width: 1.4,
      ),
    ),
  );
}

AbnormalityType _initialSelectedType({
  required List<AbnormalityType> activeTypes,
  required ChargeAbnormality? existing,
}) {
  if (existing == null) return activeTypes.first;

  for (final type in activeTypes) {
    if (type.firestoreId == existing.abnormalityTypeId ||
        type.code == existing.abnormalityTypeId ||
        type.code == existing.abnormalityTypeCode) {
      return type;
    }
  }

  return activeTypes.first;
}

ReannealingStatus _defaultRaStatusForType(AbnormalityType type) {
  if (type.isRaCoilColourType) {
    return ReannealingStatus.required;
  }

  if (type.suggestsReannealing) {
    return ReannealingStatus.pendingDecision;
  }

  return ReannealingStatus.notApplicable;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _categoryLabel(AbnormalityCategory category) {
  switch (category) {
    case AbnormalityCategory.process:
      return 'Process';
    case AbnormalityCategory.equipment:
      return 'Equipment';
    case AbnormalityCategory.resultQuality:
      return 'Result / Quality';
    case AbnormalityCategory.reannealing:
      return 'Re-annealing';
    case AbnormalityCategory.other:
      return 'Other';
  }
}

String _severityLabel(AbnormalitySeverity severity) {
  switch (severity) {
    case AbnormalitySeverity.low:
      return 'Low';
    case AbnormalitySeverity.medium:
      return 'Medium';
    case AbnormalitySeverity.high:
      return 'High';
    case AbnormalitySeverity.critical:
      return 'Critical';
  }
}

String _raStatusLabel(ReannealingStatus status) {
  switch (status) {
    case ReannealingStatus.notApplicable:
      return 'Not Applicable';
    case ReannealingStatus.pendingDecision:
      return 'Pending Decision';
    case ReannealingStatus.required:
      return 'Required';
    case ReannealingStatus.notRequired:
      return 'Not Required';
    case ReannealingStatus.completed:
      return 'Completed';
  }
}

String _rootReasonCategoryLabel(RootReasonCategory category) {
  switch (category) {
    case RootReasonCategory.unknown:
      return 'Unknown';
    case RootReasonCategory.baseRelated:
      return 'Base Related';
    case RootReasonCategory.furnaceRelated:
      return 'Furnace Related';
    case RootReasonCategory.forceCoolerRelated:
      return 'Force Cooler Related';
    case RootReasonCategory.atmosphereRelated:
      return 'Atmosphere Related';
    case RootReasonCategory.thermocoupleTemperature:
      return 'Thermocouple / Temperature';
    case RootReasonCategory.cycleInterruption:
      return 'Cycle Interruption';
    case RootReasonCategory.materialOrCoilCondition:
      return 'Material / Coil Condition';
    case RootReasonCategory.operationsRelated:
      return 'Operations Related';
    case RootReasonCategory.other:
      return 'Other';
  }
}

String _assetTypeLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'Base';
    case AssetType.furnace:
      return 'Furnace';
    case AssetType.forceCooler:
      return 'Force Cooler';
    case AssetType.innerCover:
      return 'Inner Cover';
    case AssetType.governedCustom:
      return 'Governed Asset';
  }
}

IconData _assetIcon(AssetType type) {
  switch (type) {
    case AssetType.base:
      return Icons.foundation_rounded;
    case AssetType.furnace:
      return Icons.local_fire_department_rounded;
    case AssetType.forceCooler:
      return Icons.ac_unit_rounded;
    case AssetType.innerCover:
      return Icons.inventory_2_outlined;
    case AssetType.governedCustom:
      return Icons.precision_manufacturing_outlined;
  }
}

Color _categoryColor(AbnormalityCategory category) {
  switch (category) {
    case AbnormalityCategory.process:
      return BafColors.planned;
    case AbnormalityCategory.equipment:
      return BafColors.maintenance;
    case AbnormalityCategory.resultQuality:
      return BafColors.charges;
    case AbnormalityCategory.reannealing:
      return BafColors.audit;
    case AbnormalityCategory.other:
      return BafColors.admin;
  }
}

Color _severityColor(AbnormalitySeverity severity) {
  switch (severity) {
    case AbnormalitySeverity.low:
      return BafColors.success;
    case AbnormalitySeverity.medium:
      return BafColors.warning;
    case AbnormalitySeverity.high:
      return BafColors.maintenance;
    case AbnormalitySeverity.critical:
      return BafColors.danger;
  }
}

Color _raStatusColor(ReannealingStatus status) {
  switch (status) {
    case ReannealingStatus.notApplicable:
      return BafColors.textSecondary;
    case ReannealingStatus.pendingDecision:
      return BafColors.warning;
    case ReannealingStatus.required:
      return BafColors.audit;
    case ReannealingStatus.notRequired:
      return BafColors.admin;
    case ReannealingStatus.completed:
      return BafColors.success;
  }
}

String _auditReasonLabel(AuditReason reason) {
  final raw = reason.name;

  final words = raw
      .replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
  )
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'));

  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
