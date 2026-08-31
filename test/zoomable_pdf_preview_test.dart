import 'dart:convert';
import 'dart:typed_data';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/reports/presentation/zoomable_pdf_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF pages expose direct zoom, fit, and page navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _TestHost(
        pages: <PdfPreviewPageData>[
          _page(width: 595, height: 842),
          _page(width: 595, height: 842),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    final firstViewer = tester.widget<InteractiveViewer>(
      find.byKey(const Key('pdf-preview-interactive-page')),
    );
    expect(firstViewer.transformationController!.value.getMaxScaleOnAxis(), 1);

    await tester.tap(find.byKey(const Key('pdf-preview-zoom-in')));
    await tester.pump();
    expect(find.text('150%'), findsOneWidget);
    expect(
      firstViewer.transformationController!.value.getMaxScaleOnAxis(),
      1.5,
    );

    await tester.tap(find.byKey(const Key('pdf-preview-fit-page')));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    expect(firstViewer.transformationController!.value.getMaxScaleOnAxis(), 1);

    await tester.tap(find.byKey(const Key('pdf-preview-next-page')));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    final previous = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('pdf-preview-previous-page')),
        matching: find.byType(IconButton),
      ),
    );
    final next = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('pdf-preview-next-page')),
        matching: find.byType(IconButton),
      ),
    );
    expect(previous.onPressed, isNotNull);
    expect(next.onPressed, isNull);
  });

  testWidgets('double tap zooms the current PDF page and toggles back to fit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_TestHost(pages: <PdfPreviewPageData>[_page()]));
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(const Key('pdf-preview-interactive-page'));
    await tester.tap(viewerFinder);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(viewerFinder);
    await tester.pumpAndSettle();

    var viewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2.25);

    await tester.tap(viewerFinder);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(viewerFinder);
    await tester.pumpAndSettle();

    viewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
  });

  testWidgets('pinch gesture directly zooms the current PDF page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_TestHost(pages: <PdfPreviewPageData>[_page()]));
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(const Key('pdf-preview-interactive-page'));
    final center = tester.getCenter(viewerFinder);
    final left = await tester.startGesture(
      center - const Offset(24, 0),
      pointer: 1,
    );
    final right = await tester.startGesture(
      center + const Offset(24, 0),
      pointer: 2,
    );
    await tester.pump();
    await left.moveTo(center - const Offset(90, 0));
    await right.moveTo(center + const Offset(90, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1.5),
    );
  });

  testWidgets('PDF controls fit without overflow on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(300, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _TestHost(pages: <PdfPreviewPageData>[_page(), _page(), _page()]),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('pdf-preview-zoom-in')), findsOneWidget);
    expect(find.byKey(const Key('pdf-preview-next-page')), findsOneWidget);
    expect(find.byKey(const Key('pdf-preview-scale-indicator')), findsNothing);
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.pages});

  final List<PdfPreviewPageData> pages;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: BafAppTheme.light,
    home: Scaffold(body: ZoomablePdfPageDeck(pages: pages)),
  );
}

PdfPreviewPageData _page({int width = 595, int height = 842}) =>
    PdfPreviewPageData(
      image: MemoryImage(_transparentPng),
      width: width,
      height: height,
    );

final Uint8List _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4'
  '2mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
