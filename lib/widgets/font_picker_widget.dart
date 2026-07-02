import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/font_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FONT REGISTRY
// ─────────────────────────────────────────────────────────────────────────────

class FontEntry {
  final String family;
  final String category; // 'gu_unicode' | 'hi' | 'en'
  const FontEntry(this.family, this.category);
}

class FontRegistry {
  static const _guUni = 'gu_unicode';
  static const _hi = 'hi';
  static const _en = 'en';

  static const List<FontEntry> allFonts = [
    // ── Gujarati Unicode Fonts ─────────────────────────
    FontEntry('Noto Serif Gujarati', _guUni),
    FontEntry('Noto Sans Gujarati', _guUni),
    FontEntry('Rasa', _guUni),
    FontEntry('Farsan', _guUni),
    FontEntry('Hind Vadodara', _guUni),
    FontEntry('Baloo Bhai 2', _guUni),
    FontEntry('Mukta Vaani', _guUni),
    FontEntry('Shrikhand', _guUni),
    FontEntry('Mogra', _guUni),
    FontEntry('Kumar One', _guUni),
    FontEntry('Kumar One Outline', _guUni),
    FontEntry('Anek Gujarati', _guUni),
    // ── Hindi / Devanagari ─────────────────────────────
    FontEntry('Noto Sans Devanagari', _hi),
    FontEntry('Noto Serif Devanagari', _hi),
    FontEntry('Mukta', _hi),
    FontEntry('Hind', _hi),
    FontEntry('Baloo 2', _hi),
    FontEntry('Poppins', _hi),
    FontEntry('Tiro Devanagari Hindi', _hi),
    FontEntry('Yatra One', _hi),
    FontEntry('Mogra', _hi),
    FontEntry('Kalam', _hi),
    FontEntry('Amita', _hi),
    FontEntry('Laila', _hi),
    FontEntry('Rozha One', _hi),
    FontEntry('Rajdhani', _hi),
    // ── English / Stylish ──────────────────────────────
    FontEntry('Dancing Script', _en),
    FontEntry('Great Vibes', _en),
    FontEntry('Parisienne', _en),
    FontEntry('Allura', _en),
    FontEntry('Sacramento', _en),
    FontEntry('Alex Brush', _en),
    FontEntry('Pinyon Script', _en),
    FontEntry('Monsieur La Doulaise', _en),
    FontEntry('Luxurious Script', _en),
    FontEntry('Engagement', _en),
    FontEntry('Arizonia', _en),
    FontEntry('Cookie', _en),
    FontEntry('Charm', _en),
    FontEntry('Meie Script', _en),
    FontEntry('Mr De Haviland', _en),
    FontEntry('Dr Sugiyama', _en),
    FontEntry('Herr Von Muellerhoff', _en),
    FontEntry('Rochester', _en),
    FontEntry('Niconne', _en),
    FontEntry('WindSong', _en),
    FontEntry('Playball', _en),
    FontEntry('Clicker Script', _en),
    FontEntry('Qwigley', _en),
    FontEntry('Aguafina Script', _en),
    FontEntry('Redressed', _en),
    FontEntry('Cinzel Decorative', _en),
    FontEntry('Cinzel', _en),
    FontEntry('Forum', _en),
    FontEntry('Marcellus', _en),
    FontEntry('Playfair Display', _en),
    FontEntry('Cormorant Garamond', _en),
    FontEntry('Libre Baskerville', _en),
    FontEntry('Montserrat', _en),
    FontEntry('Pacifico', _en),
    FontEntry('Lobster', _en),
    FontEntry('Satisfy', _en),
    FontEntry('Yellowtail', _en),
    FontEntry('Kaushan Script', _en),
    FontEntry('Italianno', _en),
    FontEntry('Roboto', _en),
  ];

  static List<FontEntry> getAll() {
    final existing = allFonts.map((e) => e.family.toLowerCase()).toSet();
    final dynamic = FontService.registeredFamilies
        .where((f) => !existing.contains(f.toLowerCase()) && !f.toLowerCase().startsWith('kap'))
        .map((f) => FontEntry(f, _en));
    return [...allFonts, ...dynamic];
  }

  static String sampleFor(FontEntry font) {
    switch (font.category) {
      case _guUni:
        return 'સસ્નેહ આમંત્રણ';
      case _hi:
        return 'सस्नेह आमंत्रण';
      default:
        return 'Cordial Invitation';
    }
  }

