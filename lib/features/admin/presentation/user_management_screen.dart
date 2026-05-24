// FILE: lib/features/admin/presentation/user_management_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/validation/user_input_validator.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/providers/audit_provider.dart';

// ─────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => AppUser.fromFirestore(doc.data(), doc.id))
                .toList(),
      );
});

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
              borderRadius: BorderRadius.circular(16),
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
                  onPressed: () => _approveUser(context, ref, user),
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
                onPressed: () => _showRoleDialog(context, ref, user),
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
    final currentUser = _currentAdmin(ref);
    if (currentUser == null) {
      _showAccessDeniedSnackBar(context);
      return;
    }

    final approvalValidation = UserInputValidator.validateApprovalTarget(user);
    if (approvalValidation.isInvalid) {
      _showValidationSnackBar(context, approvalValidation.summary);
      return;
    }

    final before = _userAuditMap(user);
    final after = <String, dynamic>{...before, 'isApproved': true};

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'isApproved': true},
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not approve ${user.name}: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    try {
      await _logUserAudit(
        ref: ref,
        action: AuditAction.update,
        currentUser: currentUser,
        targetUser: user,
        before: before,
        after: after,
        summary: 'Approved user ${user.name}',
        reasonNotes: 'Admin approved user access.',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to audit user approval for ${user.uid}: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User approved, but audit log could not be saved.'),
            backgroundColor: BafColors.warning,
          ),
        );
      }
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name} approved'),
        backgroundColor: BafColors.sync,
      ),
    );
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

    final selectedRoles = Set<AppRole>.from(user.roles);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Roles — ${user.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      AppRole.values.map((role) {
                        return CheckboxListTile(
                          title: Text(_roleLabel(role)),
                          subtitle: Text(role.name),
                          value: selectedRoles.contains(role),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedRoles.add(role);
                              } else {
                                selectedRoles.remove(role);
                              }
                            });
                          },
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BafColors.navySoft,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final currentUser = _currentAdmin(ref);
                    if (currentUser == null) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      if (context.mounted) {
                        _showAccessDeniedSnackBar(context);
                      }
                      return;
                    }

                    if (selectedRoles.isEmpty) {
                      if (context.mounted) {
                        _showValidationSnackBar(
                          context,
                          'Select at least one role for ${user.name}.',
                        );
                      }
                      return;
                    }

                    final isSelf = currentUser.uid == user.uid;
                    if (isSelf &&
                        user.roles.contains(AppRole.admin) &&
                        !selectedRoles.contains(AppRole.admin)) {
                      if (context.mounted) {
                        _showValidationSnackBar(
                          context,
                          'You cannot remove your own Admin role.',
                        );
                      }
                      return;
                    }

                    final normalizedRoles =
                        selectedRoles.toList()
                          ..sort((a, b) => a.index.compareTo(b.index));

                    final lastApprovedAdminWouldBeRemoved =
                        user.roles.contains(AppRole.admin) &&
                        !normalizedRoles.contains(AppRole.admin) &&
                        await _isLastApprovedAdmin(user.uid);
                    if (lastApprovedAdminWouldBeRemoved) {
                      if (context.mounted) {
                        _showValidationSnackBar(
                          context,
                          'At least one approved Admin must remain.',
                        );
                      }
                      return;
                    }

                    final roleValidation =
                        UserInputValidator.validateRoleAssignment(
                          currentUser: currentUser,
                          targetUser: user,
                          selectedRoles: normalizedRoles,
                          lastApprovedAdminWouldBeRemoved:
                              lastApprovedAdminWouldBeRemoved,
                        );
                    if (roleValidation.isInvalid) {
                      if (context.mounted) {
                        _showValidationSnackBar(
                          context,
                          roleValidation.summary,
                        );
                      }
                      return;
                    }

                    final before = _userAuditMap(user);
                    final after = <String, dynamic>{
                      ...before,
                      'roles':
                          normalizedRoles.map((role) => role.name).toList(),
                    };

                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                            'roles':
                                normalizedRoles
                                    .map((role) => role.name)
                                    .toList(),
                          });
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not update ${user.name}: $e'),
                            backgroundColor: BafColors.danger,
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      await _logUserAudit(
                        ref: ref,
                        action: AuditAction.update,
                        currentUser: currentUser,
                        targetUser: user,
                        before: before,
                        after: after,
                        summary: 'Updated roles for ${user.name}',
                        reasonNotes: 'Admin updated user roles.',
                      );
                    } catch (e) {
                      debugPrint(
                        '⚠️ Failed to audit role update for ${user.uid}: $e',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Roles updated, but audit log could not be saved.',
                            ),
                            backgroundColor: BafColors.warning,
                          ),
                        );
                      }
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  AppUser? _currentAdmin(WidgetRef ref) {
    final currentUser = ref.read(currentAppUserProvider).value;
    if (currentUser == null || !currentUser.canManageUsers) return null;
    return currentUser;
  }

  bool _canManageUsers(WidgetRef ref) {
    return _currentAdmin(ref) != null;
  }

  Future<bool> _isLastApprovedAdmin(String targetUid) async {
    final snap =
        await FirebaseFirestore.instance
            .collection('users')
            .where('roles', arrayContains: AppRole.admin.name)
            .get();

    final adminIds =
        snap.docs
            .where((doc) => doc.data()['isApproved'] == true)
            .map((doc) => doc.id)
            .toSet();
    return adminIds.length == 1 && adminIds.contains(targetUid);
  }

  Map<String, dynamic> _userAuditMap(AppUser user) {
    return {
      'uid': user.uid,
      'name': user.name,
      'email': user.email,
      'roles': user.roles.map((role) => role.name).toList(),
      'isApproved': user.isApproved,
      'createdAt': user.createdAt.toIso8601String(),
    };
  }

  Future<void> _logUserAudit({
    required WidgetRef ref,
    required AuditAction action,
    required AppUser currentUser,
    required AppUser targetUser,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
    required String summary,
    required String reasonNotes,
  }) async {
    await ref
        .read(auditRepositoryProvider)
        .log(
          AuditEvent.fromContext(
            entityType: 'user',
            entityId: targetUser.uid,
            action: action,
            context: AuditContext(
              performedByUid: currentUser.uid,
              performedByName: currentUser.name,
              reason: AuditReason.manualOverride,
              reasonNotes: reasonNotes,
              before: before,
              after: after,
              summary: summary,
              severity: AuditSeverity.high,
            ),
          ),
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
