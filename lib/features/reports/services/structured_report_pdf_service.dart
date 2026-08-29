import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/baf_design_system.dart';
import '../domain/report_provenance.dart';
import '../domain/structured_report_document.dart';

class StructuredReportPdfService {
  StructuredReportPdfService._();

  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, HH:mm');
  static const PdfColor _graphite = PdfColor(0.078, 0.129, 0.157);
  static const PdfColor _teal = PdfColor(0.055, 0.478, 0.494);
  static const PdfColor _cobalt = PdfColor(0.196, 0.404, 0.694);
  static const PdfColor _success = PdfColor(0.176, 0.502, 0.314);
  static const PdfColor _warning = PdfColor(0.769, 0.529, 0.118);
  static const PdfColor _danger = PdfColor(0.784, 0.298, 0.212);
  static const PdfColor _surface = PdfColor(0.949, 0.965, 0.969);
  static const PdfColor _border = PdfColor(0.831, 0.867, 0.882);
  static const PdfColor _muted = PdfColor(0.333, 0.404, 0.435);

  static Future<Uint8List> build(StructuredReportDocument report) async {
    final sailData = await rootBundle.load(BafBrand.sailMarkAsset);
    final manmithasData = await rootBundle.load(BafBrand.markAsset);
    final regularFontData = await rootBundle.load(BafBrand.reportFontAsset);
    final mediumFontData = await rootBundle.load(
      BafBrand.reportFontMediumAsset,
    );
    final sailLogo = pw.MemoryImage(_assetBytes(sailData));
    final manmithasLogo = pw.MemoryImage(_assetBytes(manmithasData));
    final regularFont = pw.Font.ttf(regularFontData);
    final mediumFont = pw.Font.ttf(mediumFontData);
    final document = pw.Document(
      title: report.title,
      author: report.generatedByName,
      creator: '${BafBrand.productName} | ${BafBrand.makerName}',
      subject: '${report.title} ${report.reportId}',
      keywords: 'BAF, maintenance, operations, SAIL, CRM-III',
    );
    final pageFormat =
        report.orientation == StructuredReportOrientation.landscape
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4;

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(base: regularFont, bold: mediumFont),
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 30),
        header:
            (_) => _header(
              report: report,
              sailLogo: sailLogo,
              manmithasLogo: manmithasLogo,
            ),
        footer: (context) => _footer(context, report),
        build:
            (_) => <pw.Widget>[
              _identity(report),
              pw.SizedBox(height: 16),
              for (var index = 0; index < report.sections.length; index++) ...[
                if (report.sections[index].pageBreakBefore) pw.NewPage(),
                ..._section(report.sections[index]),
                if (index < report.sections.length - 1) pw.SizedBox(height: 16),
              ],
            ],
      ),
    );
    return document.save();
  }

  static pw.Widget _header({
    required StructuredReportDocument report,
    required pw.MemoryImage sailLogo,
    required pw.MemoryImage manmithasLogo,
  }) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 9),
    margin: const pw.EdgeInsets.only(bottom: 14),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.8)),
    ),
    child: pw.Row(
      children: <pw.Widget>[
        pw.SizedBox(
          width: 74,
          height: 35,
          child: pw.Image(sailLogo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                BafBrand.plantName,
                style: const pw.TextStyle(
                  color: _graphite,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${BafBrand.productName}  |  ${report.title}',
                style: const pw.TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
        ),
        pw.SizedBox(
          width: 38,
          height: 32,
          child: pw.Image(manmithasLogo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 7),
        pw.Text(
          BafBrand.makerLabel,
          style: const pw.TextStyle(
            color: _graphite,
            fontSize: 6.8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _footer(
    pw.Context context,
    StructuredReportDocument report,
  ) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.only(top: 7),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _border, width: 0.6)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Text(
            '${report.reportId}  |  ${report.provenance.sourceMode.label}',
            style: const pw.TextStyle(color: _muted, fontSize: 6.8),
          ),
        ),
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(color: _muted, fontSize: 7),
        ),
      ],
    ),
  );

  static pw.Widget _identity(StructuredReportDocument report) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(
        report.title,
        style: const pw.TextStyle(
          color: _graphite,
          fontSize: 23,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        report.subtitle,
        style: const pw.TextStyle(color: _muted, fontSize: 10),
      ),
      pw.SizedBox(height: 12),
      _metadataGrid(<StructuredReportField>[
        StructuredReportField(label: 'Scope', value: report.scopeLabel),
        if (report.periodStart != null)
          StructuredReportField(
            label: 'Reporting period',
            value:
                '${_dateTime.format(report.periodStart!.toLocal())} to '
                '${_dateTime.format(report.periodEnd!.toLocal())}',
          ),
        StructuredReportField(
          label: 'Generated by',
          value: report.generatedByName,
        ),
        StructuredReportField(
          label: 'Generated at',
          value: _dateTime.format(report.generatedAt.toLocal()),
        ),
        StructuredReportField(label: 'Report ID', value: report.reportId),
      ]),
      pw.SizedBox(height: 12),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: const PdfColor(0.922, 0.957, 0.957),
          border: pw.Border.all(color: _teal, width: 0.7),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          report.provenance.evidenceStatement,
          style: const pw.TextStyle(color: _graphite, fontSize: 8.2),
        ),
      ),
    ],
  );

  static List<pw.Widget> _section(StructuredReportSection section) =>
      <pw.Widget>[
        _sectionHeading(section.title, section.subtitle),
        if (section.metrics.isNotEmpty) ...[
          _metricGrid(section.metrics),
          pw.SizedBox(height: 10),
        ],
        if (section.fields.isNotEmpty) ...[
          _metadataGrid(section.fields),
          pw.SizedBox(height: 9),
        ],
        for (final paragraph in section.paragraphs) ...[
          pw.Text(
            paragraph,
            style: const pw.TextStyle(
              color: _graphite,
              fontSize: 8.4,
              height: 1.35,
            ),
          ),
          pw.SizedBox(height: 7),
        ],
        for (final table in section.tables) ...[
          if (table.title?.trim().isNotEmpty == true)
            pw.Text(
              table.title!,
              style: const pw.TextStyle(
                color: _graphite,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          if (table.subtitle?.trim().isNotEmpty == true) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              table.subtitle!,
              style: const pw.TextStyle(color: _muted, fontSize: 7.5),
            ),
          ],
          if (table.title?.trim().isNotEmpty == true ||
              table.subtitle?.trim().isNotEmpty == true)
            pw.SizedBox(height: 6),
          ..._tables(table),
          pw.SizedBox(height: 9),
        ],
      ];

  static pw.Widget _sectionHeading(String title, String? subtitle) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.only(left: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: _teal, width: 3)),
        ),
        child: pw.Text(
          title,
          style: const pw.TextStyle(
            color: _graphite,
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      if (subtitle?.trim().isNotEmpty == true) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          subtitle!,
          style: const pw.TextStyle(color: _muted, fontSize: 8),
        ),
      ],
      pw.SizedBox(height: 9),
    ],
  );

  static pw.Widget _metricGrid(List<StructuredReportMetric> metrics) => pw.Wrap(
    spacing: 8,
    runSpacing: 8,
    children: metrics
        .map(
          (metric) => pw.Container(
            width: 150,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _tone(metric.tone), width: 0.7),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  metric.label,
                  style: const pw.TextStyle(color: _muted, fontSize: 7),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  metric.value,
                  style: pw.TextStyle(
                    color: _tone(metric.tone),
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (metric.detail?.trim().isNotEmpty == true) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    metric.detail!,
                    style: const pw.TextStyle(color: _muted, fontSize: 6.5),
                  ),
                ],
              ],
            ),
          ),
        )
        .toList(growable: false),
  );

  static pw.Widget _metadataGrid(List<StructuredReportField> fields) =>
      pw.Table(
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(105),
          1: pw.FlexColumnWidth(),
        },
        children: fields
            .map(
              (field) => pw.TableRow(
                children: <pw.Widget>[
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      field.label,
                      style: const pw.TextStyle(
                        color: _muted,
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      field.value,
                      style: const pw.TextStyle(color: _graphite, fontSize: 8),
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      );

  static List<pw.Widget> _tables(StructuredReportTable table) {
    if (table.rows.isEmpty) {
      return <pw.Widget>[_emptyStatement('No records in this section.')];
    }
    const rowsPerBlock = 8;
    final rows = table.rows
        .map(
          (row) => row
              .map((cell) => _cellText(cell, table.cellCharacterLimit))
              .toList(growable: false),
        )
        .toList(growable: false);
    final widths =
        table.columnFlex == null
            ? null
            : <int, pw.TableColumnWidth>{
              for (var index = 0; index < table.columnFlex!.length; index++)
                index: pw.FlexColumnWidth(table.columnFlex![index]),
            };
    final widgets = <pw.Widget>[];
    for (var start = 0; start < rows.length; start += rowsPerBlock) {
      if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 6));
      final end =
          start + rowsPerBlock < rows.length
              ? start + rowsPerBlock
              : rows.length;
      widgets.add(
        pw.TableHelper.fromTextArray(
          headers: table.headers,
          data: rows.sublist(start, end),
          border: pw.TableBorder.all(color: _border, width: 0.55),
          columnWidths: widths,
          headerDecoration: const pw.BoxDecoration(color: _graphite),
          headerStyle: const pw.TextStyle(
            color: PdfColors.white,
            fontSize: 7.2,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(color: _graphite, fontSize: 7),
          oddRowDecoration: const pw.BoxDecoration(color: _surface),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 4,
          ),
          cellAlignment: pw.Alignment.centerLeft,
          headerAlignment: pw.Alignment.centerLeft,
        ),
      );
    }
    return widgets;
  }

  static pw.Widget _emptyStatement(String text) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _surface,
      border: pw.Border.all(color: _border, width: 0.6),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Text(text, style: const pw.TextStyle(color: _muted, fontSize: 8)),
  );

  static String _cellText(String value, int? characterLimit) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (characterLimit == null || normalized.length <= characterLimit) {
      return normalized;
    }
    return '${normalized.substring(0, characterLimit - 3).trimRight()}...';
  }

  static PdfColor _tone(StructuredReportMetricTone tone) => switch (tone) {
    StructuredReportMetricTone.neutral => _muted,
    StructuredReportMetricTone.info => _cobalt,
    StructuredReportMetricTone.positive => _success,
    StructuredReportMetricTone.warning => _warning,
    StructuredReportMetricTone.danger => _danger,
  };

  static Uint8List _assetBytes(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
