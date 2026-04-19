class BranchModel {
  final int id;
  final String name;
  final String? city;
  final String? address;
  final String? phone;
  final String? mapLink;
  final bool isActive;
  final bool pickupAvailable;
  final bool deliveryAvailable;
  final String? deliveryCoverage;
  final bool productAvailable;
  final int productCount;
  final int orderCount;

  const BranchModel({
    required this.id,
    required this.name,
    this.city,
    this.address,
    this.phone,
    this.mapLink,
    this.isActive = true,
    this.pickupAvailable = true,
    this.deliveryAvailable = true,
    this.deliveryCoverage,
    this.productAvailable = true,
    this.productCount = 0,
    this.orderCount = 0,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      city: _asNullableString(json['city']),
      address: _asNullableString(json['address']),
      phone: _asNullableString(json['phone']),
      mapLink: _asNullableString(json['map_link']),
      isActive: _asBool(json['is_active'], fallback: true),
      pickupAvailable: _asBool(json['pickup_available'], fallback: true),
      deliveryAvailable: _asBool(json['delivery_available'], fallback: true),
      deliveryCoverage: _asNullableString(json['delivery_coverage']),
      productAvailable: _asBool(json['product_available'], fallback: true),
      productCount: _asInt(json['product_count']),
      orderCount: _asInt(json['order_count']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  static String? _asNullableString(dynamic value) {
    final normalized = _asString(value);
    return normalized.isEmpty ? null : normalized;
  }

  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }
}
