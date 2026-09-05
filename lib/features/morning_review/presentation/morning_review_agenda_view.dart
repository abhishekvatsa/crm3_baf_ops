import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../domain/morning_review_agenda.dart';
import '../domain/morning_review_models.dart';
import 'morning_review_editors.dart';

class MorningReviewAgendaView extends StatefulWidget {
  const MorningReviewAgendaView({
    super.key,
    required this.session,
    required this.joined,
    required this.busy,
    required this.entries,
    required this.concerns,
    required this.checks,
    required this.onAddEntry,
    required this.onAddConcern,
    required this.onCheckConcern,
    required this.onResolveConcern,
    required this.onAddAddendum,
  });

  final MorningReviewSession session;
  final bool joined;
  final bool busy;
  final List<MorningReviewEntry> entries;
  final List<MorningReviewStandingConcern> concerns;
  final List<MorningReviewConcernCheck> checks;
  final ValueChanged<MorningReviewSourceFact?>? onAddEntry;
  final VoidCallback? onAddConcern;
  final ValueChanged<MorningReviewStandingConcern>? onCheckConcern;
  final ValueChanged<MorningReviewStandingConcern>? onResolveConcern;
  final VoidCallback? onAddAddendum;

  @override
  State<MorningReviewAgendaView> createState() =>
      _MorningReviewAgendaViewState();
}

class _MorningReviewAgendaViewState extends State<MorningReviewAgendaView> {
  MorningReviewAgendaFilter _filter = MorningReviewAgendaFilter.all;

