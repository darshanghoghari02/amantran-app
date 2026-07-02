import 'package:flutter/material.dart';
import '../../../models/template_element.dart';
import '../../../widgets/font_picker_widget.dart';

/// Bottom toolbar for the editor canvas.
///
/// Provides controls for:
/// - Color picker (predefined palette)
/// - Font family selector
/// - Font size slider
/// - Text alignment buttons
/// - Width & Height controls
/// - Font weight toggle
class EditorToolbar extends StatefulWidget {
  final TemplateElement? selectedElement;
  final Function(Color color) onColorChanged;
  final Function(String fontFamily) onFontFamilyChanged;
  final Function(double fontSize) onFontSizeChanged;
  final Function(TextAlign align) onAlignChanged;
  final Function(FontWeight weight) onFontWeightChanged;
  final Function(double width, double height) onSizeChanged;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const EditorToolbar({
    super.key,
    required this.selectedElement,
    required this.onColorChanged,
    required this.onFontFamilyChanged,
    required this.onFontSizeChanged,
    required this.onAlignChanged,
    required this.onFontWeightChanged,
    required this.onSizeChanged,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Rebuild when tab changes so height updates dynamically
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🎨 COLOR PALETTE
  static const List<Color> _colors = [
    Colors.black,
    Colors.white,
    Color(0xFFB71C1C), // Deep Red
    Color(0xFFC62828), // Red
    Color(0xFFE53935), // Light Red
    Color(0xFFD32F2F), // Red 700
    Color(0xFF8B0000), // Dark Red
    Color(0xFFFF5722), // Deep Orange
    Color(0xFFFF9800), // Orange
    Color(0xFFFFC107), // Amber
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFF3F51B5), // Indigo
    Color(0xFF9C27B0), // Purple
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFD4AF37), // Gold
    Color(0xFFC49A6C), // Tan
    Color(0xFF8D6E63), // Brown 400
  ];

  // Font list is now managed by FontPickerWidget / FontRegistry

  @override
  Widget build(BuildContext context) {
    final element = widget.selectedElement;

    if (element == null) {
      return Container(
        height: 60,
        color: Colors.grey.shade100,
        child: const Center(
          child: Text(
            "Tap an element to customize it",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 🔹 DRAG HANDLE
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 🔹 TAB BAR
          TabBar(
            controller: _tabController,
            labelColor: Colors.red.shade700,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.red.shade700,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.palette, size: 18), text: "Color"),
              Tab(icon: Icon(Icons.text_fields, size: 18), text: "Font"),
              Tab(icon: Icon(Icons.format_size, size: 18), text: "Size"),
              Tab(icon: Icon(Icons.aspect_ratio, size: 18), text: "Resize"),
            ],
          ),

          // 🔹 TAB CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildColorTab(element),
                _buildFontTab(element),
                _buildSizeTab(element),
                _buildResizeTab(element),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 🎨 COLOR TAB
  // ─────────────────────────────────────────────────
  Widget _buildColorTab(TemplateElement element) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: _colors.length,
        itemBuilder: (context, index) {
          final color = _colors[index];
          final isActive = element.color.toARGB32() == color.toARGB32();

          return GestureDetector(
            onTap: () => widget.onColorChanged(color),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? Colors.blue : Colors.grey.shade300,
                  width: isActive ? 3 : 1,
                ),
              ),
              child: isActive
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color:
                          color == Colors.white ? Colors.black : Colors.white,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 🔤 FONT TAB
  // ─────────────────────────────────────────────────
  Widget _buildFontTab(TemplateElement element) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact Font Family Selector Row which opens FontPickerSheet modal
          FontSelectorRow(
            currentFont: element.fontFamily,
            onFontSelected: (font) => widget.onFontFamilyChanged(font),
          ),
          const SizedBox(height: 12),
          // Alignment + Bold/Duplicate/Delete row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _alignButton(Icons.format_align_left, TextAlign.left, element),
              _alignButton(Icons.format_align_center, TextAlign.center, element),
              _alignButton(Icons.format_align_right, TextAlign.right, element),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.format_bold,
                  color: element.fontWeight == FontWeight.bold
                      ? Colors.red.shade700
                      : Colors.grey,
                ),
                onPressed: () {
                  widget.onFontWeightChanged(
                    element.fontWeight == FontWeight.bold
                        ? FontWeight.normal
                        : FontWeight.bold,
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.copy, color: Colors.blue.shade400),
                onPressed: widget.onDuplicate,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 📏 SIZE TAB (Font Size)
  // ─────────────────────────────────────────────────
  Widget _buildSizeTab(TemplateElement element) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.text_decrease, size: 18, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: element.fontSize.clamp(8.0, 60.0),
                  min: 8,
                  max: 60,
                  divisions: 52,
                  label: "${element.fontSize.toInt()}",
                  activeColor: Colors.red.shade700,
                  onChanged: (val) => widget.onFontSizeChanged(val),
                ),
              ),
              const Icon(Icons.text_increase, size: 18, color: Colors.grey),
            ],
          ),
          Text(
            "Font Size: ${element.fontSize.toInt()}px",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 📐 RESIZE TAB (Width & Height)
  // ─────────────────────────────────────────────────
  Widget _buildResizeTab(TemplateElement element) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Width control
          Row(
            children: [
              const SizedBox(
                width: 30,
                child: Text("W",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => widget.onSizeChanged(
                    (element.width - 5).clamp(30.0, 800.0), element.height),
              ),
              Expanded(
                child: Slider(
                  value: element.width.clamp(30.0, 800.0),
                  min: 30,
                  max: 800,
                  divisions: 154,
                  label: "${element.width.toInt()}",
                  activeColor: Colors.blue.shade600,
                  onChanged: (val) {
                    widget.onSizeChanged(val, element.height);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => widget.onSizeChanged(
                    (element.width + 5).clamp(30.0, 800.0), element.height),
              ),
              SizedBox(
                width: 35,
                child: Text("${element.width.toInt()}",
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),

          // Height control
          Row(
            children: [
              const SizedBox(
                width: 30,
                child: Text("H",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => widget.onSizeChanged(
                    element.width, (element.height - 5).clamp(20.0, 800.0)),
              ),
              Expanded(
                child: Slider(
                  value: element.height.clamp(20.0, 800.0),
                  min: 20,
                  max: 800,
                  divisions: 156,
                  label: "${element.height.toInt()}",
                  activeColor: Colors.green.shade600,
                  onChanged: (val) {
                    widget.onSizeChanged(element.width, val);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => widget.onSizeChanged(
                    element.width, (element.height + 5).clamp(20.0, 800.0)),
              ),
              SizedBox(
                width: 35,
                child: Text("${element.height.toInt()}",
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alignButton(IconData icon, TextAlign align, TemplateElement element) {
    final isActive = element.textAlign == align;
    return IconButton(
      icon: Icon(icon, color: isActive ? Colors.red.shade700 : Colors.grey),
      onPressed: () => widget.onAlignChanged(align),
    );
  }
}
