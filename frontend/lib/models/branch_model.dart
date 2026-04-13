class BranchModel {
  final int id;
  final String name;
  final String? city;
  final String? address;
  final String? phone;
  final bool isActive;
  final bool pickupAvailable;
  final bool deliveryAvailable;
  final String? deliveryCoverage;
  final int productCount;
  final int orderCount;

  const BranchModel({
    required this.id,
    required this.name,
    this.city,
    this.address,
    this.phone,
    this.isActive = true,
    this.pickupAvailable = true,
    this.deliveryAvailable = true,
    this.deliveryCoverage,
    this.productCount = 0,
    this.orderCount = 0,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      city: json['city'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      pickupAvailable: json['pickup_available'] as bool? ?? true,
      deliveryAvailable: json['delivery_available'] as bool? ?? true,
      deliveryCoverage: (json['delivery_coverage'] as String?)?.trim(),
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
    );
  }
}
