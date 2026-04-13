import 'branch_model.dart';

class OrderCustomerModel {
  final int id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? guestSessionId;

  const OrderCustomerModel({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.guestSessionId,
  });

  factory OrderCustomerModel.fromJson(Map<String, dynamic> json) {
    return OrderCustomerModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: (json['full_name'] as String? ?? '').trim(),
      email: (json['email'] as String?)?.trim(),
      phone: (json['phone'] as String?)?.trim(),
      guestSessionId: (json['guest_session_id'] as String?)?.trim(),
    );
  }
}

class OrderAddressModel {
  final int id;
  final String label;
  final String city;
  final String neighborhood;
  final String addressLine;

  const OrderAddressModel({
    required this.id,
    required this.label,
    required this.city,
    required this.neighborhood,
    required this.addressLine,
  });

  factory OrderAddressModel.fromJson(Map<String, dynamic> json) {
    return OrderAddressModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: (json['label'] as String? ?? '').trim(),
      city: (json['city'] as String? ?? '').trim(),
      neighborhood: (json['neighborhood'] as String? ?? '').trim(),
      addressLine: (json['address_line'] as String? ?? '').trim(),
    );
  }
}

class OrderLineModel {
  final int id;
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final double lineTotal;

  const OrderLineModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.lineTotal,
  });

  factory OrderLineModel.fromJson(Map<String, dynamic> json) {
    return OrderLineModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: (json['product_name'] as String? ?? '').trim(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OrderModel {
  final int id;
  final String orderNumber;
  final String orderType;
  final String orderStatus;
  final String paymentMethod;
  final String paymentStatus;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount;
  final double totalAmount;
  final String? notes;
  final String? adminNotes;
  final String? createdAt;
  final BranchModel? branch;
  final OrderAddressModel? address;
  final OrderCustomerModel? customer;
  final List<OrderLineModel> items;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.orderType,
    required this.orderStatus,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.totalAmount,
    required this.notes,
    required this.adminNotes,
    required this.createdAt,
    required this.branch,
    required this.address,
    required this.customer,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return OrderModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderNumber: (json['order_number'] as String? ?? '').trim(),
      orderType: (json['order_type'] as String? ?? '').trim(),
      orderStatus: (json['order_status'] as String? ?? '').trim(),
      paymentMethod: (json['payment_method'] as String? ?? '').trim(),
      paymentStatus: (json['payment_status'] as String? ?? '').trim(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      notes: (json['notes'] as String?)?.trim(),
      adminNotes: (json['admin_notes'] as String?)?.trim(),
      createdAt: (json['created_at'] as String?)?.trim(),
      branch: json['branch'] is Map<String, dynamic>
          ? BranchModel.fromJson(json['branch'] as Map<String, dynamic>)
          : null,
      address: json['address'] is Map<String, dynamic>
          ? OrderAddressModel.fromJson(json['address'] as Map<String, dynamic>)
          : null,
      customer: json['customer'] is Map<String, dynamic>
          ? OrderCustomerModel.fromJson(
              json['customer'] as Map<String, dynamic>)
          : null,
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(OrderLineModel.fromJson)
              .toList()
          : const <OrderLineModel>[],
    );
  }
}
