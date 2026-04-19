import 'product_model.dart';

class WishlistItemModel {
  final int id;
  final int productId;
  final String? createdAt;
  final ProductModel? product;

  const WishlistItemModel({
    required this.id,
    required this.productId,
    this.createdAt,
    this.product,
  });

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    return WishlistItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as String?)?.trim(),
      product: json['product'] is Map<String, dynamic>
          ? ProductModel.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }
}
