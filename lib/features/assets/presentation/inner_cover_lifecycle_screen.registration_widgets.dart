part of 'inner_cover_lifecycle_screen.dart';

class _RegistrationActionBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onRegister;
  final double keyboardInset;

  const _RegistrationActionBar({
    required this.onCancel,
    required this.onRegister,
    required this.keyboardInset,
  });

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOut,
    padding: EdgeInsets.only(bottom: keyboardInset),
    child: SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: BafColors.card,
          border: Border(top: BorderSide(color: BafColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.lg,
            BafSpacing.md,
            BafSpacing.lg,
            BafSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onRegister,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RegistrationFormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _RegistrationFormSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BafSectionHeading(title: title, subtitle: subtitle, icon: icon),
      const SizedBox(height: BafSpacing.md),
      ...children,
    ],
  );
}

class _ResponsiveFormPair extends StatelessWidget {
  final Widget first;
  final Widget second;

  const _ResponsiveFormPair({required this.first, required this.second});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < BafBreakpoints.compact) {
        return Column(
          children: [
            first,
            const SizedBox(height: BafSpacing.md),
            second,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: BafSpacing.md),
          Expanded(child: second),
        ],
      );
    },
  );
}

class _InlineFormError extends StatelessWidget {
  final String message;

  const _InlineFormError({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BafSpacing.md),
    decoration: BoxDecoration(
      color: BafColors.danger.withValues(alpha: 0.08),
      border: Border.all(color: BafColors.danger.withValues(alpha: 0.28)),
      borderRadius: BorderRadius.circular(BafRadius.medium),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, color: BafColors.danger),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: BafColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionEditorState {
  final InnerCoverFabricationSectionType type;
  InnerCoverSectionMaterialSource source =
      InnerCoverSectionMaterialSource.newFabricated;
  InnerCoverProfile? donor;
  final donorKey = TextEditingController();
  final length = TextEditingController();
  final cuts = TextEditingController(text: '1');
  final notes = TextEditingController();

  _SectionEditorState(this.type);

  void markAncestryUnknown() {
    source = InnerCoverSectionMaterialSource.reusedUnknownLegacyDonor;
    donor = null;
    donorKey.clear();
  }

  void markNewFabricated() {
    source = InnerCoverSectionMaterialSource.newFabricated;
    donor = null;
    donorKey.clear();
  }

  InnerCoverFabricationSectionDraft toDraft() =>
      InnerCoverFabricationSectionDraft(
        type: type,
        materialSource: source,
        donor: donor,
        donorSectionKey: donorKey.text.trim().isEmpty
            ? null
            : donorKey.text.trim(),
        lengthMm: double.tryParse(length.text.trim()),
        cutCount: int.tryParse(cuts.text.trim()) ?? 1,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );

  List<String> rawValidationErrors() {
    final errors = <String>[];
    final rawLength = length.text.trim();
    if (rawLength.isNotEmpty && double.tryParse(rawLength) == null) {
      errors.add(
        '${type.label}: enter a valid numeric length or leave it blank.',
      );
    }
    final rawCuts = cuts.text.trim();
    if (rawCuts.isEmpty || int.tryParse(rawCuts) == null) {
      errors.add('${type.label}: enter a whole-number cut count.');
    }
    return errors;
  }

  void dispose() {
    donorKey.dispose();
    length.dispose();
    cuts.dispose();
    notes.dispose();
  }
}

class _FabricationSectionEditor extends StatelessWidget {
  final _SectionEditorState state;
  final List<InnerCoverProfile> donors;
  final VoidCallback onChanged;

  const _FabricationSectionEditor({
    required this.state,
    required this.donors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final known =
        state.source == InnerCoverSectionMaterialSource.reusedKnownDonor;
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: BafColors.border),
        borderRadius: BorderRadius.circular(BafRadius.medium),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded:
            state.type == InnerCoverFabricationSectionType.lowerAssembly,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: BafSpacing.md,
          vertical: BafSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          BafSpacing.md,
          0,
          BafSpacing.md,
          BafSpacing.md,
        ),
        leading: const Icon(
          Icons.account_tree_outlined,
          color: BafColors.maintenance,
        ),
        title: Text(
          state.type.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          state.source.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          DropdownButtonFormField<InnerCoverSectionMaterialSource>(
            key: ValueKey('${state.type.name}-${state.source.name}'),
            initialValue: state.source,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Material source'),
            items: InnerCoverSectionMaterialSource.values
                .map(
                  (source) => DropdownMenuItem(
                    value: source,
                    child: Text(source.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              state.source = value ?? state.source;
              if (state.source !=
                  InnerCoverSectionMaterialSource.reusedKnownDonor) {
                state.donor = null;
                state.donorKey.clear();
              }
              onChanged();
            },
          ),
          const SizedBox(height: BafSpacing.md),
          if (known) ...[
            if (donors.isEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No salvageable donor Inner Cover is currently registered.',
                  style: TextStyle(
                    color: BafColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
            ],
            DropdownButtonFormField<InnerCoverProfile>(
              initialValue: state.donor,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Known donor'),
              items: donors
                  .map(
                    (donor) => DropdownMenuItem(
                      value: donor,
                      child: Text(
                        donor.serialNumber,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                state.donor = value;
                onChanged();
              },
            ),
            const SizedBox(height: BafSpacing.md),
            TextField(
              controller: state.donorKey,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Donor section / cut ID',
              ),
            ),
            const SizedBox(height: BafSpacing.md),
          ],
          _ResponsiveFormPair(
            first: TextField(
              controller: state.length,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(labelText: 'Length (mm)'),
            ),
            second: TextField(
              controller: state.cuts,
              keyboardType: TextInputType.number,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(labelText: 'Cuts used'),
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: state.notes,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Section notes (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _InnerCoverIntakePage extends ConsumerStatefulWidget {
  final String innerCoverId;
  const _InnerCoverIntakePage({required this.innerCoverId});

  @override
  ConsumerState<_InnerCoverIntakePage> createState() =>
      _InnerCoverIntakePageState();
}

class _InnerCoverIntakePageState extends ConsumerState<_InnerCoverIntakePage> {
  late Future<InnerCoverProfile> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _read();
  }

  Future<InnerCoverProfile> _read() => ref
      .read(assetHierarchyRepositoryProvider)
      .readInnerCoverFromServer(widget.innerCoverId);

  @override
  Widget build(BuildContext context) {
    final access = CurrentActorAccess.resolve(
      ref.watch(currentAppUserProvider),
    );
    if (access.availability == CurrentActorAvailability.verifying) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Registered Inner Cover',
        appBarSubtitle: 'Confirm intake and continue to inspection',
        appBarIcon: Icons.layers_outlined,
        accent: BafColors.maintenance,
        label: 'Checking Inner Cover access',
      );
    }
    if (access.availability == CurrentActorAvailability.verificationFailed) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Registered Inner Cover',
        appBarSubtitle: 'Confirm intake and continue to inspection',
        appBarIcon: Icons.layers_outlined,
        accent: BafColors.maintenance,
        message: 'Inner Cover access could not be verified.',
      );
    }
    final user = access.actor;
    return BafScreenScaffold(
      title: 'Registered Inner Cover',
      subtitle: 'Confirm intake and continue to inspection',
      icon: Icons.layers_outlined,
      accent: BafColors.maintenance,
      body: user == null || !user.isApproved
          ? const SingleChildScrollView(
              child: BafStatePanel(
                icon: Icons.lock_outline_rounded,
                color: BafColors.danger,
                title: 'Inner Cover access required',
                message: 'An approved account is required to view this cover.',
              ),
            )
          : FutureBuilder<InnerCoverProfile>(
              future: _profile,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SingleChildScrollView(
                    child: BafStatePanel.error(
                      title: 'Registration recorded; current state unconfirmed',
                      message:
                          'Do not register the cover again. Check its current state to continue to inspection.',
                      primaryLabel: 'Check current cover',
                      onPrimary: () => setState(() => _profile = _read()),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const BafLoadingPanel(
                    label: 'Checking the registered cover',
                    color: BafColors.maintenance,
                  );
                }
                final cover = snapshot.data!;
                return _CoverDetailsSheet(
                  cover: cover,
                  bulgeEvidence: null,
                  canManage: user.canManageAssetHierarchy,
                  onAccept: () => _acceptCover(context, ref, cover, user),
                  onAssign: () => _assignAvailableCover(
                    context,
                    ref,
                    user,
                    cover,
                    (ref.read(allAssetInstancesProvider).value ?? const [])
                        .where(
                          (asset) =>
                              asset.isActive && asset.assetClassCode == 'BASE',
                        )
                        .toList(),
                  ),
                  onDelink: () => _delinkCover(
                    context,
                    ref,
                    cover,
                    (ref
                                .read(innerCoverAssignmentBatchProvider)
                                .value
                                ?.records ??
                            const <BaseInnerCoverAssignment>[])
                        .where((item) => item.innerCoverId == cover.id)
                        .firstOrNull,
                    user,
                  ),
                  onState: () => _changeCoverState(context, ref, cover, user),
                  onCheckSavedLifecycle: () =>
                      _checkSavedInnerCoverLifecycle(context, ref, cover),
                );
              },
            ),
    );
  }
}

class _PendingInnerCoverRegistrationsPage extends ConsumerStatefulWidget {
  const _PendingInnerCoverRegistrationsPage();

  @override
  ConsumerState<_PendingInnerCoverRegistrationsPage> createState() =>
      _PendingInnerCoverRegistrationsPageState();
}

class _PendingInnerCoverRegistrationsPageState
    extends ConsumerState<_PendingInnerCoverRegistrationsPage> {
  late Future<List<DurableSubmission>> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _load();
  }

  Future<List<DurableSubmission>> _load() => ref
      .read(innerCoverLifecycleSubmissionControllerProvider)
      .pendingRegistrations();

  Future<void> _check(DurableSubmission row) async {
    try {
      final profile = await ref
          .read(innerCoverLifecycleSubmissionControllerProvider)
          .check(row.submissionId);
      if (!mounted) return;
      ref.invalidate(innerCoverProfileBatchProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${profile.serialNumber}: registration confirmed.'),
        ),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _InnerCoverIntakePage(innerCoverId: profile.id),
        ),
      );
      if (mounted) setState(() => _rows = _load());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
      setState(() => _rows = _load());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const BafAppBarTitle(
        title: 'Pending registrations',
        subtitle: 'Original saved intake requests',
        icon: Icons.pending_actions_rounded,
        accent: BafColors.maintenance,
      ),
    ),
    body: FutureBuilder<List<DurableSubmission>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return const _EmptyState(
            icon: Icons.task_alt_rounded,
            message: 'No saved Inner Cover registrations need checking.',
          );
        }
        final controller = ref.read(
          innerCoverLifecycleSubmissionControllerProvider,
        );
        return ListView.separated(
          padding: const EdgeInsets.all(BafSpacing.lg),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: BafSpacing.sm),
          itemBuilder: (context, index) {
            final row = rows[index];
            Map<String, dynamic>? request;
            try {
              request = controller.registrationRequestOf(row);
            } on Object {
              request = null;
            }
            final draft = request?['registrationDraft'];
            final serial = draft is Map
                ? draft['serialNumber']?.toString() ?? row.aggregateId
                : row.aggregateId;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: Text(serial),
                subtitle: Text(
                  'Saved ${DateFormat('dd MMM yyyy, HH:mm').format(row.createdAt.toLocal())}\n'
                  'Request ${row.requestId} · ${row.state.name}',
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: () => _check(row),
                  child: const Text('Check'),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
