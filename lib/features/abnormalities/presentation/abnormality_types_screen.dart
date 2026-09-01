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
import '../../maintenance/data/maintenance_model.dart';
import '../data/abnormality_model.dart';
import '../providers/abnormality_provider.dart';

class AbnormalityTypesScreen extends ConsumerStatefulWidget {
  const AbnormalityTypesScreen({super.key});

  @override
  ConsumerState<AbnormalityTypesScreen> createState() =>
      _AbnormalityTypesScreenState();
}

class _AbnormalityTypesScreenState
    extends ConsumerState<AbnormalityTypesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).value;
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
        loading:
            () => const BafLoadingPanel(
              label: 'Loading abnormality types',
              color: BafColors.charges,
            ),
        error:
            (err, _) => _StateCard(
              icon: Icons.error_outline_rounded,
              title: 'Could not load abnormality types',
              message: '$err',
              color: BafColors.danger,
            ),
        data: (types) {
          final visible =
              types.where((type) {
                final query = _searchQuery.trim().toLowerCase();
                if (query.isEmpty) return true;

                return type.code.toLowerCase().contains(query) ||
                    type.title.toLowerCase().contains(query) ||
                    (type.description ?? '').toLowerCase().contains(query) ||
                    type.category.name.toLowerCase().contains(query);
              }).toList();

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
                    total: types.length,
                    active: types.where((type) => type.isActive).length,
                    inactive: types.where((type) => !type.isActive).length,
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
                  child: _AbnormalityTypeToolbar(
                    onSearchChanged:
                        (value) => setState(() => _searchQuery = value),
                    onCreate: () => _showTypeForm(),
                  ),
                ),
              ),
              if (visible.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _StateCard(
                    icon: Icons.rule_folder_outlined,
                    title: 'No abnormality types found',
                    message:
                        'Create master data first. Operators will later select from this list while logging abnormalities.',
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
                        onDelete:
                            type.isRaCoilColourType
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
    final actor = ref.read(currentAppUserProvider).value;
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

      final syncOutcome =
          kIsWeb
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
        SyncRequestOutcome.failed =>
          'Default abnormality types were checked locally, but cloud synchronization needs attention.',
      };
      _showAbnormalityTypeSnack(
        message,
        color:
            syncOutcome == SyncRequestOutcome.failed ? BafColors.danger : null,
      );
    } catch (e) {
      if (!mounted) return;

      _showAbnormalityTypeSnack('Seeding failed: $e', color: BafColors.danger);
    }
  }

  Future<void> _showTypeForm({AbnormalityType? existing}) async {
    final actor = ref.read(currentAppUserProvider).value;

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
      builder:
          (_) => _AbnormalityTypeFormDialog(actor: actor, existing: existing),
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
      SyncRequestOutcome.failed =>
        'Abnormality type $action on this device, but cloud synchronization needs attention.',
    };
    _showAbnormalityTypeSnack(
      message,
      color: syncOutcome == SyncRequestOutcome.failed ? BafColors.danger : null,
    );
  }

  Future<void> _confirmDelete(AbnormalityType type) async {
    final actor = ref.read(currentAppUserProvider).value;

    if (actor == null || !actor.canManageAbnormalityTypes) {
      _showAbnormalityTypeSnack(
        'Only Admin can delete abnormality type master data.',
        color: BafColors.danger,
      );
      return;
    }

    final decision = await showDialog<_AbnormalityTypeDeleteDecision>(
      context: context,
      builder: (_) => _AbnormalityTypeDeleteDialog(type: type),
    );

    if (!mounted || decision == null) {
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

      final syncOutcome =
          kIsWeb
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
        SyncRequestOutcome.failed =>
          'Abnormality type marked as deleted on this device, but cloud synchronization needs attention.',
      };
      _showAbnormalityTypeSnack(
        message,
        color:
            syncOutcome == SyncRequestOutcome.failed ? BafColors.danger : null,
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
                  items:
                      AbnormalityCategory.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(_categoryLabel(category)),
                        );
                      }).toList(),
                  onChanged:
                      _isSaving
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
                  items:
                      AbnormalitySeverity.values.map((severity) {
                        return DropdownMenuItem(
                          value: severity,
                          child: Text(_severityLabel(severity)),
                        );
                      }).toList(),
                  onChanged:
                      _isSaving
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
                    children:
                        AssetType.values.map((assetType) {
                          final selected = _selectedAssets.contains(assetType);
                          return FilterChip(
                            label: Text(_assetTypeLabel(assetType)),
                            selected: selected,
                            selectedColor: BafColors.assets.withValues(
                              alpha: 0.14,
                            ),
                            checkmarkColor: BafColors.assets,
                            side: BorderSide(
                              color:
                                  selected
                                      ? BafColors.assets.withValues(alpha: 0.35)
                                      : BafColors.border,
                            ),
                            onSelected:
                                _isSaving
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
                  onChanged:
                      _isSaving
                          ? null
                          : (value) =>
                              setState(() => _suggestsReannealing = value),
                ),
                SwitchListTile(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: BafColors.success,
                  title: const Text('Active'),
                  subtitle: const Text(
                    'Inactive types stay in history but are hidden from normal entry lists.',
                  ),
                  onChanged:
                      _isSaving || existing?.isRaCoilColourType == true
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
          child:
              _isSaving
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
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final existing = _existing;
    final beforeSnapshot = existing?.toAuditMap();

    try {
      final now = DateTime.now();
      final code = _normalizeCode(_codeController.text);
      final record =
          existing == null ? AbnormalityType() : copyAbnormalityType(existing);

      if (existing == null) {
        record
          ..firestoreId = const Uuid().v4()
          ..createdAt = now
          ..createdByUid = widget.actor.uid
          ..createdByName = widget.actor.name
          ..version = 1;
      }

      record
        ..code = existing?.isRaCoilColourType == true ? existing!.code : code
        ..title = _titleController.text.trim()
        ..description =
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim()
        ..category = _selectedCategory
        ..severity = _selectedSeverity
        ..applicableAssetTypes = _selectedAssets.toList()
        ..suggestsReannealing = _suggestsReannealing
        ..isActive = _isActive
        ..isDeleted = false
        ..updatedAt = now
        ..lastEditedByUid = widget.actor.uid
        ..lastEditedByName = widget.actor.name
        ..isSynced = false;

      final auditContext = AuditContext(
        performedByUid: widget.actor.uid,
        performedByName: widget.actor.name,
        reasonNotes:
            existing == null
                ? 'Created abnormality type'
                : 'Updated abnormality type',
        before: beforeSnapshot,
      );

      final repository = ref.read(abnormalityRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      if (existing == null) {
        await repository.saveType(
          record,
          actor: widget.actor,
          auditContext: auditContext,
        );
      } else {
        await repository.updateType(
          record,
          actor: widget.actor,
          auditContext: auditContext,
        );
      }

      final syncOutcome =
          kIsWeb
              ? SyncRequestOutcome.succeeded
              : await syncCoordinator.runFullSyncWithResult(
                reason:
                    existing == null
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
                items:
                    AuditReason.values.map((reason) {
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
          onPressed:
              () => Navigator.pop(
                context,
                _AbnormalityTypeDeleteDecision(
                  reason: _selectedReason,
                  notes:
                      _reasonController.text.trim().isEmpty
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

// ─────────────────────────────────────────────────────────────
// UI WIDGETS
// ─────────────────────────────────────────────────────────────

class _AbnormalityTypeToolbar extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;

  const _AbnormalityTypeToolbar({
    required this.onSearchChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      decoration: InputDecoration(
        hintText: 'Search by code, title or category',
        hintStyle: const TextStyle(color: BafColors.textSecondary),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: BafColors.textSecondary,
        ),
        filled: true,
        fillColor: BafColors.card,
        isDense: true,
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
          borderSide: const BorderSide(color: BafColors.navySoft, width: 1.4),
        ),
      ),
      onChanged: onSearchChanged,
    );
    final create = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: BafColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: BafSpacing.lg),
      ),
      onPressed: onCreate,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New type'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: BafSpacing.sm), create],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: BafSpacing.md),
            create,
          ],
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int total;
  final int active;
  final int inactive;

  const _HeaderCard({
    required this.total,
    required this.active,
    required this.inactive,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      key: const ValueKey('abnormality-types-summary'),
      padding: const EdgeInsets.all(BafSpacing.md),
      backgroundColor: BafColors.navy,
      borderColor: BafColors.navySoft.withValues(alpha: 0.26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final introduction = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: const Icon(
                  Icons.rule_folder_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational abnormality master',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: BafSpacing.xs),
                    Text(
                      'Govern cycle-event choices and RA routing.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                introduction,
                const SizedBox(height: BafSpacing.md),
                Row(
                  children: [
                    Expanded(child: _MetricPill(label: 'Total', value: total)),
                    const SizedBox(width: BafSpacing.sm),
                    Expanded(
                      child: _MetricPill(label: 'Active', value: active),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    Expanded(
                      child: _MetricPill(label: 'Inactive', value: inactive),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: introduction),
              const SizedBox(width: BafSpacing.xl),
              _MetricPill(label: 'Total', value: total),
              const SizedBox(width: BafSpacing.sm),
              _MetricPill(label: 'Active', value: active),
              const SizedBox(width: BafSpacing.sm),
              _MetricPill(label: 'Inactive', value: inactive),
            ],
          );
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final int value;

  const _MetricPill({required this.label, required this.value});

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
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _AbnormalityTypeCard extends StatelessWidget {
  final AbnormalityType type;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _AbnormalityTypeCard({
    required this.type,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(type.category);

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
                  color: color,
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
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children: [
                          StatusBadge(
                            label: type.code,
                            color: BafColors.admin,
                            icon: Icons.tag_rounded,
                          ),
                          StatusBadge(
                            label: _categoryLabel(type.category),
                            color: color,
                            icon: Icons.category_rounded,
                          ),
                          StatusBadge(
                            label: _severityLabel(type.severity),
                            color: _severityColor(type.severity),
                            icon: Icons.priority_high_rounded,
                          ),
                          if (type.suggestsReannealing)
                            const StatusBadge(
                              label: 'RA',
                              color: BafColors.audit,
                              icon: Icons.repeat_rounded,
                            ),
                          StatusBadge(
                            label: type.isActive ? 'ACTIVE' : 'INACTIVE',
                            color:
                                type.isActive
                                    ? BafColors.success
                                    : BafColors.textSecondary,
                            icon:
                                type.isActive
                                    ? Icons.check_circle_rounded
                                    : Icons.pause_circle_outline_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: BafSpacing.md),
                      Text(
                        type.title,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((type.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: BafSpacing.xs),
                        Text(
                          type.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 13,
                            height: 1.28,
                          ),
                        ),
                      ],
                      const SizedBox(height: BafSpacing.md),
                      Wrap(
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children:
                            type.applicableAssetTypes.isEmpty
                                ? const [
                                  _SoftChip(
                                    icon: Icons.all_inclusive_rounded,
                                    label: 'All / unspecified assets',
                                  ),
                                ]
                                : type.applicableAssetTypes.map((assetType) {
                                  return _SoftChip(
                                    icon: _assetIcon(assetType),
                                    label: _assetTypeLabel(assetType),
                                  );
                                }).toList(),
                      ),
                      const SizedBox(height: BafSpacing.md),
                      Text(
                        'Updated ${DateFormat('dd MMM yyyy, HH:mm').format(type.updatedAt)}'
                        '${type.lastEditedByName == null ? '' : ' by ${type.lastEditedByName}'}',
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
                    tooltip:
                        type.isRaCoilColourType
                            ? 'Seeded RA type cannot be deleted'
                            : 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    color:
                        onDelete == null
                            ? BafColors.textSecondary.withValues(alpha: 0.45)
                            : BafColors.danger,
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

class _SoftChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: BafColors.assets),
      label: Text(label),
      labelStyle: const TextStyle(
        color: BafColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: BafColors.assets.withValues(alpha: 0.08),
      side: BorderSide(color: BafColors.assets.withValues(alpha: 0.16)),
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
    final effectiveColor = color ?? BafColors.navy;

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

InputDecoration _inputDecoration({required String label, String? hint}) {
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
      borderSide: const BorderSide(color: BafColors.navySoft, width: 1.4),
    ),
  );
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
