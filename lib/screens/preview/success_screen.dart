import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/template_model.dart';
import '../../models/template_element.dart';
import '../../models/page_model.dart';
import '../../models/kankotri_data.dart';
import '../../models/user_design.dart';
import '../../providers/designs_provider.dart';
import 'widgets/preview_page.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/top_notification.dart';
import '../../services/interaction_service.dart';
import '../../utils/image_resolver.dart';

class SuccessScreen extends StatefulWidget {
  final TemplateModel template;
  final KankotriData data;
  final int previewPageIndex;
  final String designId;
  final List<bool>? visiblePages;
  final List<PageModel>? pages;

  const SuccessScreen({
    super.key,
    required this.template,
    required this.data,
    required this.previewPageIndex,
    required this.designId,
    this.visiblePages,
    this.pages,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  bool isSaving = true;
  String? savedPdfPath;
  String? pdfDisplayName;
  String? saveError;
  double saveProgress = 0.0;
  String saveStatus = '';

  late final List<GlobalKey> pageKeys;
  late final List<Widget> pages;
  late final List<PageModel> pagesList;

  @override
  void initState() {
    super.initState();
    pagesList = widget.pages ?? [];
    final elementsToRender = widget.data.customElements ?? [];
    final total = pagesList.isNotEmpty ? pagesList.length : widget.template.totalPages;

    pageKeys = List.generate(total, (_) => GlobalKey());
    pages = List.generate(total, (index) {
      final String bgUrl = index < pagesList.length
          ? pagesList[index].backgroundImage
          : widget.template.thumbnail;
      final double width = index < pagesList.length ? pagesList[index].width : 1080.0;
      final double height = index < pagesList.length ? pagesList[index].height : 1920.0;

      return PreviewPage(
        backgroundImage: bgUrl,
        elements: elementsToRender,
        pageIndex: index,
        activeLanguage: widget.data.activeLanguage,
        canvasWidth: width,
        canvasHeight: height,
      );
    });

    _startSavingProcess(elementsToRender);
  }

  List<int> get _visiblePageIndices {
    final indices = <int>[];
    for (int i = 0; i < pages.length; i++) {
      if (widget.visiblePages == null || widget.visiblePages![i]) {
        indices.add(i);
      }
    }
    return indices;
  }

  String _defaultPdfBaseName() {
    final groom = widget.data.groomName.trim();
    final bride = widget.data.brideName.trim();
    if (groom.isNotEmpty && bride.isNotEmpty) {
      return _sanitizeFileName('${groom}_${bride}_Invitation');
    }
    final title = widget.template.title.trim();
    if (title.isNotEmpty) {
      return _sanitizeFileName(title);
    }
    return 'Invitation_${widget.designId}';
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*\n\r\t]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^\.+'), '')
        .trim();
  }

  Future<Directory> _getSaveDirectory() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      final folder = Directory('${downloads.path}/Amantran');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      return folder;
    }
    return getApplicationDocumentsDirectory();
  }

  void _updateSaveStatus(String status, double progress) {
    if (!mounted) return;
    setState(() {
      saveStatus = status;
      saveProgress = progress;
    });
  }

  Future<Uint8List?> capture(GlobalKey key) async {
    try {
      final context = key.currentContext;
      if (context == null) return null;
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture Error: $e");
      return null;
    }
  }

  Future<void> _startSavingProcess(List<TemplateElement> elementsToRender) async {
    final lang = context.read<LanguageProvider>();
    _updateSaveStatus(lang.finalizingDesign, 0.05);
    final baseName = _defaultPdfBaseName();

    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 200));

      final visibleIndices = _visiblePageIndices;
      if (visibleIndices.isEmpty) {
        throw Exception('No visible pages to save');
      }

      // Precache backgrounds to ensure they load instantly
      try {
        await Future.wait(visibleIndices.map((pageIndex) {
          final String bgUrl = pageIndex < pagesList.length
              ? pagesList[pageIndex].backgroundImage
              : widget.template.thumbnail;
          if (bgUrl.isEmpty) return Future.value();
          final imgProvider = isNetworkImage(bgUrl)
              ? NetworkImage(resolveImageUrl(bgUrl))
              : AssetImage(cleanAssetPath(bgUrl)) as ImageProvider;
          return precacheImage(imgProvider, context);
        }));
      } catch (e) {
        debugPrint("Precache background error: $e");
      }

      // Wait for the widgets to settle with the cached images
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 150));

      _updateSaveStatus(lang.finalizingDesign, 0.3);

      // Capture all pages concurrently in parallel
      final capturedBytesList = await Future.wait(
        visibleIndices.map((pageIndex) => capture(pageKeys[pageIndex])),
      );

      final pdf = pw.Document();
      final totalVisible = visibleIndices.length;

      for (int step = 0; step < totalVisible; step++) {
        final pageIndex = visibleIndices[step];
        _updateSaveStatus(
          lang.savingPage(step + 1, totalVisible),
          0.3 + (0.5 * (step / totalVisible)),
        );

        final bytes = capturedBytesList[step];
        if (bytes == null) {
          throw Exception('Failed to capture page ${pageIndex + 1}');
        }

        final image = pw.MemoryImage(bytes);
        final pageMapElements = elementsToRender
            .where((e) =>
                e.pageIndex == pageIndex &&
                e.mapUrl != null &&
                e.mapUrl!.isNotEmpty)
            .toList();

        final double width =
            pageIndex < pagesList.length ? pagesList[pageIndex].width : 1080.0;
        final double height =
            pageIndex < pagesList.length ? pagesList[pageIndex].height : 1920.0;

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

      _updateSaveStatus(lang.saving, 0.85);

      final dir = await _getSaveDirectory();
      final path = '${dir.path}/$baseName.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      savedPdfPath = path;
      pdfDisplayName = baseName;
      saveError = null;

      debugPrint("PDF Saved at: $path");
      InteractionService.logInteraction(
        type: 'download_pdf',
        description: 'Successfully generated and downloaded invitation PDF',
        details: {
          'designId': widget.designId,
          'pdfPath': path,
          'fileName': '$baseName.pdf',
        },
      );
    } catch (e) {
      debugPrint("Error generating PDF: $e");
      saveError = lang.saveFailed;
    }

    if (!mounted) return;
    context.read<DesignsProvider>().saveCompleted(UserDesign(
          id: widget.designId,
          template: widget.template,
          elements: elementsToRender,
          updatedAt: DateTime.now(),
          isDraft: false,
          pdfName: baseName,
        ));

    if (mounted) {
      setState(() {
        isSaving = false;
        saveProgress = saveError == null ? 1.0 : 0.0;
      });

      if (savedPdfPath != null) {
        TopNotification.show(
          context,
          message: lang.downloadComplete,
          type: NotificationType.success,
        );
      } else if (saveError != null) {
        TopNotification.show(
          context,
          message: saveError!,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _showRenameDialog() async {
    final lang = context.read<LanguageProvider>();
    final controller = TextEditingController(text: pdfDisplayName ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.renamePdf),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: lang.fileName,
            hintText: 'My_Invitation',
            suffixText: '.pdf',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.cancel),
          ),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(ctx, trimmed);
              }
            },
            child: Text(lang.rename),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await _renamePdfFile(newName);
    }
  }

  Future<void> _renamePdfFile(String newBaseName) async {
    if (savedPdfPath == null) return;

    final sanitized = _sanitizeFileName(newBaseName);
    if (sanitized.isEmpty) return;

    try {
      final oldFile = File(savedPdfPath!);
      if (!await oldFile.exists()) return;

      final dir = oldFile.parent;
      var targetPath = '${dir.path}/$sanitized.pdf';

      if (targetPath != savedPdfPath) {
        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          targetPath = '${dir.path}/${sanitized}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        }
        await oldFile.rename(targetPath);
      }

      if (!mounted) return;
      setState(() {
        savedPdfPath = targetPath;
        pdfDisplayName = sanitized;
      });

      context.read<DesignsProvider>().saveCompleted(UserDesign(
            id: widget.designId,
            template: widget.template,
            elements: widget.data.customElements ?? [],
            updatedAt: DateTime.now(),
            isDraft: false,
            pdfName: sanitized,
          ));

      TopNotification.show(
        context,
        message: '$sanitized.pdf',
        type: NotificationType.success,
      );
    } catch (e) {
      debugPrint('Rename error: $e');
      if (mounted) {
        TopNotification.show(
          context,
          message: context.read<LanguageProvider>().saveFailed,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _sharePdf(String platform) async {
    if (savedPdfPath == null) return;

    bool sharedDirectly = false;

    if (Platform.isAndroid && platform != 'Other') {
      String? packageName;
      if (platform == 'WhatsApp') {
        packageName = 'com.whatsapp';
      } else if (platform == 'Gmail') {
        packageName = 'com.google.android.gm';
      } else if (platform == 'Messages') {
        packageName = 'com.google.android.apps.messaging';
      }

      if (packageName != null) {
        try {
          final fileName = savedPdfPath!.split('/').last;
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          if (await tempFile.exists()) {
            try {
              await tempFile.delete();
            } catch (_) {}
          }
          await File(savedPdfPath!).copy(tempFile.path);

          // Get user's email for Gmail FROM field
          final userProvider = context.read<UserProvider>();
          final userEmail = userProvider.email;

          const channel = MethodChannel('com.olive.amantran/apk_share');
          final bool? success = await channel.invokeMethod<bool>(
            'shareFileToPackage',
            {
              'filePath': tempFile.path,
              'packageName': packageName,
              'userEmail': userEmail,
            },
          );
          sharedDirectly = success ?? false;
        } catch (e) {
          debugPrint('Direct share to $packageName failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Direct share failed: $e\nMake sure to COLD RUN/REBUILD the app if you just changed native code.'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }

    // For "Other" or if direct share failed, show Android Share Sheet
    if (!sharedDirectly) {
      await Share.shareXFiles(
        [XFile(savedPdfPath!)],
        text: 'Check out my Wedding Invitation!',
      );
    }

    InteractionService.logInteraction(
      type: 'share_invitation',
      description: 'Shared invitation via $platform',
      details: {'designId': widget.designId, 'platform': platform},
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF5F6), Colors.white],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (isSaving)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          lang.saving,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: Stack(
                  children: [
                    if (isSaving)
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
                                children: List.generate(pages.length, (index) {
                                  final double width = index < pagesList.length
                                      ? pagesList[index].width
                                      : 1080.0;
                                  final double height = index < pagesList.length
                                      ? pagesList[index].height
                                      : 1920.0;

                                  return RepaintBoundary(
                                    key: pageKeys[index],
                                    child: SizedBox(
                                      width: width,
                                      height: height,
                                      child: pages[index],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),

                    Positioned.fill(
                      child: isSaving ? _buildSavingState(lang) : _buildCompleteState(lang),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavingState(LanguageProvider lang) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 360,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(15, -15),
                child: Transform.rotate(
                  angle: 0.05,
                  child: _mockCard(Colors.white, showContent: true),
                ),
              ),
              Transform.translate(
                offset: const Offset(-15, -5),
                child: Transform.rotate(
                  angle: -0.05,
                  child: _mockCard(Colors.white, showContent: true),
                ),
              ),
              _mockCard(Colors.white, showContent: true),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          saveStatus.isNotEmpty ? saveStatus : lang.finalizingDesign,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF94C66),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          lang.savedToDownloads,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: saveProgress > 0 ? saveProgress : null,
              minHeight: 6,
              backgroundColor: const Color(0xFFF94C66).withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF94C66)),
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF94C66).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF94C66),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: Text(
                  lang.cancel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteState(LanguageProvider lang) {
    final hasPdf = savedPdfPath != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportH = constraints.maxHeight;
        final isSmall = viewportH < 700;
        final cardHeight = isSmall ? viewportH * 0.40 : 380.0;

    return Stack(
      children: [
        Positioned(top: 20, left: 20, child: _fireworkIcon()),
        Positioned(top: 40, right: 40, child: _decorativeLine(const Color(0xFFF94C66), -0.5)),
        Positioned(top: 120, right: 25, child: _starIcon()),
        Positioned(top: 160, left: 30, child: _decorativeLine(const Color(0xFFF94C66), 0.5)),
        Positioned(top: 250, left: 20, child: _starIcon()),
        Positioned(top: 260, right: 10, child: _fireworkIcon()),
        Positioned(top: 320, right: 30, child: _decorativeLine(const Color(0xFFF94C66), -0.8)),
        Positioned(top: 340, left: 40, child: _decorativeLine(const Color(0xFFF94C66), 0.8)),

        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewportH),
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            SizedBox(
              height: cardHeight,
              child: _mockCard(Colors.white, showContent: true),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasPdf ? Icons.check_circle : Icons.error_outline,
                  color: hasPdf ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  hasPdf ? lang.downloadComplete : (saveError ?? lang.saveFailed),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (hasPdf && pdfDisplayName != null) ...[
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Color(0xFFF94C66), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$pdfDisplayName.pdf',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: _showRenameDialog,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: const Color(0xFFF94C66),
                      tooltip: lang.renamePdf,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
            ],
            if (hasPdf)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      OpenFile.open(savedPdfPath!);
                      InteractionService.logInteraction(
                        type: 'open_pdf',
                        description: 'Opened generated invitation PDF file',
                        details: {'designId': widget.designId},
                      );
                    },
                    icon: const Icon(Icons.file_open, size: 16, color: Color(0xFFF94C66)),
                    label: Text(lang.openPdf, style: const TextStyle(color: Color(0xFFF94C66))),
                  ),
                  TextButton.icon(
                    onPressed: _showRenameDialog,
                    icon: const Icon(Icons.drive_file_rename_outline, size: 16, color: Color(0xFFF94C66)),
                    label: Text(lang.rename, style: const TextStyle(color: Color(0xFFF94C66))),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      isSaving = true;
                      saveError = null;
                      saveProgress = 0.0;
                      saveStatus = '';
                    });
                    _startSavingProcess(widget.data.customElements ?? []);
                  },
                  icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFF94C66)),
                  label: Text(lang.retry, style: const TextStyle(color: Color(0xFFF94C66))),
                ),
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF94C66).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF94C66),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(lang.home, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF94C66),
                        side: const BorderSide(color: Color(0xFFF94C66)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(lang.edit, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            if (hasPdf) ...[
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade200, indent: 40)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      lang.shareWith,
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200, endIndent: 40)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialItem(
                    onTap: () => _sharePdf('WhatsApp'),
                    logo: _outlinedContainer(
                      color: const Color(0xFF25D366),
                      child: SvgPicture.string(
                        '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="#25D366" d="M12.004 2c-5.523 0-10 4.477-10 10c0 1.767.459 3.427 1.263 4.873L2 22l5.247-1.377A9.947 9.947 0 0 0 12.004 22c5.523 0 10-4.477 10-10s-4.477-10-10-10zm.004 18.231c-1.63 0-3.167-.423-4.512-1.164l-.323-.178l-3.102.813l.827-3.023l-.196-.312c-.812-1.294-1.264-2.821-1.264-4.43c0-4.542 3.695-8.237 8.237-8.237s8.237 3.695 8.237 8.237s-3.696 8.237-8.237 8.237zm4.515-6.185c-.247-.124-1.464-.722-1.692-.804s-.392-.124-.556.124c-.165.247-.638.804-.784.969c-.144.165-.29.185-.536.062c-.247-.124-1.043-.385-1.986-1.227c-.733-.654-1.228-1.462-1.372-1.71c-.144-.247-.015-.381.109-.504c.112-.111.247-.289.37-.433c.124-.144.165-.247.247-.412c.082-.165.042-.31-.02-.433c-.062-.124-.556-1.341-.763-1.835c-.201-.486-.403-.42-.556-.427c-.144-.007-.31-.008-.474-.008c-.165 0-.433.062-.659.31c-.227.247-.866.845-.866 2.062c0 1.217.886 2.392 1.01 2.557c.124.165 1.743 2.661 4.221 3.732c.59.255 1.05.407 1.41.521c.594.188 1.135.161 1.562.097c.477-.071 1.464-.598 1.67-.1.206-.577.206-1.072.144-1.175c-.062-.103-.227-.165-.474-.289z"/></svg>''',
                        width: 28,
                        height: 28,
                      ),
                    ),
                    label: "WhatsApp",
                  ),
                  const SizedBox(width: 20),
                  _buildSocialItem(
                    onTap: () => _sharePdf('Gmail'),
                    logo: _outlinedContainer(
                      color: Colors.red,
                      child: const Icon(Icons.mail, color: Colors.red, size: 26),
                    ),
                    label: "Gmail",
                  ),
                  const SizedBox(width: 20),
                  _buildSocialItem(
                    onTap: () => _sharePdf('Messages'),
                    logo: _outlinedContainer(
                      color: Colors.blue,
                      child: const Icon(Icons.message, color: Colors.blue, size: 26),
                    ),
                    label: "Messages",
                  ),
                  const SizedBox(width: 20),
                  _buildSocialItem(
                    onTap: () => _sharePdf('Other'),
                    logo: _outlinedContainer(
                      color: Colors.black,
                      child: const Icon(Icons.grid_view_rounded, color: Colors.black87, size: 24),
                    ),
                    label: "More",
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
          ),
        ),
      ],
    );
      },
    );
  }

  Widget _outlinedContainer({required Color color, required Widget child}) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _buildSocialItem({required VoidCallback onTap, required Widget logo, required String label}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _mockCard(Color color, {bool showContent = false}) {
    return AspectRatio(
      aspectRatio: 0.65,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: showContent
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: IgnorePointer(
                  child: pages[widget.previewPageIndex],
                ),
              )
            : null,
      ),
    );
  }

  Widget _starIcon() {
    return Transform.rotate(
      angle: 0.5,
      child: const Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
    );
  }

  Widget _decorativeLine(Color color, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 12,
        height: 3,
        decoration: BoxDecoration(
          color: color.withOpacity(0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _fireworkIcon() {
    return Icon(Icons.auto_awesome, color: const Color(0xFFF94C66).withOpacity(0.2), size: 40);
  }
}
