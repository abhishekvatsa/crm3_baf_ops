import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/baf_design_system.dart';

class ZoomablePdfPreview extends StatelessWidget {
  const ZoomablePdfPreview({
    super.key,
    required this.documentBuilder,
    required this.pageFormat,
    required this.fileName,
  });

  final LayoutCallback documentBuilder;
  final PdfPageFormat pageFormat;
  final String fileName;

  @override
  Widget build(BuildContext context) => Theme(
    data: pdfPreviewControlTheme(Theme.of(context)),
    child: PdfPreview.builder(
      build: documentBuilder,
      initialPageFormat: pageFormat,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      allowPrinting: true,
      allowSharing: true,
      pdfFileName: fileName,
      dpi: 180,
      scrollViewDecoration: const BoxDecoration(color: BafColors.surfaceMuted),
      actionBarTheme: const PdfActionBarTheme(
        backgroundColor: BafColors.graphite,
        iconColor: BafColors.graphite,
        elevation: 0,
        height: 58,
        actionSpacing: BafSpacing.sm,
      ),
      loadingWidget: const _PdfPreviewLoading(),
      pagesBuilder:
          (context, pages) => ZoomablePdfPageDeck(
            pages: List<PdfPreviewPageData>.unmodifiable(pages),
          ),
    ),
  );
}

ThemeData pdfPreviewControlTheme(ThemeData base) => base.copyWith(
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: BafColors.graphite,
      disabledForegroundColor: BafColors.textTertiary,
      backgroundColor: Colors.white,
      disabledBackgroundColor: BafColors.surfaceMuted,
      minimumSize: const Size.square(42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.small),
        side: const BorderSide(color: BafColors.borderStrong),
      ),
    ),
  ),
);

class ZoomablePdfPageDeck extends StatefulWidget {
  const ZoomablePdfPageDeck({super.key, required this.pages})
    : assert(pages.length > 0);

  final List<PdfPreviewPageData> pages;

  @override
  State<ZoomablePdfPageDeck> createState() => _ZoomablePdfPageDeckState();
}

class _ZoomablePdfPageDeckState extends State<ZoomablePdfPageDeck> {
  final GlobalKey<_ZoomablePdfPageState> _pageKey =
      GlobalKey<_ZoomablePdfPageState>();

  int _pageIndex = 0;
  double _scale = 1;

  @override
  void didUpdateWidget(covariant ZoomablePdfPageDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = math.min(_pageIndex, widget.pages.length - 1);
    final oldPage =
        _pageIndex < oldWidget.pages.length
            ? oldWidget.pages[_pageIndex]
            : null;
    final nextPage = widget.pages[nextIndex];
    if (nextIndex != _pageIndex || oldPage != nextPage) {
      _pageIndex = nextIndex;
      _scale = 1;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Expanded(
        child: Semantics(
          label: 'PDF page ${_pageIndex + 1} of ${widget.pages.length}',
          child: _ZoomablePdfPage(
            key: _pageKey,
            page: widget.pages[_pageIndex],
            onScaleChanged: _onScaleChanged,
          ),
        ),
      ),
      _PdfPageToolbar(
        pageIndex: _pageIndex,
        pageCount: widget.pages.length,
        scale: _scale,
        onPrevious: _pageIndex == 0 ? null : () => _showPage(_pageIndex - 1),
        onNext:
            _pageIndex == widget.pages.length - 1
                ? null
                : () => _showPage(_pageIndex + 1),
        onZoomOut:
            _scale <= 1.01 ? null : () => _pageKey.currentState?.zoomOut(),
        onResetZoom:
            _scale <= 1.01 ? null : () => _pageKey.currentState?.resetZoom(),
        onZoomIn: _scale >= 4.99 ? null : () => _pageKey.currentState?.zoomIn(),
      ),
    ],
  );

  void _showPage(int index) {
    setState(() {
      _pageIndex = index;
      _scale = 1;
    });
  }

  void _onScaleChanged(double scale) {
    if ((scale - _scale).abs() < 0.01) {
      return;
    }
    setState(() => _scale = scale);
  }
}

class _ZoomablePdfPage extends StatefulWidget {
  const _ZoomablePdfPage({
    super.key,
    required this.page,
    required this.onScaleChanged,
  });

  final PdfPreviewPageData page;
  final ValueChanged<double> onScaleChanged;

  @override
  State<_ZoomablePdfPage> createState() => _ZoomablePdfPageState();
}

class _ZoomablePdfPageState extends State<_ZoomablePdfPage> {
  static const double _minScale = 1;
  static const double _maxScale = 5;
  static const double _zoomStep = 0.5;

  final TransformationController _transformationController =
      TransformationController();

  Offset? _doubleTapPosition;
  double _displayScale = _minScale;

