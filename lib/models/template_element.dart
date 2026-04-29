import 'package:flutter/material.dart';

/// Types of elements that can be placed on the canvas
enum ElementType {
  text,
  image,
  divider,
  decorative,
}

/// A single element on the Kankotri editor canvas.
/// Each element has position, size, styling, and bilingual content.
class TemplateElement {
  // 🔴 IDENTITY
  final String id;
  final ElementType type;

  // 🔴 PAGE (which page this element belongs to, 0-indexed)
  final int pageIndex;

  // 🔴 CONTENT (BILINGUAL)
  String content;           // English or default text
  String contentGujarati;   // Gujarati translation

  // 🔴 POSITION (relative to canvas, in logical pixels)
  double x;
  double y;

  // 🔴 SIZE
  double width;
  double height;

  // 🔴 TEXT STYLING
  double fontSize;
  String fontFamily;
  Color color;
  FontWeight fontWeight;
  TextAlign textAlign;
  FontStyle fontStyle;
  double letterSpacing;
  double lineHeight;

  // 🔴 ELEMENT BEHAVIOR
  bool isEditable;   // Can user change text content?
  bool isMovable;    // Can user drag element?
  bool isResizable;  // Can user resize element?
  bool isVisible;    // Is element currently visible?

  // 🔴 DECORATIVE
  double opacity;
  String? assetPath;  // For image/decorative types

  TemplateElement({
    required this.id,
    this.type = ElementType.text,
    this.pageIndex = 0,
    this.content = '',
    this.contentGujarati = '',
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
    this.isEditable = true,
    this.isMovable = true,
    this.isResizable = true,
    this.isVisible = true,
    this.opacity = 1.0,
    this.assetPath,
  });

  /// Create a deep copy of this element
  TemplateElement copyWith({
    String? id,
    ElementType? type,
    int? pageIndex,
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
    String? assetPath,
  }) {
    return TemplateElement(
      id: id ?? this.id,
      type: type ?? this.type,
      pageIndex: pageIndex ?? this.pageIndex,
      content: content ?? this.content,
      contentGujarati: contentGujarati ?? this.contentGujarati,
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
      assetPath: assetPath ?? this.assetPath,
    );
  }

  /// Get the display text based on language mode
  String getDisplayText(bool isGujarati) {
    if (isGujarati && contentGujarati.isNotEmpty) {
      return contentGujarati;
    }
    return content;
  }
}
