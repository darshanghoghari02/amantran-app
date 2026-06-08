import 'package:flutter/material.dart';
import '../../../models/template_element.dart';
import '../../../utils/image_resolver.dart';
import 'static_element.dart';

/// A single page in the preview that renders a background and all elements for that page.
class PreviewPage extends StatelessWidget {
  final String backgroundImage;
  final List<TemplateElement> elements;
  final int pageIndex;
  final String activeLanguage;
  final double canvasWidth;
  final double canvasHeight;

  const PreviewPage({
    super.key,
    required this.backgroundImage,
    required this.elements,
    required this.pageIndex,
    required this.activeLanguage,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Filter elements for this specific page and sort by zIndex ascending
    final pageElements = elements.where((e) => e.pageIndex == pageIndex).toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;

        // The raw canvas coordinates are relative to canvasWidth and canvasHeight
        final double scaleX = width / canvasWidth;
        final double scaleY = height / canvasHeight;

        return Container(
          width: width,
          height: height,
          color: Colors.white,
          child: Stack(
            children: [
              // 🔹 BACKGROUND IMAGE
              Positioned.fill(
                child: isNetworkImage(backgroundImage)
                    ? Image.network(
                        resolveImageUrl(backgroundImage),
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        cleanAssetPath(backgroundImage.isNotEmpty ? backgroundImage : 'assets/images/banner_image.png'),
                        fit: BoxFit.cover,
                      ),
              ),

              // 🔹 ELEMENTS
              ...pageElements.map((el) => StaticElement(
                    element: el,
                    activeLanguage: activeLanguage,
                    scaleX: scaleX,
                    scaleY: scaleY,
                  )),
            ],
          ),
        );
      },
    );
  }
}
