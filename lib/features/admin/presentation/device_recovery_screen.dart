import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/user_directory_provider.dart';
import '../services/device_recovery_command_service.dart';
import '../services/device_recovery_listener.dart';

final registeredRecoveryDevicesProvider = FutureProvider.autoDispose
    .family<List<DeviceRecoveryInstallation>, String>((ref, targetUid) async {
      final actor = await ref.watch(currentAppUserProvider.future);
      return ref
          .watch(deviceRecoveryCommandServiceProvider)
          .listInstallations(actor: actor, targetUid: targetUid);
    });

class DeviceRecoveryScreen extends ConsumerWidget {
  const DeviceRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentAppUserProvider);
    return BafScreenScaffold(
      title: 'Device recovery',
      subtitle: 'Registered phones and protected local resets',
      icon: Icons.phonelink_erase_rounded,
      accent: BafColors.admin,
      actions: [
        IconButton(
          tooltip: 'Refresh approved users',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(allUsersProvider),
        ),
      ],
      body: actor.when(
        loading:
            () => const BafLoadingPanel(
              label: 'Checking administrator authority',
              color: BafColors.admin,
            ),
        error:
            (error, _) => BafStatePanel.error(
              title: 'Administrator authority unavailable',
              message: '$error',
            ),
        data: (currentUser) {
          if (currentUser == null ||
              !currentUser.isApproved ||
              !currentUser.isAdmin) {
            return BafStatePanel.empty(
              title: 'Administrator access required',
              message: 'Only an approved administrator may reset a phone.',
              icon: Icons.admin_panel_settings_outlined,
              color: BafColors.admin,
            );
          }
          return ref
              .watch(allUsersProvider)
              .when(
                loading:
                    () => const BafLoadingPanel(
                      label: 'Loading approved users',
                      color: BafColors.admin,
                    ),
                error:
                    (error, _) => BafStatePanel.error(
                      title: 'User directory unavailable',
                      message: '$error',
                      onPrimary: () => ref.invalidate(allUsersProvider),
                    ),
                data: (users) {
                  final approved =
                      users.where((user) => user.isApproved).toList()..sort(
                        (left, right) => left.name.toLowerCase().compareTo(
                          right.name.toLowerCase(),
                        ),
                      );
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      const _RecoverySafeguards(),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Icon(
                            Icons.devices_rounded,
                            color: BafColors.admin,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Approved users',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            '${approved.length}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: BafColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (approved.isEmpty)
                        BafStatePanel.empty(
                          title: 'No approved users',
                          message: 'There are no approved phones to recover.',
                          icon: Icons.person_search_rounded,
                          color: BafColors.admin,
                        )
                      else
                        ...approved.map(
                          (user) => _RecoveryUserPanel(
                            actor: currentUser,
                            user: user,
                          ),
                        ),
                    ],
                  );
                },
              );
        },
      ),
    );
  }
}

class _RecoverySafeguards extends StatelessWidget {
  const _RecoverySafeguards();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.08),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(BafRadius.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.security_rounded,
              size: 24,
              color: BafColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected phone only',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: BafColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Local records are backed up, removed and downloaded '
                    'again. Cloud records and the signed-in account remain '
                    'unchanged.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BafColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryUserPanel extends ConsumerStatefulWidget {
  const _RecoveryUserPanel({required this.actor, required this.user});

  final AppUser actor;
  final AppUser user;

  @override
  ConsumerState<_RecoveryUserPanel> createState() => _RecoveryUserPanelState();
}

class _RecoveryUserPanelState extends ConsumerState<_RecoveryUserPanel> {
  bool _expanded = false;
  String? _busyInstallation;