  static TextStyle previewStyle(FontEntry font, {double size = 20}) {
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w500);
    final lower = font.family.toLowerCase();
    for (final reg in FontService.registeredFamilies) {
      if (reg.toLowerCase() == lower) return base.copyWith(fontFamily: reg);
    }
    const bundled = ['noto serif gujarati', 'noto sans gujarati', 'hind vadodara', 'rasa', 'shrikhand', 'farsan'];
    if (bundled.contains(lower)) return base.copyWith(fontFamily: font.family);
    try {
      return GoogleFonts.getFont(font.family, textStyle: base);
    } catch (_) {
      return base.copyWith(fontFamily: font.family);
    }
  }

  static String categoryLabel(String cat) {
    switch (cat) {
      case _guUni:    return 'Gujarati';
      case _hi:       return 'Hindi';
      case _en:       return 'English';
      default:        return 'All';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPACT FONT SELECTOR ROW  (used in FormatBottomSheet / EditorToolbar)
// ─────────────────────────────────────────────────────────────────────────────

/// A compact, tappable row showing the current font that opens the font picker
/// modal sheet when tapped.
class FontSelectorRow extends StatelessWidget {
  final String currentFont;
  final ValueChanged<String> onFontSelected;
  final String label;

  const FontSelectorRow({
    super.key,
    required this.currentFont,
    required this.onFontSelected,
    this.label = 'Font Family',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FontPickerSheet.show(
        context,
        currentFont: currentFont,
        onFontSelected: onFontSelected,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.font_download_outlined, size: 18, color: Colors.grey),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF94C66).withValues(alpha: 0.25)),
              ),
              child: Text(
                currentFont,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF94C66),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFF94C66), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FONT PICKER MODAL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class FontPickerSheet extends StatefulWidget {
  final String currentFont;
  final ValueChanged<String> onFontSelected;
  final ScrollController? scrollController;

  const FontPickerSheet({
    super.key,
    required this.currentFont,
    required this.onFontSelected,
    this.scrollController,
  });

  /// Opens the font picker as a draggable modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String currentFont,
    required ValueChanged<String> onFontSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        maxChildSize: 0.95,
        minChildSize: 0.40,
        expand: false,
        builder: (ctx, scrollController) => FontPickerSheet(
          currentFont: currentFont,
          onFontSelected: onFontSelected,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  State<FontPickerSheet> createState() => _FontPickerSheetState();
}

class _FontPickerSheetState extends State<FontPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _activeCategory;
  late String _selectedFont;

  static const _cats = [
    ('gu_unicode', 'Gujarati'),
    ('hi', 'Hindi'),
    ('en', 'English'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedFont = widget.currentFont;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allFonts = FontRegistry.getAll();
    final filtered = allFonts.where((f) {
      final matchSearch = _query.isEmpty ||
          f.family.toLowerCase().contains(_query.toLowerCase());
      final matchCat = _activeCategory == null || f.category == _activeCategory;
      return matchSearch && matchCat;
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Drag handle ────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const Text('Font Family',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF94C66),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Done',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Search bar ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: 'Search fonts...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                  prefixIconConstraints: BoxConstraints(
                    minWidth: 36,
                    minHeight: 40,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Category tabs ─────────────────────────
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _catChip(null, 'All'),
                ..._cats.map((c) => _catChip(c.$1, c.$2)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Font list ─────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final font = filtered[i];
                final isSel = _selectedFont.toLowerCase() == font.family.toLowerCase();
                return _FontRow(
                  font: font,
                  isSelected: isSel,
                  onTap: () {
                    setState(() => _selectedFont = font.family);
                    widget.onFontSelected(font.family);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _catChip(String? cat, String label) {
    final active = _activeCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _activeCategory = cat),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF94C66) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FONT ROW  (individual row in the list)
// ─────────────────────────────────────────────────────────────────────────────

class _FontRow extends StatelessWidget {
  final FontEntry font;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontRow({
    required this.font,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sample = FontRegistry.sampleFor(font);
    final style = FontRegistry.previewStyle(font, size: 22);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF0F2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFFF94C66).withValues(alpha: 0.35), width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            // Font sample preview
            Expanded(
              child: Text(
                sample,
                style: style.copyWith(
                  color: isSelected ? Colors.black87 : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            // Font name label
            Text(
              font.family,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? const Color(0xFFF94C66)
                    : Colors.grey.shade400,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 8),
            // Selection circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFFF94C66)
                    : Colors.grey.shade100,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFF94C66)
                      : Colors.grey.shade300,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
