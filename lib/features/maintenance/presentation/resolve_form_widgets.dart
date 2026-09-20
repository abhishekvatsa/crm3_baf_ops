part of 'resolve_form.dart';

class _ResolveBottomBar extends StatelessWidget {
  final bool attendanceOnly;
  final bool isSubmitting;
  final String? actingAsName;
  final VoidCallback? onSubmit;

  const _ResolveBottomBar({
    required this.attendanceOnly,
    required this.isSubmitting,
    required this.actingAsName,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final actor = actingAsName?.trim();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          BafSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: BafColors.card,
          border: Border(top: BorderSide(color: BafColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (actor != null && actor.isNotEmpty) ...[
              Text(
                'Acting as: $actor',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
            ],
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: BafColors.sync,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: BafColors.border,
                  disabledForegroundColor: BafColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                  ),
                ),
                icon:
                    isSubmitting
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.task_alt_rounded),
                label: Text(
                  isSubmitting ? 'Saving...' : attendanceOnly ? 'Save attendance — issue stays active' : 'Mark as Resolved',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
