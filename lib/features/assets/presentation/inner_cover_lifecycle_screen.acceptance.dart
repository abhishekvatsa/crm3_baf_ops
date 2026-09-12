part of 'inner_cover_lifecycle_screen.dart';

class _AcceptanceResult extends InnerCoverAcceptanceInput {
  const _AcceptanceResult({
    required super.inspectedOn,
    required super.acceptanceReference,
    super.leakTestReference,
    super.ndtReference,
    super.notes,
    required super.reason,
  });
}

class _AcceptanceDialog extends ConsumerStatefulWidget {
  final InnerCoverProfile initialCover;
  final DurableSubmission? initialSubmission;
  final AppUser originalActor;
  final Future<InnerCoverProfile> Function(
    _AcceptanceResult,
    String,
    InnerCoverProfile,
  )
  onSubmit;
  final Future<InnerCoverProfile> Function(InnerCoverProfile) onRefreshSubject;
  const _AcceptanceDialog({
    required this.initialCover,
    this.initialSubmission,
    required this.originalActor,
    required this.onSubmit,
    required this.onRefreshSubject,
  });

  @override
  ConsumerState<_AcceptanceDialog> createState() => _AcceptanceDialogState();
}

class _AcceptanceDialogState extends ConsumerState<_AcceptanceDialog> {
  final _acceptance = TextEditingController();
  final _leak = TextEditingController();
  final _ndt = TextEditingController();
  final _notes = TextEditingController();
  final _reason = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _requestId;
  DateTime? _inspectedOn;
  String? _dateError;
  String? _error;
  bool _busy = false;
  _AcceptanceResult? _submitted;
  late InnerCoverProfile _reviewedCover;
  bool _reviewRequired = false;
  String? _reviewMessage;

  @override
  void initState() {
    super.initState();
    _reviewedCover = widget.initialCover;
    final retained = widget.initialSubmission;
    if (retained != null) {
      final saved = InnerCoverAcceptanceSubmission.parse(retained.envelopeJson);
      final input = saved.input;
      _requestId = saved.requestId;
      _inspectedOn = input.inspectedOn.toLocal();
      _acceptance.text = input.acceptanceReference;
      _leak.text = input.leakTestReference ?? '';
      _ndt.text = input.ndtReference ?? '';
      _notes.text = input.notes ?? '';
      _reason.text = input.reason;
      _submitted = _AcceptanceResult(
        inspectedOn: input.inspectedOn,
        acceptanceReference: input.acceptanceReference,
        reason: input.reason,
        leakTestReference: input.leakTestReference,
        ndtReference: input.ndtReference,
        notes: input.notes,
      );
      _reviewMessage = retained.state.isAccepted
          ? 'Recovered a recorded acceptance. Check the current cover; acceptance will not be sent again.'
          : 'Recovered your saved acceptance for revision ${saved.expectedVersion}. Check or retry the same request.';
    }
  }

  bool get _canAccept =>
      _reviewedCover.lifecycleState ==
          InnerCoverLifecycleState.awaitingInspection ||
      _reviewedCover.lifecycleState == InnerCoverLifecycleState.underInspection;

