import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/persistence/durable_submission_repository.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/burner_block_lifecycle_event.dart';
import '../../providers/burner_block_correction_provider.dart';
import '../../repositories/burner_block_correction_repository.dart';

/// Opens both correction history and the original-account recovery route.
/// No new identity is generated while a saved request owns this installation.
class BurnerBlockCorrectionControls extends StatelessWidget {
  const BurnerBlockCorrectionControls({
    super.key,
    required this.event,
    required this.currentEventId,
  });
  final BurnerBlockLifecycleEvent event;
  final String? currentEventId;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Review installation correction',
    icon: const Icon(Icons.edit_calendar_outlined),
    onPressed: () => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CorrectionDialog(event: event),
    ),
  );
}

class _CorrectionDialog extends ConsumerStatefulWidget {
  const _CorrectionDialog({required this.event});
  final BurnerBlockLifecycleEvent event;
  @override
  ConsumerState<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends ConsumerState<_CorrectionDialog> {
  final _reason = TextEditingController();
  BurnerBlockCorrectionReview? _review;
  DurableSubmission? _pending;
  DateTime? _effectiveAt;
  String? _error;
  String? _originUid;
  bool _busy = true;
  final _date = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _requireOrigin() {
    final actor = ref.read(currentAppUserProvider);
    if (actor.isLoading ||
        actor.hasError ||
        actor.valueOrNull?.canAdjudicateFurnaceStuckup != true ||
        actor.valueOrNull?.uid != _originUid) {
      throw StateError(
        'Return to the approved account that opened this correction.',
      );
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _originUid ??= ref.read(currentAppUserProvider).valueOrNull?.uid;
      _requireOrigin();
      final service = ref.read(burnerBlockCorrectionCommandServiceProvider);
      final pending = await service.pendingForEvent(widget.event.eventId);
      if (!mounted) return;
      _requireOrigin();
      if (pending != null) {
        setState(() {
          _pending = pending;
          _review = null;
        });
      } else {
        final review = await ref
            .read(burnerBlockCorrectionRepositoryProvider)
            .review(widget.event.eventId);
        if (!mounted) return;
        _requireOrigin();
        setState(() {
          _pending = null;
          _review = review;
          _effectiveAt ??= review.effectiveAt;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _chooseDate() async {
    final current = (_effectiveAt ?? widget.event.actionPerformedAt).toLocal();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      _effectiveAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      ).toUtc();
    });
  }

  Future<void> _submit() async {
    final review = _review;
    if (_pending == null && (review == null || _effectiveAt == null)) return;
    if (_pending == null &&
        (_reason.text.trim().isEmpty ||
            _effectiveAt == review!.effectiveAt ||
            _effectiveAt!.isAfter(DateTime.now()))) {
      setState(() {
        _error =
            'Choose a changed installation time that has already occurred and explain the correction.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _requireOrigin();
      final service = ref.read(burnerBlockCorrectionCommandServiceProvider);
      if (_pending != null) {
        await service.resume(_pending!.submissionId);
      } else {
        await service.correct(
          correctionId: const Uuid().v4(),
          eventId: widget.event.eventId,
          expectedCurrentEventId: review!.current.eventId,
          correctedActionPerformedAt: _effectiveAt!.toUtc().toIso8601String(),
          reason: _reason.text.trim(),
          supersedesCorrectionId: review.effectiveCorrection?.id,
        );
      }
      if (!mounted) return;
      _requireOrigin();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Installation correction confirmed. The original record is preserved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      // Refresh the immutable pending owner after an uncertain result. Retain
      // the operator's date and explanation for a definitive refusal.
      await _load();
      if (mounted) {
        setState(() {
          _error = message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(currentAppUserProvider);
    final sameActor =
        !actor.isLoading &&
        !actor.hasError &&
        actor.valueOrNull?.uid == _originUid &&
        actor.valueOrNull?.canAdjudicateFurnaceStuckup == true;
    final review = _review;
    final pending = _pending;
    return AlertDialog(
      title: Text(
        'Burner B${widget.event.burnerPosition} installation correction',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!sameActor)
                const Text(
                  'An approved original account is required. Close this window and return to that account.',
                ),
              if (_busy) const LinearProgressIndicator(),
              if (sameActor) ...[
                Text(
                  'Originally recorded installation: ${_date.format(widget.event.actionPerformedAt.toLocal())}',
                ),
                const Text(
                  'A correction changes the effective installation time. It does not record another replacement.',
                ),
                if (pending != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'A saved correction still needs confirmation. Check the original request before making another correction.',
                  ),
                  Text('Saved ${_date.format(pending.createdAt.toLocal())}'),
                ] else if (review != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Effective installation: ${_date.format(review.effectiveAt.toLocal())}',
                  ),
                  if (review.effectiveCorrection case final correction?) ...[
                    Text('Last correction: ${correction.reason}'),
                    Text(
                      'Reviewed by ${correction.reviewerName} on ${_date.format(correction.correctedAt.toLocal())}',
                    ),
                    const Text(
                      'This correction will explicitly supersede that reviewed correction.',
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      'Correct time: ${_date.format(_effectiveAt!.toLocal())}',
                    ),
                  ),
                  TextField(
                    controller: _reason,
                    enabled: !_busy,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Why is the recorded time wrong?',
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (sameActor && review == null && pending == null)
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Retry server check'),
          ),
        if (sameActor && (review != null || pending != null))
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(
              pending == null ? 'Save correction' : 'Check saved correction',
            ),
          ),
      ],
    );
  }
}
