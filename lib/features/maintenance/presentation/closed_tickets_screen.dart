// FILE: lib/features/maintenance/presentation/closed_tickets_screen.dart

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/maintenance_model.dart';
import '../domain/maintenance_ticket_correction.dart';
import '../providers/maintenance_provider.dart';
import '../services/closed_ticket_history_service.dart';
import '../services/maintenance_issue_command_reconciler.dart';
import '../services/maintenance_issue_resolution_command.dart';
import '../../../core/providers/refresh_providers.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../features/auth/data/user_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../planned_maintenance/data/maintenance_intelligence.dart';
import '../../planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'maintenance_ticket_correction_dialog.dart';
import 'maintenance_ticket_detail_screen.dart';

part 'closed_tickets_screen.corrections.dart';
part 'closed_tickets_screen.record_actions.dart';

class ClosedTicketsScreen extends ConsumerWidget {
  const ClosedTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    return actorAsync.when(
      loading:
          () => BafScreenStateScaffold.loading(
            appBarTitle: 'Closed issue history',
            appBarSubtitle: 'Resolved work and administrative closures',
            appBarIcon: Icons.inventory_2_outlined,
            accent: BafColors.maintenance,
            label: 'Checking closure-history access',
          ),
      error:
          (_, _) => BafScreenStateScaffold.error(
            appBarTitle: 'Closed issue history',
            appBarSubtitle: 'Resolved work and administrative closures',
            appBarIcon: Icons.inventory_2_outlined,
            accent: BafColors.maintenance,
            message: 'Could not verify closure-history access.',
          ),
      data: (actor) {
        if (actor == null || !actor.canViewClosedMaintenanceTickets) {
          return BafScreenStateScaffold.access(
            appBarTitle: 'Closed issue history',
            appBarSubtitle: 'Resolved work and administrative closures',
            appBarIcon: Icons.inventory_2_outlined,
            accent: BafColors.maintenance,
            title: 'History access required',
            message:
                'An approved app account is required to view closed records.',
          );
        }
        return _ClosedTicketsBody(actor: actor);
      },
    );
  }
}

class _ClosedTicketsBody extends ConsumerStatefulWidget {
  const _ClosedTicketsBody({required this.actor});

  final AppUser actor;

  @override
  ConsumerState<_ClosedTicketsBody> createState() =>
      _ClosedTicketsScreenState();
}

