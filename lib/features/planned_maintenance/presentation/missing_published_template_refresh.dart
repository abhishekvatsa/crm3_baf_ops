import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/template_active_version_refresh_provider.dart';
import '../providers/template_governance_provider.dart';
import '../services/template_active_version_refresh.dart';

/// Explicit recovery for a known active pointer whose local version is absent.
/// Package, actor and version form this widget's identity in the parent.
class MissingPublishedTemplateRefresh extends ConsumerStatefulWidget {
  const MissingPublishedTemplateRefresh({
    super.key,
    required this.actorUid,
    required this.packageId,
    required this.versionId,
  });
  final String actorUid;
  final String packageId;
  final String versionId;
  @override
  ConsumerState<MissingPublishedTemplateRefresh> createState() =>
      _MissingPublishedTemplateRefreshState();
}

class _MissingPublishedTemplateRefreshState
    extends ConsumerState<MissingPublishedTemplateRefresh> {
  bool _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final access = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    );
    if (!access.isReady ||
        access.actor?.uid != widget.actorUid ||
        !access.actor!.canAssignJobExecution) {
      return const SizedBox.shrink();
    }
    final refresh = ref.watch(templateActiveVersionRefreshProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This package has a published version, but its saved copy is missing on this device. Assignment is paused.',
        ),
        const SizedBox(height: 8),
        if (refresh != null)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _refresh(refresh),
            icon: const Icon(Icons.refresh),
            label: Text(
              _busy
                  ? 'Checking published catalogue…'
                  : 'Refresh published catalogue',
            ),
          )
        else
          const Text(
            'Ask an administrator to review the missing published version.',
          ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, semanticsLabel: _message),
        ],
      ],
    );
  }

  Future<void> _refresh(TemplateActiveVersionRefresh refresh) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    String message;
    try {
      await refresh.refresh(
        packageId: widget.packageId,
        versionId: widget.versionId,
      );
      message = 'Published catalogue restored. Assignment checks will refresh.';
    } on TemplateActiveVersionRefreshException catch (error) {
      message = error.message;
    } catch (_) {
      message =
          'The server could not confirm the catalogue. Check your connection and retry, or ask an administrator. Saved work is retained.';
    }
    if (!mounted) return;
    final access = CurrentActorAccess.resolve(ref.read(currentAppUserProvider));
    if (!access.isReady || access.actor?.uid != widget.actorUid) return;
    setState(() {
      _busy = false;
      _message = message;
    });
    ref.invalidate(packageVersionsProvider(widget.packageId));
    ref.invalidate(
      templatePublicationReadinessProvider(
        TemplatePublicationReadinessQuery(
          packageFirestoreId: widget.packageId,
          versionFirestoreId: widget.versionId,
        ),
      ),
    );
  }
}
