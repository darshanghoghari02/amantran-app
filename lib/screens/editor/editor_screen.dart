import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/invitation_provider.dart';
import '../../models/template_model.dart';
import '../../models/template_element.dart';
import '../../models/page_model.dart';
import '../../providers/app_data_provider.dart';
import '../../services/transliteration_engine.dart';
import 'package:http/http.dart' as http;
import '../preview/preview_screen.dart';
import '../form/form_screen.dart';
import '../../models/user_design.dart';
import '../../providers/designs_provider.dart';
import '../../services/interaction_service.dart';
import 'widgets/draggable_element.dart';
import '../../utils/image_resolver.dart';
import 'widgets/bottom_sheets.dart';
import 'widgets/transliteration_field.dart';
import '../../providers/language_provider.dart';
import '../../widgets/top_notification.dart';
import 'dart:convert';

/// Multi-page drag-and-drop editor canvas.
///
/// Supports 6 pages matching the preview structure:
/// Page 0: Ganesh & Family
/// Page 1: Bride & Groom
/// Page 2: Event Details
/// Page 3: Family Details
/// Page 4: Invitation
/// Page 5: Contact & Thanks
class EditorScreen extends StatefulWidget {
  final TemplateModel template;
  final String? designId;
  final List<TemplateElement>? initialElements;

  const EditorScreen(
      {super.key, required this.template, this.designId, this.initialElements});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String? selectedElementId;
  // Removed local isGujarati as we now use lang.activeInvitationLanguage
  int currentPage = 0;
  final PageController _pageController = PageController();
  final TransliterationEngine _engine = TransliterationEngine();

  // 🔄 UNDO / REDO
  List<List<TemplateElement>> _undoStack = [];
  List<List<TemplateElement>> _redoStack = [];
  List<TemplateElement>? _actionOriginalState;

  int get totalPages => _pages.length;
  late String _currentDesignId;
  
  bool _isLoading = true;
  List<PageModel> _pages = [];
  bool _isDiscarding = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _currentDesignId =
        widget.designId ?? DateTime.now().millisecondsSinceEpoch.toString();
        
