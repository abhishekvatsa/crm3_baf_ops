import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../data/baf_module_catalogue_seed.dart';
import '../domain/module_composer_models.dart';
import '../data/module_registry_model.dart';
import '../domain/module_workshop_published_sources.dart';

enum ModuleWorkshopResultAction {
  selectDraft,
  openFocusedEditor,
  cloneSeed,
  cloneKnowledge,
  clonePublishedModule,
  cloneRegistryModule,
}

class ModuleWorkshopResult {
  final ModuleWorkshopResultAction action;
  final int moduleIndex;
  final int sourceIndex;

  const ModuleWorkshopResult._({
    required this.action,
    this.moduleIndex = -1,
    this.sourceIndex = -1,
  });

  const ModuleWorkshopResult.selectDraft(int moduleIndex)
    : this._(
        action: ModuleWorkshopResultAction.selectDraft,
        moduleIndex: moduleIndex,
      );

  const ModuleWorkshopResult.openFocusedEditor(int moduleIndex)
    : this._(
        action: ModuleWorkshopResultAction.openFocusedEditor,
        moduleIndex: moduleIndex,
      );

  const ModuleWorkshopResult.cloneSeed(int sourceIndex)
    : this._(
        action: ModuleWorkshopResultAction.cloneSeed,
        sourceIndex: sourceIndex,
      );

  const ModuleWorkshopResult.cloneKnowledge(int sourceIndex)
    : this._(
        action: ModuleWorkshopResultAction.cloneKnowledge,
        sourceIndex: sourceIndex,
      );

  const ModuleWorkshopResult.clonePublishedModule(int sourceIndex)
    : this._(
        action: ModuleWorkshopResultAction.clonePublishedModule,
        sourceIndex: sourceIndex,
      );

  const ModuleWorkshopResult.cloneRegistryModule(int sourceIndex)
    : this._(
        action: ModuleWorkshopResultAction.cloneRegistryModule,
        sourceIndex: sourceIndex,
      );
}

class ModuleWorkshopScreen extends StatelessWidget {
  final List<ComposerModuleDraft> draftModules;
  final int seedCatalogueCount;
  final int knowledgeCatalogueCount;
  final int publishedSourceCount;
  final List<BafModuleSeed> seedModules;
  final List<BafKnowledgeEntry> knowledgeRows;
  final List<PublishedModuleSource> publishedSources;
  final List<PublishedRegistryModuleSource> registrySources;

  const ModuleWorkshopScreen({
    super.key,
    required this.draftModules,
    this.seedCatalogueCount = 0,
    this.knowledgeCatalogueCount = 0,
    this.publishedSourceCount = 0,
    this.seedModules = const [],
    this.knowledgeRows = const [],
    this.publishedSources = const <PublishedModuleSource>[],
    this.registrySources = const <PublishedRegistryModuleSource>[],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0.4,
        title: const Text('Module Workshop'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final children = [
              _WorkshopSection(
                expandChild: wide,
                title: 'Draft Modules',
                subtitle:
                    'Modules in the current composer draft. Select one or open the focused editor.',
                icon: Icons.edit_note_rounded,
                color: BafColors.planned,
                child:
                    draftModules.isEmpty
                        ? const _EmptyWorkshopPanel(
                          message:
                              'No draft modules yet. Return to the composer to add or clone a module.',
                        )
                        : Column(
                          children: [
                            for (var i = 0; i < draftModules.length; i++)
                              _DraftModuleCard(
                                module: draftModules[i],
                                moduleIndex: i,
                              ),
                          ],
                        ),
              ),
              _WorkshopSection(
                expandChild: wide,
                title: 'Seed Catalogue',
                subtitle:
                    'Emergency/manual seed catalogue remains available from the composer as a controlled fallback source.',
                icon: Icons.inventory_2_rounded,
                color: BafColors.warning,
                child:
                    seedModules.isEmpty
                        ? _SourceSummaryCard(
                          count: seedCatalogueCount,
                          label: 'seed modules available',
                          detail:
                              'For now, this shell can show source availability without changing catalogue, sync, or publishing contracts.',
                        )
                        : _SeedSourceList(seedModules: seedModules),
              ),
              _WorkshopSection(
                expandChild: wide,
                title: 'Knowledge Catalogue',
                subtitle:
                    'BAF knowledge rows remain available from the composer right rail.',
                icon: Icons.psychology_alt_rounded,
                color: BafColors.audit,
                child:
                    knowledgeRows.isEmpty
                        ? _SourceSummaryCard(
                          count: knowledgeCatalogueCount,
                          label: 'knowledge rows loaded',
                          detail:
                              'Workshop browsing can be expanded without changing storage, sync, or publishing contracts.',
                        )
                        : _KnowledgeSourceList(knowledgeRows: knowledgeRows),
              ),
              _WorkshopSection(
                expandChild: wide,
                title: 'Published Template Sources',
                subtitle:
                    'Frozen TemplateVersion snapshots are read-only governed sources. Cloning creates a new draft module.',
                icon: Icons.verified_rounded,
                color: BafColors.sync,
                child:
                    publishedSources.isEmpty
                        ? _SourceSummaryCard(
                          count: publishedSourceCount,
                          label: 'published modules available',
                          detail:
                              'No published modules are loaded yet. Publish governed TemplateVersions first, then reuse their frozen module snapshots here.',
                        )
                        : _PublishedSourceList(
                          publishedSources: publishedSources,
                        ),
              ),
              _WorkshopSection(
                expandChild: wide,
                title: 'Governed Module Registry',
                subtitle:
                    'Admin/SI-published registry revisions are approved reusable module sources. Cloning creates a new draft snapshot.',
                icon: Icons.workspace_premium_rounded,
                color: BafColors.success,
                child:
                    registrySources.isEmpty
                        ? const _SourceSummaryCard(
                          count: 0,
                          label: 'published registry revisions available',
                          detail:
                              'Published registry revisions appear here after Admin/SI publish governed module revisions.',
                        )
                        : _RegistrySourceList(registrySources: registrySources),
              ),
            ];

            if (wide) {
              return GridView.count(
                padding: const EdgeInsets.all(BafSpacing.lg),
                crossAxisCount: 2,
                mainAxisSpacing: BafSpacing.lg,
                crossAxisSpacing: BafSpacing.lg,
                childAspectRatio: 1.22,
                children: children,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(BafSpacing.lg),
              itemBuilder: (context, index) => children[index],
              separatorBuilder:
                  (context, index) => const SizedBox(height: BafSpacing.lg),
              itemCount: children.length,
            );
          },
        ),
      ),
    );
  }
}

