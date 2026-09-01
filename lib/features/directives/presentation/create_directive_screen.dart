// FILE: lib/features/directives/presentation/create_directive_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/operational_directive_model.dart';
import '../providers/operational_directive_provider.dart';
import '../../../features/maintenance/data/maintenance_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../planned_maintenance/domain/baf_tag_resolver_v2.dart';
import '../../maintenance/utils/asset_validator.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../auth/providers/auth_provider.dart';

class CreateDirectiveScreen extends ConsumerStatefulWidget {
  const CreateDirectiveScreen({super.key});

  @override
  ConsumerState<CreateDirectiveScreen> createState() =>
      _CreateDirectiveScreenState();
}

class _CreateDirectiveScreenState extends ConsumerState<CreateDirectiveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _assetNumberController = TextEditingController();

  bool _isSubmitting = false;

  AppRole? _directedTo;
  AssetType? _assetType;

  // Component Intelligence State
  final _tagController = TextEditingController();
  final _componentController = TextEditingController();

  String? _resolvedSystem;
  String? _resolvedSubsystem;
  List<String>? _resolvedPath;

  bool _isAutoResolved = false;
  bool _userOverrodeComponent = false;

  @override
  void initState() {
    super.initState();
    _componentController.addListener(() {
      if (!_isAutoResolved) return;
      _userOverrodeComponent = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _assetNumberController.dispose();
    _tagController.dispose();
    _componentController.dispose();
    super.dispose();
  }

  // Tag Resolution
  void _resolveTag(String rawTag) {
    final tag = rawTag.trim();
    _userOverrodeComponent = false;

    if (tag.isEmpty) {
      _clearAutoFields();
      return;
    }

    final result = BafTagResolverV2.resolveToMap(tag, assetContext: _assetType);
    final bool isResolved = result['isAutoResolved'] == true;

    if (!isResolved) {
      _clearAutoFields();
      return;
    }

    final path = result['hierarchyPath'];
    final safePath = path is List ? List<String>.from(path) : null;

    setState(() {
      _resolvedSystem = result['system'] as String?;
      _resolvedSubsystem = result['subsystem'] as String?;
      _resolvedPath = safePath;

      if (!_userOverrodeComponent && _componentController.text.trim().isEmpty) {
        _componentController.text = (result['component'] as String?) ?? '';
      }

      _isAutoResolved = true;
    });
  }

  void _clearAutoFields() {
    setState(() {
      _resolvedSystem = null;
      _resolvedSubsystem = null;
      _resolvedPath = null;
      _isAutoResolved = false;
      _userOverrodeComponent = false;
    });
  }

  String _cleanRequiredText(String value) => value.trim();

  String? _cleanOptionalText(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  int? _assetNumberForSubmit() {
    if (_assetType == null) return null;
    return int.tryParse(_assetNumberController.text.trim());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_directedTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target group')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final actor = ref.read(currentAppUserProvider).value;
      if (actor == null || !actor.canCreateDirective) {
        throw Exception('Not authorized to issue operational directives.');
      }
      if (!actor.directiveTargets.contains(_directedTo)) {
        throw Exception('Not authorized to direct instructions to this role.');
      }

      final now = DateTime.now();
      final tagText = _cleanOptionalText(_tagController.text)?.toUpperCase();
      final componentText = _cleanOptionalText(_componentController.text);

      final directive =
          OperationalDirective()
            ..firestoreId = const Uuid().v4()
            ..title = _cleanRequiredText(_titleController.text)
            ..description = _cleanRequiredText(_descController.text)
            ..directedTo = _directedTo!
            ..assetType = _assetType
            ..assetNumber = _assetNumberForSubmit()
            ..component = componentText
            ..tag = tagText
            ..subsystem = _cleanOptionalText(_resolvedSubsystem ?? '')
            ..hierarchyPath = _resolvedPath
            ..createdByUid = actor.uid
            ..createdByName = actor.name
            ..issuedByUid = actor.uid
            ..issuedByName = actor.name
            ..issuedAt = now
            ..isActive = true
            ..createdAt = now
            ..updatedAt = now
            ..version = 1
            ..isSynced = false;

      final repo = ref.read(directiveRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      await repo.saveDirective(directive, actor: actor);

      final syncOutcome =
          directive.isSynced
              ? SyncRequestOutcome.succeeded
              : await syncCoordinator.runFullSyncWithResult(
                reason: 'directive_created',
                force: true,
              );
      final (message, color) = switch (syncOutcome) {
        SyncRequestOutcome.succeeded => (
          'Directive issued and synchronized.',
          BafColors.sync,
        ),
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled => (
          'Directive saved on this device; synchronization is queued.',
          BafColors.warning,
        ),
        SyncRequestOutcome.failed => (
          'Directive saved on this device, but cloud synchronization needs attention.',
          BafColors.danger,
        ),
      };

      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.pop(context);
        messenger?.showSnackBar(
          SnackBar(content: Text(message), backgroundColor: color),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: BafColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
          icon == null
              ? null
              : Icon(icon, color: BafColors.textSecondary, size: 20),
      filled: true,
      fillColor: BafColors.background,
      labelStyle: const TextStyle(
        color: BafColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: BafColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: 14,
      ),
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
        borderSide: const BorderSide(color: BafColors.directives, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.danger, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).value;
    if (appUser == null || !appUser.canCreateDirective) {
      return const _DirectiveAccessDeniedScaffold();
    }
    final validTargets = appUser.directiveTargets;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Issue directive',
          subtitle: 'Route an operational instruction with accountability',
          icon: Icons.campaign_outlined,
          accent: BafColors.directives,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.lg,
            BafSpacing.lg,
            BafSpacing.lg,
            BafSpacing.xl,
          ),
          children: [
            _HeroCard(validTargetsCount: validTargets.length),
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Directive Details',
              subtitle: 'Define the instruction and the role responsible.',
              icon: Icons.campaign_rounded,
              accentColor: BafColors.directives,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: _fieldDecoration(
                    label: 'Title / Subject',
                    hint: 'Example: Isolate line before inspection',
                    icon: Icons.title_rounded,
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: BafSpacing.md),
                DropdownButtonFormField<AppRole>(
                  isExpanded: true,
                  initialValue: _directedTo,
                  hint: const Text('Select Target Role'),
                  decoration: _fieldDecoration(
                    label: 'Route To',
                    icon: Icons.groups_rounded,
                  ),
                  items:
                      validTargets
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _directedTo = v),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Target Asset',
              subtitle: 'Attach the directive to an asset when applicable.',
              icon: Icons.precision_manufacturing_rounded,
              accentColor: BafColors.assets,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useStacked = constraints.maxWidth < 360;

                    final typeField = DropdownButtonFormField<AssetType>(
                      isExpanded: true,
                      initialValue: _assetType,
                      decoration: _fieldDecoration(
                        label: 'Type (Optional)',
                        icon: Icons.category_rounded,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        ...AssetType.values.map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.name.toUpperCase()),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _assetType = v),
                    );

                    final numberField = TextFormField(
                      controller: _assetNumberController,
                      keyboardType: TextInputType.number,
                      enabled: _assetType != null,
                      decoration: _fieldDecoration(
                        label: 'Number',
                        icon: Icons.confirmation_number_outlined,
                      ),
                      validator: (value) {
                        // If no asset type selected, no validation (field is disabled anyway)
                        if (_assetType == null) return null;
                        if (value == null || value.trim().isEmpty) {
                          return 'Asset number is required when type is selected';
                        }
                        final number = int.tryParse(value.trim());
                        if (number == null) return 'Invalid number';
                        if (!AssetValidator.isValid(_assetType!, number)) {
                          return AssetValidator.getValidationMessage(
                            _assetType!,
                            number,
                          );
                        }
                        return null;
                      },
                    );

                    if (useStacked) {
                      return Column(
                        children: [
                          typeField,
                          const SizedBox(height: BafSpacing.md),
                          numberField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: typeField),
                        const SizedBox(width: BafSpacing.md),
                        Expanded(child: numberField),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Target Equipment / Tag',
              subtitle:
                  'Optional tag intelligence can auto-fill equipment context.',
              icon: Icons.account_tree_rounded,
              accentColor: BafColors.sync,
              children: [
                TextFormField(
                  controller: _tagController,
                  decoration: _fieldDecoration(
                    label: 'Instrument Tag',
                    hint: 'Example: FIT45',
                    icon: Icons.sell_outlined,
                  ),
                  onChanged: _resolveTag,
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _componentController,
                  decoration: _fieldDecoration(
                    label:
                        _isAutoResolved
                            ? 'Component (auto-filled, editable)'
                            : 'Component Name',
                    icon: Icons.memory_rounded,
                  ),
                ),
                if (_isAutoResolved) ...[
                  const SizedBox(height: BafSpacing.md),
                  _ResolvedTagCard(
                    system: _resolvedSystem,
                    subsystem: _resolvedSubsystem,
                  ),
                ],
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Instructions / Details',
              subtitle:
                  'Write clear, action-oriented instructions for the target role.',
              icon: Icons.notes_rounded,
              accentColor: BafColors.warning,
              children: [
                TextFormField(
                  controller: _descController,
                  minLines: 4,
                  maxLines: 7,
                  decoration: _fieldDecoration(
                    label: 'Detailed instructions',
                    hint:
                        'State the action, constraints, and expected outcome.',
                    icon: Icons.edit_note_rounded,
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomSubmitBar(
        isSubmitting: _isSubmitting,
        onSubmit: _isSubmitting ? null : _submit,
      ),
    );
  }
}

class _DirectiveAccessDeniedScaffold extends StatelessWidget {
  const _DirectiveAccessDeniedScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Issue directive',
          subtitle: 'Route an operational instruction with accountability',
          icon: Icons.campaign_outlined,
          accent: BafColors.directives,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.xl),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(BafSpacing.xl),
            decoration: BoxDecoration(
              color: BafColors.card,
              borderRadius: BorderRadius.circular(BafRadius.large),
              border: Border.all(color: BafColors.border),
              boxShadow: BafShadows.subtle,
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, color: BafColors.danger, size: 48),
                SizedBox(height: BafSpacing.md),
                Text(
                  'Directive creation access denied',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: BafSpacing.sm),
                Text(
                  'Only Admin/SI, Contract Supervisor, Shift Supervisor and Operations users can issue operational directives.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BafColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int validTargetsCount;

  const _HeroCard({required this.validTargetsCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.navy,
        borderRadius: BorderRadius.circular(BafRadius.large),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operational Directive',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  validTargetsCount == 0
                      ? 'No eligible targets loaded yet.'
                      : '$validTargetsCount eligible target group${validTargetsCount == 1 ? '' : 's'} available.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(icon, color: accentColor, size: 21),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 13,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _ResolvedTagCard extends StatelessWidget {
  final String? system;
  final String? subsystem;

  const _ResolvedTagCard({required this.system, required this.subsystem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.sync.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.sync.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 17, color: BafColors.sync),
              SizedBox(width: BafSpacing.sm),
              Text(
                'Tag Resolved',
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (system != null || subsystem != null) ...[
            const SizedBox(height: BafSpacing.sm),
            if (system != null)
              Text(
                'System: $system',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (subsystem != null)
              Text(
                'Subsystem: $subsystem',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BottomSubmitBar extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onSubmit;

  const _BottomSubmitBar({required this.isSubmitting, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          BafSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: BafColors.card,
          border: Border(top: BorderSide(color: BafColors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: BafColors.navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: BafColors.border,
              disabledForegroundColor: BafColors.textSecondary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BafRadius.medium),
              ),
            ),
            icon:
                isSubmitting
                    ? const SizedBox(
                      height: 19,
                      width: 19,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.send_rounded, size: 20),
            label: Text(
              isSubmitting ? 'Issuing directive...' : 'Issue Directive',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