  @override
  void didUpdateWidget(covariant _ZoomablePdfPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      _reset(notify: false);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void zoomIn() => _applyScale(
    math.min(_maxScale, _displayScale + _zoomStep),
    _viewportCenter,
  );

  void zoomOut() => _applyScale(
    math.max(_minScale, _displayScale - _zoomStep),
    _viewportCenter,
  );

  void resetZoom() => _reset();

  Offset get _viewportCenter {
    final renderBox = context.findRenderObject();
    if (renderBox is RenderBox && renderBox.hasSize) {
      return renderBox.size.center(Offset.zero);
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
    onDoubleTap: () {
      if (_displayScale > _minScale + 0.01) {
        _reset();
      } else {
        _applyScale(2.25, _doubleTapPosition ?? _viewportCenter);
      }
    },
    child: InteractiveViewer(
      key: const Key('pdf-preview-interactive-page'),
      transformationController: _transformationController,
      minScale: _minScale,
      maxScale: _maxScale,
      panEnabled: _displayScale > _minScale + 0.01,
      boundaryMargin: const EdgeInsets.all(48),
      onInteractionUpdate: (_) => _reportScale(),
      onInteractionEnd: (_) => _reportScale(),
      child: ColoredBox(
        color: BafColors.surfaceMuted,
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.lg),
          child: Center(
            child: AspectRatio(
              aspectRatio: widget.page.aspectRatio,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BafColors.borderStrong),
                  boxShadow: BafShadows.raised,
                ),
                child: ClipRect(
                  child: Image(
                    image: widget.page.image,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void _reportScale() {
    final scale = _transformationController.value.getMaxScaleOnAxis().clamp(
      _minScale,
      _maxScale,
    );
    if ((scale - _displayScale).abs() >= 0.01) {
      setState(() => _displayScale = scale);
      widget.onScaleChanged(scale);
    }
  }

  void _applyScale(double requestedScale, Offset focalPoint) {
    final scale = requestedScale.clamp(_minScale, _maxScale);
    if (scale <= _minScale + 0.01) {
      _reset();
      return;
    }
    final matrix = Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(
      focalPoint.dx * (1 - scale),
      focalPoint.dy * (1 - scale),
      0,
    );
    _transformationController.value = matrix;
    setState(() => _displayScale = scale);
    widget.onScaleChanged(scale);
  }

  void _reset({bool notify = true}) {
    _transformationController.value = Matrix4.identity();
    _doubleTapPosition = null;
    _displayScale = _minScale;
    if (notify) {
      widget.onScaleChanged(_minScale);
    }
  }
}

class _PdfPageToolbar extends StatelessWidget {
  const _PdfPageToolbar({
    required this.pageIndex,
    required this.pageCount,
    required this.scale,
    required this.onPrevious,
    required this.onNext,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onZoomIn,
  });

  final int pageIndex;
  final int pageCount;
  final double scale;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onZoomOut;
  final VoidCallback? onResetZoom;
  final VoidCallback? onZoomIn;

  @override
  Widget build(BuildContext context) => Material(
    color: BafColors.card,
    child: Container(
      height: 58,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BafColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final buttonWidth = compact ? 36.0 : 42.0;
          return Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _ToolbarIconButton(
                      key: const Key('pdf-preview-previous-page'),
                      tooltip: 'Previous page',
                      icon: Icons.chevron_left_rounded,
                      onPressed: onPrevious,
                      width: buttonWidth,
                    ),
                    SizedBox(
                      width: compact ? 44 : 64,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${pageIndex + 1} / $pageCount',
                          key: const Key('pdf-preview-page-indicator'),
                          style: const TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    _ToolbarIconButton(
                      key: const Key('pdf-preview-next-page'),
                      tooltip: 'Next page',
                      icon: Icons.chevron_right_rounded,
                      onPressed: onNext,
                      width: buttonWidth,
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, color: BafColors.border),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _ToolbarIconButton(
                      key: const Key('pdf-preview-zoom-out'),
                      tooltip: 'Zoom out',
                      icon: Icons.zoom_out_rounded,
                      onPressed: onZoomOut,
                      width: buttonWidth,
                    ),
                    _ToolbarIconButton(
                      key: const Key('pdf-preview-fit-page'),
                      tooltip: 'Fit page',
                      icon: Icons.fit_screen_rounded,
                      onPressed: onResetZoom,
                      width: buttonWidth,
                    ),
                    _ToolbarIconButton(
                      key: const Key('pdf-preview-zoom-in'),
                      tooltip: 'Zoom in',
                      icon: Icons.zoom_in_rounded,
                      onPressed: onZoomIn,
                      width: buttonWidth,
                    ),
                    if (!compact)
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${(scale * 100).round()}%',
                          key: const Key('pdf-preview-scale-indicator'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.width,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double width;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: BoxConstraints.tightFor(width: width, height: 48),
    iconSize: 21,
    style: IconButton.styleFrom(
      foregroundColor: BafColors.graphiteSoft,
      disabledForegroundColor: BafColors.textTertiary.withValues(alpha: 0.45),
      backgroundColor: Colors.transparent,
      disabledBackgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      minimumSize: Size(width, 48),
    ),
    icon: Icon(icon),
  );
}

class _PdfPreviewLoading extends StatelessWidget {
  const _PdfPreviewLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircularProgressIndicator(),
        SizedBox(height: BafSpacing.md),
        Text(
          'Preparing report preview',
          style: TextStyle(
            color: BafColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
