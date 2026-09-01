import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';

class AbnormalityTypeUnavailableState extends StatelessWidget {
  final Widget state;
  final VoidCallback onCreate;

  const AbnormalityTypeUnavailableState({
    required this.state,
    required this.onCreate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(child: state),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.sm,
              BafSpacing.lg,
              BafSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: _NewAbnormalityTypeButton(onPressed: onCreate),
            ),
          ),
        ],
      ),
    );
  }
}

class AbnormalityTypeToolbar extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;

  const AbnormalityTypeToolbar({
    required this.onSearchChanged,
    required this.onCreate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      decoration: InputDecoration(
        hintText: 'Search by code, title or category',
        hintStyle: const TextStyle(color: BafColors.textSecondary),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: BafColors.textSecondary,
        ),
        filled: true,
        fillColor: BafColors.card,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          borderSide: const BorderSide(color: BafColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          borderSide: const BorderSide(color: BafColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          borderSide: const BorderSide(color: BafColors.navySoft, width: 1.4),
        ),
      ),
      onChanged: onSearchChanged,
    );
    final create = _NewAbnormalityTypeButton(onPressed: onCreate);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: BafSpacing.sm), create],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: BafSpacing.md),
            create,
          ],
        );
      },
    );
  }
}

class _NewAbnormalityTypeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _NewAbnormalityTypeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('abnormality-types-create'),
      style: FilledButton.styleFrom(
        backgroundColor: BafColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: BafSpacing.lg),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New type'),
    );
  }
}
