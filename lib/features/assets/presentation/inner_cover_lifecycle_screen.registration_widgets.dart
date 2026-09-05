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
          children: [first, const SizedBox(height: BafSpacing.md), second],
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
        donorSectionKey:
            donorKey.text.trim().isEmpty ? null : donorKey.text.trim(),
        lengthMm: double.tryParse(length.text.trim()),
        cutCount: int.tryParse(cuts.text.trim()) ?? 1,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );

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
            items:
                InnerCoverSectionMaterialSource.values
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
              items:
                  donors
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
