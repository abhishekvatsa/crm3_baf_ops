// FILE: lib/features/auth/presentation/pending_approval_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../providers/auth_provider.dart';

class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  bool _isRefreshingProfile = false;
  bool _isSigningOut = false;
  String? _refreshError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BafSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(BafSpacing.xl),
                decoration: BoxDecoration(
                  color: BafColors.card,
                  borderRadius: BorderRadius.circular(BafRadius.xLarge),
                  border: Border.all(color: BafColors.border),
                  boxShadow: BafShadows.subtle,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BafBrandLockup(compact: true),
                    const SizedBox(height: BafSpacing.xl),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: BafColors.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(BafRadius.xLarge),
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        size: 44,
                        color: BafColors.warning,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    const Text(
                      'Awaiting Approval',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    const Text(
                      'Your account has been created and is pending admin approval. You will get access as soon as an admin approves your profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    if (_refreshError != null) ...[
                      const SizedBox(height: BafSpacing.lg),
                      _PendingErrorCard(message: _refreshError!),
                    ],
                    const SizedBox(height: BafSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              _isRefreshingProfile ? null : _refreshProfile,
                          icon:
                              _isRefreshingProfile
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.refresh_rounded),
                          label: Text(
                            _isRefreshingProfile ? 'Refreshing…' : 'Refresh',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BafColors.navySoft,
                            side: const BorderSide(color: BafColors.navySoft),
                            padding: const EdgeInsets.symmetric(
                              horizontal: BafSpacing.lg,
                              vertical: BafSpacing.md,
                            ),
                          ),
                        ),
                        const SizedBox(width: BafSpacing.md),
                        FilledButton.icon(
                          onPressed:
                              _isRefreshingProfile || _isSigningOut
                                  ? null
                                  : _signOut,
                          icon:
                              _isSigningOut
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.logout_rounded),
                          label: Text(
                            _isSigningOut ? 'Signing out…' : 'Sign Out',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: BafColors.navySoft,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: BafSpacing.lg,
                              vertical: BafSpacing.md,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isRefreshingProfile = true;
      _refreshError = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.ensureUserDocument();
      if (!mounted) return;
      ref.invalidate(currentAppUserProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshError = 'Could not refresh your approval status. $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshingProfile = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _refreshError = null;
    });
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (error) {
      if (!mounted) return;
      setState(() => _refreshError = '$error');
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }
}

class _PendingErrorCard extends StatelessWidget {
  final String message;

  const _PendingErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: BafColors.danger),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: BafColors.danger,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
