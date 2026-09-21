import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/operational_event.dart';
import '../providers/operational_event_amendment_provider.dart';
import '../services/operational_event_amendment_service.dart';

class OperationalEventAmendmentControls extends ConsumerWidget {
  const OperationalEventAmendmentControls({
    super.key,
    required this.event,
    required this.occurrenceIndex,
  });
  final OperationalEvent event;
  final int occurrenceIndex;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(currentAppUserProvider);
    final actor = authority.valueOrNull;
    final canAmend =
        !authority.isLoading &&
        !authority.hasError &&
        actor != null &&
        actor.isApproved &&
        (actor.isAdmin || actor.isSI);
    final amendment = event.intervalEndAmendments[occurrenceIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (amendment != null)
          Text(
            'Reviewed closure: ${_time(amendment.correctedResolvedAt)}\n${amendment.reason}\nReviewed by ${amendment.amendedByName} on ${_time(amendment.amendedAt)}',
          ),
        if (canAmend &&
            event.isEffective &&
            event.closedOccurrence(occurrenceIndex) != null)
          TextButton.icon(
            key: ValueKey('amend-event-${event.eventId}-$occurrenceIndex'),
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _AmendmentDialog(
                event: event,
                occurrenceIndex: occurrenceIndex,
              ),
            ),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Amend closure time'),
          ),
      ],
    );
  }
}

String _time(DateTime value) =>
    DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());

class _AmendmentDialog extends ConsumerStatefulWidget {
  const _AmendmentDialog({required this.event, required this.occurrenceIndex});
  final OperationalEvent event;
  final int occurrenceIndex;
  @override
  ConsumerState<_AmendmentDialog> createState() => _AmendmentDialogState();
}

class _AmendmentDialogState extends ConsumerState<_AmendmentDialog> {
  final _reason = TextEditingController();
  OperationalEventAmendmentReview? _review;
  DurableSubmission? _pending;
  DateTime? _corrected;
  String? _error, _originUid;
  bool _busy = true;

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
    final authority = ref.read(currentAppUserProvider);
    final actor = authority.valueOrNull;
    if (authority.isLoading ||
        authority.hasError ||
        actor == null ||
        actor.uid != _originUid ||
        !actor.isApproved ||
        !(actor.isAdmin || actor.isSI)) {
      throw StateError(
        'Return to the approved account that opened this amendment.',
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
      final pending = await ref
          .read(operationalEventAmendmentServiceProvider)
          .pending(widget.event.eventId, widget.occurrenceIndex);
      if (!mounted) return;
      _requireOrigin();
      if (pending != null) {
        setState(() {
          _pending = pending;
          _review = null;
        });
      } else {
        final review = await ref
            .read(operationalEventAmendmentRepositoryProvider)
            .review(widget.event.eventId, widget.occurrenceIndex);
        if (!mounted) return;
        _requireOrigin();
        setState(() {
          _pending = null;
          _review = review;
          _corrected ??= review.effectiveEnd;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseDate() async {
    final review = _review!;
    final current = _corrected!.toLocal();
    final now = DateTime.now();
    final last = review.nextStart != null && review.nextStart!.isBefore(now)
        ? review.nextStart!.toLocal()
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(last) ? last : current,
      firstDate: review.original.startedAt.toLocal(),
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(
      () => _corrected = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      ).toUtc(),
    );
  }

  Future<void> _submit() async {
    final review = _review;
    if (_pending == null && (review == null || _corrected == null)) return;
    if (_pending == null &&
        (_reason.text.trim().isEmpty ||
            _reason.text.trim().length > 1000 ||
            _corrected!.isAtSameMomentAs(review!.effectiveEnd) ||
            _corrected!.isBefore(review.original.startedAt) ||
            _corrected!.isAfter(DateTime.now()) ||
            (review.nextStart != null &&
                _corrected!.isAfter(review.nextStart!)))) {
      setState(
        () => _error =
            'Choose a changed closure time after its start and before the next occurrence, and explain the amendment.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _requireOrigin();
      final service = ref.read(operationalEventAmendmentServiceProvider);
      if (_pending != null) {
        await service.resume(_pending!.submissionId);
      } else {
        await service.submit(
          review: review!,
          correctedResolvedAt: _corrected!,
          reason: _reason.text,
        );
      }
      if (!mounted) return;
      _requireOrigin();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Closure amendment confirmed. The original record is preserved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      // A definitive refusal refreshes review without discarding the draft;
      // an uncertain result instead exposes recovery of the original request.
      await _load();
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authority = ref.watch(currentAppUserProvider);
    final actor = authority.valueOrNull;
    final sameActor =
        !authority.isLoading &&
        !authority.hasError &&
        actor != null &&
        actor.uid == _originUid &&
        actor.isApproved &&
        (actor.isAdmin || actor.isSI);
    final review = _review;
    return AlertDialog(
      title: const Text('Amend recorded closure'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!sameActor)
                const Text(
                  'Return to the approved original account to review this saved amendment.',
                ),
              if (_busy) const LinearProgressIndicator(),
              if (sameActor) ...[
                Text(
                  'Originally recorded closure: ${_time(widget.event.closedOccurrence(widget.occurrenceIndex)!.resolvedAt)}',
                ),
                const Text(
                  'The reviewed time changes duration calculations. The original closure and restoration note remain preserved.',
                ),
                if (_pending != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'A saved amendment still needs confirmation. Check the original request before submitting another amendment.',
                  ),
                ] else if (review != null) ...[
                  Text('Effective closure: ${_time(review.effectiveEnd)}'),
                  if (review.amendment case final amendment?)
                    Text(
                      'Last amendment: ${amendment.reason}\nReviewed by ${amendment.amendedByName} on ${_time(amendment.amendedAt)}',
                    ),
                  if (review.history.isNotEmpty)
                    ExpansionTile(
                      title: const Text('Amendment history'),
                      children: [
                        for (final amendment in review.history)
                          ListTile(
                            title: Text(
                              'Effective closure: ${_time(amendment.correctedResolvedAt)}',
                            ),
                            subtitle: Text(
                              '${amendment.reason}\nReviewed by ${amendment.amendedByName} on ${_time(amendment.amendedAt)}',
                            ),
                          ),
                      ],
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text('Correct time: ${_time(_corrected!)}'),
                  ),
                  TextField(
                    controller: _reason,
                    enabled: !_busy,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Why is the recorded closure time wrong?',
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
        if (sameActor && review == null && _pending == null)
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Retry server check'),
          ),
        if (sameActor && (review != null || _pending != null))
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(
              _pending == null ? 'Save amendment' : 'Check saved amendment',
            ),
          ),
      ],
    );
  }
}
