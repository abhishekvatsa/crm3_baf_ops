part of 'template_publisher_screen.dart';

class _PublisherHeader extends StatelessWidget {
  final _ValidationResult validation;

  const _PublisherHeader({required this.validation});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconTile(
            icon: Icons.publish_rounded,
            color: BafColors.planned,
            size: 56,
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BAF Template Authoring',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                const Text(
                  'Build modules through the Composer and Workshop, validate frozen snapshots, and publish immutable governed TemplateVersions. Advanced JSON panels remain available as controlled fallback.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.sm,
                  children: [
                    StatusBadge(
                      label:
                          validation.canPublish
                              ? 'Ready to publish'
                              : 'Draft incomplete',
                      color:
                          validation.canPublish
                              ? BafColors.success
                              : BafColors.warning,
                      icon:
                          validation.canPublish
                              ? Icons.verified_rounded
                              : Icons.rule_rounded,
                    ),
                    StatusBadge(
                      label: '${validation.moduleCount} modules',
                      color: BafColors.assets,
                      icon: Icons.view_module_rounded,
                    ),
                    StatusBadge(
                      label: '${validation.fieldCount} fields',
                      color: BafColors.audit,
                      icon: Icons.checklist_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerQuickStartSection extends StatelessWidget {
  final _ValidationResult validation;
  final VoidCallback onOpenComposer;

  const _ComposerQuickStartSection({
    required this.validation,
    required this.onOpenComposer,
  });

  @override
  Widget build(BuildContext context) {
    final hasGeneratedPayload =
        validation.moduleCount > 0 || validation.fieldCount > 0;

    return _Panel(
      title:
          hasGeneratedPayload
              ? 'Primary authoring path'
              : 'Start here: Module Composer',
      subtitle:
          'Use the Module Composer and Workshop to build, reuse, merge, and review modules before publishing. The advanced JSON publisher remains available for inspection and controlled recovery.',
      icon: Icons.architecture_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasGeneratedPayload
                    ? 'Composer payload detected in this draft.'
                    : 'Open Module Composer before publishing a new governed TemplateVersion.',
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              const Text(
                'The Composer and Workshop keep module-first authoring primary while preserving publisher validation and frozen snapshot review.',
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.xs,
                children: [
                  StatusBadge(
                    label: '${validation.moduleCount} module(s)',
                    color: BafColors.planned,
                    icon: Icons.view_module_rounded,
                  ),
                  StatusBadge(
                    label: '${validation.fieldCount} field(s)',
                    color: BafColors.audit,
                    icon: Icons.checklist_rounded,
                  ),
                  StatusBadge(
                    label:
                        validation.canPublish
                            ? 'publish-ready'
                            : 'publisher will validate',
                    color:
                        validation.canPublish
                            ? BafColors.success
                            : BafColors.warning,
                    icon:
                        validation.canPublish
                            ? Icons.verified_rounded
                            : Icons.rule_rounded,
                  ),
                ],
              ),
            ],
          );

          final action = FilledButton.icon(
            onPressed: onOpenComposer,
            style: FilledButton.styleFrom(
              backgroundColor: BafColors.planned,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: BafSpacing.lg,
                vertical: BafSpacing.md,
              ),
            ),
            icon: const Icon(Icons.open_in_full_rounded),
            label: const Text('Open Module Composer'),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                const SizedBox(height: BafSpacing.md),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: summary),
              const SizedBox(width: BafSpacing.lg),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _PackageSection extends StatelessWidget {
  final List<TemplatePackage> packages;
  final String? selectedPackageId;
  final TextEditingController packageCodeController;
  final TextEditingController packageTitleController;
  final TextEditingController descriptionController;
  final TextEditingController assetTypeController;
  final TextEditingController assetScopeController;
  final ValueChanged<String?> onPackageChanged;

  const _PackageSection({
    required this.packages,
    required this.selectedPackageId,
    required this.packageCodeController,
    required this.packageTitleController,
    required this.descriptionController,
    required this.assetTypeController,
    required this.assetScopeController,
    required this.onPackageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sorted =
        packages.where((package) => package.firestoreId != null).toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    return _Panel(
      title: '1. Package',
      subtitle:
          'Select an existing governance package or create a new BAF catalogue package.',
      icon: Icons.inventory_2_rounded,
      child: Column(
        children: [
          DropdownButtonFormField<String?>(
            initialValue: selectedPackageId,
            decoration: _inputDecoration(
              label: 'Template package',
              icon: Icons.folder_copy_rounded,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: _newPackageSentinel,
                child: Text('Create new package'),
              ),
              ...sorted.map(
                (package) => DropdownMenuItem<String?>(
                  value: package.firestoreId,
                  child: Text('${package.packageCode} — ${package.title}'),
                ),
              ),
            ],
            onChanged: onPackageChanged,
          ),
          const SizedBox(height: BafSpacing.md),
          _ResponsiveTwoColumn(
            left: TextField(
              controller: packageCodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration(
                label: 'Package code',
                hint: 'FURNACE_FULL_PM',
                icon: Icons.tag_rounded,
              ),
            ),
            right: TextField(
              controller: packageTitleController,
              decoration: _inputDecoration(
                label: 'Package title',
                hint: 'Furnace Full Maintenance',
                icon: Icons.title_rounded,
              ),
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 3,
            decoration: _inputDecoration(
              label: 'Description',
              hint: 'Scope, intended equipment and governance context',
              icon: Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          _ResponsiveTwoColumn(
            left: TextField(
              controller: assetTypeController,
              decoration: _inputDecoration(
                label: 'Asset type',
                hint: 'furnace / base / innerCover',
                icon: Icons.precision_manufacturing_rounded,
              ),
            ),
            right: TextField(
              controller: assetScopeController,
              decoration: _inputDecoration(
                label: 'Asset number scope',
                hint: 'Furnace 1-13 / all bases',
                icon: Icons.filter_alt_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisciplineSection extends StatelessWidget {
  final Set<String> selectedDisciplines;
  final List<_DisciplineOption> options;
  final ValueChanged<String> onToggle;

  const _DisciplineSection({
    required this.selectedDisciplines,
    required this.options,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '2. Discipline scope',
      subtitle:
          'Assigned disciplines are stored on the package and version metadata for audit and future assignment filtering.',
      icon: Icons.groups_2_rounded,
      child: Wrap(
        spacing: BafSpacing.sm,
        runSpacing: BafSpacing.sm,
        children:
            options.map((option) {
              final selected = selectedDisciplines.contains(option.value);
              return FilterChip(
                selected: selected,
                avatar: Icon(
                  option.icon,
                  size: 18,
                  color: selected ? Colors.white : BafColors.textSecondary,
                ),
                label: Text(option.label),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : BafColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                selectedColor: BafColors.planned,
                checkmarkColor: Colors.white,
                backgroundColor: BafColors.card,
                side: BorderSide(
                  color: selected ? BafColors.planned : BafColors.border,
                ),
                onSelected: (_) => onToggle(option.value),
              );
            }).toList(),
      ),
    );
  }
}

class _VersionSection extends StatelessWidget {
  final int nextVersionNumber;
  final TextEditingController versionLabelController;
  final TextEditingController releaseNotesController;
  final TextEditingController changeSummaryController;
  final TextEditingController minAppVersionController;
  final TextEditingController publishReasonController;

  const _VersionSection({
    required this.nextVersionNumber,
    required this.versionLabelController,
    required this.releaseNotesController,
    required this.changeSummaryController,
    required this.minAppVersionController,
    required this.publishReasonController,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '3. Version notes',
      subtitle:
          'Prepare the draft version metadata that will become part of the publish audit trail.',
      icon: Icons.new_releases_rounded,
      child: Column(
        children: [
          _ResponsiveTwoColumn(
            left: TextField(
              controller: versionLabelController,
              decoration: _inputDecoration(
                label: 'Version label',
                hint: 'v$nextVersionNumber / BAF-H2-2026',
                icon: Icons.label_rounded,
              ),
            ),
            right: TextField(
              controller: minAppVersionController,
              decoration: _inputDecoration(
                label: 'Minimum app version',
                hint: 'optional',
                icon: Icons.system_update_rounded,
              ),
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: changeSummaryController,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration(
              label: 'Change summary',
              hint: 'What changed in this catalogue version?',
              icon: Icons.compare_arrows_rounded,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: releaseNotesController,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration(
              label: 'Release notes',
              hint:
                  'Operational guidance for SI/Admin and future assignment users',
              icon: Icons.article_rounded,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: publishReasonController,
            minLines: 2,
            maxLines: 3,
            decoration: _inputDecoration(
              label: 'Publish reason',
              hint: 'Why is this version being formally published?',
              icon: Icons.history_edu_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonPayloadSection extends StatelessWidget {
  final TextEditingController jobTemplateJsonController;
  final TextEditingController moduleSnapshotsJsonController;
  final TextEditingController fieldDefinitionsJsonController;
  final TextEditingController checklistJsonController;
  final VoidCallback onChanged;
  final VoidCallback onOpenComposer;
  final Future<void> Function(TextEditingController controller) onPretty;
  final Future<void> Function(TextEditingController controller) onPaste;
  final void Function(TextEditingController controller, _JsonRoot root) onClear;

  const _JsonPayloadSection({
    required this.jobTemplateJsonController,
    required this.moduleSnapshotsJsonController,
    required this.fieldDefinitionsJsonController,
    required this.checklistJsonController,
    required this.onChanged,
    required this.onOpenComposer,
    required this.onPretty,
    required this.onPaste,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '4. Advanced frozen JSON payloads / Composer output',
      subtitle:
          'Use the module-first Composer/Workshop path by default. These JSON panels remain available for advanced inspection, fallback, or controlled recovery; payloads are frozen after publish and copied into future runtime assignments.',
      icon: Icons.data_object_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: BafColors.planned.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BafRadius.medium),
              side: BorderSide(
                color: BafColors.planned.withValues(alpha: 0.18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(BafSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 560;
                  final iconBox = Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: BafColors.planned.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                    child: const Icon(
                      Icons.architecture_rounded,
                      color: BafColors.planned,
                    ),
                  );
                  const description = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Module-first Composer / Workshop',
                        style: TextStyle(
                          color: BafColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Author, reuse, merge, and review modules in the module-first workflow, then return generated frozen payloads here for advanced validation.',
                        style: TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  );
                  final openComposerButton = FilledButton.icon(
                    onPressed: onOpenComposer,
                    icon: const Icon(Icons.open_in_full_rounded),
                    label: const Text('Open Composer'),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            iconBox,
                            const SizedBox(width: BafSpacing.md),
                            const Expanded(child: description),
                          ],
                        ),
                        const SizedBox(height: BafSpacing.md),
                        openComposerButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      iconBox,
                      const SizedBox(width: BafSpacing.md),
                      const Expanded(child: description),
                      const SizedBox(width: BafSpacing.md),
                      openComposerButton,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          _JsonPanel(
            title: 'jobTemplateSnapshotJson',
            subtitle:
                'Single JSON object describing the high-level template snapshot.',
            controller: jobTemplateJsonController,
            expectedRoot: _JsonRoot.object,
            minLines: 8,
            onChanged: onChanged,
            onPretty: onPretty,
            onPaste: onPaste,
            onClear: onClear,
          ),
          const SizedBox(height: BafSpacing.md),
          _JsonPanel(
            title: 'moduleSnapshotsJson',
            subtitle:
                'JSON array of module snapshots. Required before publishing.',
            controller: moduleSnapshotsJsonController,
            expectedRoot: _JsonRoot.list,
            minLines: 10,
            onChanged: onChanged,
            onPretty: onPretty,
            onPaste: onPaste,
            onClear: onClear,
          ),
          const SizedBox(height: BafSpacing.md),
          _JsonPanel(
            title: 'fieldDefinitionsJson',
            subtitle:
                'JSON array of field definitions. This is the main BAF catalogue field payload.',
            controller: fieldDefinitionsJsonController,
            expectedRoot: _JsonRoot.list,
            minLines: 12,
            highlight: true,
            onChanged: onChanged,
            onPretty: onPretty,
            onPaste: onPaste,
            onClear: onClear,
          ),
          const SizedBox(height: BafSpacing.md),
          _JsonPanel(
            title: 'checklistJson',
            subtitle: 'Optional checklist JSON array. Empty array is allowed.',
            controller: checklistJsonController,
            expectedRoot: _JsonRoot.list,
            minLines: 7,
            onChanged: onChanged,
            onPretty: onPretty,
            onPaste: onPaste,
            onClear: onClear,
          ),
        ],
      ),
    );
  }
}

class _ValidationSection extends StatelessWidget {
  final _ValidationResult validation;

  const _ValidationSection({required this.validation});

  @override
  Widget build(BuildContext context) {
    final color =
        validation.canPublish
            ? BafColors.success
            : validation.errors.isNotEmpty
            ? BafColors.danger
            : BafColors.warning;

    return _Panel(
      title: '5. Publish readiness',
      subtitle:
          'The screen validates client-side before calling the provider. Firestore rules remain the final authority.',
      icon: Icons.fact_check_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              StatusBadge(
                label: validation.canPublish ? 'Publishable' : 'Blocked',
                color: color,
                icon:
                    validation.canPublish
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
              ),
              Tooltip(
                message: validation.contentHash ?? 'hash pending',
                child: StatusBadge(
                  label: _compactContentHash(validation.contentHash),
                  color: BafColors.audit,
                  icon: Icons.fingerprint_rounded,
                ),
              ),
              StatusBadge(
                label: '${validation.checklistCount} checklist items',
                color: BafColors.assets,
                icon: Icons.playlist_add_check_rounded,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          if (validation.errors.isEmpty && validation.warnings.isEmpty)
            const _ValidationLine(
              text: 'All required package, discipline and JSON checks passed.',
              color: BafColors.success,
              icon: Icons.verified_rounded,
            )
          else ...[
            ...validation.errors.map(
              (error) => _ValidationLine(
                text: error,
                color: BafColors.danger,
                icon: Icons.error_outline_rounded,
              ),
            ),
            ...validation.warnings.map(
              (warning) => _ValidationLine(
                text: warning,
                color: BafColors.warning,
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExistingVersionsSection extends ConsumerWidget {
  final String packageFirestoreId;
  final ValueChanged<TemplateVersion> onResumeDraft;

  const _ExistingVersionsSection({
    required this.packageFirestoreId,
    required this.onResumeDraft,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(
      packageVersionsProvider(packageFirestoreId),
    );

    return _Panel(
      title: 'Existing package versions',
      subtitle:
          'Saved drafts can be resumed and published as the same governed record. Published rows remain immutable source records.',
      icon: Icons.history_rounded,
      child: versionsAsync.when(
        loading:
            () => const Padding(
              padding: EdgeInsets.all(BafSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
        error:
            (e, _) => Text(
              'Could not load versions: $e',
              style: const TextStyle(color: BafColors.danger),
            ),
        data: (versions) {
          if (versions.isEmpty) {
            return const Text(
              'No versions yet. The first publish will create v1.',
              style: TextStyle(color: BafColors.textSecondary),
            );
          }

          final drafts = versions
              .where((version) => version.isDraft && !version.isDeleted)
              .toList(growable: false);
          final recentNonDrafts = versions
              .where((version) => !version.isDraft && !version.isDeleted)
              .take(6);
          final visible = <TemplateVersion>[...drafts, ...recentNonDrafts];

          return Column(
            children:
                visible.map((version) {
                  final color = switch (version.status) {
                    TemplateVersionStatus.draft => BafColors.warning,
                    TemplateVersionStatus.published => BafColors.success,
                    TemplateVersionStatus.retired => BafColors.danger,
                    TemplateVersionStatus.archived => BafColors.admin,
                  };
                  return Container(
                    margin: const EdgeInsets.only(bottom: BafSpacing.sm),
                    padding: const EdgeInsets.all(BafSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                      border: Border.all(color: BafColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _IconTile(
                              icon: Icons.new_releases_rounded,
                              color: color,
                              size: 42,
                            ),
                            const SizedBox(width: BafSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'v${version.versionNumber} ${version.versionLabel ?? ''}'
                                        .trim(),
                                    style: const TextStyle(
                                      color: BafColors.textPrimary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: BafSpacing.xs),
                                  Tooltip(
                                    message:
                                        version.contentHash ?? 'No hash yet',
                                    child: Text(
                                      _compactContentHash(version.contentHash),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: BafColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: version.status.name,
                              color: color,
                            ),
                          ],
                        ),
                        if (version.isDraft) ...[
                          const SizedBox(height: BafSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                              key: Key(
                                'resume-template-version-${version.firestoreId ?? version.id}',
                              ),
                              onPressed: () => onResumeDraft(version),
                              icon: const Icon(Icons.edit_note_rounded),
                              label: const Text('Resume draft'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// _PublishBar
// ──────────────────────────────────────────────────────────────────────────
// Used as Scaffold.bottomNavigationBar.
//
// The Scaffold itself reserves space for this bar above the body and
// passes the system gesture inset down through MediaQuery — we let
// SafeArea(top: false) pick that up cleanly instead of computing
// viewPadding.bottom manually (which double-counted the inset and
// inflated the bar's height in mobile builds).
//
// Mobile (< 760dp) layout:
//   - status text (bounded to 2 lines, ellipsis)
//   - [optional] full-width "Open Module Composer" when the draft is empty
//   - row of [Reset | Save Draft] each Expanded for equal half-width
//   - full-width Publish New Version
//
// Wide (>= 760dp) layout: single row with Expanded status + buttons.
// ──────────────────────────────────────────────────────────────────────────
class _PublishBar extends StatelessWidget {
  final _ValidationResult validation;
  final bool isPublishing;
  final VoidCallback onOpenComposer;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;
  final VoidCallback onReset;

  const _PublishBar({
    required this.validation,
    required this.isPublishing,
    required this.onOpenComposer,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BafColors.card,
      elevation: 0,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: BafSpacing.sm),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: BafColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.md,
              BafSpacing.lg,
              BafSpacing.md,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 760;
                    final isEmptyDraft =
                        validation.moduleCount == 0 &&
                        validation.fieldCount == 0;

                    final statusMessage =
                        validation.canPublish
                            ? 'Ready: publish will create an immutable TemplateVersion and audit row.'
                            : isEmptyDraft
                            ? 'Start with Module Composer, then complete package/version metadata.'
                            : '${validation.errors.length} error(s), ${validation.warnings.length} warning(s)';

                    final statusText = Text(
                      statusMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            validation.canPublish
                                ? BafColors.success
                                : isEmptyDraft
                                ? BafColors.textPrimary
                                : BafColors.textSecondary,
                        fontSize: isNarrow ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    );

                    final composerButton = FilledButton.icon(
                      onPressed: isPublishing ? null : onOpenComposer,
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.planned,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: BafSpacing.lg,
                          vertical: BafSpacing.md,
                        ),
                      ),
                      icon: const Icon(Icons.architecture_rounded, size: 18),
                      label: const Text('Open Module Composer'),
                    );

                    final resetButton = OutlinedButton.icon(
                      onPressed: isPublishing ? null : onReset,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reset'),
                    );
                    final draftButton = OutlinedButton.icon(
                      onPressed: isPublishing ? null : onSaveDraft,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Draft'),
                    );
                    final publishButton = FilledButton.icon(
                      onPressed:
                          isPublishing || !validation.canPublish
                              ? null
                              : onPublish,
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.planned,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: BafSpacing.lg,
                          vertical: BafSpacing.md,
                        ),
                      ),
                      icon:
                          isPublishing
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.publish_rounded),
                      label: Text(
                        isPublishing ? 'Publishing…' : 'Publish New Version',
                      ),
                    );

                    if (isNarrow) {
                      // Mobile column: deterministic, no Wrap.
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          statusText,
                          if (isEmptyDraft) ...[
                            const SizedBox(height: BafSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: composerButton,
                            ),
                          ],
                          const SizedBox(height: BafSpacing.sm),
                          Row(
                            children: [
                              Expanded(child: resetButton),
                              const SizedBox(width: BafSpacing.sm),
                              Expanded(child: draftButton),
                            ],
                          ),
                          const SizedBox(height: BafSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: publishButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: statusText),
                        const SizedBox(width: BafSpacing.md),
                        if (isEmptyDraft) ...[
                          composerButton,
                          const SizedBox(width: BafSpacing.sm),
                        ],
                        resetButton,
                        const SizedBox(width: BafSpacing.sm),
                        draftButton,
                        const SizedBox(width: BafSpacing.sm),
                        publishButton,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
