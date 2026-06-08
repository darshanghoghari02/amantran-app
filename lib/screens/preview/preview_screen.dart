import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../models/template_model.dart';
import '../../models/template_element.dart';
import '../../models/page_model.dart';
import '../../models/kankotri_data.dart';
import '../../models/user_design.dart';
import '../../providers/designs_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/interaction_service.dart';

import 'widgets/preview_page.dart';
import 'success_screen.dart';
import '../../widgets/subscription_bottom_sheet.dart';

class PreviewScreen extends StatefulWidget {
  final KankotriData data;
  final TemplateModel template;
  final String designId;
  final List<PageModel>? pages;

  const PreviewScreen({
    super.key,
    required this.data,
    required this.template,
    required this.designId,
    this.pages,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final PageController controller = PageController();

  late final List<GlobalKey> pageKeys;
  late final List<bool> visiblePages;
  late final List<Widget> pages;
  late final List<TemplateElement> elementsToRender;
  late final List<PageModel> _pagesList;

  @override
  void initState() {
    super.initState();

    _pagesList = widget.pages ?? [];
    final total = _pagesList.isNotEmpty ? _pagesList.length : widget.template.totalPages;
    pageKeys = List.generate(total, (_) => GlobalKey());

    elementsToRender = widget.data.customElements ?? [];

    // Load visible pages based on elements visibility. If all elements on a page are invisible, the page is invisible.
    visiblePages = List.generate(total, (index) {
      final pageElements = elementsToRender.where((e) => e.pageIndex == index).toList();
      if (pageElements.isNotEmpty && pageElements.every((e) => !e.isVisible)) {
        return false;
      }
      return true;
    });

    pages = List.generate(total, (index) {
      final String bgUrl = index < _pagesList.length 
          ? _pagesList[index].backgroundImage 
          : widget.template.thumbnail;
      final double width = index < _pagesList.length ? _pagesList[index].width : 1080.0;
      final double height = index < _pagesList.length ? _pagesList[index].height : 1920.0;

      return PreviewPage(
        backgroundImage: bgUrl,
        elements: elementsToRender,
        pageIndex: index,
        activeLanguage: widget.data.activeLanguage,
        canvasWidth: width,
        canvasHeight: height,
      );
    });

    InteractionService.logInteraction(
      type: 'preview_design',
      description: 'Opened preview screen for design',
      details: {'designId': widget.designId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Preview",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const Spacer(),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF94C66),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 LIST OF PAGES
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  if (!visiblePages[index]) return const SizedBox.shrink();

                  final double width = index < _pagesList.length ? _pagesList[index].width : 1080.0;
                  final double height = index < _pagesList.length ? _pagesList[index].height : 1920.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Page header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Page ${index + 1}/${pages.length}",
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Delete Page?"),
                                    content: const Text("Are you sure you want to delete this page?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text("Cancel"),
                                      ),
                                       TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          setState(() {
                                            visiblePages[index] = false;
                                            // Set all elements on this page as invisible
                                            for (var e in elementsToRender) {
                                              if (e.pageIndex == index) {
                                                e.isVisible = false;
                                              }
                                            }
                                          });
                                          // Save draft to database immediately
                                          context.read<DesignsProvider>().saveDraft(UserDesign(
                                                id: widget.designId,
                                                template: widget.template,
                                                elements: elementsToRender,
                                                updatedAt: DateTime.now(),
                                              ));
                                          InteractionService.logInteraction(
                                            type: 'delete_page',
                                            description: 'Deleted page ${index + 1} of invitation design',
                                            details: {
                                              'designId': widget.designId,
                                              'pageIndex': index,
                                              'pageNumber': index + 1,
                                            },
                                          );
                                        },
                                        child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Page Render
                        RepaintBoundary(
                          key: pageKeys[index],
                          child: AspectRatio(
                            aspectRatio: width / height,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: pages[index],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // 🔹 STICKY BOTTOM DOWNLOAD BUTTON
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              final subProvider = context.read<SubscriptionProvider>();
              final isUnlocked = subProvider.isTemplateUnlocked(widget.template);
              if (widget.template.isPremium && !isUnlocked) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => SubscriptionBottomSheet(template: widget.template),
                );
                return;
              }

              int firstVisible = visiblePages.indexWhere((v) => v);
              if (firstVisible == -1) firstVisible = 0;
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SuccessScreen(
                    template: widget.template,
                    data: widget.data,
                    previewPageIndex: firstVisible,
                    designId: widget.designId,
                    visiblePages: visiblePages,
                    pages: _pagesList,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text("Download", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF94C66),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 4,
            ),
          ),
        ),
      ),
    );
  }
}
