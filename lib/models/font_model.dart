class FontModel {
  final String fontFamily;
  final String fontUrl;
  final bool isActive;

  FontModel({
    required this.fontFamily,
    required this.fontUrl,
    this.isActive = true,
  });

  factory FontModel.fromJson(Map<String, dynamic> json) {
    return FontModel(
      fontFamily: json['fontFamily'] as String? ?? '',
      fontUrl: json['fontUrl'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontFamily': fontFamily,
      'fontUrl': fontUrl,
      'isActive': isActive,
    };
  }
}
