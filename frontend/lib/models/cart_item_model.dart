import 'branch_model.dart';
import 'product_model.dart';

class CartItemModel {
  final int id;
  final int quantity;
  final int? branchId;
  final double lineTotal;
  final ProductModel product;
  final BranchModel? branch;

  const CartItemModel({
    required this.id,
    required this.quantity,
    required this.branchId,
    required this.lineTotal,
    required this.product,
    required this.branch,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt(),
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      product: ProductModel.fromJson(
        (json['product'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      branch: json['branch'] is Map<String, dynamic>
          ? BranchModel.fromJson(json['branch'] as Map<String, dynamic>)
          : null,
    );
  }
}
