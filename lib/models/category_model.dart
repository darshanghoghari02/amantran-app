import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final String coverImage;
  final bool isActive;
  final int displayOrder;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.coverImage,
    this.isActive = true,
    required this.displayOrder,
  });

  static String formatDisplayName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json, String documentId) {
    final rawName = json['name'] as String? ?? '';
    return CategoryModel(
      id: documentId,
      name: formatDisplayName(rawName),
      slug: json['slug'] as String? ?? '',
      coverImage: (json['coverImage'] ?? json['iconUrl']) as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'coverImage': coverImage,
      'isActive': isActive,
      'displayOrder': displayOrder,
    };
  }
}
