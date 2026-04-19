import 'branch_model.dart';
import 'product_model.dart';

class ProductDetailModel {
  final ProductModel product;
  final List<ProductModel> relatedProducts;
  final List<BranchModel> availableBranches;

  const ProductDetailModel({
    required this.product,
    this.relatedProducts = const <ProductModel>[],
    this.availableBranches = const <BranchModel>[],
  });

  factory ProductDetailModel.fromJson(Map<String, dynamic> json) {
    final productJson =
        (json['product'] as Map?)?.cast<String, dynamic>() ?? const {};
    final relatedJson = json['related_products'] as List? ?? const [];
    final branchesJson = json['available_branches'] as List? ?? const [];

    return ProductDetailModel(
      product: ProductModel.fromJson(productJson),
      relatedProducts: relatedJson
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList(),
      availableBranches: branchesJson
          .whereType<Map<String, dynamic>>()
          .map(BranchModel.fromJson)
          .toList(),
    );
  }
}
