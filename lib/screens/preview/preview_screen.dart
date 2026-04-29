import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/template_model.dart';
import '../../models/kankotri_data.dart';

import 'widgets/preview_page.dart';

class PreviewScreen extends StatefulWidget {
  final KankotriData data;
  final TemplateModel template;

  const PreviewScreen({
    super.key,
    required this.data,
    required this.template,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final PageController controller = PageController();

  final List<GlobalKey> pageKeys = List.generate(7, (_) => GlobalKey());

  int currentPage = 0;
  bool isGenerating = false;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();

    final elementsToRender = widget.data.customElements ?? widget.template.elements;

    pages = List.generate(7, (index) {
      return PreviewPage(
        template: widget.template,
        elements: elementsToRender,
        pageIndex: index,
        isGujarati: widget.data.isGujarati,
      );
    });
  }

  // ------------------------------------------------------------
  // 📸 SAFE CAPTURE
  // ------------------------------------------------------------
  Future<Uint8List?> capture(GlobalKey key) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final context = key.currentContext;
      if (context == null) return null;

      final boundary = context.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture Error: $e");
      return null;
    }
  }

  // ------------------------------------------------------------
  // 📄 GENERATE PDF (FIXED)
  // ------------------------------------------------------------
  Future<void> generatePdf() async {
    setState(() => isGenerating = true);

    final pdf = pw.Document();

    for (int i = 0; i < pages.length; i++) {
      await controller.animateToPage(
        i,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      await Future.delayed(const Duration(milliseconds: 600));

      final bytes = await capture(pageKeys[i]);

      if (bytes != null) {
        pdf.addPage(
          pw.Page(
            margin: pw.EdgeInsets.zero,
            build: (_) =>
                pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
          ),
        );
      }
    }

    setState(() => isGenerating = false);

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  // ------------------------------------------------------------
  // 🧩 UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Preview"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: isGenerating ? null : generatePdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔥 PAGE VIEW
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: pages.length,
                  onPageChanged: (index) {
                    setState(() => currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return Center(
                      child: RepaintBoundary(
                        key: pageKeys[index],
                        child: AspectRatio(
                          aspectRatio: 0.65, // 🔥 FIXED
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: pages[index],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ◀️ LEFT
                if (currentPage > 0)
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _nav(Icons.arrow_back, () {
                        controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }),
                    ),
                  ),

                // ▶️ RIGHT
                if (currentPage < pages.length - 1)
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _nav(Icons.arrow_forward, () {
                        controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 🔴 DOTS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: currentPage == i ? 12 : 8,
                height: currentPage == i ? 12 : 8,
                decoration: BoxDecoration(
                  color: currentPage == i ? Colors.red : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 🔴 ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final bytes = await capture(pageKeys[currentPage]);

                      if (bytes != null) {
                        await Printing.sharePdf(
                          bytes: bytes,
                          filename: "kankotri.png",
                        );
                      }
                    },
                    child: const Text("Download Page"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isGenerating ? null : generatePdf,
                    child: isGenerating
                        ? const CircularProgressIndicator()
                        : const Text("Download PDF"),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),
        ],
      ),
    );
  }

  // 🔘 NAV BUTTON
  Widget _nav(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}
