// FILE: lib/features/admin/presentation/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/validation/user_input_validator.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../providers/user_directory_provider.dart';
import '../providers/user_authority_command_provider.dart';
import '../services/user_authority_command_service.dart';

// ─────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────

final _authorityMutationBusyProvider = StateProvider.autoDispose
    .family<bool, String>((ref, uid) => false);

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentAppUserProvider);

    return ColoredBox(
      color: BafColors.background,
      child: currentUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => _AdminUserStateCard(
              icon: Icons.error_outline_rounded,
              color: BafColors.danger,
              title: 'Could not verify admin access',
              message: '$e',
            ),
        data: (currentUser) {
          if (currentUser == null || !currentUser.canManageUsers) {
            return const _AdminUserStateCard(
              icon: Icons.lock_outline_rounded,
              color: BafColors.danger,
              title: 'Admin access required',
              message: 'Only approved admin users can manage user access.',
            );
          }

          final usersAsync = ref.watch(allUsersProvider);

          return usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (e, _) => _AdminUserStateCard(
                  icon: Icons.error_outline_rounded,
                  color: BafColors.danger,
                  title: 'Could not load users',
                  message: '$e',
                ),
            data: (users) {
              final sortedUsers = [...users]..sort((a, b) {
                final approvalCompare =
                    a.isApproved == b.isApproved ? 0 : (a.isApproved ? 1 : -1);
                if (approvalCompare != 0) return approvalCompare;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

              final pending = sortedUsers.where((u) => !u.isApproved).toList();
              final approved = sortedUsers.where((u) => u.isApproved).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  _UserManagementHeader(
                    pendingCount: pending.length,
                    approvedCount: approved.length,
                  ),
                  const SizedBox(height: 18),

                  if (pending.isNotEmpty) ...[
                    const _SectionHeader(
                      title: 'Pending approval',
                      subtitle: 'Review and approve new users',
                      color: BafColors.warning,
                      icon: Icons.pending_actions_rounded,
                    ),
                    const SizedBox(height: 10),
                    ...pending.map(
                      (user) => _UserCard(user: user, isPending: true),
                    ),
                    const SizedBox(height: 18),
                  ],

                  const _SectionHeader(
                    title: 'Approved users',
                    subtitle: 'Manage access roles for existing users',
                    color: BafColors.sync,
                    icon: Icons.verified_user_rounded,
                  ),
                  const SizedBox(height: 10),

                  if (approved.isEmpty)
                    const _AdminUserStateCard(
                      icon: Icons.people_outline_rounded,
                      color: BafColors.admin,
                      title: 'No approved users',
                      message: 'Approved users will appear here.',
                    )
                  else
                    ...approved.map(
                      (user) => _UserCard(user: user, isPending: false),
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

// ─────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────

class _UserManagementHeader extends StatelessWidget {
  final int pendingCount;
  final int approvedCount;

  const _UserManagementHeader({
    required this.pendingCount,
    required this.approvedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: BafColors.admin.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: BafColors.admin,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Management',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Approve users and assign operational roles safely.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: '$pendingCount pending',
                      color:
                          pendingCount > 0
                              ? BafColors.warning
                              : BafColors.admin,
                      icon: Icons.pending_rounded,
                    ),
                    StatusBadge(
                      label: '$approvedCount approved',
                      color: BafColors.sync,
                      icon: Icons.verified_rounded,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 17,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
// User Card
// ─────────────────────────────────────────────────────────────

class _UserCard extends ConsumerWidget {
  final AppUser user;
  final bool isPending;

  const _UserCard({required this.user, required this.isPending});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMutating = ref.watch(_authorityMutationBusyProvider(user.uid));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _UserAvatar(user: user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isPending)
                FilledButton(
                  onPressed:
                      isMutating
                          ? null
                          : () => _approveUser(context, ref, user),
                  style: FilledButton.styleFrom(
                    backgroundColor: BafColors.sync,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BafRadius.small),
                    ),
                  ),
                  child: const Text(
                    'APPROVE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                )
              else
                IconButton(
                  onPressed:
                      isMutating ? null : () => _revokeUser(context, ref, user),
                  tooltip: 'Revoke access',
                  icon: const Icon(Icons.person_off_rounded),
                  color: BafColors.danger,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...user.roles.map(
                (role) => StatusBadge(
                  label: _roleLabel(role),
                  color: _roleColor(role),
                ),
              ),
              ActionChip(
                label: const Text(
                  '+ Role',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
                avatar: const Icon(Icons.edit_rounded, size: 16),
                onPressed:
                    isMutating
                        ? null
                        : () => _showRoleDialog(context, ref, user),
                backgroundColor: BafColors.background,
                side: const BorderSide(color: BafColors.border),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveUser(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    if (_currentAdmin(ref) == null) {
      _showAccessDeniedSnackBar(context);
      return;
    }

    final approvalValidation = UserInputValidator.validateApprovalTarget(user);
    if (approvalValidation.isInvalid) {
      _showValidationSnackBar(context, approvalValidation.summary);
      return;
    }

    final reason = await _requestMutationReason(
      context,
      title: 'Approve ${user.name}',
      actionLabel: 'APPROVE',
    );
    if (reason == null || !context.mounted) return;

    _setMutationBusy(context, ref, user.uid, true);
    try {
      await ref
          .read(userAuthorityCommandServiceProvider)
          .approve(user, reason: reason);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} approved'),
          backgroundColor: BafColors.sync,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showMutationError(context, user.name, e);
    } finally {
      _setMutationBusy(context, ref, user.uid, false);
    }
  }

  Future<void> _revokeUser(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    if (_currentAdmin(ref) == null) {
      _showAccessDeniedSnackBar(context);
      return;
    }
    final reason = await _requestMutationReason(
      context,
      title: 'Revoke ${user.name}',
      actionLabel: 'REVOKE',
    );
    if (reason == null || !context.mounted) return;

    _setMutationBusy(context, ref, user.uid, true);
    try {
      await ref
          .read(userAuthorityCommandServiceProvider)
          .revoke(user, reason: reason);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} access revoked'),
          backgroundColor: BafColors.warning,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showMutationError(context, user.name, e);
    } finally {
      _setMutationBusy(context, ref, user.uid, false);
    }
  }

  Future<void> _showRoleDialog(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    if (!_canManageUsers(ref)) {
      _showAccessDeniedSnackBar(context);
      return;
    }

    final input = await showDialog<_RoleAssignmentInput>(
      context: context,
      builder: (_) => _RoleAssignmentDialog(user: user),
    );
    if (input == null || !context.mounted) return;

    final currentUser = _currentAdmin(ref);
    if (currentUser == null) {
      _showAccessDeniedSnackBar(context);
      return;
    }
    final validation = UserInputValidator.validateRoleAssignment(
      currentUser: currentUser,
      targetUser: user,
      selectedRoles: input.roles,
    );
    if (validation.isInvalid) {
      _showValidationSnackBar(context, validation.summary);
      return;
    }

    _setMutationBusy(context, ref, user.uid, true);
    try {
      await ref
          .read(userAuthorityCommandServiceProvider)
          .replaceRoles(user, roles: input.roles, reason: input.reason);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated roles for ${user.name}'),
          backgroundColor: BafColors.sync,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        _showMutationError(context, user.name, error);
      }
    } finally {
      if (context.mounted) {
        _setMutationBusy(context, ref, user.uid, false);
      }
    }
  }

  AppUser? _currentAdmin(WidgetRef ref) {
    final currentUser = ref.read(currentAppUserProvider).value;
    if (currentUser == null || !currentUser.canManageUsers) return null;
    return currentUser;
  }

  bool _canManageUsers(WidgetRef ref) {
    return _currentAdmin(ref) != null;
  }

  void _setMutationBusy(
    BuildContext context,
    WidgetRef ref,
    String uid,
    bool value,
  ) {
    if (!context.mounted) return;
    ref.read(_authorityMutationBusyProvider(uid).notifier).state = value;
  }

  Future<String?> _requestMutationReason(
    BuildContext context, {
    required String title,
    required String actionLabel,
  }) async {
    return showDialog<String>(
      context: context,
      builder:
          (_) => _AuthorityReasonDialog(title: title, actionLabel: actionLabel),
    );
  }

  void _showMutationError(
    BuildContext context,
    String targetName,
    Object error,
  ) {
    if (!context.mounted) return;
    final message =
        error is UserAuthorityMutationException
            ? switch (error.reasonCode) {
              'last-approved-admin-required' =>
                'At least one approved Admin must remain.',
              'authority-preimage-mismatch' =>
                'Authority for $targetName changed. Review the latest record and try again.',
              'approved-admin-required' =>
                'Your approved Admin authority changed. Re-open User Management.',
              _ => error.message,
            }
            : 'Could not update $targetName: $error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: BafColors.danger),
    );
  }

  void _showAccessDeniedSnackBar(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Admin access required'),
        backgroundColor: BafColors.danger,
      ),
    );
  }

  void _showValidationSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: BafColors.warning),
    );
  }

  String _roleLabel(AppRole role) {
    return _authorityRoleLabel(role);
  }

  Color _roleColor(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return BafColors.admin;
      case AppRole.si:
        return BafColors.navySoft;
      case AppRole.contractSupervisor:
        return BafColors.charges;
      case AppRole.shiftSupervisor:
        return BafColors.assets;
      case AppRole.seniorElectrical:
        return BafColors.warning;
      case AppRole.seniorMechanical:
        return BafColors.planned;
      case AppRole.seniorInstrumentation:
        return BafColors.audit;
      case AppRole.seniorRefractory:
      case AppRole.refractory:
        return BafColors.directives;
      case AppRole.operations:
        return BafColors.sync;
    }
  }
}

class _RoleAssignmentInput {
  final List<AppRole> roles;
  final String reason;

  const _RoleAssignmentInput({required this.roles, required this.reason});
}

class _RoleAssignmentDialog extends StatefulWidget {
  final AppUser user;

  const _RoleAssignmentDialog({required this.user});

  @override
  State<_RoleAssignmentDialog> createState() => _RoleAssignmentDialogState();
}

class _RoleAssignmentDialogState extends State<_RoleAssignmentDialog> {
  late final TextEditingController _reasonController;
  late final Set<AppRole> _selectedRoles;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _selectedRoles = Set<AppRole>.from(widget.user.roles);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Roles — ${widget.user.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...AppRole.values.map((role) {
              return CheckboxListTile(
                title: Text(_authorityRoleLabel(role)),
                subtitle: Text(role.name),
                value: _selectedRoles.contains(role),
                onChanged: (checked) {
                  setState(() {
                    _validationMessage = null;
                    if (checked == true) {
                      _selectedRoles.add(role);
                    } else {
                      _selectedRoles.remove(role);
                    }
                  });
                },
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Reason',
                errorText: _validationMessage,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.navySoft,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('SAVE'),
        ),
      ],
    );
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (_selectedRoles.isEmpty || reason.length < 8) {
      setState(() {
        _validationMessage =
            _selectedRoles.isEmpty
                ? 'Select at least one role.'
                : 'Enter a reason of at least 8 characters.';
      });
      return;
    }
    Navigator.pop(
      context,
      _RoleAssignmentInput(
        roles: normalizeAuthorityRoles(_selectedRoles),
        reason: reason,
      ),
    );
  }
}

class _AuthorityReasonDialog extends StatefulWidget {
  final String title;
  final String actionLabel;

  const _AuthorityReasonDialog({
    required this.title,
    required this.actionLabel,
  });

  @override
  State<_AuthorityReasonDialog> createState() => _AuthorityReasonDialogState();
}

class _AuthorityReasonDialogState extends State<_AuthorityReasonDialog> {
  late final TextEditingController _controller;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: 500,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: 'Reason',
          errorText: _validationMessage,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < 8) {
      setState(() {
        _validationMessage = 'Enter a reason of at least 8 characters.';
      });
      return;
    }
    Navigator.pop(context, reason);
  }
}

String _authorityRoleLabel(AppRole role) {
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

class _UserAvatar extends StatelessWidget {
  final AppUser user;

  const _UserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user.photoUrl != null && user.photoUrl!.trim().isNotEmpty;
    final fallback =
        user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : 'U';

    return CircleAvatar(
      radius: 21,
      backgroundColor: BafColors.navySoft.withValues(alpha: 0.10),
      backgroundImage: hasPhoto ? NetworkImage(user.photoUrl!) : null,
      child:
          hasPhoto
              ? null
              : Text(
                fallback,
                style: const TextStyle(
                  color: BafColors.navySoft,
                  fontWeight: FontWeight.w900,
                ),
              ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// State Card
// ─────────────────────────────────────────────────────────────

class _AdminUserStateCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _AdminUserStateCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(color: BafColors.border),
            boxShadow: BafShadows.subtle,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
