import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_model.dart';
import '../providers/auth_provider.dart';

final accessSessionBackgroundedProvider = StateProvider<bool>((ref) => false);
final onlineAccessReaderProvider = Provider<Future<AppUser?> Function(String)>((
  ref,
) {
  return (uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    if (doc.metadata.isFromCache || doc.metadata.hasPendingWrites) {
      throw StateError('Current access could not be verified.');
    }
    return doc.data() == null
        ? null
        : AppUser.fromFirestore(
            doc.data()!,
            uid,
            fromCache: false,
            observedAt: DateTime.now().toUtc(),
          );
  };
});
final onlineAccessCheckProvider = FutureProvider<AppUser?>((ref) async {
  final profile = ref.watch(currentAppUserProvider).value;
  if (profile == null) return null;
  final checked = await ref.watch(onlineAccessReaderProvider)(profile.uid);
  return checked;
});

bool onlineAccessMatches(AppUser? observed, AppUser? checked) {
  if (observed == null ||
      checked == null ||
      !observed.isApproved ||
      !checked.isApproved ||
      !checked.hasServerAuthorityObservation ||
      observed.uid != checked.uid ||
      observed.authorityRevision != checked.authorityRevision) {
    return false;
  }
  final left = observed.roles.map((role) => role.name).toSet();
  final right = checked.roles.map((role) => role.name).toSet();
  return left.length == right.length && left.containsAll(right);
}

/// Keeps existing editors mounted but concealed and inert while access is checked.
/// No cached record or draft is deleted when online confirmation is unavailable.
class OnlineAccessGate extends ConsumerWidget {
  const OnlineAccessGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentAppUserProvider).value;
    if (actor == null || !actor.isApproved) return child;
    final check = ref.watch(onlineAccessCheckProvider);
    final backgrounded = ref.watch(accessSessionBackgroundedProvider);
    final allowed =
        !backgrounded &&
        !check.isLoading &&
        !check.hasError &&
        onlineAccessMatches(actor, check.value);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !allowed,
          child: TickerMode(
            enabled: allowed,
            child: ExcludeFocus(excluding: !allowed, child: child),
          ),
        ),
        if (!allowed)
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 42),
                      const SizedBox(height: 16),
                      const Text(
                        'Online access check required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        check.isLoading
                            ? 'Checking current account access...'
                            : 'Connect to the internet and check again. Saved work remains on this device. An Admin can restore withdrawn access after review.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (check.isLoading)
                        const CircularProgressIndicator()
                      else
                        FilledButton(
                          onPressed: () =>
                              ref.invalidate(onlineAccessCheckProvider),
                          child: const Text('Check access again'),
                        ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(authServiceProvider).signOut();
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(content: Text('$error')),
                              );
                            }
                          }
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