  @override
  Widget build(BuildContext context) {
    final devices =
        _expanded
            ? ref.watch(registeredRecoveryDevicesProvider(widget.user.uid))
            : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: BafColors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: BafColors.border),
          borderRadius: BorderRadius.circular(BafRadius.medium),
        ),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: BafColors.admin.withValues(alpha: 0.10),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: BafColors.admin,
                ),
              ),
              title: Text(
                widget.user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                widget.user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded)
              devices!.when(
                loading:
                    () => const Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                error:
                    (error, _) => Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$error',
                              style: const TextStyle(color: BafColors.danger),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Retry device inventory',
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                data:
                    (installations) =>
                        installations.isEmpty
                            ? const Padding(
                              padding: EdgeInsets.fromLTRB(18, 2, 18, 18),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'No registered phone',
                                  style: TextStyle(
                                    color: BafColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                            : Column(
                              children: installations
                                  .map(_buildInstallation)
                                  .toList(growable: false),
                            ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallation(DeviceRecoveryInstallation installation) {
    final pending = installation.recoveryStatus == 'pending';
    final inProgress = installation.recoveryStatus == 'in_progress';
    final busy = _busyInstallation == installation.installationId;
    final status = switch (installation.recoveryStatus) {
      'pending' => ('Reset pending', BafColors.warning),
      'in_progress' => ('Reset in progress', BafColors.info),
      'completed' => ('Last reset completed', BafColors.success),
      'failed' => ('Last reset refused', BafColors.danger),
      'cancelled' => ('Last reset cancelled', BafColors.textSecondary),
      _ => ('Available', BafColors.info),
    };
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BafColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            installation.platform == 'ios'
                ? Icons.phone_iphone_rounded
                : Icons.phone_android_rounded,
            size: 22,
            color: BafColors.admin,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${installation.platform.toUpperCase()} '
                  '${installation.shortIdentity}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  status.$1,
                  style: TextStyle(color: status.$2, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  'Registered ${_displayTimestamp(installation.updatedAt)}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (busy || inProgress)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: pending ? 'Cancel pending reset' : 'Reset this phone',
              icon: Icon(
                pending ? Icons.cancel_outlined : Icons.phonelink_erase_rounded,
                color: pending ? BafColors.warning : BafColors.danger,
              ),
              onPressed: () => _confirm(installation, cancel: pending),
            ),
        ],
      ),
    );
  }

  String _displayTimestamp(String raw) {
    final visible = raw.replaceFirst('T', ' ');
    return visible.length > 16 ? visible.substring(0, 16) : visible;
  }

  void _refresh() {
    ref.invalidate(registeredRecoveryDevicesProvider(widget.user.uid));
  }

  Future<void> _confirm(
    DeviceRecoveryInstallation installation, {
    required bool cancel,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder:
          (_) => _RecoveryConfirmationDialog(
            user: widget.user,
            installation: installation,
            cancel: cancel,
          ),
    );
    if (reason == null || !mounted) return;
    setState(() => _busyInstallation = installation.installationId);
    try {
      final commands = ref.read(deviceRecoveryCommandServiceProvider);
      if (cancel) {
        final requestId = installation.recoveryRequestId;
        if (requestId == null) {
          throw const DeviceRecoveryException(
            'The pending reset no longer has a valid request identity.',
          );
        }
        await commands.cancelReset(
          actor: widget.actor,
          requestId: requestId,
          targetUid: widget.user.uid,
          installationId: installation.installationId,
          reason: reason,
        );
      } else {
        await commands.requestReset(
          actor: widget.actor,
          targetUid: widget.user.uid,
          installationId: installation.installationId,
          reason: reason,
        );
        if (widget.actor.uid == widget.user.uid) {
          unawaited(
            ref
                .read(deviceRecoveryListenerProvider)
                .checkNow(
                  reason: 'admin_requested_own_device',
                  expectedInstallationId: installation.installationId,
                ),
          );
        }
      }
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cancel
                ? 'Pending phone reset cancelled.'
                : 'Protected reset requested for the selected phone.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busyInstallation = null);
    }
  }
}

class _RecoveryConfirmationDialog extends StatefulWidget {
  const _RecoveryConfirmationDialog({
    required this.user,
    required this.installation,
    required this.cancel,
  });

  final AppUser user;
  final DeviceRecoveryInstallation installation;
  final bool cancel;

  @override
  State<_RecoveryConfirmationDialog> createState() =>
      _RecoveryConfirmationDialogState();
}

class _RecoveryConfirmationDialogState
    extends State<_RecoveryConfirmationDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _confirmation = TextEditingController();

  String get _requiredConfirmation =>
      '${widget.cancel ? 'CANCEL' : 'RESET'} '
      '${widget.installation.shortIdentity}';

  @override
  void dispose() {
    _reason.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        widget.cancel ? Icons.cancel_outlined : Icons.phonelink_erase_rounded,
        color: widget.cancel ? BafColors.warning : BafColors.danger,
      ),
      title: Text(
        widget.cancel ? 'Cancel phone reset' : 'Reset selected phone',
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.user.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.installation.platform.toUpperCase()} '
              '${widget.installation.shortIdentity}',
              style: const TextStyle(color: BafColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Audited reason'),
              validator:
                  (value) =>
                      (value?.trim().length ?? 0) < 12
                          ? 'Enter at least 12 characters.'
                          : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmation,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Type $_requiredConfirmation',
              ),
              validator:
                  (value) =>
                      value?.trim() != _requiredConfirmation
                          ? 'Enter the exact selected-phone confirmation.'
                          : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor:
                widget.cancel ? BafColors.warning : BafColors.danger,
          ),
          onPressed: () {
            if (_form.currentState?.validate() != true) return;
            Navigator.of(context).pop(_reason.text.trim());
          },
          icon: Icon(
            widget.cancel ? Icons.close_rounded : Icons.phonelink_erase_rounded,
          ),
          label: Text(widget.cancel ? 'Cancel reset' : 'Request reset'),
        ),
      ],
    );
  }
}
