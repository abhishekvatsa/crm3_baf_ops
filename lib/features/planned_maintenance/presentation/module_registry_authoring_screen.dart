import 'package:flutter/material.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/persisted_data_integrity_notice.dart';
import '../../auth/data/user_model.dart';
import '../data/module_registry_model.dart';
import '../domain/module_composer_models.dart';
import '../domain/module_registry_concurrency.dart';

class ModuleRegistryAuthoringScreen extends StatefulWidget {
  final AppUser actor;
  final List<ComposerModuleDraft> draftModules;
  final Future<List<ModuleRegistryRevision>> Function() loadDraftRevisions;
  final Future<List<PublishedRegistryModuleSource>> Function()
  loadPublishedSources;
  final Future<void> Function(ComposerModuleDraft module, String reason)
  createDraft;
  final Future<void> Function(
    ModuleRegistryRevision revision,
    ComposerModuleDraft module,
    String reason,
  )
  updateDraft;
  final Future<void> Function(ModuleRegistryRevision revision, String reason)
  publishDraft;
  final Future<void> Function(ModuleRegistryRevision revision, String reason)
  retireRevision;
  final Future<void> Function(ModuleRegistryFamily family, String reason)
  retireFamily;

  const ModuleRegistryAuthoringScreen({
    super.key,
    required this.actor,
    required this.draftModules,
    required this.loadDraftRevisions,
    required this.loadPublishedSources,
    required this.createDraft,
    required this.updateDraft,
    required this.publishDraft,
    required this.retireRevision,
    required this.retireFamily,
  });

  @override
  State<ModuleRegistryAuthoringScreen> createState() =>
      _ModuleRegistryAuthoringScreenState();
}

