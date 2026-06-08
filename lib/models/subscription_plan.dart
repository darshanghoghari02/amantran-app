class SubscriptionPlanModel {
  final String id;
  final String name;
  final double price;
  final String description;
  final bool isActive;
  final List<String> includedCategories;
  final List<String> includedTemplateIds;

  final String durationType;
  final int durationDays;
  final String? customStartDate;
  final String? customEndDate;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.isActive,
    required this.includedCategories,
    required this.includedTemplateIds,
    this.durationType = 'monthly',
    this.durationDays = 30,
    this.customStartDate,
    this.customEndDate,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json, String documentId) {
    return SubscriptionPlanModel(
      id: documentId,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      includedCategories: (json['includedCategories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      includedTemplateIds: (json['includedTemplateIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      durationType: json['durationType'] as String? ?? 'monthly',
      durationDays: json['durationDays'] as int? ?? 30,
      customStartDate: json['customStartDate'] as String?,
      customEndDate: json['customEndDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'isActive': isActive,
      'includedCategories': includedCategories,
      'includedTemplateIds': includedTemplateIds,
      'durationType': durationType,
      'durationDays': durationDays,
      'customStartDate': customStartDate,
      'customEndDate': customEndDate,
    };
  }
}
