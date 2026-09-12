import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../data/user_model.dart';
import '../domain/current_actor_access.dart';
import '../providers/auth_provider.dart';

/// A draft belongs to the account that started it, even after a refresh.
String? currentActorActionMessage(
  CurrentActorAccess access, {
  String? originUid,
  bool Function(AppUser)? permission,
}) {
  if (!access.isReady) return access.message;
  final actor = access.actor!;
  if (originUid != null && actor.uid != originUid) {
    return 'Return to the account that started this form to continue. Your entries are retained.';
  }
  if (permission != null && !permission(actor)) {
    return 'Your account does not currently have permission for this action. Your entries are retained.';
  }
  return null;
}

class CurrentActorNotice extends StatelessWidget {
  const CurrentActorNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(BafSpacing.md),
    child: Text(message, style: const TextStyle(color: BafColors.warning)),
  );
}

/// Keeps the real dialog mounted while its authority is temporarily unavailable.
/// This owns its provider subscription independently of the launching screen.
class CurrentActorDialogGuard extends ConsumerWidget {
  const CurrentActorDialogGuard({
    super.key,
    required this.originUid,
    required this.permission,
    required this.child,
  });

  final String originUid;
  final bool Function(AppUser) permission;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = currentActorActionMessage(
      CurrentActorAccess.resolve(ref.watch(currentAppUserProvider)),
      originUid: originUid,
      permission: permission,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeFocus(
          excluding: message != null,
          child: Offstage(offstage: message != null, child: child),
        ),
        if (message != null)
          AlertDialog(
            title: const Text('Account verification required'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close form'),
              ),
            ],
          ),
      ],
    );
  }
}
