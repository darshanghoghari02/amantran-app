import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateModel {
  final String id;
  final String title;
  final String slug;
  final String categoryId;
  final String thumbnail;
  final String previewImage;
  final bool isPremium;
  final bool isActive;
  final List<String> supportedLanguages;
  final List<String> supportedFonts;
  final int pagesCount;
  final double? singlePurchasePrice;
  final bool includedInMonthlyPlan;
  final bool includedInYearlyPlan;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TemplateModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.categoryId,
    required this.thumbnail,
    required this.previewImage,
    this.isPremium = false,
    this.isActive = true,
    this.supportedLanguages = const [],
    this.supportedFonts = const [],
    this.pagesCount = 0,
    this.singlePurchasePrice,
    this.includedInMonthlyPlan = true,
    this.includedInYearlyPlan = true,
    this.createdAt,
    this.updatedAt,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json, String documentId) {
    var languages = json['supportedLanguages'] as List? ?? [];
    var fonts = json['supportedFonts'] as List? ?? [];

    return TemplateModel(
      id: documentId,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      previewImage: json['previewImage'] as String? ?? json['thumbnail'] as String? ?? '',
      isPremium: json['isPremium'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      supportedLanguages: languages.map((e) => e.toString()).toList(),
      supportedFonts: fonts.map((e) => e.toString()).toList(),
      pagesCount: (json['pagesCount'] as num?)?.toInt() ?? 0,
      singlePurchasePrice: (json['singlePurchasePrice'] as num?)?.toDouble(),
      includedInMonthlyPlan: json['includedInMonthlyPlan'] as bool? ?? true,
      includedInYearlyPlan: json['includedInYearlyPlan'] as bool? ?? true,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'slug': slug,
      'categoryId': categoryId,
      'thumbnail': thumbnail,
      'previewImage': previewImage,
      'isPremium': isPremium,
      'isActive': isActive,
      'supportedLanguages': supportedLanguages,
      'supportedFonts': supportedFonts,
      'pagesCount': pagesCount,
      'singlePurchasePrice': singlePurchasePrice,
      'includedInMonthlyPlan': includedInMonthlyPlan,
      'includedInYearlyPlan': includedInYearlyPlan,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is Timestamp) return dateValue.toDate();
    if (dateValue is String) return DateTime.tryParse(dateValue);
    return null;
  }

  // Backwards compatibility for templates list screen
  String get name => title;
  int get totalPages => pagesCount > 0 ? pagesCount : 1;
  String getPageImage(int index) => previewImage;
}
