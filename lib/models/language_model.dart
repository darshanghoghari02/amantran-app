class LanguageModel {
  final String code;
  final String name;
  final bool isActive;
  final String? scriptSample;

  LanguageModel({
    required this.code,
    required this.name,
    this.isActive = true,
    this.scriptSample,
  });

  factory LanguageModel.fromJson(Map<String, dynamic> json, String documentId) {
    return LanguageModel(
      code: json['code'] as String? ?? documentId,
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      scriptSample: json['scriptSample'] as String? ??
          json['script'] as String? ??
          json['scriptPreview'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'isActive': isActive,
      if (scriptSample != null) 'scriptSample': scriptSample,
    };
  }
}
