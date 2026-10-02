// FILE: lib/features/abnormalities/presentation/abnormality_types_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/dashboard_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../audit/models/audit_event_model.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/presentation/current_actor_gate.dart';

import '../../maintenance/data/maintenance_model.dart';
import '../data/abnormality_model.dart';
import '../providers/abnormality_provider.dart';
import 'abnormality_types_toolbar.dart';

part 'abnormality_types_screen.widgets.dart';

class AbnormalityTypesScreen extends ConsumerStatefulWidget {
  const AbnormalityTypesScreen({super.key});

  @override
  ConsumerState<AbnormalityTypesScreen> createState() =>
      _AbnormalityTypesScreenState();
}

enum _TypeStatusFilter { all, active, inactive }

class _AbnormalityTypesScreenState
    extends ConsumerState<AbnormalityTypesScreen> {
  String _searchQuery = '';
  _TypeStatusFilter _statusFilter = _TypeStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final access = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    );
    final appUser = access.actor;
    if (!access.isReady) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Abnormality types',
        appBarSubtitle: 'Cycle-event and quality classification',
        appBarIcon: Icons.rule_folder_outlined,
        accent: BafColors.charges,
        title: 'Account verification required',
        message: access.message,
      );
    }
    if (appUser == null || !appUser.canManageAbnormalityTypes) {
      return Scaffold(
        backgroundColor: BafColors.background,
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Abnormality types',
            subtitle: 'Cycle-event and quality classification',
            icon: Icons.rule_folder_outlined,
            accent: BafColors.charges,
          ),
        ),
        body: const _StateCard(
          icon: Icons.lock_outline_rounded,
          title: 'Admin access required',
          message: 'Only Admin can manage abnormality type master data.',
          color: BafColors.danger,
        ),
      );
    }

    final typesAsync = ref.watch(allAbnormalityTypesProvider);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Abnormality types',
          subtitle: 'Cycle-event and quality classification',
          icon: Icons.rule_folder_outlined,
          accent: BafColors.charges,
        ),
        actions: [
          IconButton(
            tooltip: 'Seed RA coil colour type',
            icon: const Icon(Icons.auto_fix_high_rounded),
            color: BafColors.audit,
            onPressed: _seedDefaults,
          ),
        ],
      ),
      body: typesAsync.when(
        loading: () => AbnormalityTypeUnavailableState(
          state: const BafLoadingPanel(
            label: 'Loading abnormality types',
            color: BafColors.charges,
          ),
          onCreate: () => _showTypeForm(),
        ),
        error: (err, _) => AbnormalityTypeUnavailableState(
          state: _StateCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load abnormality types',
            message: '$err',
            color: BafColors.danger,
          ),
          onCreate: () => _showTypeForm(),
        ),
        data: (types) {
          final matchingSearch = types.where((type) {
            final query = _searchQuery.trim().toLowerCase();
            if (query.isEmpty) return true;

            return type.code.toLowerCase().contains(query) ||
                type.title.toLowerCase().contains(query) ||
                (type.description ?? '').toLowerCase().contains(query) ||
                type.category.name.toLowerCase().contains(query);
          }).toList();
          final visible = matchingSearch
              .where(
                (type) => switch (_statusFilter) {
                  _TypeStatusFilter.all => true,
                  _TypeStatusFilter.active => type.isActive,
                  _TypeStatusFilter.inactive => !type.isActive,
                },
              )
              .toList();

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  BafSpacing.lg,
                  BafSpacing.lg,
                  BafSpacing.lg,
                  BafSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: _HeaderCard(
                    total: matchingSearch.length,
                    active: matchingSearch
                        .where((type) => type.isActive)
                        .length,
                    inactive: matchingSearch
                        .where((type) => !type.isActive)
                        .length,
                    selected: _statusFilter,
                    onSelected: (value) =>
                        setState(() => _statusFilter = value),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  BafSpacing.lg,
                  BafSpacing.sm,
                  BafSpacing.lg,
                  BafSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: AbnormalityTypeToolbar(
                    onSearchChanged: (value) =>
                        setState(() => _searchQuery = value),
                    onCreate: () => _showTypeForm(),
                  ),
                ),
              ),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _StateCard(
                    icon: Icons.rule_folder_outlined,
                    title: 'No abnormality types found',
                    message: types.isEmpty
                        ? 'Create master data first. Operators will later select from this list while logging abnormalities.'
                        : 'No types match this search and status. Select Total to show all statuses, or change the search.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.lg,
                    BafSpacing.xs,
                    BafSpacing.lg,
                    112,
                  ),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final type = visible[index];

                      return _AbnormalityTypeCard(
                        type: type,
                        onEdit: () => _showTypeForm(existing: type),
                        onDelete: type.isRaCoilColourType
                            ? null
                            : () => _confirmDelete(type),
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

  Future<void> _seedDefaults() async {
    final actor = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor;
    if (actor == null || !actor.canManageAbnormalityTypes) {
      _showAbnormalityTypeSnack(
        'Only Admin can seed abnormality type master data.',
        color: BafColors.danger,
      );
      return;
    }

    try {
      final repository = ref.read(abnormalityRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.seedDefaultTypes(actor: actor);

      final syncOutcome = kIsWeb
          ? SyncRequestOutcome.succeeded
          : await syncCoordinator.runFullSyncWithResult(
              reason: 'abnormality_type_seeded',
              force: true,
            );

      if (!mounted) return;

      final message = switch (syncOutcome) {
        SyncRequestOutcome.succeeded =>
          'Default abnormality types checked and synchronized.',
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled =>
          'Default abnormality types checked on this device; synchronization is queued.',
        SyncRequestOutcome.partial =>
          'Partly synced. Server data was refreshed, but some saved changes still need attention. Check Sync health for details.',
        SyncRequestOutcome.failed =>
          'Default abnormality types were checked locally, but cloud synchronization needs attention.',
      };
      _showAbnormalityTypeSnack(
        message,
        color: syncOutcome.isPartial
            ? BafColors.warning
            : syncOutcome == SyncRequestOutcome.failed
            ? BafColors.danger
            : null,
      );
    } catch (e) {
      if (!mounted) return;

      _showAbnormalityTypeSnack('Seeding failed: $e', color: BafColors.danger);
    }
  }

  Future<void> _showTypeForm({AbnormalityType? existing}) async {
    final actor = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor;

    if (actor == null || !actor.canManageAbnormalityTypes) {
      _showAbnormalityTypeSnack(
        'Only Admin can manage abnormality type master data.',
        color: BafColors.danger,
      );
      return;
    }

    final syncOutcome = await showDialog<SyncRequestOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CurrentActorDialogGuard(
        originUid: actor.uid,
        permission: (user) => user.canManageAbnormalityTypes,
        child: _AbnormalityTypeFormDialog(actor: actor, existing: existing),
      ),
    );

    if (!mounted || syncOutcome == null) {
      return;
    }

    final action = existing == null ? 'created' : 'updated';
    final message = switch (syncOutcome) {
      SyncRequestOutcome.succeeded =>
        'Abnormality type $action and synchronized.',
      SyncRequestOutcome.queued || SyncRequestOutcome.throttled =>
        'Abnormality type $action on this device; synchronization is queued.',
      SyncRequestOutcome.partial =>
        'Partly synced. Server data was refreshed, but some saved changes still need attention. Check Sync health for details.',
      SyncRequestOutcome.failed =>
        'Abnormality type $action on this device, but cloud synchronization needs attention.',
    };
    _showAbnormalityTypeSnack(
      message,
      color: syncOutcome.isPartial
          ? BafColors.warning
          : syncOutcome == SyncRequestOutcome.failed
          ? BafColors.danger
          : null,
    );
  }

  Future<void> _confirmDelete(AbnormalityType type) async {
    final actor = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor;

    if (actor == null || !actor.canManageAbnormalityTypes) {
      _showAbnormalityTypeSnack(
        'Only Admin can delete abnormality type master data.',
        color: BafColors.danger,
      );
      return;
    }

    final decision = await showDialog<_AbnormalityTypeDeleteDecision>(
      context: context,
      builder: (_) => CurrentActorDialogGuard(
        originUid: actor.uid,
        permission: (user) => user.canManageAbnormalityTypes,
        child: _AbnormalityTypeDeleteDialog(type: type),
      ),
    );

    if (!mounted || decision == null) {
      return;
    }

    if (currentActorActionMessage(
          CurrentActorAccess.resolve(ref.read(currentAppUserProvider)),
          originUid: actor.uid,
          permission: (user) => user.canManageAbnormalityTypes,
        ) !=
        null) {
      return;
    }
    final dynamic id = kIsWeb ? type.firestoreId : type.id;

    if (id == null) {
      _showAbnormalityTypeSnack(
        'Abnormality type ID is missing',
        color: BafColors.warning,
      );
      return;
    }

    try {
      final repository = ref.read(abnormalityRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.softDeleteType(
        id,
        actor: actor,
        auditContext: AuditContext(
          performedByUid: actor.uid,
          performedByName: actor.name,
          reason: decision.reason,
          reasonNotes: decision.notes,
          before: type.toAuditMap(),
        ),
      );

      final syncOutcome = kIsWeb
          ? SyncRequestOutcome.succeeded
          : await syncCoordinator.runFullSyncWithResult(
              reason: 'abnormality_type_deleted',
              force: true,
            );

      if (!mounted) return;

      final message = switch (syncOutcome) {
        SyncRequestOutcome.succeeded =>
          'Abnormality type marked as deleted and synchronized.',
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled =>
          'Abnormality type marked as deleted on this device; synchronization is queued.',
        SyncRequestOutcome.partial =>
          'Partly synced. Server data was refreshed, but some saved changes still need attention. Check Sync health for details.',
        SyncRequestOutcome.failed =>
          'Abnormality type marked as deleted on this device, but cloud synchronization needs attention.',
      };
      _showAbnormalityTypeSnack(
        message,
        color: syncOutcome.isPartial
            ? BafColors.warning
            : syncOutcome == SyncRequestOutcome.failed
            ? BafColors.danger
            : null,
      );
    } catch (e) {
      if (!mounted) return;

      _showAbnormalityTypeSnack('Delete failed: $e', color: BafColors.danger);
    }
  }

  void _showAbnormalityTypeSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

class _AbnormalityTypeFormDialog extends ConsumerStatefulWidget {
  final AppUser actor;
  final AbnormalityType? existing;

  const _AbnormalityTypeFormDialog({
    required this.actor,
    required this.existing,
  });

  @override
  ConsumerState<_AbnormalityTypeFormDialog> createState() =>
      _AbnormalityTypeFormDialogState();
}

class _AbnormalityTypeFormDialogState
    extends ConsumerState<_AbnormalityTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late AbnormalityCategory _selectedCategory;
  late AbnormalitySeverity _selectedSeverity;
  late Set<AssetType> _selectedAssets;
  late bool _suggestsReannealing;
  late bool _isActive;
  bool _isSaving = false;

  AbnormalityType? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    _codeController = TextEditingController(text: existing?.code ?? '');
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _selectedCategory = existing?.category ?? AbnormalityCategory.process;
    _selectedSeverity = existing?.severity ?? AbnormalitySeverity.medium;
    _selectedAssets = Set<AssetType>.from(
      existing?.applicableAssetTypes ?? const <AssetType>[],
    );
    _suggestsReannealing = existing?.suggestsReannealing ?? false;
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    return AlertDialog(
      title: Text(
        existing == null ? 'Create Abnormality Type' : 'Edit Abnormality Type',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  enabled:
                      !_isSaving &&
                      (existing == null || !existing.isRaCoilColourType),
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration(
                    label: 'Code',
                    hint: 'Example: FURNACE_STUCK',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Required';
                    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(text)) {
                      return 'Use letters, numbers and underscore only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  decoration: _inputDecoration(
                    label: 'Title',
                    hint: 'Example: Furnace Getting Stuck',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSaving,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    label: 'Description',
                    hint: 'Explain when this abnormality type should be used',
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                DropdownButtonFormField<AbnormalityCategory>(
                  isExpanded: true,
                  initialValue: _selectedCategory,
                  decoration: _inputDecoration(label: 'Category'),
                  items: AbnormalityCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_categoryLabel(category)),
                    );
                  }).toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedCategory = value);
                        },
                ),
                const SizedBox(height: BafSpacing.md),
                DropdownButtonFormField<AbnormalitySeverity>(
                  isExpanded: true,
                  initialValue: _selectedSeverity,
                  decoration: _inputDecoration(label: 'Default Severity'),
                  items: AbnormalitySeverity.values.map((severity) {
                    return DropdownMenuItem(
                      value: severity,
                      child: Text(_severityLabel(severity)),
                    );
                  }).toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedSeverity = value);
                        },
                ),
                const SizedBox(height: BafSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Applicable Assets',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: BafColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.sm,
                    children: AssetType.values.map((assetType) {
                      final selected = _selectedAssets.contains(assetType);
                      return FilterChip(
                        label: Text(_assetTypeLabel(assetType)),
                        selected: selected,
                        selectedColor: BafColors.assets.withValues(alpha: 0.14),
                        checkmarkColor: BafColors.assets,
                        side: BorderSide(
                          color: selected
                              ? BafColors.assets.withValues(alpha: 0.35)
                              : BafColors.border,
                        ),
                        onSelected: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  if (value) {
                                    _selectedAssets.add(assetType);
                                  } else {
                                    _selectedAssets.remove(assetType);
                                  }
                                });
                              },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: BafSpacing.lg),
                SwitchListTile(
                  value: _suggestsReannealing,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: BafColors.audit,
                  title: const Text('Suggests RA'),
                  subtitle: const Text(
                    'Use this when the type commonly needs an RA decision.',
                  ),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _suggestsReannealing = value),
                ),
                SwitchListTile(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: BafColors.success,
                  title: const Text('Active'),
                  subtitle: const Text(
                    'Inactive types stay in history but are hidden from normal entry lists.',
                  ),
                  onChanged: _isSaving || existing?.isRaCoilColourType == true
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.navy,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final access = CurrentActorAccess.resolve(ref.read(currentAppUserProvider));
    final message = currentActorActionMessage(
      access,
      originUid: widget.actor.uid,
      permission: (user) => user.canManageAbnormalityTypes,
    );
    if (message != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final actor = access.actor!;
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final existing = _existing;
    final beforeSnapshot = existing?.toAuditMap();

    try {
      final now = DateTime.now();
      final code = _normalizeCode(_codeController.text);
      final record = existing == null
          ? AbnormalityType()
          : copyAbnormalityType(existing);

      if (existing == null) {
        record
          ..firestoreId = const Uuid().v4()
          ..createdAt = now
          ..createdByUid = actor.uid
          ..createdByName = actor.name
          ..version = 1;
      }

      record
        ..code = existing?.isRaCoilColourType == true ? existing!.code : code
        ..title = _titleController.text.trim()
        ..description = _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim()
        ..category = _selectedCategory
        ..severity = _selectedSeverity
        ..applicableAssetTypes = _selectedAssets.toList()
        ..suggestsReannealing = _suggestsReannealing
        ..isActive = _isActive
        ..isDeleted = false
        ..updatedAt = now
        ..lastEditedByUid = actor.uid
        ..lastEditedByName = actor.name
        ..isSynced = false;

      final auditContext = AuditContext(
        performedByUid: actor.uid,
        performedByName: actor.name,
        reasonNotes: existing == null
            ? 'Created abnormality type'
            : 'Updated abnormality type',
        before: beforeSnapshot,
      );

      final repository = ref.read(abnormalityRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      if (existing == null) {
        await repository.saveType(
          record,
          actor: actor,
          auditContext: auditContext,
        );
      } else {
        await repository.updateType(
          record,
          actor: actor,
          auditContext: auditContext,
        );
      }

      final syncOutcome = kIsWeb
          ? SyncRequestOutcome.succeeded
          : await syncCoordinator.runFullSyncWithResult(
              reason: existing == null
                  ? 'abnormality_type_created'
                  : 'abnormality_type_edited',
              force: true,
            );

      if (!mounted) return;
      Navigator.pop(context, syncOutcome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }
}

class _AbnormalityTypeDeleteDecision {
  final AuditReason? reason;
  final String? notes;

  const _AbnormalityTypeDeleteDecision({this.reason, this.notes});
}

class _AbnormalityTypeDeleteDialog extends StatefulWidget {
  final AbnormalityType type;

  const _AbnormalityTypeDeleteDialog({required this.type});

  @override
  State<_AbnormalityTypeDeleteDialog> createState() =>
      _AbnormalityTypeDeleteDialogState();
}

class _AbnormalityTypeDeleteDialogState
    extends State<_AbnormalityTypeDeleteDialog> {
  late final TextEditingController _reasonController;
  AuditReason? _selectedReason;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark Abnormality Type as Deleted'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '"${widget.type.title}" will be hidden from active selection but retained for audit and historical records.',
                style: const TextStyle(color: BafColors.textSecondary),
              ),
              const SizedBox(height: BafSpacing.md),
              DropdownButtonFormField<AuditReason>(
                isExpanded: true,
                decoration: _inputDecoration(label: 'Reason', hint: 'Optional'),
                initialValue: _selectedReason,
                items: AuditReason.values.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(_auditReasonLabel(reason)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedReason = value),
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                textInputAction: TextInputAction.newline,
                decoration: _inputDecoration(
                  label: 'Additional notes',
                  hint: 'Optional',
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
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(
            context,
            _AbnormalityTypeDeleteDecision(
              reason: _selectedReason,
              notes: _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
            ),
          ),
          child: const Text('Mark Deleted'),
        ),
      ],
    );
  }
}

String _normalizeCode(String raw) {
  return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');
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