class _ModuleRegistryAuthoringScreenState
    extends State<ModuleRegistryAuthoringScreen> {
  bool _loading = true;
  bool _busy = false;
  int _selectedDraftModuleIndex = 0;
  List<ModuleRegistryRevision> _draftRevisions = const [];
  List<PublishedRegistryModuleSource> _publishedSources = const [];
  String? _error;
  bool _integrityError = false;

  bool get _canGovern => widget.actor.canManageTemplateGovernance;
  bool get _canMutate => _canGovern && _error == null;

  ComposerModuleDraft? get _selectedComposerModule {
    if (widget.draftModules.isEmpty) {
      return null;
    }
    final safeIndex = _selectedDraftModuleIndex.clamp(
      0,
      widget.draftModules.length - 1,
    );
    return widget.draftModules[safeIndex];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _integrityError = false;
    });
    try {
      final drafts = await widget.loadDraftRevisions();
      final published = await widget.loadPublishedSources();
      if (!mounted) {
        return;
      }
      setState(() {
        _draftRevisions = drafts;
        _publishedSources = published;
        _loading = false;
      });
    } on PersistedDataFormatException {
      if (!mounted) {
        return;
      }
      setState(() {
        _error =
            'A registry governance record has missing, malformed, or inconsistent lifecycle history. Actions are disabled until the source record is repaired and this view reloads cleanly.';
        _integrityError = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _integrityError = false;
        _loading = false;
      });
    }
  }

  Future<bool> _runAction(Future<void> Function() action) async {
    if (!_canGovern) {
      _showSnack('Registry authoring is Admin/SI-only.', BafColors.danger);
      return false;
    }
    if (_error != null) {
      _showSnack(
        'Registry data must load cleanly before governance actions are enabled.',
        BafColors.danger,
      );
      return false;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) {
        return false;
      }
      await _load();
      if (!mounted) {
        return false;
      }
      if (_error != null) {
        return false;
      }
      return true;
    } on ModuleRegistryStaleDraftException catch (error) {
      if (!mounted) {
        return false;
      }
      await _load();
      if (!mounted) {
        return false;
      }
      _showSnack(error.operatorMessage, BafColors.warning);
      return false;
    } catch (e) {
      if (!mounted) {
        return false;
      }
      _showSnack(e.toString(), BafColors.danger);
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _createDraftFromSelectedModule() async {
    final module = _selectedComposerModule;
    if (module == null) {
      _showSnack('No composer module selected.', BafColors.warning);
      return;
    }
    final reason = await _promptReason(
      title: 'Create registry draft',
      label: 'Reason / authoring note',
      initialValue: 'Create governed registry draft from ${module.moduleCode}.',
      minLength: 6,
    );
    if (!mounted || reason == null) {
      return;
    }
    final success = await _runAction(() => widget.createDraft(module, reason));
    if (!mounted || !success) {
      return;
    }
    _showSnack(
      'Registry draft created from ${module.moduleCode}.',
      BafColors.success,
    );
  }

  Future<void> _updateDraftFromSelectedModule(
    ModuleRegistryRevision revision,
  ) async {
    final module = _selectedComposerModule;
    if (module == null) {
      _showSnack('No composer module selected.', BafColors.warning);
      return;
    }
    final reason = await _promptReason(
      title: 'Update registry draft',
      label: 'Reason / change note',
      initialValue: 'Update registry draft from ${module.moduleCode}.',
      minLength: 6,
    );
    if (!mounted || reason == null) {
      return;
    }
    final success = await _runAction(
      () => widget.updateDraft(revision, module, reason),
    );
    if (!mounted || !success) {
      return;
    }
    _showSnack(
      'Registry draft updated from ${module.moduleCode}.',
      BafColors.success,
    );
  }

  Future<void> _publishDraft(ModuleRegistryRevision revision) async {
    final module = revision.toComposerModuleDraft();
    final reason = await _promptReason(
      title: 'Publish registry revision',
      label: 'Publish reason',
      initialValue:
          'Approve ${module.moduleCode} as governed registry revision.',
      minLength: 10,
    );
    if (!mounted || reason == null) {
      return;
    }
    final success = await _runAction(
      () => widget.publishDraft(revision, reason),
    );
    if (!mounted || !success) {
      return;
    }
    _showSnack(
      'Published registry revision for ${module.moduleCode}.',
      BafColors.success,
    );
  }

  Future<void> _retireRevision(PublishedRegistryModuleSource source) async {
    final module = source.module;
    final reason = await _promptReason(
      title: 'Retire registry revision',
      label: 'Retire reason',
      initialValue:
          'Retire registry revision ${source.revision.revisionNumber} for ${module.moduleCode}.',
      minLength: 10,
    );
    if (!mounted || reason == null) {
      return;
    }
    final success = await _runAction(
      () => widget.retireRevision(source.revision, reason),
    );
    if (!mounted || !success) {
      return;
    }
    _showSnack(
      'Retired registry revision for ${module.moduleCode}.',
      BafColors.warning,
    );
  }

  Future<void> _retireFamily(ModuleRegistryFamily family) async {
    final reason = await _promptReason(
      title: 'Retire registry family',
      label: 'Retire reason',
      initialValue: 'Retire registry family ${family.moduleCode}.',
      minLength: 10,
    );
    if (!mounted || reason == null) {
      return;
    }
    final success = await _runAction(() => widget.retireFamily(family, reason));
    if (!mounted || !success) {
      return;
    }
    _showSnack(
      'Retired registry family ${family.moduleCode}.',
      BafColors.warning,
    );
  }

  Future<String?> _promptReason({
    required String title,
    required String label,
    required String initialValue,
    required int minLength,
  }) {
    return showDialog<String>(
      context: context,
      builder:
          (_) => _RegistryReasonDialog(
            title: title,
            label: label,
            initialValue: initialValue,
            minLength: minLength,
          ),
    );
  }

  void _showSnack(String message, Color color) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0.4,
        title: const Text('Registry Authoring'),
        actions: [
          IconButton(
            tooltip: 'Reload registry authoring data',
            onPressed: _busy || _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.all(BafSpacing.lg),
                  children: [
                    _GovernanceBanner(
                      actor: widget.actor,
                      canGovern: _canGovern,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: BafSpacing.md),
                      if (_integrityError)
                        PersistedDataIntegrityNotice(
                          title: 'Governance timeline needs repair',
                          message: _error!,
                        )
                      else
                        _WarningPanel(message: _error!),
                    ],
                    const SizedBox(height: BafSpacing.lg),
                    _CurrentDraftModulePanel(
                      draftModules: widget.draftModules,
                      selectedIndex: _selectedDraftModuleIndex,
                      onSelected:
                          (index) =>
                              setState(() => _selectedDraftModuleIndex = index),
                      onCreateDraft:
                          _busy || !_canMutate
                              ? null
                              : _createDraftFromSelectedModule,
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _RegistryDraftPanel(
                      draftRevisions: _draftRevisions,
                      selectedComposerModule: _selectedComposerModule,
                      busy: _busy,
                      canGovern: _canMutate,
                      onUpdateFromComposer: _updateDraftFromSelectedModule,
                      onPublish: _publishDraft,
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _PublishedRegistryPanel(
                      sources: _publishedSources,
                      busy: _busy,
                      canGovern: _canMutate,
                      onRetireRevision: _retireRevision,
                      onRetireFamily: _retireFamily,
                    ),
                  ],
                ),
      ),
    );
  }
}

