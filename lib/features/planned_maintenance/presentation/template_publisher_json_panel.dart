part of 'template_publisher_screen.dart';

class _JsonPanel extends StatefulWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final _JsonRoot expectedRoot;
  final int minLines;
  final bool highlight;
  final VoidCallback onChanged;
  final Future<void> Function(TextEditingController controller) onPretty;
  final Future<void> Function(TextEditingController controller) onPaste;
  final void Function(TextEditingController controller, _JsonRoot root) onClear;

  const _JsonPanel({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.expectedRoot,
    required this.minLines,
    required this.onChanged,
    required this.onPretty,
    required this.onPaste,
    required this.onClear,
    this.highlight = false,
  });

  @override
  State<_JsonPanel> createState() => _JsonPanelState();
}

class _JsonPanelState extends State<_JsonPanel> {
  bool _isHoveringDrag = false;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.highlight
            ? BafColors.planned.withValues(alpha: 0.45)
            : BafColors.border;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isHoveringDrag = true);
        return details.data.trim().isNotEmpty;
      },
      onLeave: (_) => setState(() => _isHoveringDrag = false),
      onAcceptWithDetails: (details) {
        widget.controller.text = details.data;
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );
        setState(() => _isHoveringDrag = false);
        widget.onChanged();
      },
      builder: (context, _, __) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(BafSpacing.md),
          decoration: BoxDecoration(
            color:
                _isHoveringDrag
                    ? BafColors.planned.withValues(alpha: 0.08)
                    : const Color(0xFFFBFCFE),
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(
              color: _isHoveringDrag ? BafColors.planned : borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: BafColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: BafSpacing.xs),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Wrap(
                    spacing: BafSpacing.xs,
                    children: [
                      _TinyActionButton(
                        label: 'Paste',
                        icon: Icons.content_paste_rounded,
                        onPressed: () => widget.onPaste(widget.controller),
                      ),
                      _TinyActionButton(
                        label: 'Pretty',
                        icon: Icons.auto_fix_high_rounded,
                        onPressed: () => widget.onPretty(widget.controller),
                      ),
                      _TinyActionButton(
                        label: 'Clear',
                        icon: Icons.clear_rounded,
                        onPressed:
                            () => widget.onClear(
                              widget.controller,
                              widget.expectedRoot,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: widget.controller,
                minLines: widget.minLines,
                maxLines: widget.minLines + 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText:
                      widget.expectedRoot == _JsonRoot.object
                          ? '{\n  "title": "..."\n}'
                          : '[\n  { "key": "..." }\n]',
                  filled: true,
                  fillColor: Colors.white,
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
                    borderSide: const BorderSide(
                      color: BafColors.planned,
                      width: 1.4,
                    ),
                  ),
                ),
                onChanged: (_) => widget.onChanged(),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _compactContentHash(String? hash) {
  final value = hash?.trim();
  if (value == null || value.isEmpty) return 'hash pending';
  final separator = value.indexOf(':');
  if (separator <= 0 || value.length <= 28) return value;

  final prefix = value.substring(0, separator);
  final digest = value.substring(separator + 1);
  if (digest.length <= 16) return value;

  return '$prefix:${digest.substring(0, 8)}…${digest.substring(digest.length - 6)}';
}
