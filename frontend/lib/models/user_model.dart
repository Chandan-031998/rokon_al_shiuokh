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
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: (json['label'] as String? ?? '').trim(),
      city: (json['city'] as String? ?? '').trim(),
      neighborhood: (json['neighborhood'] as String? ?? '').trim(),
      addressLine: (json['address_line'] as String? ?? '').trim(),
      isDefault: json['is_default'] as bool? ?? false,
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
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: (json['full_name'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      phone: (json['phone'] as String?)?.trim(),
      role: (json['role'] as String? ?? 'customer').trim(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: (json['created_at'] as String?)?.trim(),
      orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      addresses: rawAddresses is List
          ? rawAddresses
              .whereType<Map<String, dynamic>>()
              .map(SavedAddressModel.fromJson)
              .toList()
          : const <SavedAddressModel>[],
      preferredBranch: json['preferred_branch'] is Map<String, dynamic>
          ? BranchModel.fromJson(
              json['preferred_branch'] as Map<String, dynamic>)
          : null,
    );
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
