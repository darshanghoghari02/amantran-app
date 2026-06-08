import 'template_element.dart';

class PageModel {
  final String id;
  final String backgroundImage;
  final int pageNumber;
  final double width;
  final double height;
  final List<TemplateElement> elements;

  PageModel({
    required this.id,
    required this.backgroundImage,
    required this.pageNumber,
    required this.width,
    required this.height,
    this.elements = const [],
  });

  factory PageModel.fromJson(Map<String, dynamic> json, String documentId) {
    var elementsList = json['elements'] as List? ?? [];
    List<TemplateElement> parsedElements = [];
    
    for (var elementData in elementsList) {
      if (elementData is Map) {
        parsedElements.add(TemplateElement.fromJson(Map<String, dynamic>.from(elementData)));
      }
    }

    return PageModel(
      id: documentId,
      backgroundImage: json['backgroundImage'] as String? ?? '',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 1080.0,
      height: (json['height'] as num?)?.toDouble() ?? 1920.0,
      elements: parsedElements,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backgroundImage': backgroundImage,
      'pageNumber': pageNumber,
      'width': width,
      'height': height,
      'elements': elements.map((e) => e.toJson()).toList(),
    };
  }
}
