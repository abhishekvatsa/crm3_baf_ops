// FILE: lib/features/planned_maintenance/presentation/published_template_assignment_screen.dart

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/models/audit_event_model.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/utils/asset_validator.dart';
import '../data/template_governance_model.dart';
import '../domain/template_version_assignment_builder.dart';
import '../providers/job_module_provider.dart';
import '../providers/planned_maintenance_provider.dart';
import '../providers/template_governance_provider.dart';
import 'template_publisher_screen.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../data/job_module_model.dart';

class PublishedTemplateAssignmentScreen extends ConsumerStatefulWidget {
  const PublishedTemplateAssignmentScreen({super.key});

  @override
  ConsumerState<PublishedTemplateAssignmentScreen> createState() =>
      _PublishedTemplateAssignmentScreenState();
}

class _PublishedTemplateAssignmentScreenState
    extends ConsumerState<PublishedTemplateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetNumberController = TextEditingController();
  final _chargeNoController = TextEditingController();
  final _remarksController = TextEditingController();

  String? _selectedPackageId;
  String? _selectedVersionId;
  AssetType _assetType = AssetType.base;
  bool _assetTypeTouched = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _assetNumberController.dispose();
    _chargeNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(currentAppUserProvider);

    return appUserAsync.when(
      loading: () => const Scaffold(
        backgroundColor: BafColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _AssignmentErrorScaffold(message: 'User error: $e'),
      data: (actor) {
        if (actor == null || !actor.canAssignJobExecution) {
          return const _AssignmentAccessDeniedScaffold();
        }

        final packagesAsync = ref.watch(templatePackagesProvider);
        return packagesAsync.when(
          loading: () => const Scaffold(
            backgroundColor: BafColors.background,
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _AssignmentErrorScaffold(
            message: 'Template package error: $e',
          ),
          data: (packages) => _buildWithPackages(actor, packages),
        );
      },
    );
  }

  Widget _buildWithPackages(AppUser actor, List<TemplatePackage> packages) {
    final assignablePackages = packages
        .where((package) =>
    !package.isDeleted &&
        package.lifecycleStatus == TemplatePackageLifecycleStatus.active &&
        _clean(package.firestoreId) != null)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    _hydrateInitialPackage(assignablePackages);

    final selectedPackage = _findPackage(assignablePackages, _selectedPackageId);
    final versionsAsync = selectedPackage == null
        ? null
        : ref.watch(packageVersionsProvider(selectedPackage.firestoreId!));

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Assign Published Catalogue'),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
        actions: [
          if (actor.canManageTemplateGovernance)
            IconButton(
              tooltip: 'Open Template Publisher',
              onPressed: _openTemplatePublisher,
              icon: const Icon(Icons.publish_rounded),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: versionsAsync == null
            ? _buildNoPackagesState(actor, assignablePackages)
            : versionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _InlineError(message: 'Version error: $e'),
          data: (versions) {
            final assignableVersions = versions
                .where((version) => version.isAssignable)
                .toList()
              ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
            _hydrateInitialVersion(selectedPackage!, assignableVersions);
            final selectedVersion =
            _findVersion(assignableVersions, _selectedVersionId);
            TemplateVersionAssignmentPreview? preview;
            TemplateVersionAssignmentException? previewError;
            if (selectedVersion != null) {
              try {
                preview = previewTemplateVersionAssignment(
                  package: selectedPackage,
                  version: selectedVersion,
                );
              } on TemplateVersionAssignmentException catch (error) {
                previewError = error;
              }
            }

            if (preview != null && !_assetTypeTouched) {
              _assetType = preview.assetType;
            }

            return ListView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.lg,
                BafSpacing.md,
                BafSpacing.lg,
                120,
              ),
              children: [
                _AssignmentHeaderCard(
                  package: selectedPackage,
                  version: selectedVersion,
                  preview: preview,
                ),
                if (previewError != null) ...[
                  const SizedBox(height: BafSpacing.md),
                  _PublisherPromptCallout(
                    message:
                    'This published version cannot be assigned because its governance snapshot is invalid: ${previewError.message}',
                    onOpenPublisher: actor.canManageTemplateGovernance
                        ? _openTemplatePublisher
                        : null,
                  ),
                ],
                const SizedBox(height: BafSpacing.lg),
                _SectionCard(
                  title: 'Governed catalogue source',
                  subtitle:
                  'Choose the active package/version to freeze into this job.',
                  icon: Icons.verified_rounded,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey('published-package-selector'),
                      initialValue: _selectedPackageId,
                      isExpanded: true,
                      decoration: _inputDecoration(
                        'Template package',
                        icon: Icons.inventory_2_rounded,
                      ),
                      items: assignablePackages
                          .map(
                            (package) => DropdownMenuItem<String>(
                          value: package.firestoreId,
                          child: Text(
                            '${package.packageCode} — ${package.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() {
                        _selectedPackageId = value;
                        _selectedVersionId = null;
                        _assetTypeTouched = false;
                      }),
                      validator: (value) => value == null
                          ? 'Select a governed package'
                          : null,
                    ),
                    const SizedBox(height: BafSpacing.md),
                    DropdownButtonFormField<String>(
                      key: ValueKey('published-version-${_selectedPackageId ?? ''}'),
                      initialValue: _selectedVersionId,
                      isExpanded: true,
                      decoration: _inputDecoration(
                        'Published version',
                        icon: Icons.new_releases_rounded,
                      ),
                      items: assignableVersions
                          .map(
                            (version) => DropdownMenuItem<String>(
                          value: version.firestoreId,
                          child: Text(
                            _versionLabel(version),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() {
                        _selectedVersionId = value;
                        _assetTypeTouched = false;
                      }),
                      validator: (value) => value == null
                          ? 'Select a published version'
                          : null,
                    ),
                    if (assignableVersions.isEmpty) ...[
                      const SizedBox(height: BafSpacing.sm),
                      _PublisherPromptCallout(
                        message:
                        'This package has no active published TemplateVersion. Publish a valid version before assigning governed jobs.',
                        onOpenPublisher: actor.canManageTemplateGovernance
                            ? _openTemplatePublisher
                            : null,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: BafSpacing.lg),
                _SectionCard(
                  title: 'Job details',
                  subtitle:
                  'Choose the exact asset and add assignment context.',
                  icon: Icons.assignment_turned_in_rounded,
                  children: [
                    DropdownButtonFormField<AssetType>(
                      key: ValueKey('asset-type-${_selectedVersionId ?? ''}-${_assetType.name}'),
                      initialValue: _assetType,
                      decoration: _inputDecoration(
                        'Asset type',
                        icon: Icons.precision_manufacturing_rounded,
                      ),
                      items: AssetType.values
                          .map(
                            (type) => DropdownMenuItem<AssetType>(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        ),
                      )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() {
                        if (value != null) {
                          _assetType = value;
                          _assetTypeTouched = true;
                        }
                      }),
                    ),
                    const SizedBox(height: BafSpacing.md),
                    TextFormField(
                      controller: _assetNumberController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        '${_assetType.name.toUpperCase()} Number',
                        hint: 'e.g. 221',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final number = int.tryParse(value.trim());
                        if (number == null) return 'Invalid number';
                        if (!AssetValidator.isValid(_assetType, number)) {
                          return AssetValidator.getValidationMessage(
                            _assetType,
                            number,
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: BafSpacing.md),
                    TextFormField(
                      controller: _chargeNoController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        'Active charge number',
                        hint: 'Optional',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        return int.tryParse(text) == null
                            ? 'Invalid number'
                            : null;
                      },
                    ),
                    const SizedBox(height: BafSpacing.md),
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'Instructions / remarks',
                        hint: 'Optional notes for attending teams',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BafSpacing.lg),
                _ModulePreviewSection(preview: preview),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _AssignmentBottomBar(
        isSubmitting: _isSubmitting,
        onSubmit: _isSubmitting ? null : () => _submit(actor),
      ),
    );
  }

  Widget _buildNoPackagesState(AppUser actor, List<TemplatePackage> packages) {
    if (packages.isNotEmpty) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: _EmptyAssignmentState(
          onOpenPublisher:
          actor.canManageTemplateGovernance ? _openTemplatePublisher : null,
        ),
      ),
    );
  }

  Future<void> _openTemplatePublisher() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TemplatePublisherScreen()),
    );
  }

  void _hydrateInitialPackage(List<TemplatePackage> packages) {
    if (packages.isEmpty) {
      _selectedPackageId = null;
      return;
    }
    if (_selectedPackageId != null &&
        packages.any((package) => package.firestoreId == _selectedPackageId)) {
      return;
    }
    _selectedPackageId = packages.first.firestoreId;
  }

  void _hydrateInitialVersion(
      TemplatePackage package,
      List<TemplateVersion> versions,
      ) {
    if (_selectedVersionId != null &&
        versions.any((version) => version.firestoreId == _selectedVersionId)) {
      return;
    }
    if (versions.isEmpty) {
      _selectedVersionId = null;
      return;
    }
    final activeId = _clean(package.activeVersionFirestoreId);
    final active = activeId == null ? null : _findVersion(versions, activeId);
    _selectedVersionId = (active ?? versions.first).firestoreId;
  }

  TemplatePackage? _findPackage(List<TemplatePackage> packages, String? id) {
    if (id == null) return null;
    for (final package in packages) {
      if (package.firestoreId == id) return package;
    }
    return null;
  }

  TemplateVersion? _findVersion(List<TemplateVersion> versions, String? id) {
    if (id == null) return null;
    for (final version in versions) {
      if (version.firestoreId == id) return version;
    }
    return null;
  }

  Future<void> _submit(AppUser actor) async {
    if (!_formKey.currentState!.validate()) return;
    if (!actor.canAssignJobExecution) {
      _showSnack('Not authorized to assign planned jobs.', BafColors.danger);
      return;
    }

    final package = await _selectedPackage();
    final version = await _selectedVersion();
    if (!mounted) return;

    if (package == null || version == null) {
      _showSnack('Select a published catalogue version first.', BafColors.danger);
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final assignment = buildAssignmentFromPublishedTemplateVersion(
        package: package,
        version: version,
        actor: actor,
        assetNumber: int.parse(_assetNumberController.text.trim()),
        assetType: _assetType,
        chargeNoAtEvent: _parseOptionalInt(_chargeNoController.text),
        remarks: _clean(_remarksController.text),
      );

      final plannedRepository = ref.read(plannedRepositoryProvider);
      final jobModuleRepository = ref.read(jobModuleRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await plannedRepository.saveExecution(
        assignment.execution,
        actor: actor,
      );

      for (final module in assignment.modules) {
        if (!kIsWeb) {
          module.jobExecutionLocalId = assignment.execution.id;
        }
        await jobModuleRepository.saveModule(
          module,
          actor: actor,
          auditContext: AuditContext(
            performedByUid: actor.uid,
            performedByName: actor.name,
            summary: 'Assigned process module from published template version',
          ),
        );
      }

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'published_template_version_assigned',
          force: true,
        ),
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Assigned ${assignment.execution.templateName ?? 'published job'} with ${assignment.modules.length} module(s).',
          ),
          backgroundColor: BafColors.sync,
        ),
      );
    } on TemplateVersionAssignmentException catch (e) {
      if (!mounted) return;
      _showSnack(
        'Cannot assign published catalogue: ${e.message}',
        BafColors.danger,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to assign published catalogue: $e', BafColors.danger);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<TemplatePackage?> _selectedPackage() async {
    final id = _selectedPackageId;
    if (id == null) return null;
    return ref.read(templateGovernanceRepositoryProvider).getPackageByFirestoreId(id);
  }

  Future<TemplateVersion?> _selectedVersion() async {
    final id = _selectedVersionId;
    if (id == null) return null;
    return ref.read(templateGovernanceRepositoryProvider).getVersionByFirestoreId(id);
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  InputDecoration _inputDecoration(
      String label, {
        String? hint,
        IconData? icon,
        bool alignLabelWithHint = false,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
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
        borderSide: const BorderSide(color: BafColors.planned, width: 1.5),
      ),
    );
  }
}

class _AssignmentHeaderCard extends StatelessWidget {
  final TemplatePackage package;
  final TemplateVersion? version;
  final TemplateVersionAssignmentPreview? preview;

  const _AssignmentHeaderCard({
    required this.package,
    required this.version,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.planned.withValues(alpha: 0.18)),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Governed assignment',
            style: TextStyle(
              color: BafColors.planned,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            preview?.templateName ?? package.title,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.12,
            ),
          ),
          if (_clean(package.description) != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              package.description!.trim(),
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              StatusBadge(
                label: package.packageCode,
                color: BafColors.assets,
                icon: Icons.inventory_2_rounded,
              ),
              if (version != null)
                StatusBadge(
                  label: 'v${version!.versionNumber}',
                  color: BafColors.sync,
                  icon: Icons.verified_rounded,
                ),
              StatusBadge(
                label: '${preview?.modules.length ?? 0} modules',
                color: BafColors.planned,
                icon: Icons.view_module_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModulePreviewSection extends StatelessWidget {
  final TemplateVersionAssignmentPreview? preview;

  const _ModulePreviewSection({required this.preview});

  @override
  Widget build(BuildContext context) {
    final modules = preview?.modules ?? const <TemplateVersionModulePreview>[];
    return _SectionCard(
      title: 'Frozen module preview',
      subtitle:
      'These module snapshots will be copied into the runtime job. Later catalogue edits will not mutate this assignment.',
      icon: Icons.account_tree_rounded,
      children: [
        if (modules.isEmpty)
          const _InlineEmpty(
            text: 'No published modules found in this version.',
          )
        else
          ...modules.take(12).map((module) => _ModulePreviewTile(module: module)),
        if (modules.length > 12) ...[
          const SizedBox(height: BafSpacing.sm),
          Text(
            '+${modules.length - 12} more module(s)',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _ModulePreviewTile extends StatelessWidget {
  final TemplateVersionModulePreview module;

  const _ModulePreviewTile({required this.module});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _disciplineColor(module.discipline).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: Icon(
              Icons.view_module_rounded,
              color: _disciplineColor(module.discipline),
              size: 22,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${module.discipline.name} · ${module.fieldCount} field(s)',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_clean(module.code) != null)
            StatusBadge(label: module.code!, color: BafColors.admin),
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

class _AssignmentBottomBar extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onSubmit;

  const _AssignmentBottomBar({
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
              : const Icon(Icons.verified_rounded),
          label: Text(
            isSubmitting ? 'Assigning...' : 'Assign Published Job',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _EmptyAssignmentState extends StatelessWidget {
  final VoidCallback? onOpenPublisher;

  const _EmptyAssignmentState({this.onOpenPublisher});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.xl),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, color: BafColors.admin, size: 48),
          const SizedBox(height: BafSpacing.md),
          const Text(
            'No active published catalogue packages found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BafColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          const Text(
            'No assignable TemplateVersion is active yet. Publish a valid catalogue version from Template Publisher first, then return here to assign governed jobs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BafColors.textSecondary, height: 1.35),
          ),
          if (onOpenPublisher != null) ...[
            const SizedBox(height: BafSpacing.lg),
            FilledButton.icon(
              onPressed: onOpenPublisher,
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Open Template Publisher'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublisherPromptCallout extends StatelessWidget {
  final String message;
  final VoidCallback? onOpenPublisher;

  const _PublisherPromptCallout({
    required this.message,
    this.onOpenPublisher,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.22)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: BafColors.warning),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          );

          final action = onOpenPublisher == null
              ? null
              : TextButton.icon(
            onPressed: onOpenPublisher,
            icon: const Icon(Icons.publish_rounded),
            label: const Text('Open Publisher'),
          );

          if (action == null) return text;
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: BafSpacing.sm),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: text),
              const SizedBox(width: BafSpacing.sm),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String text;

  const _InlineEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: BafColors.textSecondary),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Text(
          message,
          style: const TextStyle(color: BafColors.danger),
        ),
      ),
    );
  }
}

class _AssignmentAccessDeniedScaffold extends StatelessWidget {
  const _AssignmentAccessDeniedScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BafColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(BafSpacing.xl),
          child: Text(
            'Only Admin/SI, supervisors and senior discipline users can assign planned jobs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BafColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _AssignmentErrorScaffold extends StatelessWidget {
  final String message;

  const _AssignmentErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.xl),
          child: Text(
            message,
            style: const TextStyle(color: BafColors.danger),
          ),
        ),
      ),
    );
  }
}

String _versionLabel(TemplateVersion version) {
  final label = _clean(version.versionLabel);
  final hash = _clean(version.contentHash);
  final suffix = hash == null ? '' : ' · ${hash.substring(0, hash.length < 8 ? hash.length : 8)}';
  return 'v${version.versionNumber}${label == null ? '' : ' — $label'}$suffix';
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

int? _parseOptionalInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}

Color _disciplineColor(JobModuleDiscipline discipline) {
  switch (discipline) {
    case JobModuleDiscipline.mechanical:
      return BafColors.planned;
    case JobModuleDiscipline.electrical:
      return const Color(0xFFF59E0B);
    case JobModuleDiscipline.instrumentation:
      return BafColors.audit;
    case JobModuleDiscipline.operations:
      return BafColors.sync;
    case JobModuleDiscipline.others:
      return BafColors.directives;
    case JobModuleDiscipline.shiftInCharge:
      return BafColors.charges;
    case JobModuleDiscipline.safety:
      return BafColors.danger;
    case JobModuleDiscipline.admin:
    case JobModuleDiscipline.shared:
      return BafColors.admin;
  }
}
