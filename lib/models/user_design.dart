import 'template_model.dart';
import 'template_element.dart';

class UserDesign {
  final String id;
  final TemplateModel template;
  final List<TemplateElement> elements;
  final DateTime updatedAt;
  final bool isDraft;
  final String? pdfName;
  
  UserDesign({
    required this.id,
    required this.template,
    required this.elements,
    required this.updatedAt,
    this.isDraft = true,
    this.pdfName,
  });

  UserDesign copyWith({bool? isDraft, DateTime? updatedAt, String? pdfName}) {
    return UserDesign(
      id: id,
      template: template,
      // Deep copy elements to avoid reference sharing
      elements: elements.map((e) => e.copyWith()).toList(),
      updatedAt: updatedAt ?? this.updatedAt,
      isDraft: isDraft ?? this.isDraft,
      pdfName: pdfName ?? this.pdfName,
    );
  }
}
