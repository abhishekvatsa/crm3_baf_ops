// FILE: lib/features/planned_maintenance/presentation/create_template_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/job_template_model.dart';
import '../providers/planned_maintenance_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/maintenance/data/maintenance_model.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';

class CreateTemplateScreen extends ConsumerStatefulWidget {
  const CreateTemplateScreen({super.key});

  @override
  ConsumerState<CreateTemplateScreen> createState() =>
      _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends ConsumerState<CreateTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  AssetType _assetType = AssetType.base;
  final Set<String> _selectedAgencies = {};
  bool _isSubmitting = false;

  final List<String> _availableAgencies = const [
    'electrical',
    'mechanical',
    'instrumentation',
    'refractory',
    'emd',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    if (_selectedAgencies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one agency'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null || !appUser.canCreateLegacyJobTemplate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Admin/SI can create job templates.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
      final now = DateTime.now();

      final createdByUid = appUser.uid;
      final createdByName = _cleanOptionalText(appUser.name) ??
          _cleanOptionalText(firebaseUser?.displayName) ??
          _cleanOptionalText(firebaseUser?.email);

      final template = JobTemplate()
        ..firestoreId = const Uuid().v4()
        ..jobName = _nameController.text.trim()
        ..description = _cleanOptionalText(_descController.text)
        ..applicableAssetType = _assetType
        ..assignedAgencies = (_selectedAgencies.toList()..sort())
        ..createdByUid = createdByUid
        ..createdByName = createdByName
        ..isActive = true
        ..isDeprecated = false
        ..version = 1
        ..isSynced = false
        ..createdAt = now
        ..updatedAt = now;

      template.setFields(<TemplateField>[]);

      final repository = ref.read(plannedRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.saveTemplate(
        template,
        actor: appUser,
      );

      unawaited(
        syncCoordinator.runFullSync(reason: 'template_created', force: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Template created'),
          backgroundColor: BafColors.sync,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to create template: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).value;
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    final appUserName = _cleanOptionalText(appUser?.name) ??
        _cleanOptionalText(firebaseUser?.displayName) ??
        _cleanOptionalText(firebaseUser?.email);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('New Template'),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.lg,
            BafSpacing.md,
            BafSpacing.lg,
            BafSpacing.xl,
          ),
          children: [
            _IntroCard(appUserName: appUserName),
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Template details',
              subtitle: 'Define the planned job name and purpose.',
              icon: Icons.description_rounded,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    'Job name',
                    hint: 'e.g. Base full maintenance',
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
                  controller: _descController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    'Description',
                    hint: 'Optional context shown to the attending team',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Asset context',
              subtitle: 'Choose where this template applies.',
              icon: Icons.precision_manufacturing_rounded,
              children: [
                DropdownButtonFormField<AssetType>(
                  initialValue: _assetType,
                  isExpanded: true,
                  decoration: _inputDecoration('Asset type'),
                  items: AssetType.values
                      .map(
                        (type) => DropdownMenuItem<AssetType>(
                      value: type,
                      child: Text(
                        _assetTypeLabel(type),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _assetType = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Responsible agencies',
              subtitle: 'Select all teams responsible for this planned job.',
              icon: Icons.groups_rounded,
              children: [
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.sm,
                  children: _availableAgencies.map((agency) {
                    final selected = _selectedAgencies.contains(agency);
                    return FilterChip(
                      label: Text(
                        _agencyLabel(agency),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? BafColors.planned
                              : BafColors.textSecondary,
                        ),
                      ),
                      selected: selected,
                      selectedColor: BafColors.planned.withValues(alpha: 0.12),
                      checkmarkColor: BafColors.planned,
                      side: BorderSide(
                        color: selected
                            ? BafColors.planned.withValues(alpha: 0.45)
                            : BafColors.border,
                      ),
                      backgroundColor: BafColors.card,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedAgencies.add(agency);
                          } else {
                            _selectedAgencies.remove(agency);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _CreateTemplateBottomBar(
        isSubmitting: _isSubmitting,
        onSubmit: _isSubmitting ? null : _submit,
      ),
    );
  }

  InputDecoration _inputDecoration(
      String label, {
        String? hint,
        bool alignLabelWithHint = false,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: BafColors.card,
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
        borderSide: const BorderSide(
          color: BafColors.planned,
          width: 1.5,
        ),
      ),
    );
  }

  String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.base:
        return 'BASE';
      case AssetType.furnace:
        return 'FURNACE';
      case AssetType.forceCooler:
        return 'FORCE COOLER';
      case AssetType.innerCover:
        return 'INNER COVER';
    }
  }

  String _agencyLabel(String agency) {
    switch (agency) {
      case 'emd':
        return 'EMD';
      case 'instrumentation':
        return 'I&A';
      default:
        return agency.toUpperCase();
    }
  }
}


class _CreateTemplateBottomBar extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onSubmit;

  const _CreateTemplateBottomBar({
    required this.isSubmitting,
    required this.onSubmit,
  });

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
        child: FilledButton.icon(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.planned,
            foregroundColor: Colors.white,
            disabledBackgroundColor: BafColors.border,
            disabledForegroundColor: BafColors.textSecondary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
          ),
          icon: isSubmitting
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : const Icon(Icons.add_task_rounded),
          label: Text(
            isSubmitting ? 'Creating...' : 'Create Template',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String? appUserName;

  const _IntroCard({this.appUserName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(
          color: BafColors.planned.withValues(alpha: 0.18),
        ),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BafColors.planned.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: BafColors.planned,
              size: 30,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create planned job template',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Start with the job identity. Add checklist fields in the designer next.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (appUserName != null && appUserName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  StatusBadge(
                    label: 'Creating as $appUserName',
                    color: BafColors.planned,
                    icon: Icons.person_outline_rounded,
                  ),
                ],
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
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
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
              Icon(icon, color: BafColors.planned, size: 22),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
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
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

String? _cleanOptionalText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