class _RegistryReasonDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  final int minLength;

  const _RegistryReasonDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.minLength,
  });

  @override
  State<_RegistryReasonDialog> createState() => _RegistryReasonDialogState();
}

class _RegistryReasonDialogState extends State<_RegistryReasonDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_handleReasonChanged);
  }

  void _handleReasonChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleReasonChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    final canSubmit = value.length >= widget.minLength;

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: 'Minimum ${widget.minLength} characters.',
              errorText:
                  value.isEmpty || canSubmit
                      ? null
                      : 'Enter at least ${widget.minLength} characters.',
              border: const OutlineInputBorder(),
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
          onPressed: canSubmit ? () => Navigator.pop(context, value) : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _GovernanceBanner extends StatelessWidget {
  final AppUser actor;
  final bool canGovern;

  const _GovernanceBanner({required this.actor, required this.canGovern});

  @override
  Widget build(BuildContext context) {
    return _RegistryCard(
      title: 'Governed registry authority',
      subtitle:
          canGovern
              ? '${actor.name} can create, edit, publish, and retire registry modules.'
              : '${actor.name} can view registry context but cannot author registry modules.',
      icon: Icons.verified_user_rounded,
      color: canGovern ? BafColors.success : BafColors.warning,
      child: const Text(
        'Registry governance remains Admin/SI-only. Supervisor proposals, offline mutation queue, Isar sync, and hard delete are not enabled.',
        style: TextStyle(color: BafColors.textSecondary, height: 1.35),
      ),
    );
  }
}

class _CurrentDraftModulePanel extends StatelessWidget {
  final List<ComposerModuleDraft> draftModules;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onCreateDraft;

  const _CurrentDraftModulePanel({
    required this.draftModules,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCreateDraft,
  });

  @override
  Widget build(BuildContext context) {
    return _RegistryCard(
      title: 'Create registry draft from composer module',
      subtitle:
          'Pick one current draft module and create a governed registry draft.',
      icon: Icons.note_add_rounded,
      color: BafColors.planned,
      child:
          draftModules.isEmpty
              ? const _EmptyText('No composer draft modules are available yet.')
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedIndex.clamp(
                      0,
                      draftModules.length - 1,
                    ),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Composer module',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 0; i < draftModules.length; i++)
                        DropdownMenuItem<int>(
                          value: i,
                          child: Text(
                            '${draftModules[i].moduleCode} — ${draftModules[i].title}',
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onSelected(value);
                      }
                    },
                  ),
                  const SizedBox(height: BafSpacing.md),
                  FilledButton.icon(
                    onPressed: onCreateDraft,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Create registry draft'),
                  ),
                ],
              ),
    );
  }
}

class _RegistryDraftPanel extends StatelessWidget {
  final List<ModuleRegistryRevision> draftRevisions;
  final ComposerModuleDraft? selectedComposerModule;
  final bool busy;
  final bool canGovern;
  final Future<void> Function(ModuleRegistryRevision revision)
  onUpdateFromComposer;
  final Future<void> Function(ModuleRegistryRevision revision) onPublish;

  const _RegistryDraftPanel({
    required this.draftRevisions,
    required this.selectedComposerModule,
    required this.busy,
    required this.canGovern,
    required this.onUpdateFromComposer,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    return _RegistryCard(
      title: 'Registry drafts',
      subtitle:
          'Draft revisions are editable. Publishing freezes content as an immutable registry revision.',
      icon: Icons.edit_document,
      color: BafColors.audit,
      child:
          draftRevisions.isEmpty
              ? const _EmptyText('No registry drafts found.')
              : Column(
                children: [
                  for (final revision in draftRevisions)
                    _RegistryDraftCard(
                      revision: revision,
                      selectedComposerModule: selectedComposerModule,
                      busy: busy,
                      canGovern: canGovern,
                      onUpdateFromComposer: onUpdateFromComposer,
                      onPublish: onPublish,
                    ),
                ],
              ),
    );
  }
}

class _RegistryDraftCard extends StatelessWidget {
  final ModuleRegistryRevision revision;
  final ComposerModuleDraft? selectedComposerModule;
  final bool busy;
  final bool canGovern;
  final Future<void> Function(ModuleRegistryRevision revision)
  onUpdateFromComposer;
  final Future<void> Function(ModuleRegistryRevision revision) onPublish;