  @override
  Widget build(BuildContext context) {
    final agenda = compileMorningReviewAgenda(
      sourceFacts: widget.session.sourceFacts,
      entries: widget.entries,
    );
    final visibleSubjects = agenda.subjectsFor(_filter);
    final checksByConcern = {
      for (final check in widget.checks) check.concernId: check,
    };
    final visibleConcerns = widget.concerns
        .where((concern) {
          if (_filter == MorningReviewAgendaFilter.all) return true;
          if (_filter == MorningReviewAgendaFilter.open) {
            return concern.status == MorningReviewConcernStatus.active;
          }
          if (_filter == MorningReviewAgendaFilter.resolved) {
            return concern.status == MorningReviewConcernStatus.resolved;
          }
          return false;
        })
        .toList(growable: false);
    final hasVisibleContent =
        visibleSubjects.isNotEmpty || visibleConcerns.isNotEmpty;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        BafContentFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BafScreenIntro(
                title:
                    widget.session.isOpen ? 'Today\'s room' : 'Frozen meeting',
                subtitle:
                    widget.session.isOpen
                        ? widget.joined
                            ? 'Add updates under your own name; source facts remain read-only.'
                            : 'Join explicitly to contribute. Viewing alone is not attendance.'
                        : widget.session.finalSummary ?? 'Meeting finalized.',
                icon:
                    widget.session.isOpen
                        ? Icons.forum_outlined
                        : Icons.inventory_2_outlined,
                accent: BafColors.cobalt,
                trailing:
                    widget.onAddEntry != null
                        ? FilledButton.icon(
                          onPressed:
                              widget.busy
                                  ? null
                                  : () => widget.onAddEntry!(null),
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('Add contribution'),
                        )
                        : widget.onAddAddendum != null
                        ? OutlinedButton.icon(
                          onPressed: widget.busy ? null : widget.onAddAddendum,
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('Add addendum'),
                        )
                        : null,
              ),
              if (widget.session.sourceCaptureState ==
                  MorningReviewSourceCaptureState.bounded) ...[
                const SizedBox(height: BafSpacing.md),
                _AgendaInlineNotice(
                  icon: Icons.info_outline_rounded,
                  color: BafColors.warning,
                  text:
                      'Source capture reached its governed bound for '
                      '${widget.session.sourceCollectionsAtLimit.join(', ')}. The meeting may proceed, but the PDF will retain this limitation.',
                ),
              ],
              if (widget.session.isOpen) ...[
                const SizedBox(height: BafSpacing.md),
                const _AgendaInlineNotice(
                  icon: Icons.info_outline_rounded,
                  color: BafColors.cobalt,
                  text:
                      'Meeting updates are attributed discussion records only. They do not alter maintenance workflow, lane completion or formal compliance.',
                ),
              ],
              const SizedBox(height: BafSpacing.lg),
              Text(
                '${agenda.subjects.length} subjects · '
                '${widget.session.sourceFacts.length} source facts · '
                '${widget.entries.length} contributions',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: BafSpacing.sm),
              _AgendaFilterGrid(
                agenda: agenda,
                concerns: widget.concerns,
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              for (final section in MorningReviewSection.values) ...[
                if (visibleSubjects.any(
                      (subject) => subject.section == section,
                    ) ||
                    (section == MorningReviewSection.safety &&
                        visibleConcerns.isNotEmpty)) ...[
                  const SizedBox(height: BafSpacing.xl),
                  BafSectionLabel(
                    title: morningReviewSectionLabel(section),
                    subtitle: _sectionSubtitle(section),
                    trailing:
                        section == MorningReviewSection.safety &&
                                widget.onAddConcern != null
                            ? IconButton.filledTonal(
                              tooltip: 'Add standing concern',
                              style: IconButton.styleFrom(
                                backgroundColor: BafColors.cobalt,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    BafColors.surfaceStrong,
                                disabledForegroundColor: BafColors.textTertiary,
                              ),
                              onPressed:
                                  widget.busy ? null : widget.onAddConcern,
                              icon: const Icon(Icons.push_pin_outlined),
                            )
                            : null,
                  ),
                  const SizedBox(height: BafSpacing.sm),
                  if (section == MorningReviewSection.safety)
                    ...visibleConcerns.map(
                      (concern) => Padding(
                        padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                        child: MorningReviewConcernCard(
                          concern: concern,
                          check: checksByConcern[concern.concernId],
                          onCheck:
                              concern.status ==
                                          MorningReviewConcernStatus.active &&
                                      checksByConcern[concern.concernId] == null
                                  ? widget.onCheckConcern == null
                                      ? null
                                      : () => widget.onCheckConcern!(concern)
                                  : null,
                          onResolve:
                              concern.status ==
                                          MorningReviewConcernStatus.active &&
                                      widget.onResolveConcern != null
                                  ? () => widget.onResolveConcern!(concern)
                                  : null,
                        ),
                      ),
                    ),
                  ...visibleSubjects
                      .where((subject) => subject.section == section)
                      .map(
                        (subject) => Padding(
                          padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                          child: _AgendaSubjectCard(
                            subject: subject,
                            filter: _filter,
                            onDiscuss: widget.onAddEntry,
                          ),
                        ),
                      ),
                ],
              ],
              if (!hasVisibleContent) ...[
                const SizedBox(height: BafSpacing.xl),
                BafStatePanel.empty(
                  title: 'No matching meeting subjects',
                  message: 'Choose another status filter to continue.',
                  icon: Icons.filter_alt_off_outlined,
                  color: BafColors.cobalt,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class MorningReviewConcernCard extends StatelessWidget {
  const MorningReviewConcernCard({
    super.key,
    required this.concern,
    this.check,
    this.onCheck,
    this.onResolve,
  });

  final MorningReviewStandingConcern concern;
  final MorningReviewConcernCheck? check;
  final VoidCallback? onCheck;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final active = concern.status == MorningReviewConcernStatus.active;
    final color =
        concern.criticality == MorningReviewConcernCriticality.safety
            ? BafColors.danger
            : BafColors.warning;
    return BafRecordSurface(
      accent: active ? color : BafColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                concern.criticality == MorningReviewConcernCriticality.safety
                    ? Icons.health_and_safety_outlined
                    : Icons.push_pin_outlined,
                color: color,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  concern.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _AgendaStatusPill(
                icon: active ? Icons.schedule_outlined : Icons.check_rounded,
                label: active ? 'Carried' : 'Resolved',
                color: active ? color : BafColors.success,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(concern.detail),
          const SizedBox(height: BafSpacing.sm),
          Text(
            'Raised by ${concern.createdByName} · '
            '${DateFormat('dd MMM yyyy').format(_indiaTime(concern.createdAt))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (check != null) ...[
            const SizedBox(height: BafSpacing.sm),
            _AgendaInlineNotice(
              icon:
                  check!.state == MorningReviewConcernCheckState.complied
                      ? Icons.check_circle_outline
                      : Icons.error_outline_rounded,
              color:
                  check!.state == MorningReviewConcernCheckState.complied
                      ? BafColors.success
                      : BafColors.danger,
              text:
                  '${check!.state.name}: ${check!.note} · ${check!.checkedByName}',
            ),
          ],
          if (onCheck != null || onResolve != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                if (onCheck != null)
                  OutlinedButton.icon(
                    onPressed: onCheck,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Record today\'s check'),
                  ),
                if (onResolve != null)
                  TextButton.icon(
                    onPressed: onResolve,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Resolve concern'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AgendaFilterGrid extends StatelessWidget {
  const _AgendaFilterGrid({
    required this.agenda,
    required this.concerns,
    required this.selected,
    required this.onSelected,
  });

  final MorningReviewAgenda agenda;
  final List<MorningReviewStandingConcern> concerns;
  final MorningReviewAgendaFilter selected;
  final ValueChanged<MorningReviewAgendaFilter> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720 ? 4 : 2;
      final width =
          (constraints.maxWidth - BafSpacing.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: BafSpacing.sm,
        runSpacing: BafSpacing.sm,
        children: [
          for (final filter in MorningReviewAgendaFilter.values)
            SizedBox(
              width: width,
              height: 72,
              child: _AgendaFilterBox(
                filter: filter,
                count: _countFor(filter),
                selected: selected == filter,
                onTap: () => onSelected(filter),
              ),
            ),
        ],
      );
    },
  );

  int _countFor(MorningReviewAgendaFilter filter) {
    final concernCount = switch (filter) {
      MorningReviewAgendaFilter.all => concerns.length,
      MorningReviewAgendaFilter.open =>
        concerns
            .where(
              (concern) => concern.status == MorningReviewConcernStatus.active,
            )
            .length,
      MorningReviewAgendaFilter.resolved =>
        concerns
            .where(
              (concern) =>
                  concern.status == MorningReviewConcernStatus.resolved,
            )
            .length,
      _ => 0,
    };
    return agenda.countFor(filter) + concernCount;
  }
}

class _AgendaFilterBox extends StatelessWidget {
  const _AgendaFilterBox({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final MorningReviewAgendaFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _agendaFilterColor(filter);
    return Material(
      key: ValueKey('morning-review-filter-${filter.name}'),
      color: selected ? color.withValues(alpha: 0.14) : BafColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: BorderSide(
          color: selected ? color.withValues(alpha: 0.62) : BafColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(_agendaFilterIcon(filter), size: 21, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _agendaFilterLabel(filter),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'subject' : 'subjects'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaSubjectCard extends StatelessWidget {
  const _AgendaSubjectCard({
    required this.subject,
    required this.filter,
    required this.onDiscuss,
  });

  final MorningReviewAgendaSubject subject;
  final MorningReviewAgendaFilter filter;
  final ValueChanged<MorningReviewSourceFact?>? onDiscuss;

  @override
  Widget build(BuildContext context) {
    final matters =
        filter == MorningReviewAgendaFilter.all
            ? subject.matters
            : subject.matters
                .where((matter) => matter.categories.contains(filter))
                .toList(growable: false);
    return BafRecordSurface(
      key: ValueKey('morning-review-subject-${subject.key}'),
      accent: _subjectAccent(subject),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                subject.isShared
                    ? Icons.hub_outlined
                    : subject.isGovernedAsset
                    ? Icons.precision_manufacturing_outlined
                    : Icons.edit_note_outlined,
                color: _subjectAccent(subject),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subject.isShared
                          ? 'Linked to more than one governed source'
                          : subject.isGovernedAsset
                          ? 'Governed physical asset'
                          : 'Meeting-provided scope',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _AgendaStatusPill(
                icon: Icons.list_alt_outlined,
                label:
                    '${matters.length} ${matters.length == 1 ? 'matter' : 'matters'}',
                color: _subjectAccent(subject),
              ),
            ],
          ),
          if (subject.categories.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in subject.categories)
                  if (category != MorningReviewAgendaFilter.all)
                    _AgendaStatusPill(
                      icon: _agendaFilterIcon(category),
                      label: _agendaFilterLabel(category),
                      color: _agendaFilterColor(category),
                    ),
              ],
            ),
          ],
          for (var index = 0; index < matters.length; index++) ...[
            const SizedBox(height: BafSpacing.md),
            if (index > 0) ...[
              const Divider(height: 1),
              const SizedBox(height: BafSpacing.md),
            ],
            _AgendaMatterView(
              matter: matters[index],
              onDiscuss:
                  onDiscuss == null || matters[index].sourceFacts.length != 1
                      ? null
                      : () => onDiscuss!(matters[index].sourceFacts.single),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgendaMatterView extends StatelessWidget {
  const _AgendaMatterView({required this.matter, required this.onDiscuss});

  final MorningReviewAgendaMatter matter;
  final VoidCallback? onDiscuss;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(matter.title, style: Theme.of(context).textTheme.titleSmall),
      if (matter.sourceFacts.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          '${matter.status} · '
          '${matter.sourceFacts.map((fact) => fact.sourceType).toSet().join(', ')}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: BafColors.cobalt,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
      if (matter.sourceFacts.length > 1 &&
          matter.linkedAssetLabels.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          'Linked assets: ${matter.linkedAssetLabels.join(', ')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      if (matter.summary.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(matter.summary),
      ],
      if (matter.currentCompliance.isNotEmpty) ...[
        const SizedBox(height: BafSpacing.sm),
        _AgendaEntryGroup(
          title: 'Current compliance',
          entries: matter.currentCompliance,
          color: BafColors.success,
        ),
      ],
      if (matter.remainingCompliance.isNotEmpty) ...[
        const SizedBox(height: BafSpacing.sm),
        _AgendaEntryGroup(
          title: 'Remaining compliance',
          entries: matter.remainingCompliance,
          color: BafColors.maintenance,
        ),
      ],
      if (matter.discussion.isNotEmpty) ...[
        const SizedBox(height: BafSpacing.sm),
        _AgendaEntryGroup(
          title: 'Meeting notes',
          entries: matter.discussion,
          color: BafColors.audit,
        ),
      ],
      if (onDiscuss != null) ...[
        const SizedBox(height: BafSpacing.sm),
        TextButton.icon(
          onPressed: onDiscuss,
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Add update'),
        ),
      ],
    ],
  );
}

class _AgendaEntryGroup extends StatelessWidget {
  const _AgendaEntryGroup({
    required this.title,
    required this.entries,
    required this.color,
  });

  final String title;
  final List<MorningReviewEntry> entries;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(BafRadius.small),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final entry in entries) ...[
            const SizedBox(height: 6),
            Text(entry.text),
            const SizedBox(height: 2),
            Text(
              '${entry.authorName} · '
              '${DateFormat('HH:mm').format(_indiaTime(entry.createdAt))} IST · '
              '${morningReviewEntryKindLabel(entry.kind)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );
}

class _AgendaStatusPill extends StatelessWidget {
  const _AgendaStatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: color.withValues(alpha: 0.24)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AgendaInlineNotice extends StatelessWidget {
  const _AgendaInlineNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(BafRadius.small),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: BafSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

String _agendaFilterLabel(MorningReviewAgendaFilter filter) => switch (filter) {
  MorningReviewAgendaFilter.all => 'All',
  MorningReviewAgendaFilter.down => 'Down',
  MorningReviewAgendaFilter.unavailable => 'Unavailable',
  MorningReviewAgendaFilter.unfit => 'Unfit',
  MorningReviewAgendaFilter.stuckUp => 'Stuck-up',
  MorningReviewAgendaFilter.open => 'Open',
  MorningReviewAgendaFilter.resolved => 'Resolved',
};

IconData _agendaFilterIcon(MorningReviewAgendaFilter filter) =>
    switch (filter) {
      MorningReviewAgendaFilter.all => Icons.dashboard_outlined,
      MorningReviewAgendaFilter.down => Icons.power_off_outlined,
      MorningReviewAgendaFilter.unavailable => Icons.event_busy_outlined,
      MorningReviewAgendaFilter.unfit => Icons.build_circle_outlined,
      MorningReviewAgendaFilter.stuckUp => Icons.link_off_outlined,
      MorningReviewAgendaFilter.open => Icons.pending_actions_outlined,
      MorningReviewAgendaFilter.resolved => Icons.task_alt_outlined,
    };

Color _agendaFilterColor(MorningReviewAgendaFilter filter) => switch (filter) {
  MorningReviewAgendaFilter.all => BafColors.cobalt,
  MorningReviewAgendaFilter.down => BafColors.danger,
  MorningReviewAgendaFilter.unavailable => BafColors.cobalt,
  MorningReviewAgendaFilter.unfit => BafColors.warning,
  MorningReviewAgendaFilter.stuckUp => BafColors.audit,
  MorningReviewAgendaFilter.open => BafColors.maintenance,
  MorningReviewAgendaFilter.resolved => BafColors.success,
};

Color _subjectAccent(MorningReviewAgendaSubject subject) {
  if (subject.categories.contains(MorningReviewAgendaFilter.down)) {
    return BafColors.danger;
  }
  if (subject.categories.contains(MorningReviewAgendaFilter.unfit)) {
    return BafColors.warning;
  }
  if (subject.categories.contains(MorningReviewAgendaFilter.stuckUp)) {
    return BafColors.audit;
  }
  if (subject.categories.contains(MorningReviewAgendaFilter.resolved) &&
      !subject.categories.contains(MorningReviewAgendaFilter.open)) {
    return BafColors.success;
  }
  return BafColors.cobalt;
}

String _sectionSubtitle(MorningReviewSection section) => switch (section) {
  MorningReviewSection.safety =>
    'Human-entered standing concerns and prior-day critical alarm facts',
  MorningReviewSection.furnace =>
    'Open, changed and recently resolved Furnace matters',
  MorningReviewSection.base =>
    'Base and linked Inner Cover constraints, work and decisions',
  MorningReviewSection.forcedCooler =>
    'Forced Cooler exceptions and active work only',
  MorningReviewSection.otherAsset => 'Other governed or provisional assets',
  MorningReviewSection.plantWide =>
    'Utilities, directives, disruptions, ideas and room conclusions',
};

DateTime _indiaTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 5, minutes: 30));
