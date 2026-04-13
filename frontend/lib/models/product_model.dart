class ProductModel {
  final int id;
  final String name;
  final double price;
  final int categoryId;
  final int? branchId;
  final String? nameAr;
  final String? imageUrl;
  final String? description;
  final String? sku;
  final int stockQty;
  final String? packSize;
  final bool isFeatured;
  final bool isActive;
  final String? categoryName;
  final String? branchName;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    this.branchId,
    this.nameAr,
    this.imageUrl,
    this.description,
    this.sku,
    this.stockQty = 0,
    this.packSize,
    this.isFeatured = false,
    this.isActive = true,
    this.categoryName,
    this.branchName,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt(),
      nameAr: json['name_ar'] as String?,
      imageUrl: _normalizeImageUrl(json['image_url'] as String?),
      description: json['description'] as String?,
      sku: json['sku'] as String?,
      stockQty: (json['stock_qty'] as num?)?.toInt() ?? 0,
      packSize: (json['pack_size'] as String?)?.trim(),
      isFeatured: json['is_featured'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      categoryName: (json['category_name'] as String?)?.trim(),
      branchName: (json['branch_name'] as String?)?.trim(),
    );
  }
}

String? _normalizeImageUrl(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  return value;
}
