import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../../core/services/saved_submission_review_service.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';

final savedSubmissionReviewServiceProvider =
    Provider<SavedSubmissionReviewService>((ref) {
      return SavedSubmissionReviewService(
        store: ref.watch(durableSubmissionRepositoryProvider),
        requireReviewer: () {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          if (!access.isReady ||
              ref.read(firebaseAuthProvider).currentUser?.uid !=
                  access.actor?.uid) {
            throw const DurableSubmissionException(
              'review-account-unavailable',
              'Your approved account could not be verified. Saved work remains retained.',
            );
          }
          return access.actor!;
        },
        requireCapability: (callable, uid) async {
          await const CommandCapabilityService().requireCapabilities(
            callableName: callable,
            originActorUid: uid,
            requiredCapabilities: const {'savedSubmissionReview.v1'},
          );
        },
        invoke: (callable, data) async => (await FirebaseFunctions.instanceFor(
          region: 'asia-south1',
        ).httpsCallable(callable).call<Object?>(data)).data,
      );
    });

class SavedSubmissionReviewScreen extends ConsumerStatefulWidget {
  const SavedSubmissionReviewScreen({super.key});
  @override
  ConsumerState<SavedSubmissionReviewScreen> createState() =>
      _SavedSubmissionReviewScreenState();
}