class _ClosedTicketsScreenState extends ConsumerState<_ClosedTicketsBody> {
  int _currentPage = 0;
  final int _pageSize = 20;
  final List<MaintenanceRecord> _tickets = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _totalCount = 0;
  ClosedTicketPageCursor? _lastDocument;
  final Set<String> _reopeningTicketKeys = <String>{};
  final Set<String> _classifyingTicketKeys = <String>{};
  final Set<String> _correctingTicketKeys = <String>{};
  late final ProviderSubscription<int> _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _refreshSubscription = ref.listenManual<int>(refreshClosedTicketsProvider, (
      previous,
      next,
    ) {
      if (next != previous) {
        _loadInitial();
      }
    });
    _loadInitial();
  }

  @override
  void dispose() {
    _refreshSubscription.close();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (!mounted) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(closedTicketHistoryServiceProvider);
      final count = await service.count(actor: widget.actor);
      final page = await service.loadPage(
        actor: widget.actor,
        limit: _pageSize,
        offset: 0,
      );
      final tickets = page.records;

      if (!mounted) {
        return;
      }

      setState(() {
        _totalCount = count;
        _tickets
          ..clear()
          ..addAll(tickets);
        _hasMore = tickets.length == _pageSize && _tickets.length < _totalCount;
        _currentPage = 0;
        _lastDocument = page.cursor;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showSnack(
        message: 'Error loading closed tickets: $e',
        color: BafColors.danger,
      );
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (kIsWeb && _tickets.isNotEmpty && _lastDocument == null) {
      await _loadInitial();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(closedTicketHistoryServiceProvider);
      final nextPage = _currentPage + 1;
      final page = await service.loadPage(
        actor: widget.actor,
        limit: _pageSize,
        offset: nextPage * _pageSize,
        cursor: _lastDocument,
      );
      final nextTickets = page.records;

      if (!mounted) {
        return;
      }

      setState(() {
        _tickets.addAll(nextTickets);
        _hasMore =
            nextTickets.length == _pageSize && _tickets.length < _totalCount;
        _currentPage = nextPage;
        if (page.cursor != null) {
          _lastDocument = page.cursor;
        } else if (kIsWeb && nextTickets.isNotEmpty && _hasMore) {
          _hasMore = false;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showSnack(
        message: 'Error loading more tickets: $e',
        color: BafColors.danger,
      );
    }
  }

  static String _ticketKey(MaintenanceRecord ticket) {
    final firestoreId = ticket.firestoreId?.trim();
    if (firestoreId != null && firestoreId.isNotEmpty) {
      return 'fs:$firestoreId';
    }
    return 'local:${ticket.id}';
  }

  Future<void> _reopenTicket(MaintenanceRecord ticket) async {
    if (!ticket.isSynced) {
      _showSnack(
        message: 'Synchronize this issue before reopening it.',
        color: BafColors.warning,
      );
      return;
    }
    if (ticket.workflowDeferred) {
      _showSnack(
        message:
            'This ticket is held by workflow compliance and cannot be reopened here.',
        color: BafColors.warning,
      );
      return;
    }
    final remarks = await showDialog<String>(
      context: context,
      builder:
          (_) => _ReopenTicketDialog(
            ticketLabel:
                '${_assetTypeLabel(ticket.assetType)} ${ticket.assetNumber}',
          ),
    );

    if (!mounted || remarks == null) {
      return;
    }

    final ticketKey = _ticketKey(ticket);
    if (_reopeningTicketKeys.contains(ticketKey)) {
      return;
    }
    setState(() => _reopeningTicketKeys.add(ticketKey));

    try {
      final appUser = ref.read(currentAppUserProvider).value;
      final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
      if (appUser == null ||
          firebaseUser == null ||
          firebaseUser.uid != appUser.uid ||
          !appUser.canReopenMaintenanceTicket) {
        throw StateError(
          'You are not authorized to reopen maintenance tickets.',
        );
      }
      final ticketId = ticket.firestoreId?.trim();
      if (ticketId == null || ticketId.isEmpty) {
        throw StateError('This issue has no governed server identity.');
      }
      final command = buildMaintenanceIssueReopenCommand(
        ticket: ticket,
        remarks: remarks,
      );
      final expectedLocalVersion = ticket.version;
      final expectedLocalUpdatedAt = ticket.updatedAt.toUtc();
      final receipt = await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      validateMaintenanceIssueReopenReceipt(
        command: command,
        receipt: receipt,
        assignedLanes: ticket.issueLanePlan.assignedLanes,
      );

      var converged = false;
      if (kIsWeb) {
        final remote = await ref
            .read(firestoreMaintenanceRepo)
            .readMaintenanceIssueCommandServerState(ticketId);
        final remotePlan = remote?.issueLanePlanReadResult.value;
        converged =
            remote != null &&
            remote.version >= receipt.aggregateVersion &&
            !remote.isResolved &&
            remote.status == TicketStatus.open &&
            remotePlan != null &&
            remotePlan.acknowledgedLanes.isEmpty &&
            remotePlan.completedLanes.isEmpty;
      } else {
        try {
          await ref
              .read(maintenanceIssueCommandReconcilerProvider)
              .adoptServerMutation(
                firestoreId: ticketId,
                expectedLocalVersion: expectedLocalVersion,
                expectedLocalUpdatedAt: expectedLocalUpdatedAt,
                minimumServerVersion: receipt.aggregateVersion,
              );
          converged = true;
        } on MaintenanceIssueCommandConvergenceException {
          converged = false;
        }
      }

      try {
        await ref
            .read(syncCoordinatorProvider)
            .runFullSync(reason: 'ticket_reopened', force: true);
      } catch (_) {
        // The server has already accepted the reopen. A later sync can repeat
        // exact point-read adoption without recreating the transition.
      }
      ref.read(refreshClosedTicketsProvider.notifier).state++;

      final message =
          converged
              ? 'Ticket reopened and verified against the plant system.'
              : 'Ticket reopen accepted. Exact device refresh is pending and will retry during sync.';
      final color = converged ? BafColors.maintenance : BafColors.warning;
      _showSnack(message: message, color: color);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnack(message: 'Failed to reopen: $e', color: BafColors.danger);
    } finally {
      if (mounted) {
        setState(() => _reopeningTicketKeys.remove(ticketKey));
      }
    }
  }

  Future<void> _classifyTicket(
    MaintenanceRecord ticket,
    List<MaintenanceClassDefinition> definitions,
  ) async {
    final ticketId = ticket.firestoreId?.trim();
    if (ticketId == null || ticketId.isEmpty) return;
    final current = _ticketMaintenanceClass(ticket);
    final draft = await showDialog<_TicketClassificationDraft>(
      context: context,
      builder:
          (_) => _TicketClassificationDialog(
            definitions: definitions,
            current: current,
          ),
    );
    if (draft == null || !mounted) return;
    final ticketKey = _ticketKey(ticket);
    setState(() => _classifyingTicketKeys.add(ticketKey));
    try {
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(
            WorkflowCommand(
              commandId: WorkflowCommandFactory.uniqueId(
                'classify_maintenance_ticket',
              ),
              type: WorkflowCommandType.classifyMaintenanceTicket,
              aggregateId: ticketId,
              expectedVersion: ticket.version,
              payload: {
                'definitionId': draft.definition.id,
                'definitionVersion': draft.definition.version,
                'reason': draft.reason,
              },
            ),
          );
      await ref
          .read(syncCoordinatorProvider)
          .runFullSync(reason: 'maintenance_issue_classified', force: true);
      await _loadInitial();
      _showSnack(
        message: 'Maintenance class recorded against the actual closure time.',
        color: BafColors.success,
      );
    } catch (error) {
      _showSnack(
        message: 'Could not classify maintenance: $error',
        color: BafColors.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _classifyingTicketKeys.remove(ticketKey));
      }
    }
  }

  void _showSnack({required String message, required Color color}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _setCorrectionBusy(String ticketKey, bool busy) {
    if (!mounted) return;
    setState(
      () =>
          busy
              ? _correctingTicketKeys.add(ticketKey)
              : _correctingTicketKeys.remove(ticketKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).value;
    final canReopenTickets = appUser?.canReopenMaintenanceTicket == true;
    final canCorrectTickets = appUser?.canCorrectMaintenanceTicket == true;
    final maintenanceClasses =
        ref.watch(maintenanceClassDefinitionsProvider).value ??
        const <MaintenanceClassDefinition>[];

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Closed issues',
          subtitle: 'Resolution evidence and administrative dispositions',
          icon: Icons.history_rounded,
          accent: BafColors.maintenance,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child:
            _isLoading && _tickets.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _tickets.isEmpty
                ? const _ClosedTicketsEmptyState()
                : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.lg,
                    BafSpacing.md,
                    BafSpacing.lg,
                    BafSpacing.xl,
                  ),
                  itemCount: _tickets.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: BafSpacing.lg),
                        child: _ClosedTicketsHeader(
                          totalCount: _totalCount,
                          loadedCount: _tickets.length,
                          hasMore: _hasMore,
                        ),
                      );
                    }

                    if (index == _tickets.length + 1) {
                      return _LoadMoreFooter(
                        isLoading: _isLoading,
                        hasMore: _hasMore,
                        onLoadMore: _loadNextPage,
                      );
                    }

                    final ticket = _tickets[index - 1];
                    final ticketKey = _ticketKey(ticket);
                    final assetClassId =
                        ticket.assetHierarchyReference?.assetClassId;
                    final matchingClasses =
                        maintenanceClasses
                            .where(
                              (definition) => definition.appliesTo(
                                assetTypeKey: ticket.assetType.name,
                                assetClassId: assetClassId,
                              ),
                            )
                            .toList();
                    final closedAt = ticket.endDate ?? ticket.updatedAt;
                    final reopenWindowElapsed =
                        DateTime.now().difference(closedAt).inHours >= 4;
                    return Padding(
                      key: ValueKey(ticketKey),
                      padding: const EdgeInsets.only(bottom: BafSpacing.md),
                      child: _ClosedTicketCard(
                        ticket: ticket,
                        onViewDetails:
                            () => _openTicketDetails(
                              ticket,
                              canCorrect: canCorrectTickets && ticket.isSynced,
                            ),
                        canCorrect: canCorrectTickets && ticket.isSynced,
                        isCorrecting: _correctingTicketKeys.contains(ticketKey),
                        onCorrect: () => _correctTicket(ticket),
                        canReopenTicket: canReopenTickets,
                        isReopening: _reopeningTicketKeys.contains(ticketKey),
                        onReopen: () => _reopenTicket(ticket),
                        maintenanceClass: _ticketMaintenanceClass(ticket),
                        canClassify:
                            appUser?.canClassifyCompletedMaintenance == true &&
                            ticket.wasTechnicallyResolved &&
                            reopenWindowElapsed &&
                            ticket.assetType != AssetType.innerCover &&
                            ticket.firestoreId?.trim().isNotEmpty == true &&
                            matchingClasses.isNotEmpty,
                        isClassifying: _classifyingTicketKeys.contains(
                          ticketKey,
                        ),
                        onClassify:
                            () => _classifyTicket(ticket, matchingClasses),
                      ),
                    );
                  },
                ),
      ),
    );
  }

  FrozenMaintenanceClass? _ticketMaintenanceClass(MaintenanceRecord ticket) {
    final metadata = ticket.metadataJson?.trim();
    if (metadata == null || metadata.isEmpty) return null;
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is! Map || decoded['maintenanceClassification'] is! Map) {
        return null;
      }
      return FrozenMaintenanceClass.fromMap(
        Map<String, dynamic>.from(decoded['maintenanceClassification'] as Map),
        source: 'maintenance ${ticket.firestoreId}/maintenanceClassification',
      );
    } on Object {
      return null;
    }
  }

  static String _assetTypeLabel(AssetType type) {
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

class _ReopenTicketDialog extends StatefulWidget {
  final String ticketLabel;

  const _ReopenTicketDialog({required this.ticketLabel});

  @override
  State<_ReopenTicketDialog> createState() => _ReopenTicketDialogState();
}

class _ReopenTicketDialogState extends State<_ReopenTicketDialog> {
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reopen Ticket'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.ticketLabel,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              const Text(
                'Reopening will move this record back to open issues for attending teams.',
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: BafSpacing.lg),
              TextField(
                controller: _remarksController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: 'Reason for reopening (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                  ),
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
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _remarksController.text),
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.maintenance,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reopen'),
        ),
      ],
    );
  }
}

