class ProductImageModel {
  final int id;
  final int? productId;
  final String imageUrl;
  final int sortOrder;
  final bool isPrimary;
  final String? createdAt;

  const ProductImageModel({
    required this.id,
    this.productId,
    required this.imageUrl,
    this.sortOrder = 0,
    this.isPrimary = false,
    this.createdAt,
  });

  factory ProductImageModel.fromJson(Map<String, dynamic> json) {
    return ProductImageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt(),
      imageUrl: ((json['image_url'] as String?) ?? '').trim(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: (json['created_at'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      if (productId != null) 'product_id': productId,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'is_primary': isPrimary,
    };
  }

  ProductImageModel copyWith({
    int? id,
    int? productId,
    String? imageUrl,
    int? sortOrder,
    bool? isPrimary,
    String? createdAt,
  }) {
    return ProductImageModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
