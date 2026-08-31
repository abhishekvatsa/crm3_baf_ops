import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../domain/structured_report_document.dart';
import '../services/structured_report_pdf_service.dart';
import 'zoomable_pdf_preview.dart';

class StructuredReportPdfPreviewScreen extends StatelessWidget {
  const StructuredReportPdfPreviewScreen({super.key, required this.report});

  final StructuredReportDocument report;

  @override
  Widget build(BuildContext context) {
    final pageFormat =
        report.orientation == StructuredReportOrientation.landscape
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4;
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'PDF report preview',
          subtitle: 'Review, share, save or print the generated document',
          icon: Icons.picture_as_pdf_outlined,
          accent: BafColors.maintenance,
        ),
      ),
      body: ZoomablePdfPreview(
        pageFormat: pageFormat,
        fileName: report.fileName,
        documentBuilder: (_) => StructuredReportPdfService.build(report),
      ),
    );
  }
}
