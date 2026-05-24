import 'package:flutter/material.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../audit/models/audit_event_model.dart';
import '../../utils/admin_ticket_helpers.dart';

class AdminDeleteDecision {
  final AuditReason? reason;
  final String? notes;

  const AdminDeleteDecision({this.reason, this.notes});
}

class AdminDeleteReasonDialog extends StatefulWidget {
  final String title;
  final String message;

  const AdminDeleteReasonDialog({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  State<AdminDeleteReasonDialog> createState() =>
      _AdminDeleteReasonDialogState();
}

class _AdminDeleteReasonDialogState extends State<AdminDeleteReasonDialog> {
  final TextEditingController _notesController = TextEditingController();
  AuditReason? _selectedReason;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.message),
              const SizedBox(height: BafSpacing.md),
              DropdownButtonFormField<AuditReason>(
                initialValue: _selectedReason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
                items:
                    AuditReason.values.map((reason) {
                      return DropdownMenuItem<AuditReason>(
                        value: reason,
                        child: Text(
                          reason.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _selectedReason = value),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Additional notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed:
              () => Navigator.pop(
                context,
                AdminDeleteDecision(
                  reason: _selectedReason,
                  notes: cleanAdminOptionalText(_notesController.text),
                ),
              ),
          child: const Text('Mark Deleted'),
        ),
      ],
    );
  }
}
