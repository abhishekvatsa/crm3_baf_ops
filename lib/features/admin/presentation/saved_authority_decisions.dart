import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/persistence/durable_submission_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/user_authority_durable_command_provider.dart';

/// Available to the original account even after it loses its Admin role.
class SavedAuthorityDecisions extends ConsumerStatefulWidget {
  const SavedAuthorityDecisions({super.key});
  @override
  ConsumerState<SavedAuthorityDecisions> createState() =>
      _SavedAuthorityDecisionsState();
}

class _SavedAuthorityDecisionsState
    extends ConsumerState<SavedAuthorityDecisions> {
  List<DurableSubmission> rows = const [];
  String? message;
  bool busy = false;
  String? ownerUid;
  StreamSubscription<List<DurableSubmission>>? subscription;
  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    final uid = ref.read(currentAppUserProvider).value?.uid;
    try {
      final owner = ref.read(userAuthorityDurableCommandControllerProvider);
      if (uid != null && (ownerUid != uid || subscription == null)) {
        await subscription?.cancel();
        subscription = owner.store
            .watchForActor(uid)
            .listen(
              (values) {
                if (mounted &&
                    ref.read(currentAppUserProvider).value?.uid == uid) {
                  setState(() {
                    rows = values
                        .where((row) => row.protocol == 'userAuthority.v1')
                        .toList();
                    ownerUid = uid;
                  });
                }
              },
              onError: (Object error) {
                if (mounted) {
                  setState(() {
                    message = 'Saved decision evidence needs review: $error';
                  });
                }
              },
            );
      }
      final values = await owner.listForCurrentActor();
      if (mounted && ref.read(currentAppUserProvider).value?.uid == uid) {
        setState(() {
          rows = values;
          ownerUid = uid;
        });
      }
    } catch (error) {
      if (mounted && ref.read(currentAppUserProvider).value?.uid == uid) {
        setState(() {
          ownerUid = uid;
          message =
              'Saved access decisions could not be read. Nothing was discarded or sent: $error';
        });
      }
    }
  }

  Future<void> check(DurableSubmission row, {bool dispatch = false}) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await ref
          .read(userAuthorityDurableCommandControllerProvider)
          .check(row.submissionId, dispatch: dispatch);
      if (mounted &&
          ref.read(currentAppUserProvider).value?.uid == row.actorUid) {
        setState(() {
          message =
              'Original decision confirmed (${result.operation.wireName}). Current access may have changed; check the current directory separately.';
        });
      }
    } catch (error) {
      if (mounted &&
          ref.read(currentAppUserProvider).value?.uid == row.actorUid) {
        setState(() {
          message = '$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
        await load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(currentAppUserProvider).value;
    if (actor == null ||
        actor.uid != ownerUid ||
        (rows.isEmpty && message == null)) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved access decisions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Check the original outcome before creating another decision. Checking never grants access.',
            ),
            if (message != null) Text(message!),
            for (final row in rows)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => check(row),
                    child: Text('Check ${row.aggregateId}'),
                  ),
                  if (actor.canManageUsers)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text(
                                    'Retry the saved decision?',
                                  ),
                                  content: Text(
                                    'Account: ${row.aggregateId}. This sends the original reviewed decision. A changed account revision will be refused.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Retry original'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && mounted) {
                                await check(row, dispatch: true);
                              }
                            },
                      child: const Text('Retry original decision'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
