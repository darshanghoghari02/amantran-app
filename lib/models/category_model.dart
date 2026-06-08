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

  factory CategoryModel.fromJson(Map<String, dynamic> json, String documentId) {
    return CategoryModel(
      id: documentId,
      name: json['name'] as String? ?? '',
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
