// FILE: lib/features/directives/presentation/directives_screen.dart

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/operational_directive_model.dart';
import '../providers/operational_directive_provider.dart';
import '../../auth/data/user_model.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import 'create_directive_screen.dart';
import '../../auth/providers/auth_provider.dart';

class DirectivesScreen extends ConsumerStatefulWidget {
  const DirectivesScreen({super.key});

  @override
  ConsumerState<DirectivesScreen> createState() => _DirectivesScreenState();
}

class _DirectivesScreenState extends ConsumerState<DirectivesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final directivesAsync = ref.watch(openDirectivesProvider);
    final appUser = ref.watch(currentAppUserProvider).value;
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;
    final fabBottomGap = BafSpacing.lg + bottomSafeInset;
    final listBottomPadding = 56 + fabBottomGap + BafSpacing.xl;

    return Stack(
      children: [
        ColoredBox(
          color: BafColors.background,
          child: directivesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(message: 'Error: $e'),
            data: (allDirectives) {
              final visible = _visibleDirectives(allDirectives, appUser);
              final directives = _filterDirectives(visible, _query);

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      BafSpacing.lg,
                      BafSpacing.lg,
                      BafSpacing.lg,
                      listBottomPadding,
                    ),
                    children: [
                      _DirectivesHeader(
                        count: directives.length,
                        totalCount: visible.length,
                        query: _query,
                        onQueryChanged:
                            (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: BafSpacing.md),
                      if (directives.isEmpty)
                        _EmptyDirectivesState(
                          hasSearch: _query.trim().isNotEmpty,
                        )
                      else
                        ...directives.map(
                          (directive) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: BafSpacing.md,
                            ),
                            child: _DirectiveCard(
                              directive: directive,
                              appUser: appUser,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (appUser?.canCreateDirective == true)
          Positioned(
            bottom: fabBottomGap,
            right: BafSpacing.lg,
            child: FloatingActionButton.extended(
              heroTag: 'directives_fab',
              backgroundColor: BafColors.directives,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Directive',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateDirectiveScreen(),
                  ),
                );
              },
            ),
          ),
      ],
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
    if (needle.isEmpty) return directives;
    return directives
        .where((directive) {
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
  }
}

class _DirectivesHeader extends StatelessWidget {
  final int count;
  final int totalCount;
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _DirectivesHeader({
    required this.count,
    required this.totalCount,
    required this.query,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Directives',
                    style: TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Clear operational instructions, ownership and closure tracking.',
                    style: TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: BafSpacing.sm),
            StatusBadge(
              label: '$count active',
              color: BafColors.directives,
              icon: Icons.flag_outlined,
            ),
          ],
        ),
        const SizedBox(height: BafSpacing.md),
        TextField(
          key: const ValueKey('directives-search'),
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Search title, asset or target role',
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
        ),
        const SizedBox(height: BafSpacing.xs),
        Text(
          query.trim().isEmpty
              ? '$totalCount visible to your role'
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

  const _EmptyDirectivesState({required this.hasSearch});

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
                ? 'No active directive matches this search.'
                : 'All clear - no pending instructions for your role.',
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

  const _DirectiveCard({required this.directive, required this.appUser});

  @override
  ConsumerState<_DirectiveCard> createState() => _DirectiveCardState();
}

class _DirectiveCardState extends ConsumerState<_DirectiveCard> {
  Timer? _timer;
  bool _isAcknowledging = false;
  bool _isClosing = false;

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
                          fontSize: 13,
                          height: 1.35,
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
                          if (!isClosed)
                            StatusBadge(
                              label: 'Open ${_formatDuration(elapsed)}',
                              color: BafColors.warning,
                              icon: Icons.timer_outlined,
                            ),
                        ],
                      ),

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
                                onPressed:
                                    _isAcknowledging
                                        ? null
                                        : () =>
                                            _acknowledgeDirective(directive),
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
                                icon:
                                    _isAcknowledging
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
                                onPressed:
                                    _isClosing
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
                                icon:
                                    _isClosing
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.check_circle_rounded,
                                        ),
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

      await repo.acknowledgeDirective(id, actor: appUser);

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'directive_acknowledged',
          force: true,
        ),
      );

      if (!mounted) return;

      _showDirectiveSnack('Directive acknowledged', BafColors.sync);
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

    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => const _CloseDirectiveDialog(),
    );

    if (!mounted || remarks == null) {
      return;
    }
    if (_isClosing) {
      return;
    }
    setState(() => _isClosing = true);

    try {
      final closureRemarks = remarks.trim().isEmpty ? null : remarks.trim();

      final repo = ref.read(directiveRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final id = kIsWeb ? directive.firestoreId : directive.id;

      if (id == null) {
        throw Exception('Directive is missing its sync identifier.');
      }

      await repo.closeDirective(
        id,
        actor: appUser,
        remarks: closureRemarks,
        wasUnacknowledged: directive.status != DirectiveStatus.acknowledged,
      );

      unawaited(
        syncCoordinator.runFullSync(reason: 'directive_closed', force: true),
      );

      if (!mounted) return;

      _showDirectiveSnack('Directive closed', BafColors.sync);
    } catch (e) {
      if (!mounted) return;

      _showDirectiveSnack('Failed to close directive: $e', BafColors.danger);
    } finally {
      if (mounted) {
        setState(() => _isClosing = false);
      }
    }
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
    }
  }
}

class _CloseDirectiveDialog extends StatefulWidget {
  const _CloseDirectiveDialog();

  @override
  State<_CloseDirectiveDialog> createState() => _CloseDirectiveDialogState();
}

class _CloseDirectiveDialogState extends State<_CloseDirectiveDialog> {
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
      title: const Text('Close Directive'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add a short closure note if useful for traceability.',
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarksController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: 'Remarks (optional)',
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
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.sync,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, _remarksController.text),
          child: const Text('Close'),
        ),
      ],
    );
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        StatusBadge(label: status.name.toUpperCase(), color: statusColor),
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
      children: [
        Icon(icon, size: 15, color: BafColors.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.25,
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
