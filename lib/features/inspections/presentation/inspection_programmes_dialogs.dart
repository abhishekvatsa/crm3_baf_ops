part of 'inspection_programmes_screen.dart';

class _LinkInspectionIssueDialog extends StatefulWidget {
  const _LinkInspectionIssueDialog();

  @override
  State<_LinkInspectionIssueDialog> createState() =>
      _LinkInspectionIssueDialogState();
}

class _LinkInspectionIssueDialogState
    extends State<_LinkInspectionIssueDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Link maintenance issue'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Maintenance issue ID',
        helperText: 'The issue must identify the same asset.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        icon: const Icon(Icons.link_rounded),
        label: const Text('Link'),
      ),
    ],
  );
}

class _InspectionReasonDialog extends StatefulWidget {
  const _InspectionReasonDialog({
    required this.title,
    required this.message,
    this.minimumLength = 1,
    this.actionLabel = 'Record',
    this.destructive = false,
  });

  final String title;
  final String message;
  final int minimumLength;
  final String actionLabel;
  final bool destructive;

  @override
  State<_InspectionReasonDialog> createState() =>
      _InspectionReasonDialogState();
}

class _InspectionReasonDialogState extends State<_InspectionReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.message),
        const SizedBox(height: BafSpacing.md),
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Reason',
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: widget.destructive
            ? FilledButton.styleFrom(backgroundColor: BafColors.danger)
            : null,
        onPressed: _controller.text.trim().length >= widget.minimumLength
            ? () => Navigator.pop(context, _controller.text.trim())
            : null,
        child: Text(widget.actionLabel),
      ),
    ],
  );
}
