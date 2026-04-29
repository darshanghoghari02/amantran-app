import 'package:flutter/material.dart';
import '../../../models/template_model.dart';
import '../../../models/template_element.dart';
import 'static_element.dart';

/// A single page in the preview that renders a background and all elements for that page.
class PreviewPage extends StatelessWidget {
  final TemplateModel template;
  final List<TemplateElement> elements;
  final int pageIndex;
  final bool isGujarati;

  const PreviewPage({
    super.key,
    required this.template,
    required this.elements,
    required this.pageIndex,
    this.isGujarati = true,
  });

  @override
  Widget build(BuildContext context) {
    // Filter elements for this specific page
    final pageElements = elements.where((e) => e.pageIndex == pageIndex).toList();

    return Container(
      width: template.canvasWidth,
      height: template.canvasHeight,
      color: Colors.white,
      child: Stack(
        children: [
          // 🔹 BACKGROUND IMAGE
          Positioned.fill(
            child: Image.asset(
              template.getPageImage(pageIndex),
              fit: BoxFit.cover,
            ),
          ),

          // 🔹 ELEMENTS
          ...pageElements.map((el) => StaticElement(
                element: el,
                isGujarati: isGujarati,
              )),
        ],
      ),
    );
  }
}
