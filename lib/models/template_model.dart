import 'package:flutter/material.dart';
import 'template_element.dart';

class TemplateModel {
  // 🔴 IDENTITY
  final String id;
  final String name;

  // 🔴 TEMPLATE FOLDER (Contains page1.jpg through page6.jpg)
  final String folderPath;

  // 🔴 OPTIONAL TEXT POSITIONS (kept for backward compatibility)
  final double groomTop;
  final double brideTop;
  final double dateTop;

  // 🔥 DYNAMIC ELEMENTS (NEW)
  final List<TemplateElement> elements;

  // 🔥 CANVAS REFERENCE SIZE
  final double canvasWidth;
  final double canvasHeight;

  // 🔥 UI THEMING (KEPT FROM ORIGINAL)
  final Color primaryColor;
  final Color textColor;
  final String fontFamily;

  TemplateModel({
    this.id = '',
    this.name = '',
    required this.folderPath,

    // Default positions (safe fallback — KEPT)
    this.groomTop = 260,
    this.brideTop = 300,
    this.dateTop = 340,

    // Dynamic elements (NEW)
    this.elements = const [],

    // Canvas reference size
    this.canvasWidth = 360,
    this.canvasHeight = 640,

    // Default theme (KEPT)
    this.primaryColor = Colors.red,
    this.textColor = Colors.black,
    this.fontFamily = 'Farsan',
  });

  /// The main thumbnail image for the template selection screen
  String get image => '$folderPath/page1.jpg';

  /// Get the background image for a specific page index (0-5)
  String getPageImage(int pageIndex) {
    return '$folderPath/page${pageIndex + 1}.jpg';
  }
}