class _WorkshopSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;
  final bool expandChild;

  const _WorkshopSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  foregroundColor: color,
                  child: Icon(icon),
                ),
                const SizedBox(width: BafSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: BafSpacing.xs),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
            if (expandChild)
              Expanded(child: SingleChildScrollView(child: child))
            else
              child,
          ],
        ),
      ),
    );
  }
}

class _DraftModuleCard extends StatelessWidget {
  final ComposerModuleDraft module;
  final int moduleIndex;

  const _DraftModuleCard({required this.module, required this.moduleIndex});

  @override
  Widget build(BuildContext context) {
    final title =
        module.title.trim().isEmpty ? module.moduleCode : module.title.trim();
    final subtitle = [
      '${module.fields.length} fields',
      '${module.checklistItems.length} checklist items',
      module.discipline.name,
      module.frequency.name,
    ].join(' • ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.xs,
              children: [
                Text(
                  module.moduleCode,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (module.requiredForClosure)
                  const _MiniBadge(
                    label: 'Closure-critical',
                    color: BafColors.danger,
                  ),
                if (module.requiresJointReview)
                  const _MiniBadge(
                    label: 'Joint review',
                    color: BafColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              title,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              subtitle,
              style: const TextStyle(color: BafColors.textSecondary),
            ),
            const SizedBox(height: BafSpacing.md),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        ModuleWorkshopResult.selectDraft(moduleIndex),
                      ),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Select'),
                ),
                FilledButton.icon(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        ModuleWorkshopResult.openFocusedEditor(moduleIndex),
                      ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open focused editor'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeedSourceList extends StatelessWidget {
  final List<BafModuleSeed> seedModules;

  const _SeedSourceList({required this.seedModules});

  @override
  Widget build(BuildContext context) {
    final visible = seedModules.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${seedModules.length} seed modules available. Showing ${visible.length}.',
          style: const TextStyle(color: BafColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: BafSpacing.md),
        for (var i = 0; i < visible.length; i++)
          _SeedSourceCard(seed: visible[i], sourceIndex: i),
      ],
    );
  }
}

class _SeedSourceCard extends StatelessWidget {
  final BafModuleSeed seed;
  final int sourceIndex;

  const _SeedSourceCard({required this.seed, required this.sourceIndex});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      seed.catalogueArea,
      seed.functionalSection,
      seed.componentGroup,
      seed.defaultDiscipline.name,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              seed.moduleCode,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              seed.moduleTitle,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: BafSpacing.xs),
              Text(
                subtitle,
                style: const TextStyle(color: BafColors.textSecondary),
              ),
            ],
            const SizedBox(height: BafSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed:
                    () => Navigator.pop(
                      context,
                      ModuleWorkshopResult.cloneSeed(sourceIndex),
                    ),
                icon: const Icon(Icons.library_add_rounded),
                label: const Text('Clone into draft'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeSourceList extends StatelessWidget {
  final List<BafKnowledgeEntry> knowledgeRows;

  const _KnowledgeSourceList({required this.knowledgeRows});

  @override
  Widget build(BuildContext context) {
    final visible = knowledgeRows.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${knowledgeRows.length} knowledge rows loaded. Showing ${visible.length}.',
          style: const TextStyle(color: BafColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: BafSpacing.md),
        for (var i = 0; i < visible.length; i++)
          _KnowledgeSourceCard(entry: visible[i], sourceIndex: i),
      ],
    );
  }
}

class _KnowledgeSourceCard extends StatelessWidget {
  final BafKnowledgeEntry entry;
  final int sourceIndex;

