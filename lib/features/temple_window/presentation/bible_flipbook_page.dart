import 'dart:async';

import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_flip/page_flip.dart';
import 'package:pdfx/pdfx.dart';

class BibleFlipbookPage extends StatefulWidget {
  const BibleFlipbookPage({super.key});

  @override
  State<BibleFlipbookPage> createState() => _BibleFlipbookPageState();
}

class _BibleFlipbookPageState extends State<BibleFlipbookPage> {
  // Page flip controller
  final PageFlipController _flipController = PageFlipController();

  // PDF rendering
  PdfDocument? _pdfDocument;
  final Map<int, Uint8List> _pageImageCache = {};
  // Render queue to avoid concurrent platform calls
  Future<void> _renderQueue = Future.value();

  int _currentPage = 1; // 1-based for UI
  int _totalPages = 0;
  bool _showControls = true;
  bool _isLoading = true;
  bool _pdfSupported = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Defer platform-channel usage to after first frame for safety
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPdf();
    });
  }

  Future<void> _openPdf() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _pdfSupported = true;
    });
    try {
      final supported = await hasPdfSupport();
      if (!supported) {
        if (!mounted) return;
        setState(() {
          _pdfSupported = false;
          _isLoading = false;
        });
        return;
      }

      PdfDocument? doc;
      try {
        // First try opening by asset path
        doc = await PdfDocument.openAsset('assets/temple/bible.pdf');
      } catch (e) {
        // Fallback: load bytes and open from memory (may work in some contexts)
        debugPrint('Pdf openAsset failed, trying openData: $e');
        final bytes = await rootBundle.load('assets/temple/bible.pdf');
        doc = await PdfDocument.openData(bytes.buffer.asUint8List());
      }

      if (!mounted) return;
  final nonNullDoc = doc;
      setState(() {
        _pdfDocument = nonNullDoc;
        _totalPages = nonNullDoc.pagesCount;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to open PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      HapticFeedback.selectionClick();
      _flipController.previousPage();
    }
  }

  void _goToNextPage() {
    if (_totalPages > 0 && _currentPage < _totalPages) {
      HapticFeedback.selectionClick();
      _flipController.nextPage();
    }
  }

  void _jumpToPage(int page) {
    if (_totalPages == 0) return;
  final clamped = page.clamp(1, _totalPages).toInt();
    if (clamped != _currentPage) {
      // Update UI immediately and then command the flip controller.
      setState(() => _currentPage = clamped);
      _flipController.goToPage(clamped - 1); // controller is 0-based
    }
  }

  Future<void> _showGotoDialog() async {
    if (_totalPages == 0) return;
    final controller = TextEditingController(text: _currentPage.toString());
    final page = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Go to page', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            style: const TextStyle(color: Colors.white),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '1 - $_totalPages',
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
            ),
            onSubmitted: (v) {
              final parsed = int.tryParse(v.trim());
              if (parsed != null) {
                Navigator.of(context).pop(parsed);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed != null) {
                  Navigator.of(context).pop(parsed);
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
    if (page != null) {
      // Clamp to valid range and jump.
      _jumpToPage(page);
    }
  }

  Future<Uint8List> _renderPageBytes(int pageNumber, {double? targetWidth}) async {
    // Return from cache if available
    if (_pageImageCache.containsKey(pageNumber)) return _pageImageCache[pageNumber]!;

    final completer = Completer<Uint8List>();
    _renderQueue = _renderQueue.then((_) async {
      final doc = _pdfDocument!;
      final page = await doc.getPage(pageNumber);
      try {
        // Maintain aspect ratio based on original page size
        final originalW = page.width;
        final originalH = page.height;
        final width = targetWidth ?? originalW;
        final height = originalH * (width / originalW);
        final PdfPageImage? img = await page.render(
          width: width,
          height: height,
          format: PdfPageImageFormat.png,
          // Keep original light background instead of forcing dark
          backgroundColor: '#FFFFFF',
          quality: 100,
        );
        if (img == null) throw Exception('Render returned null for page $pageNumber');
        final bytes = img.bytes;
        _pageImageCache[pageNumber] = bytes;
        if (!completer.isCompleted) completer.complete(bytes);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      } finally {
        await page.close();
      }
    });

    return completer.future;
  }

  Widget _buildPage(int indexZeroBased) {
    final pageNumber = indexZeroBased + 1;
    return LayoutBuilder(
      builder: (context, constraints) {
  final targetWidth = constraints.maxWidth.clamp(200, 4096).toDouble();
        return FutureBuilder<Uint8List>(
          future: _pdfDocument == null
              ? Future<Uint8List>.error('Document not loaded')
              : _renderPageBytes(pageNumber, targetWidth: targetWidth),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Text(
                  'Failed to load page $pageNumber',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }
            return Container(
              // Transparent so the image shows true PDF colors
              color: Colors.transparent,
              alignment: Alignment.center,
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 6),
          child: BackNavButton(),
        ),
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Holy Bible', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            children: [
              // Flipbook Viewer as the base
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (!_pdfSupported)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.white70, size: 42),
                        const SizedBox(height: 12),
                        const Text(
                          'PDF rendering is not supported on this platform.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _openPdf,
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _openPdf,
                          child: const Text('Try again', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: PageFlipWidget(
                    controller: _flipController,
                    // White background to match paper
                    backgroundColor: Colors.white,
                    duration: const Duration(milliseconds: 1100),
                    initialIndex: ((_currentPage - 1).clamp(0, _totalPages > 0 ? _totalPages - 1 : 0)).toInt(),
                    onPageFlipped: (index) {
                      // index is 0-based
                      setState(() => _currentPage = (index + 1).clamp(1, _totalPages));
                    },
                    children: List.generate(
                      _totalPages,
                      (i) => _buildPage(i),
                    ),
                  ),
                ),

              // Left and right tap zones to flip pages like a book
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final edgeWidth = constraints.maxWidth * 0.24; // 24% left/right edges
                    return Row(
                      children: [
                        SizedBox(
                          width: edgeWidth,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _goToPreviousPage,
                          ),
                        ),
                        // Center area passes gestures through to the PDF (scroll/zoom)
                        Expanded(
                          child: Container(color: Colors.transparent),
                        ),
                        SizedBox(
                          width: edgeWidth,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _goToNextPage,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Top center page indicator (fades with controls)
              if (_showControls)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _totalPages > 0 ? 'Page $_currentPage / $_totalPages' : 'Loading…',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),

              // Bottom controls with slider and prev/next
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xA6000000),
                        border: Border(
                          top: BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                            color: Colors.white,
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Previous page',
                          ),
                          Expanded(
                            child: Center(
                              child: _totalPages > 0
                                  ? IconButton(
                                      onPressed: _showGotoDialog,
                                      color: Colors.white,
                                      icon: const Icon(Icons.keyboard),
                                      tooltip: 'Go to page…',
                                    )
                                  : const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                            ),
                          ),
                          IconButton(
                            onPressed: (_totalPages > 0 && _currentPage < _totalPages) ? _goToNextPage : null,
                            color: Colors.white,
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Next page',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
