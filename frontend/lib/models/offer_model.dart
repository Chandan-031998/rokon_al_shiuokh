class OfferModel {
  final int id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? bannerUrl;
  final String? discountType;
  final double discountValue;
  final int? productId;
  final int? categoryId;
  final int? branchId;
  final String? startsAt;
  final String? endsAt;
  final bool isActive;

  const OfferModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.bannerUrl,
    this.discountType,
    this.discountValue = 0,
    this.productId,
    this.categoryId,
    this.branchId,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      subtitle: (json['subtitle'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
      bannerUrl: (json['banner_url'] as String?)?.trim(),
      discountType: (json['discount_type'] as String?)?.trim(),
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
      productId: (json['product_id'] as num?)?.toInt(),
      categoryId: (json['category_id'] as num?)?.toInt(),
      branchId: (json['branch_id'] as num?)?.toInt(),
      startsAt: (json['starts_at'] as String?)?.trim(),
      endsAt: (json['ends_at'] as String?)?.trim(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
