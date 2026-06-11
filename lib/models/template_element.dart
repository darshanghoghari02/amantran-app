import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/font_service.dart';
import '../services/language_registry.dart';

/// Types of elements that can be placed on the canvas
enum ElementType {
  text,
  image,
  divider,
  decorative,
  sticker,
}

/// A single element on the Kankotri editor canvas.
class TemplateElement {
  final String id;
  final ElementType type;
  final int pageIndex;

  // Internal multi-lingual content map
  final Map<String, String> contentMap;

  double x;
  double y;
  double width;
  double height;

  // Text Styling
  double fontSize;
  String fontFamily;
  Color color;
  FontWeight fontWeight;
  TextAlign textAlign;
  FontStyle fontStyle;
  double letterSpacing;
  double lineHeight;
  TextDecoration textDecoration;

  // Element Behaviors
  bool isEditable;
  bool isMovable;
  bool isResizable;
  bool isVisible;

  // Formatting & Custom URLs
  double opacity;
  double rotation;
  int zIndex;
  String? assetPath; // image asset or URL
  String? mapUrl;

  TemplateElement({
    required this.id,
    this.type = ElementType.text,
    this.pageIndex = 0,
    Map<String, String>? contentMap,
    String content = '',
    String contentGujarati = '',
    this.x = 0,
    this.y = 0,
    this.width = 200,
    this.height = 40,
    this.fontSize = 16,
    this.fontFamily = 'Roboto',
    this.color = Colors.black,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.center,
    this.fontStyle = FontStyle.normal,
    this.letterSpacing = 0,
    this.lineHeight = 1.4,
    this.textDecoration = TextDecoration.none,
    this.isEditable = true,
    this.isMovable = true,
    this.isResizable = true,
    this.isVisible = true,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.zIndex = 0,
    this.assetPath,
    this.mapUrl,
  }) : this.contentMap = contentMap ?? {
          'en': content,
          'gu': contentGujarati,
        };

  // Getters/setters to preserve absolute backwards compatibility with existing UI/Provider code
  String get content {
    return sanitizeCorruptedText(contentMap['en'] ?? '');
  }

  set content(String val) {
    contentMap['en'] = sanitizeCorruptedText(val);
  }

  String get contentGujarati {
    return sanitizeCorruptedText(contentMap['gu'] ?? '');
  }

  set contentGujarati(String val) {
    contentMap['gu'] = sanitizeCorruptedText(val);
  }

  String? get imageUrl => assetPath;
  set imageUrl(String? val) {
    assetPath = val;
  }

