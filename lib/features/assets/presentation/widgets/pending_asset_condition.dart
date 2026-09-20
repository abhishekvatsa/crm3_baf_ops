import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../admin/presentation/saved_submission_review_screen.dart';
import '../../providers/asset_condition_submission_provider.dart';

class PendingAssetCondition extends ConsumerWidget {
  const PendingAssetCondition({super.key, required this.assetId});
  final String assetId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(assetConditionPendingProvider(assetId));
    return pending.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Text('Saved condition evidence needs review.'),
      data: (saved) => saved == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A saved condition change is awaiting confirmation. Its original request is retained.',
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(assetConditionSubmissionControllerProvider)
                          .check(saved.submissionId);
                      ref.invalidate(assetConditionPendingProvider(assetId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Original change confirmed. Current restrictions are shown separately.',
                            ),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$error')));
                      }
                    }
                  },
                  child: const Text('Check saved condition change'),
                ),
                if (saved.attemptCount > 0) ...[
                  const Text(
                    'If checking keeps being refused, ask an administrator to review the original request before making another change.',
                  ),
                  if (ref
                          .watch(currentAppUserProvider)
                          .asData
                          ?.value
                          ?.isAdmin ==
                      true)
                    TextButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SavedSubmissionReviewScreen(),
                          ),
                        );
                        if (context.mounted) {
                          ref.invalidate(
                            assetConditionPendingProvider(assetId),
                          );
                        }
                      },
                      child: const Text('Review saved condition request'),
                    ),
                ],
              ],
            ),
    );
  }
}
