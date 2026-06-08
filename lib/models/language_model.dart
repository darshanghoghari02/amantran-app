class LanguageModel {
  final String code;
  final String name;
  final bool isActive;

  LanguageModel({
    required this.code,
    required this.name,
    this.isActive = true,
  });

  factory LanguageModel.fromJson(Map<String, dynamic> json, String documentId) {
    return LanguageModel(
      code: json['code'] as String? ?? documentId,
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'isActive': isActive,
    };
  }
}
