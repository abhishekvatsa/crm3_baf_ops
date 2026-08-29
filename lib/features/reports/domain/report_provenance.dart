enum ReportSourceMode { hybridApplicationSnapshot, cloudApplicationSnapshot }

extension ReportSourceModeLabel on ReportSourceMode {
  String get label => switch (this) {
    ReportSourceMode.hybridApplicationSnapshot =>
      'Hybrid device and cloud application snapshot',
    ReportSourceMode.cloudApplicationSnapshot => 'Cloud application snapshot',
  };
}

class ReportProvenance {
  const ReportProvenance({
    required this.sourceMode,
    this.lastSyncCompletedAt,
    this.lastSyncSucceeded,
    this.pendingLocalWrites,
    this.completenessNotes = const <String>[],
  });

  const ReportProvenance.applicationSnapshot()
    : sourceMode = ReportSourceMode.hybridApplicationSnapshot,
      lastSyncCompletedAt = null,
      lastSyncSucceeded = null,
      pendingLocalWrites = null,
      completenessNotes = const <String>[];

  final ReportSourceMode sourceMode;
  final DateTime? lastSyncCompletedAt;
  final bool? lastSyncSucceeded;
  final int? pendingLocalWrites;
  final List<String> completenessNotes;

  bool get hasKnownPendingWrites => (pendingLocalWrites ?? 0) > 0;

  String get evidenceStatement {
    final notes = <String>[
      '${sourceMode.label}. Included records passed the app\'s persisted-data '
          'and signed-in authority checks at generation time.',
      if (lastSyncCompletedAt != null)
        'The last recorded synchronization completed at '
            '${lastSyncCompletedAt!.toLocal().toIso8601String()}'
            '${lastSyncSucceeded == true
                ? ' successfully'
                : lastSyncSucceeded == false
                ? ' with failures'
                : ''}.',
      if (pendingLocalWrites != null)
        pendingLocalWrites == 0
            ? 'No pending local writes were counted when the report was opened.'
            : '$pendingLocalWrites pending local '
                '${pendingLocalWrites == 1 ? 'write was' : 'writes were'} counted when the report was opened.',
      ...completenessNotes,
      'This document is not an independently server-certified database extract.',
    ];
    return notes.join(' ');
  }
}
