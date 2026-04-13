import 'branch_model.dart';

class SavedAddressModel {
  final int id;
  final String label;
  final String city;
  final String neighborhood;
  final String addressLine;
  final bool isDefault;

  const SavedAddressModel({
    required this.id,
    required this.label,
    required this.city,
    required this.neighborhood,
    required this.addressLine,
    required this.isDefault,
  });

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: UserModel._asInt(json['id']),
      label: UserModel._asString(json['label']),
      city: UserModel._asString(json['city']),
      neighborhood: UserModel._asString(json['neighborhood']),
      addressLine: UserModel._asString(json['address_line']),
      isDefault: UserModel._asBool(json['is_default']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'city': city,
      'neighborhood': neighborhood,
      'address_line': addressLine,
      'is_default': isDefault,
    };
  }
}

class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;
  final String? createdAt;
  final int orderCount;
  final double totalSpent;
  final List<SavedAddressModel> addresses;
  final BranchModel? preferredBranch;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.orderCount = 0,
    this.totalSpent = 0,
    required this.addresses,
    required this.preferredBranch,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawAddresses = json['addresses'];
    return UserModel(
      id: _asInt(json['id']),
      fullName: _asString(json['full_name']),
      email: _asString(json['email']),
      phone: _asNullableString(json['phone']),
      role: _asString(json['role']).isEmpty
          ? 'customer'
          : _asString(json['role']),
      isActive: _asBool(json['is_active'], fallback: true),
      createdAt: _asNullableString(json['created_at']),
      orderCount: _asInt(json['order_count']),
      totalSpent: _asDouble(json['total_spent']),
      addresses: rawAddresses is List
          ? rawAddresses
              .whereType<Map<String, dynamic>>()
              .map(SavedAddressModel.fromJson)
              .where((address) =>
                  address.id > 0 ||
                  address.label.isNotEmpty ||
                  address.addressLine.isNotEmpty)
              .toList()
          : const <SavedAddressModel>[],
      preferredBranch: json['preferred_branch'] is Map<String, dynamic>
          ? _safePreferredBranch(
              json['preferred_branch'] as Map<String, dynamic>)
          : null,
    );
  }

  static BranchModel? _safePreferredBranch(Map<String, dynamic> json) {
    final branch = BranchModel.fromJson(json);
    if (branch.id <= 0 || branch.name.isEmpty) {
      return null;
    }
    return branch;
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

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
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

  static bool _asBool(dynamic value, {bool fallback = false}) {
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt,
      'order_count': orderCount,
      'total_spent': totalSpent,
      'addresses': addresses.map((address) => address.toJson()).toList(),
      'preferred_branch': preferredBranch == null
          ? null
          : {
              'id': preferredBranch!.id,
              'name': preferredBranch!.name,
              'city': preferredBranch!.city,
              'address': preferredBranch!.address,
              'phone': preferredBranch!.phone,
            },
    };
  }
}