    _initEditor();
  }

  Future<void> _initEditor() async {
    try {
      final appData = context.read<AppDataProvider>();
      _pages = await appData.getTemplatePages(widget.template.id);
      
      List<TemplateElement> elementsToLoad = [];
      
      if (widget.initialElements != null) {
        elementsToLoad = widget.initialElements!;
      } else {
        // Load default elements from all pages
        for (var page in _pages) {
          for (var el in page.elements) {
            elementsToLoad.add(el.copyWith(pageIndex: page.pageNumber - 1));
          }
        }
      }

      if (mounted) {
        await context.read<InvitationProvider>().loadNewTemplate(
              elementsToLoad,
              isNew: widget.initialElements == null,
            );
        _autoSaveDraft();
        InteractionService.logInteraction(
          type: 'customize_template',
          description: 'Started customizing template: ${widget.template.title}',
          details: {
            'designId': _currentDesignId,
            'templateId': widget.template.id,
            'templateName': widget.template.title,
          },
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading template pages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Elements for the current page only
  List<TemplateElement> currentPageElements(InvitationProvider provider) =>
      provider.elements
          .where((e) => e.pageIndex == currentPage && e.isVisible)
          .toList();

  TemplateElement? selectedElement(InvitationProvider provider) {
    if (selectedElementId == null) return null;
    try {
      return provider.elements.firstWhere((e) => e.id == selectedElementId);
    } catch (_) {
      return null;
    }
  }

  void _addNewTextField() {
    _beginAction();

    final provider = context.read<InvitationProvider>();
    final newId = 'custom_text_${DateTime.now().millisecondsSinceEpoch}';

    // Page dimensions
    final pageW = currentPage < _pages.length ? _pages[currentPage].width : 1080.0;
    final pageH = currentPage < _pages.length ? _pages[currentPage].height : 1920.0;

    // Proportional positioning
    final width = pageW * 0.7; // 70% of canvas width
    final height = pageH * 0.06; // 6% of canvas height
    final x = (pageW - width) / 2; // Center horizontally
    final y = pageH * 0.6; // 60% down the page
    final fontSize = pageH * 0.025; // Proportional font size (approx 48 for 1920 height, which is 16 * 3)

    final newElement = TemplateElement(
      id: newId,
      pageIndex: currentPage,
      type: ElementType.text,
      content: 'New Text',
      contentGujarati: 'નવો ટેક્સ્ટ',
      x: x,
      y: y,
      width: width,
      height: height,
      fontSize: fontSize,
      fontFamily: 'Montserrat',
      color: Colors.black87,
      fontWeight: FontWeight.normal,
      textAlign: TextAlign.center,
      isMovable: true,
      isResizable: true,
      isEditable: true,
      isVisible: true,
    );

    setState(() {
      final updated = List<TemplateElement>.from(provider.elements)
        ..add(newElement);
      provider.elements = updated;
      selectedElementId = newId;
    });

    provider.notifyListeners();
    InteractionService.logInteraction(
      type: 'add_text_element',
      description: 'Added a new custom text field on page $currentPage',
      details: {
        'designId': _currentDesignId,
        'pageIndex': currentPage,
        'elementId': newId,
      },
    );
    _endAction();
  }

  void _deleteElement(TemplateElement element) {
    _beginAction();

    final provider = context.read<InvitationProvider>();
    setState(() {
      if (element.id.startsWith('custom_text_')) {
        final updated = List<TemplateElement>.from(provider.elements)
          ..removeWhere((e) => e.id == element.id);
        provider.elements = updated;
      } else {
        element.isVisible = false;
      }
      selectedElementId = null;
    });

    provider.notifyListeners();
    InteractionService.logInteraction(
      type: 'delete_element',
      description: 'Deleted element: ${element.id}',
      details: {
        'designId': _currentDesignId,
        'elementId': element.id,
        'elementType': element.type.name,
      },
    );
    _endAction();
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    final lang = context.read<LanguageProvider>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.saveDraft,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1C1C)),
              ),
              const SizedBox(height: 16),
              Text(
                lang.unsavedChanges,
                style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.4),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      setState(() {
                        _isDiscarding = true;
                      });
                      
                      if (widget.initialElements == null) {
                        await context.read<DesignsProvider>().deleteDesign(_currentDesignId);
                      } else {
                        final savedId = await context.read<DesignsProvider>().saveDraft(UserDesign(
                              id: _currentDesignId,
                              template: widget.template,
                              elements: widget.initialElements!,
                              updatedAt: DateTime.now(),
                            ));
                        if (mounted) {
                          setState(() {
                            _currentDesignId = savedId;
                          });
                        }
                      }
                      
                      Navigator.pop(ctx, true);
                    },
                    style: TextButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF757575),
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: Text(
                      lang.discard,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF757575),
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: Text(
                      lang.cancel,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () async {
                      final elements = context
                          .read<InvitationProvider>()
                          .elements;
                      final savedId = await context
                          .read<DesignsProvider>()
                          .saveDraft(UserDesign(
                            id: _currentDesignId,
                            template: widget.template,
                            elements: elements,
                            updatedAt: DateTime.now(),
                          ));
                      if (mounted) {
                        setState(() {
                          _currentDesignId = savedId;
                        });
                      }
                      TopNotification.show(context,
                          message: lang.draftSaved);
                      Navigator.pop(ctx, true);
                    },
                    style: TextButton.styleFrom(
                        foregroundColor:
                            const Color(0xFFF94C66),
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: Text(
                      lang.done,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();
    final lang = context.watch<LanguageProvider>();
    final elements = provider.elements;
    return PopScope(
      canPop: _allowPop,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog(context);
        if (shouldExit && mounted) {
          setState(() {
            _allowPop = true;
          });
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF94C66)))
            : SafeArea(
          child: Column(
            children: [
              // 🔥 CUSTOM TOP BAR
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.home_outlined,
                            color: Colors.black87),
                        onPressed: () async {
                          final shouldExit = await _showExitDialog(context);
                          if (shouldExit && mounted) {
                            Navigator.popUntil(context, (r) => r.isFirst);
                          }
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border:
                            Border.all(color: Colors.grey.shade100, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.undo,
                                color: _undoStack.isNotEmpty
                                    ? Colors.black87
                                    : Colors.black26),
                            onPressed: _undoStack.isNotEmpty ? _undo : null,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                          IconButton(
                            icon: Icon(Icons.redo,
                                color: _redoStack.isNotEmpty
                                    ? Colors.black87
                                    : Colors.black26),
                            onPressed: _redoStack.isNotEmpty ? _redo : null,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                          IconButton(
                            icon: const Icon(Icons.visibility_rounded,
                                color: Colors.black87),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PreviewScreen(
                                    data: provider.data,
                                    template: widget.template,
                                    designId: _currentDesignId,
                                    pages: _pages,
                                  ),
                                ),
                              );
                            },
                            tooltip: "Preview",
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                          IconButton(
                            icon: const Icon(Icons.location_on_rounded,
                                color: Color(0xFFF94C66)),
                            onPressed: _showMapLocationDialog,
                            tooltip: "Set Live Location",
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                           Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 4.0),
                             child: Tooltip(
                              message: "Auto-Align & Center All Elements",
                              child: InkWell(
                                onTap: () {
                                  _beginAction();
                                  provider.alignAndCenterAllElements(pages: _pages, force: false);
                                  _endAction();
                                  InteractionService.logInteraction(
                                    type: 'auto_align_elements',
                                    description: 'Auto-aligned and centered elements',
                                    details: {'designId': _currentDesignId},
                                  );
                                  TopNotification.show(
                                    context,
                                    message: "Page layout optimized and auto-centered successfully!",
                                  );
                                },
                                borderRadius: BorderRadius.circular(100),
                                child: Container(
                                  padding: const EdgeInsets.all(7.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB200).withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFFB200).withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFB200).withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.format_align_center_rounded,
                                    color: Color(0xFFFF9100),
                                    size: 19,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PreviewScreen(
                              data: context.read<InvitationProvider>().data,
                              template: widget.template,
                              designId: _currentDesignId,
                              pages: _pages,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF94C66),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      child: Text(lang.save,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),

              // 🔥 CANVAS (PageView) — Responsive
              Expanded(
                child: _pages.isEmpty 
                    ? const Center(child: Text("No pages found for this template"))
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final currentPageModel = _pages[currentPage];
                    final templateAspect = currentPageModel.width / currentPageModel.height;
                    final availableWidth =
                        constraints.maxWidth - 24; // 12px padding each side
                    final availableHeight =
                        constraints.maxHeight - 16; // 8px padding top/bottom

                    double canvasW, canvasH;
                    if (availableWidth / availableHeight > templateAspect) {
                      // Height-constrained
                      canvasH = availableHeight;
                      canvasW = canvasH * templateAspect;
                    } else {
                      // Width-constrained
                      canvasW = availableWidth;
                      canvasH = canvasW / templateAspect;
                    }

                    final scaleX = canvasW / currentPageModel.width;
                    final scaleY = canvasH / currentPageModel.height;

                    return PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: totalPages,
                      onPageChanged: (index) {
                        setState(() {
                          currentPage = index;
                          selectedElementId = null;
                        });
                      },
                      itemBuilder: (context, pageIndex) {
                        final pageElements = elements
                            .where(
                                (e) => e.pageIndex == pageIndex && e.isVisible)
                            .toList();

                        TemplateElement? selectedElement;
                        if (selectedElementId != null) {
                          try {
                            selectedElement = pageElements.firstWhere((e) => e.id == selectedElementId);
                          } catch (_) {}
                        }

                        final pageW = pageIndex < _pages.length ? _pages[pageIndex].width : 1080.0;
                        final pageH = pageIndex < _pages.length ? _pages[pageIndex].height : 1920.0;

                        final bool isCenteredV = selectedElement != null &&
                            (selectedElement.x + selectedElement.width / 2 - pageW / 2).abs() < 1.0;

                        final bool isCenteredH = selectedElement != null &&
                            (selectedElement.y + selectedElement.height / 2 - pageH / 2).abs() < 1.0;

                        return GestureDetector(
                          onTap: () => setState(() => selectedElementId = null),
                          child: Center(
                            child: Container(
                              width: canvasW,
                              height: canvasH,
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Background
                                    Positioned.fill(
                                      child: isNetworkImage(_pages[pageIndex].backgroundImage)
                                          ? Image.network(resolveImageUrl(_pages[pageIndex].backgroundImage), fit: BoxFit.cover)
                                          : Image.asset(cleanAssetPath(_pages[pageIndex].backgroundImage), fit: BoxFit.cover),
                                    ),
                                    // Elements for this page (scaled)
                                    ...pageElements.map((element) =>
                                        DraggableElement(
                                          element: element,
                                          isSelected:
                                              element.id == selectedElementId,
                                          activeLanguage:
                                              lang.activeInvitationLanguage,
                                          onTap: () => setState(() =>
                                              selectedElementId = element.id),
                                          onDelete: () =>
                                              _deleteElement(element),
                                          onDrag: (dx, dy) => setState(() {
                                            element.x += dx / scaleX;
                                            element.y += dy / scaleY;

                                            // Snap horizontally to center if close
                                            final centerX = element.x + element.width / 2;
                                            if ((centerX - pageW / 2).abs() < 5.0) {
                                              element.x = pageW / 2 - element.width / 2;
                                            }

                                            // Snap vertically to center if close
                                            final centerY = element.y + element.height / 2;
                                            if ((centerY - pageH / 2).abs() < 5.0) {
                                              element.y = pageH / 2 - element.height / 2;
                                            }
                                          }),
                                          onResize: (w, h, fontSize,
                                                  {newX, newY, newLetterSpacing}) =>
                                              setState(() {
                                            element.width = w;
                                            element.height = h;
                                            if (fontSize != null) {
                                              element.fontSize = fontSize;
                                            }
                                            if (newX != null) {
                                              element.x = newX;
                                            }
                                            if (newY != null) {
                                              element.y = newY;
                                            }
                                            if (newLetterSpacing != null) {
                                              element.letterSpacing = newLetterSpacing;
                                            }
                                          }),
                                          onTextEdit: (en, gu) {
                                             final String activeLang = lang.activeInvitationLanguage;
                                             final bool isLocalized = activeLang != 'English';
                                             final String activeCode = () {
                                               switch (activeLang.toLowerCase()) {
                                                 case 'english': return 'en';
                                                 case 'gujarati': return 'gu';
                                                 case 'hindi': return 'hi';
                                                 case 'marathi': return 'mr';
                                                 case 'punjabi': return 'pa';
                                                 case 'urdu': return 'ur';
                                                 case 'tamil': return 'ta';
                                                 default: return 'en';
                                               }
                                             }();

                                             setState(() {
                                               element.contentMap['en'] = sanitizeCorruptedText(en);
                                               if (isLocalized) {
                                                 element.contentMap[activeCode] = sanitizeCorruptedText(gu);
                                                 if (activeCode == 'gu') {
                                                   element.contentGujarati = gu;
                                                 }
                                               } else {
                                                 final translited = sanitizeCorruptedText(_engine.transliterate(en, lang: 'Gujarati'));
                                                 element.contentMap['gu'] = translited;
                                                 element.contentGujarati = translited;
                                               }
                                               _updateTextElementDimensions(element);
                                             });

                                             context
                                                 .read<InvitationProvider>()
                                                 .syncElementBackToProvider(
                                                     element);
                                             _autoSaveDraft();

                                             if (!isLocalized && en.isNotEmpty) {
                                               _engine
                                                   .transliterateAsync(en, lang: 'Gujarati')
                                                   .then((result) {
                                                 if (mounted && result.isNotEmpty) {
                                                   setState(() {
                                                     final cleanResult = sanitizeCorruptedText(result);
                                                     element.contentMap['gu'] = cleanResult;
                                                     element.contentGujarati = cleanResult;
                                                     _updateTextElementDimensions(element);
                                                   });
                                                   context
                                                       .read<InvitationProvider>()
                                                       .syncElementBackToProvider(
                                                           element);
                                                   _autoSaveDraft();
                                                 }
                                               });
                                             }
                                           },
                                          onActionStart: _beginAction,
                                          onActionEnd: _endAction,
                                          scaleX: scaleX,
                                          scaleY: scaleY,
                                        )),
                                    // Vertical Guideline for Selected Element
                                    if (selectedElement != null)
                                      Positioned(
                                        top: 0,
                                        bottom: 0,
                                        left: (selectedElement.x + selectedElement.width / 2) * scaleX,
                                        child: CustomPaint(
                                          painter: GuidelinePainter(
                                            vertical: true,
                                            color: isCenteredV ? const Color(0xFFF94C66) : const Color(0xFF2196F3).withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ),
                                    // Horizontal Guideline for Selected Element
                                    if (selectedElement != null)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        top: (selectedElement.y + selectedElement.height / 2) * scaleY,
                                        child: CustomPaint(
                                          painter: GuidelinePainter(
                                            vertical: false,
                                            color: isCenteredH ? const Color(0xFFF94C66) : const Color(0xFF2196F3).withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // 🗺️ MIDDLE BAR: + Add Text & Page Navigation
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _addNewTextField,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF5E7E),
                              Color(0xFFF94C66),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF94C66)
                                  .withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              "Add Text",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border:
                            Border.all(color: Colors.grey.shade100, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded,
                                size: 22),
                            color: currentPage > 0
                                ? const Color(0xFF4A4A4A)
                                : Colors.black12,
                            onPressed: currentPage > 0
                                ? () {
                                    _pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Page ${currentPage + 1}/$totalPages",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A4A4A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded,
                                size: 22),
                            color: currentPage < totalPages - 1
                                ? const Color(0xFF4A4A4A)
                                : Colors.black12,
                            onPressed: currentPage < totalPages - 1
                                ? () {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 🔥 PREMIUM BOTTOM TOOLBAR — Floating Card Style
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.black.withOpacity(0.03)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _bottomToolIcon(Icons.edit_note_rounded, "Edit",
                        () => _showEditBottomSheet()),
                    _bottomToolIcon(Icons.text_format_rounded, "Format",
                        () => _showFormatBottomSheet()),
                    _bottomToolIcon(Icons.sync_rounded, "Rotate",
                        () => _showRotationBottomSheet()),
                    _bottomToolIcon(Icons.palette_outlined, "Color",
                        () => _showColorBottomSheet()),
                    _bottomToolIcon(Icons.opacity_rounded, "Opacity",
                        () => _showOpacityBottomSheet()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomToolIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4A4A4A), size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10,
                color: Colors.black45,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 🔄 UNDO / REDO LOGIC
  // ─────────────────────────────────────────────────

  void _beginAction() {
    _actionOriginalState = context
        .read<InvitationProvider>()
        .elements
        .map((e) => e.copyWith())
        .toList();
  }

  void _endAction() {
    if (_actionOriginalState == null) return;
    final provider = context.read<InvitationProvider>();
    final currentStateStr = _hashElements(provider.elements);
    final originalStateStr = _hashElements(_actionOriginalState!);

    if (currentStateStr != originalStateStr) {
      setState(() {
        _undoStack.add(_actionOriginalState!);
        if (_undoStack.length > 30)
          _undoStack.removeAt(0); // keep last 30 actions
        _redoStack.clear();
      });
      _autoSaveDraft();
    }
    _actionOriginalState = null;
  }

  void _autoSaveDraft() {
    final elements = context.read<InvitationProvider>().elements;
    context.read<DesignsProvider>().saveDraft(UserDesign(
          id: _currentDesignId,
          template: widget.template,
          elements: elements,
          updatedAt: DateTime.now(),
        )).then((savedId) {
          if (mounted && _currentDesignId != savedId) {
            setState(() {
              _currentDesignId = savedId;
            });
          }
        });
  }

  String _hashElements(List<TemplateElement> els) {
    return els
        .map((e) =>
            "${e.id}:${e.x}:${e.y}:${e.width}:${e.height}:${e.fontSize}:${e.color.value}:${e.rotation}:${e.opacity}:${e.content}:${e.contentGujarati}:${e.fontFamily}:${e.textAlign}:${e.fontWeight}:${e.fontStyle}:${e.textDecoration}")
        .join("|");
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final provider = context.read<InvitationProvider>();
    setState(() {
      _redoStack.add(provider.elements.map((e) => e.copyWith()).toList());
      final prevState = _undoStack.removeLast();
      provider.elements.clear();
      provider.elements.addAll(prevState.map((e) => e.copyWith()));
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final provider = context.read<InvitationProvider>();
    setState(() {
      _undoStack.add(provider.elements.map((e) => e.copyWith()).toList());
      final nextState = _redoStack.removeLast();
      provider.elements.clear();
      provider.elements.addAll(nextState.map((e) => e.copyWith()));
    });
  }

  // ─────────────────────────────────────────────────
  // 🛠 BOTTOM SHEETS
  // ─────────────────────────────────────────────────

  void _showEditBottomSheet() {
    if (selectedElementId == null) return;
    final provider = context.read<InvitationProvider>();
    final lang = context.read<LanguageProvider>();
    final el = provider.elements.firstWhere((e) => e.id == selectedElementId,
        orElse: () => provider.elements.first);
    if (el.id.contains('_map_')) {
      _showMapLocationDialog();
      return;
    }
    if (el.type == ElementType.text) {
      String currentEn = el.content;
      String currentGu = el.contentGujarati;

      _beginAction();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Edit Text"),
          content: SizedBox(
            width: 400,
            child: TransliterationField(
              initialText: lang.activeInvitationLanguage != 'English'
                  ? (el.contentGujarati.isNotEmpty
                      ? el.contentGujarati
                      : el.content)
                  : el.content,
              isTransliterationOn: lang.activeInvitationLanguage != 'English',
              label: "Edit Content",
              maxLines: 4,
              onChanged: (en, gu) {
                currentEn = en;
                currentGu = gu;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final isLocalized = lang.activeInvitationLanguage != 'English';
                setState(() {
                  if (isLocalized) {
                    el.contentGujarati = currentGu;
                    if (el.content.isEmpty ||
                        el.content == el.contentGujarati) {
                      el.content = currentGu;
                    }
                  } else {
                    el.content = currentEn;
                    el.contentGujarati = _engine.transliterate(currentEn,
                        lang: lang.activeInvitationLanguage);
                  }
                });
                Navigator.pop(ctx);

                if (!isLocalized && currentEn.isNotEmpty) {
                  _engine
                      .transliterateAsync(currentEn,
                          lang: lang.activeInvitationLanguage)
                      .then((result) {
                    if (mounted && result != el.contentGujarati) {
                      setState(() => el.contentGujarati = result);
                    }
                  });
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ).then((_) => _endAction());
    }
  }

  Future<String?> _resolveShortUrl(String url) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url))..followRedirects = true;
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 4));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.request != null) {
        return response.request!.url.toString();
      }
    } catch (_) {}
    return null;
  }

  String? _extractPlaceNameFromMapsUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Format 1: https://www.google.com/maps/place/Place+Name/@21.12,72.34...
      if (uri.pathSegments.contains('place')) {
        final index = uri.pathSegments.indexOf('place');
        if (index + 1 < uri.pathSegments.length) {
          final rawPlace = uri.pathSegments[index + 1];
          final placeName = rawPlace.split('/')[0].split('@')[0];
          if (placeName.isNotEmpty) {
            final decoded = Uri.decodeComponent(placeName.replaceAll('+', ' '));
            if (decoded.trim().isNotEmpty && !decoded.contains('http')) {
              return decoded.trim();
            }
          }
        }
      }
      
      // Format 2: https://www.google.com/maps/search/Place+Name/...
      if (uri.pathSegments.contains('search')) {
        final index = uri.pathSegments.indexOf('search');
        if (index + 1 < uri.pathSegments.length) {
          final rawPlace = uri.pathSegments[index + 1];
          final placeName = rawPlace.split('/')[0].split('@')[0];
          if (placeName.isNotEmpty) {
            final decoded = Uri.decodeComponent(placeName.replaceAll('+', ' '));
            if (decoded.trim().isNotEmpty && !decoded.contains('http')) {
              return decoded.trim();
            }
          }
        }
      }
      
      // Format 3: https://maps.google.com/?q=Place+Name
      if (uri.queryParameters.containsKey('q')) {
        final q = uri.queryParameters['q'];
        if (q != null && q.isNotEmpty) {
          if (!RegExp(r'^-?\d+(\.\d+)?,?-?\d+(\.\d+)?$').hasMatch(q)) {
            final decoded = Uri.decodeComponent(q.replaceAll('+', ' '));
            if (decoded.trim().isNotEmpty && !decoded.contains('http')) {
              return decoded.trim();
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, double>? _extractCoordinatesFromUrl(String url) {
    try {
      // Format 1: @lat,lng
      final regex1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
      var match = regex1.firstMatch(url);
      if (match != null) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }

      // Format 2: !3dlat!4dlng
      final regex2 = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
      match = regex2.firstMatch(url);
      if (match != null) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }

      // Format 3: q=lat,lng
      final regex3 = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
      match = regex3.firstMatch(url);
      if (match != null) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'WeddingCardApp/1.0 (contact@amantran.app)',
        },
      ).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          final address = data['address'] as Map?;
          final displayName = data['display_name'] as String?;
          
          if (address != null) {
            final venue = address['amenity'] ?? address['tourism'] ?? address['building'] ?? address['shop'] ?? address['hotel'] ?? address['office'] ?? address['historic'] ?? address['leisure'] ?? address['place'];
            final road = address['road'] ?? address['suburb'] ?? address['neighbourhood'];
            final village = address['village'] ?? address['town'] ?? address['city'];
            final district = address['state_district'] ?? address['county'] ?? address['state'];
            
            final lines = <String>[];
            if (venue != null) {
              lines.add('${venue.toString()},');
            }
            if (road != null) {
              lines.add('${road.toString()},');
            }
            final cityPart = <String>[];
            if (village != null) cityPart.add(village.toString());
            if (district != null && district.toString() != village.toString()) cityPart.add(district.toString());
            if (cityPart.isNotEmpty) {
              lines.add('${cityPart.join(", ")}.');
            }
            
            if (lines.isNotEmpty) {
              return lines.join('\n');
            }
          }
          
          if (displayName != null && displayName.isNotEmpty) {
            final parts = displayName.split(',');
            if (parts.length > 3) {
              return parts.take(3).join('\n').trim();
            }
            return displayName.replaceAll(', ', '\n').trim();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _showMapLocationDialog() {
    final provider = context.read<InvitationProvider>();
    String currentUrl = '';
    for (final e in provider.elements) {
      if (e.id.contains('_map_') && e.mapUrl != null && e.mapUrl!.isNotEmpty) {
        currentUrl = e.mapUrl!;
        break;
      }
    }

    final controller = TextEditingController(text: currentUrl);
    String lastParsedUrl = currentUrl;
    bool isFetching = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void _applyExtractedName(String name) {
            final transliterated = _engine.transliterate(name, lang: 'Gujarati');
            
            setState(() {
              for (var i = 0; i < provider.elements.length; i++) {
                final e = provider.elements[i];
                if (e.type == ElementType.text &&
                    (e.id.contains('sthal_address') || e.id.contains('sthal_address_map_url'))) {
                  provider.elements[i] = e.copyWith(
                    content: name,
                    contentGujarati: transliterated.isNotEmpty ? transliterated : e.contentGujarati,
                  );
                }
              }
            });

            provider.updateField(() {
              for (final ev in provider.events) {
                ev.place = name;
                if (transliterated.isNotEmpty) {
                  ev.placeGu = transliterated;
                }
              }
            });
          }

          void _fetchAddressData(String url) async {
            if (url.isEmpty || url == lastParsedUrl) return;
            lastParsedUrl = url;

            setDialogState(() {
              isFetching = true;
            });

            // 1. Try instant local parsing first
            final localName = _extractPlaceNameFromMapsUrl(url);
            if (localName != null && localName.isNotEmpty) {
              _applyExtractedName(localName);
            }

            // 2. Try instantly parsing coordinates from URL
            final coords = _extractCoordinatesFromUrl(url);
            if (coords != null) {
              final address = await _reverseGeocode(coords['latitude']!, coords['longitude']!);
              if (address != null && address.isNotEmpty) {
                _applyExtractedName(address);
                setDialogState(() {
                  isFetching = false;
                });
                return;
              }
            }

            // 3. Resolve redirected URL for goo.gl or maps.app.goo.gl link
            if (url.contains('maps.app.goo.gl') || url.contains('goo.gl/maps') || url.contains('maps.google.com') || url.contains('google.com/maps')) {
              try {
                final resolvedUrl = await _resolveShortUrl(url);
                final targetUrl = resolvedUrl ?? url;

                // Check coordinates on resolved URL
                final resolvedCoords = _extractCoordinatesFromUrl(targetUrl);
                if (resolvedCoords != null) {
                  final address = await _reverseGeocode(resolvedCoords['latitude']!, resolvedCoords['longitude']!);
                  if (address != null && address.isNotEmpty) {
                    _applyExtractedName(address);
                    setDialogState(() {
                      isFetching = false;
                    });
                    return;
                  }
                }

                // Check if we can locally parse the long URL
                final redirectedLocal = _extractPlaceNameFromMapsUrl(targetUrl);
                if (redirectedLocal != null && redirectedLocal.isNotEmpty) {
                  _applyExtractedName(redirectedLocal);
                }

                // Fetch page HTML to extract og:title
                final response = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 4));
                final html = response.body;

                // Try og:title match
                final ogTitleRegExp = RegExp(r'''<meta[^>]*property=["\']og:title["\'][^>]*content=["\'](.*?)["\']''', caseSensitive: false);
                final ogMatch = ogTitleRegExp.firstMatch(html);
                String? richPlaceName;
                if (ogMatch != null) {
                  var ogTitle = ogMatch.group(1) ?? '';
                  ogTitle = ogTitle
                      .replaceAll('&amp;', '&')
                      .replaceAll('&#39;', "'")
                      .replaceAll('&quot;', '"')
                      .replaceAll('&lt;', '<')
                      .replaceAll('&gt;', '>');
                  final cleaned = ogTitle.trim();
                  if (cleaned.isNotEmpty && !cleaned.contains('Google Maps') && cleaned != 'Google Maps') {
                    richPlaceName = cleaned;
                  }
                }

                if (richPlaceName == null) {
                  final titleRegExp = RegExp(r'<title>(.*?)</title>', caseSensitive: false);
                  final match = titleRegExp.firstMatch(html);
                  if (match != null) {
                    var title = match.group(1) ?? '';
                    title = title
                        .replaceAll('&amp;', '&')
                        .replaceAll('&#39;', "'")
                        .replaceAll('&quot;', '"')
                        .replaceAll('&lt;', '<')
                        .replaceAll('&gt;', '>');
                    final suffixIndex = title.indexOf(' - Google Maps');
                    if (suffixIndex != -1) {
                      title = title.substring(0, suffixIndex);
                    }
                    final suffixIndex2 = title.indexOf(' – Google Maps');
                    if (suffixIndex2 != -1) {
                      title = title.substring(0, suffixIndex2);
                    }
                    final cleaned = title.trim();
                    if (cleaned.isNotEmpty && !cleaned.contains('Google Maps') && cleaned != 'Google Maps') {
                      richPlaceName = cleaned;
                    }
                  }
                }

                if (richPlaceName != null && richPlaceName.isNotEmpty) {
                  _applyExtractedName(richPlaceName);
                }
              } catch (_) {}
            }

            setDialogState(() {
              isFetching = false;
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFF94C66), size: 28),
                const SizedBox(width: 10),
                const Text(
                  "Set Live Location",
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Paste a Google Maps link. The venue name, address, and city will automatically fetch and load into the card.",
                    style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    maxLines: 2,
                    onChanged: (val) {
                      _fetchAddressData(val.trim());
                    },
                    decoration: InputDecoration(
                      labelText: "Paste Google Maps Link",
                      labelStyle: const TextStyle(
                          color: Color(0xFFF94C66), fontWeight: FontWeight.bold),
                      hintText: "https://maps.google.com/...",
                      hintStyle: const TextStyle(color: Colors.black26),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Color(0xFFF94C66), width: 2),
                      ),
                      prefixIcon: const Icon(Icons.link, color: Color(0xFFF94C66)),
                      suffixIcon: isFetching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF94C66)),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(foregroundColor: Colors.black38),
                child: const Text("Cancel",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  final newUrl = controller.text.trim();
                  _beginAction();
                  setState(() {
                    final updatedElements = List<TemplateElement>.from(provider.elements);
                    
                    // Update existing elements
                    for (var i = 0; i < updatedElements.length; i++) {
                      final e = updatedElements[i];
                      final idLower = e.id.toLowerCase();
                      if (idLower.contains('map') || 
                          idLower.contains('sthal') || 
                          idLower.contains('address') || 
                          idLower.contains('location')) {
                        updatedElements[i] =
                            e.copyWith(mapUrl: newUrl.isNotEmpty ? newUrl : null);
                      }
                    }

                    // Dynamically add or remove map icon if needed
                    if (newUrl.isNotEmpty) {
                      bool hasMapIcon = updatedElements.any((e) => e.id.contains('_map_icon') && e.isVisible);
                      if (!hasMapIcon) {
                        bool hasHiddenIcon = false;
                        for (var i = 0; i < updatedElements.length; i++) {
                          if (updatedElements[i].id.contains('_map_icon')) {
                            updatedElements[i] = updatedElements[i].copyWith(
                              isVisible: true,
                              mapUrl: newUrl,
                            );
                            hasHiddenIcon = true;
                            break;
                          }
                        }

                        if (!hasHiddenIcon) {
                          final pageW = currentPage < _pages.length ? _pages[currentPage].width : 1080.0;
                          final pageH = currentPage < _pages.length ? _pages[currentPage].height : 1920.0;
                          
                          double iconX = pageW / 2 - 50;
                          double iconY = pageH * 0.75;
                          
                          try {
                            final addressEl = updatedElements.firstWhere(
                              (e) => e.pageIndex == currentPage && (e.id.contains('sthal_address') || e.id.contains('address'))
                            );
                            iconX = addressEl.x + (addressEl.width - 100) / 2;
                            iconY = addressEl.y + addressEl.height + 15;
                          } catch (_) {
                            try {
                              final textEl = updatedElements.firstWhere(
                                (e) => e.pageIndex == currentPage && e.type == ElementType.text
                              );
                              iconX = textEl.x + (textEl.width - 100) / 2;
                              iconY = textEl.y + textEl.height + 15;
                            } catch (_) {}
                          }

                          final newIcon = TemplateElement(
                            id: 'custom_map_icon_${DateTime.now().millisecondsSinceEpoch}',
                            pageIndex: currentPage,
                            type: ElementType.image,
                            x: iconX,
                            y: iconY,
                            width: 100,
                            height: 100,
                            isMovable: true,
                            isResizable: true,
                            isVisible: true,
                            mapUrl: newUrl,
                          );
                          
                          updatedElements.add(newIcon);
                        }
                      }
                    } else {
                      // If newUrl is empty, hide map icons
                      for (var i = 0; i < updatedElements.length; i++) {
                        if (updatedElements[i].id.contains('_map_icon')) {
                          updatedElements[i] = updatedElements[i].copyWith(
                            isVisible: false,
                            mapUrl: null,
                          );
                        }
                      }
                    }
                    
                    provider.elements = updatedElements;
                  });
                  _endAction();
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(newUrl.isNotEmpty
                          ? "Live location and PDF map links updated successfully!"
                          : "Live location removed."),
                      backgroundColor: const Color(0xFFF94C66),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF94C66),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text("Save Link",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFormatBottomSheet() {
    if (selectedElementId == null) return;
    _beginAction();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FormatBottomSheet(
        elementId: selectedElementId!,
        onChanged: () => setState(() {}),
      ),
    ).then((_) => _endAction());
  }

  void _showRotationBottomSheet() {
    if (selectedElementId == null) return;
    _beginAction();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => RotationBottomSheet(
        elementId: selectedElementId!,
        onChanged: () => setState(() {}),
      ),
    ).then((_) => _endAction());
  }

  void _showColorBottomSheet() {
    if (selectedElementId == null) return;
    _beginAction();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ColorBottomSheet(
        elementId: selectedElementId!,
        onChanged: () => setState(() {}),
      ),
    ).then((_) => _endAction());
  }

  void _showOpacityBottomSheet() {
    if (selectedElementId == null) return;
    _beginAction();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => OpacityBottomSheet(
        elementId: selectedElementId!,
        onChanged: () => setState(() {}),
      ),
    ).then((_) => _endAction());
  }

  // ─────────────────────────────────────────────────
  // 🔀 NAVIGATION
  // ─────────────────────────────────────────────────
  void _goToForm() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormScreen(
          template: widget.template,
          returnMode: true,
        ),
      ),
    );
  }

  void _goToPreview() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PreviewScreen(
                  data: context.read<InvitationProvider>().data,
                  template: widget.template,
                  designId: _currentDesignId,
                )));
  }

  // ─────────────────────────────────────────────────
  // 🔄 AUTO-TRANSLITERATE ALL ELEMENTS
  // ─────────────────────────────────────────────────
  /// Called when language toggle changes.
  /// When switching to Gujarati: For any element whose English content
  /// was modified by the user, auto-transliterate to Gujarati.
  /// When switching to English: No action needed, content is always stored.
  void _autoTransliterateAll() {
    final lang = context.read<LanguageProvider>();
    if (lang.activeInvitationLanguage == 'English') return;

    // First pass: instant sync from dictionary/cache
    final modifiedElements = <TemplateElement>[];
    setState(() {
      for (final el in context.read<InvitationProvider>().elements) {
        if (el.type != ElementType.text) continue;
        if (!el.isEditable) continue;
        if (el.content.isEmpty) continue;

        final defaultEl = _findDefaultElement(el.id);

        if (defaultEl == null || el.content != defaultEl.content) {
          el.contentGujarati = _engine.transliterate(el.content);
          _updateTextElementDimensions(el);
          modifiedElements.add(el);
        }
      }
    });

    // Second pass: async API for better accuracy
    for (final el in modifiedElements) {
      _engine.transliterateAsync(el.content).then((result) {
        if (mounted && result != el.contentGujarati) {
          setState(() {
            el.contentGujarati = result;
            _updateTextElementDimensions(el);
          });
          context.read<InvitationProvider>().syncElementBackToProvider(el);
        }
      });
    }
  }

  /// Helper to measure visual text size and update the element's dimensions
  void _updateTextElementDimensions(TemplateElement el) {
    final lang = context.read<LanguageProvider>().activeInvitationLanguage;
    final provider = context.read<InvitationProvider>();
    final maxW = provider.getMaxConstraintWidthForElement(el);
    final String displayText = el.getDisplayText(lang);
    final textStyle = el.getTextStyle(scale: 1.0);

    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
      textAlign: el.textAlign,
    );
    textPainter.layout(maxWidth: maxW);

    final double oldWidth = el.width;
    final double newWidth = textPainter.width > 0 ? textPainter.width + 6.0 : 20.0;
    
    double newX = el.x;
    if (el.textAlign == TextAlign.center) {
      newX = el.x + (oldWidth - newWidth) / 2;
    } else if (el.textAlign == TextAlign.right || el.textAlign == TextAlign.end) {
      newX = el.x + oldWidth - newWidth;
    }

    el.width = newWidth;
    el.height = textPainter.height > 0 ? textPainter.height + 2.0 : 20.0;
    el.x = newX;
  }

  /// Find the original default element by ID
  TemplateElement? _findDefaultElement(String id) {
    try {
      for (var page in _pages) {
        for (var el in page.elements) {
          if (el.id == id) return el;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Dynamic Max Width Helper for self-healing text layouts
double getMaxConstraintWidth(String elementId) {
  final String id = elementId.toLowerCase();
  final bool isLeftColumn = id.contains('event1') || 
                            id.contains('bhojan_title') || 
                            id.contains('bhojan_time') || 
                            id.contains('list1a') || 
                            id.contains('list2a') || 
                            id.contains('list3a') || 
                            id.endsWith('_left');
                            
  final bool isRightColumn = id.contains('event2') || 
                             id.contains('sthal_title') || 
                             id.contains('sthal_address') || 
                             id.contains('list1b') || 
                             id.contains('list2b') || 
                             id.contains('list3b') || 
                             id.endsWith('_right');

  if (isLeftColumn || isRightColumn) {
    return 160.0;
  }
  return 320.0;
}

/// A lightweight custom painter to render vertical or horizontal alignment guidelines
class GuidelinePainter extends CustomPainter {
  final bool vertical;
  final Color color;

  GuidelinePainter({required this.vertical, this.color = const Color(0xFFF94C66)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double dashWidth = 6.0;
    const double dashSpace = 4.0;

    if (vertical) {
      double startY = 0;
      while (startY < size.height) {
        canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
        startY += dashWidth + dashSpace;
      }
    } else {
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
        startX += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuidelinePainter oldDelegate) {
    return oldDelegate.vertical != vertical || oldDelegate.color != color;
  }
}