class _TicketClassificationDraft {
  const _TicketClassificationDraft({
    required this.definition,
    required this.reason,
  });

  final MaintenanceClassDefinition definition;
  final String reason;
}

class _TicketClassificationDialog extends StatefulWidget {
  const _TicketClassificationDialog({
    required this.definitions,
    required this.current,
  });

  final List<MaintenanceClassDefinition> definitions;
  final FrozenMaintenanceClass? current;

  @override
  State<_TicketClassificationDialog> createState() =>
      _TicketClassificationDialogState();
}

class _TicketClassificationDialogState
    extends State<_TicketClassificationDialog> {
  late String _definitionId;
  late final TextEditingController _reason;

  @override
  void initState() {
    super.initState();
    final currentId = widget.current?.definitionId;
    _definitionId =
        widget.definitions.any((item) => item.id == currentId)
            ? currentId!
            : widget.definitions.first.id;
    _reason = TextEditingController(
      text:
          widget.current == null
              ? 'Classify final resolved issue work against the reviewed scope.'
              : 'Correct the completed issue classification with audited evidence.',
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.current == null
            ? 'Classify completed maintenance'
            : 'Correct maintenance class',
      ),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This writes an immutable completion event at the issue’s actual closure time and updates the applicable cadence counters.',
              style: TextStyle(color: BafColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _definitionId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Maintenance class'),
              items:
                  widget.definitions
                      .map(
                        (definition) => DropdownMenuItem(
                          value: definition.id,
                          child: Text(definition.title),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) =>
                      setState(() => _definitionId = value ?? _definitionId),
            ),
            const SizedBox(height: BafSpacing.sm),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Classification reason',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final definition = widget.definitions.firstWhere(
              (item) => item.id == _definitionId,
            );
            final reason = _reason.text.trim();
            if (reason.length < 5) return;
            Navigator.pop(
              context,
              _TicketClassificationDraft(
                definition: definition,
                reason: reason,
              ),
            );
          },
          icon: const Icon(Icons.event_repeat_rounded),
          label: const Text('Record class'),
        ),
      ],
    );
  }
}

