import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/providers/audit_provider.dart';

class MaintenanceTicketCorrectionHistorySection extends ConsumerWidget {
  const MaintenanceTicketCorrectionHistorySection({
    super.key,
    required this.ticketId,
  });

  final String? ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanTicketId = ticketId?.trim();
    final auditAsync =
        cleanTicketId == null || cleanTicketId.isEmpty
            ? const AsyncData<List<AuditEvent>>(<AuditEvent>[])
            : ref.watch(
              maintenanceTicketCorrectionAuditProvider(cleanTicketId),
            );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: BafColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: BafColors.maintenance,
                size: 21,
              ),
              SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  'Audited corrections',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          ..._spaced(
            auditAsync.when(
              loading: () => const <Widget>[_CorrectionHistoryLoading()],
              error:
                  (_, _) => const <Widget>[
                    _EvidenceMessage(
                      text:
                          'Correction history could not be verified. Reconnect and reopen this record before relying on its correction status.',
                      isError: true,
                    ),
                  ],
              data:
                  (events) =>
                      events.isEmpty
                          ? const <Widget>[
                            _EvidenceMessage(
                              text:
                                  'No governed Admin/SI corrections are recorded for this issue.',
                            ),
                          ]
                          : <Widget>[
                            for (var index = 0; index < events.length; index++)
                              _CorrectionAuditView(
                                event: events[index],
                                sequence: events.length - index,
                              ),
                          ],
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _spaced(List<Widget> children) {
    return <Widget>[
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(height: 10),
        children[index],
      ],
    ];
  }
}

class _CorrectionHistoryLoading extends StatelessWidget {
  const _CorrectionHistoryLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            'Verifying correction history...',
            style: TextStyle(color: BafColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _CorrectionAuditView extends StatelessWidget {
  const _CorrectionAuditView({required this.event, required this.sequence});

  static const _fieldOrder = <String>[
    'description',
    'routedTo',
    'maintenanceType',
    'isCritical',
    'component',
    'subsystem',
    'tag',
    'classification',
    'otherDepartment',
    'remarks',
  ];

  final AuditEvent event;
  final int sequence;

  @override
  Widget build(BuildContext context) {
    final changes = _readChanges();
    return Container(
      key: ValueKey('ticket-correction-$sequence'),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: BafColors.warning,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  'Correction $sequence · ${_dateTime(event.timestamp)}',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          _AuditValue(
            label: 'Recorded by',
            value: _firstRecordedText(
              event.performedByName,
              event.performedByUid,
            ),
          ),
          _AuditValue(
            label: 'Reason',
            value:
                event.reasonNotes?.trim().isNotEmpty == true
                    ? event.reasonNotes!.trim()
                    : 'No correction reason was retained.',
          ),
          if (changes == null)
            const _EvidenceMessage(
              text:
                  'The retained before-and-after correction evidence is malformed and cannot be displayed safely.',
              isError: true,
            )
          else if (changes.isEmpty)
            const _EvidenceMessage(
              text:
                  'The retained correction does not identify a supported changed field.',
              isError: true,
            )
          else
            for (final change in changes)
              _CorrectionFieldChange(change: change),
        ],
      ),
    );
  }

  List<_CorrectionChange>? _readChanges() {
    try {
      final before = event.before;
      final after = event.after;
      if (before == null || after == null) return null;
      return <_CorrectionChange>[
        for (final field in _fieldOrder)
          if (before[field] != after[field])
            _CorrectionChange(
              field: field,
              before: before[field],
              after: after[field],
            ),
      ];
    } on FormatException {
      return null;
    }
  }

  static String _firstRecordedText(String? name, String uid) {
    final cleanName = name?.trim();
    return cleanName == null || cleanName.isEmpty ? uid : cleanName;
  }
}

class _CorrectionChange {
  const _CorrectionChange({
    required this.field,
    required this.before,
    required this.after,
  });

  final String field;
  final Object? before;
  final Object? after;
}

class _CorrectionFieldChange extends StatelessWidget {
  const _CorrectionFieldChange({required this.change});

  final _CorrectionChange change;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BafSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fieldLabel(change.field),
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CorrectionValue(
                  label: 'Before',
                  value: _fieldValue(change.field, change.before),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 17),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: BafColors.textSecondary,
                ),
              ),
              Expanded(
                child: _CorrectionValue(
                  label: 'After',
                  value: _fieldValue(change.field, change.after),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditValue extends StatelessWidget {
  const _AuditValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectionValue extends StatelessWidget {
  const _CorrectionValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.small),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceMessage extends StatelessWidget {
  const _EvidenceMessage({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: isError ? BafColors.danger : BafColors.textSecondary,
        fontWeight: isError ? FontWeight.w700 : FontWeight.normal,
        height: 1.35,
      ),
    );
  }
}

String _fieldLabel(String field) => switch (field) {
  'routedTo' => 'Responsible lane',
  'maintenanceType' => 'Maintenance type',
  'isCritical' => 'Critical issue',
  'otherDepartment' => 'Other department',
  _ => _enumLabel(field),
};

String _fieldValue(String field, Object? value) {
  if (value == null || value is String && value.trim().isEmpty) {
    return 'Not recorded';
  }
  if (value is bool) return value ? 'Yes' : 'No';
  final text = value.toString();
  if (field == 'routedTo' ||
      field == 'maintenanceType' ||
      field == 'classification') {
    return _enumLabel(text);
  }
  return text;
}

String _enumLabel(String value) {
  final words = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return words[0].toUpperCase() + words.substring(1);
}

String _dateTime(DateTime value) =>
    DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());