class _SavedSubmissionReviewScreenState
    extends ConsumerState<SavedSubmissionReviewScreen> {
  Future<List<DurableSubmission>>? _rows;
  String? _loadedActor;
  bool _showHistory = false;
  bool _busy = false;
  String? _message;

  void _refresh() {
    setState(
      () => _rows = ref.read(savedSubmissionReviewServiceProvider).list(),
    );
  }

  Future<void> _review(DurableSubmission row) async {
    final reviewerUid = CurrentActorAccess.resolve(
      ref.read(currentAppUserProvider),
    ).actor?.uid;
    if (reviewerUid == null) return;
    final reason = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) => _guardDialog(
          context,
          ref,
          reviewerUid,
          () => AlertDialog(
            title: const Text('Review saved request'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Check the relevant business record first. Describe what you found and why this saved request should be closed.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    maxLines: 4,
                    maxLength: 1600,
                    decoration: const InputDecoration(
                      labelText: 'Review notes',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, reason.text),
                child: const Text('Check server'),
              ),
            ],
          ),
        ),
      ),
    );
    // Dialog dismissal still animates; its controller is disposed next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => reason.dispose());
    if (note == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = ref.read(savedSubmissionReviewServiceProvider);
      final inspection = await service.inspect(row, note);
      if (!mounted) return;
      if (inspection.alreadyResolved) {
        setState(
          () => _message =
              'The earlier review was already completed. Its original decision is now saved on this device.',
        );
        _refresh();
        return;
      }
      final present = inspection.response['observation'] == 'receiptPresent';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => Consumer(
          builder: (context, ref, _) => _guardDialog(
            context,
            ref,
            reviewerUid,
            () => AlertDialog(
              title: Text(
                present
                    ? 'An existing result was found'
                    : 'No receipt was found',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      present
                          ? 'Review the server result below against the saved work. Closing this hold records your review; it does not submit another business change.'
                          : 'A missing receipt does not prove that this work never happened: older receipts may have expired. Confirm that you checked the business records. Closing this request prevents any delayed copy with its original identity from executing.',
                    ),
                    if (present)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SelectableText(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(inspection.response['receiptSummary']),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'The original saved evidence and review decision will remain on this device.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep hold'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Record review and close hold'),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      await service.finalize(inspection);
      if (mounted) {
        setState(
          () =>
              _message = 'Review recorded. The original evidence is retained.',
        );
        _refresh();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is FirebaseFunctionsException
              ? error.message ??
                    'The review could not be confirmed. Keep the saved work and check again.'
              : '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    );
    final actor = access.actor;
    final ready =
        access.isReady &&
        actor != null &&
        actor.isAdmin &&
        ref.watch(firebaseAuthProvider).currentUser?.uid == actor.uid;
    if (!ready) {
      _rows = null;
      _loadedActor = null;
      return BafScreenStateScaffold.access(
        appBarTitle: 'Saved work review',
        appBarSubtitle: 'Retained requests and review history',
        appBarIcon: Icons.save_as_outlined,
        message: 'A currently approved administrator is required.',
      );
    }
    if (_loadedActor != actor.uid) {
      _loadedActor = actor.uid;
      _message = null;
      _rows = ref.read(savedSubmissionReviewServiceProvider).list();
    }
    return BafScreenScaffold(
      title: 'Saved work review',
      subtitle: 'Retained requests and review history',
      icon: Icons.save_as_outlined,
      actions: [
        IconButton(
          onPressed: _busy ? null : _refresh,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: FutureBuilder<List<DurableSubmission>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const BafLoadingPanel(label: 'Checking saved requests');
          }
          if (snapshot.hasError) {
            return BafStatePanel.error(
              title: 'Saved work needs attention',
              message: '${snapshot.error}',
              onPrimary: _refresh,
            );
          }
          final rows = (snapshot.data ?? [])
              .where((row) => _showHistory || row.state.isUnresolved)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Saved requests on this device. Check an accepted result from its original business page. An administrator can review older or uncertain requests here.',
              ),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include completed review history'),
                  value: _showHistory,
                  onChanged: (value) => setState(() => _showHistory = value),
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_message!),
                ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No saved requests need review.'),
                ),
              for (final row in rows)
                Card(
                  child: ExpansionTile(
                    title: Text(_title(row.resourceKey)),
                    subtitle: Text(
                      row.state == DurableSubmissionState.reviewResolved
                          ? 'Reviewed; evidence retained'
                          : row.state.isAccepted
                          ? 'Accepted; check the business page'
                          : row.lastErrorMessage ??
                                'Saved request awaiting confirmation',
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saved: ${row.createdAt.toLocal()}'),
                      Text(
                        'Original account: ${row.actorUid ?? 'Unknown in older evidence'}',
                      ),
                      ExpansionTile(
                        title: const Text('Original saved evidence'),
                        children: [
                          SelectableText(
                            row.isLegacy
                                ? utf8.decode(
                                    base64Decode(row.legacySourceBase64!),
                                    allowMalformed: true,
                                  )
                                : row.envelopeJson,
                          ),
                        ],
                      ),
                      if (row.receiptJson != null)
                        ExpansionTile(
                          title: const Text(
                            'Retained result and review evidence',
                          ),
                          children: [SelectableText(row.receiptJson!)],
                        ),
                      if (row.state.isUnresolved &&
                          !row.state.isAccepted &&
                          row.state != DurableSubmissionState.reviewConflict)
                        FilledButton(
                          onPressed: _busy ? null : () => _review(row),
                          child: const Text('Review this request'),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _title(String key) => switch (key.split(':').first) {
    'morningReview' => 'Morning Review',
    'burnerEvidence' || 'legacyBurner' => 'Burner / UV evidence',
    'innerCoverAcceptance' => 'Inner Cover acceptance',
    'qualityMonitoringCreation' => 'Quality monitoring',
    'publishedTemplateAssignment' => 'Published job assignment',
    'inspectionCampaignCreation' => 'Inspection programme',
    _ => 'Saved work',
  };
}

Widget _guardDialog(
  BuildContext context,
  WidgetRef ref,
  String uid,
  Widget Function() contents,
) {
  final access = CurrentActorAccess.resolve(ref.watch(currentAppUserProvider));
  if (!access.isReady ||
      access.actor?.uid != uid ||
      access.actor?.isAdmin != true ||
      ref.watch(firebaseAuthProvider).currentUser?.uid != uid) {
    return AlertDialog(
      title: const Text('Account verification changed'),
      content: const Text(
        'Return to the approved administrator account before reviewing saved work.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
  return contents();
}
