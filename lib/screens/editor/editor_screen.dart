import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/invitation_provider.dart';
import '../../models/template_model.dart';
import '../../models/template_element.dart';
import '../../data/templates.dart' show pageNames;
import '../../services/transliteration_engine.dart';
import '../preview/preview_screen.dart';
import '../form/form_screen.dart';
import 'widgets/draggable_element.dart';
import 'widgets/editor_toolbar.dart';
import 'widgets/language_toggle.dart';

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
  const EditorScreen({super.key, required this.template});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String? selectedElementId;
  bool isGujarati = true;
  int currentPage = 0;
  final PageController _pageController = PageController();
  final TransliterationEngine _engine = TransliterationEngine();

  static final int totalPages = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvitationProvider>().initElements(widget.template.elements);
    });
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();
    final elements = provider.elements;
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text(
            widget.template.name.isNotEmpty ? widget.template.name : "Editor"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          LanguageToggle(
            isGujarati: isGujarati,
            onChanged: (val) {
              setState(() => isGujarati = val);
              _autoTransliterateAll();
            },
          ),
          const SizedBox(width: 4),
          IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: "Fill Form",
              onPressed: _goToForm),
          IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: "Preview",
              onPressed: _goToPreview),
        ],
      ),
      body: Column(
        children: [
          // 🔥 TOP ACTION BAR
          _buildActionBar(),

          // 🔥 PAGE INDICATOR
          _buildPageIndicator(),

          // 🔥 CANVAS (PageView)
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: totalPages,
              onPageChanged: (index) {
                setState(() {
                  currentPage = index;
                  selectedElementId = null; // deselect when switching pages
                });
              },
              itemBuilder: (context, pageIndex) {
                final pageElements = elements
                    .where((e) => e.pageIndex == pageIndex && e.isVisible)
                    .toList();

                return GestureDetector(
                  onTap: () => setState(() => selectedElementId = null),
                  child: Center(
                    child: Container(
                      width: widget.template.canvasWidth,
                      height: widget.template.canvasHeight,
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
                              child: Image.asset(
                                  widget.template.getPageImage(pageIndex),
                                  fit: BoxFit.cover),
                            ),
                            // Elements for this page
                            ...pageElements.map((element) => DraggableElement(
                                  element: element,
                                  isSelected: element.id == selectedElementId,
                                  isGujarati: isGujarati,
                                  onTap: () => setState(
                                      () => selectedElementId = element.id),
                                  onDrag: (dx, dy) => setState(() {
                                    element.x += dx;
                                    element.y += dy;
                                  }),
                                  onResize: (w, h) => setState(() {
                                    element.width = w;
                                    element.height = h;
                                  }),
                                  onTextEdit: (text) {
                                    setState(() {
                                      if (isGujarati) {
                                        element.contentGujarati = text;
                                        if (element.content.isEmpty ||
                                            element.content ==
                                                element.contentGujarati) {
                                          element.content = text;
                                        }
                                      } else {
                                        element.content = text;
                                        // Instant sync from dictionary/cache
                                        element.contentGujarati =
                                            _engine.transliterate(text);
                                      }
                                    });
                                    // Then try API for better result
                                    if (!isGujarati && text.isNotEmpty) {
                                      _engine
                                          .transliterateAsync(text)
                                          .then((result) {
                                        if (mounted &&
                                            result != element.contentGujarati) {
                                          setState(() =>
                                              element.contentGujarati = result);
                                        }
                                      });
                                    }
                                  },
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 🔥 BOTTOM TOOLBAR
          EditorToolbar(
            selectedElement: selectedElement(provider),
            onColorChanged: (c) =>
                setState(() => selectedElement(provider)?.color = c),
            onFontFamilyChanged: (f) =>
                setState(() => selectedElement(provider)?.fontFamily = f),
            onFontSizeChanged: (s) =>
                setState(() => selectedElement(provider)?.fontSize = s),
            onAlignChanged: (a) =>
                setState(() => selectedElement(provider)?.textAlign = a),
            onFontWeightChanged: (w) =>
                setState(() => selectedElement(provider)?.fontWeight = w),
            onSizeChanged: (w, h) => setState(() {
              selectedElement(provider)?.width = w;
              selectedElement(provider)?.height = h;
            }),
            onDelete: () {
              if (selectedElementId != null) {
                setState(() {
                  provider.elements
                      .removeWhere((e) => e.id == selectedElementId);
                  selectedElementId = null;
                });
              }
            },
            onDuplicate: () {
              if (selectedElement(provider) != null) {
                final newId = 'copy_${DateTime.now().millisecondsSinceEpoch}';
                final copy = selectedElement(provider)!.copyWith(
                  id: newId,
                  x: selectedElement(provider)!.x + 20,
                  y: selectedElement(provider)!.y + 20,
                );
                setState(() {
                  provider.elements.add(copy);
                  selectedElementId = newId;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 📄 PAGE INDICATOR (dots + page name)
  // ─────────────────────────────────────────────────
  Widget _buildPageIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          // Page name
          Text(
            "Page ${currentPage + 1}: ${pageNames[currentPage]}",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (i) {
              final isActive = i == currentPage;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        isActive ? Colors.red.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 🔧 TOP ACTION BAR
  // ─────────────────────────────────────────────────
  Widget _buildActionBar() {
    final provider = context.watch<InvitationProvider>();
    return Container(
      height: 44,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _actionBtn(Icons.text_fields, "Text", _addTextElement),
          _actionBtn(Icons.horizontal_rule, "Divider", _addDividerElement),
          const Spacer(),
          Text("${currentPageElements(provider).length} items",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 20),
            tooltip: "Reset page",
            onPressed: _resetCurrentPage,
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // ➕ ADD ELEMENTS (to current page)
  // ─────────────────────────────────────────────────
  void _addTextElement() {
    final provider = context.read<InvitationProvider>();
    final id = 'custom_${currentPage}_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      provider.elements.add(TemplateElement(
        id: id,
        type: ElementType.text,
        pageIndex: currentPage,
        content: "New Text",
        contentGujarati: "નવો ટેક્સ્ટ",
        x: 100,
        y: 300,
        width: 160,
        height: 36,
        fontSize: 16,
        fontFamily: widget.template.fontFamily,
        color: widget.template.textColor,
      ));
      selectedElementId = id;
    });
  }

  void _addDividerElement() {
    final provider = context.read<InvitationProvider>();
    final id = 'div_${currentPage}_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      provider.elements.add(TemplateElement(
        id: id,
        type: ElementType.divider,
        pageIndex: currentPage,
        x: 80,
        y: 320,
        width: 200,
        height: 4,
        color: widget.template.textColor,
        isEditable: false,
      ));
      selectedElementId = id;
    });
  }

  // ─────────────────────────────────────────────────
  // 🔄 RESET CURRENT PAGE
  // ─────────────────────────────────────────────────
  void _resetCurrentPage() {
    final provider = context.read<InvitationProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Reset Page ${currentPage + 1}?"),
        content:
            const Text("This will reset this page's elements to defaults."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                provider.elements
                    .removeWhere((e) => e.pageIndex == currentPage);
                final defaults = widget.template.elements
                    .where((e) => e.pageIndex == currentPage)
                    .map((e) => e.copyWith())
                    .toList();
                provider.elements.addAll(defaults);
                selectedElementId = null;
              });
              Navigator.pop(ctx);
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
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
                template: widget.template)));
  }

  // ─────────────────────────────────────────────────
  // 🔄 AUTO-TRANSLITERATE ALL ELEMENTS
  // ─────────────────────────────────────────────────
  /// Called when language toggle changes.
  /// When switching to Gujarati: For any element whose English content
  /// was modified by the user, auto-transliterate to Gujarati.
  /// When switching to English: No action needed, content is always stored.
  void _autoTransliterateAll() {
    if (!isGujarati) return;

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
          modifiedElements.add(el);
        }
      }
    });

    // Second pass: async API for better accuracy
    for (final el in modifiedElements) {
      _engine.transliterateAsync(el.content).then((result) {
        if (mounted && result != el.contentGujarati) {
          setState(() => el.contentGujarati = result);
        }
      });
    }
  }

  /// Find the original default element by ID
  TemplateElement? _findDefaultElement(String id) {
    try {
      return widget.template.elements.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────
  // 🔄 SYNC: Form Data → Canvas Elements
  // ─────────────────────────────────────────────────
  // ─────────────────────────────────────────────────
  // 🔄 SYNC: Form Data → Canvas Elements
  // ─────────────────────────────────────────────────
}
