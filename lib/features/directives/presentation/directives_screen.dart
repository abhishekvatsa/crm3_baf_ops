// FILE: lib/features/directives/presentation/directives_screen.dart

import 'dart:async' show Timer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/operational_directive_model.dart';
import '../providers/operational_directive_provider.dart';
import '../../auth/data/user_model.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/burner_condition_round.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/providers/burner_condition_round_provider.dart';
import '../../assets/services/burner_condition_round_service.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../core/widgets/incremental_list_footer.dart';
import '../providers/directive_history_provider.dart';
import 'create_directive_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/presentation/current_actor_gate.dart';
import '../../admin/presentation/saved_submission_review_screen.dart';
import '../../../core/persistence/durable_submission_repository.dart';

part 'directives_screen.burner_recovery.dart';
part 'directives_screen.closure_dialog.dart';

enum _DirectiveListStatus { open, all, closed }

class DirectivesScreen extends ConsumerStatefulWidget {
  const DirectivesScreen({super.key});

  @override
  ConsumerState<DirectivesScreen> createState() => _DirectivesScreenState();
}

class _DirectivesScreenState extends ConsumerState<DirectivesScreen> {
  static const _screenTitle = 'Directives';
  static const _screenSubtitle =
      'Operational instructions, ownership and closure';
  static const _screenIcon = Icons.assignment_late_outlined;