  Future<void> _reviewCurrentCover() async {
    if (_busy || _submitted != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final current = await widget.onRefreshSubject(_reviewedCover);
      if (!mounted) return;
      setState(() {
        _reviewedCover = current;
        _reviewRequired = !_canAccept;
        _reviewMessage = _canAccept
            ? '${current.serialNumber}: ${current.lifecycleState.label}, revision ${current.version}. Review the retained inspection before accepting.'
            : '${current.serialNumber}: ${current.lifecycleState.label}. Acceptance is not currently available. Your inspection entries are retained.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseInspectionTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _inspectedOn ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_inspectedOn ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _inspectedOn = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _dateError = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _reviewRequired) return;
    final access = CurrentActorAccess.resolve(ref.read(currentAppUserProvider));
    final actorError = !access.isReady
        ? access.message
        : access.actor!.uid != widget.originalActor.uid
        ? 'Return to the original account to check this acceptance.'
        : _submitted == null && !access.actor!.isAdmin
        ? 'Only an approved admin can accept this Inner Cover.'
        : null;
    if (actorError != null) {
      setState(() => _error = actorError);
      return;
    }
    final retryingUncertainSubmission = _submitted != null;
    if (_submitted == null) {
      final valid = _formKey.currentState!.validate();
      setState(
        () => _dateError = _inspectedOn == null
            ? 'Choose when the inspection actually took place.'
            : _inspectedOn!.isAfter(DateTime.now())
            ? 'Inspection time cannot be in the future.'
            : null,
      );
      if (!valid || _dateError != null) return;
      String? optional(TextEditingController value) =>
          cleanHierarchyText(value.text);
      final input = _AcceptanceResult(
        inspectedOn: _inspectedOn!,
        acceptanceReference: _acceptance.text.trim(),
        leakTestReference: optional(_leak),
        ndtReference: optional(_ndt),
        notes: optional(_notes),
        reason: _reason.text.trim(),
      );
      final validationError = input.validationError(
        now: DateTime.now(),
        receivedOn: _reviewedCover.receivedOrCompletedOn,
      );
      if (validationError != null) {
        setState(() => _error = validationError);
        return;
      }
      _submitted = input;
      _requestId = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await widget.onSubmit(
        _submitted!,
        _requestId!,
        _reviewedCover,
      );
      if (mounted) Navigator.pop(context, profile);
    } catch (error) {
      if (mounted) {
        setState(() {
          final rejectedLocally =
              error is AssetHierarchyInputRejected &&
              !retryingUncertainSubmission;
          _error = error is AssetHierarchyCommandRefused
              ? 'Acceptance was refused. Your entries are retained; review and correct them. ${error.message}'
              : rejectedLocally
              ? 'Acceptance was not sent. Correct the retained entries. $error'
              : '$error';
          if (error is AssetHierarchyCommandRefused || rejectedLocally) {
            _submitted = null;
            _requestId = null;
          }
          if (error is AssetHierarchyCommandRefused &&
              error.requiresSubjectReview) {
            _reviewRequired = true;
            _reviewMessage = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _acceptance.dispose();
    _leak.dispose();
    _ndt.dispose();
    _notes.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Accept Inner Cover'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Record the actual inspection time. The server records when acceptance is submitted separately.',
              ),
              if (_reviewMessage != null) Text(_reviewMessage!),
              TextButton.icon(
                onPressed: _submitted != null ? null : _chooseInspectionTime,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _inspectedOn == null
                      ? 'Choose inspection date and time'
                      : DateFormat('dd MMM yyyy, HH:mm').format(_inspectedOn!),
                ),
              ),
              if (_dateError != null)
                Text(
                  _dateError!,
                  style: const TextStyle(color: BafColors.danger),
                ),
              TextFormField(
                controller: _acceptance,
                readOnly: _submitted != null,
                validator: InnerCoverAcceptanceInput.referenceError,
                decoration: const InputDecoration(
                  labelText: 'Acceptance reference',
                ),
              ),
              TextFormField(
                controller: _leak,
                readOnly: _submitted != null,
                validator: InnerCoverAcceptanceInput.optionalReferenceError,
                decoration: const InputDecoration(
                  labelText: 'Leak-test reference',
                ),
              ),
              TextFormField(
                controller: _ndt,
                readOnly: _submitted != null,
                validator: InnerCoverAcceptanceInput.optionalReferenceError,
                decoration: const InputDecoration(labelText: 'NDT reference'),
              ),
              TextFormField(
                controller: _notes,
                readOnly: _submitted != null,
                validator: InnerCoverAcceptanceInput.notesError,
                decoration: const InputDecoration(
                  labelText: 'Inspection notes',
                ),
              ),
              TextFormField(
                controller: _reason,
                readOnly: _submitted != null,
                validator: InnerCoverAcceptanceInput.reasonError,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Acceptance reason',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: BafSpacing.md),
                Text(_error!, style: const TextStyle(color: BafColors.danger)),
                if (_submitted != null)
                  const Text(
                    'Check or retry this same acceptance before starting another one. Saved submissions can be reopened here after restarting the app. Closing this form does not cancel a submission.',
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy
            ? null
            : _reviewRequired
            ? _reviewCurrentCover
            : _submit,
        child: Text(
          _busy
              ? 'Checking…'
              : _reviewRequired
              ? 'Review current cover'
              : _submitted == null
              ? 'Accept'
              : 'Check or retry',
        ),
      ),
    ],
  );
}