class _ClosedTicketsHeader extends StatelessWidget {
  final int totalCount;
  final int loadedCount;
  final bool hasMore;

  const _ClosedTicketsHeader({
    required this.totalCount,
    required this.loadedCount,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BafColors.audit.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: BafColors.audit,
              size: 30,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Closed issue records',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                const Text(
                  'Review technical resolutions and issues closed without resolution.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: '$loadedCount loaded',
                      color: BafColors.audit,
                      icon: Icons.list_alt_rounded,
                    ),
                    StatusBadge(
                      label: '$totalCount total',
                      color: BafColors.admin,
                      icon: Icons.inventory_2_rounded,
                    ),
                    StatusBadge(
                      label: hasMore ? 'More available' : 'All loaded',
                      color: hasMore ? BafColors.warning : BafColors.sync,
                      icon:
                          hasMore
                              ? Icons.expand_more_rounded
                              : Icons.check_circle_rounded,
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

class _ClosedTicketCard extends StatelessWidget {
  final MaintenanceRecord ticket;
  final VoidCallback onViewDetails;
  final bool canCorrect;
  final bool isCorrecting;
  final VoidCallback onCorrect;
  final bool canReopenTicket;
  final bool isReopening;
  final VoidCallback onReopen;
  final FrozenMaintenanceClass? maintenanceClass;
  final bool canClassify;
  final bool isClassifying;
  final VoidCallback onClassify;

  const _ClosedTicketCard({
    required this.ticket,
    required this.onViewDetails,
    required this.canCorrect,
    required this.isCorrecting,
    required this.onCorrect,
    required this.canReopenTicket,
    required this.isReopening,
    required this.onReopen,
    required this.maintenanceClass,
    required this.canClassify,
    required this.isClassifying,
    required this.onClassify,
  });

  @override
  Widget build(BuildContext context) {
    final closedAt = ticket.endDate ?? ticket.updatedAt;
    final hoursSince = DateTime.now().difference(closedAt).inHours;
    final canReopen =
        canReopenTicket &&
        ticket.wasTechnicallyResolved &&
        ticket.isSynced &&
        hoursSince <= 4 &&
        !ticket.workflowDeferred;
    final agencyColor = _agencyColor(ticket.routedTo);
    final administrativeClosure = ticket.administrativeClosure;
    final innerCover = ticket.assetHierarchyReference?.innerCoverAssociation;
    final burnerReadings =
        ticket.burnerLockoutReadResult.value?.resolutionMicroampReadings.entries
            .toList() ??
        [];
    burnerReadings.sort((left, right) => left.key.compareTo(right.key));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BafRadius.large),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: agencyColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(BafSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: agencyColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                BafRadius.medium,
                              ),
                            ),
                            child: Icon(
                              _assetIcon(ticket.assetType),
                              color: agencyColor,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: BafSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_assetTypeLabel(ticket.assetType)} ${ticket.assetNumber}',
                                  style: const TextStyle(
                                    color: BafColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: BafSpacing.xs),
                                Text(
                                  ticket.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: BafColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'View full issue record',
                            onPressed: onViewDetails,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: BafSpacing.md),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusBadge(
                            label: _deptLabel(ticket.routedTo),
                            color: agencyColor,
                            icon: Icons.engineering_rounded,
                          ),
                          StatusBadge(
                            label:
                                administrativeClosure == null
                                    ? 'Resolved'
                                    : administrativeClosure.disposition.name ==
                                        'stillRelevant'
                                    ? 'Closed unresolved - retained'
                                    : 'Closed - relevance ended',
                            color:
                                administrativeClosure == null
                                    ? BafColors.sync
                                    : BafColors.warning,
                            icon:
                                administrativeClosure == null
                                    ? Icons.check_circle_rounded
                                    : Icons.inventory_2_outlined,
                          ),
                          StatusBadge(
                            label:
                                !ticket.isSynced
                                    ? 'Sync pending'
                                    : canReopen
                                    ? 'Reopen window'
                                    : 'Locked',
                            color:
                                !ticket.isSynced
                                    ? BafColors.warning
                                    : canReopen
                                    ? BafColors.maintenance
                                    : BafColors.admin,
                            icon:
                                !ticket.isSynced
                                    ? Icons.cloud_off_rounded
                                    : canReopen
                                    ? Icons.refresh_rounded
                                    : Icons.lock_clock_rounded,
                          ),
                          if (ticket.isWorkflowLinked)
                            StatusBadge(
                              label: ticket.workflowStateLabel,
                              color:
                                  ticket.workflowDeferred
                                      ? BafColors.warning
                                      : BafColors.audit,
                              icon:
                                  ticket.workflowDeferred
                                      ? Icons.pause_circle_outline_rounded
                                      : Icons.account_tree_outlined,
                            ),
                          if (maintenanceClass != null)
                            StatusBadge(
                              label: maintenanceClass!.title,
                              color: BafColors.success,
                              icon: Icons.event_repeat_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: BafSpacing.md),
                      _MetaLine(
                        icon: Icons.event_available_rounded,
                        text:
                            'Closed ${DateFormat('dd MMM yyyy, HH:mm').format(closedAt)}',
                      ),
                      const SizedBox(height: 5),
                      _MetaLine(
                        icon: Icons.person_outline_rounded,
                        text: 'By ${ticket.closedByName ?? 'Unknown'}',
                      ),
                      if (administrativeClosure != null) ...[
                        const SizedBox(height: 5),
                        _MetaLine(
                          icon: Icons.notes_rounded,
                          text: administrativeClosure.reason,
                        ),
                      ],
                      if (innerCover != null) ...[
                        const SizedBox(height: 5),
                        _MetaLine(
                          icon: Icons.layers_outlined,
                          text:
                              innerCover.innerCoverSerialNumber == null
                                  ? 'At event: no Inner Cover linked'
                                  : 'At event: Inner Cover ${innerCover.innerCoverSerialNumber}',
                        ),
                      ],
                      if (burnerReadings.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        _MetaLine(
                          icon: Icons.speed_rounded,
                          text:
                              'Flame signal: ${burnerReadings.map((entry) => 'B${entry.key} ${NumberFormat('0.###').format(entry.value)} µA').join(' · ')}',
                        ),
                      ],
                      _ClosedTicketRecordActions(
                        onViewDetails: onViewDetails,
                        canCorrect: canCorrect,
                        isCorrecting: isCorrecting,
                        onCorrect: onCorrect,
                      ),
                      const SizedBox(height: BafSpacing.sm),
                      if (canReopen)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isReopening ? null : onReopen,
                            style: FilledButton.styleFrom(
                              backgroundColor: BafColors.maintenance,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  BafRadius.medium,
                                ),
                              ),
                            ),
                            icon:
                                isReopening
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                    ),
                            label: Text(
                              isReopening ? 'Reopening…' : 'Reopen Ticket',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: BafColors.background,
                            borderRadius: BorderRadius.circular(
                              BafRadius.medium,
                            ),
                            border: Border.all(color: BafColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_clock_rounded,
                                size: 16,
                                color: BafColors.textSecondary,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  administrativeClosure == null
                                      ? 'Reopen unavailable after 4 hours'
                                      : 'Administrative closure is preserved as final evidence',
                                  style: const TextStyle(
                                    color: BafColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (canClassify) ...[
                        const SizedBox(height: BafSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isClassifying ? null : onClassify,
                            icon:
                                isClassifying
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.event_repeat_rounded),
                            label: Text(
                              isClassifying
                                  ? 'Recording class…'
                                  : maintenanceClass == null
                                  ? 'Classify completed maintenance'
                                  : 'Correct maintenance class',
                            ),
                          ),
                        ),
                      ],
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

  static String _assetTypeLabel(AssetType type) {
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

  static IconData _assetIcon(AssetType type) {
    switch (type) {
      case AssetType.base:
        return Icons.grid_view_rounded;
      case AssetType.furnace:
        return Icons.local_fire_department_rounded;
      case AssetType.forceCooler:
        return Icons.air_rounded;
      case AssetType.innerCover:
        return Icons.inventory_2_rounded;
      case AssetType.governedCustom:
        return Icons.precision_manufacturing_outlined;
    }
  }

  static Color _agencyColor(RoutedTo dept) {
    switch (dept) {
      case RoutedTo.operations:
        return BafColors.sync;
      case RoutedTo.electrical:
        return BafColors.warning;
      case RoutedTo.mechanical:
        return BafColors.planned;
      case RoutedTo.instrumentation:
        return BafColors.audit;
      case RoutedTo.refractory:
        return BafColors.directives;
      case RoutedTo.emd:
        return BafColors.assets;
      case RoutedTo.shiftInCharge:
        return BafColors.charges;
      case RoutedTo.others:
        return BafColors.admin;
    }
  }

  static String _deptLabel(RoutedTo dept) {
    switch (dept) {
      case RoutedTo.operations:
        return 'Operations';
      case RoutedTo.electrical:
        return 'Electrical';
      case RoutedTo.mechanical:
        return 'Mechanical';
      case RoutedTo.instrumentation:
        return 'I&A';
      case RoutedTo.refractory:
        return 'RED / Refractory';
      case RoutedTo.emd:
        return 'EMD';
      case RoutedTo.shiftInCharge:
        return 'Shift In-Charge';
      case RoutedTo.others:
        return 'Others';
    }
  }
}

class _LoadMoreFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const _LoadMoreFooter({
    required this.isLoading,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: BafSpacing.md),
        child: Center(
          child: StatusBadge(
            label: 'All closed tickets loaded',
            color: BafColors.sync,
            icon: Icons.check_circle_rounded,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BafSpacing.md),
      child: Center(
        child:
            isLoading
                ? const CircularProgressIndicator()
                : OutlinedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Load More'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BafColors.audit,
                    side: const BorderSide(color: BafColors.audit),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                  ),
                ),
      ),
    );
  }
}

class _ClosedTicketsEmptyState extends StatelessWidget {
  const _ClosedTicketsEmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(BafSpacing.xl),
      children: [
        const SizedBox(height: BafSpacing.xl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BafSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(color: BafColors.border),
            boxShadow: BafShadows.subtle,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: BafColors.sync.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: BafColors.sync,
                  size: 38,
                ),
              ),
              const SizedBox(height: BafSpacing.lg),
              const Text(
                'No closed tickets yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              const Text(
                'Resolved work and administrative closures will appear here for review.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
