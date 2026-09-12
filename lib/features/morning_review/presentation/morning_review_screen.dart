import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/presentation/current_actor_gate.dart';
import '../../../core/persistence/durable_submission.dart';
import '../../reports/presentation/structured_report_pdf_screen.dart';
import '../domain/morning_review_models.dart';
import '../domain/morning_review_report.dart';
import '../providers/morning_review_providers.dart';
import '../services/morning_review_command_service.dart';
import 'morning_review_agenda_view.dart';
import 'morning_review_editors.dart';
import 'saved_morning_review_change_panel.dart';

part 'morning_review_screen.commands.dart';

class MorningReviewScreen extends ConsumerStatefulWidget {
  const MorningReviewScreen({super.key});

  @override
  ConsumerState<MorningReviewScreen> createState() =>
      _MorningReviewScreenState();
}

class _MorningReviewScreenState extends ConsumerState<MorningReviewScreen> {
  bool _busy = false;
  String? _reconciliationScheduledFor;
  DurableSubmission? _savedChange;
  String? _savedChangeError;

  void _update(VoidCallback action) => setState(action);

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    return actorAsync.when(
      skipLoadingOnRefresh: false,
      skipError: false,
      loading: () => BafScreenStateScaffold.loading(
        appBarTitle: 'Morning Review',
        appBarSubtitle: 'Daily plant coordination and action ownership',
        appBarIcon: Icons.groups_2_outlined,
        label: 'Loading review authority',
      ),
      error: (error, _) => BafScreenStateScaffold.error(
        appBarTitle: 'Morning Review',
        appBarSubtitle: 'Daily plant coordination and action ownership',
        appBarIcon: Icons.groups_2_outlined,
        message: '$error',
        onRetry: () => ref.invalidate(currentAppUserProvider),
      ),
      data: (actor) {
        if (actor == null || !actor.canViewMorningReview) {
          return const BafScreenStateScaffold(
            appBarTitle: 'Morning Review',
            appBarSubtitle: 'Daily plant coordination and action ownership',
            appBarIcon: Icons.groups_2_outlined,
            state: BafStatePanel(
              icon: Icons.lock_outline_rounded,
              color: BafColors.danger,
              title: 'Approved access required',
              message: 'Morning Review is available to approved plant users.',
            ),
          );
        }
        _schedulePendingReconciliation(actor);
        return _buildAuthorized(context, actor);
      },
    );
  }

  Widget _buildAuthorized(BuildContext context, AppUser actor) {
    final sessionAsync = ref.watch(currentMorningReviewSessionProvider);
    final recentAsync = ref.watch(recentMorningReviewSessionsProvider);
    final activeActionsAsync = ref.watch(activeMorningReviewActionsProvider);
    final concernsAsync = ref.watch(morningReviewStandingConcernsProvider);
    final assets =
        ref.watch(allAssetInstancesProvider).value ??
        const <AssetInstanceRecord>[];

    return DefaultTabController(
      length: 4,
      child: BafScreenScaffold(
        title: 'Morning Review',
        subtitle: 'Safety, asset status, decisions and owned actions',
        icon: Icons.groups_2_outlined,
        accent: BafColors.cobalt,
        actions: [
          IconButton(
            tooltip: 'Refresh Morning Review',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: Icon(Icons.view_agenda_outlined), text: 'Agenda'),
            Tab(icon: Icon(Icons.task_alt_outlined), text: 'Actions'),
            Tab(icon: Icon(Icons.how_to_reg_outlined), text: 'People'),
            Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'Archive'),
          ],
        ),
        body: Column(
          children: [
            if (_savedChange != null || _savedChangeError != null)
              SavedMorningReviewChangePanel(
                saved: _savedChange,
                error: _savedChangeError,
                busy: _busy,
                onCheck: () => unawaited(_reconcilePending(actor.uid)),
                onCancelNeverSent: () => unawaited(_cancelUnsentChange()),
              ),
            Expanded(
              child: sessionAsync.when(
                loading: () =>
                    const BafLoadingPanel(label: 'Loading today\'s review'),
                error: (error, _) =>
                    BafStatePanel.error(message: '$error', onPrimary: _refresh),
                data: (session) => session == null
                    ? _NoSessionTabs(
                        actor: actor,
                        busy: _busy,
                        recentAsync: recentAsync,
                        activeActionsAsync: activeActionsAsync,
                        concernsAsync: concernsAsync,
                        onStart: () => unawaited(_startReview()),
                        onNotHeld: () => unawaited(_recordNotHeld()),
                        onOpenArchive: _openArchive,
                        onAcceptAction:
                            (action) => unawaited(_acceptAction(action)),
                        onCompleteAction:
                            (action) => unawaited(_completeAction(action)),
                      )
                      : _buildSessionTabs(
                        actor: actor,
                        session: session,
                        recentAsync: recentAsync,
                        activeActionsAsync: activeActionsAsync,
                        concernsAsync: concernsAsync,
                        assets: assets,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTabs({
    required AppUser actor,
    required MorningReviewSession session,
    required AsyncValue<List<MorningReviewSession>> recentAsync,
    required AsyncValue<List<MorningReviewAction>> activeActionsAsync,
    required AsyncValue<List<MorningReviewStandingConcern>> concernsAsync,
    required List<AssetInstanceRecord> assets,
  }) {
    final participantsAsync = ref.watch(
      morningReviewParticipantsProvider(session.sessionId),
    );
    final entriesAsync = ref.watch(
      morningReviewEntriesProvider(session.sessionId),
    );
    final sessionActionsAsync = ref.watch(
      morningReviewActionsProvider(session.sessionId),
    );
    final checksAsync = ref.watch(
      morningReviewConcernChecksProvider(session.sessionId),
    );
    final participants =
        participantsAsync.value ?? const <MorningReviewParticipant>[];
    final joined = participants.any(
      (participant) => participant.userUid == actor.uid,
    );
    final currentActions =
        sessionActionsAsync.value ?? const <MorningReviewAction>[];
    final actionById = <String, MorningReviewAction>{
      for (final action
          in activeActionsAsync.value ?? const <MorningReviewAction>[])
        action.actionId: action,
      for (final action in currentActions) action.actionId: action,
    };
    final visibleActions = actionById.values.toList()..sort(_compareActions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SessionStrip(
          session: session,
          actor: actor,
          joined: joined,
          participantCount: participants.length,
          openActionCount:
              visibleActions
                  .where(
                    (action) =>
                        action.status != MorningReviewActionStatus.completed,
                  )
                  .length,
          busy: _busy,
          onJoin:
              session.isOpen && !joined
                  ? () => unawaited(_joinReview(session.sessionId))
                  : null,
          onTakeOver:
              session.isOpen &&
                      joined &&
                      actor.canFacilitateMorningReview &&
                      session.facilitatorUid != actor.uid
                  ? () => unawaited(_takeOver(session))
                  : null,
          onFinalize:
              session.isOpen &&
                      (session.facilitatorUid == actor.uid || actor.isAdmin)
                  ? () => unawaited(_finalize(session))
                  : null,
          onOpenRecord:
              session.isFinalized
                  ? () => _openArchive(session.sessionId)
                  : null,
        ),
        Expanded(
          child: TabBarView(
            children: [
              _AgendaBoundary(
                session: session,
                actor: actor,
                joined: joined,
                busy: _busy,
                entriesAsync: entriesAsync,
                concernsAsync: concernsAsync,
                checksAsync: checksAsync,
                onAddEntry:
                    session.isOpen && joined
                        ? (fact) => unawaited(
                          _addEntry(
                            actor: actor,
                            session: session,
                            assets: assets,
                            sourceFact: fact,
                          ),
                        )
                        : null,
                onAddConcern:
                    session.isOpen && joined
                        ? () => unawaited(_addStandingConcern(session))
                        : null,
                onCheckConcern:
                    session.isOpen && joined
                        ? (concern) =>
                            unawaited(_checkStandingConcern(session, concern))
                        : null,
                onResolveConcern:
                    session.isOpen && (actor.isAdmin || actor.isSI)
                        ? (concern) =>
                            unawaited(_resolveStandingConcern(session, concern))
                        : null,
                onAddAddendum:
                    session.isFinalized && (actor.isAdmin || actor.isSI)
                        ? () => unawaited(
                          _addAddendum(session: session, assets: assets),
                        )
                        : null,
              ),
              _ActionBoundary(
                actor: actor,
                busy: _busy,
                actions: visibleActions,
                hasError:
                    sessionActionsAsync.hasError || activeActionsAsync.hasError,
                error: sessionActionsAsync.error ?? activeActionsAsync.error,
                loading:
                    sessionActionsAsync.isLoading ||
                    activeActionsAsync.isLoading,
                canCreate: session.isOpen && joined,
                onCreate:
                    () => unawaited(
                      _createAction(
                        session: session,
                        assets: assets,
                        participants: participants,
                      ),
                    ),
                onAccept: (action) => unawaited(_acceptAction(action)),
                onComplete: (action) => unawaited(_completeAction(action)),
              ),
              _PeopleBoundary(
                session: session,
                actor: actor,
                joined: joined,
                busy: _busy,
                participantsAsync: participantsAsync,
                onJoin: () => unawaited(_joinReview(session.sessionId)),
              ),
              _ArchiveTab(recentAsync: recentAsync, onOpen: _openArchive),
            ],
          ),
        ),
      ],
    );
  }

  void _openArchive(String sessionId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MorningReviewRecordScreen(sessionId: sessionId),
      ),
    );
  }
}

class _NoSessionTabs extends StatelessWidget {
  const _NoSessionTabs({
    required this.actor,
    required this.busy,
    required this.recentAsync,
    required this.activeActionsAsync,
    required this.concernsAsync,
    required this.onStart,
    required this.onNotHeld,
    required this.onOpenArchive,
    required this.onAcceptAction,
    required this.onCompleteAction,
  });

  final AppUser actor;
  final bool busy;
  final AsyncValue<List<MorningReviewSession>> recentAsync;
  final AsyncValue<List<MorningReviewAction>> activeActionsAsync;
  final AsyncValue<List<MorningReviewStandingConcern>> concernsAsync;
  final VoidCallback onStart;
  final VoidCallback onNotHeld;
  final ValueChanged<String> onOpenArchive;
  final ValueChanged<MorningReviewAction> onAcceptAction;
  final ValueChanged<MorningReviewAction> onCompleteAction;

  @override
  Widget build(BuildContext context) => TabBarView(
    children: [
      _NoSessionAgenda(
        actor: actor,
        busy: busy,
        concernsAsync: concernsAsync,
        onStart: onStart,
        onNotHeld: onNotHeld,
      ),
      _ActionBoundary(
        actor: actor,
        busy: busy,
        actions: activeActionsAsync.value ?? const <MorningReviewAction>[],
        hasError: activeActionsAsync.hasError,
        error: activeActionsAsync.error,
        loading: activeActionsAsync.isLoading,
        canCreate: false,
        onCreate: null,
        onAccept: onAcceptAction,
        onComplete: onCompleteAction,
      ),
      BafStatePanel.empty(
        title: 'Attendance starts with the meeting',
        message:
            'Opening this page does not mark attendance. Use Join after an Admin or SI starts today\'s review.',
        icon: Icons.how_to_reg_outlined,
        color: BafColors.cobalt,
      ),
      _ArchiveTab(recentAsync: recentAsync, onOpen: onOpenArchive),
    ],
  );
}

class _NoSessionAgenda extends StatelessWidget {
  const _NoSessionAgenda({
    required this.actor,
    required this.busy,
    required this.concernsAsync,
    required this.onStart,
    required this.onNotHeld,
  });

  final AppUser actor;
  final bool busy;
  final AsyncValue<List<MorningReviewStandingConcern>> concernsAsync;
  final VoidCallback onStart;
  final VoidCallback onNotHeld;

  @override
  Widget build(BuildContext context) {
    final clock = DateTime.now();
    final minute = currentIndiaMinuteOfDay(clock);
    final withinWindow = minute >= 480 && minute <= 600;
    final missedWindow = minute > 600;
    final adminBypass = actor.isAdmin && !withinWindow;
    final canStartNow = canStartMorningReviewNow(actor, clock);
    final activeConcerns =
        (concernsAsync.value ?? const <MorningReviewStandingConcern>[])
            .where(
              (concern) => concern.status == MorningReviewConcernStatus.active,
            )
            .toList();
    final title =
        adminBypass
            ? 'Admin start override available'
            : minute < 480
            ? 'Today\'s review window has not opened'
            : missedWindow
            ? 'Today\'s review was not opened'
            : 'Ready for today\'s Morning Review';
    final message =
        adminBypass
            ? 'Admin may open today\'s session outside the standard 08:00–10:00 India-time window. The start remains attributed and audited.'
            : minute < 480
            ? 'An Admin or SI can open the single daily session between 08:00 and 10:00 India time.'
            : missedWindow
            ? 'An Admin or SI can record why the meeting was not held. A late meeting cannot be back-created.'
            : 'One Admin or SI opens the session. Other approved users join explicitly before contributing.';
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        BafContentFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BafStatePanel(
                icon:
                    canStartNow
                        ? Icons.schedule_rounded
                        : Icons.event_busy_outlined,
                color: canStartNow ? BafColors.cobalt : BafColors.textSecondary,
                title: title,
                message: message,
                primaryLabel:
                    canStartNow
                        ? 'Start Morning Review'
                        : actor.canStartMorningReview && missedWindow
                        ? 'Record not held'
                        : null,
                primaryIcon:
                    canStartNow
                        ? Icons.play_arrow_rounded
                        : Icons.event_busy_outlined,
                onPrimary: canStartNow ? onStart : onNotHeld,
                busy: busy,
              ),
              if (adminBypass && missedWindow) ...[
                const SizedBox(height: BafSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onNotHeld,
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Record review not held'),
                  ),
                ),
              ],
              if (activeConcerns.isNotEmpty) ...[
                const SizedBox(height: BafSpacing.xl),
                BafSectionLabel(
                  title: 'Concerns still carried',
                  subtitle:
                      '${activeConcerns.length} active item${activeConcerns.length == 1 ? '' : 's'} will lead the next meeting.',
                ),
                const SizedBox(height: BafSpacing.md),
                ...activeConcerns.map(
                  (concern) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    child: MorningReviewConcernCard(concern: concern),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

bool canStartMorningReviewNow(AppUser actor, [DateTime? clock]) {
  if (!actor.canStartMorningReview) return false;
  if (actor.isAdmin) return true;
  final minute = currentIndiaMinuteOfDay(clock);
  return minute >= 480 && minute <= 600;
}

class _SessionStrip extends StatelessWidget {
  const _SessionStrip({
    required this.session,
    required this.actor,
    required this.joined,
    required this.participantCount,
    required this.openActionCount,
    required this.busy,
    required this.onJoin,
    required this.onTakeOver,
    required this.onFinalize,
    required this.onOpenRecord,
  });

  final MorningReviewSession session;
  final AppUser actor;
  final bool joined;
  final int participantCount;
  final int openActionCount;
  final bool busy;
  final VoidCallback? onJoin;
  final VoidCallback? onTakeOver;
  final VoidCallback? onFinalize;
  final VoidCallback? onOpenRecord;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: BafColors.surfaceRaised,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.sm,
        BafSpacing.lg,
        BafSpacing.md,
      ),
      child: Wrap(
        spacing: BafSpacing.sm,
        runSpacing: BafSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusPill(
            icon:
                session.isOpen
                    ? Icons.radio_button_checked
                    : Icons.verified_outlined,
            label: session.isOpen ? 'Live' : 'Finalized',
            color: session.isOpen ? BafColors.success : BafColors.cobalt,
          ),
          _StatusPill(
            icon: Icons.person_outline_rounded,
            label: session.facilitatorName,
            color: BafColors.admin,
          ),
          _StatusPill(
            icon: Icons.groups_outlined,
            label: '$participantCount joined',
            color: BafColors.cobalt,
          ),
          _StatusPill(
            icon: Icons.task_alt_outlined,
            label: '$openActionCount active actions',
            color: openActionCount == 0 ? BafColors.success : BafColors.warning,
          ),
          if (session.isOpen)
            _StatusPill(
              icon:
                  joined ? Icons.how_to_reg_rounded : Icons.visibility_outlined,
              label: joined ? 'Attendance recorded' : 'Viewing only',
              color: joined ? BafColors.success : BafColors.textSecondary,
            ),
          if (onJoin != null)
            FilledButton.icon(
              onPressed: busy ? null : onJoin,
              icon: const Icon(Icons.how_to_reg_outlined),
              label: const Text('Join'),
            ),
          if (onTakeOver != null)
            OutlinedButton.icon(
              onPressed: busy ? null : onTakeOver,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Take over'),
            ),
          if (onFinalize != null)
            FilledButton.icon(
              onPressed: busy ? null : onFinalize,
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Finalize'),
              style: FilledButton.styleFrom(
                backgroundColor: BafColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          if (onOpenRecord != null)
            OutlinedButton.icon(
              onPressed: onOpenRecord,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Meeting record'),
            ),
        ],
      ),
    ),
  );
}

class _AgendaBoundary extends StatelessWidget {
  const _AgendaBoundary({
    required this.session,
    required this.actor,
    required this.joined,
    required this.busy,
    required this.entriesAsync,
    required this.concernsAsync,
    required this.checksAsync,
    required this.onAddEntry,
    required this.onAddConcern,
    required this.onCheckConcern,
    required this.onResolveConcern,
    required this.onAddAddendum,
  });

  final MorningReviewSession session;
  final AppUser actor;
  final bool joined;
  final bool busy;
  final AsyncValue<List<MorningReviewEntry>> entriesAsync;
  final AsyncValue<List<MorningReviewStandingConcern>> concernsAsync;
  final AsyncValue<List<MorningReviewConcernCheck>> checksAsync;
  final ValueChanged<MorningReviewSourceFact?>? onAddEntry;
  final VoidCallback? onAddConcern;
  final ValueChanged<MorningReviewStandingConcern>? onCheckConcern;
  final ValueChanged<MorningReviewStandingConcern>? onResolveConcern;
  final VoidCallback? onAddAddendum;

  @override
  Widget build(BuildContext context) {
    if (entriesAsync.hasError ||
        concernsAsync.hasError ||
        checksAsync.hasError) {
      return BafStatePanel.error(
        message:
            '${entriesAsync.error ?? concernsAsync.error ?? checksAsync.error}',
      );
    }
    if (entriesAsync.isLoading ||
        concernsAsync.isLoading ||
        checksAsync.isLoading) {
      return const BafLoadingPanel(label: 'Loading the meeting agenda');
    }
    return MorningReviewAgendaView(
      session: session,
      joined: joined,
      busy: busy,
      entries: entriesAsync.value ?? const [],
      concerns: concernsAsync.value ?? const [],
      checks: checksAsync.value ?? const [],
      onAddEntry: onAddEntry,
      onAddConcern: onAddConcern,
      onCheckConcern: onCheckConcern,
      onResolveConcern: onResolveConcern,
      onAddAddendum: onAddAddendum,
    );
  }
}

class _ActionBoundary extends StatelessWidget {
  const _ActionBoundary({
    required this.actor,
    required this.busy,
    required this.actions,
    required this.hasError,
    required this.error,
    required this.loading,
    required this.canCreate,
    required this.onCreate,
    required this.onAccept,
    required this.onComplete,
  });

  final AppUser actor;
  final bool busy;
  final List<MorningReviewAction> actions;
  final bool hasError;
  final Object? error;
  final bool loading;
  final bool canCreate;
  final VoidCallback? onCreate;
  final ValueChanged<MorningReviewAction> onAccept;
  final ValueChanged<MorningReviewAction> onComplete;

  @override
  Widget build(BuildContext context) {
    if (hasError) return BafStatePanel.error(message: '$error');
    if (loading) {
      return const BafLoadingPanel(label: 'Loading owned actions');
    }
    return _ActionTab(
      actor: actor,
      busy: busy,
      actions: actions,
      canCreate: canCreate,
      onCreate: onCreate,
      onAccept: onAccept,
      onComplete: onComplete,
    );
  }
}

class _ActionTab extends StatelessWidget {
  const _ActionTab({
    required this.actor,
    required this.busy,
    required this.actions,
    required this.canCreate,
    required this.onCreate,
    required this.onAccept,
    required this.onComplete,
  });

  final AppUser actor;
  final bool busy;
  final List<MorningReviewAction> actions;
  final bool canCreate;
  final VoidCallback? onCreate;
  final ValueChanged<MorningReviewAction> onAccept;
  final ValueChanged<MorningReviewAction> onComplete;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      BafContentFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BafScreenIntro(
              title: 'Actions that remain owned',
              subtitle:
                  'Open actions survive the meeting record and remain here until completion.',
              icon: Icons.task_alt_outlined,
              accent: BafColors.warning,
              trailing:
                  canCreate
                      ? FilledButton.icon(
                        onPressed: busy ? null : onCreate,
                        icon: const Icon(Icons.assignment_add),
                        label: const Text('Create action'),
                      )
                      : null,
            ),
            const SizedBox(height: BafSpacing.xl),
            if (actions.isEmpty)
              BafStatePanel.empty(
                title: 'No active Morning Review actions',
                message:
                    'Actions created in a meeting will remain visible until their owner completes them.',
                icon: Icons.task_alt_outlined,
                color: BafColors.success,
              )
            else
              ...actions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                  child: _ActionCard(
                    action: action,
                    canMutate: _canMutateAction(actor, action),
                    busy: busy,
                    onAccept: () => onAccept(action),
                    onComplete: () => onComplete(action),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _PeopleBoundary extends StatelessWidget {
  const _PeopleBoundary({
    required this.session,
    required this.actor,
    required this.joined,
    required this.busy,
    required this.participantsAsync,
    required this.onJoin,
  });

  final MorningReviewSession session;
  final AppUser actor;
  final bool joined;
  final bool busy;
  final AsyncValue<List<MorningReviewParticipant>> participantsAsync;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => participantsAsync.when(
    loading: () => const BafLoadingPanel(label: 'Loading attendance'),
    error: (error, _) => BafStatePanel.error(message: '$error'),
    data: (participants) => ListView(
      children: [
        BafContentFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BafScreenIntro(
                title: 'Explicit attendance',
                subtitle:
                    'Only users who select Join appear in the meeting record.',
                icon: Icons.how_to_reg_outlined,
                accent: BafColors.cobalt,
                trailing: session.isOpen && !joined
                    ? FilledButton.icon(
                        onPressed: busy ? null : onJoin,
                        icon: const Icon(Icons.how_to_reg_outlined),
                        label: const Text('Join review'),
                      )
                    : null,
              ),
              const SizedBox(height: BafSpacing.xl),
              ...participants.map(
                (participant) => Padding(
                  padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                  child: _ParticipantCard(
                    participant: participant,
                    isFacilitator:
                        participant.userUid == session.facilitatorUid,
                    isCurrentUser: participant.userUid == actor.uid,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ArchiveTab extends StatelessWidget {
  const _ArchiveTab({required this.recentAsync, required this.onOpen});

  final AsyncValue<List<MorningReviewSession>> recentAsync;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => recentAsync.when(
    loading: () => const BafLoadingPanel(label: 'Loading meeting records'),
    error: (error, _) => BafStatePanel.error(message: '$error'),
    data: (sessions) => ListView(
      children: [
        BafContentFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BafScreenIntro(
                title: 'Recent meeting records',
                subtitle:
                    'Final records remain available for 14 days after finalization.',
                icon: Icons.picture_as_pdf_outlined,
                accent: BafColors.audit,
              ),
              const SizedBox(height: BafSpacing.xl),
              if (sessions.isEmpty)
                BafStatePanel.empty(
                  title: 'No retained meeting records',
                  message:
                      'Finalized and not-held records will appear here during their retention period.',
                  icon: Icons.inventory_2_outlined,
                  color: BafColors.audit,
                )
              else
                ...sessions.map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    child: BafRecordSurface(
                      onTap: session.isOpen
                          ? null
                          : () => onOpen(session.sessionId),
                      accent: session.isOpen
                          ? BafColors.success
                          : session.status == MorningReviewStatus.notHeld
                          ? BafColors.warning
                          : BafColors.audit,
                      child: Row(
                        children: [
                          Icon(
                            session.isOpen
                                ? Icons.radio_button_checked
                                : session.status == MorningReviewStatus.notHeld
                                ? Icons.event_busy_outlined
                                : Icons.picture_as_pdf_outlined,
                          ),
                          const SizedBox(width: BafSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.plantDay,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  session.status == MorningReviewStatus.notHeld
                                      ? 'Not held · ${session.finalSummary}'
                                      : session.isOpen
                                      ? 'Live · ${session.facilitatorName}'
                                      : 'Finalized by ${session.finalizedByName}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (!session.isOpen)
                            const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MorningReviewRecordScreen extends ConsumerWidget {
  const MorningReviewRecordScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentAsync = ref.watch(morningReviewDocumentProvider(sessionId));
    final entriesAsync = ref.watch(morningReviewEntriesProvider(sessionId));
    return BafScreenScaffold(
      title: 'Meeting Record',
      subtitle: sessionId,
      icon: Icons.picture_as_pdf_outlined,
      accent: BafColors.audit,
      body: documentAsync.when(
        loading: () => const BafLoadingPanel(label: 'Loading meeting record'),
        error: (error, _) => BafStatePanel.error(message: '$error'),
        data: (document) {
          if (document == null) {
            return BafStatePanel.empty(
              title: 'Record no longer retained',
              message:
                  'The governed 14-day application retention period has ended, or the meeting has not yet been finalized.',
              icon: Icons.event_busy_outlined,
              color: BafColors.textSecondary,
            );
          }
          if (entriesAsync.isLoading) {
            return const BafLoadingPanel(
              label: 'Loading retained addenda for the meeting record',
            );
          }
          if (entriesAsync.hasError) {
            return BafStatePanel.error(message: '${entriesAsync.error}');
          }
          final addenda = (entriesAsync.value ?? const <MorningReviewEntry>[])
              .where((entry) => entry.kind == MorningReviewEntryKind.addendum)
              .toList();
          return ListView(
            children: [
              BafContentFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BafScreenIntro(
                      title: document.title,
                      subtitle:
                          document.status == MorningReviewStatus.notHeld
                              ? 'Meeting not held'
                              : 'Frozen source, attendance and action record',
                      icon: Icons.inventory_2_outlined,
                      accent: BafColors.audit,
                      trailing: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => StructuredReportPdfPreviewScreen(
                                    report: buildMorningReviewReport(
                                      document: document,
                                      addenda: addenda,
                                    ),
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Open PDF'),
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xl),
                    BafRecordSurface(
                      accent: BafColors.audit,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.finalSummary,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: BafSpacing.md),
                          Wrap(
                            spacing: BafSpacing.sm,
                            runSpacing: BafSpacing.sm,
                            children: [
                              _StatusPill(
                                icon: Icons.person_outline_rounded,
                                label: document.facilitatorName ?? 'Not held',
                                color: BafColors.admin,
                              ),
                              _StatusPill(
                                icon: Icons.groups_outlined,
                                label:
                                    '${document.participants.length} participants',
                                color: BafColors.cobalt,
                              ),
                              _StatusPill(
                                icon: Icons.task_alt_outlined,
                                label: '${document.actions.length} actions',
                                color: BafColors.warning,
                              ),
                              _StatusPill(
                                icon: Icons.push_pin_outlined,
                                label:
                                    '${document.standingConcerns.length} concerns',
                                color:
                                    document.standingConcerns.any(
                                          (concern) =>
                                              concern.status ==
                                              MorningReviewConcernStatus.active,
                                        )
                                        ? BafColors.warning
                                        : BafColors.success,
                              ),
                              _StatusPill(
                                icon: Icons.note_add_outlined,
                                label: '${addenda.length} addenda',
                                color: BafColors.audit,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.canMutate,
    required this.busy,
    required this.onAccept,
    required this.onComplete,
  });

  final MorningReviewAction action;
  final bool canMutate;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final completed = action.status == MorningReviewActionStatus.completed;
    final owner =
        action.assigneeRole == null
            ? action.assigneeName ?? action.assigneeUid ?? 'Unassigned'
            : morningReviewRoleLabel(action.assigneeRole!);
    final color =
        completed
            ? BafColors.success
            : action.dueAt?.isBefore(DateTime.now()) == true
            ? BafColors.danger
            : BafColors.warning;
    return BafRecordSurface(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.task_alt_outlined, color: color),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  action.text,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusPill(
                icon:
                    completed
                        ? Icons.check_rounded
                        : action.status == MorningReviewActionStatus.accepted
                        ? Icons.handshake_outlined
                        : Icons.schedule_outlined,
                label: action.status.name,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            '${_assetLabel(action.assetClassName, action.assetNumber)} · $owner',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          Text(
            action.completedAt != null
                ? 'Completed ${DateFormat('dd MMM yyyy, HH:mm').format(_indiaTime(action.completedAt!))} IST by ${action.completedByName}'
                : action.dueAt == null
                ? 'No due time · from ${action.sessionId}'
                : 'Due ${DateFormat('dd MMM yyyy, HH:mm').format(_indiaTime(action.dueAt!))} IST · from ${action.sessionId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (action.completionNote != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(action.completionNote!),
          ],
          if (canMutate && !completed) ...[
            const SizedBox(height: BafSpacing.sm),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                if (action.status == MorningReviewActionStatus.open)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onAccept,
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Accept'),
                  ),
                FilledButton.icon(
                  onPressed: busy ? null : onComplete,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BafColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.participant,
    required this.isFacilitator,
    required this.isCurrentUser,
  });

  final MorningReviewParticipant participant;
  final bool isFacilitator;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) => BafRecordSurface(
    accent: isFacilitator ? BafColors.cobalt : null,
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: BafColors.surfaceMuted,
          child: Text(
            participant.userName.isEmpty
                ? 'U'
                : participant.userName[0].toUpperCase(),
          ),
        ),
        const SizedBox(width: BafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                participant.userName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                participant.roleKeys.map(morningReviewRoleLabel).join(', '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Joined ${DateFormat('HH:mm').format(_indiaTime(participant.joinedAt))} IST',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (isFacilitator)
          const _StatusPill(
            icon: Icons.record_voice_over_outlined,
            label: 'Facilitator',
            color: BafColors.cobalt,
          )
        else if (isCurrentUser)
          const _StatusPill(
            icon: Icons.person_outline_rounded,
            label: 'You',
            color: BafColors.success,
          ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
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
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

bool _canMutateAction(AppUser actor, MorningReviewAction action) =>
    actor.isAdmin ||
    actor.isSI ||
    action.assigneeUid == actor.uid ||
    actor.roles.any((role) => role.name == action.assigneeRole);

int _compareActions(MorningReviewAction left, MorningReviewAction right) {
  final byStatus = left.status.index.compareTo(right.status.index);
  if (byStatus != 0) return byStatus;
  final leftDue = left.dueAt;
  final rightDue = right.dueAt;
  if (leftDue == null && rightDue != null) return 1;
  if (leftDue != null && rightDue == null) return -1;
  if (leftDue != null && rightDue != null) {
    final byDue = leftDue.compareTo(rightDue);
    if (byDue != 0) return byDue;
  }
  return left.createdAt.compareTo(right.createdAt);
}

String _assetLabel(String? assetClassName, String? assetNumber) =>
    assetClassName == null || assetNumber == null
        ? 'Plant-wide'
        : '$assetClassName $assetNumber';

DateTime _indiaTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 5, minutes: 30));