  String _query = '';
  final _searchController = TextEditingController();
  _DirectiveListStatus _status = _DirectiveListStatus.open;
  int _visibleLimit = businessListPageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: _screenTitle,
        appBarSubtitle: _screenSubtitle,
        appBarIcon: _screenIcon,
        accent: BafColors.directives,
        label: 'Checking directive access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: _screenTitle,
        appBarSubtitle: _screenSubtitle,
        appBarIcon: _screenIcon,
        accent: BafColors.directives,
        title: 'Could not verify directive access',
        message: 'Directive access could not be verified.',
        onRetry: () => ref.invalidate(currentAppUserProvider),
      );
    }
    final appUser = actorAsync.value;
    if (appUser == null || !appUser.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: _screenTitle,
        appBarSubtitle: _screenSubtitle,
        appBarIcon: _screenIcon,
        accent: BafColors.directives,
        title: 'Directive access required',
        message: 'An approved operational role is required to view directives.',
      );
    }
    final directivesAsync = _status == _DirectiveListStatus.open
        ? ref.watch(openDirectivesProvider)
        : ref.watch(directiveHistoryProvider);

    return BafScreenScaffold(
      title: _screenTitle,
      subtitle: _screenSubtitle,
      icon: _screenIcon,
      accent: BafColors.directives,
      body: directivesAsync.when(
        loading: () => const BafLoadingPanel(
          label: 'Loading operational directives',
          color: BafColors.directives,
        ),
        error: (e, _) => _ErrorState(message: 'Error: $e'),
        data: (allDirectives) {
          final visible = _visibleDirectives(allDirectives, appUser);
          final directives = _filterDirectives(visible, _query);
          final displayed = directives.take(_visibleLimit).toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  BafSpacing.lg,
                  BafSpacing.lg,
                  BafSpacing.lg,
                  BafSpacing.xl,
                ),
                children: [
                  if (!directivesAreQualified(allDirectives))
                    const Text(
                      'Some directives are unreadable or not server-confirmed. Valid instructions remain shown; counts are incomplete.',
                    ),
                  _DirectivesHeader(
                    qualified: directivesAreQualified(allDirectives),
                    count: directives.length,
                    totalCount: visible.length,
                    query: _query,
                    searchController: _searchController,
                    status: _status,
                    onStatusChanged: (value) => setState(() {
                      _status = value;
                      _visibleLimit = businessListPageSize;
                    }),
                    onQueryChanged: (value) => setState(() {
                      _query = value;
                      _visibleLimit = businessListPageSize;
                    }),
                    onCreate: appUser.canCreateDirective
                        ? _openCreateDirective
                        : null,
                  ),
                  ExpansionTile(
                    key: const ValueKey('directive-saved-changes-tools'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(
                      bottom: BafSpacing.sm,
                    ),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: const Icon(
                      Icons.sync,
                      color: BafColors.textSecondary,
                    ),
                    title: const Text('Saved changes'),
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final result = await OrdinaryDirectiveCommands()
                                .checkAll();
                            if (!context.mounted) return;
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${result.succeeded} saved changes confirmed; ${result.failed} still need attention.',
                                ),
                              ),
                            );
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(content: Text('$error')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.sync),
                        label: const Text('Check saved directive changes'),
                      ),
                      if (!kIsWeb && appUser.roles.contains(AppRole.admin))
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const SavedSubmissionReviewScreen(),
                            ),
                          ),
                          child: const Text('Review held saved changes'),
                        ),
                      if (kIsWeb && appUser.isAdmin)
                        TextButton(
                          onPressed: () => _reviewBrowserSaved(appUser),
                          child: const Text('Review held browser changes'),
                        ),
                    ],
                  ),
                  const SizedBox(height: BafSpacing.md),
                  if (directives.isEmpty &&
                      directivesAreQualified(allDirectives))
                    _EmptyDirectivesState(
                      hasSearch: _query.trim().isNotEmpty,
                      status: _status,
                    )
                  else
                    ...displayed.map(
                      (directive) => Padding(
                        padding: const EdgeInsets.only(bottom: BafSpacing.md),
                        child: _DirectiveCard(
                          key: ValueKey(
                            'directive-card-${directive.firestoreId ?? 'local-${directive.id}'}',
                          ),
                          directive: directive,
                          appUser: appUser,
                        ),
                      ),
                    ),
                  if (directives.isNotEmpty)
                    IncrementalListFooter(
                      visibleCount: displayed.length,
                      totalCount: directives.length,
                      onShowMore: () =>
                          setState(() => _visibleLimit += businessListPageSize),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _reviewBrowserSaved(AppUser actor) async {
    final owner = OrdinaryDirectiveCommands(web: true);
    try {
      final pending = await owner.webPendingForReview(actor);
      if (!mounted) return;
      if (pending.isEmpty) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('No held browser changes.')),
        );
        return;
      }
      final key = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose saved instruction'),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final item in pending)
                  ListTile(
                    title: Text(item.title),
                    onTap: () => Navigator.pop(context, item.key),
                  ),
              ],
            ),
          ),
        ),
      );
      if (key == null || !mounted) return;
      final notes = TextEditingController();
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => CurrentActorDialogGuard(
          originUid: actor.uid,
          permission: (actor) => actor.isAdmin,
          child: AlertDialog(
            title: const Text('Review notes'),
            content: TextField(
              controller: notes,
              maxLines: 4,
              maxLength: 1600,
              decoration: const InputDecoration(
                labelText: 'What did you verify?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, notes.text),
                child: const Text('Check server'),
              ),
            ],
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => notes.dispose());
      if (reason == null || !mounted) return;
      final inspection = await owner.inspectWebReview(
        actor: actor,
        key: key,
        reason: reason,
      );
      if (!mounted) return;
      final result = inspection['result'] as Map;
      final accepted =
          result['observation'] == 'receiptPresent' ||
          result['outcome'] == 'reviewedExisting';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => CurrentActorDialogGuard(
          originUid: actor.uid,
          permission: (actor) => actor.isAdmin,
          child: AlertDialog(
            title: const Text('Finish review?'),
            content: Text(
              accepted
                  ? 'The server retains an acceptance. Preserve that outcome and close this saved retry.'
                  : 'No acceptance receipt was found. Permanently prevent this exact saved request from executing; preserve its original evidence for a fresh reviewed action.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm reviewed closure'),
              ),
            ],
          ),
        ),
      );
      if (confirm != true) return;
      await owner.finalizeWebReview(actor: actor, inspection: inspection);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Review retained. Refresh the instruction before making a new change.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  void _openCreateDirective() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateDirectiveScreen()),
    );
  }

  List<OperationalDirective> _visibleDirectives(
    List<OperationalDirective> allDirectives,
    AppUser? appUser,
  ) {
    if (appUser == null) {
      return [];
    }

    return allDirectives
        .where((directive) => canUserSeeDirective(directive, appUser))
        .toList();
  }

  List<OperationalDirective> _filterDirectives(
    List<OperationalDirective> directives,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    final filtered = directives
        .where((directive) {
          final matchesStatus = switch (_status) {
            _DirectiveListStatus.open =>
              directive.status != DirectiveStatus.closed,
            _DirectiveListStatus.closed =>
              directive.status == DirectiveStatus.closed,
            _DirectiveListStatus.all => true,
          };
          if (!matchesStatus) return false;
          if (needle.isEmpty) return true;
          return <String?>[
            directive.title,
            directive.description,
            directive.assetType?.name,
            directive.assetNumber?.toString(),
            directive.component,
            directive.subsystem,
            directive.tag,
            directive.directedTo.name,
            directive.priority.name,
            directive.issuedByName,
          ].any((value) => value?.toLowerCase().contains(needle) == true);
        })
        .toList(growable: false);
    filtered.sort((left, right) {
      final byCreatedAt = right.createdAt.compareTo(left.createdAt);
      return byCreatedAt != 0
          ? byCreatedAt
          : (left.firestoreId ?? 'local-${left.id}').compareTo(
              right.firestoreId ?? 'local-${right.id}',
            );
    });
    return filtered;
  }
}

