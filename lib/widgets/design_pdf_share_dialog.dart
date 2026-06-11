import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/user_design.dart';
import '../models/page_model.dart';
import '../providers/app_data_provider.dart';
import '../providers/language_provider.dart';
import '../screens/preview/widgets/preview_page.dart';
import '../utils/image_resolver.dart';

class DesignPdfShareDialog extends StatefulWidget {
  final UserDesign design;

  const DesignPdfShareDialog({super.key, required this.design});

  @override
  State<DesignPdfShareDialog> createState() => _DesignPdfShareDialogState();
}

class _DesignPdfShareDialogState extends State<DesignPdfShareDialog> {
  bool _isLoading = true;
  String _statusText = 'Loading design pages...';
  String? _errorMessage;
  List<PageModel> _pages = [];
  List<GlobalKey> _pageKeys = [];

  @override
  void initState() {
    super.initState();
    _fetchPagesAndGeneratePdf();
  }

  Future<void> _fetchPagesAndGeneratePdf() async {
    try {
      final appData = context.read<AppDataProvider>();

      setState(() {
        _statusText = 'Loading invitation pages...';
      });

      _pages = await appData.getTemplatePagesCachedFirst(widget.design.template.id);
      
      if (_pages.isEmpty) {
        throw Exception('No pages found for this template');
      }

      _pageKeys = List.generate(_pages.length, (_) => GlobalKey());

      setState(() {
        _statusText = 'Generating high-quality PDF...';
      });

      // Precache backgrounds to ensure they load instantly
      try {
        await Future.wait(_pages.map((page) {
          if (page.backgroundImage.isEmpty) return Future.value();
          final imgProvider = isNetworkImage(page.backgroundImage)
              ? NetworkImage(resolveImageUrl(page.backgroundImage))
              : AssetImage(cleanAssetPath(page.backgroundImage)) as ImageProvider;
          return precacheImage(imgProvider, context);
        }));
      } catch (e) {
        debugPrint("Precache background error: $e");
      }

      // Wait for the widgets to settle with the cached images (reduced delay)
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 150));

      final pdf = pw.Document();

      for (int i = 0; i < _pages.length; i++) {
        final bytes = await _capture(_pageKeys[i]);
        if (bytes == null) {
          throw Exception('Failed to capture page ${i + 1}');
        }

        final image = pw.MemoryImage(bytes);
        final pageMapElements = widget.design.elements
            .where((e) =>
                e.pageIndex == i &&
                e.mapUrl != null &&
                e.mapUrl!.isNotEmpty)
            .toList();

        final double width = _pages[i].width;
        final double height = _pages[i].height;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(width, height),
            build: (pw.Context context) {
              if (pageMapElements.isEmpty) {
                return pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Image(image, fit: pw.BoxFit.cover),
                );
              }

              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Stack(
                  children: [
                    pw.Image(image, fit: pw.BoxFit.cover),
                    ...pageMapElements.map((e) {
                      return pw.Positioned(
                        left: e.x,
                        top: e.y,
                        child: pw.UrlLink(
                          destination: e.mapUrl!,
                          child: pw.SizedBox(
                            width: e.width,
                            height: e.height,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        );
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = _getPdfFileName();
      final tempPath = '${tempDir.path}/$fileName.pdf';
      final file = File(tempPath);
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;

      // Close the dialog and trigger sharing
      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(tempPath)],
        text: 'Check out my invitation: ${widget.design.template.title}',
      );
    } catch (e) {
      debugPrint('Error sharing design PDF: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().contains('No pages found')
              ? 'Could not load invitation pages.'
              : 'Failed to generate PDF. Please try again.';
        });
      }
    }
  }

  Future<Uint8List?> _capture(GlobalKey key) async {
    try {
      final context = key.currentContext;
      if (context == null) return null;
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture Error: $e");
      return null;
    }
  }

  String _getPdfFileName() {
    String groom = '';
    String bride = '';
    
    try {
      final gEl = widget.design.elements.firstWhere(
        (e) => e.id == 'p1_groom' || e.id.startsWith('p1_groom_'),
      );
      groom = gEl.contentMap['en'] ?? gEl.content;
    } catch (_) {}

    try {
      final bEl = widget.design.elements.firstWhere(
        (e) => e.id == 'p1_bride' || e.id.startsWith('p1_bride_'),
      );
      bride = bEl.contentMap['en'] ?? bEl.content;
    } catch (_) {}

    // Clean up names
    groom = groom.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    bride = bride.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();

    if (groom.isNotEmpty && bride.isNotEmpty) {
      return _sanitizeFileName('${groom}_${bride}_Invitation');
    }

    final title = widget.design.template.title.trim();
    if (title.isNotEmpty) {
      return _sanitizeFileName(title);
    }
    return 'Invitation_${widget.design.id}';
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*\n\r\t]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^\.+'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = context.watch<LanguageProvider>().activeInvitationLanguage;

    return Stack(
      children: [
        // Invisible offscreen RepaintBoundaries
        if (_pages.isNotEmpty && _pageKeys.length == _pages.length)
          Positioned(
            left: -9999,
            top: -9999,
            child: ClipRect(
              child: SizedBox(
                width: 1,
                height: 1,
                child: OverflowBox(
                  minWidth: 0.0,
                  minHeight: 0.0,
                  maxWidth: 5000.0,
                  maxHeight: 25000.0,
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_pages.length, (index) {
                      final double width = _pages[index].width;
                      final double height = _pages[index].height;

                      return RepaintBoundary(
                        key: _pageKeys[index],
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: PreviewPage(
                            backgroundImage: _pages[index].backgroundImage,
                            elements: widget.design.elements,
                            pageIndex: index,
                            activeLanguage: activeLang,
                            canvasWidth: width,
                            canvasHeight: height,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),

        // Beautiful centered dialog
        Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(color: Color(0xFFF94C66), strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _statusText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'Something went wrong',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF94C66),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