  const _RegistryDraftCard({
    required this.revision,
    required this.selectedComposerModule,
    required this.busy,
    required this.canGovern,
    required this.onUpdateFromComposer,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final module = revision.toComposerModuleDraft();
    final canUpdate = canGovern && !busy && selectedComposerModule != null;
    final canPublish = canGovern && !busy;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: BafSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModuleHeader(module: module, badge: 'Draft'),
            const SizedBox(height: BafSpacing.sm),
            Text(
              'Registry ID: ${revision.registryModuleId}\nContent hash: ${revision.contentHash}',
              style: const TextStyle(
                color: BafColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      canUpdate ? () => onUpdateFromComposer(revision) : null,
                  icon: const Icon(Icons.sync_alt_rounded),
                  label: const Text('Update from selected module'),
                ),
                FilledButton.icon(
                  onPressed: canPublish ? () => onPublish(revision) : null,
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text('Publish registry revision'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedRegistryPanel extends StatelessWidget {
  final List<PublishedRegistryModuleSource> sources;
  final bool busy;
  final bool canGovern;
  final Future<void> Function(PublishedRegistryModuleSource source)
  onRetireRevision;
  final Future<void> Function(ModuleRegistryFamily family) onRetireFamily;

  const _PublishedRegistryPanel({
    required this.sources,
    required this.busy,
    required this.canGovern,
    required this.onRetireRevision,
    required this.onRetireFamily,
  });

  @override
  Widget build(BuildContext context) {
    return _RegistryCard(
      title: 'Published registry revisions',
      subtitle:
          'Published revisions are immutable. Retire hides them from new template reuse without deleting history.',
      icon: Icons.workspace_premium_rounded,
      color: BafColors.success,
      child:
          sources.isEmpty
              ? const _EmptyText('No published registry revisions found.')
              : Column(
                children: [
                  for (final source in sources)
                    _PublishedRegistryCard(
                      source: source,
                      busy: busy,
                      canGovern: canGovern,
                      onRetireRevision: onRetireRevision,
                      onRetireFamily: onRetireFamily,
                    ),
                ],
              ),
    );
  }
}

class _PublishedRegistryCard extends StatelessWidget {
  final PublishedRegistryModuleSource source;
  final bool busy;
  final bool canGovern;
  final Future<void> Function(PublishedRegistryModuleSource source)
  onRetireRevision;
  final Future<void> Function(ModuleRegistryFamily family) onRetireFamily;

  const _PublishedRegistryCard({
    required this.source,
    required this.busy,
    required this.canGovern,
    required this.onRetireRevision,
    required this.onRetireFamily,
  });

  @override
  Widget build(BuildContext context) {
    final module = source.module;
    final family = source.family;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: BafSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModuleHeader(
              module: module,
              badge: 'Published rev ${source.revision.revisionNumber}',
            ),
            const SizedBox(height: BafSpacing.sm),
            Text(
              '${source.sourceLabel}\nContent hash: ${source.revision.contentHash}',
              style: const TextStyle(
                color: BafColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      canGovern && !busy
                          ? () => onRetireRevision(source)
                          : null,
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Retire revision'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      canGovern && !busy && family != null
                          ? () => onRetireFamily(family)
                          : null,
                  icon: const Icon(Icons.archive_rounded),
                  label: const Text('Retire family'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  const _RegistryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
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
            child,
          ],
        ),
      ),
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  final ComposerModuleDraft module;
  final String badge;

  const _ModuleHeader({required this.module, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BafSpacing.sm,
      runSpacing: BafSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          module.moduleCode,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        _SmallBadge(label: badge, color: BafColors.sync),
        if (module.requiredForClosure)
          const _SmallBadge(label: 'Closure-critical', color: BafColors.danger),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

class _EmptyText extends StatelessWidget {
  final String message;

  const _EmptyText(this.message);

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(color: BafColors.textSecondary),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  final String message;

  const _WarningPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: const TextStyle(color: BafColors.warning)),
    );
  }
}
