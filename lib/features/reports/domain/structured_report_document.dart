import 'report_provenance.dart';

enum StructuredReportOrientation { portrait, landscape }

enum StructuredReportMetricTone { neutral, info, positive, warning, danger }

class StructuredReportMetric {
  const StructuredReportMetric({
    required this.label,
    required this.value,
    this.detail,
    this.tone = StructuredReportMetricTone.neutral,
  });

  final String label;
  final String value;
  final String? detail;
  final StructuredReportMetricTone tone;
}

class StructuredReportField {
  const StructuredReportField({required this.label, required this.value});

  final String label;
  final String value;
}

class StructuredReportTable {
  StructuredReportTable({
    required this.headers,
    required List<List<String>> rows,
    this.title,
    this.subtitle,
    this.columnFlex,
    this.cellCharacterLimit,
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ) {
    if (headers.isEmpty) {
      throw ArgumentError.value(headers, 'headers', 'must not be empty');
    }
    if (rows.any((row) => row.length != headers.length)) {
      throw ArgumentError('Every report table row must match its headers.');
    }
    if (columnFlex != null && columnFlex!.length != headers.length) {
      throw ArgumentError('Column flex values must match the header count.');
    }
    if (cellCharacterLimit != null && cellCharacterLimit! < 40) {
      throw ArgumentError.value(
        cellCharacterLimit,
        'cellCharacterLimit',
        'must be at least 40 characters',
      );
    }
  }

  final String? title;
  final String? subtitle;
  final List<String> headers;
  final List<List<String>> rows;
  final List<double>? columnFlex;

  /// Null preserves complete cell text. Summary reports may set an explicit
  /// limit and must state that complete records remain available elsewhere.
  final int? cellCharacterLimit;
}

class StructuredReportSection {
  StructuredReportSection({
    required this.title,
    this.subtitle,
    this.metrics = const <StructuredReportMetric>[],
    this.fields = const <StructuredReportField>[],
    this.paragraphs = const <String>[],
    this.tables = const <StructuredReportTable>[],
    this.pageBreakBefore = false,
  });

  final String title;
  final String? subtitle;
  final List<StructuredReportMetric> metrics;
  final List<StructuredReportField> fields;
  final List<String> paragraphs;
  final List<StructuredReportTable> tables;
  final bool pageBreakBefore;
}

class StructuredReportDocument {
  StructuredReportDocument({
    required this.title,
    required this.subtitle,
    required this.reportId,
    required this.generatedAt,
    required this.generatedByName,
    required this.scopeLabel,
    required this.provenance,
    required List<StructuredReportSection> sections,
    this.periodStart,
    this.periodEnd,
    this.orientation = StructuredReportOrientation.portrait,
  }) : sections = List<StructuredReportSection>.unmodifiable(sections) {
    if (title.trim().isEmpty || reportId.trim().isEmpty) {
      throw ArgumentError('A report title and report ID are required.');
    }
    if (sections.isEmpty) {
      throw ArgumentError('A structured report requires at least one section.');
    }
    if ((periodStart == null) != (periodEnd == null)) {
      throw ArgumentError(
        'A reporting period must provide both start and end.',
      );
    }
    if (periodStart != null && periodEnd!.isBefore(periodStart!)) {
      throw ArgumentError('The report period end precedes its start.');
    }
  }

  final String title;
  final String subtitle;
  final String reportId;
  final DateTime generatedAt;
  final String generatedByName;
  final String scopeLabel;
  final ReportProvenance provenance;
  final List<StructuredReportSection> sections;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final StructuredReportOrientation orientation;

  String get fileName {
    final cleaned = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'crm3_${cleaned.isEmpty ? 'report' : cleaned}_$reportId.pdf';
  }
}

String createStructuredReportId(String prefix, DateTime generatedAt) {
  final utc = generatedAt.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  final date = '${two(utc.year % 100)}${two(utc.month)}${two(utc.day)}';
  final time = '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  final cleanPrefix = prefix.trim().toUpperCase().replaceAll(
    RegExp(r'[^A-Z0-9]+'),
    '-',
  );
  return '${cleanPrefix.isEmpty ? 'REPORT' : cleanPrefix}-$date-$time';
}
