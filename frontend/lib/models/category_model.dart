class CategoryModel {
  final int id;
  final String name;
  final String? nameAr;
  final String? imageUrl;
  final String? iconKey;
  final int sortOrder;
  final bool isActive;
  final int productCount;

  const CategoryModel({
    required this.id,
    required this.name,
    this.nameAr,
    this.imageUrl,
    this.iconKey,
    this.sortOrder = 0,
    this.isActive = true,
    this.productCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      nameAr: json['name_ar'] as String?,
      imageUrl: json['image_url'] as String?,
      iconKey: json['icon_key'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
    );
  }
}
