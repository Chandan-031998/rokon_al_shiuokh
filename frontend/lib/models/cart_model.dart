import 'cart_item_model.dart';

class CartModel {
  final List<CartItemModel> items;
  final double subtotal;
  final double total;
  final String currency;

  const CartModel({
    required this.items,
    required this.subtotal,
    required this.total,
    required this.currency,
  });

  bool get isEmpty => items.isEmpty;

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(CartItemModel.fromJson)
            .toList()
        : const <CartItemModel>[];

    return CartModel(
      items: items,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String? ?? 'SAR').trim(),
    );
  }
}
