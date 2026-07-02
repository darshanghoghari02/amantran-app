import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/template_element.dart';
import '../../../providers/invitation_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../widgets/font_picker_widget.dart';

// ─────────────────────────────────────────────────
// COMMON SHEET WRAPPER
// ─────────────────────────────────────────────────
class _SheetWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  const _SheetWrapper({
    required this.child,
    required this.onDone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    // Ensure the sheet always sits above the system navigation bar
    final bottomInset = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: bottomInset > 0 ? bottomInset : 24,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onCancel,
                child: Text(lang.cancel,
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ),
              GestureDetector(
                onTap: onDone,
                child: Text(lang.done,
                    style: const TextStyle(
                        color: Color(0xFFF94C66),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
          // Extra breathing room above nav bar
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// FORMAT BOTTOM SHEET
// ─────────────────────────────────────────────────
class FormatBottomSheet extends StatefulWidget {
  final String elementId;
  final VoidCallback onChanged;
  final List<String>? supportedLanguages;

  const FormatBottomSheet({
    super.key,
    required this.elementId,
    required this.onChanged,
    this.supportedLanguages,
  });

  @override
  State<FormatBottomSheet> createState() => _FormatBottomSheetState();
}

class _FormatBottomSheetState extends State<FormatBottomSheet> {
  late TemplateElement element;
  late TemplateElement _originalState;

  // Font list is now managed by FontPickerWidget / FontRegistry


  @override
  void initState() {
    super.initState();
    final provider = context.read<InvitationProvider>();
    element = provider.elements.firstWhere((e) => e.id == widget.elementId);
    _originalState = element.copyWith();
  }

  void _updateDimensions() {
    final langProvider = context.read<LanguageProvider>();
    final activeLanguage = langProvider.activeInvitationLanguage;
    final maxW = getMaxConstraintWidth(element.id);
    final String displayText = element.getDisplayText(activeLanguage);
    final textStyle =
        element.getTextStyleForLanguage(activeLanguage, scale: 1.0);

    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
      textAlign: element.textAlign,
    );
    textPainter.layout(maxWidth: maxW);

    final double newW = textPainter.width > 0 ? textPainter.width + 6.0 : 20.0;
    final double newH = textPainter.height > 0 ? textPainter.height + 2.0 : 20.0;

    if (element.textAlign == TextAlign.center) {
      element.x = element.x + (element.width - newW) / 2;
    } else if (element.textAlign == TextAlign.right || element.textAlign == TextAlign.end) {
      element.x = element.x + element.width - newW;
    }

    element.width = newW;
    element.height = newH;
  }

  void _revert() {
    element.fontSize = _originalState.fontSize;
    element.fontWeight = _originalState.fontWeight;
    element.fontStyle = _originalState.fontStyle;
    element.textDecoration = _originalState.textDecoration;
    element.textAlign = _originalState.textAlign;
    element.fontFamily = _originalState.fontFamily;
    element.x = _originalState.x;
    element.y = _originalState.y;
    element.width = _originalState.width;
    element.height = _originalState.height;
    widget.onChanged();
    Navigator.pop(context);
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    // allFonts local variable removed — FontPickerWidget handles the list internally
    return _SheetWrapper(
      onCancel: _revert,
      onDone: () => Navigator.pop(context),
      child: Column(
        children: [
          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFF94C66),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: const Color(0xFFF94C66),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: element.fontSize.clamp(8.0, 100.0),
              min: 8,
              max: 100,
              onChanged: (val) {
                setState(() {
                  element.fontSize = val;
                  _updateDimensions();
                });
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(height: 20),
          // Toggle row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _toggleBtn("B", element.fontWeight == FontWeight.bold, () {
                setState(() {
                  element.fontWeight = element.fontWeight == FontWeight.bold
                      ? FontWeight.normal
                      : FontWeight.bold;
                  _updateDimensions();
                });
                widget.onChanged();
              }),
              _toggleBtn("I", element.fontStyle == FontStyle.italic, () {
                setState(() {
                  element.fontStyle = element.fontStyle == FontStyle.italic
                      ? FontStyle.normal
                      : FontStyle.italic;
                  _updateDimensions();
                });
                widget.onChanged();
              }, isItalic: true),
              _toggleBtn(
                  "U", element.textDecoration == TextDecoration.underline, () {
                setState(() {
                  element.textDecoration =
                      element.textDecoration == TextDecoration.underline
                          ? TextDecoration.none
                          : TextDecoration.underline;
                  _updateDimensions();
                });
                widget.onChanged();
              }, isUnderline: true),
              if (lang.activeInvitationLanguage.toLowerCase() == 'english')
                _toggleBtn("aA", false, () {
                  setState(() {
                    final text = element.content;
                    if (text == text.toUpperCase()) {
                      element.content = text.toLowerCase();
                    } else if (text == text.toLowerCase()) {
                      element.content = _toTitleCase(text);
                    } else {
                      element.content = text.toUpperCase();
                    }

                    // Also handle the localized slot if it contains Latin characters
                    final textGu = element.contentGujarati;
                    if (textGu.contains(RegExp(r'[a-zA-Z]'))) {
                      if (textGu == textGu.toUpperCase()) {
                        element.contentGujarati = textGu.toLowerCase();
                      } else if (textGu == textGu.toLowerCase()) {
                        element.contentGujarati = _toTitleCase(textGu);
                      } else {
                        element.contentGujarati = textGu.toUpperCase();
                      }
                    }
                    _updateDimensions();
                  });
                  widget.onChanged();
                }),
            ],
          ),
          const SizedBox(height: 20),
          // Align row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _alignBtn(Icons.format_align_left,
                    element.textAlign == TextAlign.left, TextAlign.left),
                _alignBtn(Icons.format_align_center,
                    element.textAlign == TextAlign.center, TextAlign.center),
                _alignBtn(Icons.format_align_right,
                    element.textAlign == TextAlign.right, TextAlign.right),
                _alignBtn(Icons.format_align_justify,
                    element.textAlign == TextAlign.justify, TextAlign.justify),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Font Family Section
          FontSelectorRow(
            currentFont: element.fontFamily,
            label: lang.currentLanguage == 'Gujarati'
                ? 'ફોન્ટ ફેમિલી'
                : 'Font Family',
            onFontSelected: (font) {
              setState(() {
                element.fontFamily = font;
                _updateDimensions();
              });
              widget.onChanged();
            },
          ),
          const SizedBox(height: 16),

          // Invitation Language Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang.invitationLanguageLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Builder(
                builder: (context) {
                  final dropdownLanguages = widget.supportedLanguages != null &&
                          widget.supportedLanguages!.isNotEmpty
                      ? widget.supportedLanguages!
                      : lang.invitationLanguages.toList();

                  String activeLang = lang.activeInvitationLanguage;
                  if (!dropdownLanguages.contains(activeLang)) {
                    if (dropdownLanguages.isNotEmpty) {
                      activeLang = dropdownLanguages.first;
                    }
                  }

                  return DropdownButton<String>(
                    value: activeLang,
                    underline: const SizedBox(),
                    onChanged: (val) {
                      if (val != null) {
                        lang.activeInvitationLanguage = val;
                        final invProvider = context.read<InvitationProvider>();
                        invProvider.applyLanguageInstant(lang,
                            invitationLanguage: val);
                        setState(() {
                          _updateDimensions();
                        });
                        widget.onChanged();
                        invProvider.scheduleLanguageRefine(
                          force: true,
                          delay: const Duration(milliseconds: 400),
                          invitationLanguage: val,
                        );
                      }
                    },
                    items: dropdownLanguages
                        .map((l) => DropdownMenuItem(
                              value: l,
                              child: Text(l, style: const TextStyle(fontSize: 14)),
                            ))
                        .toList(),
                  );
                }
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String text, bool isSelected, VoidCallback onTap,
      {bool isItalic = false, bool isUnderline = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65,
        height: 35,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF94C66) : Colors.white,
          border: Border.all(
              color:
                  isSelected ? const Color(0xFFF94C66) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration:
                isUnderline ? TextDecoration.underline : TextDecoration.none,
            decorationColor: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _alignBtn(IconData icon, bool isSelected, TextAlign align) {
    return GestureDetector(
      onTap: () {
        setState(() {
          element.textAlign = align;
          _updateDimensions();
        });
        widget.onChanged();
      },
      child: Icon(icon,
          color: isSelected ? const Color(0xFFF94C66) : Colors.grey.shade600,
          size: 20),
    );
  }
}

// ─────────────────────────────────────────────────
// ROTATION BOTTOM SHEET
// ─────────────────────────────────────────────────
class RotationBottomSheet extends StatefulWidget {
  final String elementId;
  final VoidCallback onChanged;

  const RotationBottomSheet(
      {super.key, required this.elementId, required this.onChanged});

  @override
  State<RotationBottomSheet> createState() => _RotationBottomSheetState();
}

class _RotationBottomSheetState extends State<RotationBottomSheet> {
  late TemplateElement element;
  late double _originalRotation;

  @override
  void initState() {
    super.initState();
    final provider = context.read<InvitationProvider>();
    element = provider.elements.firstWhere((e) => e.id == widget.elementId);
    _originalRotation = element.rotation;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return _SheetWrapper(
      onCancel: () {
        element.rotation = _originalRotation;
        widget.onChanged();
        Navigator.pop(context);
      },
      onDone: () => Navigator.pop(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang.rotationLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text("${element.rotation.toInt()}",
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFF94C66),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: const Color(0xFFF94C66),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: element.rotation.clamp(-180.0, 180.0),
              min: -180,
              max: 180,
              onChanged: (val) {
                setState(() => element.rotation = val);
                widget.onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// OPACITY BOTTOM SHEET
// ─────────────────────────────────────────────────
class OpacityBottomSheet extends StatefulWidget {
  final String elementId;
  final VoidCallback onChanged;

  const OpacityBottomSheet(
      {super.key, required this.elementId, required this.onChanged});

  @override
  State<OpacityBottomSheet> createState() => _OpacityBottomSheetState();
}

class _OpacityBottomSheetState extends State<OpacityBottomSheet> {
  late TemplateElement element;
  late double _originalOpacity;

  @override
  void initState() {
    super.initState();
    final provider = context.read<InvitationProvider>();
    element = provider.elements.firstWhere((e) => e.id == widget.elementId);
    _originalOpacity = element.opacity;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return _SheetWrapper(
      onCancel: () {
        element.opacity = _originalOpacity;
        widget.onChanged();
        Navigator.pop(context);
      },
      onDone: () => Navigator.pop(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang.opacityLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text("${(element.opacity * 100).toInt()}",
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFF94C66),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: const Color(0xFFF94C66),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: element.opacity.clamp(0.0, 1.0),
              min: 0,
              max: 1,
              onChanged: (val) {
                setState(() => element.opacity = val);
                widget.onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// COLOR BOTTOM SHEET
// ─────────────────────────────────────────────────
class ColorBottomSheet extends StatefulWidget {
  final String elementId;
  final VoidCallback onChanged;

  const ColorBottomSheet(
      {super.key, required this.elementId, required this.onChanged});

  @override
  State<ColorBottomSheet> createState() => _ColorBottomSheetState();
}

class _ColorBottomSheetState extends State<ColorBottomSheet> {
  late TemplateElement element;
  late Color _originalColor;

  static const List<Color> _colors = [
    Colors.white,
    Colors.grey,
    Colors.black,
    Colors.red,
    Colors.brown,
    Colors.blue,
    Colors.pink,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<InvitationProvider>();
    element = provider.elements.firstWhere((e) => e.id == widget.elementId);
    _originalColor = element.color;
  }

  void _showCustomColorPicker() {
    showDialog(
      context: context,
      builder: (context) => _CustomColorPickerDialog(
        initialColor: element.color,
        onColorChanged: (newColor) {
          setState(() => element.color = newColor);
          widget.onChanged();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final contains = _colors.any((c) => c.value == element.color.value);
    final displayColors = List<Color>.from(_colors);
    if (!contains) {
      displayColors.add(element.color);
    }

    return _SheetWrapper(
      onCancel: () {
        element.color = _originalColor;
        widget.onChanged();
        Navigator.pop(context);
      },
      onDone: () => Navigator.pop(context),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: displayColors.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Rainbow button
            return GestureDetector(
              onTap: _showCustomColorPicker,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.red,
                      Colors.yellow,
                      Colors.green,
                      Colors.blue,
                      Colors.purple,
                      Colors.red
                    ],
                  ),
                ),
              ),
            );
          }
          final color = displayColors[index - 1];
          final isSelected = element.color.value == color.value;
          return GestureDetector(
            onTap: () {
              setState(() => element.color = color);
              widget.onChanged();
            },
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: isSelected
                  ? Icon(Icons.check,
                      size: 16,
                      color:
                          color == Colors.white ? Colors.black : Colors.white)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CUSTOM COLOR PICKER DIALOG
// ─────────────────────────────────────────────────
class _CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const _CustomColorPickerDialog({
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<_CustomColorPickerDialog> createState() =>
      _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late HSVColor _hsvColor;
  final GlobalKey _svAreaKey = GlobalKey();
  final GlobalKey _hueSliderKey = GlobalKey();
  Size? _svAreaSize;
  Size? _hueSliderSize;

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSizes();
    });
  }

  void _updateSizes() {
    final svRenderBox = _svAreaKey.currentContext?.findRenderObject() as RenderBox?;
    final hueRenderBox = _hueSliderKey.currentContext?.findRenderObject() as RenderBox?;
    setState(() {
      _svAreaSize = svRenderBox?.size;
      _hueSliderSize = hueRenderBox?.size;
    });
  }

  void _onHueChanged(double value) {
    setState(() {
      _hsvColor = _hsvColor.withHue(value);
    });
  }

  void _onSVChanged(double s, double v) {
    setState(() {
      _hsvColor = _hsvColor
          .withSaturation(s.clamp(0.0, 1.0))
          .withValue(v.clamp(0.0, 1.0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _hsvColor.toColor();
    final hexString =
        '#${currentColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.read<LanguageProvider>().chooseColorLabel,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Saturation/Value Area
            SizedBox(
              height: 150,
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (_svAreaSize != null) {
                    final s = (details.localPosition.dx / _svAreaSize!.width).clamp(0.0, 1.0);
                    final v = 1.0 - (details.localPosition.dy / _svAreaSize!.height).clamp(0.0, 1.0);
                    _onSVChanged(s, v);
                  }
                },
                onTapDown: (details) {
                  if (_svAreaSize != null) {
                    final s = (details.localPosition.dx / _svAreaSize!.width).clamp(0.0, 1.0);
                    final v = 1.0 - (details.localPosition.dy / _svAreaSize!.height).clamp(0.0, 1.0);
                    _onSVChanged(s, v);
                  }
                },
                child: Container(
                  key: _svAreaKey,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                      ],
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white,
                          HSVColor.fromAHSV(1.0, _hsvColor.hue, 1.0, 1.0)
                              .toColor(),
                        ],
                      ),
                      backgroundBlendMode: BlendMode.multiply,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: _hsvColor.saturation * (_svAreaSize?.width ?? 280) - 10,
                          top: (1.0 - _hsvColor.value) * (_svAreaSize?.height ?? 150) - 10,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              color: currentColor,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Hue Slider
            SizedBox(
              height: 20,
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (_hueSliderSize != null) {
                    final effectiveWidth = _hueSliderSize!.width - 20;
                    final hue = (details.localPosition.dx / effectiveWidth).clamp(0.0, 1.0) * 360.0;
                    _onHueChanged(hue);
                  }
                },
                onTapDown: (details) {
                  if (_hueSliderSize != null) {
                    final effectiveWidth = _hueSliderSize!.width - 20;
                    final hue = (details.localPosition.dx / effectiveWidth).clamp(0.0, 1.0) * 360.0;
                    _onHueChanged(hue);
                  }
                },
                child: Container(
                  key: _hueSliderKey,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: (_hsvColor.hue / 360.0) * ((_hueSliderSize?.width ?? 280) - 20),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade400),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 2)
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Hex display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(hexString,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, letterSpacing: 1)),
                  const Spacer(),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.read<LanguageProvider>().cancel,
                      style: const TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    widget.onColorChanged(currentColor);
                    Navigator.pop(context);
                  },
                  child: Text(context.read<LanguageProvider>().done,
                      style: const TextStyle(color: Color(0xFFF94C66))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    return 480.0;
  }
  return 960.0;
}