  const _KnowledgeSourceCard({required this.entry, required this.sourceIndex});

  @override
  Widget build(BuildContext context) {
    final title =
        entry.taskText.trim().isEmpty
            ? entry.moduleCandidateCode
            : entry.taskText.trim();
    final subtitle = [
      entry.sourceLabel,
      entry.functionalSection,
      entry.componentGroup,
      entry.discipline.name,
      entry.composerReadiness.name,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.moduleCandidateCode,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              title,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: BafSpacing.xs),
              Text(
                subtitle,
                style: const TextStyle(color: BafColors.textSecondary),
              ),
            ],
            const SizedBox(height: BafSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed:
                    entry.isCloneable
                        ? () => Navigator.pop(
                          context,
                          ModuleWorkshopResult.cloneKnowledge(sourceIndex),
                        )
                        : null,
                icon: const Icon(Icons.library_add_check_rounded),
                label: Text(
                  entry.isCloneable ? 'Clone into draft' : 'Reference only',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedSourceList extends StatelessWidget {
  final List<PublishedModuleSource> publishedSources;

  const _PublishedSourceList({required this.publishedSources});

  @override
  Widget build(BuildContext context) {
    final visible = publishedSources.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${publishedSources.length} published modules available. Showing ${visible.length}.',
          style: const TextStyle(color: BafColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: BafSpacing.md),
        for (var i = 0; i < visible.length; i++)
          _PublishedModuleSourceCard(source: visible[i], sourceIndex: i),
      ],
    );
  }
}

class _PublishedModuleSourceCard extends StatelessWidget {
  final PublishedModuleSource source;
  final int sourceIndex;

  const _PublishedModuleSourceCard({
    required this.source,
    required this.sourceIndex,
  });

  @override
  Widget build(BuildContext context) {
    final module = source.module;
    final title =
        module.title.trim().isEmpty ? module.moduleCode : module.title.trim();
    final subtitle = [
      source.sourceLabel,
      '${module.fields.length} fields',
      '${module.checklistItems.length} checklist items',
      module.discipline.name,
    ].join(' • ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.xs,
              children: [
                Text(
                  module.moduleCode,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const _MiniBadge(
                  label: 'Published snapshot',
                  color: BafColors.sync,
                ),
                if (module.requiredForClosure)
                  const _MiniBadge(
                    label: 'Closure-critical',
                    color: BafColors.danger,
                  ),
              ],
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              title,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              subtitle,
              style: const TextStyle(color: BafColors.textSecondary),
            ),
            const SizedBox(height: BafSpacing.sm),
            Text(
              source.packageTitle,
              style: const TextStyle(
                color: BafColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            FilledButton.icon(
              onPressed:
                  () => Navigator.pop(
                    context,
                    ModuleWorkshopResult.clonePublishedModule(sourceIndex),
                  ),
              icon: const Icon(Icons.content_copy_rounded),
              label: const Text('Clone as draft module'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrySourceList extends StatelessWidget {
  const _RegistrySourceList({required this.registrySources});

  final List<PublishedRegistryModuleSource> registrySources;

  @override
  Widget build(BuildContext context) {
    final visible = registrySources.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${registrySources.length} governed registry revisions available. Showing ${visible.length}.',
          style: const TextStyle(color: BafColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: BafSpacing.md),
        for (var i = 0; i < visible.length; i++)
          _RegistryModuleSourceCard(source: visible[i], sourceIndex: i),
      ],
    );
  }
}

class _RegistryModuleSourceCard extends StatelessWidget {
  final PublishedRegistryModuleSource source;
  final int sourceIndex;

  const _RegistryModuleSourceCard({
    required this.source,
    required this.sourceIndex,
  });

  @override
  Widget build(BuildContext context) {
    final module = source.module;
    final title =
        module.title.trim().isEmpty ? module.moduleCode : module.title.trim();
    final subtitle = [
      source.sourceLabel,
      '${module.fields.length} fields',
      '${module.checklistItems.length} checklist items',
      module.discipline.name,
    ].join(' • ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.xs,
              children: [
                Text(
                  module.moduleCode,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const _MiniBadge(
                  label: 'Registry revision',
                  color: BafColors.success,
                ),
                if (module.requiredForClosure)
                  const _MiniBadge(
                    label: 'Closure-critical',
                    color: BafColors.danger,
                  ),
              ],
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              title,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              subtitle,
              style: const TextStyle(color: BafColors.textSecondary),
            ),
            const SizedBox(height: BafSpacing.md),
            FilledButton.icon(
              onPressed:
                  () => Navigator.pop(
                    context,
                    ModuleWorkshopResult.cloneRegistryModule(sourceIndex),
                  ),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('Clone registry revision'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceSummaryCard extends StatelessWidget {
  final int count;
  final String label;
  final String detail;

  const _SourceSummaryCard({
    required this.count,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          Text(
            detail,
            style: const TextStyle(
              color: BafColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkshopPanel extends StatelessWidget {
  final String message;

  const _EmptyWorkshopPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: BafColors.textSecondary, height: 1.4),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.sm,
        vertical: BafSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