class _DirectivesHeader extends StatelessWidget {
  final bool qualified;
  final int count;
  final int totalCount;
  final String query;
  final TextEditingController searchController;
  final _DirectiveListStatus status;
  final ValueChanged<_DirectiveListStatus> onStatusChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onCreate;

  const _DirectivesHeader({
    this.qualified = true,
    required this.count,
    required this.totalCount,
    required this.query,
    required this.searchController,
    required this.status,
    required this.onStatusChanged,
    required this.onQueryChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BafScreenIntro(
          title: 'Directives',
          subtitle: 'Clear instructions, ownership and closure tracking.',
          icon: Icons.assignment_late_outlined,
          accent: BafColors.directives,
          trailing: onCreate == null
              ? null
              : FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New Directive'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BafColors.directives,
                    foregroundColor: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: BafSpacing.md),
        Wrap(
          key: const ValueKey('directives-status-filter'),
          spacing: BafSpacing.sm,
          runSpacing: BafSpacing.xs,
          children: [
            for (final option in _DirectiveListStatus.values)
              ChoiceChip(
                label: Text(switch (option) {
                  _DirectiveListStatus.open => 'Open',
                  _DirectiveListStatus.all => 'All',
                  _DirectiveListStatus.closed => 'Closed',
                }),
                selected: option == status,
                onSelected: (_) => onStatusChanged(option),
              ),
          ],
        ),
        const SizedBox(height: BafSpacing.md),
        BafSearchField(
          fieldKey: const ValueKey('directives-search'),
          controller: searchController,
          hintText: 'Search title, asset or target role',
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: BafSpacing.xs),
        Text(
          query.trim().isEmpty
              ? (qualified
                    ? '$totalCount ${status == _DirectiveListStatus.all ? 'directives' : status.name} visible to your role'
                    : 'Partial or unconfirmed list')
              : '$count of $totalCount matching',
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyDirectivesState extends StatelessWidget {
  final bool hasSearch;
  final _DirectiveListStatus status;

  const _EmptyDirectivesState({required this.hasSearch, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BafSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: BafColors.sync.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 32,
              color: BafColors.sync,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          const Text(
            'No directives found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BafColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            hasSearch
                ? 'No directive matches this search and status.'
                : status == _DirectiveListStatus.open
                ? 'No pending instructions are currently visible for your role.'
                : 'No ${status.name == 'all' ? '' : 'closed '}directives are currently visible for your role.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: BafColors.card,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(color: BafColors.danger.withValues(alpha: 0.18)),
            boxShadow: BafShadows.subtle,
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: BafColors.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectiveCard extends ConsumerStatefulWidget {
  final OperationalDirective directive;
  final AppUser? appUser;

  const _DirectiveCard({
    super.key,
    required this.directive,
    required this.appUser,
  });

  @override
  ConsumerState<_DirectiveCard> createState() => _DirectiveCardState();
}

class _DirectiveCardState extends ConsumerState<_DirectiveCard> {
  Timer? _timer;
  bool _isAcknowledging = false;
  bool _isClosing = false;
  void _setBurnerClosing(bool value) {
    if (mounted) setState(() => _isClosing = value);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directive = widget.directive;
    final appUser = widget.appUser;

    final canAcknowledge =
        appUser != null &&
        directive.status == DirectiveStatus.open &&
        appUser.canAcknowledgeDirective(directive.directedTo) &&
        directive.acknowledgedByUid != appUser.uid;

    final canClose =
        appUser?.canCloseDirectiveInstance(
          createdByUid: directiveOwnerUid(directive),
          directedTo: directive.directedTo,
          acknowledgedByUid: directive.acknowledgedByUid,
        ) ??
        false;

    final statusColor = _statusColor(directive.status);
    final elapsed = DateTime.now().difference(directive.createdAt);
    final isClosed = directive.status == DirectiveStatus.closed;

    return Container(
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BafRadius.large),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: _roleColor(directive.directedTo)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DirectiveTopRow(
                        title: directive.title,
                        status: directive.status,
                        statusColor: statusColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        directive.description,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusBadge(
                            label: 'To ${_roleLabel(directive.directedTo)}',
                            color: _roleColor(directive.directedTo),
                            icon: Icons.arrow_forward_rounded,
                          ),
                          if (directive.assetType != null)
                            StatusBadge(
                              label:
                                  '${_assetTypeLabel(directive.assetType!)} ${directive.assetNumber ?? ''}'
                                      .trim(),
                              color: BafColors.assets,
                              icon: Icons.precision_manufacturing_rounded,
                            ),
                          StatusBadge(
                            label: 'Priority ${directive.priority.name}',
                            color:
                                directive.priority == DirectivePriority.critical
                                ? BafColors.danger
                                : BafColors.directives,
                            icon: Icons.priority_high_rounded,
                          ),
                          if (!isClosed)
                            StatusBadge(
                              label: 'Open ${_formatDuration(elapsed)}',
                              color: BafColors.warning,
                              icon: Icons.timer_outlined,
                            ),
                        ],
                      ),

                      if (directive.component?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: BafSpacing.sm),
                        _MetaLine(
                          icon: Icons.build_outlined,
                          text: directive.component!.trim(),
                        ),
                      ],
                      if (directive.tag?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: BafSpacing.xs),
                        _MetaLine(
                          icon: Icons.sell_outlined,
                          text: 'Tag ${directive.tag!.trim()}',
                        ),
                      ],
                      if (directive.hierarchyPath?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          directive.hierarchyPath!.join(' / '),
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      _MetaLine(
                        icon: Icons.person_outline_rounded,
                        text:
                            'By ${directiveOwnerName(directive) ?? 'Unknown'} · ${DateFormat('dd MMM, HH:mm').format(directive.createdAt)}',
                      ),

                      if (directive.remarks != null &&
                          directive.remarks!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _RemarksBox(text: directive.remarks!.trim()),
                      ],

                      if (!isClosed && (canAcknowledge || canClose)) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: BafSpacing.sm,
                          runSpacing: BafSpacing.sm,
                          children: [
                            if (canAcknowledge)
                              FilledButton.icon(
                                onPressed: _isAcknowledging
                                    ? null
                                    : () => _acknowledgeDirective(directive),
                                style: FilledButton.styleFrom(
                                  backgroundColor: BafColors.directives,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      BafRadius.medium,
                                    ),
                                  ),
                                ),
                                icon: _isAcknowledging
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.task_alt_rounded),
                                label: Text(
                                  _isAcknowledging
                                      ? 'Acknowledging…'
                                      : 'Acknowledge',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            if (canClose)
                              FilledButton.icon(
                                onPressed: _isClosing
                                    ? null
                                    : () => _closeDirective(directive),
                                style: FilledButton.styleFrom(
                                  backgroundColor: BafColors.sync,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      BafRadius.medium,
                                    ),
                                  ),
                                ),
                                icon: _isClosing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_rounded),
                                label: Text(
                                  _isClosing ? 'Closing…' : 'Close Directive',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (directive.firestoreId?.startsWith(
                                'burner_round_red_hot_',
                              ) ==
                              true &&
                          appUser?.canRecordBurnerConditionRound == true)
                        TextButton.icon(
                          onPressed: _isClosing
                              ? null
                              : () => _checkSavedBurnerDirective(
                                  directive,
                                  appUser!,
                                  onlySaved: true,
                                ),
                          icon: const Icon(Icons.history),
                          label: const Text('Check saved Burner/UV compliance'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acknowledgeDirective(OperationalDirective directive) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      _showDirectiveSnack(
        'No signed-in user found for acknowledgement.',
        BafColors.danger,
      );
      return;
    }

    if (_isAcknowledging) {
      return;
    }
    setState(() => _isAcknowledging = true);

    try {
      final repo = ref.read(directiveRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final id = kIsWeb ? directive.firestoreId : directive.id;

      if (id == null) {
        throw Exception('Directive is missing its sync identifier.');
      }

      await repo.acknowledgeDirective(
        id,
        actor: appUser,
        expectedVersion: directive.version,
      );

      final outcome = kIsWeb
          ? SyncRequestOutcome.succeeded
          : await syncCoordinator.runFullSyncWithResult(
              reason: 'directive_acknowledged',
              force: true,
            );

      if (!mounted) return;

      final (message, color) = switch (outcome) {
        SyncRequestOutcome.succeeded => (
          'Directive acknowledged and synchronized.',
          BafColors.sync,
        ),
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled => (
          'Acknowledgement saved on this device; synchronization is queued.',
          BafColors.warning,
        ),
        SyncRequestOutcome.partial => (
          'Partly synced. Server data was refreshed, but some saved changes still need attention. Check Sync health for details.',
          BafColors.warning,
        ),
        SyncRequestOutcome.failed => (
          'Acknowledgement saved on this device, but cloud synchronization needs attention.',
          BafColors.danger,
        ),
      };
      _showDirectiveSnack(message, color);
    } catch (e) {
      if (!mounted) return;

      _showDirectiveSnack(
        'Failed to acknowledge directive: $e',
        BafColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isAcknowledging = false);
      }
    }
  }

  Future<void> _closeDirective(OperationalDirective directive) async {
    final appUser = ref.read(currentAppUserProvider).value;

    if (appUser == null) {
      _showDirectiveSnack(
        'No signed-in user found for closure audit identity',
        BafColors.danger,
      );
      return;
    }

    final BurnerRedHotDirectiveBinding? burnerBinding;
    try {
      burnerBinding = BurnerRedHotDirectiveBinding.tryDecode(
        directive.metadataJson,
      );
    } on FormatException catch (error) {
      _showDirectiveSnack(error.message, BafColors.danger);
      return;
    }

    if (burnerBinding != null &&
        await _checkSavedBurnerDirective(
          directive,
          appUser,
          onlySaved: false,
        )) {
      return;
    }
    if (!mounted) return;

    final repo = ref.read(directiveRepositoryProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider);
    final closure = await showDialog<_DirectiveClosureDraft>(
      context: context,
      builder: (_) => CurrentActorDialogGuard(
        originUid: appUser.uid,
        permission: (actor) => actor.isApproved,
        child: _CloseDirectiveDialog(
          burnerBinding: burnerBinding,
          onSave: burnerBinding != null
              ? null
              : (draft) async {
                  final id = kIsWeb ? directive.firestoreId : directive.id;
                  if (id == null) {
                    throw StateError('Directive identity is missing.');
                  }
                  await repo.closeDirective(
                    id,
                    actor: appUser,
                    expectedVersion: directive.version,
                    remarks: draft.remarks.trim().isEmpty
                        ? null
                        : draft.remarks.trim(),
                    wasUnacknowledged:
                        directive.status != DirectiveStatus.acknowledged,
                  );
                },
        ),
      ),
    );

    if (!mounted || closure == null) {
      return;
    }
    if (_isClosing) {
      return;
    }
    setState(() => _isClosing = true);
    var governedClosureCommitted = false;
    var retryIdentityCleanupPending = false;

    try {
      final closureRemarks = closure.remarks.trim().isEmpty
          ? null
          : closure.remarks.trim();

      final id = kIsWeb ? directive.firestoreId : directive.id;

      if (id == null) {
        throw Exception('Directive is missing its sync identifier.');
      }

      final conditionRecorded = burnerBinding != null;
      if (burnerBinding != null) {
        final firestoreId = directive.firestoreId;
        if (firestoreId == null) {
          throw const BurnerConditionRoundException(
            'Synchronize this directive before recording Burner/UV compliance.',
            code: 'failed-precondition',
          );
        }
        final result = await _completeBurnerDirectiveCompliance(
          directive: directive,
          binding: burnerBinding,
          dispositions: closure.burnerDispositions,
          actor: appUser,
          closureRemarks: closureRemarks,
        );
        governedClosureCommitted = true;
        await repo.adoptServerDirectiveClosure(
          firestoreId: firestoreId,
          expectedBeforeVersion: directive.version,
          committedVersion: result.closedDirectiveVersion,
          actor: appUser,
          closedAt: result.committedAt,
          wasUnacknowledged: directive.status != DirectiveStatus.acknowledged,
          remarks: closureRemarks,
        );
        final finalized = await ref
            .read(burnerConditionRoundServiceProvider)
            .finalizeDirectiveCompliance(result: result, actorUid: appUser.uid);
        retryIdentityCleanupPending = finalized.retryIdentityCleanupPending;
      }

      final outcome = kIsWeb
          ? SyncRequestOutcome.succeeded
          : await syncCoordinator.runFullSyncWithResult(
              reason: 'directive_closed',
              force: true,
            );

      if (!mounted) return;

      final (message, color) = switch (outcome) {
        SyncRequestOutcome.succeeded => (
          conditionRecorded
              ? retryIdentityCleanupPending
                    ? 'Burner condition updated and directive closed. Retry cleanup remains queued on this device.'
                    : 'Burner condition updated; directive closed and synchronized.'
              : 'Directive closed and synchronized.',
          BafColors.sync,
        ),
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled => (
          'Closure saved on this device; synchronization is queued.',
          BafColors.warning,
        ),
        SyncRequestOutcome.partial => (
          'Partly synced. Server data was refreshed, but some saved changes still need attention. Check Sync health for details.',
          BafColors.warning,
        ),
        SyncRequestOutcome.failed => (
          'Closure saved on this device, but cloud synchronization needs attention.',
          BafColors.danger,
        ),
      };
      _showDirectiveSnack(message, color);
    } catch (e) {
      if (!mounted) return;

      _showDirectiveSnack(
        governedClosureCommitted
            ? 'The server closed this burner directive, but this device could not adopt the exact readback. Refresh or run Sync before retrying: $e'
            : 'Failed to close directive: $e',
        BafColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isClosing = false);
      }
    }
  }

  Future<BurnerDirectiveComplianceResult> _completeBurnerDirectiveCompliance({
    required OperationalDirective directive,
    required BurnerRedHotDirectiveBinding binding,
    required Map<int, BurnerDirectiveComplianceDisposition> dispositions,
    required AppUser actor,
    String? closureRemarks,
  }) async {
    if (!actor.canRecordBurnerConditionRound) {
      throw const BurnerConditionRoundException(
        'Your role cannot record the required Burner/UV compliance evidence.',
        code: 'permission-denied',
      );
    }
    final assetNumber = directive.assetNumber;
    if (directive.assetType != AssetType.furnace || assetNumber == null) {
      throw const BurnerConditionRoundException(
        'The burner directive has no exact Furnace identity.',
        code: 'data-loss',
      );
    }
    final results = await Future.wait<Object>([
      ref.read(assetClassesProvider.future),
      ref.read(allAssetInstancesProvider.future),
    ]);
    final classes = results[0] as List<AssetClassRecord>;
    final assets = results[1] as List<AssetInstanceRecord>;
    final furnaceClasses = classes
        .where(
          (item) =>
              item.isActive &&
              item.legacyAssetTypeKey == AssetType.furnace.name,
        )
        .toList(growable: false);
    if (furnaceClasses.length != 1) {
      throw const BurnerConditionRoundException(
        'Exactly one active governed Furnace class is required.',
        code: 'failed-precondition',
      );
    }
    final furnaces = assets
        .where(
          (item) =>
              item.isActive &&
              item.assetClassId == furnaceClasses.single.id &&
              item.assetNumber == assetNumber,
        )
        .toList(growable: false);
    if (furnaces.length != 1) {
      throw BurnerConditionRoundException(
        'Furnace $assetNumber could not be resolved to one governed asset.',
        code: 'failed-precondition',
      );
    }
    final furnace = furnaces.single;
    final latest = await ref.read(burnerComplianceCurrentReaderProvider)(
      LatestBurnerConditionRoundsQuery(
        actorUid: actor.uid,
        assetInstanceIds: <String>[furnace.id],
      ),
    );
    final current = latest[furnace.id];
    if (current == null) {
      throw BurnerConditionRoundException(
        'The source Burner audit ${binding.sourceRoundId} is not available for safe compliance.',
        code: 'failed-precondition',
      );
    }
    if (current.assetNumber != assetNumber ||
        current.assetInstanceId != furnace.id) {
      throw const BurnerConditionRoundException(
        'The latest Burner audit no longer matches the directed Furnace.',
        code: 'data-loss',
      );
    }
    final directiveId = directive.firestoreId;
    if (directiveId == null) {
      throw const BurnerConditionRoundException(
        'The burner directive has no server identity.',
        code: 'failed-precondition',
      );
    }
    final result = await ref
        .read(burnerConditionRoundServiceProvider)
        .completeDirective(
          furnace: furnace,
          current: current,
          directiveId: directiveId,
          expectedDirectiveVersion: directive.version,
          wasUnacknowledged: directive.status != DirectiveStatus.acknowledged,
          dispositions: dispositions,
          actor: actor,
          closureRemarks: closureRemarks,
        );
    ref.invalidate(latestBurnerConditionRoundsProvider);
    return result;
  }

  void _showDirectiveSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Color _statusColor(DirectiveStatus status) {
    switch (status) {
      case DirectiveStatus.open:
        return BafColors.warning;
      case DirectiveStatus.acknowledged:
        return BafColors.planned;
      case DirectiveStatus.closed:
        return BafColors.sync;
    }
  }

  Color _roleColor(AppRole role) {
    switch (role) {
      case AppRole.si:
        return BafColors.navySoft;
      case AppRole.contractSupervisor:
        return BafColors.charges;
      case AppRole.shiftSupervisor:
        return BafColors.assets;
      case AppRole.seniorElectrical:
        return const Color(0xFFF59E0B);
      case AppRole.seniorMechanical:
        return BafColors.planned;
      case AppRole.seniorInstrumentation:
        return BafColors.audit;
      case AppRole.seniorRefractory:
        return BafColors.directives;
      case AppRole.refractory:
        return BafColors.directives;
      case AppRole.operations:
        return BafColors.sync;
      case AppRole.admin:
        return BafColors.admin;
    }
  }

  String _roleLabel(AppRole role) {
    switch (role) {
      case AppRole.si:
        return 'SI';
      case AppRole.contractSupervisor:
        return 'Contract Supervisor';
      case AppRole.shiftSupervisor:
        return 'Shift Supervisor';
      case AppRole.seniorElectrical:
        return 'Sr. Electrical';
      case AppRole.seniorMechanical:
        return 'Sr. Mechanical';
      case AppRole.seniorInstrumentation:
        return 'Sr. I&A';
      case AppRole.seniorRefractory:
        return 'Sr. Refractory';
      case AppRole.refractory:
        return 'Refractory';
      case AppRole.operations:
        return 'Operations';
      case AppRole.admin:
        return 'Admin';
    }
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
      case AssetType.governedCustom:
        return 'GOVERNED ASSET';
    }
  }
}

class _DirectiveTopRow extends StatelessWidget {
  final String title;
  final DirectiveStatus status;
  final Color statusColor;

  const _DirectiveTopRow({
    required this.title,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: const TextStyle(
        color: BafColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    );
    final badge = StatusBadge(
      label: status.name.toUpperCase(),
      color: statusColor,
    );
    if (MediaQuery.sizeOf(context).width < 480 ||
        MediaQuery.textScalerOf(context).scale(16) > 20) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: BafSpacing.sm),
          badge,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        const SizedBox(width: BafSpacing.sm),
        badge,
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: BafColors.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _RemarksBox extends StatelessWidget {
  final String text;

  const _RemarksBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notes_rounded,
            color: BafColors.textSecondary,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.3,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