  factory TemplateElement.fromJson(Map<String, dynamic> json) {
    final Map<String, String> cMap = {};
    
    // Parse translations map first (supports both lowercase codes and full language names)
    if (json['translations'] is Map) {
      (json['translations'] as Map).forEach((k, v) {
        final key = k.toString().trim();
        final code = LanguageRegistry.instance.codeFor(key);
        cMap[code] = sanitizeCorruptedText(v.toString());
      });
    }

    // Fallbacks if translations map is missing or incomplete
    if (json['content'] is Map) {
      (json['content'] as Map).forEach((k, v) {
        final key = k.toString().trim();
        final code = LanguageRegistry.instance.codeFor(key);
        cMap[code] = sanitizeCorruptedText(v.toString());
      });
    } else if (json['content'] is String) {
      if (!cMap.containsKey('en')) cMap['en'] = sanitizeCorruptedText(json['content'] as String);
      if (json['contentGujarati'] != null && !cMap.containsKey('gu')) {
        cMap['gu'] = sanitizeCorruptedText(json['contentGujarati'] as String);
      }
    }

    if (json['text'] is String) {
      final textVal = sanitizeCorruptedText(json['text'] as String);
      for (final code in ['en', 'gu', 'hi', 'mr', 'pa', 'ta', 'ur', 'ks', 'sa', 'or', 'as']) {
        if (!cMap.containsKey(code)) cMap[code] = textVal;
      }
    }

    // Preserve older structure root-level strings
    if (json['content'] is String && !cMap.containsKey('en')) {
      cMap['en'] = sanitizeCorruptedText(json['content'] as String);
    }
    if (json['contentGujarati'] is String && !cMap.containsKey('gu')) {
      cMap['gu'] = sanitizeCorruptedText(json['contentGujarati'] as String);
    }

    return TemplateElement(
      id: json['id']?.toString() ?? '',
      type: ElementType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () {
          if (json['type'] == 'sticker') return ElementType.sticker;
          return ElementType.text;
        },
      ),
      pageIndex: json['pageIndex'] as int? ?? 0,
      contentMap: cMap,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 200.0,
      height: (json['height'] as num?)?.toDouble() ?? 40.0,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      fontFamily: json['fontFamily']?.toString() ?? 'Roboto',
      color: _parseColor(json['color'] ?? json['colorValue'] ?? json['color_value'] ?? json['colorString'] ?? json['textColor'] ?? json['fontColor']),
      fontWeight: _parseFontWeight(json['fontWeight'] ?? json['fontWeightIndex']),
      textAlign: TextAlign.values.firstWhere(
        (e) => e.name == json['textAlign'] || e.name == json['alignment'],
        orElse: () => TextAlign.center,
      ),
      fontStyle: FontStyle.values.firstWhere(
        (e) => e.name == json['fontStyle'],
        orElse: () => FontStyle.normal,
      ),
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.4,
      textDecoration: _stringToTextDecoration(json['textDecoration']?.toString()),
      isEditable: json['isEditable'] as bool? ?? true,
      isMovable: json['isMovable'] as bool? ?? true,
      isResizable: json['isResizable'] as bool? ?? true,
      isVisible: json['isVisible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      assetPath: json['imagePath'] ?? json['imageUrl'] ?? json['assetPath']?.toString(),
      mapUrl: json['mapUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'pageIndex': pageIndex,
      'content': contentMap,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'color': '#${color.value.toRadixString(16).padLeft(8, '0')}',
      'fontWeight': _fontWeightToString(fontWeight),
      'textAlign': textAlign.name,
      'fontStyle': fontStyle.name,
      'letterSpacing': letterSpacing,
      'lineHeight': lineHeight,
      'textDecoration': _textDecorationToString(textDecoration),
      'isEditable': isEditable,
      'isMovable': isMovable,
      'isResizable': isResizable,
      'isVisible': isVisible,
      'opacity': opacity,
      'rotation': rotation,
      'zIndex': zIndex,
      'imageUrl': assetPath,
      'imagePath': assetPath,
      'assetPath': assetPath,
      'mapUrl': mapUrl,
      'translations': contentMap.map((code, text) {
        final name = LanguageRegistry.instance.nameForCode(code) ?? code;
        final displayName = name.isEmpty
            ? name
            : '${name[0].toUpperCase()}${name.substring(1)}';
        return MapEntry(displayName, text);
      }),
    };
  }

  static Color _parseColor(dynamic colorValue) {
    if (colorValue == null) return Colors.black;
    if (colorValue is int) return Color(colorValue);
    if (colorValue is Map) {
      try {
        final r = (colorValue['r'] ?? colorValue['red'] ?? 0) as num;
        final g = (colorValue['g'] ?? colorValue['green'] ?? 0) as num;
        final b = (colorValue['b'] ?? colorValue['blue'] ?? 0) as num;
        final a = (colorValue['a'] ?? colorValue['alpha'] ?? 1.0) as num;
        return Color.fromARGB(
          (a.toDouble() * 255).round().clamp(0, 255),
          r.toInt().clamp(0, 255),
          g.toInt().clamp(0, 255),
          b.toInt().clamp(0, 255),
        );
      } catch (_) {}
    }
    if (colorValue is String) {
      String str = colorValue.trim();
      // Try parsing as decimal integer first
      final decVal = int.tryParse(str, radix: 10);
      if (decVal != null) {
        return Color(decVal);
      }

      str = str.toLowerCase();
      if (str.startsWith('rgb')) {
        try {
          final RegExp regExp = RegExp(r'\d+\.?\d*');
          final matches = regExp.allMatches(str).map((m) => double.parse(m.group(0)!)).toList();
          if (matches.length >= 3) {
            int r = matches[0].round().clamp(0, 255);
            int g = matches[1].round().clamp(0, 255);
            int b = matches[2].round().clamp(0, 255);
            double a = matches.length >= 4 ? matches[3] : 1.0;
            int alphaInt = (a * 255).round().clamp(0, 255);
            return Color.fromARGB(alphaInt, r, g, b);
          }
        } catch (_) {}
      }
      
      String hexString = str
          .replaceAll('#', '')
          .replaceAll('0x', '')
          .trim();
          
      if (hexString.length == 6) {
        hexString = 'ff$hexString';
      } else if (hexString.length == 8) {
        if (!hexString.startsWith('ff')) {
          // Convert RGBA to ARGB
          hexString = hexString.substring(6, 8) + hexString.substring(0, 6);
        }
      }
      return Color(int.tryParse(hexString, radix: 16) ?? Colors.black.value);
    }
    return Colors.black;
  }

  static FontWeight _parseFontWeight(dynamic weight) {
    if (weight == null) return FontWeight.normal;
    if (weight is int) {
      if (weight >= 100 && weight <= 900) {
        switch (weight) {
          case 100: return FontWeight.w100;
          case 200: return FontWeight.w200;
          case 300: return FontWeight.w300;
          case 400: return FontWeight.w400;
          case 500: return FontWeight.w500;
          case 600: return FontWeight.w600;
          case 700: return FontWeight.w700;
          case 800: return FontWeight.w800;
          case 900: return FontWeight.w900;
        }
      }
      if (weight >= 0 && weight <= 8) {
        switch (weight) {
          case 0: return FontWeight.w100;
          case 1: return FontWeight.w200;
          case 2: return FontWeight.w300;
          case 3: return FontWeight.w400;
          case 4: return FontWeight.w500;
          case 5: return FontWeight.w600;
          case 6: return FontWeight.w700;
          case 7: return FontWeight.w800;
          case 8: return FontWeight.w900;
        }
      }
    }
    String weightStr = weight.toString().toLowerCase();
    if (weightStr.contains('100')) return FontWeight.w100;
    if (weightStr.contains('200')) return FontWeight.w200;
    if (weightStr.contains('300')) return FontWeight.w300;
    if (weightStr.contains('400')) return FontWeight.w400;
    if (weightStr.contains('500')) return FontWeight.w500;
    if (weightStr.contains('600')) return FontWeight.w600;
    if (weightStr.contains('700')) return FontWeight.w700;
    if (weightStr.contains('800')) return FontWeight.w800;
    if (weightStr.contains('900')) return FontWeight.w900;
    if (weightStr.contains('bold')) return FontWeight.bold;
    return FontWeight.normal;
  }

  static String _fontWeightToString(FontWeight fw) {
    if (fw == FontWeight.w100) return 'w100';
    if (fw == FontWeight.w200) return 'w200';
    if (fw == FontWeight.w300) return 'w300';
    if (fw == FontWeight.w400) return 'w400';
    if (fw == FontWeight.w500) return 'w500';
    if (fw == FontWeight.w600) return 'w600';
    if (fw == FontWeight.w700) return 'w700';
    if (fw == FontWeight.w800) return 'w800';
    if (fw == FontWeight.w900) return 'w900';
    if (fw == FontWeight.bold) return 'bold';
    return 'normal';
  }

  static TextDecoration _stringToTextDecoration(String? str) {
    switch (str) {
      case 'underline':
        return TextDecoration.underline;
      case 'lineThrough':
        return TextDecoration.lineThrough;
      case 'overline':
        return TextDecoration.overline;
      default:
        return TextDecoration.none;
    }
  }

  static String _textDecorationToString(TextDecoration dec) {
    if (dec == TextDecoration.underline) return 'underline';
    if (dec == TextDecoration.lineThrough) return 'lineThrough';
    if (dec == TextDecoration.overline) return 'overline';
    return 'none';
  }

  TemplateElement copyWith({
    String? id,
    ElementType? type,
    int? pageIndex,
    Map<String, String>? contentMap,
    String? content,
    String? contentGujarati,
    double? x,
    double? y,
    double? width,
    double? height,
    double? fontSize,
    String? fontFamily,
    Color? color,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? lineHeight,
    bool? isEditable,
    bool? isMovable,
    bool? isResizable,
    bool? isVisible,
    double? opacity,
    double? rotation,
    int? zIndex,
    TextDecoration? textDecoration,
    String? assetPath,
    String? mapUrl,
  }) {
    final Map<String, String> newContentMap = Map<String, String>.from(contentMap ?? this.contentMap);
    if (content != null) newContentMap['en'] = content;
    if (contentGujarati != null) newContentMap['gu'] = contentGujarati;

    return TemplateElement(
      id: id ?? this.id,
      type: type ?? this.type,
      pageIndex: pageIndex ?? this.pageIndex,
      contentMap: newContentMap,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      color: color ?? this.color,
      fontWeight: fontWeight ?? this.fontWeight,
      textAlign: textAlign ?? this.textAlign,
      fontStyle: fontStyle ?? this.fontStyle,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      isEditable: isEditable ?? this.isEditable,
      isMovable: isMovable ?? this.isMovable,
      isResizable: isResizable ?? this.isResizable,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      textDecoration: textDecoration ?? this.textDecoration,
      assetPath: assetPath ?? this.assetPath,
      mapUrl: mapUrl ?? this.mapUrl,
    );
  }

  String getDisplayText(String activeLanguage) {
    final String code = _getLanguageCode(activeLanguage);
    final String? text = contentMap[code];
    if (text != null && text.isNotEmpty) {
      return sanitizeCorruptedText(text);
    }
    // Never fall back to a different regional script — only English
    final en = contentMap['en'] ?? '';
    if (en.isNotEmpty) return sanitizeCorruptedText(en);
    return '';
  }

  static bool hasGujaratiScript(String text) =>
      text.runes.any((r) => r >= 0xA80 && r <= 0xAFF);

  static bool hasArabicScript(String text) =>
      text.runes.any((r) => (r >= 0x600 && r <= 0x6FF) || (r >= 0x750 && r <= 0x77F));

  static bool hasDevanagariScript(String text) =>
      text.runes.any((r) => r >= 0x900 && r <= 0x97F);

  static bool hasGurmukhiScript(String text) =>
      text.runes.any((r) => r >= 0xA00 && r <= 0xA7F);

  static bool isTranslationValid(
      String result, String targetLang, String source) {
    if (result.isEmpty) return false;
    if (result.trim() == source.trim()) return false;

    final code = LanguageRegistry.instance.codeFor(targetLang);
    switch (code) {
      case 'ur':
        if (hasArabicScript(result)) return true;
        return !hasGujaratiScript(result);
      case 'gu':
        return hasGujaratiScript(result) || !hasArabicScript(result);
      case 'hi':
      case 'mr':
      case 'sa':
      case 'ne':
        return hasDevanagariScript(result) || !hasGujaratiScript(source);
      case 'pa':
        return hasGurmukhiScript(result) || !hasGujaratiScript(source);
      case 'ta':
        return result.runes.any((r) => r >= 0xB80 && r <= 0xBFF) ||
            !hasGujaratiScript(source);
      case 'bn':
        return result.runes.any((r) => r >= 0x980 && r <= 0x9FF) ||
            !hasGujaratiScript(source);
      default:
        return !hasGujaratiScript(result) || !hasGujaratiScript(source);
    }
  }

  TextStyle getTextStyleForLanguage(String activeLanguage, {double scale = 1.0}) {
    final baseStyle = getTextStyle(scale: scale);
    final code = languageCodeFor(activeLanguage);
    switch (code) {
      case 'ur':
      case 'ks':
        return GoogleFonts.notoNastaliqUrdu(textStyle: baseStyle);
      case 'pa':
        return GoogleFonts.notoSansGurmukhi(textStyle: baseStyle);
      case 'gu':
        return baseStyle.copyWith(fontFamily: 'Noto Serif Gujarati');
      case 'hi':
      case 'mr':
      case 'sa':
      case 'ne':
        return GoogleFonts.notoSansDevanagari(textStyle: baseStyle);
      case 'bn':
      case 'as':
        return GoogleFonts.notoSansBengali(textStyle: baseStyle);
      case 'ta':
        return GoogleFonts.notoSansTamil(textStyle: baseStyle);
      case 'te':
        return GoogleFonts.notoSansTelugu(textStyle: baseStyle);
      case 'kn':
        return GoogleFonts.notoSansKannada(textStyle: baseStyle);
      case 'ml':
        return GoogleFonts.notoSansMalayalam(textStyle: baseStyle);
      case 'or':
        return GoogleFonts.notoSansOriya(textStyle: baseStyle);
      default:
        return baseStyle;
    }
  }

  static TextDirection textDirectionFor(String activeLanguage) {
    return LanguageRegistry.instance.isRtl(activeLanguage)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  static String languageCodeFor(String activeLanguage) {
    return LanguageRegistry.instance.codeFor(activeLanguage);
  }

  static String _getLanguageCode(String activeLanguage) =>
      languageCodeFor(activeLanguage);

  void setLocalizedText(String activeLanguage, String text) {
    contentMap[languageCodeFor(activeLanguage)] = sanitizeCorruptedText(text);
    if (languageCodeFor(activeLanguage) == 'gu') {
      contentGujarati = text;
    }
  }

  String getLocalizedText(String activeLanguage) {
    return sanitizeCorruptedText(
        contentMap[languageCodeFor(activeLanguage)] ?? '');
  }

  TextStyle getTextStyle({double scale = 1.0}) {
    final double fs = fontSize * scale;
    final baseStyle = TextStyle(
      fontSize: fs,
      color: color,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: textDecoration,
      letterSpacing: letterSpacing * scale,
      height: lineHeight,
    );

    final String lowerFamily = fontFamily.toLowerCase();

    // 1. Check locally bundled fonts case-insensitively
    if (lowerFamily == 'kap011') {
      return baseStyle.copyWith(fontFamily: 'KAP011');
    }
    if (lowerFamily == 'noto serif gujarati') {
      return baseStyle.copyWith(fontFamily: 'Noto Serif Gujarati');
    }
    if (lowerFamily == 'kankotri') {
      return baseStyle.copyWith(fontFamily: 'Kankotri');
    }
    if (lowerFamily.startsWith('custom_')) {
      return baseStyle.copyWith(fontFamily: fontFamily); // Keep original case for custom_
    }

    // 2. Check dynamically registered fonts case-insensitively
    String? matchedRegisteredFamily;
    for (final reg in FontService.registeredFamilies) {
      if (reg.toLowerCase() == lowerFamily) {
        matchedRegisteredFamily = reg;
        break;
      }
    }
    if (matchedRegisteredFamily != null) {
      return baseStyle.copyWith(fontFamily: matchedRegisteredFamily);
    }

    // 3. Try to resolve via the GoogleFonts package (for standard Google Fonts).
    try {
      return GoogleFonts.getFont(fontFamily, textStyle: baseStyle);
    } catch (_) {
      // 4. Final fallback: let Flutter resolve the fontFamily name directly.
      return baseStyle.copyWith(fontFamily: fontFamily);
    }
  }
}

// Keep translate functions inside template_element.dart for compatibility with existing imports
String translateGujaratiToHindi(String text) {
  if (text.isEmpty) return text;
  final StringBuffer sb = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final int code = text.codeUnitAt(i);
    if (code >= 0x0A80 && code <= 0x0AFF) {
      sb.writeCharCode(code - 0x0180);
    } else {
      sb.write(text[i]);
    }
  }
  return sb.toString();
}

String translateGujaratiToPunjabi(String text) {
  if (text.isEmpty) return text;
  final StringBuffer sb = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final int code = text.codeUnitAt(i);
    if (code >= 0x0A80 && code <= 0x0AFF) {
      sb.writeCharCode(code - 0x0080);
    } else {
      sb.write(text[i]);
    }
  }
  return sb.toString();
}

String translateGujaratiToUrdu(String text) {
  return text; // Fallback representation
}

String sanitizeCorruptedText(String text) {
  return text
      .replaceAll('ચિઇ', 'ચિ.')
      .replaceAll('તાઇ', 'તા.')
      .replaceAll('શ્રીલ', 'શ્રી,');
}
